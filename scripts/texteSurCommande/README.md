# Textes longs SAP (STXH/STXL) -> IFS

## Pourquoi un script RFC et pas du SQL

`raw_data.stxh` porte les cles des textes longs (objet, nom, type, langue),
mais le contenu est dans `stxl.clustd` : un cluster **compresse** SAP
(`EXPORT/IMPORT TO DATABASE`), de type **LRAW** que `RFC_READ_TABLE` ne sait
pas renvoyer. La colonne est donc NULL sur 100 % des lignes de
`raw_data.stxl`, et serait illisible meme remplie. Le contenu ne s'obtient
que par module fonction.

Le systeme `PRO` est en **R/3 4.6C** : `READ_TEXT` appele en RFC y repond
`NOT_FOUND` (DA 300) sur **toutes** les cles, meme celles dont l'en-tete
existe (cause des CSV vides d'aout 2026). **`RFC_READ_TEXT`** (table de cles
en entree, lignes en sortie) fonctionne : 500 cles en ~0,7 s.

## Ou sont les sources (le depot n'a que des COPIES)

| Fichier ici | Source de reference (montee dans le conteneur `pyrfc_app`) |
|---|---|
| `extract_textes_longs_sap.py`, `test_extract_textes_longs_sap.py`, `01_ddl_*.sql` | `/root/pyrfc_app/SapExtractionProject/texteSurCommande/` |
| `textes_jobs.py`, `test_textes_jobs.py` | `/root/pyrfc_app/SapExtractionProject/` (+ routes `/textes/*` dans `api_simple.py`) |

Apres modification : resynchroniser les copies, puis `docker restart pyrfc_app`.

## Depuis l'application (ecran Extraction > Textes longs SAP)

`/extraction/textes` (`frontend/src/pages/TextesExtraction.tsx`) -> Flask
`/api/v1/extraction/textes/*` (`backend/api/extraction.py`, proxy) -> API
sap-extraction `/textes/*` (`textes_jobs.py`, job en thread, un seul a la
fois, 409 sinon) -> `executer()` du script. L'ecran propose les objets /
types / langues presents dans `raw_data.stxh` avec le volume deja charge.
Les jobs sont en memoire (perdus au redemarrage du service SAP).

## En ligne de commande

```bash
docker exec -w /app/texteSurCommande pyrfc_app python extract_textes_longs_sap.py --objet MATERIAL --tdid BEST --langue F
docker exec -w /app/texteSurCommande pyrfc_app python extract_textes_longs_sap.py --objet EINA     # tous ID, toutes langues
docker exec -w /app/texteSurCommande pyrfc_app python -m unittest test_extract_textes_longs_sap
docker exec -w /app pyrfc_app python -m unittest tests.test_textes_jobs
```

- Cible : `raw_data.sap_long_text` (migration 081 ; ex-`sap_material_text`),
  une ligne SAPscript par enregistrement, `line_no` = rang renvoye par SAP,
  `tdformat` brut, cle `(tdobject, tdid, tdspras, tdname)`.
- Idempotent : le lot remplace les lignes deja presentes pour les memes
  `(tdobject, tdid, tdspras)`. Une annulation ne charge rien.
- **Tout l'inventaire STXH est lu** : `stxh.tdtxtlines` n'est pas fiable
  (2 024 en-tetes MATERIAL/BEST a « 0 ligne » portaient 3 332 lignes).
  `--exclure-vides` ne sert qu'a raccourcir un essai.
- `--diagnostic` compare `READ_TEXT` et `RFC_READ_TEXT` sur 5 cles.

## Cote ETL (`sql/`)

`clean_data.texte_long_sap(objet, id, nom, langues[])` (`sql/functions/`,
compilee par `sql/inventory/compile.sh`) recompose un texte : `*`, `/` et
format vide = nouvelle ligne, `=` = suite de la ligne precedente, `/:` et
`/*` ignores, espaces de fin de ligne retires, `btrim`, `LEFT 2000`, NULL
sans texte ; premiere langue du tableau qui a un texte.

| Cible IFS | Source | Langues | Couverture 20/09/2026 |
|---|---|---|---|
| `part_catalog.info_text` | `MATERIAL / BEST`, `tdname = numero_article` (MATNR 18) | `F` | 20 469 / 28 481 articles, aucun tronque |
| `purchase_part_supplier.note_text` | `EINA / AT` (`infnr`) puis saut de ligne puis `EINE / BT` (`infnr‖ekorg‖esokz‖werks`) | `F, E, D, N` | 1 381 / 37 527 liens : 7 320 des 8 622 fiches-info avec texte sont sur l'org. d'achat 6000, hors perimetre 9200/9000 |

Tests : `backend/tests/test_sap_long_text.py`,
`backend/tests/test_inventory_part_catalog_info_text.py`,
`backend/tests/test_extraction_textes_routes.py` (dans le conteneur backend).
Apres toute extraction, rejouer le module inventory dans l'ecran ETL.
