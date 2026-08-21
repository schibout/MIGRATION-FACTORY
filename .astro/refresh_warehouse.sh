#!/usr/bin/env bash
# Regenerate .astro/warehouse.md from the live database.
# Usage:  ./.astro/refresh_warehouse.sh
# Reads DB_HOST / DB_PORT / DB_USER / DB_PASSWORD / DB_NAME from ../.env.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
set -a; . ./.env; set +a
export PGPASSWORD="$DB_PASSWORD"

DUMP="$(mktemp -d)"
trap 'rm -rf "$DUMP"' EXIT
P=(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -tA -F'|' -v ON_ERROR_STOP=1)
SCHEMAS="'raw_data','clean_data','public','snapshots'"
# strip newlines and the field separator out of every free-text column
CLEAN="regexp_replace(replace(coalesce(%s,''),'|','/'),'[\r\n]+',' ','g')"

echo "-> database identity"
"${P[@]}" -c "SELECT current_database(),
       split_part(version(),' on ',1),
       pg_size_pretty(pg_database_size(current_database())),
       coalesce(host(inet_server_addr()),'localhost')||':'||coalesce(inet_server_port()::text,'5432');" > "$DUMP/dbinfo.psv"

echo "-> tables"
"${P[@]}" -c "
SELECT n.nspname, c.relname, c.relkind,
       CASE WHEN c.reltuples < 0 THEN NULL ELSE c.reltuples::bigint END,
       pg_total_relation_size(c.oid),
       $(printf "$CLEAN" "obj_description(c.oid,'pg_class')")
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname IN ($SCHEMAS) AND c.relkind IN ('r','p','v','m')
ORDER BY 1,2;" > "$DUMP/tables.psv"

echo "-> exact counts for never-analyzed tables"
Q=$(awk -F'|' 'BEGIN{n=0} $4=="" && ($3=="r"||$3=="p"){n++;
     printf "%sSELECT '\''%s.%s'\'' AS t, count(*)::bigint AS c FROM %s.%s",
       (n>1?" UNION ALL ":""), $1,$2,$1,$2}' "$DUMP/tables.psv")
if [ -n "$Q" ]; then "${P[@]}" -c "$Q" > "$DUMP/exact_counts.psv"; else : > "$DUMP/exact_counts.psv"; fi

echo "-> columns"
"${P[@]}" -c "
SELECT c.table_schema, c.table_name, c.ordinal_position, c.column_name,
       CASE WHEN c.data_type='character varying'
              THEN 'varchar('||coalesce(c.character_maximum_length::text,'')||')'
            WHEN c.data_type='numeric'
              THEN 'numeric('||coalesce(c.numeric_precision::text,'')||','||coalesce(c.numeric_scale::text,'')||')'
            ELSE c.data_type END,
       c.is_nullable,
       $(printf "$CLEAN" "col_description(fc.oid, c.ordinal_position)")
FROM information_schema.columns c
JOIN pg_class fc ON fc.relname = c.table_name
JOIN pg_namespace fn ON fn.oid = fc.relnamespace AND fn.nspname = c.table_schema
WHERE c.table_schema IN ($SCHEMAS)
ORDER BY 1,2,3;" > "$DUMP/columns.psv"

echo "-> constraints and unique indexes"
"${P[@]}" -c "
SELECT n.nspname, t.relname, con.contype,
       (SELECT string_agg(a.attname, ',' ORDER BY x.ord)
          FROM unnest(con.conkey) WITH ORDINALITY AS x(attnum, ord)
          JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = x.attnum),
       coalesce(fn.nspname||'.'||ft.relname,''),
       coalesce((SELECT string_agg(a.attname, ',' ORDER BY x.ord)
          FROM unnest(con.confkey) WITH ORDINALITY AS x(attnum, ord)
          JOIN pg_attribute a ON a.attrelid = ft.oid AND a.attnum = x.attnum),'')
FROM pg_constraint con
JOIN pg_class t ON t.oid = con.conrelid
JOIN pg_namespace n ON n.oid = t.relnamespace
LEFT JOIN pg_class ft ON ft.oid = con.confrelid
LEFT JOIN pg_namespace fn ON fn.oid = ft.relnamespace
WHERE con.contype IN ('p','f','u') AND n.nspname IN ($SCHEMAS)
ORDER BY 1,2,3;" > "$DUMP/constraints.psv"

"${P[@]}" -c "
SELECT n.nspname, t.relname,
       (SELECT string_agg(a.attname, ',' ORDER BY x.ord)
          FROM unnest(i.indkey::int[]) WITH ORDINALITY AS x(attnum, ord)
          JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = x.attnum)
FROM pg_index i
JOIN pg_class t ON t.oid = i.indrelid
JOIN pg_namespace n ON n.oid = t.relnamespace
WHERE i.indisunique AND NOT i.indisprimary AND i.indpred IS NULL
  AND n.nspname IN ($SCHEMAS)
ORDER BY 1,2;" > "$DUMP/uniq_idx.psv"

echo "-> SAP DDIC dictionary"
"${P[@]}" -c "SELECT lower(table_name), $(printf "$CLEAN" description)
              FROM public.sap_table_properties ORDER BY 1;" > "$DUMP/sap_desc.psv"
"${P[@]}" -c "SELECT lower(table_name), string_agg(lower(field_name), ',' ORDER BY position)
              FROM public.sap_table_fields WHERE key_flag GROUP BY 1 ORDER BY 1;" > "$DUMP/sap_keys.psv"
"${P[@]}" -c "SELECT lower(table_name)||'.'||lower(field_name), $(printf "$CLEAN" "nullif(field_text,'')")
              FROM public.sap_table_fields
              WHERE coalesce(nullif(field_text,''), header_text, '') <> '';" > "$DUMP/sap_fields.psv"
"${P[@]}" -c "
SELECT lower(table_name), lower(field_name), lower(check_table)
FROM public.sap_table_fields
WHERE coalesce(check_table,'') <> ''
  AND lower(check_table) IN (SELECT lower(relname) FROM pg_class c
        JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='raw_data')
  AND lower(table_name) IN (SELECT lower(relname) FROM pg_class c
        JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='raw_data')
ORDER BY 1,2;" > "$DUMP/sap_fk.psv"

echo "-> IFS spec catalog"
# The Lot*.xlsx sources contain a few duplicated / shifted rows: keep the
# uppercase FIELD_NAME variant with the lowest sort_order.
"${P[@]}" -c "
SELECT DISTINCT ON (lower(entity), lower(field_name))
       lower(entity)||'.'||lower(field_name), $(printf "$CLEAN" field_label_fr)
FROM public.ifs_field_catalog WHERE coalesce(field_label_fr,'') <> ''
ORDER BY lower(entity), lower(field_name), (field_name = upper(field_name)) DESC, sort_order;" > "$DUMP/ifs_labels.psv"
"${P[@]}" -c "
SELECT lower(entity), string_agg(f, ',' ORDER BY so) FROM (
  SELECT DISTINCT ON (lower(entity), lower(field_name))
         entity, lower(field_name) f, sort_order so, primary_key
  FROM public.ifs_field_catalog
  ORDER BY lower(entity), lower(field_name), (field_name = upper(field_name)) DESC, sort_order
) x WHERE primary_key GROUP BY 1 ORDER BY 1;" > "$DUMP/ifs_keys.psv"

echo "-> ETL catalog and AI domain routing"
"${P[@]}" -c "SELECT category, table_schema, table_name, display_name, $(printf "$CLEAN" description), is_active
              FROM public.etl_export_queries ORDER BY category, display_name;" > "$DUMP/export_queries.psv"
"${P[@]}" -c "SELECT domaine_fonctionnel, table_name, display_name, $(printf "$CLEAN" description)
              FROM public.etl_extraction_queries ORDER BY 1,2;" > "$DUMP/extraction_queries.psv"
"${P[@]}" -c "SELECT domain_id, replace(replace(keywords::text,'\"',''),'|','/'),
                     replace(replace(tables::text,'\"',''),'|','/')
              FROM public.ai_domain_tables WHERE actif ORDER BY position;" > "$DUMP/domains.psv"

echo "-> categorical value families (from planner stats)"
"${P[@]}" -c "
SELECT schemaname, tablename, attname, n_distinct::text,
       array_to_string(most_common_vals::text::text[], ', ')
FROM pg_stats
WHERE schemaname IN ($SCHEMAS) AND n_distinct BETWEEN 2 AND 30
  AND most_common_vals IS NOT NULL AND attname <> 'mandt'
  AND attname ~ '(type|status|statut|categor|role|state|etat|nature|flag|mode|kind|source|level|priorit|direction)'
ORDER BY 1,2,3;" > "$DUMP/categoricals2.psv"

python3 "$ROOT/.astro/warehouse_gen.py" "$DUMP" "$ROOT/.astro/warehouse.md"
