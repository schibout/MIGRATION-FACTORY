#!/usr/bin/env python3
"""
spec2catalog.py — migration-Factory
Parse un classeur de spec IFS (Lot*.xlsx) et génère :
  1. INSERTs vers public.ifs_field_catalog (le référentiel de métadonnées)
  2. DDL clean_data conforme aux conventions du projet
  3. Squelette de règles de gestion (mandatory, defaults, enums, refs)
Usage : python3 spec2catalog.py <fichier.xlsx> <lot_id> <out_dir>
"""
import sys, re, json
import pandas as pd
from pathlib import Path

TYPE_MAP = {  # conventions clean_data
    'VARCHAR2': lambda l: f"VARCHAR({int(l)})" if l and int(l) > 0 else "VARCHAR(4000)",
    'NUMBER':   lambda l: f"NUMERIC({int(l)},0)" if l else "NUMERIC",
    'DATE':     lambda l: "DATE",
    'CLOB':     lambda l: "TEXT",
}

def parse_enum(raw):
    """'(DB-values <==> Client-values)\\nBASELINE <==> Baseline,...' -> [{db,client}]"""
    if not isinstance(raw, str) or '<==>' not in raw:
        return None
    pairs = []
    for line in raw.splitlines():
        if '<==>' in line and not line.startswith('(DB-values'):
            db, _, client = line.partition('<==>')
            pairs.append({'db': db.strip().rstrip(','), 'client': client.strip().rstrip(',')})
    return pairs or None

def main(xlsx, lot_id, out_dir):
    out = Path(out_dir); out.mkdir(parents=True, exist_ok=True)
    xl = pd.ExcelFile(xlsx)
    defs = pd.read_excel(xl, sheet_name='Migration Object Definitions')
    entities = defs[defs['IN_SCOPE'].astype(str).str.upper() == 'YES']['TARGET_ID'].tolist()
    entities = [e for e in entities if e in xl.sheet_names]

    catalog_rows, ddl_files, rules = [], [], {}
    for ent in entities:
        df = pd.read_excel(xl, sheet_name=ent)
        df = df[df['FIELD_NAME'].notna()]
        cols_sql, ent_rules = [], []
        for _, r in df.iterrows():
            fname = str(r['FIELD_NAME']).strip()
            if not re.match(r'^[A-Z][A-Z0-9_]*$', fname):
                continue  # lignes de bruit / sample data
            dtype = str(r.get('DATA_TYPE') or '').strip().upper()
            dlen  = r.get('DATA_LENGTH')
            in_scope = str(r.get('IN_SCOPE') or '').strip().upper() == 'YES'
            sqltype = TYPE_MAP.get(dtype, lambda l: "VARCHAR(4000)")(dlen if pd.notna(dlen) else None)
            col_sql = f"    {fname.lower():<32} {sqltype}"
            cols_sql.append(col_sql if in_scope else f"    -- {fname.lower():<29} {sqltype}  -- IN_SCOPE=NO")
            enum = parse_enum(r.get('ENUMERATION_VALUES'))
            catalog_rows.append({
                'lot_id': lot_id, 'entity': ent, 'field_name': fname,
                'field_label_fr': r.get('FIELD_LABEL_FR'),
                'data_type': dtype, 'data_length': int(dlen) if pd.notna(dlen) else None,
                'sql_type': sqltype,
                'mandatory': str(r.get('MANDATORY')).upper() == 'TRUE',
                'primary_key': str(r.get('PRIMARY_KEY')).upper() == 'TRUE',
                'insertable': str(r.get('INSERTABLE')).upper() == 'TRUE',
                'updatable': str(r.get('UPDATABLE')).upper() == 'TRUE',
                'lov': str(r.get('LOV')).upper() == 'TRUE',
                'default_value': None if pd.isna(r.get('DEFAULT_VALUE')) else str(r.get('DEFAULT_VALUE')),
                'reference': None if pd.isna(r.get('REFERENCE')) else str(r.get('REFERENCE')),
                'enumeration_values': enum,
                'rnd_flags': None if pd.isna(r.get('RND_FLAGS')) else str(r.get('RND_FLAGS')),
                'in_scope': in_scope,
                'transformation_rules': None if pd.isna(r.get('TRANSFORMATION_RULES')) else str(r.get('TRANSFORMATION_RULES')),
                'comments': None if pd.isna(r.get('COMMENTS')) else str(r.get('COMMENTS')),
                'sort_order': None if pd.isna(r.get('SORT_ORDER')) else int(r.get('SORT_ORDER')),
            })
            # règles de gestion dérivées
            if str(r.get('MANDATORY')).upper() == 'TRUE' and in_scope:
                ent_rules.append({'field': fname, 'rule': 'NOT_NULL_ON_LOAD'})
            if pd.notna(r.get('DEFAULT_VALUE')):
                ent_rules.append({'field': fname, 'rule': 'DEFAULT', 'value': str(r['DEFAULT_VALUE'])})
            if enum:
                ent_rules.append({'field': fname, 'rule': 'ENUM_DB_VALUES', 'allowed': [p['db'] for p in enum]})
            if pd.notna(r.get('REFERENCE')):
                ent_rules.append({'field': fname, 'rule': 'FK_LOGICAL', 'target': str(r['REFERENCE'])})
        # DDL
        ddl = (f"-- Genere par spec2catalog.py depuis {Path(xlsx).name} / feuille {ent}\n"
               f"CREATE TABLE IF NOT EXISTS clean_data.{ent.lower()} (\n"
               + ",\n".join(c for c in cols_sql if not c.lstrip().startswith('--'))
               + ("\n" if not any(c.lstrip().startswith('--') for c in cols_sql) else ",\n")
               + "\n".join(c for c in cols_sql if c.lstrip().startswith('--'))
               + "\n);\n")
        # fix trailing comma before comments block
        ddl = re.sub(r',\n((?:    --.*\n?)+)\);', r'\n\1);', ddl)
        p = out / f"clean_data_{ent.lower()}.sql"
        p.write_text(ddl, encoding='utf-8')
        ddl_files.append(str(p))
        rules[ent] = ent_rules

    # catalog inserts
    cat_sql = ["-- Chargement public.ifs_field_catalog"]
    for c in catalog_rows:
        vals = []
        for k in ['lot_id','entity','field_name','field_label_fr','data_type','data_length','sql_type',
                  'mandatory','primary_key','insertable','updatable','lov','default_value','reference',
                  'enumeration_values','rnd_flags','in_scope','transformation_rules','comments','sort_order']:
            v = c[k]
            if v is None or (isinstance(v, float) and pd.isna(v)): vals.append('NULL')
            elif isinstance(v, bool): vals.append('TRUE' if v else 'FALSE')
            elif isinstance(v, int): vals.append(str(v))
            elif isinstance(v, list): vals.append("'" + json.dumps(v, ensure_ascii=False).replace("'", "''") + "'::jsonb")
            else: vals.append("'" + str(v).replace("'", "''") + "'")
        cat_sql.append("INSERT INTO public.ifs_field_catalog (lot_id, entity, field_name, field_label_fr, data_type, data_length, sql_type, mandatory, primary_key, insertable, updatable, lov, default_value, reference, enumeration_values, rnd_flags, in_scope, transformation_rules, comments, sort_order)\nVALUES (" + ", ".join(vals) + ")\nON CONFLICT ON CONSTRAINT uq_ifs_field_catalog DO UPDATE SET\n  field_label_fr=EXCLUDED.field_label_fr, data_type=EXCLUDED.data_type, data_length=EXCLUDED.data_length, sql_type=EXCLUDED.sql_type, mandatory=EXCLUDED.mandatory, primary_key=EXCLUDED.primary_key, insertable=EXCLUDED.insertable, updatable=EXCLUDED.updatable, lov=EXCLUDED.lov, default_value=EXCLUDED.default_value, reference=EXCLUDED.reference, enumeration_values=EXCLUDED.enumeration_values, rnd_flags=EXCLUDED.rnd_flags, in_scope=EXCLUDED.in_scope, transformation_rules=EXCLUDED.transformation_rules, comments=EXCLUDED.comments, sort_order=EXCLUDED.sort_order;")
    (out / f"load_catalog_{lot_id}.sql").write_text("\n".join(cat_sql), encoding='utf-8')
    (out / f"rules_{lot_id}.json").write_text(json.dumps(rules, ensure_ascii=False, indent=2), encoding='utf-8')
    print(f"Entités traitées : {len(entities)}")
    print(f"Champs catalogués : {len(catalog_rows)}")
    print(f"DDL générés : {len(ddl_files)}")

if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2], sys.argv[3])
