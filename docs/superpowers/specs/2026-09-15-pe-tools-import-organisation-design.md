# Design — Import PE Tools par fichier + organisation de maintenance

Date : 2026-09-15. Écran `/maintenance/pe-tools`, table `raw_data.pe_tools`,
module ETL PM Actions (`sql/pm_actions/`).

## 1. Contexte et objectif

`raw_data.pe_tools` (1 760 lignes) a été chargée une fois, hors application, par
fusion des CSV `PeTool - 7.<CODE>.csv` (script externe `fusion_csv.py`). Rien ne
trace le fichier d'origine, et l'organisation de maintenance IFS
(`pm_action.org_code`) est une constante `FR_MAINT`
(`public.get_default_value('clean_data.pm_action','org_code')`).

Le métier veut que l'organisation soit déduite du **fichier d'origine** :

| Code fichier | Organisation IFS |
|---|---|
| MSJ | FR-MSJ |
| MCAR | SJ-MCAR |
| MATC | SJ-MATC |
| MELY | SJ-MELY |
| MFIE | SJ-MFIE |
| MSGX | SJ-MSGX |
| MSCT | SJ-MSCT |
| MNRJ | SJ-MSST |
| MTRO | SJ-MTRO |

Décisions prises :
- Créer un **import applicatif** dans l'écran PE Tools (il n'en existe pas).
- Mode **remplacer par fichier** : redéposer un fichier remplace uniquement ses
  lignes ; les lignes historiques (sans `nom_fichier`) ne sont jamais touchées.
- Règle fichier → organisation stockée dans une **table de paramétrage** en
  base ; code inconnu → organisation NULL + avertissement (pas de repli
  générique `SJ-<CODE>`).
- **CSV uniquement** (pas de lecture des `.xlsm`).
- `org_contract` reste la constante `SJ` pour toutes les organisations, y
  compris `FR-MSJ` (hypothèse à confirmer côté IFS ; changer la constante ne
  relève pas de ce chantier).

## 2. Format des fichiers source

Constaté sur `C:\document\Export\PETools\PeTool - 7.MCAR.csv` :
- encodage **cp850**, séparateur `;`, CRLF, en-tête sur la 1re ligne ;
- en-têtes métier : `Localisation / Classement`, `Gamme en DMS`,
  `Poste technique`, `Niveau SAP`, `Plan Entretien`, `Poste entretien`,
  `Groupe de Gamme`, `Compteur de Gamme`, `Frequence`, `Désignation`, `Type`,
  `Criticité`, `Parité semaine`, `Jour`, `Décal.`, `Date de validation`,
  `Lien Fichier de gamme Source`, `Lien Fichier DMS SAP en PDF`, `DMS_SAP`,
  `Charge`, `Nombre intervenants`, `Date rév.`,
  `Nb jours depuis la dernière rév.` ;
- certains exports contiennent un guillemet ouvrant jamais refermé : chaque
  ligne physique est équilibrée avant parsing (technique reprise de
  `fusion_csv.py`) ;
- des lignes peuvent avoir plus de champs que l'en-tête : le surplus est ignoré.

Rapprochement en-tête → colonne par **clé normalisée** : NFKD sans accents,
minuscules, espaces réduits, suffixe ` .:` retiré (`Date rév.` ≡ `date rev`).
Le mapping des 23 colonnes est celui de `TABLE_PE_TOOLS` dans `fusion_csv.py`.

## 3. Données — migration `migrations/075_pe_tools_import_organisation.sql`

Idempotente, rejouable.

1. `raw_data.pe_tools` :
   - `nom_fichier TEXT` — nom du CSV déposé, tel quel (`PeTool - 7.MCAR.csv`) ;
   - `organisation_maintenance TEXT` — organisation IFS calculée à l'import ;
   - `imported_at TIMESTAMPTZ` ;
   - `CREATE INDEX IF NOT EXISTS idx_pe_tools_nom_fichier ON raw_data.pe_tools (nom_fichier)`.
   Les lignes existantes restent à NULL sur ces 3 colonnes.
2. `public.pe_tools_organisation` :
   ```sql
   code_fichier  TEXT PRIMARY KEY,   -- 'MCAR' (majuscules)
   org_code      TEXT NOT NULL,      -- 'SJ-MCAR'
   description   TEXT,
   is_active     BOOLEAN NOT NULL DEFAULT TRUE,
   updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
   updated_by    TEXT
   ```
   Seed des 9 lignes du tableau, `ON CONFLICT (code_fichier) DO NOTHING`
   (une valeur modifiée à la main n'est pas écrasée par un rejeu).
3. `public.pe_tools_code_fichier(nom_fichier TEXT) RETURNS TEXT` (IMMUTABLE) :
   extrait le code = segment entre le dernier `.` précédant l'extension et
   l'extension, en majuscules : `PeTool - 7.MCAR.csv` → `MCAR`,
   `petool - 7.msgx.CSV` → `MSGX`, `PeTool - 7.MSJ.xlsm` → `MSJ`.
   Sans extension ou sans point intermédiaire → NULL.
4. `public.pe_tools_org_code(nom_fichier TEXT) RETURNS TEXT` (STABLE) :
   `SELECT org_code FROM public.pe_tools_organisation WHERE code_fichier =
   pe_tools_code_fichier(nom_fichier) AND is_active`. Inconnu → NULL.
   Unique implémentation de la règle : utilisée par l'import et rejouable
   (`UPDATE raw_data.pe_tools SET organisation_maintenance =
   public.pe_tools_org_code(nom_fichier) WHERE nom_fichier IS NOT NULL`) si le
   paramétrage change après un import.

## 4. Backend — `backend/api/maintenance_pe_tools.py`

### 4.1 Parsing — `backend/services/pe_tools_import_service.py`

Module sans dépendance Flask, testable seul.

- `PE_TOOLS_COLUMNS: list[tuple[str, str]]` — (colonne SQL, intitulé CSV), les
  23 couples de `fusion_csv.py`.
- `cle(nom) -> str` — normalisation décrite en §2.
- `parse_pe_tools_csv(content: bytes, sep=';') -> ParsedFile` avec :
  - `rows: list[dict[str, str | None]]` — clés = colonnes SQL, valeurs
    strippées, `''` → `None` ; lignes entièrement vides ignorées ;
  - `missing_columns: list[str]` — intitulés attendus absents de l'en-tête ;
  - `unknown_columns: list[str]` — intitulés du fichier sans équivalent ;
  - `repaired_lines: int` — lignes aux guillemets réparés.
- Erreurs (`ValueError`, message en français) : contenu vide, en-tête ne
  contenant ni `Poste technique` ni `Plan Entretien` (fichier hors format).
- Décodage : si le contenu commence par le BOM UTF-8 (`EF BB BF`), lire en
  `utf-8-sig` (l'export CSV de l'écran est en UTF-8 BOM : on accepte son
  propre export en retour) ; sinon cp850 avec `errors='replace'`.

### 4.2 Route `POST /api/v1/maintenance/pe-tools/import`

- Multipart, champ `files` répété (1..n). Extension `.csv` obligatoire
  (sinon le fichier est en erreur, les autres continuent).
- Pour chaque fichier, dans **sa propre transaction** :
  1. `parse_pe_tools_csv` ;
  2. `org = SELECT public.pe_tools_org_code(%s)` ;
  3. `DELETE FROM raw_data.pe_tools WHERE nom_fichier = %s` → `lignes_supprimees` ;
  4. `INSERT` par lots (`execute_values`) avec `raw_id` =
     `(SELECT COALESCE(MAX(raw_id),0) FROM raw_data.pe_tools) + row_number`
     calculé une fois avant l'insert, `nom_fichier`, `organisation_maintenance`,
     `imported_at = NOW()`, `updated_at = NOW()`, `updated_by = _user()`
     (colonnes d'audit seulement si `_has_audit_columns`) ;
  5. commit ; toute exception → rollback du fichier, statut `error`.
- Réponse `200` (même si certains fichiers sont en erreur) :
  ```json
  {"success": true,
   "results": [
     {"fichier": "PeTool - 7.MCAR.csv", "status": "ok",
      "code_fichier": "MCAR", "organisation_maintenance": "SJ-MCAR",
      "lignes_supprimees": 0, "lignes_inserees": 109,
      "avertissements": ["Colonne absente du fichier : Décal."]},
     {"fichier": "PeTool - 7.MENG.csv", "status": "ok",
      "code_fichier": "MENG", "organisation_maintenance": null,
      "lignes_supprimees": 0, "lignes_inserees": 42,
      "avertissements": ["Code MENG absent de public.pe_tools_organisation : organisation non renseignée"]},
     {"fichier": "x.txt", "status": "error", "error": "Extension attendue : .csv"}
   ]}
  ```
  `success` = au moins un fichier `ok`. Aucun fichier fourni → `400`.
- Avertissements produits : colonnes manquantes, colonnes ignorées, guillemets
  réparés (`n ligne(s) réparée(s)`), organisation non résolue.
- `cache_invalidate(CACHE_PREFIX)` après le dernier fichier.
- Le blueprint est déjà sous JWT global ; aucune permission supplémentaire
  (même niveau que l'édition de lignes).

### 4.3 Routes existantes

- `COLUMNS` reste la liste des colonnes **éditables** (inchangée : PUT/POST ne
  peuvent pas écrire `nom_fichier` ni `organisation_maintenance`).
- Nouvelle liste `COMPUTED_COLUMNS = ['nom_fichier', 'organisation_maintenance']`
  ajoutée à la sélection de la liste, du détail et de l'export CSV (en tête,
  après `raw_id` et avant les colonnes métier, pour être visibles).
- `FILTER_COLUMNS` : + `nom_fichier`, + `organisation_maintenance`.
- `ORDERABLE` : + ces 2 colonnes.
- Réponse de la liste : `columns` inclut désormais `COMPUTED_COLUMNS + COLUMNS`.
- Comme pour les colonnes d'audit (migration 029), leur présence est détectée
  une fois (`information_schema`) : sans la migration 075, l'écran fonctionne
  comme avant et l'import renvoie `503` « migration 075 non jouée ».

## 5. Frontend — `frontend/src/pages/MaintenancePeToolsPage.tsx`

- Bouton **Importer** (icône upload) à côté d'« Exporter CSV ».
- Dialog `ImportPeToolsDialog` (composant local au fichier, comme les autres
  dialogs de la page) :
  - `<input type="file" multiple accept=".csv">`, liste des fichiers choisis
    avec leur taille ; rappel en une phrase : « Les lignes déjà importées
    depuis un fichier du même nom sont remplacées ; les autres ne bougent pas. »
  - bouton **Lancer l'import** → `api.post('/maintenance/pe-tools/import',
    FormData)` ; spinner pendant l'appel ;
  - résultat : tableau par fichier (fichier, organisation, supprimées,
    insérées, statut) + avertissements/erreurs en `Alert` sous chaque ligne ;
    organisation NULL affichée en `Chip` orange « non résolue ».
  - fermeture → rechargement de la liste et des stats.
- Grille : 2 colonnes `Fichier` et `Organisation` (lecture seule, chip
  monospace), ajoutées aux filtres déroulants (les `filter_options` viennent
  déjà de l'API) et au panneau de détail. Le formulaire d'édition ne les
  propose pas.

## 6. ETL PM Actions — `sql/pm_actions/`

- `clean_data.v_pm_source` : la vue est définie en base (pas de fichier source
  dans le dépôt) ; ajouter sa définition (`CREATE OR REPLACE VIEW`, reprise de
  `pg_get_viewdef`) dans `00_pm_helpers.sql` avec la colonne
  `t.organisation_maintenance` en plus.
- `01_populate_pm_action.sql` : dans `agg`, `min(s.organisation_maintenance)
  AS org_code_fichier` ; à l'insert,
  `org_code = COALESCE(a.org_code_fichier, v_org_code)`. Une `pm_no` ne
  provient que d'un seul fichier en pratique ; `min()` sert de garde.
- `04_populate_pm_action_role.sql` : `org_code = p.org_code` depuis la
  jointure `clean_data.pm_action p` déjà présente (au lieu de la constante),
  pour rester cohérent avec l'action.
- `org_contract`, `mch_code_contract` : inchangés (`SJ`).
- Lignes historiques sans fichier → `FR_MAINT` comme aujourd'hui.

## 7. Tests et vérification

- `backend/tests/test_pe_tools_import_service.py` (sans base) :
  - décodage cp850 (« Désignation », « rév. ») et UTF-8 BOM ;
  - mapping complet des 23 colonnes sur l'en-tête réel de `PeTool - 7.MCAR.csv`
    (copie tronquée à 3 lignes dans `backend/tests/fixtures/`) ;
  - colonne manquante / inconnue → listes d'avertissement ;
  - guillemet non fermé réparé, ligne plus large que l'en-tête ;
  - fichier vide / hors format → `ValueError`.
- Vérification SQL de `pe_tools_code_fichier` sur les 9 noms + casse +
  `.xlsm` + nom sans point (bloc `DO` d'assertions en fin de migration).
- Sur le serveur (tests exécutés à distance, cf. workflow) :
  1. jouer la migration 075, `cd sql/pm_actions && ./compile.sh` ;
  2. importer les 8 CSV de `C:\document\Export\PETools` depuis l'écran ;
     comparer `lignes_inserees` à `wc -l` − 1 (MCAR : 109, MATC : 120,
     MELY : 440, MFIE : 596, MNRJ : 179, MSCT : 168, MSGX : 20) ;
  3. réimporter MCAR : `lignes_supprimees = 109`, total inchangé ;
  4. `CALL clean_data.populate_all_pm_actions()` puis
     `SELECT org_code, count(*) FROM clean_data.pm_action GROUP BY 1`.

## 8. Hors périmètre

- Écran d'administration de `public.pe_tools_organisation` (modification par
  SQL pour l'instant).
- Lecture des `.xlsm`.
- Reprise des 1 760 lignes historiques : elles restent sans organisation.
  Une fois les 9 fichiers réimportés, les supprimer manuellement
  (`DELETE FROM raw_data.pe_tools WHERE nom_fichier IS NULL`) pour éviter les
  doublons de `pm_no` entre l'historique et l'import.
- Changement de `org_contract` par organisation.
