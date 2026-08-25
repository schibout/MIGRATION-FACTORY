#!/usr/bin/env python3
"""Génère les INSERT de seed pour public.etl_default_values depuis
sql/supplier/inventaire_colonnes_valeurs_defaut.csv.
Usage : python sql/config/generate_default_values_seed.py > /tmp/seed_supplier.sql
"""
import csv
import sys
from pathlib import Path

# Forcer UTF-8 en sortie : le codepage console Windows (cp1252/850) par
# defaut corromprait les accents (script_source, description) autrement.
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

CSV_PATH = Path(__file__).resolve().parents[1] / 'supplier' / 'inventaire_colonnes_valeurs_defaut.csv'
TYPES_RETENUS = {'CONSTANTE_FORCEE': 'CONSTANTE', 'NULL_EXPLICITE': 'NULL'}
COLONNES_TECHNIQUES = {'created_by', 'updated_by', 'created_timestamp', 'updated_timestamp', 'is_deleted'}


def esc(s):
    return s.replace("'", "''")


def main():
    vus = set()
    lignes = []
    with open(CSV_PATH, encoding='utf-8-sig', newline='') as f:
        for row in csv.DictReader(f, delimiter=';'):
            type_v = TYPES_RETENUS.get(row['type_valeur_defaut'])
            if type_v is None or row['colonne'] in COLONNES_TECHNIQUES:
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
                f"VALUES ('supplier', '{esc(row['table_cible'])}', '{esc(row['colonne'])}', "
                f"'{esc(row['variante'])}', '{type_v}', {valeur}, '{desc}', 'migration_031')\n"
                "ON CONFLICT (table_cible, colonne, variante) DO NOTHING;"
            )
    print(f"-- Seed supplier : {len(lignes)} lignes générées depuis l'inventaire CSV")
    print('\n'.join(lignes))


if __name__ == '__main__':
    sys.exit(main())
