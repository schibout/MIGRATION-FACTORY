#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Chargement initial des contrats d'interface dans Migration Factory.

Reprend le classeur fige (par defaut
sql/supplier/contrat_interface_SAP_IFS_Supplier.xlsx) vers les tables
public.interface_contract_* creees par les migrations 051 / 052.

Le script est IDEMPOTENT : il fait un UPSERT sur les cles naturelles
  - interface_contract_table  : (module, table_cible)
  - interface_contract_column : (contract_table_id, target_column)
et ne reecrit une ligne QUE si sa definition a reellement change. C'est
indispensable : le trigger sur updated_at sert au calcul d'obsolescence des
validations metier, une reecriture a l'identique invaliderait tout le travail
de relecture deja fait.

Apres ce chargement initial, la BASE est la source de verite : les corrections
se font dans l'ecran « Contrats d'interface ». Le script ne sert plus qu'a
amorcer un nouveau module.

Usage :
    python scripts/seed_interface_contracts.py [classeur.xlsx] [--module supplier]
                                               [--dry-run]
"""

import argparse
import os
import re
import sys

import psycopg2
import psycopg2.extras

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(BASE_DIR, 'backend'))

from services.interface_contract_excel import parse_contract_workbook  # noqa: E402

CLASSEUR_DEFAUT = os.path.join(BASE_DIR, 'sql', 'supplier',
                               'contrat_interface_SAP_IFS_Supplier.xlsx')

DB = dict(
    host=os.getenv('DB_HOST', '10.190.100.58'),
    port=os.getenv('DB_PORT', '5432'),
    dbname=os.getenv('DB_NAME', 'sap_migration_db'),
    user=os.getenv('DB_USER', 'postgres'),
    password=os.getenv('DB_PASSWORD', 'trimet2025'),
)

SCHEMAS_SOURCE = ('raw_data', 'clean_data')

# Cle naturelle d'une ligne de contrat (cf. migration 052 §4) : la section en
# fait partie, un onglet pouvant documenter deux fois la meme colonne cible
# quand le chargement se fait en plusieurs etapes.
CLE_NATURELLE = ('contract_table_id', 'section', 'target_column')

# Champs de definition compares pour decider s'il faut vraiment reecrire
CHAMPS_DEFINITION = (
    'field_label', 'systeme_source', 'source_schema', 'source_table',
    'source_column', 'source_expression', 'transformation_rule',
    'condition_application', 'exemple_valeur', 'row_type', 'default_value_column',
    'default_value_variante', 'sort_order',
)


# ---------------------------------------------------------------------------
# Resolution de la source structuree
# ---------------------------------------------------------------------------
def charger_catalogue(cur):
    """{(schema, table): {colonnes}} pour raw_data et clean_data."""
    cur.execute(
        """
        SELECT table_schema, table_name, column_name
        FROM information_schema.columns
        WHERE table_schema = ANY(%s)
        """,
        (list(SCHEMAS_SOURCE),),
    )
    catalogue = {}
    for schema, table, colonne in cur.fetchall():
        catalogue.setdefault((schema, table), set()).add(colonne)
    return catalogue


def resoudre_source(expression, catalogue):
    """Extrait (schema, table, colonne) de la premiere reference du texte libre
    « Champ / Table source » qui correspond a une VRAIE colonne de la base.

    On ne devine rien : les alias du classeur ('sf.denomination_sociale') qui
    ne correspondent a aucune table reelle sont laisses a NULL — la source
    structuree ne sert qu'a l'apercu de donnees et a l'analyse d'impact, une
    valeur fausse y serait pire que pas de valeur.
    """
    if not expression:
        return None, None, None

    # 1. reference qualifiee schema.table.colonne
    for schema, table, colonne in re.findall(r'\b(\w+)\.(\w+)\.(\w+)\b', expression):
        if colonne in catalogue.get((schema, table), ()):
            return schema, table, colonne

    # 2. reference table.colonne, le schema est deduit du catalogue
    for table, colonne in re.findall(r'\b(\w+)\.(\w+)\b', expression):
        for schema in SCHEMAS_SOURCE:
            if colonne in catalogue.get((schema, table), ()):
                return schema, table, colonne
    return None, None, None


# ---------------------------------------------------------------------------
# Upsert
# ---------------------------------------------------------------------------
def upsert_table(cur, table):
    cur.execute(
        """
        INSERT INTO public.interface_contract_table
            (module, schema_cible, table_cible, libelle, description,
             source_procedure, ordre)
        VALUES (%(module)s, %(schema_cible)s, %(table_cible)s, %(libelle)s,
                %(description)s, %(source_procedure)s, %(ordre)s)
        ON CONFLICT (module, table_cible) DO UPDATE
           SET schema_cible     = EXCLUDED.schema_cible,
               libelle          = EXCLUDED.libelle,
               description      = EXCLUDED.description,
               source_procedure = EXCLUDED.source_procedure,
               ordre            = EXCLUDED.ordre
         WHERE (public.interface_contract_table.schema_cible,
                public.interface_contract_table.libelle,
                public.interface_contract_table.description,
                public.interface_contract_table.source_procedure,
                public.interface_contract_table.ordre)
            IS DISTINCT FROM
               (EXCLUDED.schema_cible, EXCLUDED.libelle, EXCLUDED.description,
                EXCLUDED.source_procedure, EXCLUDED.ordre)
        RETURNING id
        """,
        table,
    )
    row = cur.fetchone()
    if row:
        return row[0], True
    cur.execute(
        'SELECT id FROM public.interface_contract_table '
        'WHERE module = %s AND table_cible = %s',
        (table['module'], table['table_cible']),
    )
    return cur.fetchone()[0], False


def upsert_colonne(cur, contract_table_id, ligne):
    params = {'contract_table_id': contract_table_id,
              'section': ligne.get('section'),
              'target_column': ligne['target_column']}
    params.update({champ: ligne.get(champ) for champ in CHAMPS_DEFINITION})
    params.setdefault('row_type', 'COLUMN')

    champs_sql = ', '.join(CHAMPS_DEFINITION)
    valeurs_sql = ', '.join('%%(%s)s' % champ for champ in CHAMPS_DEFINITION)
    set_sql = ', '.join('%s = EXCLUDED.%s' % (champ, champ) for champ in CHAMPS_DEFINITION)
    actuel_sql = ', '.join('public.interface_contract_column.%s' % c for c in CHAMPS_DEFINITION)
    nouveau_sql = ', '.join('EXCLUDED.%s' % c for c in CHAMPS_DEFINITION)

    cur.execute(
        """
        INSERT INTO public.interface_contract_column
            (contract_table_id, section, target_column, {champs})
        VALUES (%(contract_table_id)s, %(section)s, %(target_column)s, {valeurs})
        ON CONFLICT (contract_table_id, COALESCE(section, ''), target_column) DO UPDATE
           SET {sets}
         WHERE ({actuel}) IS DISTINCT FROM ({nouveau})
        RETURNING id, (xmax = 0) AS creee
        """.format(champs=champs_sql, valeurs=valeurs_sql, sets=set_sql,
                   actuel=actuel_sql, nouveau=nouveau_sql),
        params,
    )
    row = cur.fetchone()
    if row:
        return row[0], 'creee' if row[1] else 'modifiee'
    cur.execute(
        """SELECT id FROM public.interface_contract_column
            WHERE contract_table_id = %s
              AND COALESCE(section, '') = COALESCE(%s, '')
              AND target_column = %s""",
        (contract_table_id, ligne.get('section'), ligne['target_column']),
    )
    return cur.fetchone()[0], 'inchangee'


def upsert_validation(cur, colonne_id, validation, auteur):
    """Reprend une validation deja portee par le classeur (colonnes jaunes)."""
    statut = validation.get('statut') or 'A_VALIDER'
    cur.execute(
        """
        INSERT INTO public.interface_contract_validation
            (contract_column_id, statut, remarque_metier, validated_by, validated_at)
        VALUES (%s, %s, %s, %s, CURRENT_TIMESTAMP)
        ON CONFLICT (contract_column_id) DO UPDATE
           SET statut          = EXCLUDED.statut,
               remarque_metier = EXCLUDED.remarque_metier,
               validated_by    = EXCLUDED.validated_by,
               validated_at    = EXCLUDED.validated_at
        """,
        (colonne_id, statut, validation.get('remarque_metier'), auteur),
    )
    cur.execute(
        """
        INSERT INTO public.interface_contract_event
            (contract_column_id, event_type, nouveau_statut, commentaire, auteur)
        VALUES (%s, 'IMPORT_EXCEL', %s, %s, %s)
        """,
        (colonne_id, statut, validation.get('remarque_metier'), auteur),
    )


# ---------------------------------------------------------------------------
def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('classeur', nargs='?', default=CLASSEUR_DEFAUT)
    parser.add_argument('--module', default='supplier')
    parser.add_argument('--auteur', default='seed')
    parser.add_argument('--dry-run', action='store_true',
                        help='analyse le classeur sans rien ecrire')
    args = parser.parse_args()

    if not os.path.exists(args.classeur):
        parser.error('classeur introuvable : %s' % args.classeur)

    tables = parse_contract_workbook(args.classeur, module=args.module)
    print('Classeur : %s' % args.classeur)
    print('%d onglets table, %d lignes de contrat'
          % (len(tables), sum(len(t['rows']) for t in tables)))

    conn = psycopg2.connect(**DB)
    conn.autocommit = False
    try:
        cur = conn.cursor()
        catalogue = charger_catalogue(cur)

        total = {'creee': 0, 'modifiee': 0, 'inchangee': 0}
        sans_source = 0
        for table in tables:
            table_id, table_modifiee = upsert_table(cur, table)
            for ligne in table['rows']:
                if ligne['row_type'] in ('COLUMN', 'CONFIG_SUMMARY'):
                    schema, src_table, colonne = resoudre_source(
                        ligne.get('source_expression'), catalogue)
                    ligne['source_schema'] = schema
                    ligne['source_table'] = src_table
                    ligne['source_column'] = colonne
                    if ligne['row_type'] == 'COLUMN' and not src_table:
                        sans_source += 1
                colonne_id, etat = upsert_colonne(cur, table_id, ligne)
                total[etat] += 1
                if ligne.get('validation'):
                    upsert_validation(cur, colonne_id, ligne['validation'], args.auteur)
            print('  %-34s -> id %-4s %s (%d lignes)'
                  % (table['table_cible'], table_id,
                     'maj' if table_modifiee else '  ', len(table['rows'])))

        # Lignes presentes en base mais absentes du classeur : on ne supprime
        # rien (la base est la source de verite apres le seed), on signale.
        cur.execute(
            """
            SELECT t.table_cible, c.section, c.target_column
            FROM public.interface_contract_column c
            JOIN public.interface_contract_table t ON t.id = c.contract_table_id
            WHERE t.module = %s
            """,
            (args.module,),
        )
        connues = {(t['table_cible'], r.get('section'), r['target_column'])
                   for t in tables for r in t['rows']}
        orphelines = [r for r in cur.fetchall() if tuple(r) not in connues]

        if args.dry_run:
            conn.rollback()
            print('\n[dry-run] aucune ecriture')
        else:
            conn.commit()

        print('\nColonnes : %d creees, %d modifiees, %d inchangees'
              % (total['creee'], total['modifiee'], total['inchangee']))
        print('Source structuree non resolue (texte libre / alias) : %d lignes' % sans_source)
        if orphelines:
            print('En base mais absentes du classeur (non supprimees) : %d'
                  % len(orphelines))
            for table_cible, section, target in orphelines[:20]:
                print('  %s.%s [%s]' % (table_cible, target, section or ''))
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


if __name__ == '__main__':
    main()
