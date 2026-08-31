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

Une meme cle (table, colonne) peut etre partagee par plusieurs modules avec des valeurs
DIVERGENTES : le seed lui donne alors une variante par module (nom du module en
majuscules) au lieu de `STANDARD`. Le remplacement lit donc les migrations de seed pour
choisir la bonne variante :

    public.get_default_value('clean_data.customer_info', 'party_type', 'Customer', 'CUSTOMER')

Sans cela, un appel sans variante lirait la ligne `STANDARD` d'un AUTRE module (ex.
`payment_way_per_identity.party_type` = `Supplier` cote fournisseur) et changerait
silencieusement le resultat du chargement. Pour la meme raison, la valeur seedee est
comparee au litteral remplace : toute divergence est signalee et la ligne n'est PAS
reecrite.

La detection reutilise l'analyseur de `extract_default_values.py`, ce qui garantit que
l'inventaire et la reecriture voient exactement les memes projections.

Usage :
    python sql/config/apply_default_values.py <dossier_module> [--dry-run]
"""
import argparse
import csv
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from extract_default_values import analyser_fichier  # noqa: E402

RACINE = Path(__file__).resolve().parents[2]
FICHIER_TYPES = RACINE / 'sql' / 'config' / 'types_colonnes_cibles.tsv'
# Seeds de public.etl_default_values : source de verite des variantes et des valeurs.
FICHIERS_SEED = [
    RACINE / 'migrations' / '031_create_etl_default_values.sql',
    RACINE / 'migrations' / '032_seed_etl_default_values_autres_modules.sql',
    RACINE / 'migrations' / '034_seed_variantes_payment_way_per_identity.sql',
    RACINE / 'migrations' / '035_seed_etl_default_values_pm_actions.sql',
    RACINE / 'migrations' / '036_seed_default_value_c_density_fil.sql',
    RACINE / 'migrations' / '037_seed_valeurs_defaut_a_arbitrer.sql',
    RACINE / 'migrations' / '038_seed_valeurs_defaut_cust_ord_customer_file.sql',
]


def _decouper_valeurs(texte: str):
    """Decoupe la liste d'arguments d'un VALUES (...) SQL en respectant les quotes.

    Retourne la liste des valeurs ; None pour un NULL non quote (une chaine quotee
    valant 'NULL' reste la chaine 'NULL').
    """
    champs, courant, quote_vue, dans_quote, i = [], [], False, False, 0
    while i < len(texte):
        car = texte[i]
        if dans_quote:
            if car == "'":
                if i + 1 < len(texte) and texte[i + 1] == "'":
                    courant.append("'")
                    i += 2
                    continue
                dans_quote = False
            else:
                courant.append(car)
        elif car == "'":
            dans_quote = True
            quote_vue = True
        elif car == ",":
            champs.append(("".join(courant).strip(), quote_vue))
            courant, quote_vue = [], False
        elif car == ")":
            break
        else:
            courant.append(car)
        i += 1
    champs.append(("".join(courant).strip(), quote_vue))
    return [None if (not quote and valeur.upper() == "NULL") else valeur
            for valeur, quote in champs]


def charger_seed(chemins=None):
    """Retourne {(table_cible, colonne, variante): (type_valeur, valeur)} depuis les seeds."""
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
            _module, table, colonne, variante, type_valeur, valeur = champs[:6]
            # ON CONFLICT DO NOTHING cote SQL : la premiere ligne inseree gagne.
            seed.setdefault((table, colonne, variante), (type_valeur, valeur))
    return seed


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


def traiter(dossier: Path, dry_run: bool, types=None, seeds=None):
    casts = charger_casts(types)
    if casts is None:
        return 1
    seed = charger_seed(seeds)
    if seed is None:
        return 1
    inventaire, ignores = charger_inventaire(dossier)
    variante_module = dossier.name.upper()

    total, par_fichier, sans_cast_connu = 0, {}, []
    divergences, absentes = [], []

    for fichier in sorted(dossier.glob('*.sql')):
        projections = analyser_fichier(fichier)
        with open(fichier, encoding='utf-8', newline='') as flux:
            lignes = flux.read().splitlines(keepends=True)
        remplacements = []

        for p in projections:
            valeur = ('NULL' if p['type_valeur_defaut'] == 'NULL_EXPLICITE'
                      else p['valeur_par_defaut'])
            cle = (p['table_cible'], p['colonne'], valeur)
            if cle not in inventaire:
                continue

            table_courte = p['table_cible'].split('.', 1)[1]
            cast = casts.get((table_courte, p['colonne']), '')

            # Variante du module si le seed en a cree une (valeurs divergentes entre
            # modules sur la meme cle), sinon STANDARD.
            variante = (variante_module
                        if (p['table_cible'], p['colonne'], variante_module) in seed
                        else 'STANDARD')
            seedee = seed.get((p['table_cible'], p['colonne'], variante))
            if seedee is None:
                absentes.append(f"{p['table_cible']}.{p['colonne']} (aucune ligne seedee)")
            else:
                type_seed, valeur_seed = seedee
                attendu = None if p['type_valeur_defaut'] == 'NULL_EXPLICITE' else valeur
                obtenu = None if type_seed == 'NULL' else valeur_seed
                if attendu != obtenu:
                    divergences.append(
                        f"{fichier.name}:{p['ligne_projection']} {p['table_cible']}.{p['colonne']}"
                        f" [{variante}] litteral={attendu!r} != seed={obtenu!r}")
                    continue

            arg_variante = '' if variante == 'STANDARD' else f", '{variante}'"
            appel = (f"public.get_default_value('{p['table_cible']}', '{p['colonne']}', "
                     f"{repli_sql(p['type_valeur_defaut'], valeur)}{arg_variante}){cast}")
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
                with open(fichier, 'w', encoding='utf-8', newline='') as flux:
                    flux.write(''.join(lignes))

    print(f"Module {dossier.name} : {total} remplacements"
          f"{' (simulation)' if dry_run else ''}, {ignores} lignes A_ARBITRER ignorees")
    for nom, n in sorted(par_fichier.items()):
        print(f"   {n:4d}  {nom}")
    if absentes:
        print(f"   {len(absentes)} cle(s) sans ligne dans le seed (repli code en dur utilise) :")
        for cle in sorted(set(absentes)):
            print(f"      {cle}")
    for anomalie in sans_cast_connu:
        print(f"   ANOMALIE {anomalie}", file=sys.stderr)
    for divergence in divergences:
        print(f"   DIVERGENCE (non reecrite) {divergence}", file=sys.stderr)
    return 1 if divergences else 0


def main():
    sys.stdout.reconfigure(encoding='utf-8')
    parseur = argparse.ArgumentParser(description=__doc__)
    parseur.add_argument('dossier')
    parseur.add_argument('--dry-run', action='store_true',
                         help="compte les remplacements sans ecrire les fichiers")
    parseur.add_argument('--types', help="fichier TSV de types (defaut : sql/config/types_colonnes_cibles.tsv)")
    parseur.add_argument('--seed', action='append',
                         help="migration de seed a lire (defaut : migrations/031 + 032)")
    args = parseur.parse_args()
    return traiter(Path(args.dossier), args.dry_run, args.types, args.seed)


if __name__ == '__main__':
    sys.exit(main())
