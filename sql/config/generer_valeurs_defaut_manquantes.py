#!/usr/bin/env python3
"""Genere le script SQL d'insertion des valeurs par defaut absentes de la base.

Les migrations de seed (031, 032, 034...) sont la source de verite des valeurs
livrees avec le depot. Une migration etendue APRES son application laisse des
lignes seedees qui n'ont jamais atteint `public.etl_default_values` : la fonction
`get_default_value` n'ayant plus d'argument de repli depuis la migration 044,
un appel sur une de ces cles rendrait NULL en silence.

Ce script compare les seeds a la base et ecrit une migration contenant les seules
lignes manquantes, chacune en `ON CONFLICT DO NOTHING` : rejouable sans effet de
bord, et sans jamais ecraser une valeur ajustee depuis l'ecran
`/configuration/valeurs-defaut`.

Usage :
    python sql/config/generer_valeurs_defaut_manquantes.py                 # rapport + migration
    python sql/config/generer_valeurs_defaut_manquantes.py --dry-run       # rapport seul
    python sql/config/generer_valeurs_defaut_manquantes.py --tous          # rejoue TOUS les seeds
    python sql/config/generer_valeurs_defaut_manquantes.py --sortie x.sql

Code de sortie : 0 si un script a ete ecrit ou s'il n'y a rien a inserer, 1 sur erreur.
"""
import argparse
import os
import re
import sys
from pathlib import Path

import psycopg2

sys.path.insert(0, str(Path(__file__).resolve().parent))
from apply_default_values import FICHIERS_SEED, _decouper_valeurs  # noqa: E402
from verifier_valeurs_defaut import APPEL, modules  # noqa: E402

RACINE = Path(__file__).resolve().parents[2]
DOSSIER_MIGRATIONS = RACINE / 'migrations'

DB = dict(
    host=os.getenv('DB_HOST', '10.190.100.58'),
    port=os.getenv('DB_PORT', '5432'),
    dbname=os.getenv('DB_NAME', 'sap_migration_db'),
    user=os.getenv('DB_USER', 'postgres'),
    password=os.getenv('DB_PASSWORD', 'trimet2025'),
)

# Colonnes d'un VALUES de seed, dans l'ordre des migrations 031/032.
CHAMPS = ('module', 'table_cible', 'colonne', 'variante',
          'type_valeur', 'valeur', 'description', 'created_by')


def charger_seed_complet(chemins=None):
    """Retourne {(table_cible, colonne, variante): dict(CHAMPS)} depuis les seeds.

    Contrairement a `apply_default_values.charger_seed`, garde tous les champs :
    il faut pouvoir reecrire la ligne INSERT a l'identique.
    """
    seed = {}
    for chemin in (chemins or FICHIERS_SEED):
        chemin = Path(chemin)
        if not chemin.exists():
            print(f"Fichier de seed absent : {chemin}", file=sys.stderr)
            return None
        texte = chemin.read_text(encoding='utf-8')
        for bloc in re.finditer(r'VALUES\s*\(', texte):
            champs = _decouper_valeurs(texte[bloc.end():])
            if len(champs) < 6:
                continue
            ligne = dict(zip(CHAMPS, champs + [None] * (len(CHAMPS) - len(champs))))
            ligne['source'] = chemin.name
            # ON CONFLICT DO NOTHING cote SQL : la premiere ligne inseree gagne.
            seed.setdefault((ligne['table_cible'], ligne['colonne'],
                             ligne['variante']), ligne)
    return seed


def cles_en_base():
    """Retourne l'ensemble des cles (table_cible, colonne, variante) deja en base."""
    with psycopg2.connect(**DB) as conn, conn.cursor() as cur:
        cur.execute("SELECT table_cible, colonne, COALESCE(variante, 'STANDARD') "
                    "FROM public.etl_default_values")
        return {tuple(r) for r in cur.fetchall()}


def cles_appelees():
    """Retourne {cle: [emplacements]} pour chaque appel a get_default_value du depot."""
    appels = {}
    for dossier in modules():
        for fichier in sorted(dossier.glob('*.sql')):
            for numero, ligne in enumerate(
                    fichier.read_text(encoding='utf-8').splitlines(), 1):
                if ligne.lstrip().startswith('--'):   # exemples en commentaire
                    continue
                for table, colonne, variante in APPEL.findall(ligne):
                    cle = (table, colonne, variante or 'STANDARD')
                    appels.setdefault(cle, []).append(
                        f"{fichier.relative_to(RACINE)}:{numero}")
    return appels


def _litteral(valeur):
    """Rend un litteral SQL : NULL non quote, sinon chaine avec quotes doublees."""
    if valeur is None:
        return 'NULL'
    return "'" + valeur.replace("'", "''") + "'"


def prochain_numero():
    """Retourne le prochain numero de migration libre, sur 3 chiffres."""
    numeros = [int(m.group(1)) for f in DOSSIER_MIGRATIONS.glob('*.sql')
               if (m := re.match(r'(\d{3})_', f.name))]
    return f"{max(numeros, default=0) + 1:03d}"


def rendre_sql(lignes, appels, titre):
    """Rend le script SQL complet a partir des lignes de seed a inserer."""
    out = [
        "-- =====================================================================",
        f"-- {titre}",
        "--",
        "-- Genere par sql/config/generer_valeurs_defaut_manquantes.py",
        "-- Chaque INSERT est en ON CONFLICT DO NOTHING : le script est rejouable",
        "-- et ne remplace jamais une valeur ajustee depuis l'ecran",
        "-- /configuration/valeurs-defaut.",
        "-- =====================================================================",
        "",
        "BEGIN;",
        "",
    ]
    par_module = {}
    for ligne in lignes:
        par_module.setdefault(ligne['module'], []).append(ligne)

    def _cle(ligne):
        return (ligne['table_cible'], ligne['colonne'], ligne['variante'])

    for module in sorted(par_module):
        lot = sorted(par_module[module],
                     key=lambda l: (l['table_cible'], l['colonne'], l['variante']))
        out.append(f"-- --- module {module} ({len(lot)} ligne(s)) "
                   + "-" * max(0, 50 - len(module)))
        inutilisees = [l for l in lot if _cle(l) not in appels]
        if inutilisees:
            # Note groupee : une ligne de commentaire par INSERT noierait le script.
            out.append(f"-- {len(inutilisees)} de ces lignes ne sont appelees par aucun"
                       " get_default_value du depot :")
            out.append("-- elles ne changent rien au chargement, elles rendent la"
                       " constante visible et modifiable dans l'ecran.")
        for ligne in lot:
            out.append(
                "INSERT INTO public.etl_default_values "
                "(module, table_cible, colonne, variante, type_valeur, valeur, "
                "description, created_by)")
            out.append("VALUES (" + ", ".join(
                _litteral(ligne[champ]) for champ in CHAMPS) + ")")
            out.append("ON CONFLICT (table_cible, colonne, variante) DO NOTHING;")
        out.append("")

    out += [
        "-- Controle : doit afficher 0 ligne manquante.",
        "DO $$",
        "DECLARE v_manquantes integer;",
        "BEGIN",
        "    SELECT count(*) INTO v_manquantes FROM (VALUES",
        "        " + ",\n        ".join(
            f"({_litteral(l['table_cible'])}, {_litteral(l['colonne'])}, "
            f"{_litteral(l['variante'])})" for l in lignes),
        "    ) AS attendu(table_cible, colonne, variante)",
        "    WHERE NOT EXISTS (",
        "        SELECT 1 FROM public.etl_default_values d",
        "        WHERE d.table_cible = attendu.table_cible",
        "          AND d.colonne = attendu.colonne",
        "          AND COALESCE(d.variante, 'STANDARD') = attendu.variante);",
        "    IF v_manquantes > 0 THEN",
        "        RAISE EXCEPTION 'Il reste % valeur(s) par defaut absente(s)', "
        "v_manquantes;",
        "    END IF;",
        "    RAISE NOTICE 'Valeurs par defaut : les % lignes attendues sont "
        "presentes', " + str(len(lignes)) + ";",
        "END $$;",
        "",
        "COMMIT;",
        "",
    ]
    return "\n".join(out)


def main():
    parseur = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parseur.add_argument('--dry-run', action='store_true',
                         help="rapport seul, aucun fichier ecrit")
    parseur.add_argument('--tous', action='store_true',
                         help="rejoue TOUS les seeds, pas seulement les manquants")
    parseur.add_argument('--sortie', help="chemin du script SQL a ecrire")
    args = parseur.parse_args()

    seed = charger_seed_complet()
    if seed is None:
        return 1
    appels = cles_appelees()
    try:
        existantes = cles_en_base()
    except psycopg2.Error as err:
        print(f"Connexion a la base impossible : {err}", file=sys.stderr)
        return 1

    manquantes = {cle: ligne for cle, ligne in seed.items() if cle not in existantes}
    orphelines = sorted(cle for cle in appels if cle not in existantes
                        and cle not in seed)

    print(f"{len(seed)} lignes seedees, {len(existantes)} lignes en base, "
          f"{len(appels)} cles appelees par les scripts ETL")
    print(f"{len(manquantes)} seedee(s) absente(s) de la base")
    for cle, ligne in sorted(manquantes.items()):
        consommee = "appelee par l'ETL" if cle in appels else "aucun appel dans le depot"
        print(f"    {cle[0]}.{cle[1]} [{cle[2]}] = "
              f"{ligne['valeur']!r} ({ligne['source']}, {consommee})")
    if orphelines:
        print(f"\n{len(orphelines)} appel(s) sans ligne ni seed -> l'ETL ecrira NULL :")
        for cle in orphelines:
            print(f"    {cle[0]}.{cle[1]} [{cle[2]}] : {appels[cle][0]}")

    a_ecrire = seed if args.tous else manquantes
    if not a_ecrire:
        print("\nRien a inserer : la base contient deja toutes les valeurs seedees.")
        return 0
    if args.dry_run:
        print("\n--dry-run : aucun fichier ecrit.")
        return 0

    titre = ("Rejeu complet des valeurs par defaut ETL" if args.tous
             else "Valeurs par defaut ETL absentes de la base")
    # resolve() : --sortie peut etre relatif au repertoire courant, relative_to() non.
    sortie = (Path(args.sortie).resolve() if args.sortie else
              DOSSIER_MIGRATIONS / f"{prochain_numero()}_seed_valeurs_defaut_manquantes.sql")
    sortie.write_text(rendre_sql(list(a_ecrire.values()), appels, titre),
                      encoding='utf-8')
    affichage = (sortie.relative_to(RACINE) if sortie.is_relative_to(RACINE)
                 else sortie)
    print(f"\nScript ecrit : {affichage} ({len(a_ecrire)} INSERT)")
    return 0


if __name__ == '__main__':
    sys.exit(main())
