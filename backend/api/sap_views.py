from flask import Blueprint, jsonify, request, current_app
from services.data_service import get_data_service
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy import text
import json

sap_views_blueprint = Blueprint('sap_views', __name__)

# Vues clean_data (prefixe v_) avec périmètre UI: fournisseur, article, client, achat, maintenance
# Utilisé par le paramètre GET ?scope=
SAP_VIEWS = [
    {
        "id": "v_coordonnees_bancaires_fournisseurs",
        "name": "v_coordonnees_bancaires_fournisseurs",
        "label": "Coordonnées bancaires fournisseurs",
        "scopes": ["fournisseur"],
    },
    {
        "id": "v_donnees_bancaires_fournisseurs",
        "name": "v_donnees_bancaires_fournisseurs",
        "label": "Données bancaires fournisseurs",
        "scopes": ["fournisseur"],
    },
    {
        "id": "v_donnees_banques",
        "name": "v_donnees_banques",
        "label": "Données des banques",
        "scopes": ["fournisseur"],
    },
    {
        "id": "v_donnees_fournisseurs_achats",
        "name": "v_donnees_fournisseurs_achats",
        "label": "Fournisseurs - Données achats",
        "scopes": ["fournisseur"],
    },
    {
        "id": "v_fournisseurs",
        "name": "v_fournisseurs",
        "label": "Fournisseurs - Vue générale",
        "scopes": ["fournisseur"],
    },
    {
        "id": "v_fournisseurs_enrichis",
        "name": "v_fournisseurs_enrichis",
        "label": "Fournisseurs - Vue enrichie",
        "scopes": ["fournisseur"],
    },
    {
        "id": "v_article",
        "name": "v_article",
        "label": "Articles - Vue générale",
        "scopes": ["article"],
    },
    {
        "id": "v_article_maintenance",
        "name": "v_article_maintenance",
        "label": "Articles - Données maintenance",
        "scopes": ["article"],
    },
    {
        "id": "v_article_production",
        "name": "v_article_production",
        "label": "Articles - Données production",
        "scopes": ["article"],
    },
    {
        "id": "v_article_achats",
        "name": "v_article_achats",
        "label": "Articles - Données achats",
        "scopes": ["article"],
    },
]

# Filtre catalogue tables (public.sap_table_properties) par thème
SAP_CATALOG_SCOPE_KEYWORDS = {
    "fournisseur": [
        "lfa1", "lfb1", "lfm1", "lfbk", "lfas", "lfm2", "lifnr", "vendor", "supplier", "fournisseur", "lieferant",
    ],
    "article": [
        "mara", "marc", "mard", "makt", "mast", "mbew", "marm", "mvke", "mlgn", "matnr", "article", "material", "matériel",
    ],
    "client": [
        "kna1", "knb1", "knvv", "knvk", "kunnr", "customer", "client", "debitor", "debiteur",
    ],
    "achat": [
        "ekko", "ekpo", "eban", "ekkn", "eket", "purchase", "achat", "bestell", "beschaff",
    ],
    "maintenance": [
        "equi", "eqkt", "equz", "iloa", "iflo", "itob", "tplnr", "equnr", "pm_", "inob", "ilink",
        "functional", "maintenance", "fleet",
        "ihpa", "jest", "jcds", "objk", "klah", "ksml", "ausp", "crhd", "t499s",
        "iflot", "iflos",
    ],
    "comptabilite": [
        # Documents et écritures FI
        "bkpf", "bseg", "bset", "bsas", "bds", "beb",
        # Postes ouverts / reglements
        "bsak", "bsad", "bsid", "bsik",
        # Plan comptable, centres de coûts CO (perimetre compta gestion)
        "ska1", "skb1", "skat", "skas", "skb",
        # GL / new GL
        "faglflex", "fagl", "glpc", "faglseg",
        # Paiements / rapprochement bancaire
        "reguh", "regup", "feb", "febep", "febko",
        # Immobilisations
        "anla", "anlz", "anlb", "anlp",
        # CO (écritures / centres)
        "coep", "coss", "cska", "csks", "cskt",
        # Libellés métier (descriptions / noms de tables)
        "comptab", "compta", "accounting", "buchhalt", "buchung", "financ",
        "general ledger", "gl account", "hauptbuch", "sachkonto", "journal",
        "ledger", "écriture", "ecriture", "debiteur", "debitor", "kreditor",
        "chart of accounts", "kontenplan", "offene posten",
    ],
}


def _public_view_entry(entry: dict) -> dict:
    return {k: v for k, v in entry.items() if k != "scopes"}


def _table_matches_scope(table_name: str, description: str, scope: str) -> bool:
    keywords = SAP_CATALOG_SCOPE_KEYWORDS.get(scope)
    if not keywords:
        return True
    hay = f"{table_name or ''} {description or ''}".lower()
    return any(kw in hay for kw in keywords)


@sap_views_blueprint.route('/sap-views', methods=['GET'])
def get_sap_views():
    """Récupère la liste des vues SAP disponibles.

    Query: scope=fournisseur|article|client|achat|maintenance|comptabilite — filtre le périmètre (cartes du menu).
    Sans scope: toutes les vues.
    """
    try:
        scope = (request.args.get("scope") or "").strip().lower()
        views = SAP_VIEWS
        if scope:
            views = [v for v in SAP_VIEWS if scope in v.get("scopes", [])]
        return jsonify([_public_view_entry(v) for v in views]), 200
    except Exception as e:
        current_app.logger.error(f"Erreur lors de la récupération des vues SAP: {str(e)}")
        return jsonify({"error": "Erreur lors de la récupération des vues SAP"}), 500

@sap_views_blueprint.route('/sap-views/<view_name>/columns', methods=['GET'])
def get_view_columns(view_name):
    """Récupère les colonnes d'une vue SAP"""
    try:
        data_service = get_data_service()
        
        # Utiliser clean_data au lieu de raw_data
        query = f"""
            SELECT column_name, data_type, 
                   coalesce(col_description((table_schema || '.' || table_name)::regclass, ordinal_position), column_name) as column_description
            FROM information_schema.columns 
            WHERE table_schema = 'clean_data' AND table_name = '{view_name}'
            ORDER BY ordinal_position
        """
        
        with data_service.engine.connect() as connection:
            result = connection.execute(text(query))
            columns = []
            for row in result:
                columns.append({
                    "name": row[0],
                    "type": row[1],
                    "label": row[2]
                })
            
            return jsonify(columns), 200
    except SQLAlchemyError as e:
        current_app.logger.error(f"Erreur SQL lors de la récupération des colonnes: {str(e)}")
        return jsonify({"error": f"Erreur lors de la récupération des colonnes de la vue {view_name}"}), 500
    except Exception as e:
        current_app.logger.error(f"Erreur lors de la récupération des colonnes: {str(e)}")
        return jsonify({"error": f"Erreur lors de la récupération des colonnes de la vue {view_name}"}), 500

@sap_views_blueprint.route('/sap-views/<view_name>/data', methods=['GET'])
def get_view_data(view_name):
    """Récupère les données d'une vue SAP avec pagination et tri"""
    try:
        # Récupérer les paramètres de pagination et de tri
        page = request.args.get('page', 1, type=int)
        page_size = request.args.get('pageSize', 25, type=int)
        sort_field = request.args.get('sortField', '')
        sort_direction = request.args.get('sortDirection', 'asc').upper()
        search_term = request.args.get('search', '')
        filters_json = request.args.get('filters', '')
        
        # Traiter les filtres si fournis (harmonisé avec l'implémentation IFS)
        filters = {}
        if filters_json:
            try:
                filters = json.loads(filters_json)
            except json.JSONDecodeError:
                current_app.logger.warning(f"Erreur de décodage JSON pour les filtres: {filters_json}")
        
        if sort_direction not in ['ASC', 'DESC']:
            sort_direction = 'ASC'
        
        data_service = get_data_service()
        
        # Calculer l'offset pour la pagination
        offset = (page - 1) * page_size
        
        # Construire la clause ORDER BY si un champ de tri est spécifié
        order_clause = ""
        if sort_field:
            order_clause = f'ORDER BY "{sort_field}" {sort_direction}'
        
        # Obtenir les informations sur les colonnes pour les filtres
        cols_query = f"""
            SELECT column_name, data_type
            FROM information_schema.columns 
            WHERE table_schema = 'clean_data' AND table_name = '{view_name}'
            ORDER BY ordinal_position
        """
        
        # Construire les conditions WHERE pour les filtres
        where_conditions = []
        filter_params = {}
        
        with data_service.engine.connect() as connection:
            # Récupérer les types de colonnes pour adapter les filtres
            cols_result = connection.execute(text(cols_query))
            columns_info = {col[0]: col[1] for col in cols_result}
            
            # Ajouter les conditions de filtre pour chaque champ
            if filters:
                for field, value in filters.items():
                    if field in columns_info:
                        # Créer un nom de paramètre sans espaces pour éviter les problèmes de liaison
                        param_name = f"filter_{field.replace(' ', '_')}"
                        
                        # Utiliser LIKE pour les champs texte
                        if 'char' in columns_info[field].lower() or 'text' in columns_info[field].lower():
                            where_conditions.append(f'CAST("{field}" AS TEXT) ILIKE :{param_name}')
                            filter_params[param_name] = f'%{value}%'
                        else:
                            # Pour les autres types, essayer une conversion en texte et recherche LIKE
                            where_conditions.append(f'CAST("{field}" AS TEXT) ILIKE :{param_name}')
                            filter_params[param_name] = f'%{value}%'
            
            # Ajouter la condition de recherche globale si présente
            if search_term:
                search_conditions = []
                for field in columns_info:
                    # Créer un nom de paramètre unique pour chaque champ dans la recherche
                    search_param_name = f"search_{field.replace(' ', '_')}"
                    
                    # Utiliser LIKE pour tous les champs (convertis en texte)
                    search_conditions.append(f'CAST("{field}" AS TEXT) ILIKE :{search_param_name}')
                    filter_params[search_param_name] = f'%{search_term}%'
                
                if search_conditions:
                    where_conditions.append(f"({' OR '.join(search_conditions)})")
            
            # Construire la clause WHERE complète
            where_clause = f"WHERE {' AND '.join(where_conditions)}" if where_conditions else ""
            
            # Construire les requêtes avec les filtres
            count_query = f'SELECT COUNT(*) FROM clean_data."{view_name}" {where_clause}'
            data_query = f'SELECT * FROM clean_data."{view_name}" {where_clause} {order_clause} LIMIT {page_size} OFFSET {offset}'
            
            # Exécuter la requête de comptage avec les paramètres de filtre
            count_result = connection.execute(text(count_query), filter_params)
            total_count = count_result.scalar()
            
            # Exécuter la requête principale avec les paramètres de filtre
            result = connection.execute(text(data_query), filter_params)
            
            # Récupérer les noms des colonnes
            columns = result.keys()
            
            # Convertir les données en dictionnaires
            rows = [dict(zip(columns, row)) for row in result]
            
            # Obtenir les informations sur les colonnes pour inclure leurs labels
            cols_query = f"""
                SELECT column_name, data_type, 
                       coalesce(col_description((table_schema || '.' || table_name)::regclass, ordinal_position), column_name) as column_description
                FROM information_schema.columns 
                WHERE table_schema = 'clean_data' AND table_name = '{view_name}'
                ORDER BY ordinal_position
            """
            
            cols_result = connection.execute(text(cols_query))
            column_info = []
            for col in cols_result:
                column_info.append({
                    "name": col[0],
                    "type": col[1],
                    "label": col[2]
                })
            
            # Construire la réponse
            response = {
                "columns": column_info,
                "rows": rows,
                "total": total_count,
                "page": page,
                "pageSize": page_size,
                "totalPages": (total_count + page_size - 1) // page_size
            }
            
            return jsonify(response), 200
    
    except SQLAlchemyError as e:
        current_app.logger.error(f"Erreur SQL lors de la récupération des données: {str(e)}")
        return jsonify({"error": f"Erreur lors de la récupération des données de la vue {view_name}"}), 500
    except Exception as e:
        current_app.logger.error(f"Erreur lors de la récupération des données: {str(e)}")
        return jsonify({"error": f"Erreur lors de la récupération des données de la vue {view_name}"}), 500

@sap_views_blueprint.route('/sap-catalog/tables', methods=['GET'])
def get_sap_catalog_tables():
    """Récupère la liste des tables SAP avec leurs métadonnées.

    Query optionnel: scope=fournisseur|article|client|achat|maintenance|comptabilite
    (filtre sur nom de table + description selon mots-clés métier).
    """
    try:
        data_service = get_data_service()
        scope = (request.args.get("scope") or "").strip().lower()

        query = """
            SELECT 
                table_name,
                table_class,
                client_dependent,
                master_language,
                content_flag,
                auth_class,
                main_flag,
                buffer_allowed,
                description,
                availableformapping,
                created_at
            FROM public.sap_table_properties
            ORDER BY table_name
        """
    
        with data_service.engine.connect() as connection:
            result = connection.execute(text(query))
            
            tables = []
            for row in result:
                tbl = {
                    "table_name": row[0],
                    "table_class": row[1],
                    "client_dependent": row[2],
                    "master_language": row[3],
                    "content_flag": row[4],
                    "auth_class": row[5],
                    "main_flag": row[6],
                    "buffer_allowed": row[7],
                    "description": row[8],
                    "availableformapping": row[9],
                    "created_at": row[10].isoformat() if row[10] else None
                }
                if scope and not _table_matches_scope(tbl["table_name"], tbl["description"], scope):
                    continue
                tables.append(tbl)
            
            return jsonify(tables), 200
    
    except SQLAlchemyError as e:
        current_app.logger.error(f"Erreur SQL lors de la récupération des tables SAP: {str(e)}")
        return jsonify({"error": "Erreur lors de la récupération des tables SAP"}), 500
    except Exception as e:
        current_app.logger.error(f"Erreur lors de la récupération des tables SAP: {str(e)}")
        return jsonify({"error": "Erreur lors de la récupération des tables SAP"}), 500

@sap_views_blueprint.route('/sap-catalog/tables/<table_name>/fields', methods=['GET'])
def get_sap_table_fields(table_name):
    """Récupère les champs d'une table SAP"""
    try:
        data_service = get_data_service()
        
        query = """
            SELECT 
                id,
                table_name,
                field_name,
                position,
                key_flag,
                mandatory,
                data_type,
                check_table,
                length,
                decimals,
                abap_type,
                field_text,
                header_text,
                long_description,
                created_at
            FROM public.sap_table_fields
            WHERE table_name = :table_name
            ORDER BY position
        """
        
        with data_service.engine.connect() as connection:
            result = connection.execute(text(query), {"table_name": table_name})
            
            fields = []
            for row in result:
                fields.append({
                    "id": row[0],
                    "table_name": row[1],
                    "field_name": row[2],
                    "position": row[3],
                    "key_flag": row[4],
                    "mandatory": row[5],
                    "data_type": row[6],
                    "check_table": row[7],
                    "length": row[8],
                    "decimals": row[9],
                    "abap_type": row[10],
                    "field_text": row[11],
                    "header_text": row[12],
                    "long_description": row[13],
                    "created_at": row[14].isoformat() if row[14] else None
                })
            
            return jsonify(fields), 200
    
    except SQLAlchemyError as e:
        current_app.logger.error(f"Erreur SQL lors de la récupération des champs: {str(e)}")
        return jsonify({"error": f"Erreur lors de la récupération des champs de {table_name}"}), 500
    except Exception as e:
        current_app.logger.error(f"Erreur lors de la récupération des champs: {str(e)}")
        return jsonify({"error": f"Erreur lors de la récupération des champs de {table_name}"}), 500