# Tables SAP pour les opérations de maintenance — comparaison SAP vs raw_data

Quand l'utilisateur demande de vérifier les tables d'opérations de maintenance, ne pas se limiter à `raw_data` ni à la config API. Comparer trois niveaux :

1. API SAP Extraction : `/tables` et surtout `/tables/compare` pour voir les tables configurées et celles manquantes dans `raw_data`.
2. Catalogue SAP extrait : `raw_data.dd02l` / `raw_data.dd02t` pour savoir si une table existe côté SAP et récupérer son libellé.
3. PostgreSQL : `information_schema.tables` + `COUNT(*)` sur les tables `raw_data` concernées pour distinguer table absente et table présente mais vide.

## Périmètre utile opérations de maintenance

Tables d'ordres / opérations :
- `AFVC` : opérations d'ordre, table centrale des opérations. Clés usuelles : `AUFPL`, `APLZL`, `VORNR`.
- `AFVV` : valeurs, quantités, durées, dates et charges d'opération. Jointure avec `AFVC` via `AUFPL` + `APLZL`.
- `AFRU` : confirmations / pointages d'opérations.
- `AFKO` : en-tête d'ordre avec données de planification, notamment lien vers `AUFPL`.
- `AFPO` : poste d'ordre.
- `AUFK` : en-tête administratif des ordres.
- `CAUFV` : vue ordre complète.

Postes de travail :
- `CRHD` : en-tête poste de travail.
- `CRTX` : textes / désignations des postes de travail.

Gammes / opérations de gamme :
- `PLKO` : en-tête de gamme.
- `PLPO` : opérations de gamme.
- `PLAS` : sélection / affectation des postes de gamme.
- `PLFL` : séquences de gamme.
- `MAPL` : affectation matériel / objet à gamme.
- `PLMZ` : affectation composants de nomenclature aux opérations.
- `RESB` : réservations / composants d'ordre.

Contexte objet technique / statuts :
- `IFLOT`, `IFLOTX`, `IFLOS` : postes techniques et textes/structure.
- `EQUI`, `EQKT`, `EQUZ` : équipements et textes/segments temporels.
- `ILOA` : localisation / imputation objet technique.
- `IHPA` : partenaires.
- `JEST`, `JCDS` : statuts actifs et historique.

## Requête de diagnostic type

```sql
WITH candidates(tabname, role) AS (
  VALUES
    ('AFKO','ordre - en-tête planification / routing'),
    ('AFPO','ordre - poste / item'),
    ('AUFK','ordre - en-tête administratif'),
    ('CAUFV','vue ordre complète'),
    ('AFVC','opérations ordre/gamme'),
    ('AFVV','valeurs/temps opérations'),
    ('AFRU','confirmations opérations'),
    ('CRHD','poste de travail'),
    ('CRTX','texte poste de travail'),
    ('PLKO','gamme - en-tête'),
    ('PLPO','gamme - opérations'),
    ('PLAS','gamme - affectation séquences/opérations'),
    ('PLFL','gamme - séquences'),
    ('PLMZ','affectation composants à opérations'),
    ('MAPL','affectation objet/matériel à gamme'),
    ('RESB','réservations/composants ordre')
), sap AS (
  SELECT upper(tabname) tabname, max(tabclass) tabclass
  FROM raw_data.dd02l
  WHERE upper(tabname) IN (SELECT tabname FROM candidates)
  GROUP BY upper(tabname)
), txt AS (
  SELECT upper(tabname) tabname,
         max(ddtext) FILTER (WHERE ddlanguage IN ('F','FR')) ddtext_fr,
         max(ddtext) ddtext_any
  FROM raw_data.dd02t
  WHERE upper(tabname) IN (SELECT tabname FROM candidates)
  GROUP BY upper(tabname)
), raw AS (
  SELECT upper(table_name) tabname
  FROM information_schema.tables
  WHERE table_schema='raw_data' AND table_type='BASE TABLE'
)
SELECT c.tabname,
       c.role,
       (sap.tabname IS NOT NULL) AS existe_catalogue_sap_dd02l,
       coalesce(sap.tabclass,'') AS tabclass,
       coalesce(txt.ddtext_fr, txt.ddtext_any, '') AS libelle_sap,
       (raw.tabname IS NOT NULL) AS existe_dans_raw_data,
       CASE
         WHEN sap.tabname IS NOT NULL AND raw.tabname IS NULL THEN 'MANQUE DANS raw_data'
         WHEN sap.tabname IS NOT NULL AND raw.tabname IS NOT NULL THEN 'OK'
         WHEN sap.tabname IS NULL AND raw.tabname IS NOT NULL THEN 'raw_data mais pas trouvé DD02L'
         ELSE 'pas trouvé SAP/DD02L'
       END AS diagnostic
FROM candidates c
LEFT JOIN sap USING (tabname)
LEFT JOIN txt USING (tabname)
LEFT JOIN raw USING (tabname)
ORDER BY c.tabname;
```

Puis compter les lignes des tables présentes. Une table présente avec `0` ligne est à signaler séparément d'une table absente : elle existe dans `raw_data`, mais elle doit probablement être rechargée ou son périmètre d'extraction est vide.

## Pièges

- `/tables/compare` ne compare que les tables configurées dans l'API avec `raw_data`. Un `missing_count = 0` signifie seulement que la configuration actuelle est matérialisée, pas que le périmètre fonctionnel SAP est complet.
- Certaines tables peuvent exister dans `raw_data` mais être listées comme `extra_in_postgres` par `/tables/compare` parce qu'elles ne sont plus dans la config API actuelle.
- Pour les opérations, `AFVC` seule ne suffit pas : vérifier aussi `AFVV` pour temps/durées/valeurs et `AFRU` pour confirmations.
