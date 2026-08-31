#!/usr/bin/env python3
"""Verifie que toutes les valeurs par defaut des scripts ETL sont pilotables par l'ecran.

Pour chaque appel `public.get_default_value(table, colonne, repli[, variante])` trouve dans
`sql/<module>/*.sql`, controle qu'il existe une ligne correspondante dans les migrations de
seed de `public.etl_default_values`, et que la valeur seedee est IDENTIQUE au repli code en
dur. Sans ligne seedee, l'ecran Configuration > Valeurs par defaut n'affiche rien et seul le
repli s'applique ; avec une valeur differente, l'ecran ment sur ce que fait reellement l'ETL.

Signale aussi les litteraux qui n'ont jamais ete parametres, via l'inventaire de chaque
module (lignes `A_ARBITRER` comprises, contrairement a apply_default_values.py).

Usage :
    python sql/config/verifier_valeurs_defaut.py            # tous les modules
    python sql/config/verifier_valeurs_defaut.py sql/customer

Code de sortie : 0 si tout est coherent, 1 sinon.
"""
import csv
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from apply_default_values import charger_seed  # noqa: E402
from extract_default_values import COLONNES_TECHNIQUES  # noqa: E402

RACINE = Path(__file__).resolve().parents[2]

# public.get_default_value('clean_data.x', 'col', 'repli'|NULL[, 'VARIANTE'])
APPEL = re.compile(
    r"public\.get_default_value\(\s*'([^']+)'\s*,\s*'([^']+)'\s*,\s*"
    r"(NULL|'(?:[^']|'')*')\s*(?:,\s*'([A-Z0-9_]+)'\s*)?\)")


def litteral(brut):
    """Le 3e argument tel qu'il sera lu par la fonction : None pour NULL."""
    if brut == 'NULL':
        return None
    return brut[1:-1].replace("''", "'")


def modules(cible=None):
    if cible:
        return [Path(cible)]
    # `functions` porte la definition de get_default_value et ses exemples, pas un ETL.
    exclus = {'config', 'functions', 'migrations', 'ai', 'sharepoint', 'structure'}
    return sorted(d for d in (RACINE / 'sql').iterdir()
                  if d.is_dir() and any(d.glob('*.sql')) and d.name not in exclus)


def verifier(dossiers, seed):
    manquantes, divergences, appels = [], [], 0
    for dossier in dossiers:
        for fichier in sorted(dossier.glob('*.sql')):
            texte = fichier.read_text(encoding='utf-8')
            for numero, ligne in enumerate(texte.splitlines(), 1):
                if ligne.lstrip().startswith('--'):   # exemples en commentaire
                    continue
                for table, colonne, repli, variante in APPEL.findall(ligne):
                    appels += 1
                    variante = variante or 'STANDARD'
                    seedee = seed.get((table, colonne, variante))
                    ou = f"{fichier.relative_to(RACINE)}:{numero}"
                    if seedee is None:
                        manquantes.append(f"{ou} {table}.{colonne} [{variante}]")
                        continue
                    type_seed, valeur_seed = seedee
                    attendu = None if type_seed == 'NULL' else valeur_seed
                    if attendu != litteral(repli):
                        divergences.append(
                            f"{ou} {table}.{colonne} [{variante}] "
                            f"repli={litteral(repli)!r} != seed={attendu!r}")
    return appels, manquantes, divergences


def litteraux_restants(dossiers):
    """Colonnes encore codees en dur d'apres l'inventaire du module."""
    restants = set()
    for dossier in dossiers:
        inventaire = dossier / 'inventaire_colonnes_valeurs_defaut.csv'
        if not inventaire.exists():
            continue
        for ligne in csv.DictReader(open(inventaire, encoding='utf-8-sig', newline=''),
                                    delimiter=';'):
            # Seules les constantes sont parametrables ; les expressions derivees
            # (COALESCE, references de colonnes...) restent du code.
            if ligne['type_valeur_defaut'] not in ('CONSTANTE_FORCEE', 'NULL_EXPLICITE'):
                continue
            # Colonnes d'audit : hors perimetre, elles restent codees en dur.
            if ligne['colonne'] in COLONNES_TECHNIQUES:
                continue
            fichier = dossier / ligne['script_source']
            if not fichier.exists():
                continue
            # `ligne_insert` designe l'INSERT, pas la projection : on cherche le litteral
            # d'origine (`<regle_sql> as <colonne>`) partout dans le fichier.
            motif = re.compile(r"^\s*" + re.escape(ligne['regle_sql']) +
                               r"\s+AS\s+\"?" + re.escape(ligne['colonne']) + r"\"?\s*,?\s*$",
                               re.I)
            for numero, contenu in enumerate(fichier.read_text(encoding='utf-8').splitlines(), 1):
                if motif.match(contenu):
                    restants.add(f"{fichier.relative_to(RACINE)}:{numero} "
                                 f"{ligne['table_cible']}.{ligne['colonne']} = {ligne['regle_sql']}")
    return sorted(restants)


def main():
    seed = charger_seed()
    if seed is None:
        return 1
    dossiers = modules(sys.argv[1] if len(sys.argv) > 1 else None)
    appels, manquantes, divergences = verifier(dossiers, seed)
    restants = litteraux_restants(dossiers)

    print(f"{appels} appels a get_default_value, {len(seed)} lignes seedees")
    for titre, liste in (("SANS ligne seedee (invisible dans l'ecran)", manquantes),
                         ("DIVERGENCE repli / seed", divergences),
                         ("litteraux encore codes en dur", restants)):
        print(f"{len(liste)} {titre}")
        for item in liste[:40]:
            print(f"   {item}")
        if len(liste) > 40:
            print(f"   ... et {len(liste) - 40} autres")
    return 1 if (manquantes or divergences or restants) else 0


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    sys.exit(main())
