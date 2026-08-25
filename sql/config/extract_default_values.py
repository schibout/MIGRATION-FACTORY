#!/usr/bin/env python3
"""Inventorie les valeurs par defaut codees en dur dans les scripts ETL d'un module.

Detecte les projections litterales d'un INSERT ... SELECT (ou CREATE TEMP TABLE ... AS
SELECT) : une constante quotee, un nombre, ou NULL, suivie de `as <colonne>`.
Les expressions derivees (CASE, COALESCE, SUBSTRING, references de colonnes...) sont
ignorees, de meme que les litteraux des clauses WHERE / RAISE NOTICE / statistiques,
qui ne sont jamais de la forme `<litteral> as <alias>` en debut de ligne.

LIMITE CONNUE : seules les projections nommees (`<litteral> as <colonne>`) sont vues.
Les listes `VALUES (...)` positionnelles, ou la colonne est deduite de sa position dans
la liste de l'INSERT, echappent a la detection et doivent etre inventoriees a la main.
Valide sur le module supplier : 180 des 181 valeurs de l'inventaire de reference sont
retrouvees, sans aucun faux positif ; l'unique manque est un bloc VALUES positionnel.

Usage :
    python sql/config/extract_default_values.py <dossier_module> [--module <nom>]

Sortie CSV (point-virgule) sur stdout, memes colonnes que
sql/supplier/inventaire_colonnes_valeurs_defaut.csv :
    table_cible;variante;colonne;type_valeur_defaut;valeur_par_defaut;regle_sql;script_source;ligne_insert
"""
import argparse
import re
import sys
from pathlib import Path

# Colonnes d'audit : jamais parametrables, elles restent codees en dur.
COLONNES_TECHNIQUES = {
    'created_by', 'updated_by', 'created_timestamp', 'updated_timestamp', 'is_deleted',
}

# Cible d'un INSERT / CREATE TEMP TABLE : fixe la table a laquelle rattacher les projections.
RE_CIBLE = re.compile(
    r"\bINSERT\s+INTO\s+(clean_data\.[A-Za-z_][A-Za-z0-9_]*)"
    r"|\bCREATE\s+(?:TEMP|TEMPORARY)\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?([A-Za-z_][A-Za-z0-9_]*)",
    re.IGNORECASE,
)

# Une projection litterale, seule sur sa ligne, avec son alias.
#   'X' as col | '' as col | 12 as col | 0::numeric as col | NULL as col | NULL::NUMERIC(20) as col
#   DATE '2099-12-31' as col
RE_PROJECTION = re.compile(
    r"^\s*(?P<litteral>"
    r"(?:DATE\s+)?'(?P<texte>(?:[^']|'')*)'"          # constante texte (quotes doublees gerees)
    r"|NULL"                                          # NULL explicite
    r"|-?\d+(?:\.\d+)?"                               # nombre
    r")"
    r"(?P<cast>\s*::\s*[A-Za-z_][A-Za-z0-9_]*(?:\s*\(\s*\d+(?:\s*,\s*\d+)?\s*\))?)?"
    r"\s+(?:as|AS)\s+(?P<alias>[A-Za-z_][A-Za-z0-9_]*)\s*,?\s*(?:--.*)?$",
    re.IGNORECASE,
)


def analyser_fichier(chemin: Path):
    """Retourne la liste des projections litterales du fichier, avec leur table cible.

    Le suivi s'arrete a chaque fin d'instruction (`;`) : sans cela, les SELECT de
    statistiques places apres l'INSERT (`'INSERTION REUSSIE' as execution_status`)
    seraient attribues a tort a la derniere table inseree.

    Les scripts qui projettent d'abord dans une table temporaire puis inserent
    depuis celle-ci sont resolus en deuxieme passe (voir `_resoudre_temporaires`).
    """
    texte_complet = chemin.read_text(encoding='utf-8', errors='replace')
    lignes = texte_complet.splitlines()
    resultats = []
    table_courante = None
    ligne_insert = 0

    for numero, ligne in enumerate(lignes, start=1):
        cible = RE_CIBLE.search(ligne)
        if cible:
            # Casse normalisee : PostgreSQL replie les identifiants non quotes en
            # minuscules, la cle passee a get_default_value() doit donc l'etre aussi.
            nom = (cible.group(1) or cible.group(2)).lower()
            # Une table temporaire est marquee pour resolution ulterieure.
            table_courante = nom if nom.startswith('clean_data.') else f'TEMP:{nom}'
            ligne_insert = numero
            continue

        projection = RE_PROJECTION.match(ligne)
        if not projection or table_courante is None:
            if ';' in ligne:
                table_courante = None
            continue

        alias = projection.group('alias')
        if alias.lower() in COLONNES_TECHNIQUES:
            continue

        litteral = projection.group('litteral')
        cast = (projection.group('cast') or '').strip()
        texte = projection.group('texte')

        if texte is not None:
            type_defaut, valeur = 'CONSTANTE_FORCEE', texte.replace("''", "'")
        elif litteral.upper() == 'NULL':
            type_defaut, valeur = 'NULL_EXPLICITE', 'NULL'
        else:
            type_defaut, valeur = 'CONSTANTE_FORCEE', litteral

        resultats.append({
            'table_cible': table_courante,
            'colonne': alias.lower(),
            'type_valeur_defaut': type_defaut,
            'valeur_par_defaut': '' if type_defaut == 'NULL_EXPLICITE' else valeur,
            'regle_sql': litteral + cast,
            'script_source': chemin.name,
            'ligne_insert': ligne_insert,
            'ligne_projection': numero,
        })
        if ';' in ligne:
            table_courante = None

    return _resoudre_temporaires(resultats, texte_complet)


RE_INSERT_DEPUIS = re.compile(
    r"INSERT\s+INTO\s+(clean_data\.[A-Za-z_][A-Za-z0-9_]*)(.*?);",
    re.IGNORECASE | re.DOTALL,
)


def _resoudre_temporaires(resultats, texte):
    """Remplace les cibles `TEMP:<nom>` par la table clean_data qui lit cette temporaire.

    Motif courant : `CREATE TEMP TABLE t AS SELECT '<litteral>' as col ...` puis
    `INSERT INTO clean_data.X (...) SELECT ... FROM t`. Les valeurs par defaut sont
    projetees dans la temporaire mais atterrissent dans X.
    """
    correspondances = {}
    for cible, corps in RE_INSERT_DEPUIS.findall(texte):
        for mot in re.findall(r"\bFROM\s+([A-Za-z_][A-Za-z0-9_]*)", corps, re.IGNORECASE):
            correspondances.setdefault(f'TEMP:{mot.lower()}', cible.lower())

    resolus = []
    for ligne in resultats:
        table = ligne['table_cible']
        if table.startswith('TEMP:'):
            reelle = correspondances.get(table)
            if reelle is None:
                continue  # temporaire jamais reversee dans clean_data : hors perimetre
            ligne['table_cible'] = reelle
        resolus.append(ligne)
    return resolus


def main():
    # Sans cela, une redirection `> fichier` sous Windows utilise la codepage console
    # (cp1252) et corrompt les accents et les caracteres non latins.
    sys.stdout.reconfigure(encoding='utf-8')

    parseur = argparse.ArgumentParser(description=__doc__)
    parseur.add_argument('dossier', help="dossier du module, ex. sql/customer")
    parseur.add_argument('--module', help="nom du module (defaut : nom du dossier)")
    args = parseur.parse_args()

    dossier = Path(args.dossier)
    if not dossier.is_dir():
        print(f"Dossier introuvable : {dossier}", file=sys.stderr)
        return 1

    lignes = []
    for fichier in sorted(dossier.glob('*.sql')):
        lignes.extend(analyser_fichier(fichier))

    # Une seule entree par (table, colonne, valeur) : les repetitions a valeur identique
    # (blocs UNION ALL) donnent une seule ligne de configuration. Les repetitions a
    # valeurs DIFFERENTES signalent des variantes, marquees pour arbitrage manuel.
    par_cle = {}
    for ligne in lignes:
        par_cle.setdefault((ligne['table_cible'], ligne['colonne']), []).append(ligne)

    sortie = []
    for (table, colonne), occurrences in sorted(par_cle.items()):
        valeurs = {o['valeur_par_defaut'] + '|' + o['type_valeur_defaut'] for o in occurrences}
        variante = 'STANDARD' if len(valeurs) == 1 else 'A_ARBITRER'
        if variante == 'STANDARD':
            o = occurrences[0]
            sortie.append((table, variante, colonne, o['type_valeur_defaut'],
                           o['valeur_par_defaut'], o['regle_sql'], o['script_source'],
                           o['ligne_insert']))
        else:
            # Plusieurs valeurs pour la meme colonne : une ligne par occurrence, a nommer.
            for o in occurrences:
                sortie.append((table, variante, colonne, o['type_valeur_defaut'],
                               o['valeur_par_defaut'], o['regle_sql'], o['script_source'],
                               o['ligne_projection']))

    print('table_cible;variante;colonne;type_valeur_defaut;valeur_par_defaut;regle_sql;script_source;ligne_insert')
    for ligne in sortie:
        print(';'.join(str(champ).replace(';', ',') for champ in ligne))
    return 0


if __name__ == '__main__':
    sys.exit(main())
