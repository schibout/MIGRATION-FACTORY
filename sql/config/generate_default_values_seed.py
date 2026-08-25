#!/usr/bin/env python3
"""Génère les INSERT de seed pour public.etl_default_values depuis l'inventaire
CSV d'un module (sql/<module>/inventaire_colonnes_valeurs_defaut.csv).

Les lignes A_ARBITRER (même colonne, valeurs différentes selon le bloc) sont
ignorées : elles exigent de nommer des variantes, ce qui ne s'automatise pas.

Usage :
    python sql/config/generate_default_values_seed.py [dossier_module] > seed.sql
    (défaut : sql/supplier, comme le seed historique de la migration 031)
"""
import argparse
import csv
import sys
from pathlib import Path

# Forcer UTF-8 en sortie : le codepage console Windows (cp1252/850) par
# defaut corromprait les accents (script_source, description) autrement.
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

TYPES_RETENUS = {'CONSTANTE_FORCEE': 'CONSTANTE', 'NULL_EXPLICITE': 'NULL'}
COLONNES_TECHNIQUES = {'created_by', 'updated_by', 'created_timestamp', 'updated_timestamp', 'is_deleted'}


def esc(s):
    return s.replace("'", "''")


def main():
    parseur = argparse.ArgumentParser(description=__doc__)
    parseur.add_argument('dossier', nargs='?', default=str(Path(__file__).resolve().parents[1] / 'supplier'),
                         help="dossier du module, ex. sql/customer (defaut : sql/supplier)")
    parseur.add_argument('--module', help="nom du module en base (defaut : nom du dossier)")
    parseur.add_argument('--created-by', help="valeur de created_by (defaut : seed_<module>)")
    args = parseur.parse_args()

    dossier = Path(args.dossier)
    module = args.module or dossier.name
    created_by = args.created_by or f'seed_{module}'[:50]
    csv_path = dossier / 'inventaire_colonnes_valeurs_defaut.csv'

    vus = set()
    lignes = []
    arbitrages = 0
    with open(csv_path, encoding='utf-8-sig', newline='') as f:
        for row in csv.DictReader(f, delimiter=';'):
            type_v = TYPES_RETENUS.get(row['type_valeur_defaut'])
            if type_v is None or row['colonne'] in COLONNES_TECHNIQUES:
                continue
            if row['variante'] == 'A_ARBITRER':
                arbitrages += 1
                continue
            cle = (row['table_cible'], row['colonne'], row['variante'])
            if cle in vus:
                continue
            vus.add(cle)
            valeur = 'NULL' if type_v == 'NULL' else "'" + esc(row['valeur_par_defaut']) + "'"
            desc = esc(f"Source : {row['script_source']} (type {row['type_valeur_defaut']})")
            lignes.append(
                "INSERT INTO public.etl_default_values "
                "(module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)\n"
                f"VALUES ('{esc(module)}', '{esc(row['table_cible'])}', '{esc(row['colonne'])}', "
                f"'{esc(row['variante'])}', '{type_v}', {valeur}, '{desc}', '{esc(created_by)}')\n"
                "ON CONFLICT (table_cible, colonne, variante) DO NOTHING;"
            )
    print(f"-- Seed {module} : {len(lignes)} lignes générées depuis l'inventaire CSV"
          + (f" ({arbitrages} lignes A_ARBITRER ignorées)" if arbitrages else ""))
    print('\n'.join(lignes))


if __name__ == '__main__':
    sys.exit(main())
