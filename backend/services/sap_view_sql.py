"""
Generation du CREATE VIEW PostgreSQL d'une vue SAP a partir du dictionnaire DDIC
extrait dans raw_data : dd26s (tables de base), dd27s (champs), dd28s (conditions).

Fonction pure (aucun acces base) : l'appelant fournit les lignes DDIC et la liste des
colonnes reellement presentes dans raw_data. Les vues SAP ECC (classe D) ne sont que des
jointures internes ; dd28s porte les jointures en paires de lignes JL/JR et les filtres
(negation NOT, operateur, constante) chaines par and_or, les OR se groupant entre eux.
"""

TARGET_SCHEMA = 'sap_view'
SOURCE_SCHEMA = 'raw_data'

_OPS = {'EQ': '=', 'NE': '<>', 'GT': '>', 'GE': '>=', 'LT': '<', 'LE': '<=', 'LK': 'LIKE'}
_NUMERIC = {'numeric', 'integer', 'bigint', 'smallint', 'double precision', 'real'}
_DATES = {'date', 'timestamp without time zone', 'timestamp with time zone'}


def qi(name: str) -> str:
    """Identifiant PostgreSQL toujours quote (les noms SAP peuvent contenir '/')."""
    return '"' + name.strip().lower().replace('"', '""') + '"'


def _literal(constant: str):
    """Constante SAP -> litteral SQL texte, ou None si non traduisible."""
    c = (constant or '').strip()
    up = c.upper()
    if up in ('SY-LANGU', 'SYST-LANGU'):
        return "'F'"
    if up in ('SY-DATUM', 'SYST-DATUM'):
        return "to_char(current_date, 'YYYYMMDD')"
    if up == 'SPACE':
        return "''"
    if len(c) >= 2 and c[0] == "'" and c[-1] == "'":
        return "'" + c[1:-1].replace("''", "'").strip().replace("'", "''") + "'"
    if c.lstrip('-').isdigit():
        return "'" + c + "'"
    return None  # champ d'une autre table (T500P-MOLGA), variable systeme exotique...


def build_view_sql(view: str, tables, fields, conds, columns) -> dict:
    """
    view    : nom SAP de la vue (IFLO)
    tables  : noms des tables de base, ordre dd26s.tabpos
    fields  : [{'viewfield', 'tabname', 'fieldname'}], ordre dd27s.objpos
    conds   : [{'tabname', 'fieldname', 'negation', 'operator', 'constants', 'and_or'}], ordre dd28s.position
    columns : {table_minuscule: {colonne_minuscule: data_type}} pour les tables presentes dans raw_data
    Retourne {'sql', 'warnings', 'blocking', 'joins', 'filters'} ; 'sql' vaut None si bloquant.
    """
    warnings, blocking = [], []

    missing = [t for t in tables if t.lower() not in columns]
    if not tables:
        blocking.append('Aucune table de base dans dd26s')
    if missing:
        blocking.append('Tables absentes de raw_data : ' + ', '.join(missing))

    def col(tab, field):
        cols = columns.get((tab or '').lower())
        f = (field or '').strip().lower()
        if cols is None or f not in cols:
            return None, None
        return f'{qi(tab)}.{qi(f)}', cols[f]

    # --- separation jointures (paires JL/JR) / filtres
    joins, filters, i = [], [], 0
    while i < len(conds):
        r = conds[i]
        if r.get('negation') == 'JL' and i + 1 < len(conds) and conds[i + 1].get('negation') == 'JR':
            joins.append((r, conds[i + 1]))
            i += 2
        else:
            filters.append(r)
            i += 1

    # --- jointures -> (table gauche, table droite, expression)
    join_exprs = []
    for left, right in joins:
        le, lt = col(left['tabname'], left['fieldname'])
        re_, rt = col(right['tabname'], right['fieldname'])
        label = f"{left['tabname']}.{left['fieldname']} = {right['tabname']}.{right['fieldname']}"
        if le is None or re_ is None:
            if 'MANDT' in (left['fieldname'].strip().upper(), right['fieldname'].strip().upper()):
                warnings.append(f'Jointure sur le mandant ignoree (colonne absente) : {label}')
            elif not missing:
                blocking.append(f'Colonne de jointure absente de raw_data : {label}')
            continue
        if (lt in _NUMERIC) != (rt in _NUMERIC) or (lt in _DATES) != (rt in _DATES):
            le, re_ = f'{le}::text', f'{re_}::text'
        join_exprs.append((left['tabname'].lower(), right['tabname'].lower(), f'{le} = {re_}'))

    # --- filtres : groupes de OR relies par AND
    def filter_expr(r):
        e, typ = col(r['tabname'], r['fieldname'])
        label = f"{r['tabname']}.{r['fieldname']} {r.get('operator')} {r.get('constants')}"
        op = _OPS.get((r.get('operator') or '').strip())
        lit = _literal(r.get('constants'))
        if e is None:
            warnings.append(f'Condition ignoree, colonne absente de raw_data : {label}')
            return None
        if op is None or lit is None:
            warnings.append(f'Condition ignoree, non traduisible : {label}')
            return None
        if typ in _NUMERIC:
            expr = f"COALESCE({e}, 0) {op} COALESCE(NULLIF({lit}, '')::numeric, 0)"
        elif typ in _DATES:
            expr = f"COALESCE(to_char({e}, 'YYYYMMDD'), '') {op} {lit}"
        else:
            expr = f"COALESCE(TRIM({e}::text), '') {op} {lit}"
        return f'NOT ({expr})' if (r.get('negation') or '').strip() == 'NOT' else expr

    groups, current = [], []
    for r in filters:
        expr = filter_expr(r)
        if expr:
            current.append(expr)
        if (r.get('and_or') or '').strip() != 'OR':
            if current:
                groups.append(current)
            current = []
    if current:
        groups.append(current)
    where = ['(' + ' OR '.join(g) + ')' if len(g) > 1 else g[0] for g in groups]

    # --- liste de selection ('*' et '-' sont des marqueurs SAP, pas des colonnes)
    select, seen = [], set()
    for f in fields:
        vf = (f.get('viewfield') or '').strip()
        if not vf or vf in ('*', '-') or vf.lower() in seen:
            continue
        seen.add(vf.lower())
        e, _ = col(f['tabname'], f['fieldname'])
        if e is None:
            warnings.append(f"Champ absent de raw_data, expose a NULL : {f['tabname']}.{f['fieldname']}")
            e = 'NULL::text'
        select.append(f'{e} AS {qi(vf)}')
    if not select:
        blocking.append('Aucun champ exploitable dans dd27s')

    result = {
        'warnings': warnings,
        'blocking': blocking,
        'joins': [j[2] for j in join_exprs],
        'filters': where,
        'sql': None,
    }
    if blocking:
        return result

    # --- FROM : chaque table rejoint avec les conditions qui la relient aux precedentes
    first = tables[0].lower()
    joined, pending = {first}, list(join_exprs)
    lines = [f'FROM {SOURCE_SCHEMA}.{qi(first)} AS {qi(first)}']
    for t in tables[1:]:
        t = t.lower()
        on = [p for p in pending if t in (p[0], p[1]) and {p[0], p[1]} <= joined | {t}]
        pending = [p for p in pending if p not in on]
        joined.add(t)
        if not on:
            warnings.append(f'Table {t.upper()} sans condition de jointure : produit cartesien')
        cond = '\n     AND '.join(p[2] for p in on) or 'TRUE'
        lines.append(f'JOIN {SOURCE_SCHEMA}.{qi(t)} AS {qi(t)}\n      ON {cond}')
    where = [p[2] for p in pending] + where

    target = f'{TARGET_SCHEMA}.{qi(view)}'
    result['sql'] = (
        f'DROP VIEW IF EXISTS {target};\n'
        f'CREATE VIEW {target} AS\nSELECT ' + ',\n       '.join(select) + '\n'
        + '\n'.join(lines)
        + ('\nWHERE ' + '\n  AND '.join(where) if where else '')
        + ';'
    )
    return result
