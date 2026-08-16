# Portes SharePoint et activités projet IFS

Retour d'expérience sur le diagnostic des portes projet et des loaders `clean_data.alimenter_activity()`, `clean_data.alimenter_ifs_project_base()` et `clean_data.alimenter_project_activity()`.

## Tables / vues à distinguer

- `raw_data.sharepoint_porte` : ancienne source directe des portes SharePoint par projet (`numero_projet`, `porte`, `date_fin`, etc.). Utile pour diagnostic historique, mais ne pas l'utiliser comme source des loaders d'activités car elle ne porte pas correctement les portes bis/ter issues des jalons.
- `clean_data.v_portes_detail` : source de référence pour alimenter `clean_data.activity` et `clean_data.project_activity`; elle expose les jalons détaillés (`gate`, `porte_libelle`, `milestone_id`, dates) permettant de distinguer P3 / P3bis / P3ter.
- `clean_data.activity` : activités IFS de type porte réellement présentes par projet, alimentées depuis `v_portes_detail`; ne doit plus être un `CROSS JOIN` fixe P0/P0bis/P0ter/etc. pour tous les projets.
- `clean_data.project_activity` : activités projet réellement exportées/alimentées par `clean_data.alimenter_project_activity()` depuis `v_portes_detail`.

## Piège majeur : ne pas générer des portes artificielles

`clean_data.alimenter_activity()` et `clean_data.alimenter_project_activity()` doivent être pilotées par `clean_data.v_portes_detail` et non par un `CROSS JOIN` fixe ni par `raw_data.sharepoint_porte`.

Règle de sélection : ne garder que les jalons de type porte réelle, c'est-à-dire les libellés normalisés qui correspondent à `P0..P6`, `P0bis..P6bis`, `P0ter..P6ter(s)`. Exclure les jalons métier non-porte présents dans la popup SharePoint, par exemple `Point L. Maenner`, `P1 Fermée`, `P4 batch 1`, etc.

La normalisation recommandée calcule `activity_source` ainsi :
- libellé vide ou identique au `gate` `P0..P6` => `P<n>` ;
- libellé égal à `gate || 'bis'` après suppression des espaces => `P<n>bis` ;
- libellé égal à `gate || 'ter'` ou `gate || 'ters'` après suppression des espaces => `P<n>ter` ;
- sinon `NULL`, et la ligne est filtrée.

Cela permet de reprendre les vraies portes bis/ter, par exemple `21.067 / P3bis`, sans créer artificiellement toutes les bis/ter pour tous les projets.

## Diagnostic d'un projet sans `project_activity`

Si un projet a des lignes dans `raw_data.sharepoint_porte` mais aucune dans `clean_data.project_activity`, vérifier dans cet ordre :

1. Présence dans le périmètre projet :

```sql
SELECT sp.project_number, sp.code, sp.title, sp.global_status,
       EXISTS (
         SELECT 1 FROM raw_data.sharepoint_project_to_save s
         WHERE s."Numéro du projet" = sp.project_number
       ) AS in_to_save,
       EXISTS (
         SELECT 1 FROM clean_data.project_base pb
         WHERE pb.project_id = substring(coalesce(sp.project_number, sp.code), 1, 10)
       ) AS in_project_base
FROM raw_data.sharepoint_projets sp
WHERE sp.project_number = '<PROJECT_ID>' OR sp.code = '<PROJECT_ID>';
```

2. Présence dans la vue utilisée par le loader :

```sql
SELECT project_number, gate, porte_libelle, milestone_id, site_id,
       date_prevue, date_realisee, date_etat_source
FROM clean_data.v_portes_detail
WHERE substring(project_number, 1, 10) = '<PROJECT_ID>'
ORDER BY gate, porte_libelle;
```

3. Si absent de `v_portes_detail`, inspecter la définition de vue et les sources sous-jacentes :

```sql
SELECT pg_get_viewdef('clean_data.v_portes_detail'::regclass, true);

SELECT site_id, title, raw_data->>'MilestoneId' AS milestone_id,
       raw_data->>'Gate' AS gate, modified
FROM raw_data.sharepoint_statut_jalons
WHERE site_id = '<SITE_ID>'
ORDER BY title, milestone_id;

SELECT site_id, title, status_date, modified
FROM raw_data.sharepoint_etats_avancement
WHERE site_id = '<SITE_ID>'
ORDER BY title, status_date DESC;
```

## Cause fréquente observée

`clean_data.v_portes_detail` est construite depuis `raw_data.sharepoint_statut_jalons` avec un `JOIN` sur `raw_data.sharepoint_etats_avancement` :

```sql
ea.site_id = sj.site_id
AND ea.title = sj.title
```

Si un projet a des `sharepoint_statut_jalons` mais aucun `sharepoint_etats_avancement` correspondant, il disparaît de `v_portes_detail`, puis `clean_data.alimenter_project_activity()` ne crée aucune activité porte pour lui, même si `raw_data.sharepoint_porte` contient des portes.

Exemple rencontré : projet `22.060` / site `804` avait 6 portes dans `raw_data.sharepoint_porte` et 6 lignes dans `sharepoint_statut_jalons`, mais 0 ligne dans `sharepoint_etats_avancement`; il était donc absent de `v_portes_detail` et de `project_activity`.

## Requête de contrôle des comptes par couche

```sql
SELECT 'raw_sharepoint_porte' AS couche, numero_projet AS project_id,
       COUNT(*) AS nb, string_agg(porte, ', ' ORDER BY porte) AS details
FROM raw_data.sharepoint_porte
WHERE numero_projet IN (<PROJECT_LIST>)
GROUP BY numero_projet
UNION ALL
SELECT 'v_portes_detail', substring(project_number, 1, 10),
       COUNT(*), string_agg(coalesce(porte_libelle, gate), ', ' ORDER BY gate, porte_libelle)
FROM clean_data.v_portes_detail
WHERE substring(project_number, 1, 10) IN (<PROJECT_LIST>)
GROUP BY substring(project_number, 1, 10)
UNION ALL
SELECT 'project_activity', project_id,
       COUNT(*), string_agg(activity_no, ', ' ORDER BY activity_no)
FROM clean_data.project_activity
WHERE project_id IN (<PROJECT_LIST>)
GROUP BY project_id
ORDER BY project_id, couche;
```
