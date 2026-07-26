# Rapport de stage — Migration Factory (SAP ECC → IFS)

> Plateforme web temporaire d'aide à la migration de données d'un ERP **SAP ECC 6.0+** vers **IFS** (extraction, transformation, chargement — ETL).
> Document de travail : **30 tâches** détaillées (objectif, étapes, fichiers, extraits de code, difficultés) couvrant l'ensemble du projet — à enrichir pour le rapport final avec captures et schémas.

---

## 1. Contexte et intégration

La **Migration Factory** est une application full-stack interne, prévue pour une durée de vie courte (~5 mois), dont le rôle est d'**extraire** les données de l'ancien système SAP, de les **transformer** au format attendu par IFS, puis de générer les **fichiers de chargement** (CSV en archive ZIP).

| Couche | Technologies |
|--------|--------------|
| Frontend | React 18 + TypeScript + Material-UI + Vite (port 3000) |
| Backend | Flask 2.3.3 + SQLAlchemy + Python 3.11 (port 5000) |
| Base de données | PostgreSQL 12+ (serveur externe `10.190.100.58:5432`) |
| Déploiement | Docker Compose + Nginx |

Trois schémas : **`raw_data`** (121 tables SAP brutes, lecture seule), **`clean_data`** (45 vues/tables au format IFS), **`public`** (15 tables système : users, jobs, configs, logs).

**Mon intégration.** Arrivé **à mi-parcours**, mon travail a couvert deux registres : (1) la **prise en main et l'évolution** du socle et des domaines déjà entamés (auth, import/export, transcodification, clients, fournisseurs, projets, ressources) ; (2) la **conception et le développement** du domaine **Maintenance (SAP PM)** et du **module d'extraction**. Le rapport balaie volontairement tous les domaines pour refléter la largeur des compétences (full-stack, SQL avancé, ETL, intégration externe, DevOps).

> **Légende des rubriques par tâche :** 🎯 Objectif · 🪜 Étapes réalisées · 📁 Fichiers · 💻 Extrait de code · ⚠️ Difficultés · 💡 À approfondir.

---

## 2. Synthèse des 30 tâches

| # | Tâche | Domaine | Période |
|---|-------|---------|---------|
| 1 | Prise en main de l'architecture ETL | Transverse | mi-janv. |
| 2 | Environnement de développement | DevOps | mi-janv. |
| 3 | Étude du modèle de données (3 schémas) | Analyse | mi-janv. |
| 4 | Authentification JWT & rôles | Socle | fin janv. |
| 5 | Transcodification SAP→IFS | Socle | fin janv. |
| 6 | Moteur d'import générique | Socle | févr. |
| 7 | Moteur d'export dynamique | Socle | févr. |
| 8 | Explorateur de données SAP (DDIC) | Données | févr. |
| 9 | Gestion de la structure des tables | Données | févr. |
| 10 | Mapping des champs SAP→IFS | Données | févr.–mars |
| 11 | Données clients (customer) | Tiers | mars |
| 12 | Clients filiale PHL | Tiers | mars |
| 13 | Données fournisseurs (supplier) | Tiers | mars |
| 14 | Données projets (SharePoint) | Projet | mars |
| 15 | Intégration SharePoint (NTLM) | Intégration | mars |
| 16 | Import des états d'avancement projet | Projet | mars |
| 17 | Ressources de maintenance | Ressources | mars–avril |
| 18 | Articles d'inventaire (part catalog) | Articles | avril |
| 19 | Articles de maintenance + encodage grec | Maintenance | avril |
| 20 | Hiérarchie des postes techniques IH02 | Maintenance | avril |
| 21 | Édition de la hiérarchie (drag & drop) | Maintenance | avril |
| 22 | Nomenclatures (BOM postes & articles) | Maintenance | avril–mai |
| 23 | ETL `equipment_functional` + refactor | ETL | mai |
| 24 | Export spécifique Maintenance | Maintenance | mai |
| 25 | Module d'extraction SAP | Extraction | mai |
| 26 | Sauvegarde & rétention de la base | DevOps | mai |
| 27 | Configuration système & e-mails (SMTP) | Socle | mai |
| 28 | Outillage SQL (compile / déploiement procédures) | DevOps | mai–juin |
| 29 | Tableau de bord & indicateurs | Restitution | juin |
| 30 | Déploiement Docker / Nginx | DevOps | juin |

---

# PHASE 0 — Intégration et montée en compétences

## Tâche 1 — Prise en main de l'architecture ETL SAP → IFS

**Période :** mi-janvier · **Domaine :** Transverse

**🎯 Objectif.** Comprendre le découpage *extraction → transformation → chargement* et savoir où intervenir.

**🪜 Étapes réalisées.**
1. Lecture du `CLAUDE.md`, du `docker-compose.yml` et du point d'entrée `app.py`.
2. Inventaire des Blueprints d'API et des modules ETL.
3. Reconstitution du flux `raw_data → clean_data → export` et schéma maison.

**📁 Fichiers.** *(étude, pas de modification)* [backend/app.py](backend/app.py), [backend/api/__init__.py](backend/api/__init__.py), [backend/services/](backend/services/).

**💻 Extrait de code** *(enregistrement des Blueprints, `app.py`)*
```python
app.register_blueprint(auth_blueprint, url_prefix='/api/v1/auth')
app.register_blueprint(extraction_blueprint, url_prefix='/api/v1/extraction')
app.register_blueprint(ih02_hierarchy_blueprint, url_prefix='/api/v1/ih02')
# … 24 Blueprints, tous préfixés /api/v1/
```

**⚠️ Difficultés.** Volume du code (24 API + 58 pages) → j'ai dû construire ma propre carte mentale avant de coder.

**💡 À approfondir.** Schéma d'architecture (3 schémas + flux ETL), diagramme de séquence d'un export.

---

## Tâche 2 — Mise en place de l'environnement de développement

**Période :** mi-janvier · **Domaine :** DevOps

**🎯 Objectif.** Backend + frontend + accès PostgreSQL distant fonctionnels en local.

**🪜 Étapes réalisées.**
1. `pip install -r requirements.txt` puis `npm install`.
2. Création du `.env` (hôte/port/identifiants DB, clé JWT).
3. Lancement `python app.py` + `npm run dev`, test de la connexion DB.

**📁 Fichiers.** `.env` (local, non commité), [config/settings.py](backend/config/settings.py), [config/database.py](backend/config/database.py).

**💻 Extrait de code** *(connexion centralisée)*
```python
def get_db_connection():
    return psycopg2.connect(
        host=os.getenv("DB_HOST", "10.190.100.58"),
        port=os.getenv("DB_PORT", "5432"),
        dbname=os.getenv("DB_NAME", "sap_migration_db"),
        user=os.getenv("DB_USER"), password=os.getenv("DB_PASSWORD"))
```

**⚠️ Difficultés.** Encodage de la console Windows (accents/caractères grecs) ; accès réseau au serveur DB externe à configurer.

**💡 À approfondir.** Tableau des variables d'environnement, schéma réseau.

---

## Tâche 3 — Étude du modèle de données (3 schémas)

**Période :** mi-janvier · **Domaine :** Analyse

**🎯 Objectif.** Cartographier `raw_data` (sources SAP), `clean_data` (cibles IFS), `public` (système).

**🪜 Étapes réalisées.**
1. Exploration des tables via l'explorateur de l'app + requêtes `information_schema`.
2. Documentation des colonnes techniques SAP (`mandt`, `spras`, `werks`, `datbi`).
3. Repérage des tables de suivi (`import_jobs`, `import_details`, `etl_export_queries`).

**📁 Fichiers.** *(analyse)* dictionnaire de tables personnel.

**💻 Extrait de code** *(inventaire d'un schéma)*
```sql
SELECT table_name, COUNT(*) AS nb_colonnes
FROM information_schema.columns
WHERE table_schema = 'raw_data'
GROUP BY table_name ORDER BY table_name;
```

**⚠️ Difficultés.** Noms de colonnes SAP cryptiques (TPLNR, EQUNR, ARBPL…) sans documentation → reconstitution par recoupement.

**💡 À approfondir.** Modèle Entité-Association, glossaire SAP, notion de mandant et multilingue.

---

# PHASE 1 — Socle applicatif

## Tâche 4 — Authentification JWT & gestion des utilisateurs/rôles

**Période :** fin janvier · **Domaine :** Socle / Sécurité

**🎯 Objectif.** Sécuriser l'accès (connexion, jetons, rôles) et gérer les comptes.

**🪜 Étapes réalisées.**
1. Connexion par mot de passe **haché** (`verify_password`), contrôle `is_active`.
2. Émission **access + refresh tokens** porteurs du rôle (claims).
3. Décorateurs de protection (`admin_required`, `require_role`) et reset par e-mail.

**📁 Fichiers.** [backend/api/auth.py](backend/api/auth.py), [backend/api/users.py](backend/api/users.py), `utils/auth_decorators.py`, modèle `User`, [frontend/src/pages/Login.tsx](frontend/src/pages/Login.tsx), [frontend/src/pages/security/RoleManagement.tsx](frontend/src/pages/security/RoleManagement.tsx).

**💻 Extrait de code** *(émission du jeton avec rôle)*
```python
access = create_access_token(identity=str(user.id),
                             additional_claims={'role': user.role, 'username': user.username})
refresh = create_refresh_token(identity=str(user.id))
user.last_login = datetime.now(); db.session.commit()
```

**⚠️ Difficultés.** Synchroniser l'expiration du token côté front (refresh automatique) ; passage progressif de routes `optional=True` à protégées sans casser l'existant.

**💡 À approfondir.** JWT (access vs refresh, claims), hachage de mot de passe, RBAC.

---

## Tâche 5 — Transcodification SAP → IFS

**Période :** fin janvier · **Domaine :** Socle / Référentiel

**🎯 Objectif.** Gérer les **tables de correspondance** entre valeurs SAP et IFS, réutilisables par tous les ETL.

**🪜 Étapes réalisées.**
1. CRUD + recherche/filtres/pagination sur les transcodifications.
2. **Import en masse** d'un fichier de correspondances.
3. Fonction SQL d'aide consommée par les procédures d'alimentation.

**📁 Fichiers.** [backend/api/transcodification.py](backend/api/transcodification.py), modèle `Transcodification`, [frontend/src/pages/TranscodificationManagement.tsx](frontend/src/pages/TranscodificationManagement.tsx), [sql/functions/get_transcodification.sql](sql/functions/get_transcodification.sql).

**💻 Extrait de code** *(filtres dynamiques SQLAlchemy)*
```python
query = Transcodification.query
if category:       query = query.filter(Transcodification.category == category)
if status=='active': query = query.filter(Transcodification.is_active == True)
if search:
    s = f"%{search}%"
    query = query.filter(db.or_(Transcodification.source_value.ilike(s),
                                Transcodification.target_value.ilike(s)))
```

**⚠️ Difficultés.** Doublons à l'import en masse (même `category`+`source_value`) → stratégie d'upsert ; cohérence des catégories.

**💡 À approfondir.** Référentiel de mapping dans une migration, upsert à l'import.

---

## Tâche 6 — Moteur d'import générique (CSV / XLSX / XLS)

**Période :** février · **Domaine :** Socle / Import

**🎯 Objectif.** Importer **n'importe quel fichier** vers **n'importe quelle table**, avec mapping assisté et validation ligne par ligne.

**🪜 Étapes réalisées.**
1. Analyse du fichier : détection des colonnes + échantillons.
2. **Proposition automatique** de correspondances par similarité de chaînes.
3. Validation des types, puis import avec suivi `import_jobs` / `import_details`.

**📁 Fichiers.** [backend/api/import_generic.py](backend/api/import_generic.py), `services/import_service.py`, `services/file_processors.py`, `services/import_mapping_service.py`, [frontend/src/pages/ImportGeneric/](frontend/src/pages/ImportGeneric/) (steps Upload/Mapping/Validation/Import).

**💻 Extrait de code** *(mapping auto par similarité)*
```python
def calculate_similarity(a: str, b: str) -> float:
    a = a.lower().replace('_', '').replace('-', '')
    b = b.lower().replace('_', '').replace('-', '')
    return SequenceMatcher(None, a, b).ratio()   # 0 → 1
```

**⚠️ Difficultés.** Détection de type peu fiable sur colonnes mixtes/vides ; encodage des fichiers (cf. tâche 19) ; faux positifs du mapping auto → seuil + validation manuelle.

**💡 À approfondir.** *Fuzzy matching* des colonnes, assistant en étapes, reprise sur erreur ligne par ligne.

---

## Tâche 7 — Moteur d'export dynamique (ZIP / CSV)

**Période :** février · **Domaine :** Socle / Export

**🎯 Objectif.** Générer les fichiers IFS **sans écrire de code** : enregistrer une requête en base suffit.

**🪜 Étapes réalisées.**
1. Lecture des requêtes + `column_list` depuis `etl_export_queries`.
2. Exécution + **normalisation** des valeurs au format IFS.
3. Empaquetage des CSV en ZIP + cache TTL 5 min.

**📁 Fichiers.** [backend/services/export_service.py](backend/services/export_service.py), [backend/api/export.py](backend/api/export.py), [frontend/src/pages/admin/ExportQueriesManagement.tsx](frontend/src/pages/admin/ExportQueriesManagement.tsx).

**💻 Extrait de code** *(moteur SQLAlchemy avec pool)*
```python
self.engine = create_engine(conn_str, pool_size=5, max_overflow=10,
    pool_pre_ping=True, pool_recycle=3600,
    connect_args={"connect_timeout": 30, "application_name": "export_service"})
```

**⚠️ Difficultés.** Normalisations IFS (NULL→chaîne vide, **booléens en majuscules**, séparateur) ; coupures de connexion sur gros exports → `pool_pre_ping` + recyclage.

**💡 À approfondir.** Architecture « pilotée par les données », gestion d'un pool, règles de normalisation IFS.

---

# PHASE 2 — Exploration et structure des données

## Tâche 8 — Explorateur de données SAP (DDIC)

**Période :** février · **Domaine :** Données

**🎯 Objectif.** Naviguer dans les tables SAP en affichant les **libellés métier** (header_text DDIC) plutôt que les noms de colonnes cryptiques.

**🪜 Étapes réalisées.**
1. Lecture des propriétés/colonnes depuis `sap_table_properties` / `sap_table_fields`.
2. **Nettoyage** des noms de champs (DDIC les remplit d'espaces).
3. Affichage paginé + export CSV.

**📁 Fichiers.** [backend/api/sap_data_explorer.py](backend/api/sap_data_explorer.py), [backend/api/sap_views.py](backend/api/sap_views.py), [frontend/src/pages/SapDataExplorer/SapDataExplorerPage.tsx](frontend/src/pages/SapDataExplorer/SapDataExplorerPage.tsx).

**💻 Extrait de code** *(comptage de champs par table + nettoyage DDIC)*
```python
def _normalize_sap_field_rows(rows):
    # SAP DDIC pad les field_name avec des espaces → strip pour matcher les colonnes
    for r in rows:
        if isinstance(r.get('field_name'), str):
            r['field_name'] = r['field_name'].strip()
    return rows
```
```sql
SELECT p.table_name, p.description,
       (SELECT COUNT(*) FROM public.sap_table_fields f WHERE f.table_name = p.table_name) AS field_count
FROM public.sap_table_properties p
WHERE p.table_name ILIKE %s OR p.description ILIKE %s ORDER BY p.table_name;
```

**⚠️ Difficultés.** Le padding d'espaces des exports DDIC empêchait la jointure avec les colonnes réelles → `TRIM`/`strip` systématique.

**💡 À approfondir.** Notion de DDIC SAP (dictionnaire de données), affichage par `header_text`.

---

## Tâche 9 — Gestion de la structure des tables

**Période :** février · **Domaine :** Données

**🎯 Objectif.** Importer depuis Excel les **métadonnées** des tables cibles (colonnes, clés, champs obligatoires) pour piloter import et création de tables.

**🪜 Étapes réalisées.**
1. Upload d'un fichier `.xls/.xlsx` décrivant une table.
2. Stockage dans `public.table_structure_metadata` (avec `is_key`, `is_mandatory`).
3. Vue de synthèse (nb colonnes, clés, obligatoires) par table/job.

**📁 Fichiers.** [backend/api/table_structure.py](backend/api/table_structure.py), [sql/config/create_table_structure_metadata.sql](sql/config/create_table_structure_metadata.sql), [frontend/src/pages/TableStructureManagement.tsx](frontend/src/pages/TableStructureManagement.tsx).

**💻 Extrait de code** *(synthèse agrégée)*
```sql
SELECT table_name, job_name, COUNT(*) AS column_count,
       SUM(CASE WHEN is_key THEN 1 ELSE 0 END)       AS key_count,
       SUM(CASE WHEN is_mandatory THEN 1 ELSE 0 END) AS mandatory_count,
       MAX(imported_at) AS imported_at
FROM public.table_structure_metadata
GROUP BY table_name, job_name ORDER BY imported_at DESC;
```

**⚠️ Difficultés.** Formats d'en-têtes Excel hétérogènes (colonnes nommées différemment) ; gestion des doublons de réimport (même table) → remplacement par job.

**💡 À approfondir.** Métadonnées pilotant l'ETL, lecture Excel avec `pandas`, sécurisation des uploads (`secure_filename`, extensions autorisées).

---

## Tâche 10 — Mapping des champs SAP → IFS

**Période :** février–mars · **Domaine :** Données

**🎯 Objectif.** Décrire de façon configurable la **correspondance champ source → champ cible** entre tables SAP et tables IFS.

**🪜 Étapes réalisées.**
1. CRUD du référentiel de mappings (`FieldMapping`).
2. Filtres par table source/cible, statut, recherche multi-champ.
3. Export/import CSV des mappings.

**📁 Fichiers.** [backend/api/field_mapping.py](backend/api/field_mapping.py), modèle `FieldMapping`, [frontend/src/pages/FieldMappingManagement.tsx](frontend/src/pages/FieldMappingManagement.tsx).

**💻 Extrait de code** *(recherche multi-champ)*
```python
if search:
    s = f"%{search}%"
    query = query.filter(db.or_(
        FieldMapping.source_table_name.ilike(s),
        FieldMapping.source_field_name.ilike(s),
        FieldMapping.target_table.ilike(s),
        FieldMapping.target_field_name.ilike(s),
        FieldMapping.notes.ilike(s)))
```

**⚠️ Difficultés.** Différence entre transcodification (valeurs) et field mapping (colonnes) à clarifier côté métier ; cohérence avec les structures de la tâche 9.

**💡 À approfondir.** Différence mapping de champs vs transcodification de valeurs, génération assistée d'ETL à partir du mapping.

---

# PHASE 3 — Domaines de données tiers et projet

## Tâche 11 — Données clients (customer)

**Période :** mars · **Domaine :** Tiers / Clients

**🎯 Objectif.** Transformer les clients SAP vers le modèle **IFS Customer** (identité, adresses, crédit, fiscalité, paiement).

**🪜 Étapes réalisées.**
1. Module ETL appelant la procédure d'orchestration.
2. Enchaînement d'une dizaine de sous-procédures (une par table cible).
3. Journalisation et vérification des volumes.

**📁 Fichiers.** [backend/etl_modules/etl_customer.py](backend/etl_modules/etl_customer.py), [sql/customer/](sql/customer/) (`sp_insert_customer_*`).

**💻 Extrait de code** *(orchestration côté Python)*
```python
with engine.begin() as conn:
    conn.execute(text("CALL clean_data.sp_insert_customer_info_from_sap()"))
    conn.execute(text("CALL clean_data.sp_insert_customer_address_from_sap()"))
    conn.execute(text("CALL clean_data.sp_insert_customer_credit_info_from_sap()"))
    # … tax_info, payment_way, cust_ord_customer, ifs_customer_ref
```

**⚠️ Difficultés.** Dépendances entre sous-procédures (ordre d'exécution) ; clients SAP incomplets (adresses manquantes) → valeurs par défaut/rejets tracés.

**💡 À approfondir.** Découpage en sous-procédures, mapping table SAP (KNA1/KNB1…) → table IFS.

---

## Tâche 12 — Données clients de la filiale PHL

**Période :** mars · **Domaine :** Tiers / Clients

**🎯 Objectif.** Intégrer les clients d'une **filiale (PHL)** au format différent, vers le **même** modèle IFS Customer.

**🪜 Étapes réalisées.**
1. Analyse des sources `client_phl` / `client_adresse_phl`.
2. Jeu de procédures dédiées `*_from_client_phl`.
3. Validation que les tables cibles sont identiques au flux SAP.

**📁 Fichiers.** [backend/etl_modules/etl_phl_customer.py](backend/etl_modules/etl_phl_customer.py), [sql/customer_phl/](sql/customer_phl/).

**💻 Extrait de code** *(même cible, source différente)*
```sql
-- adapte la source PHL au modèle IFS commun
INSERT INTO clean_data.customer_info (customer_id, name, country, ...)
SELECT get_transcodification('COUNTRY','PHL', p.pays), p.code, p.nom, ...
FROM raw_data.client_phl p
WHERE NOT EXISTS (SELECT 1 FROM clean_data.customer_info c WHERE c.customer_id = p.code);
```

**⚠️ Difficultés.** Codifications propres à la filiale (pays, devises) → passage par la transcodification ; éviter les collisions d'identifiants avec les clients SAP.

**💡 À approfondir.** Pattern « plusieurs sources → un modèle cible unique », gestion d'un système hétérogène.

---

## Tâche 13 — Données fournisseurs (supplier)

**Période :** mars · **Domaine :** Tiers / Fournisseurs

**🎯 Objectif.** Transformer les fournisseurs SAP vers IFS, **données bancaires** comprises.

**🪜 Étapes réalisées.**
1. Appel de la procédure d'alimentation fournisseur.
2. Procédures **sans paramètres** sur vues enrichies (factures, paiement).
3. Sélection d'un échantillon de test (top 20).

**📁 Fichiers.** [backend/etl_modules/etl_supplier_base.py](backend/etl_modules/etl_supplier_base.py), [sql/supplier/](sql/supplier/) (+ `viewsAndTables/`).

**💻 Extrait de code** *(échantillon de test)*
```sql
-- ne conserve que 20 fournisseurs pour les tests de bout en bout
SELECT public.sp_keep_supplier_top20();
```

**⚠️ Difficultés.** Données bancaires (**LFBK**) multiples par fournisseur ; structure `identity_invoice_info` à corriger (cf. `corriger_structure_identity_invoice_info`, `fix_date_expire`).

**💡 À approfondir.** Particularités LFBK, vues enrichies vs procédures paramétrées, stratégie d'échantillon.

---

## Tâche 14 — Données projets (depuis SharePoint)

**Période :** mars · **Domaine :** Projet

**🎯 Objectif.** Alimenter **IFS Project** (projet, sites, rôles, sous-projets, activités) à partir des données projets SharePoint.

**🪜 Étapes réalisées.**
1. Appel des fonctions `clean_data.alimenter_ifs_project_*`.
2. Résolution des personnes (login / id SharePoint → `person_id`).
3. Alimentation des rôles, sous-projets, activités et matrice de marge.

**📁 Fichiers.** [backend/etl_modules/etl_project.py](backend/etl_modules/etl_project.py), [sql/projet/](sql/projet/), [sql/sharepoint/](sql/sharepoint/).

**💻 Extrait de code** *(résolution d'identité inter-systèmes)*
```sql
CREATE OR REPLACE FUNCTION clean_data.get_person_id_from_sharepoint_user_id(p_uid int)
RETURNS varchar AS $$
  SELECT person_id FROM clean_data.ifs_person
  WHERE sharepoint_user_id = p_uid LIMIT 1;
$$ LANGUAGE sql;
```

**⚠️ Difficultés.** Correspondance des personnes entre SharePoint et IFS (logins hétérogènes) ; limitation volontaire à 10 projets pour les tests (`limit_to_10_projects.sql`).

**💡 À approfondir.** Modèle projet IFS, résolution d'identités, matrice de marge.

---

## Tâche 15 — Intégration SharePoint (NTLM / OData)

**Période :** mars · **Domaine :** Intégration externe

**🎯 Objectif.** Récupérer projets, ressources et utilisateurs depuis l'**API SharePoint** vers `raw_data`.

**🪜 Étapes réalisées.**
1. Service HTTP authentifié **NTLM (Windows)**.
2. Identifiants lus depuis la config applicative (repli `.env`).
3. Appels OData JSON → insertion dans `raw_data.sharepoint_*`.

**📁 Fichiers.** [backend/services/sharepoint_service.py](backend/services/sharepoint_service.py), [frontend/src/pages/SharePointProjectsPage.tsx](frontend/src/pages/SharePointProjectsPage.tsx).

**💻 Extrait de code** *(authentification NTLM)*
```python
self.session.auth = HttpNtlmAuth(get_config('SHAREPOINT_USER', r'stjn\samir.chibout'),
                                 get_config('SHAREPOINT_PASSWORD', ''))
self.session.headers.update({'Accept': 'application/json;odata=verbose'})
```

**⚠️ Difficultés.** Échappement du domaine Windows (`stjn\user`) → *raw strings* ; pagination OData et timeouts SharePoint.

**💡 À approfondir.** NTLM/Windows, API OData/REST de SharePoint, configuration externalisée.

---

## Tâche 16 — Import des états d'avancement de projet

**Période :** mars · **Domaine :** Projet

**🎯 Objectif.** Importer les **états d'avancement** des projets (par site) depuis un fichier, pour enrichir le modèle projet.

**🪜 Étapes réalisées.**
1. Création/évolution de la table `etats_avancement` (+ `site_id`).
2. Page d'import dédiée (upload + validation).
3. Rattachement au projet/site correspondant.

**📁 Fichiers.** [sql/projet/create_table_etats_avancement.sql](sql/projet/create_table_etats_avancement.sql), [sql/projet/alter_etats_avancement_add_site_id.sql](sql/projet/alter_etats_avancement_add_site_id.sql), [frontend/src/pages/ImportEtatsAvancement.tsx](frontend/src/pages/ImportEtatsAvancement.tsx).

**💻 Extrait de code** *(évolution de schéma idempotente)*
```sql
ALTER TABLE clean_data.etats_avancement
    ADD COLUMN IF NOT EXISTS site_id varchar;
```

**⚠️ Difficultés.** Ajout d'une dimension `site_id` après coup sans casser les données existantes → `ADD COLUMN IF NOT EXISTS` + reprise.

**💡 À approfondir.** Évolution de schéma en cours de projet, rattachement multi-site.

---

## Tâche 17 — Ressources de maintenance (person / resource)

**Période :** mars–avril · **Domaine :** Ressources

**🎯 Objectif.** Construire le référentiel des **ressources de maintenance IFS** (personnes, disponibilités, connexions, hiérarchie).

**🪜 Étapes réalisées.**
1. Enchaînement ordonné des procédures `populate_*`.
2. Calcul de la **hiérarchie des ressources** (parents).
3. Pages de consultation par type de ressource.

**📁 Fichiers.** [backend/etl_modules/etl_maintenance_resource.py](backend/etl_modules/etl_maintenance_resource.py), [sql/maintenanceRousource/](sql/maintenanceRousource/) (`01_`→`08_`), [frontend/src/pages/resources/](frontend/src/pages/resources/).

**💻 Extrait de code** *(orchestration ordonnée)*
```python
for proc in ["populate_ifs_person", "populate_resource_detail_file",
             "populate_resource_connection", "populate_resource_availability",
             "populate_resource_parent", "populate_maint_person_resource"]:
    conn.execute(text(f"CALL clean_data.{proc}()"))
```

**⚠️ Difficultés.** Ordre strict (person avant resource, parent en dernier) ; identification des personnes sans matricule.

**💡 À approfondir.** Modèle ressources IFS, hiérarchie person↔resource, orchestration.

---

# PHASE 4 — Articles, inventaire et maintenance

## Tâche 18 — Articles d'inventaire (part catalog)

**Période :** avril · **Domaine :** Articles

**🎯 Objectif.** Alimenter le catalogue **IFS Inventory Part** (article maître, planification, fournisseur d'achat).

**🪜 Étapes réalisées.**
1. Construction d'une vue article `v_article` consolidant `mara`/`marc`/`mard`.
2. Appel de `clean_data.alimenter_part_catalog`.
3. Variante filiale (`phl_article`).

**📁 Fichiers.** [backend/etl_modules/etl_inventory_part.py](backend/etl_modules/etl_inventory_part.py), [sql/inventory/](sql/inventory/) (`alimenter_ifs_article`, `part_catalog_structure`, `v_article`, `alimenter_purchase_part_supplier`).

**💻 Extrait de code** *(consolidation article)*
```sql
CREATE OR REPLACE VIEW clean_data.v_article AS
SELECT m.matnr, LTRIM(m.matnr,'0') AS matnr_short, k.maktx AS description,
       m.mtart, m.matkl, m.meins, c.werks
FROM raw_data.mara m
LEFT JOIN raw_data.makt k ON k.matnr = m.matnr AND k.spras = 'F'
LEFT JOIN raw_data.marc c ON c.matnr = m.matnr;
```

**⚠️ Difficultés.** Articles présents dans plusieurs divisions (`marc`) → choix de la division pertinente ; unités de mesure à transcoder.

**💡 À approfondir.** Modèle article IFS, vue de consolidation, lien article ↔ fournisseur d'achat.

---

## Tâche 19 — Articles de maintenance + correctif d'encodage grec

**Période :** avril · **Domaine :** Maintenance / Qualité de données

**🎯 Objectif.** Page de consultation des **pièces de rechange** (SAP PM) et **correction d'un bug d'encodage** des désignations grecques.

**🪜 Étapes réalisées.**
1. API paginée sur `mara` filtrée `ERSA/IBAU/NLAG`.
2. Diagnostic du *mojibake* (ISO-8859-7 lu en latin-1).
3. Script SQL **idempotent** reconvertissant uniquement les lignes grecques.

**📁 Fichiers.** [backend/api/maintenance_articles.py](backend/api/maintenance_articles.py), [frontend/src/pages/MaintenanceArticlesPage.tsx](frontend/src/pages/MaintenanceArticlesPage.tsx), [sql/maintenance/fix_makt_encoding_greek.sql](sql/maintenance/fix_makt_encoding_greek.sql).

**💻 Extrait de code** *(reconversion ciblée et sûre)*
```sql
FOR r IN SELECT ctid, maktx FROM raw_data.makt
         WHERE maktx ~ '[ÁÃÄÅÆÌÍÐÑÓÕÖ…]' OR maktx ~ '[^[:ascii:]]{3,}'
LOOP
  BEGIN
    converted := convert_from(convert_to(r.maktx,'LATIN1'),'ISO_8859_7');
    IF converted IS DISTINCT FROM r.maktx THEN
      UPDATE raw_data.makt SET maktx = converted WHERE ctid = r.ctid;
    END IF;
  EXCEPTION WHEN others THEN NULL;  -- ligne déjà en grec réel : ignorée
  END;
END LOOP;
```

**⚠️ Difficultés.** Colonne **mixte** (34 600 lignes grecques + 8 200 françaises correctes) → détection fine par homoglyphes ; idempotence indispensable (réexécutable sans dégât). Sauvegarde `makt_backup_encoding` avant traitement.

**💡 À approfondir.** Encodages ISO-8859-7 / Latin-1 / UTF-8, *mojibake*, idempotence, pagination + anti-injection (liste blanche de colonnes).

---

## Tâche 20 — Hiérarchie des postes techniques (vue IH02)

**Période :** avril · **Domaine :** Maintenance — Hiérarchie

**🎯 Objectif.** Reproduire la vue arborescente **IH02** de SAP avec chargement **paresseux** et recherche.

**🪜 Étapes réalisées.**
1. Endpoints racines / enfants à la demande.
2. Profondeur via **CTE récursif** ; désignation multilingue.
3. Recherche fédérée postes (`iflot`) + équipements (`itob`).

**📁 Fichiers.** [backend/api/ih02_hierarchy.py](backend/api/ih02_hierarchy.py), [frontend/src/pages/IH02HierarchyPage.tsx](frontend/src/pages/IH02HierarchyPage.tsx).

**💻 Extrait de code** *(CTE récursif de niveau)*
```sql
WITH RECURSIVE tree AS (
  SELECT tplnr, 0 AS lvl FROM raw_data.iflot WHERE tplma IS NULL OR TRIM(tplma)=''
  UNION ALL
  SELECT c.tplnr, t.lvl+1 FROM raw_data.iflot c JOIN tree t ON c.tplma = t.tplnr)
SELECT tplnr, lvl FROM tree;
```

**⚠️ Difficultés.** Table `iflo` (poste de travail PM) parfois **absente** de `raw_data` → détection dynamique (`_iflo_available`) et jointures adaptées ; textes `'vide'` à filtrer.

**💡 À approfondir.** *Lazy loading*, CTE récursifs, héritage hiérarchique d'attribut, recherche fédérée.

---

## Tâche 21 — Édition de la hiérarchie (drag & drop, CRUD, masse)

**Période :** avril · **Domaine :** Maintenance — Hiérarchie

**🎯 Objectif.** Arbre **éditable** : corriger, **déplacer par glisser-déposer**, créer/supprimer, modifier en masse — avec garde-fous.

**🪜 Étapes réalisées.**
1. `update-location` (désignation/parent/poste de travail) + validations `crhd`.
2. `move-node` avec **garde anti-cycle** (CTE descendants).
3. `add-node` / `delete-node` récursif / `bulk-update`.

**📁 Fichiers.** [backend/api/ih02_hierarchy.py](backend/api/ih02_hierarchy.py), [frontend/src/pages/IH02HierarchyPage.tsx](frontend/src/pages/IH02HierarchyPage.tsx).

**💻 Extrait de code** *(refus de créer un cycle)*
```sql
WITH RECURSIVE descendants AS (
  SELECT tplnr FROM raw_data.iflot WHERE tplnr=%s
  UNION ALL SELECT c.tplnr FROM raw_data.iflot c JOIN descendants d ON c.tplma=d.tplnr)
SELECT 1 FROM descendants WHERE tplnr=%s;  -- nouveau parent interdit s'il en fait partie
```

**⚠️ Difficultés.** Empêcher un déplacement sous son propre descendant (boucle infinie) ; ordre des suppressions (`iflotx`→`iflo`→`iflot`) ; cohérence du drag & drop côté React.

**💡 À approfondir.** Détection de cycle, déplacement de sous-arbre, opérations *set-based*. (Commits « avant le drag and drop » → « modification des équipement ».)

---

## Tâche 22 — Nomenclatures (BOM postes techniques & articles)

**Période :** avril–mai · **Domaine :** Maintenance — Nomenclatures

**🎯 Objectif.** Afficher/éditer les **nomenclatures** : composants d'un poste et nomenclature **matière récursive** d'un article.

**🪜 Étapes réalisées.**
1. Vue matérialisée pré-assemblant `tpst→stko→stpo`.
2. Dépliage récursif des articles (préférence site `9200`).
3. Édition d'une ligne (`stpo`+`makt`) + **refresh** de la vue.

**📁 Fichiers.** [backend/api/ih02_hierarchy.py](backend/api/ih02_hierarchy.py) (routes `/bom*`, `/article-bom*`), vue `clean_data.v_fl_nomenclature`.

**💻 Extrait de code** *(BOM matière préférée + dépliable)*
```sql
SELECT p.posnr, p.idnrk, LTRIM(p.idnrk,'0') AS matnr_short, p.menge, p.meins,
       COALESCE(mk.maktx, p.potx1) AS designation,
       (SELECT COUNT(*) FROM raw_data.stpo cp
        WHERE cp.stlty='M' AND cp.stlnr=bestc.stlnr) AS children_count
FROM raw_data.stpo p
LEFT JOIN LATERAL (SELECT stlnr FROM raw_data.mast WHERE matnr=p.idnrk
    ORDER BY (CASE WHEN werks='9200' THEN 0 ELSE 1 END) LIMIT 1) bestc ON TRUE
WHERE p.stlty='M' AND p.stlnr=%s;
```

**⚠️ Difficultés.** Récursivité multi-niveaux (article composé d'articles) → `children_count` par composant pour piloter le dépliage côté UI ; cohérence après édition → `REFRESH MATERIALIZED VIEW`.

**💡 À approfondir.** BOM poste (`stlty='T'`) vs matière (`stlty='M'`), vue matérialisée (perf vs fraîcheur).

---

## Tâche 23 — ETL `equipment_functional` + refactor (abandon `ih02_capgemini`)

**Période :** mai · **Domaine :** ETL / Maintenance

**🎯 Objectif.** Industrialiser la transformation postes/équipements vers `clean_data.equipment_functional` et **abandonner** la table externe `raw_data.ih02_capgemini` (~145 000 lignes) au profit des **tables SAP standard**.

**🪜 Étapes réalisées.**
1. CTE récursif de la hiérarchie + exclusion des objets **archivés** (`jest`).
2. Insertion **niveau par niveau** (parents avant enfants).
3. Suppression contrôlée de l'ancienne table Capgemini.

**📁 Fichiers.** [sql/maintenance/alimenter_equipment_functional.sql](sql/maintenance/alimenter_equipment_functional.sql), [backend/etl_modules/etl_equipment_functional.py](backend/etl_modules/etl_equipment_functional.py), [sql/maintenance/drop_ih02_capgemini.sql](sql/maintenance/drop_ih02_capgemini.sql).

**💻 Extrait de code** *(insertion niveau par niveau)*
```sql
FOR v_level IN 0..v_max_level LOOP
  INSERT INTO clean_data.equipment_functional (mch_code, sup_mch_code, obj_level, contract, ...)
  SELECT h.tplnr, h.tplma, h.level, 'SJ', ...
  FROM tmp_fl_hier h WHERE h.level = v_level;   -- parents déjà insérés
END LOOP;
```

**⚠️ Difficultés.** Respecter l'intégrité parent→enfant (d'où l'insertion par niveau) ; exclure les objets archivés (`jest.stat IN ('I0320','I0076')`) partagés par `iflot` et `itob` ; refactor sans régression → `DROP … IF EXISTS` **sans CASCADE** après vérif de dépendances.

**💡 À approfondir.** Schéma `raw_data → clean_data`, insertion par niveau, exclusion des archives, décision d'archi « référentiel externe → tables standard ».

---

## Tâche 24 — Export spécifique Maintenance (structures & équipements)

**Période :** mai · **Domaine :** Maintenance — Restitution

**🎯 Objectif.** Produire les **exports CSV** dédiés à la maintenance (structures de postes techniques, équipements) pour contrôle et chargement IFS.

**🪜 Étapes réalisées.**
1. Endpoint d'export CSV de la hiérarchie (séparateur `;`).
2. Statistiques par niveau (`/stats`).
3. Pages d'export maintenance côté front.

**📁 Fichiers.** [backend/api/ih02_hierarchy.py](backend/api/ih02_hierarchy.py) (`/export-structures`, `/stats`), [frontend/src/pages/ExportMaintenance.tsx](frontend/src/pages/ExportMaintenance.tsx), [frontend/src/pages/ExportStructureMaintenance.tsx](frontend/src/pages/ExportStructureMaintenance.tsx).

**💻 Extrait de code** *(streaming CSV en mémoire)*
```python
output = io.StringIO()
writer = csv.DictWriter(output, fieldnames=rows[0].keys(), delimiter=';')
writer.writeheader(); writer.writerows(rows)
return Response(output.getvalue(), mimetype='text/csv',
    headers={'Content-Disposition': 'attachment; filename=ih02_postes_techniques.csv'})
```

**⚠️ Difficultés.** Séparateur `;` pour compatibilité Excel FR ; agrégats par niveau via `COUNT(*) FILTER (WHERE lvl = N)`.

**💡 À approfondir.** Clause `FILTER`, streaming CSV (`io.StringIO`), formats attendus par IFS. (Commit « export node ».)

---

# PHASE 5 — Extraction, exploitation et mise en production

## Tâche 25 — Module d'extraction SAP

**Période :** mai · **Domaine :** Extraction

**🎯 Objectif.** **Comparer** les tables SAP configurées avec `raw_data`, **créer** la structure manquante, **lancer** une extraction.

**🪜 Étapes réalisées.**
1. Service d'extraction initialisé au démarrage de l'app.
2. Comparaison config ↔ `raw_data` (tables `missing`).
3. Création de structure (sans données) + lancement avec identité JWT.

**📁 Fichiers.** [backend/api/extraction.py](backend/api/extraction.py), [backend/services/extraction_service.py](backend/services/extraction_service.py), [frontend/src/pages/Extraction.tsx](frontend/src/pages/Extraction.tsx), [frontend/src/services/extractionService.ts](frontend/src/services/extractionService.ts).

**💻 Extrait de code** *(init du service via record_once)*
```python
@extraction_blueprint.record_once
def on_register(state):
    with state.app.app_context():
        extraction_service.initialize()   # before_app_first_request KO avec Blueprints
```

**⚠️ Difficultés.** `before_app_first_request` inopérant avec les Blueprints → contournement par `record_once` ; appels en mode démo sans token → repli `demo_user`.

**💡 À approfondir.** Cycle de vie d'un Blueprint, pattern *service*, comparaison de schéma (`information_schema`), JWT optionnel.

---

## Tâche 26 — Sauvegarde & rétention automatique de la base

**Période :** mai · **Domaine :** DevOps / Données

**🎯 Objectif.** Sécuriser les données par des **sauvegardes `pg_dump`** régulières, compressées, avec **rétention**.

**🪜 Étapes réalisées.**
1. Service de backup (dump par schéma ou base complète).
2. Compression + nommage horodaté.
3. Planification et purge au-delà de N jours.

**📁 Fichiers.** [backend/services/backup_service.py](backend/services/backup_service.py), `backend/services/backup_scheduler.py`, [backend/api/backup.py](backend/api/backup.py), [dump/exportDb.sh](dump/exportDb.sh), [dump/import.sh](dump/import.sh).

**💻 Extrait de code** *(construction de la commande pg_dump)*
```python
cmd = ["pg_dump", "-h", DB_HOST, "-p", DB_PORT, "-U", DB_USER, "-F", "c", "-b", "-v"]
for s in (schemas or []):
    cmd += ["-n", s]                 # dump ciblé par schéma
cmd += ["-f", filepath, DB_NAME]
```

**⚠️ Difficultés.** Mot de passe transmis via `PGPASSWORD` (env) pour éviter le prompt ; volume des dumps → compression `gzip` + rétention `BACKUP_RETENTION_DAYS=30` ; exécution non bloquante (`Thread`).

**💡 À approfondir.** Formats `pg_dump` (`-F c`), stratégie de rétention, planification (scheduler), restauration.

---

## Tâche 27 — Configuration système & e-mails (SMTP)

**Période :** mai · **Domaine :** Socle

**🎯 Objectif.** Externaliser la configuration (SharePoint, SMTP…) en base et envoyer les e-mails (réinitialisation de mot de passe, notifications).

**🪜 Étapes réalisées.**
1. Service de configuration lisant `public.system_config` (repli `.env`).
2. Page de paramètres + page de config SMTP.
3. Envoi d'e-mails via `smtplib`.

**📁 Fichiers.** [backend/services/config_service.py](backend/services/config_service.py), [backend/api/settings.py](backend/api/settings.py), [frontend/src/pages/SmtpConfigPage.tsx](frontend/src/pages/SmtpConfigPage.tsx), [frontend/src/pages/Parametres.tsx](frontend/src/pages/Parametres.tsx).

**💻 Extrait de code** *(config externalisée avec repli)*
```python
def get_config(key, default=None):
    row = query_one("SELECT value FROM public.system_config WHERE key = %s", [key])
    return row['value'] if row else os.getenv(key, default)
```

**⚠️ Difficultés.** Priorité paramètre explicite > base > `.env` > défaut ; secrets (mot de passe SMTP/SharePoint) à ne pas exposer côté API.

**💡 À approfondir.** Configuration externalisée, hiérarchie des sources de config, envoi SMTP sécurisé.

---

## Tâche 28 — Outillage SQL (compilation / déploiement des procédures)

**Période :** mai–juin · **Domaine :** DevOps / SQL

**🎯 Objectif.** Industrialiser le **déploiement des procédures stockées** par domaine (clients, fournisseurs, projets, maintenance…) de façon reproductible.

**🪜 Étapes réalisées.**
1. Scripts `compile.sh` exécutant les `.sql` d'un domaine **dans l'ordre**.
2. Scripts `export_procedures.sh` pour extraire les définitions existantes.
3. Vérification post-déploiement.

**📁 Fichiers.** [sql/maintenance/compile.sh](sql/maintenance/compile.sh), [sql/customer/compile.sh](sql/customer/compile.sh), [sql/projet/compile.sh](sql/projet/compile.sh), `*/export_procedures.sh`.

**💻 Extrait de code** *(compilation ordonnée — `compile.sh`)*
```bash
#!/bin/bash
for f in 01_*.sql 02_*.sql 03_*.sql alimenter_*.sql; do
  echo "→ $f"
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f "$f" || exit 1
done
```

**⚠️ Difficultés.** Ordre de dépendance entre procédures (numérotation `01_…08_`) ; arrêt sur erreur (`ON_ERROR_STOP=1`) pour ne pas déployer à moitié.

**💡 À approfondir.** Versionnage des procédures, idempotence (`CREATE OR REPLACE`), pipeline de déploiement DB.

---

## Tâche 29 — Tableau de bord & indicateurs

**Période :** juin · **Domaine :** Restitution

**🎯 Objectif.** Donner une **vue d'ensemble** de l'avancement de la migration (volumes par domaine, jobs récents).

**🪜 Étapes réalisées.**
1. Endpoints d'agrégats (comptages `raw_data` / `clean_data`).
2. Cartes d'indicateurs + derniers imports/exports.
3. Mise en forme MUI (cartes, graphiques).

**📁 Fichiers.** [frontend/src/pages/Dashboard.tsx](frontend/src/pages/Dashboard.tsx), [backend/api/data.py](backend/api/data.py).

**💻 Extrait de code** *(comptage multi-tables pour les KPIs)*
```sql
SELECT 'clients'      AS domaine, COUNT(*) FROM clean_data.customer_info
UNION ALL SELECT 'fournisseurs', COUNT(*) FROM clean_data.supplier_info
UNION ALL SELECT 'postes_tech',  COUNT(*) FROM clean_data.equipment_functional;
```

**⚠️ Difficultés.** Performance des comptages sur grosses tables → comptages approximatifs/caches ; cohérence des libellés de domaines.

**💡 À approfondir.** KPIs de migration, `COUNT` exact vs estimé (`pg_class.reltuples`), rafraîchissement.

---

## Tâche 30 — Déploiement Docker / Nginx & mise en production

**Période :** juin · **Domaine :** DevOps

**🎯 Objectif.** **Livrer** la plateforme : build des images, service via Nginx, scripts de déploiement.

**🪜 Étapes réalisées.**
1. `docker-compose` (backend Gunicorn, frontend build Vite, Nginx).
2. Scripts `deploybackend.sh` / `deployfrontend.sh`.
3. Configuration Nginx (reverse proxy `/api` → backend).

**📁 Fichiers.** [docker-compose.yml](docker-compose.yml), [deploybackend.sh](deploybackend.sh), [deployfrontend.sh](deployfrontend.sh), [nginx/deploy-nginx.sh](nginx/deploy-nginx.sh), [backend/start.sh](backend/start.sh), [frontend/startApp.sh](frontend/startApp.sh).

**💻 Extrait de code** *(lancement prod backend — `start.sh`)*
```bash
gunicorn -w 4 -b 0.0.0.0:5000 app:app --timeout 120
```

**⚠️ Difficultés.** Build frontend (Vite) puis service statique par Nginx ; reverse proxy `/api/v1` → backend ; variables d'environnement en prod (sans `.env` commité).

**💡 À approfondir.** Conteneurisation, reverse proxy Nginx, build multi-étapes, mise en production d'une appli temporaire.

---

## 3. Bilan et compétences acquises

**Compétences techniques.**
- **Backend Python/Flask** : API REST (Blueprints), JWT/RBAC, SQLAlchemy + `psycopg2`, services, e-mails SMTP.
- **SQL avancé PostgreSQL** : CTE **récursifs** (hiérarchies, anti-cycle), **PL/pgSQL**, vues **matérialisées**, jointures `LATERAL`, agrégats `FILTER`, gestion d'**encodage**, `pg_dump`.
- **Frontend React/TypeScript** : Material-UI, arbre *lazy* + drag & drop, assistants multi-étapes, tableaux de bord, Axios.
- **ETL & migration** : `raw_data → clean_data`, transcodification, field mapping, idempotence, échantillonnage, suivi ligne par ligne.
- **Intégration externe** : SharePoint (NTLM, OData), configuration externalisée.
- **DevOps** : Docker Compose, Nginx, scripts de déploiement, sauvegardes/rétention.
- **Données SAP** : tiers (KNA1/LFA1…), articles (MARA/MAKT), maintenance PM (IFLOT/ITOB/STPO…), DDIC.

**Compétences transverses.** Reprise d'un code existant à mi-projet, diagnostic de bugs de données réels (encodage), décisions d'architecture réversibles, souci de la **validation** avant chargement, industrialisation/reproductibilité.

**Difficultés transversales rencontrées.**
- **Qualité/hétérogénéité des données SAP** : encodages mixtes (grec/français), tables parfois absentes de l'extraction, libellés DDIC cryptiques.
- **Sources multiples → modèle cible unique** (filiale PHL, SharePoint) imposant transcodification et résolution d'identités.
- **Hiérarchies profondes** nécessitant des garde-fous (anti-cycle, insertion par niveau, validations référentielles).
- **Reprise en cours de projet** : comprendre vite un code volumineux (24 API, 58 pages) avant de contribuer.

---

> **Note de rédaction.** Pour le rapport final : page de garde (nom, entreprise, tuteur, période), présentation de l'entreprise, **captures d'écran** par tâche, et au moins deux **schémas** (architecture 3 schémas + flux ETL ; hiérarchie IH02). Chaque rubrique « 💡 À approfondir » indique le contenu à développer ; chaque rubrique « ⚠️ Difficultés » peut alimenter la partie « problèmes rencontrés et solutions » attendue dans un rapport de stage.
