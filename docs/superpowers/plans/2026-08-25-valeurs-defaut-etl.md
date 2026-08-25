# Valeurs par défaut ETL paramétrables — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rendre les valeurs par défaut des tables d'export `clean_data` (module fournisseurs) éditables depuis un écran, sans redéploiement, via une table de paramètres + `public.get_default_value()`.

**Architecture:** Calque du pattern transcodification : table `public.etl_default_values` (seedée depuis `sql/supplier/inventaire_colonnes_valeurs_defaut.csv`) + fonction SQL `get_default_value(table, colonne, fallback, variante)` appelée dans les fonctions ETL à la place des littéraux (fallback = ancienne valeur en dur ⇒ zéro régression) + blueprint Flask CRUD + page React unique (précédent : `ReglesGestion.tsx` est mono-fichier).

**Tech Stack:** PostgreSQL/plpgsql, Flask + SQLAlchemy + flask-jwt-extended, React 18 + MUI + axios.

**Spec:** `docs/superpowers/specs/2026-08-25-valeurs-defaut-etl-design.md`

**Contraintes d'exécution (mémoire projet) :**
- Aucun `pip`/`pytest`/run Python applicatif en local. Tout ce qui touche la base ou le backend s'exécute sur le serveur `10.190.100.58` (`psql`, `docker-compose exec backend`). La génération de fichiers (script seed, stdlib uniquement) est OK en local.
- Vérification syntaxe frontend : esbuild dans le scratchpad (tsc ne vérifie rien) ; le succès s'écrit sur stderr, tester le **code de sortie**.
- Périmètre seed : `CONSTANTE_FORCEE` + `NULL_EXPLICITE` **hors colonnes techniques** (`created_by`, `updated_by`, `created_timestamp`, `updated_timestamp`, `is_deleted`) = 208 lignes + 1 clé logique `our_id_prefix`. Les colonnes techniques restent en dur (aucun intérêt métier à les paramétrer).

---

### Task 1 : Migration 031 — table `public.etl_default_values`

**Files:**
- Create: `migrations/031_create_etl_default_values.sql`

- [ ] **Step 1 : Écrire la migration (partie table)**

```sql
-- Migration 031 : table des valeurs par défaut ETL paramétrables
-- Pattern calqué sur la transcodification. Seed généré depuis
-- sql/supplier/inventaire_colonnes_valeurs_defaut.csv (voir Task 2).

CREATE TABLE IF NOT EXISTS public.etl_default_values (
    id            SERIAL PRIMARY KEY,
    module        VARCHAR(50)  NOT NULL,
    table_cible   VARCHAR(100) NOT NULL,
    colonne       VARCHAR(100) NOT NULL,
    variante      VARCHAR(30)  NOT NULL DEFAULT 'STANDARD',
    type_valeur   VARCHAR(20)  NOT NULL CHECK (type_valeur IN ('CONSTANTE','NULL')),
    valeur        TEXT,
    description   TEXT,
    is_active     BOOLEAN NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by    VARCHAR(50),
    updated_by    VARCHAR(50),
    CONSTRAINT uq_etl_default_values UNIQUE (table_cible, colonne, variante)
);

CREATE INDEX IF NOT EXISTS idx_edv_module ON public.etl_default_values(module);
CREATE INDEX IF NOT EXISTS idx_edv_table  ON public.etl_default_values(table_cible);

COMMENT ON TABLE public.etl_default_values IS
'Valeurs par défaut paramétrables injectées par les fonctions ETL via public.get_default_value(). Éditées depuis l''écran Configuration > Valeurs par défaut.';

-- Clé logique : constante intégrée dans une expression (03_alimenter_supplier_info_our_id.sql)
INSERT INTO public.etl_default_values (module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)
VALUES ('supplier', 'clean_data.supplier_info_our_id', 'our_id_prefix', 'STANDARD', 'CONSTANTE', 'TRIMET',
        'Préfixe de OUR_ID (concaténé : <prefixe>-<numero_compte_fournisseur>)', 'migration_031')
ON CONFLICT (table_cible, colonne, variante) DO NOTHING;

-- === SEED GÉNÉRÉ (Task 2) : coller ci-dessous le contenu de seed_supplier.sql ===
```

- [ ] **Step 2 : Commit**

```bash
git add migrations/031_create_etl_default_values.sql
git commit -m "feat(defaults): migration 031 table etl_default_values"
```

---

### Task 2 : Générateur de seed depuis l'inventaire CSV

**Files:**
- Create: `sql/config/generate_default_values_seed.py`
- Modify: `migrations/031_create_etl_default_values.sql` (append du seed généré)

- [ ] **Step 1 : Écrire le générateur (stdlib uniquement, exécutable en local)**

```python
#!/usr/bin/env python3
"""Génère les INSERT de seed pour public.etl_default_values depuis
sql/supplier/inventaire_colonnes_valeurs_defaut.csv.
Usage : python sql/config/generate_default_values_seed.py > /tmp/seed_supplier.sql
"""
import csv
import sys
from pathlib import Path

CSV_PATH = Path(__file__).resolve().parents[1] / 'supplier' / 'inventaire_colonnes_valeurs_defaut.csv'
TYPES_RETENUS = {'CONSTANTE_FORCEE': 'CONSTANTE', 'NULL_EXPLICITE': 'NULL'}
COLONNES_TECHNIQUES = {'created_by', 'updated_by', 'created_timestamp', 'updated_timestamp', 'is_deleted'}


def esc(s):
    return s.replace("'", "''")


def main():
    vus = set()
    lignes = []
    with open(CSV_PATH, encoding='utf-8-sig', newline='') as f:
        for row in csv.DictReader(f, delimiter=';'):
            type_v = TYPES_RETENUS.get(row['type_valeur_defaut'])
            if type_v is None or row['colonne'] in COLONNES_TECHNIQUES:
                continue
            cle = (row['table_cible'], row['colonne'], row['variante'])
            if cle in vus:
                continue
            vus.add(cle)
            valeur = 'NULL' if type_v == 'NULL' else "'" + esc(row['valeur_par_defaut']) + "'"
            desc = esc(f"Source : {row['script_source']} (type {row['type_valeur_defaut']})")
            lignes.append(
                "INSERT INTO public.etl_default_values "
                "(module, table_cible, colonne, variante, type_valeur, valeur, description, created_by)\n"
                f"VALUES ('supplier', '{esc(row['table_cible'])}', '{esc(row['colonne'])}', "
                f"'{esc(row['variante'])}', '{type_v}', {valeur}, '{desc}', 'migration_031')\n"
                "ON CONFLICT (table_cible, colonne, variante) DO NOTHING;"
            )
    print(f"-- Seed supplier : {len(lignes)} lignes générées depuis l'inventaire CSV")
    print('\n'.join(lignes))


if __name__ == '__main__':
    sys.exit(main())
```

- [ ] **Step 2 : Générer et vérifier le volume**

Run (Git Bash, racine du projet) :
```bash
python sql/config/generate_default_values_seed.py > "$TMPDIR/seed_supplier.sql" && head -3 "$TMPDIR/seed_supplier.sql" && grep -c "INSERT INTO" "$TMPDIR/seed_supplier.sql"
```
Expected : première ligne `-- Seed supplier : ~200 lignes...`, compteur entre **190 et 210** (208 lignes brutes moins les doublons table+colonne+variante).

- [ ] **Step 3 : Coller le seed généré à la fin de `migrations/031_create_etl_default_values.sql`** (sous le marqueur `=== SEED GÉNÉRÉ ===`).

- [ ] **Step 4 : Commit**

```bash
git add sql/config/generate_default_values_seed.py migrations/031_create_etl_default_values.sql
git commit -m "feat(defaults): generateur + seed supplier (~200 valeurs)"
```

---

### Task 3 : Fonction `public.get_default_value()`

**Files:**
- Create: `sql/functions/get_default_value.sql`

- [ ] **Step 1 : Écrire la fonction (même contrat que `get_transcodification` : jamais d'exception)**

```sql
-- =============================================================================
-- Fonction: get_default_value
-- Retourne la valeur par défaut paramétrée dans public.etl_default_values,
-- sinon p_fallback (valeur historique codée en dur). Ne lève JAMAIS d'exception.
--   type_valeur='CONSTANTE' -> valeur ; type_valeur='NULL' -> NULL ;
--   ligne absente/inactive/erreur -> p_fallback.
-- =============================================================================
CREATE OR REPLACE FUNCTION public.get_default_value(
    p_table    VARCHAR,
    p_colonne  VARCHAR,
    p_fallback TEXT DEFAULT NULL,
    p_variante VARCHAR DEFAULT 'STANDARD'
) RETURNS TEXT
LANGUAGE plpgsql STABLE
AS $$
DECLARE
    v_type   VARCHAR(20);
    v_valeur TEXT;
BEGIN
    SELECT type_valeur, valeur INTO v_type, v_valeur
    FROM public.etl_default_values
    WHERE table_cible = p_table AND colonne = p_colonne
      AND variante = p_variante AND is_active = TRUE;

    IF NOT FOUND THEN
        RETURN p_fallback;
    END IF;
    RETURN CASE WHEN v_type = 'NULL' THEN NULL ELSE v_valeur END;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'get_default_value(%, %, %) : % -> fallback', p_table, p_colonne, p_variante, SQLERRM;
        RETURN p_fallback;
END;
$$;

COMMENT ON FUNCTION public.get_default_value(VARCHAR, VARCHAR, TEXT, VARCHAR) IS
'Valeur par défaut ETL paramétrable (écran Configuration > Valeurs par défaut). Retourne p_fallback si non configurée.';
```

- [ ] **Step 2 : Jouer migration + fonction sur le serveur et tester les 3 cas**

Sur `10.190.100.58` (psql sur la base du projet) :
```bash
psql -f migrations/031_create_etl_default_values.sql
psql -f sql/functions/get_default_value.sql
psql -c "SELECT public.get_default_value('clean_data.ifs_fournisseurs','company','X') AS cas_constante,
                public.get_default_value('clean_data.supplier_info_general','party','X') AS cas_null,
                public.get_default_value('table.inexistante','col','FALLBACK') AS cas_fallback;"
```
Expected : `cas_constante = TRIMET` | `cas_null = NULL (vide)` | `cas_fallback = FALLBACK`.

- [ ] **Step 3 : Commit**

```bash
git add sql/functions/get_default_value.sql
git commit -m "feat(defaults): fonction public.get_default_value"
```

---

### Task 4 : Branchement ETL — script 03 (clé logique `our_id_prefix`)

**Files:**
- Modify: `sql/supplier/03_alimenter_supplier_info_our_id.sql:33`

- [ ] **Step 1 : Remplacer la constante intégrée dans l'expression**

Avant (ligne 33) :
```sql
        'TRIMET'||'-'||f.numero_compte_fournisseur as our_id,
```
Après :
```sql
        public.get_default_value('clean_data.supplier_info_our_id', 'our_id_prefix', 'TRIMET')||'-'||f.numero_compte_fournisseur as our_id,
```

- [ ] **Step 2 : Commit**

```bash
git add sql/supplier/03_alimenter_supplier_info_our_id.sql
git commit -m "feat(defaults): our_id_prefix parametrable (script 03)"
```

---

### Task 5 : Branchement ETL — les 13 autres scripts supplier

**Files:**
- Modify: `sql/supplier/01_alimenter_ifs_fournisseurs.sql`, `02_alimenter_supplier_info_general.sql`, `04_alimenter_supplier_info_address.sql`, `05_insert_supplier_address_types.sql`, `06_alimenter_comm_method.sql`, `07_alimenter_supplier_address.sql`, `08_insert_supplier_document_tax_info.sql`, `09_sp_insert_supplier_from_sap.sql`, `10_sp_insert_identity_invoice_info_from_sap.sql`, `11_sp_insert_identity_pay_info_from_sap.sql`, `12_fn_upsert_payment_way_per_identity.sql`, `14_fn_upsert_payment_address.sql`, `15_fn_upsert_supplier_tax_info.sql`

Un commit **par script**. Pour chaque script, lister ses remplacements depuis l'inventaire :

```bash
awk -F';' -v s="NOM_DU_SCRIPT.sql" '($4=="CONSTANTE_FORCEE"||$4=="NULL_EXPLICITE") && $7==s && $3!~/^(created_by|updated_by|created_timestamp|updated_timestamp|is_deleted)$/ {print $1" | "$2" | "$3" | "$4" | "$5}' sql/supplier/inventaire_colonnes_valeurs_defaut.csv
```

**Règle mécanique de remplacement** (`<t>` = table_cible, `<c>` = colonne, `<var>` = variante si ≠ STANDARD) :

| Cas dans le script | Avant | Après |
|---|---|---|
| Constante texte | `'FR' as default_language` | `public.get_default_value('<t>', 'default_language', 'FR') as default_language` |
| Booléen sans quotes | `FALSE as is_deleted`→ *(technique : ne pas toucher)* ; `FALSE as b2b_supplier` (colonne texte) | `public.get_default_value('<t>', 'b2b_supplier', 'FALSE') as b2b_supplier` |
| Booléen typé boolean | `TRUE as default_domain` | `public.get_default_value('<t>', 'default_domain', 'TRUE')::boolean as default_domain` |
| NULL explicite typé | `NULL::NUMERIC(20) as comm_id` | `public.get_default_value('<t>', 'comm_id', NULL)::NUMERIC(20) as comm_id` |
| Variante ≠ STANDARD (ex. 06_comm_method, blocs E_MAIL/FAX/PHONE ; 05_address_types) | `'PHONE' as method_id` (dans le bloc PHONE) | `public.get_default_value('<t>', 'method_id', 'PHONE', 'PHONE') as method_id` |

Règles impératives :
1. Le **fallback est TOUJOURS l'ancienne valeur en dur** — jamais NULL pour une constante.
2. Vérifier le type réel de la colonne cible (`information_schema.columns`) avant d'ajouter un cast ; les colonnes texte n'en ont pas besoin.
3. Ne toucher **ni** aux colonnes techniques (`created_by`, `updated_by`, `created_timestamp`, `updated_timestamp`, `is_deleted`) **ni** aux types `REGLE_CONDITIONNELLE`/`DYNAMIQUE`/`FALLBACK`/`AUCUNE_VALEUR_PAR_DEFAUT`.
4. Ne pas modifier les littéraux utilisés dans des `WHERE`/`ON CONFLICT`/clés de jointure — uniquement les valeurs projetées dans les `INSERT ... SELECT`.

- [ ] **Step 1..13 : Pour chaque script (ordre 01, 02, 04, 05, 06, 07, 08, 09, 10, 11, 12, 14, 15)** : lister ses lignes avec la commande awk, appliquer la règle, puis :

```bash
git add sql/supplier/NN_xxx.sql
git commit -m "feat(defaults): branchement get_default_value script NN"
```

- [ ] **Step 14 : Recompiler les fonctions sur le serveur et vérifier l'iso-résultat**

Sur le serveur :
```bash
psql -f sql/supplier/01_alimenter_ifs_fournisseurs.sql   # idem pour chaque script modifié (ou ./compile.sh s'il ne fait que des CREATE OR REPLACE)
psql -c "SELECT clean_data.alimenter_ifs_fournisseurs();" # puis la chaîne 02..08 comme d'habitude
```
Expected : mêmes comptages `RAISE NOTICE` qu'avant modification (config seedée = valeurs historiques ⇒ résultat identique). Test de bout en bout du paramétrage :
```bash
psql -c "UPDATE public.etl_default_values SET valeur='TRIMET2', updated_by='test' WHERE colonne='our_id_prefix';"
psql -c "SELECT clean_data.alimenter_supplier_info_our_id();"
psql -c "SELECT our_id FROM clean_data.supplier_info_our_id LIMIT 3;"   -- Expected : TRIMET2-xxxxx
psql -c "UPDATE public.etl_default_values SET valeur='TRIMET' WHERE colonne='our_id_prefix';"
psql -c "SELECT clean_data.alimenter_supplier_info_our_id();"
```

---

### Task 6 : Modèle SQLAlchemy `EtlDefaultValue`

**Files:**
- Create: `backend/models/etl_default_value.py`
- Modify: `backend/models/__init__.py` (export du modèle, même forme que `Transcodification`)

- [ ] **Step 1 : Écrire le modèle**

```python
from . import db
from datetime import datetime
from sqlalchemy import UniqueConstraint, Index


class EtlDefaultValue(db.Model):
    """Valeur par défaut ETL paramétrable (écran Configuration > Valeurs par défaut)"""
    __tablename__ = 'etl_default_values'
    __table_args__ = (
        UniqueConstraint('table_cible', 'colonne', 'variante', name='uq_etl_default_values'),
        Index('idx_edv_module', 'module'),
        Index('idx_edv_table', 'table_cible'),
        {'schema': 'public'}
    )

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    module = db.Column(db.String(50), nullable=False)
    table_cible = db.Column(db.String(100), nullable=False)
    colonne = db.Column(db.String(100), nullable=False)
    variante = db.Column(db.String(30), nullable=False, default='STANDARD')
    type_valeur = db.Column(db.String(20), nullable=False)  # CONSTANTE | NULL
    valeur = db.Column(db.Text)
    description = db.Column(db.Text)
    is_active = db.Column(db.Boolean, nullable=False, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    created_by = db.Column(db.String(50))
    updated_by = db.Column(db.String(50))

    def to_dict(self):
        return {
            'id': self.id,
            'module': self.module,
            'table_cible': self.table_cible,
            'colonne': self.colonne,
            'variante': self.variante,
            'type_valeur': self.type_valeur,
            'valeur': self.valeur,
            'description': self.description,
            'is_active': self.is_active,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None,
            'created_by': self.created_by,
            'updated_by': self.updated_by,
        }
```

- [ ] **Step 2 : Exporter dans `backend/models/__init__.py`** — ajouter, à côté de l'import de `Transcodification` :

```python
from .etl_default_value import EtlDefaultValue
```

- [ ] **Step 3 : Commit**

```bash
git add backend/models/etl_default_value.py backend/models/__init__.py
git commit -m "feat(defaults): modele EtlDefaultValue"
```

---

### Task 7 : Blueprint API `/api/v1/config/default-values`

**Files:**
- Create: `backend/api/default_values.py`
- Modify: `backend/api/__init__.py` (import + register, à côté du blueprint transcodification, préfixe `f'{API_PREFIX}/config'`)

- [ ] **Step 1 : Écrire le blueprint** (JWT **activé**, contrairement aux routes transcodification héritées ; pas de POST/DELETE en v1)

```python
from flask import Blueprint, request, jsonify, current_app
from flask_jwt_extended import jwt_required, get_jwt_identity
from sqlalchemy.exc import SQLAlchemyError

from models import db, EtlDefaultValue

default_values_blueprint = Blueprint('default_values', __name__)


@default_values_blueprint.route('/default-values', methods=['GET'])
@jwt_required()
def list_default_values():
    """Liste paginée + filtres module / table_cible / colonne (partiel) / is_active"""
    try:
        page = request.args.get('page', 1, type=int)
        per_page = min(request.args.get('per_page', 25, type=int), 100)
        query = EtlDefaultValue.query
        if request.args.get('module'):
            query = query.filter(EtlDefaultValue.module == request.args['module'])
        if request.args.get('table_cible'):
            query = query.filter(EtlDefaultValue.table_cible == request.args['table_cible'])
        if request.args.get('colonne'):
            query = query.filter(EtlDefaultValue.colonne.ilike(f"%{request.args['colonne']}%"))
        if request.args.get('is_active') in ('true', 'false'):
            query = query.filter(EtlDefaultValue.is_active == (request.args['is_active'] == 'true'))
        query = query.order_by(EtlDefaultValue.table_cible, EtlDefaultValue.colonne, EtlDefaultValue.variante)
        pagination = query.paginate(page=page, per_page=per_page, error_out=False)
        return jsonify({
            'default_values': [v.to_dict() for v in pagination.items],
            'total': pagination.total,
            'page': page,
            'per_page': per_page,
            'pages': pagination.pages,
        }), 200
    except SQLAlchemyError as e:
        current_app.logger.error(f"Erreur liste default-values: {e}")
        return jsonify({"error": "Erreur lors de la récupération des valeurs par défaut"}), 500


@default_values_blueprint.route('/default-values/meta', methods=['GET'])
@jwt_required()
def default_values_meta():
    """Modules et tables distincts pour alimenter les filtres de l'écran"""
    try:
        modules = [r[0] for r in db.session.query(EtlDefaultValue.module).distinct().order_by(EtlDefaultValue.module)]
        tables = [
            {'module': r[0], 'table_cible': r[1]}
            for r in db.session.query(EtlDefaultValue.module, EtlDefaultValue.table_cible)
            .distinct().order_by(EtlDefaultValue.module, EtlDefaultValue.table_cible)
        ]
        return jsonify({'modules': modules, 'tables': tables}), 200
    except SQLAlchemyError as e:
        current_app.logger.error(f"Erreur meta default-values: {e}")
        return jsonify({"error": "Erreur lors de la récupération des métadonnées"}), 500


@default_values_blueprint.route('/default-values/<int:value_id>', methods=['PUT'])
@jwt_required()
def update_default_value(value_id):
    """Champs modifiables : valeur, type_valeur, description, is_active. updated_by = identité JWT."""
    try:
        dv = EtlDefaultValue.query.get(value_id)
        if dv is None:
            return jsonify({"error": "Valeur par défaut introuvable"}), 404
        data = request.get_json() or {}
        if 'type_valeur' in data:
            if data['type_valeur'] not in ('CONSTANTE', 'NULL'):
                return jsonify({"error": "type_valeur doit être CONSTANTE ou NULL"}), 400
            dv.type_valeur = data['type_valeur']
        if 'valeur' in data:
            dv.valeur = None if dv.type_valeur == 'NULL' else data['valeur']
        if 'description' in data:
            dv.description = data['description']
        if 'is_active' in data:
            dv.is_active = bool(data['is_active'])
        dv.updated_by = get_jwt_identity()
        db.session.commit()
        return jsonify(dv.to_dict()), 200
    except SQLAlchemyError as e:
        db.session.rollback()
        current_app.logger.error(f"Erreur update default-value {value_id}: {e}")
        return jsonify({"error": "Erreur lors de la mise à jour"}), 500
```

- [ ] **Step 2 : Enregistrer dans `backend/api/__init__.py`** — à côté des lignes existantes (13 et 57) :

```python
from .default_values import default_values_blueprint
# ...
app.register_blueprint(default_values_blueprint, url_prefix=f'{API_PREFIX}/config')
```

- [ ] **Step 3 : Vérifier la syntaxe (compilation Python locale autorisée, pas d'exécution applicative)**

```bash
python -m py_compile backend/api/default_values.py backend/models/etl_default_value.py
```
Expected : code de sortie 0, aucune sortie.

- [ ] **Step 4 : Commit**

```bash
git add backend/api/default_values.py backend/api/__init__.py
git commit -m "feat(defaults): API CRUD /config/default-values (JWT actif)"
```

---

### Task 8 : Service frontend `defaultValueService.ts`

**Files:**
- Create: `frontend/src/services/defaultValueService.ts`

- [ ] **Step 1 : Écrire le service (mêmes conventions que `transcodificationService.ts` : `import api from './api'`)**

```typescript
import api from './api';

export interface EtlDefaultValue {
  id: number;
  module: string;
  table_cible: string;
  colonne: string;
  variante: string;
  type_valeur: 'CONSTANTE' | 'NULL';
  valeur: string | null;
  description?: string | null;
  is_active: boolean;
  created_at?: string;
  updated_at?: string;
  created_by?: string;
  updated_by?: string;
}

export interface DefaultValueListResponse {
  default_values: EtlDefaultValue[];
  total: number;
  page: number;
  per_page: number;
  pages: number;
}

export interface DefaultValueMeta {
  modules: string[];
  tables: { module: string; table_cible: string }[];
}

export interface DefaultValueFilters {
  page?: number;
  per_page?: number;
  module?: string;
  table_cible?: string;
  colonne?: string;
  is_active?: string; // 'true' | 'false' | ''
}

const defaultValueService = {
  list: async (filters: DefaultValueFilters): Promise<DefaultValueListResponse> => {
    const params = Object.fromEntries(
      Object.entries(filters).filter(([, v]) => v !== undefined && v !== '')
    );
    const { data } = await api.get('/config/default-values', { params });
    return data;
  },

  meta: async (): Promise<DefaultValueMeta> => {
    const { data } = await api.get('/config/default-values/meta');
    return data;
  },

  update: async (
    id: number,
    payload: Partial<Pick<EtlDefaultValue, 'valeur' | 'type_valeur' | 'description' | 'is_active'>>
  ): Promise<EtlDefaultValue> => {
    const { data } = await api.put(`/config/default-values/${id}`, payload);
    return data;
  },
};

export default defaultValueService;
```

- [ ] **Step 2 : Commit**

```bash
git add frontend/src/services/defaultValueService.ts
git commit -m "feat(defaults): service frontend defaultValueService"
```

---

### Task 9 : Page « Valeurs par défaut »

**Files:**
- Create: `frontend/src/pages/DefaultValuesManagement.tsx` (mono-fichier : filtres + tableau + dialog — précédent `ReglesGestion.tsx`)

- [ ] **Step 1 : Écrire la page**

```tsx
import React, { useCallback, useEffect, useState } from 'react';
import {
  Alert, Box, Button, Chip, Dialog, DialogActions, DialogContent, DialogTitle,
  FormControl, FormControlLabel, Checkbox, InputLabel, MenuItem, Paper, Select,
  Switch, Table, TableBody, TableCell, TableContainer, TableHead, TablePagination,
  TableRow, TextField, Typography, Snackbar,
} from '@mui/material';
import EditIcon from '@mui/icons-material/Edit';
import defaultValueService, {
  DefaultValueMeta, EtlDefaultValue,
} from '../services/defaultValueService';

const DefaultValuesManagement: React.FC = () => {
  const [rows, setRows] = useState<EtlDefaultValue[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(0);
  const [perPage, setPerPage] = useState(25);
  const [meta, setMeta] = useState<DefaultValueMeta>({ modules: [], tables: [] });
  const [filtreModule, setFiltreModule] = useState('');
  const [filtreTable, setFiltreTable] = useState('');
  const [filtreColonne, setFiltreColonne] = useState('');
  const [filtreActif, setFiltreActif] = useState('');
  const [edition, setEdition] = useState<EtlDefaultValue | null>(null);
  const [valeurEdit, setValeurEdit] = useState('');
  const [descriptionEdit, setDescriptionEdit] = useState('');
  const [estNull, setEstNull] = useState(false);
  const [message, setMessage] = useState<{ texte: string; type: 'success' | 'error' } | null>(null);

  const charger = useCallback(async () => {
    try {
      const data = await defaultValueService.list({
        page: page + 1, per_page: perPage, module: filtreModule,
        table_cible: filtreTable, colonne: filtreColonne, is_active: filtreActif,
      });
      setRows(data.default_values);
      setTotal(data.total);
    } catch {
      setMessage({ texte: 'Erreur lors du chargement des valeurs par défaut', type: 'error' });
    }
  }, [page, perPage, filtreModule, filtreTable, filtreColonne, filtreActif]);

  useEffect(() => { charger(); }, [charger]);
  useEffect(() => { defaultValueService.meta().then(setMeta).catch(() => undefined); }, []);

  const ouvrirEdition = (row: EtlDefaultValue) => {
    setEdition(row);
    setValeurEdit(row.valeur ?? '');
    setDescriptionEdit(row.description ?? '');
    setEstNull(row.type_valeur === 'NULL');
  };

  const enregistrer = async () => {
    if (!edition) return;
    try {
      await defaultValueService.update(edition.id, {
        type_valeur: estNull ? 'NULL' : 'CONSTANTE',
        valeur: estNull ? null : valeurEdit,
        description: descriptionEdit,
      });
      setMessage({ texte: 'Valeur mise à jour', type: 'success' });
      setEdition(null);
      charger();
    } catch {
      setMessage({ texte: 'Erreur lors de la mise à jour', type: 'error' });
    }
  };

  const basculerActif = async (row: EtlDefaultValue) => {
    try {
      await defaultValueService.update(row.id, { is_active: !row.is_active });
      charger();
    } catch {
      setMessage({ texte: "Erreur lors du changement d'état", type: 'error' });
    }
  };

  const estBooleenDb = edition?.colonne.endsWith('_db') &&
    ['TRUE', 'FALSE'].includes((edition?.valeur ?? '').toUpperCase());

  return (
    <Box sx={{ p: 3 }}>
      <Typography variant="h4" gutterBottom>Valeurs par défaut ETL</Typography>
      <Alert severity="info" sx={{ mb: 2 }}>
        Les modifications s'appliquent au <strong>prochain chargement ETL</strong> du module :
        les données déjà chargées ne sont pas modifiées, il faut relancer le chargement.
      </Alert>

      <Paper sx={{ p: 2, mb: 2, display: 'flex', gap: 2, flexWrap: 'wrap' }}>
        <FormControl size="small" sx={{ minWidth: 160 }}>
          <InputLabel>Module</InputLabel>
          <Select value={filtreModule} label="Module"
            onChange={(e) => { setFiltreModule(e.target.value); setFiltreTable(''); setPage(0); }}>
            <MenuItem value="">Tous</MenuItem>
            {meta.modules.map((m) => <MenuItem key={m} value={m}>{m}</MenuItem>)}
          </Select>
        </FormControl>
        <FormControl size="small" sx={{ minWidth: 280 }}>
          <InputLabel>Table cible</InputLabel>
          <Select value={filtreTable} label="Table cible"
            onChange={(e) => { setFiltreTable(e.target.value); setPage(0); }}>
            <MenuItem value="">Toutes</MenuItem>
            {meta.tables
              .filter((t) => !filtreModule || t.module === filtreModule)
              .map((t) => <MenuItem key={t.table_cible} value={t.table_cible}>{t.table_cible}</MenuItem>)}
          </Select>
        </FormControl>
        <TextField size="small" label="Colonne" value={filtreColonne}
          onChange={(e) => { setFiltreColonne(e.target.value); setPage(0); }} />
        <FormControl size="small" sx={{ minWidth: 140 }}>
          <InputLabel>Statut</InputLabel>
          <Select value={filtreActif} label="Statut"
            onChange={(e) => { setFiltreActif(e.target.value); setPage(0); }}>
            <MenuItem value="">Tous</MenuItem>
            <MenuItem value="true">Actif</MenuItem>
            <MenuItem value="false">Inactif</MenuItem>
          </Select>
        </FormControl>
      </Paper>

      <TableContainer component={Paper}>
        <Table size="small">
          <TableHead>
            <TableRow>
              <TableCell>Table</TableCell>
              <TableCell>Colonne</TableCell>
              <TableCell>Variante</TableCell>
              <TableCell>Type</TableCell>
              <TableCell>Valeur</TableCell>
              <TableCell>Description</TableCell>
              <TableCell>Actif</TableCell>
              <TableCell>Modifié</TableCell>
              <TableCell />
            </TableRow>
          </TableHead>
          <TableBody>
            {rows.map((row) => (
              <TableRow key={row.id} hover>
                <TableCell>{row.table_cible}</TableCell>
                <TableCell>{row.colonne}</TableCell>
                <TableCell>{row.variante !== 'STANDARD' ? row.variante : ''}</TableCell>
                <TableCell>
                  <Chip size="small" label={row.type_valeur}
                    color={row.type_valeur === 'NULL' ? 'default' : 'primary'} variant="outlined" />
                </TableCell>
                <TableCell>{row.type_valeur === 'NULL' ? <em>NULL</em> : row.valeur}</TableCell>
                <TableCell sx={{ maxWidth: 280, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                  {row.description}
                </TableCell>
                <TableCell>
                  <Switch size="small" checked={row.is_active} onChange={() => basculerActif(row)} />
                </TableCell>
                <TableCell>
                  {row.updated_by ? `${row.updated_by} — ${row.updated_at?.slice(0, 16).replace('T', ' ')}` : ''}
                </TableCell>
                <TableCell>
                  <Button size="small" startIcon={<EditIcon />} onClick={() => ouvrirEdition(row)}>
                    Éditer
                  </Button>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
        <TablePagination component="div" count={total} page={page} rowsPerPage={perPage}
          rowsPerPageOptions={[25, 50, 100]}
          onPageChange={(_, p) => setPage(p)}
          onRowsPerPageChange={(e) => { setPerPage(parseInt(e.target.value, 10)); setPage(0); }} />
      </TableContainer>

      <Dialog open={edition !== null} onClose={() => setEdition(null)} maxWidth="sm" fullWidth>
        <DialogTitle>Modifier la valeur par défaut</DialogTitle>
        <DialogContent sx={{ display: 'flex', flexDirection: 'column', gap: 2, mt: 1 }}>
          <TextField label="Table" value={edition?.table_cible ?? ''} disabled size="small" />
          <TextField label="Colonne" value={edition?.colonne ?? ''} disabled size="small" />
          <TextField label="Variante" value={edition?.variante ?? ''} disabled size="small" />
          <FormControlLabel
            control={<Checkbox checked={estNull} onChange={(e) => setEstNull(e.target.checked)} />}
            label="NULL explicite (aucune valeur insérée)" />
          {!estNull && (estBooleenDb ? (
            <FormControl size="small">
              <InputLabel>Valeur</InputLabel>
              <Select value={valeurEdit} label="Valeur" onChange={(e) => setValeurEdit(e.target.value)}>
                <MenuItem value="TRUE">TRUE</MenuItem>
                <MenuItem value="FALSE">FALSE</MenuItem>
              </Select>
            </FormControl>
          ) : (
            <TextField label="Valeur" value={valeurEdit} size="small"
              onChange={(e) => setValeurEdit(e.target.value)} />
          ))}
          <TextField label="Description" value={descriptionEdit} multiline minRows={2} size="small"
            onChange={(e) => setDescriptionEdit(e.target.value)} />
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setEdition(null)}>Annuler</Button>
          <Button variant="contained" onClick={enregistrer}>Enregistrer</Button>
        </DialogActions>
      </Dialog>

      <Snackbar open={message !== null} autoHideDuration={4000} onClose={() => setMessage(null)}>
        <Alert severity={message?.type ?? 'success'} onClose={() => setMessage(null)}>
          {message?.texte}
        </Alert>
      </Snackbar>
    </Box>
  );
};

export default DefaultValuesManagement;
```

- [ ] **Step 2 : Commit**

```bash
git add frontend/src/pages/DefaultValuesManagement.tsx
git commit -m "feat(defaults): ecran Valeurs par defaut ETL"
```

---

### Task 10 : Route + entrée de menu

**Files:**
- Modify: `frontend/src/App.tsx` (import + route, à côté de la route `transcodification`, ~ligne 240)
- Modify: `frontend/src/components/Layout/Sidebar.tsx` (entrée sous « Transcodification », ~ligne 32)

- [ ] **Step 1 : Route dans `App.tsx`**

```tsx
import DefaultValuesManagement from './pages/DefaultValuesManagement';
// ... dans le bloc des routes Configuration :
<Route path="configuration/valeurs-defaut" element={<DefaultValuesManagement />} />
```

- [ ] **Step 2 : Entrée Sidebar** (après le bloc Transcodification, même style ; `TuneIcon` déjà importé)

```tsx
<ListItem button component={Link} to="/configuration/valeurs-defaut">
  <ListItemIcon>
    <TuneIcon sx={{ color: '#FFF' }} />
  </ListItemIcon>
  <ListItemText primary="Valeurs par défaut" />
</ListItem>
```

- [ ] **Step 3 : Vérifier la syntaxe avec esbuild (scratchpad) — tester le CODE DE SORTIE, le succès s'écrit sur stderr**

```bash
cd frontend && npx --yes esbuild src/pages/DefaultValuesManagement.tsx src/services/defaultValueService.ts --loader:.tsx=tsx --loader:.ts=ts --bundle --outfile=/dev/null --external:react --external:react-dom --external:@mui/* --external:axios --external:react-router-dom; echo "exit=$?"
```
Expected : `exit=0`.

- [ ] **Step 4 : Commit**

```bash
git add frontend/src/App.tsx frontend/src/components/Layout/Sidebar.tsx
git commit -m "feat(defaults): route + menu Valeurs par defaut"
```

---

### Task 11 : Déploiement + vérification de bout en bout (serveur)

- [ ] **Step 1 : Déployer** — sur le serveur : `./deploybackend.sh` puis `./deployfrontend.sh` (vérifier que le conteneur backend est bien **recréé**, piège connu du script). Santé : `curl -s 127.0.0.1:5000/health` et `curl -s -o /dev/null -w '%{http_code}' 127.0.0.1:3100` → 200.

- [ ] **Step 2 : Test API** (avec un token JWT valide) :

```bash
curl -s -H "Authorization: Bearer $TOKEN" "http://127.0.0.1:5000/api/v1/config/default-values?module=supplier&per_page=5"
```
Expected : JSON `{"default_values":[...],"total":~200,...}` ; sans token → 401.

- [ ] **Step 3 : Test écran** — ouvrir `/configuration/valeurs-defaut` (port 8081) : filtres opérationnels, édition d'une valeur (ex. `default_language` FR→EN), vérifier `updated_by` renseigné, puis relancer le chargement supplier et contrôler la nouvelle valeur dans `clean_data.supplier_info_general`. Remettre FR ensuite.

- [ ] **Step 4 : Mettre à jour `CLAUDE.md`** — section « Points d'attention », ajouter :

```markdown
- **Valeurs par défaut ETL** (migration 031, écran `/configuration/valeurs-defaut`) : les constantes des fonctions ETL supplier passent par `public.get_default_value(table, colonne, fallback[, variante])` (fallback = ancienne valeur en dur). Étendre un module = générer l'inventaire CSV (cf. `sql/config/generate_default_values_seed.py`) + seed + remplacement des littéraux. Les changements ne s'appliquent qu'au prochain chargement ETL.
```

- [ ] **Step 5 : Commit final**

```bash
git add CLAUDE.md
git commit -m "docs: valeurs par defaut ETL parametrables"
```
