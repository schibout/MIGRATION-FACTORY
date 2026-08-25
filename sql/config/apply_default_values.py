#!/usr/bin/env python3
"""Remplace les valeurs par defaut codees en dur d'un module par des appels a
`public.get_default_value()`, en gardant l'ancien litteral comme repli.

Le repli garantit un deploiement neutre : tant que la table `public.etl_default_values`
est vide ou la ligne desactivee, la fonction ETL rend exactement le meme resultat
qu'avant. Un litteral remplace `'FR' as default_language` devient donc :

    public.get_default_value('clean_data.customer_info', 'default_language', 'FR') as default_language

Les colonnes cibles non textuelles recoivent un cast explicite, car `get_default_value`
retourne TEXT et PostgreSQL n'a aucun cast implicite texte -> numeric/date/boolean.
Les replis numeriques sont toujours quotes (`'1'`) : passer un entier nu ferait echouer
la resolution de la fonction, dont le 3e parametre est TEXT.

Les lignes d'inventaire marquees `A_ARBITRER` (meme colonne, valeurs differentes selon
le bloc) sont ignorees : elles exigent de nommer des variantes, ce qui ne s'automatise
pas sans risque.

La detection reutilise l'analyseur de `extract_default_values.py`, ce qui garantit que
l'inventaire et la reecriture voient exactement les memes projections.

Usage :
    python sql/config/apply_default_values.py <dossier_module> [--dry-run]
"""
import argparse
import csv
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from extract_default_values import analyser_fichier  # noqa: E402

RACINE = Path(__file__).resolve().parents[2]
FICHIER_TYPES = RACINE / 'sql' / 'config' / 'types_colonnes_cibles.tsv'


def charger_casts(chemin=None):
    """Retourne {(table_sans_schema, colonne): '::type'} pour les colonnes non textuelles."""
    casts = {}
    chemin = Path(chemin) if chemin else FICHIER_TYPES
    if not chemin.exists():
        print(f"Fichier de types absent : {chemin}", file=sys.stderr)
        return None
    with open(chemin, encoding='utf-8', newline='') as f:
        for ligne in csv.DictReader(f, delimiter='\t'):
            casts[(ligne['table'].lower(), ligne['colonne'].lower())] = ligne['cast_sql']
    return casts


def charger_inventaire(dossier: Path):
    """Retourne l'ensemble des (table, colonne, valeur) STANDARD a parametrer."""
    chemin = dossier / 'inventaire_colonnes_valeurs_defaut.csv'
    retenus = set()
    ignores = 0
    with open(chemin, encoding='utf-8-sig', newline='') as f:
        for ligne in csv.DictReader(f, delimiter=';'):
            if ligne['variante'] != 'STANDARD':
                ignores += 1
                continue
            valeur = ('NULL' if ligne['type_valeur_defaut'] == 'NULL_EXPLICITE'
                      else ligne['valeur_par_defaut'])
            retenus.add((ligne['table_cible'].lower(), ligne['colonne'].lower(), valeur))
    return retenus, ignores


def repli_sql(type_defaut: str, valeur: str) -> str:
    """Le 3e argument de get_default_value : NULL nu, ou la valeur quotee."""
    if type_defaut == 'NULL_EXPLICITE':
        return 'NULL'
    return "'" + valeur.replace("'", "''") + "'"


def traiter(dossier: Path, dry_run: bool, types=None):
    casts = charger_casts(types)
    if casts is None:
        return 1
    inventaire, ignores = charger_inventaire(dossier)

    total, par_fichier, sans_cast_connu = 0, {}, []

    for fichier in sorted(dossier.glob('*.sql')):
        projections = analyser_fichier(fichier)
        lignes = fichier.read_text(encoding='utf-8').splitlines(keepends=True)
        remplacements = []

        for p in projections:
            valeur = ('NULL' if p['type_valeur_defaut'] == 'NULL_EXPLICITE'
                      else p['valeur_par_defaut'])
            cle = (p['table_cible'], p['colonne'], valeur)
            if cle not in inventaire:
                continue

            table_courte = p['table_cible'].split('.', 1)[1]
            cast = casts.get((table_courte, p['colonne']), '')
            appel = (f"public.get_default_value('{p['table_cible']}', '{p['colonne']}', "
                     f"{repli_sql(p['type_valeur_defaut'], valeur)}){cast}")
            remplacements.append((p['ligne_projection'], p['regle_sql'], appel, p['colonne']))

        # De la fin vers le debut : les numeros de ligne restent valides pendant la reecriture.
        for numero, ancien, nouveau, colonne in sorted(remplacements, reverse=True):
            index = numero - 1
            ligne = lignes[index]
            if ancien not in ligne:
                sans_cast_connu.append(f"{fichier.name}:{numero} litteral introuvable ({ancien})")
                continue
            lignes[index] = ligne.replace(ancien, nouveau, 1)

        if remplacements:
            par_fichier[fichier.name] = len(remplacements)
            total += len(remplacements)
            if not dry_run:
                fichier.write_text(''.join(lignes), encoding='utf-8')

    print(f"Module {dossier.name} : {total} remplacements"
          f"{' (simulation)' if dry_run else ''}, {ignores} lignes A_ARBITRER ignorees")
    for nom, n in sorted(par_fichier.items()):
        print(f"   {n:4d}  {nom}")
    for anomalie in sans_cast_connu:
        print(f"   ANOMALIE {anomalie}", file=sys.stderr)
    return 0


def main():
    sys.stdout.reconfigure(encoding='utf-8')
    parseur = argparse.ArgumentParser(description=__doc__)
    parseur.add_argument('dossier')
    parseur.add_argument('--dry-run', action='store_true',
                         help="compte les remplacements sans ecrire les fichiers")
    parseur.add_argument('--types', help="fichier TSV de types (defaut : sql/config/types_colonnes_cibles.tsv)")
    args = parseur.parse_args()
    return traiter(Path(args.dossier), args.dry_run, args.types)


if __name__ == '__main__':
    sys.exit(main())
