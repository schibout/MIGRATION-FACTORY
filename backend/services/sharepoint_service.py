"""
Service pour importer les données depuis l'API SharePoint vers les tables raw_data existantes
"""

import requests
from requests_ntlm import HttpNtlmAuth
import logging
from typing import Dict, List, Any, Optional
from datetime import datetime
import json
import psycopg2
import psycopg2.extras
import os
from config.database import get_db_connection
from services.config_service import get_config

logger = logging.getLogger(__name__)

class SharePointService:
    """Service pour importer les projets SharePoint vers les tables raw_data existantes"""

    def __init__(self, sharepoint_base_url: str = None):
        # URL et credentials lus depuis public.system_config (page Paramètres),
        # avec fallback sur .env, puis valeur par défaut.
        # Un paramètre explicite passé au constructeur reste prioritaire.
        self.sharepoint_base_url = (
            sharepoint_base_url
            or get_config('SHAREPOINT_BASE_URL', 'http://asap.stjn.local')
        )
        self.session = requests.Session()

        sharepoint_user = get_config('SHAREPOINT_USER', r'stjn\samir.chibout')
        sharepoint_password = get_config('SHAREPOINT_PASSWORD', '')
        
        # Configuration de l'authentification NTLM/Windows
        # ✅ Utilisation de raw string pour éviter les problèmes d'échappement
        self.session.auth = HttpNtlmAuth(sharepoint_user, sharepoint_password)
        
        logger.info(f"🔐 Authentification SharePoint avec l'utilisateur: {sharepoint_user}")
        
        # Configuration pour SharePoint - Accepter JSON
        self.session.headers.update({
            'Accept': 'application/json;odata=verbose',
            'Content-Type': 'application/json;odata=verbose'
        })
    
    def import_projets_from_sharepoint(self, **kwargs) -> Dict[str, Any]:
        """
        Importe les projets depuis SharePoint vers raw_data.sharepoint_projets
        
        Args:
            **kwargs: Paramètres optionnels (top, filter, etc.)
            
        Returns:
            Résumé de l'import
        """
        try:
            logger.info("🚀 Début de l'import des projets SharePoint")
            
            # 1. Récupérer les données depuis SharePoint
            projets_data = self._fetch_sharepoint_projects(**kwargs)
            
            if not projets_data:
                return {
                    'success': True,
                    'message': 'Aucun projet trouvé dans SharePoint',
                    'imported_count': 0,
                    'errors': [],
                    'db_saved': False
                }
            
            logger.info(f"📋 {len(projets_data)} projets récupérés depuis SharePoint")
            
            # 2. Tenter d'importer dans la table raw_data.sharepoint_projets
            try:
                import_result = self._import_projets_to_database(projets_data)
                logger.info(f"✅ Import terminé: {import_result['imported_count']} projets sauvegardés en DB")
                
                return {
                    'success': True,
                    'imported_count': import_result['imported_count'],
                    'errors': import_result['errors'],
                    'db_saved': True,
                    'projects_data': projets_data[:5]  # Retourner un échantillon
                }
            except Exception as db_error:
                logger.warning(f"⚠️ Impossible de sauvegarder en DB: {db_error}")
                logger.info(f"✅ Projets récupérés de SharePoint (non sauvegardés en DB)")
                
                # Retourner les données même si la DB n'est pas accessible
                return {
                    'success': True,
                    'imported_count': len(projets_data),
                    'errors': [f"Base de données non accessible: {str(db_error)}"],
                    'db_saved': False,
                    'projects_data': projets_data[:10],  # Retourner un échantillon plus grand
                    'total_fetched': len(projets_data),
                    'message': 'Projets récupérés depuis SharePoint mais non sauvegardés en DB'
                }
            
        except Exception as e:
            logger.error(f"❌ Erreur lors de l'import SharePoint: {e}")
            raise
    
    def _fetch_sharepoint_projects(self, **kwargs) -> List[Dict[str, Any]]:
        """Récupère les projets depuis l'API SharePoint avec pagination"""
        try:
            url = f"{self.sharepoint_base_url}/_api/web/lists/getByTitle('Projets')/items"
            
            # Limite maximale demandée — None = AUCUNE limite (tout importer)
            max_limit = kwargs.get('top')
            page_size = 100  # SharePoint limite à 100 par défaut

            # Paramètres de requête — AUCUN filtre par défaut : tous les projets
            # sont importés quel que soit leur statut (Clôturé/Annulé inclus).
            params = {
                '$top': page_size,
                '$orderby': kwargs.get('orderby', 'ID')
            }

            # Filtre uniquement si explicitement demandé par l'appelant
            if kwargs.get('filter'):
                params['$filter'] = kwargs['filter']
            
            if kwargs.get('select'):
                params['$select'] = kwargs['select']
            
            all_projects = []
            current_url = url
            fetched_count = 0
            
            logger.info(f"🔗 Début récupération SharePoint (max: {max_limit or 'illimité'})")

            # Pagination (max_limit None = pas de plafond)
            while current_url and (max_limit is None or fetched_count < max_limit):
                logger.info(f"📋 Requête page {len(all_projects)//page_size + 1}: {current_url[:100]}...")
                
                if current_url == url:
                    # Première requête avec paramètres
                    response = self.session.get(current_url, params=params, timeout=30)
                else:
                    # Requêtes suivantes (URL complète fournie par __next)
                    response = self.session.get(current_url, timeout=30)
                
                response.raise_for_status()
                data = response.json()
                
                # SharePoint retourne les données dans d.results
                projects = data.get('d', {}).get('results', [])
                
                if not projects:
                    logger.info("📋 Aucun projet dans cette page, fin de pagination")
                    break
                
                all_projects.extend(projects)
                fetched_count += len(projects)
                logger.info(f"✅ {len(projects)} projets récupérés (total: {len(all_projects)})")
                
                # Vérifier s'il y a une page suivante
                next_url = data.get('d', {}).get('__next')
                if next_url:
                    current_url = next_url
                    logger.info(f"➡️ Page suivante disponible")
                else:
                    logger.info("✅ Dernière page atteinte")
                    break
                
                # Respecter la limite demandée (si une limite est fixée)
                if max_limit is not None and fetched_count >= max_limit:
                    logger.info(f"⚠️ Limite de {max_limit} atteinte")
                    break

            logger.info(f"✅ Total final: {len(all_projects)} projets récupérés")
            return all_projects if max_limit is None else all_projects[:max_limit]
            
        except requests.exceptions.RequestException as e:
            logger.error(f"❌ Erreur connexion SharePoint: {e}")
            raise Exception(f"Erreur de connexion à SharePoint: {e}")
        except Exception as e:
            logger.error(f"❌ Erreur inattendue: {e}")
            raise
    
    def _import_projets_to_database(self, projets_data: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Importe les projets dans raw_data.sharepoint_projets (table existante)"""
        imported_count = 0
        errors = []
        
        try:
            with get_db_connection() as conn:
                cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
                
                for projet in projets_data:
                    try:
                        # Préparer les données pour l'insertion
                        projet_data = self._prepare_projet_data(projet)
                        
                        # Utiliser UPSERT pour éviter les doublons
                        cursor.execute("""
                            INSERT INTO raw_data.sharepoint_projets (
                                sharepoint_id, title, code, project_number, description,
                                global_status, phase_text, percent_completed, health, planning, cost,
                                start_date, estimated_end_date, last_status_report_date, opening_date,
                                modified, created, imported_at,
                                budget_initial, budget_total_sap, budget_actual, budget_at_completion,
                                budget_demanded, budget_delivered, budget_im_sap, budget_ex_sap,
                                sector, group_name, template,
                                pm_id, client_correspondent_id, project_team_id, acheteur_capex_id,
                                maintenance_correspondent_id, sponsor_id, author_id, editor_id,
                                passing_gate, end_p0, end_p1, end_p2, end_p3, end_p4, end_p5, end_p6,
                                last_milestone_passed, conception_date, mise_en_service_date,
                                achevement_industriel_date, conception_state, mise_en_service_state,
                                achevement_industriel_state, project_ahead, retroplanning, attachments,
                                pris_en_charge, end_project_mark, site_url, site_url_description,
                                validation_id, content_type_id, guid, static_id,
                                file_system_object_type, ui_version_string, priority, raw_data
                            )
                            VALUES (
                                %(sharepoint_id)s, %(title)s, %(code)s, %(project_number)s, %(description)s,
                                %(global_status)s, %(phase_text)s, %(percent_completed)s, %(health)s, %(planning)s, %(cost)s,
                                %(start_date)s, %(estimated_end_date)s, %(last_status_report_date)s, %(opening_date)s,
                                %(modified)s, %(created)s, %(imported_at)s,
                                %(budget_initial)s, %(budget_total_sap)s, %(budget_actual)s, %(budget_at_completion)s,
                                %(budget_demanded)s, %(budget_delivered)s, %(budget_im_sap)s, %(budget_ex_sap)s,
                                %(sector)s, %(group_name)s, %(template)s,
                                %(pm_id)s, %(client_correspondent_id)s, %(project_team_id)s, %(acheteur_capex_id)s,
                                %(maintenance_correspondent_id)s, %(sponsor_id)s, %(author_id)s, %(editor_id)s,
                                %(passing_gate)s, %(end_p0)s, %(end_p1)s, %(end_p2)s, %(end_p3)s, %(end_p4)s, %(end_p5)s, %(end_p6)s,
                                %(last_milestone_passed)s, %(conception_date)s, %(mise_en_service_date)s,
                                %(achevement_industriel_date)s, %(conception_state)s, %(mise_en_service_state)s,
                                %(achevement_industriel_state)s, %(project_ahead)s, %(retroplanning)s, %(attachments)s,
                                %(pris_en_charge)s, %(end_project_mark)s, %(site_url)s, %(site_url_description)s,
                                %(validation_id)s, %(content_type_id)s, %(guid)s, %(static_id)s,
                                %(file_system_object_type)s, %(ui_version_string)s, %(priority)s, %(raw_data)s
                            )
                            ON CONFLICT (sharepoint_id) 
                            DO UPDATE SET 
                                title = EXCLUDED.title,
                                code = EXCLUDED.code,
                                project_number = EXCLUDED.project_number,
                                description = EXCLUDED.description,
                                global_status = EXCLUDED.global_status,
                                phase_text = EXCLUDED.phase_text,
                                percent_completed = EXCLUDED.percent_completed,
                                health = EXCLUDED.health,
                                planning = EXCLUDED.planning,
                                cost = EXCLUDED.cost,
                                start_date = EXCLUDED.start_date,
                                estimated_end_date = EXCLUDED.estimated_end_date,
                                last_status_report_date = EXCLUDED.last_status_report_date,
                                opening_date = EXCLUDED.opening_date,
                                modified = EXCLUDED.modified,
                                created = EXCLUDED.created,
                                imported_at = EXCLUDED.imported_at,
                                budget_initial = EXCLUDED.budget_initial,
                                budget_total_sap = EXCLUDED.budget_total_sap,
                                budget_actual = EXCLUDED.budget_actual,
                                budget_at_completion = EXCLUDED.budget_at_completion,
                                budget_demanded = EXCLUDED.budget_demanded,
                                budget_delivered = EXCLUDED.budget_delivered,
                                budget_im_sap = EXCLUDED.budget_im_sap,
                                budget_ex_sap = EXCLUDED.budget_ex_sap,
                                sector = EXCLUDED.sector,
                                group_name = EXCLUDED.group_name,
                                template = EXCLUDED.template,
                                pm_id = EXCLUDED.pm_id,
                                client_correspondent_id = EXCLUDED.client_correspondent_id,
                                project_team_id = EXCLUDED.project_team_id,
                                acheteur_capex_id = EXCLUDED.acheteur_capex_id,
                                maintenance_correspondent_id = EXCLUDED.maintenance_correspondent_id,
                                sponsor_id = EXCLUDED.sponsor_id,
                                author_id = EXCLUDED.author_id,
                                editor_id = EXCLUDED.editor_id,
                                passing_gate = EXCLUDED.passing_gate,
                                end_p0 = EXCLUDED.end_p0,
                                end_p1 = EXCLUDED.end_p1,
                                end_p2 = EXCLUDED.end_p2,
                                end_p3 = EXCLUDED.end_p3,
                                end_p4 = EXCLUDED.end_p4,
                                end_p5 = EXCLUDED.end_p5,
                                end_p6 = EXCLUDED.end_p6,
                                last_milestone_passed = EXCLUDED.last_milestone_passed,
                                conception_date = EXCLUDED.conception_date,
                                mise_en_service_date = EXCLUDED.mise_en_service_date,
                                achevement_industriel_date = EXCLUDED.achevement_industriel_date,
                                conception_state = EXCLUDED.conception_state,
                                mise_en_service_state = EXCLUDED.mise_en_service_state,
                                achevement_industriel_state = EXCLUDED.achevement_industriel_state,
                                project_ahead = EXCLUDED.project_ahead,
                                retroplanning = EXCLUDED.retroplanning,
                                attachments = EXCLUDED.attachments,
                                pris_en_charge = EXCLUDED.pris_en_charge,
                                end_project_mark = EXCLUDED.end_project_mark,
                                site_url = EXCLUDED.site_url,
                                site_url_description = EXCLUDED.site_url_description,
                                validation_id = EXCLUDED.validation_id,
                                content_type_id = EXCLUDED.content_type_id,
                                guid = EXCLUDED.guid,
                                static_id = EXCLUDED.static_id,
                                file_system_object_type = EXCLUDED.file_system_object_type,
                                ui_version_string = EXCLUDED.ui_version_string,
                                priority = EXCLUDED.priority,
                                raw_data = EXCLUDED.raw_data
                        """, projet_data)
                        
                        imported_count += 1
                        logger.debug(f"✅ Projet {projet_data['sharepoint_id']} traité")
                        
                    except Exception as e:
                        error_msg = f"Erreur projet {projet.get('ID', 'Unknown')}: {e}"
                        logger.error(f"❌ {error_msg}")
                        errors.append(error_msg)
                
                conn.commit()
                logger.info(f"✅ {imported_count} projets importés en base")
                
        except Exception as e:
            logger.error(f"❌ Erreur import base de données: {e}")
            raise
        
        return {
            'imported_count': imported_count,
            'errors': errors
        }
    
    def _prepare_projet_data(self, projet: Dict[str, Any]) -> Dict[str, Any]:
        """Prépare les données d'un projet pour l'insertion (mapping complet des champs)"""
        
        # Helper pour parser les dates ISO
        def parse_date(date_str):
            if not date_str or date_str == 'null':
                return None
            try:
                return datetime.fromisoformat(date_str.replace('Z', '+00:00'))
            except:
                return None
        
        # Helper pour extraire les valeurs numériques
        def get_numeric(value):
            if value is None or value == 'null':
                return None
            try:
                return float(value)
            except:
                return None
        
        # Helper pour extraire les booléens
        def get_bool(value):
            if value is None or value == 'null':
                return False
            if isinstance(value, bool):
                return value
            return str(value).lower() in ('true', '1', 'yes')
        
        # Extraction de l'URL si c'est un objet complexe
        site_url = projet.get('Site_x0020_URL')
        site_url_str = None
        site_url_desc = None
        if isinstance(site_url, dict):
            site_url_str = site_url.get('Url')
            site_url_desc = site_url.get('Description')
        elif isinstance(site_url, str):
            site_url_str = site_url
        
        # Helper pour extraire les IDs (peut être int ou None)
        def get_int(value):
            if value is None or value == 'null':
                return None
            try:
                return int(value)
            except:
                return None
        
        return {
            # Colonnes de base
            'sharepoint_id': projet.get('ID') or projet.get('Id'),
            
            # Informations principales
            'title': projet.get('Title'),
            'code': projet.get('Code'),
            'project_number': projet.get('Num_x00e9_ro_x0020_du_x0020_proj'),
            'description': projet.get('Description'),
            
            # Statut et progression
            'global_status': projet.get('Global_x0020_Status'),
            'phase_text': projet.get('PhaseText'),
            'percent_completed': get_numeric(projet.get('OData__x0025__x0020_Completed')),
            'health': projet.get('Health'),
            'planning': projet.get('Planning'),
            'cost': projet.get('Cost'),
            
            # Dates
            'start_date': parse_date(projet.get('StartDate')),
            'estimated_end_date': parse_date(projet.get('Estimated_x0020_End_x0020_Date')),
            'last_status_report_date': parse_date(projet.get('Last_x0020_Status_x0020_Report_x')),
            'opening_date': parse_date(projet.get('Date_x0020_ouverture_x0020_cr_x0')),
            'modified': parse_date(projet.get('Modified')),
            'created': parse_date(projet.get('Created')),
            'imported_at': datetime.now(),
            
            # Budget
            'budget_initial': get_numeric(projet.get('Budget_x0020_Initial')),
            'budget_total_sap': get_numeric(projet.get('Budget_x0020_Total_x0020_SAP')),
            'budget_actual': get_numeric(projet.get('Budget_x0020_Actual')),
            'budget_at_completion': get_numeric(projet.get('Budget_x0020_At_x0020_Completion')),
            'budget_demanded': get_numeric(projet.get('Budget_x0020_demand_x00e9_')),
            'budget_delivered': get_numeric(projet.get('Budget_x0020_Delivered')),
            'budget_im_sap': get_numeric(projet.get('BudgetIMSAP')),
            'budget_ex_sap': get_numeric(projet.get('BudgetEXSAP')),
            
            # Organisation
            'sector': projet.get('Secteur'),
            'group_name': projet.get('Group1'),
            'template': projet.get('Template'),
            
            # IDs de référence
            'pm_id': get_int(projet.get('PMId')),
            'client_correspondent_id': get_int(projet.get('Correspondant_x002f__x0020_ClienId')),
            'project_team_id': get_int(projet.get('ProjectTeamId')),
            'acheteur_capex_id': get_int(projet.get('Acheteur_x0020_CAPEXId')),
            'maintenance_correspondent_id': get_int(projet.get('Correspondant_x0020_MaintenanceId')),
            'sponsor_id': get_int(projet.get('SponsorId')),
            'author_id': get_int(projet.get('AuthorId')),
            'editor_id': get_int(projet.get('EditorId')),
            
            # Jalons (Gates)
            'passing_gate': projet.get('PassingGate'),
            'end_p0': parse_date(projet.get('EndP0')),
            'end_p1': parse_date(projet.get('EndP1')),
            'end_p2': parse_date(projet.get('EndP2')),
            'end_p3': parse_date(projet.get('EndP3')),
            'end_p4': parse_date(projet.get('EndP4')),
            'end_p5': parse_date(projet.get('EndP5')),
            'end_p6': parse_date(projet.get('EndP6')),
            
            # Dates spécifiques
            'last_milestone_passed': parse_date(projet.get('Last_x0020_Milestone_x0020_Passe')),
            'conception_date': parse_date(projet.get('ConceptionDate')),
            'mise_en_service_date': parse_date(projet.get('MiseEnServiceDate')),
            'achevement_industriel_date': parse_date(projet.get('AchevementIndustrielDate')),
            
            # États
            'conception_state': projet.get('ConceptionState'),
            'mise_en_service_state': projet.get('MiseEnServiceState'),
            'achevement_industriel_state': projet.get('AchevementIndustrielState'),
            
            # Flags
            'project_ahead': get_bool(projet.get('Project_x0020_Ahead')),
            'retroplanning': get_bool(projet.get('Retroplanning')),
            'attachments': get_bool(projet.get('Attachments')),
            'pris_en_charge': projet.get('PrisEnCharge'),
            'end_project_mark': projet.get('EndProjectMark'),
            
            # URL et IDs spéciaux
            'site_url': site_url_str,
            'site_url_description': site_url_desc,
            'validation_id': projet.get('ValidationId'),
            'content_type_id': projet.get('ContentTypeId'),
            'guid': projet.get('GUID'),
            'static_id': get_numeric(projet.get('StaticID')),
            
            # Métadonnées
            'file_system_object_type': get_int(projet.get('FileSystemObjectType')),
            'ui_version_string': projet.get('OData__UIVersionString'),
            'priority': projet.get('Priorit_x00e9_'),
            
            # Toutes les données brutes en JSON (pour flexibilité)
            'raw_data': json.dumps(projet)
        }
    
    def test_connection(self) -> Dict[str, Any]:
        """Teste la connexion à SharePoint"""
        try:
            url = f"{self.sharepoint_base_url}/_api/web/lists/getByTitle('Projets')/items"
            
            response = self.session.get(url, params={'$top': 1}, timeout=10)
            response.raise_for_status()
            
            data = response.json()
            projects = data.get('d', {}).get('results', [])
            
            return {
                'success': True,
                'message': 'Connexion SharePoint OK',
                'url': url,
                'sample_count': len(projects),
                'status_code': response.status_code,
                'sample_data': projects[0] if projects else None
            }
            
        except requests.exceptions.RequestException as e:
            return {
                'success': False,
                'error': f'Erreur de connexion: {str(e)}'
            }
        except Exception as e:
            return {
                'success': False,
                'error': f'Erreur: {str(e)}'
            }
    
    def import_budgets_from_sharepoint(self, **kwargs) -> Dict[str, Any]:
        """
        Importe les budgets des projets depuis SharePoint
        
        Note: Cette méthode nécessite que SharePoint ait une liste séparée pour les budgets
        ou une relation parent-enfant dans la liste Projets
        """
        try:
            logger.info("🚀 Début de l'import des budgets SharePoint")
            
            # URL de la liste des budgets (à adapter selon votre SharePoint)
            # Option 1 : Liste séparée "Projets Budgets"
            url = f"{self.sharepoint_base_url}/_api/web/lists/getByTitle('Projets Budgets')/items"
            
            # Option 2 : Si les budgets sont des sous-éléments des projets
            # Il faudrait récupérer les items avec $expand
            
            try:
                response = self.session.get(url, params={'$top': 1000}, timeout=30)
                response.raise_for_status()
                data = response.json()
                budgets = data.get('d', {}).get('results', [])
                
                if not budgets:
                    logger.warning("⚠️ Aucun budget trouvé dans SharePoint")
                    return {
                        'success': True,
                        'imported_count': 0,
                        'errors': [],
                        'message': 'Aucun budget trouvé'
                    }
                
                # Importer les budgets dans la base de données
                imported_count = self._import_budgets_to_database(budgets)
                
                logger.info(f"✅ Import budgets terminé: {imported_count} budgets importés")
                
                return {
                    'success': True,
                    'imported_count': imported_count,
                    'errors': []
                }
                
            except requests.exceptions.HTTPError as e:
                if e.response.status_code == 404:
                    logger.error("❌ Liste 'Projets Budgets' non trouvée dans SharePoint")
                    return {
                        'success': False,
                        'imported_count': 0,
                        'errors': ["Liste 'Projets Budgets' non trouvée. Vérifiez le nom de la liste SharePoint."],
                        'message': 'Liste non trouvée'
                    }
                raise
                
        except Exception as e:
            logger.error(f"❌ Erreur import budgets: {e}")
            return {
                'success': False,
                'imported_count': 0,
                'errors': [str(e)]
            }
    
    def _import_budgets_to_database(self, budgets_data: List[Dict[str, Any]]) -> int:
        """Importe les budgets dans raw_data.sharepoint_projets_budgets"""
        imported_count = 0
        
        try:
            with get_db_connection() as conn:
                cursor = conn.cursor()
                
                for budget in budgets_data:
                    try:
                        cursor.execute("""
                            INSERT INTO raw_data.sharepoint_projets_budgets (
                                projet_id, budget_initial, budget_demande, budget_1ere_p3,
                                budget_total_sap, budget_im_sap, budget_ex_sap,
                                budget_actual, budget_at_completion, budget_delivered,
                                created_at
                            )
                            VALUES (
                                %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, CURRENT_TIMESTAMP
                            )
                            ON CONFLICT (id) DO UPDATE SET
                                budget_initial = EXCLUDED.budget_initial,
                                budget_demande = EXCLUDED.budget_demande,
                                budget_1ere_p3 = EXCLUDED.budget_1ere_p3,
                                budget_total_sap = EXCLUDED.budget_total_sap,
                                budget_im_sap = EXCLUDED.budget_im_sap,
                                budget_ex_sap = EXCLUDED.budget_ex_sap,
                                budget_actual = EXCLUDED.budget_actual,
                                budget_at_completion = EXCLUDED.budget_at_completion,
                                budget_delivered = EXCLUDED.budget_delivered
                        """, (
                            budget.get('ProjetId'),  # ID du projet parent
                            budget.get('Budget_x0020_Initial'),
                            budget.get('Budget_x0020_demand_x00e9_'),
                            budget.get('Budget_x0020_1_x00e8_re_x0020_P3'),
                            budget.get('Budget_x0020_Total_x0020_SAP'),
                            budget.get('BudgetIMSAP'),
                            budget.get('BudgetEXSAP'),
                            budget.get('Budget_x0020_Actual'),
                            budget.get('Budget_x0020_At_x0020_Completion'),
                            budget.get('Budget_x0020_Delivered')
                        ))
                        
                        imported_count += 1
                        
                    except Exception as e:
                        logger.error(f"❌ Erreur import budget: {e}")
                
                conn.commit()
                
        except Exception as e:
            logger.error(f"❌ Erreur import budgets en DB: {e}")
            raise
        
        return imported_count

    def import_resources_from_sharepoint(self, **kwargs) -> Dict[str, Any]:
        """
        Importe les ressources depuis SharePoint vers raw_data.sharepoint_resources
        
        Args:
            **kwargs: Paramètres optionnels (top, filter, etc.)
            
        Returns:
            Résumé de l'import
        """
        try:
            logger.info("🚀 Début de l'import des ressources SharePoint")
            
            # 1. Récupérer les données depuis SharePoint
            resources_data = self._fetch_sharepoint_resources(**kwargs)
            
            if not resources_data:
                return {
                    'success': True,
                    'message': 'Aucune ressource trouvée dans SharePoint',
                    'imported_count': 0,
                    'errors': [],
                    'db_saved': False
                }
            
            logger.info(f"📋 {len(resources_data)} ressources récupérées depuis SharePoint")
            
            # 2. Tenter d'importer dans la table raw_data.sharepoint_resources
            try:
                import_result = self._import_resources_to_database(resources_data)
                logger.info(f"✅ Import terminé: {import_result['imported_count']} ressources sauvegardées en DB")
                
                return {
                    'success': True,
                    'imported_count': import_result['imported_count'],
                    'errors': import_result['errors'],
                    'db_saved': True,
                    'resources_data': resources_data[:5]  # Retourner un échantillon
                }
            except Exception as db_error:
                logger.warning(f"⚠️ Impossible de sauvegarder en DB: {db_error}")
                logger.info(f"✅ Ressources récupérées de SharePoint (non sauvegardées en DB)")
                
                return {
                    'success': True,
                    'imported_count': len(resources_data),
                    'errors': [f"Base de données non accessible: {str(db_error)}"],
                    'db_saved': False,
                    'resources_data': resources_data[:10],
                    'total_fetched': len(resources_data),
                    'message': 'Ressources récupérées depuis SharePoint mais non sauvegardées en DB'
                }
            
        except Exception as e:
            logger.error(f"❌ Erreur lors de l'import SharePoint: {e}")
            raise
    
    def _fetch_sharepoint_resources(self, **kwargs) -> List[Dict[str, Any]]:
        """Récupère les ressources depuis l'API SharePoint avec pagination"""
        try:
            url = f"{self.sharepoint_base_url}/_api/web/lists/getByTitle('Ressources')/items"
            
            max_limit = kwargs.get('top', 5000)
            page_size = 100
            
            params = {
                '$top': page_size,
                '$orderby': kwargs.get('orderby', 'ID')
            }
            
            if kwargs.get('filter'):
                params['$filter'] = kwargs['filter']
            
            if kwargs.get('select'):
                params['$select'] = kwargs['select']
            
            all_resources = []
            current_url = url
            fetched_count = 0
            
            logger.info(f"🔗 Début récupération SharePoint Ressources (max: {max_limit})")
            
            while current_url and fetched_count < max_limit:
                logger.info(f"📋 Requête page {len(all_resources)//page_size + 1}: {current_url[:100]}...")
                
                if current_url == url:
                    response = self.session.get(current_url, params=params, timeout=30)
                else:
                    response = self.session.get(current_url, timeout=30)
                
                response.raise_for_status()
                data = response.json()
                
                resources = data.get('d', {}).get('results', [])
                
                if not resources:
                    logger.info("📋 Aucune ressource dans cette page, fin de pagination")
                    break
                
                all_resources.extend(resources)
                fetched_count += len(resources)
                logger.info(f"✅ {len(resources)} ressources récupérées (total: {len(all_resources)})")
                
                next_url = data.get('d', {}).get('__next')
                if next_url:
                    current_url = next_url
                    logger.info(f"➡️ Page suivante disponible")
                else:
                    logger.info("✅ Dernière page atteinte")
                    break
                
                if fetched_count >= max_limit:
                    logger.info(f"⚠️ Limite de {max_limit} atteinte")
                    break
            
            logger.info(f"✅ Total final: {len(all_resources)} ressources récupérées")
            return all_resources[:max_limit]
            
        except requests.exceptions.RequestException as e:
            logger.error(f"❌ Erreur connexion SharePoint: {e}")
            raise Exception(f"Erreur de connexion à SharePoint: {e}")
        except Exception as e:
            logger.error(f"❌ Erreur inattendue: {e}")
            raise
    
    def _import_resources_to_database(self, resources_data: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Importe les ressources dans raw_data.sharepoint_resources"""
        imported_count = 0
        errors = []
        
        try:
            with get_db_connection() as conn:
                cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
                
                for resource in resources_data:
                    try:
                        resource_data = self._prepare_resource_data(resource)
                        
                        cursor.execute("""
                            INSERT INTO raw_data.sharepoint_resources (
                                sharepoint_item_id, etag, guid, list_guid,
                                filesystemobjecttype, contenttype_id, title,
                                odata__uiversionstring, attachments,
                                created, modified, author_id, editor_id,
                                resource_x0020_typeid, generic, maxunit,
                                windowsaccount_id, securitygroup,
                                imported_at, source_file, import_batch_id
                            )
                            VALUES (
                                %(sharepoint_item_id)s, %(etag)s, %(guid)s, %(list_guid)s,
                                %(filesystemobjecttype)s, %(contenttype_id)s, %(title)s,
                                %(odata__uiversionstring)s, %(attachments)s,
                                %(created)s, %(modified)s, %(author_id)s, %(editor_id)s,
                                %(resource_x0020_typeid)s, %(generic)s, %(maxunit)s,
                                %(windowsaccount_id)s, %(securitygroup)s,
                                %(imported_at)s, %(source_file)s, %(import_batch_id)s
                            )
                            ON CONFLICT (sharepoint_item_id) 
                            DO UPDATE SET 
                                etag = EXCLUDED.etag,
                                guid = EXCLUDED.guid,
                                filesystemobjecttype = EXCLUDED.filesystemobjecttype,
                                contenttype_id = EXCLUDED.contenttype_id,
                                title = EXCLUDED.title,
                                odata__uiversionstring = EXCLUDED.odata__uiversionstring,
                                attachments = EXCLUDED.attachments,
                                created = EXCLUDED.created,
                                modified = EXCLUDED.modified,
                                author_id = EXCLUDED.author_id,
                                editor_id = EXCLUDED.editor_id,
                                resource_x0020_typeid = EXCLUDED.resource_x0020_typeid,
                                generic = EXCLUDED.generic,
                                maxunit = EXCLUDED.maxunit,
                                windowsaccount_id = EXCLUDED.windowsaccount_id,
                                securitygroup = EXCLUDED.securitygroup,
                                imported_at = EXCLUDED.imported_at,
                                source_file = EXCLUDED.source_file,
                                import_batch_id = EXCLUDED.import_batch_id
                        """, resource_data)
                        
                        imported_count += 1
                        logger.debug(f"✅ Ressource {resource_data['sharepoint_item_id']} traitée")
                        
                    except Exception as e:
                        error_msg = f"Erreur ressource {resource.get('ID', 'Unknown')}: {e}"
                        logger.error(f"❌ {error_msg}")
                        errors.append(error_msg)
                
                conn.commit()
                logger.info(f"✅ {imported_count} ressources importées en base")
                
        except Exception as e:
            logger.error(f"❌ Erreur import base de données: {e}")
            raise
        
        return {
            'imported_count': imported_count,
            'errors': errors
        }
    
    def _prepare_resource_data(self, resource: Dict[str, Any]) -> Dict[str, Any]:
        """Prépare les données d'une ressource pour l'insertion"""
        
        def parse_date(date_str):
            if not date_str or date_str == 'null':
                return None
            try:
                return datetime.fromisoformat(date_str.replace('Z', '+00:00'))
            except:
                return None
        
        def get_int(value):
            if value is None or value == 'null':
                return None
            try:
                return int(value)
            except:
                return None
        
        def get_bool(value):
            if value is None or value == 'null':
                return False
            if isinstance(value, bool):
                return value
            return str(value).lower() in ('true', '1', 'yes')
        
        def get_float(value):
            if value is None or value == 'null':
                return None
            try:
                return float(value)
            except:
                return None
        
        import uuid
        
        guid_str = resource.get('GUID')
        guid_uuid = None
        if guid_str:
            try:
                guid_uuid = uuid.UUID(str(guid_str))
            except:
                pass
        
        return {
            'sharepoint_item_id': resource.get('ID') or resource.get('Id'),
            'etag': resource.get('__metadata', {}).get('etag', '').strip('"'),
            'guid': guid_uuid,
            'list_guid': uuid.UUID('bf1a480a-7bfa-4a41-bc75-301c25d3c720'),
            'filesystemobjecttype': get_int(resource.get('FileSystemObjectType')),
            'contenttype_id': resource.get('ContentTypeId'),
            'title': resource.get('Title'),
            'odata__uiversionstring': resource.get('OData__UIVersionString'),
            'attachments': get_bool(resource.get('Attachments')),
            'created': parse_date(resource.get('Created')),
            'modified': parse_date(resource.get('Modified')),
            'author_id': get_int(resource.get('AuthorId')),
            'editor_id': get_int(resource.get('EditorId')),
            'resource_x0020_typeid': get_int(resource.get('Resource_x0020_TypeId')),
            'generic': get_bool(resource.get('Generic')),
            'maxunit': get_float(resource.get('MaxUnit')),
            'windowsaccount_id': resource.get('WindowsAccountId'),
            'securitygroup': resource.get('SecurityGroup'),
            'imported_at': datetime.now(),
            'source_file': 'sharepoint_api',
            'import_batch_id': f"batch_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        }
    
    def get_resources_status(self) -> Dict[str, Any]:
        """Retourne le statut de la table raw_data.sharepoint_resources"""
        try:
            with get_db_connection() as conn:
                cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
                
                cursor.execute("""
                    SELECT 
                        COUNT(*) as total_resources,
                        MAX(imported_at) as derniere_sync,
                        COUNT(CASE WHEN imported_at >= CURRENT_TIMESTAMP - INTERVAL '1 hour' THEN 1 END) as sync_recente,
                        MIN(imported_at) as premiere_import,
                        MAX(imported_at) as dernier_import
                    FROM raw_data.sharepoint_resources
                """)
                
                stats = cursor.fetchone()
                
                return {
                    'total_resources': stats['total_resources'] if stats else 0,
                    'derniere_sync': stats['derniere_sync'].isoformat() if stats and stats['derniere_sync'] else None,
                    'sync_recente': stats['sync_recente'] if stats else 0,
                    'premiere_import': stats['premiere_import'].isoformat() if stats and stats['premiere_import'] else None,
                    'dernier_import': stats['dernier_import'].isoformat() if stats and stats['dernier_import'] else None,
                    'status': 'ok' if stats and stats['sync_recente'] > 0 else 'needs_sync'
                }
                
        except Exception as e:
            logger.error(f"❌ Erreur statut ressources: {e}")
            return {
                'error': f'Erreur lors de la récupération du statut: {str(e)}'
            }
    
    def get_table_status(self) -> Dict[str, Any]:
        """Retourne le statut des tables raw_data"""
        try:
            with get_db_connection() as conn:
                cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
                
                # Statistiques de la table projets
                cursor.execute("""
                    SELECT 
                        COUNT(*) as total_projets,
                        MAX(imported_at) as derniere_sync,
                        COUNT(CASE WHEN imported_at >= CURRENT_TIMESTAMP - INTERVAL '1 hour' THEN 1 END) as sync_recente,
                        MIN(imported_at) as premiere_import,
                        MAX(imported_at) as dernier_import
                    FROM raw_data.sharepoint_projets
                """)
                
                stats = cursor.fetchone()
                
                # Statistiques des budgets
                cursor.execute("""
                    SELECT COUNT(*) as total_budgets
                    FROM raw_data.sharepoint_projets_budgets
                """)
                
                budgets_stats = cursor.fetchone()
                
                return {
                    'total_projets': stats['total_projets'] if stats else 0,
                    'total_budgets': budgets_stats['total_budgets'] if budgets_stats else 0,
                    'derniere_sync': stats['derniere_sync'].isoformat() if stats and stats['derniere_sync'] else None,
                    'sync_recente': stats['sync_recente'] if stats else 0,
                    'premiere_import': stats['premiere_import'].isoformat() if stats and stats['premiere_import'] else None,
                    'dernier_import': stats['dernier_import'].isoformat() if stats and stats['dernier_import'] else None,
                    'status': 'ok' if stats and stats['sync_recente'] > 0 else 'needs_sync'
                }
                
        except Exception as e:
            logger.error(f"❌ Erreur statut tables: {e}")
            return {
                'error': f'Erreur lors de la récupération du statut: {str(e)}'
            }
    
    def import_users_from_sharepoint(self, **kwargs) -> Dict[str, Any]:
        """
        Importe les utilisateurs depuis SharePoint vers raw_data.sharepoint_users
        
        Args:
            **kwargs: Paramètres optionnels (top, filter, etc.)
            
        Returns:
            Résumé de l'import
        """
        try:
            logger.info("🚀 Début de l'import des utilisateurs SharePoint")
            
            # 1. Récupérer les données depuis SharePoint
            users_data = self._fetch_sharepoint_users(**kwargs)
            
            if not users_data:
                return {
                    'success': True,
                    'message': 'Aucun utilisateur trouvé dans SharePoint',
                    'imported_count': 0,
                    'errors': [],
                    'db_saved': False
                }
            
            logger.info(f"📋 {len(users_data)} utilisateurs récupérés depuis SharePoint")
            
            # 2. Tenter d'importer dans la table raw_data.sharepoint_users
            try:
                import_result = self._import_users_to_database(users_data)
                logger.info(f"✅ Import terminé: {import_result['imported_count']} utilisateurs sauvegardés en DB")
                
                return {
                    'success': True,
                    'imported_count': import_result['imported_count'],
                    'errors': import_result['errors'],
                    'db_saved': True,
                    'users_data': users_data[:5]  # Retourner un échantillon
                }
            except Exception as db_error:
                logger.warning(f"⚠️ Impossible de sauvegarder en DB: {db_error}")
                logger.info(f"✅ Utilisateurs récupérés de SharePoint (non sauvegardés en DB)")
                
                return {
                    'success': True,
                    'imported_count': len(users_data),
                    'errors': [f"Base de données non accessible: {str(db_error)}"],
                    'db_saved': False,
                    'users_data': users_data[:10],
                    'total_fetched': len(users_data),
                    'message': 'Utilisateurs récupérés depuis SharePoint mais non sauvegardés en DB'
                }
            
        except Exception as e:
            logger.error(f"❌ Erreur lors de l'import SharePoint: {e}")
            raise
    
    def _fetch_sharepoint_users(self, **kwargs) -> List[Dict[str, Any]]:
        """Récupère les utilisateurs depuis l'API SharePoint"""
        try:
            url = f"{self.sharepoint_base_url}/_api/web/siteusers"
            
            max_limit = kwargs.get('top', 5000)
            
            params = {
                '$top': max_limit
            }
            
            if kwargs.get('filter'):
                params['$filter'] = kwargs['filter']
            
            logger.info(f"🔗 Début récupération utilisateurs SharePoint (max: {max_limit})")
            logger.info(f"📋 Requête: {url}")
            
            response = self.session.get(url, params=params, timeout=30)
            response.raise_for_status()
            data = response.json()
            
            # SharePoint retourne les données dans d.results
            users = data.get('d', {}).get('results', [])
            
            logger.info(f"✅ Total: {len(users)} utilisateurs récupérés")
            return users[:max_limit]
            
        except requests.exceptions.RequestException as e:
            logger.error(f"❌ Erreur connexion SharePoint: {e}")
            raise Exception(f"Erreur de connexion à SharePoint: {e}")
        except Exception as e:
            logger.error(f"❌ Erreur inattendue: {e}")
            raise
    
    def _import_users_to_database(self, users_data: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Importe les utilisateurs dans raw_data.sharepoint_users"""
        imported_count = 0
        errors = []
        
        try:
            with get_db_connection() as conn:
                cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
                
                for user in users_data:
                    try:
                        user_data = self._prepare_user_data(user)
                        
                        cursor.execute("""
                            INSERT INTO raw_data.sharepoint_users (
                                sharepoint_user_id, login_name, title, email,
                                principal_type, is_site_admin, is_hidden_in_ui,
                                name_id, name_id_issuer, imported_at
                            )
                            VALUES (
                                %(sharepoint_user_id)s, %(login_name)s, %(title)s, %(email)s,
                                %(principal_type)s, %(is_site_admin)s, %(is_hidden_in_ui)s,
                                %(name_id)s, %(name_id_issuer)s, %(imported_at)s
                            )
                            ON CONFLICT (sharepoint_user_id) 
                            DO UPDATE SET 
                                login_name = EXCLUDED.login_name,
                                title = EXCLUDED.title,
                                email = EXCLUDED.email,
                                principal_type = EXCLUDED.principal_type,
                                is_site_admin = EXCLUDED.is_site_admin,
                                is_hidden_in_ui = EXCLUDED.is_hidden_in_ui,
                                name_id = EXCLUDED.name_id,
                                name_id_issuer = EXCLUDED.name_id_issuer,
                                imported_at = EXCLUDED.imported_at,
                                updated_at = CURRENT_TIMESTAMP
                        """, user_data)
                        
                        imported_count += 1
                        logger.debug(f"✅ Utilisateur {user_data['sharepoint_user_id']} traité")
                        
                    except Exception as e:
                        error_msg = f"Erreur utilisateur {user.get('Id', 'Unknown')}: {e}"
                        logger.error(f"❌ {error_msg}")
                        errors.append(error_msg)
                
                conn.commit()
                logger.info(f"✅ {imported_count} utilisateurs importés en base")
                
        except Exception as e:
            logger.error(f"❌ Erreur import base de données: {e}")
            raise
        
        return {
            'imported_count': imported_count,
            'errors': errors
        }
    
    def _prepare_user_data(self, user: Dict[str, Any]) -> Dict[str, Any]:
        """Prépare les données d'un utilisateur pour l'insertion"""
        
        def get_int(value):
            if value is None or value == 'null':
                return None
            try:
                return int(value)
            except:
                return None
        
        def get_bool(value):
            if value is None or value == 'null':
                return False
            if isinstance(value, bool):
                return value
            return str(value).lower() in ('true', '1', 'yes')
        
        # Extraire UserId (SID)
        user_id_info = user.get('UserId', {})
        name_id = None
        name_id_issuer = None
        
        if isinstance(user_id_info, dict):
            name_id = user_id_info.get('NameId')
            name_id_issuer = user_id_info.get('NameIdIssuer')
        
        return {
            'sharepoint_user_id': get_int(user.get('Id')),
            'login_name': user.get('LoginName'),
            'title': user.get('Title'),
            'email': user.get('Email'),
            'principal_type': get_int(user.get('PrincipalType')),
            'is_site_admin': get_bool(user.get('IsSiteAdmin')),
            'is_hidden_in_ui': get_bool(user.get('IsHiddenInUI')),
            'name_id': name_id,
            'name_id_issuer': name_id_issuer,
            'imported_at': datetime.now()
        }
    
    def get_users_status(self) -> Dict[str, Any]:
        """Retourne le statut de la table raw_data.sharepoint_users"""
        try:
            with get_db_connection() as conn:
                cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
                
                cursor.execute("""
                    SELECT 
                        COUNT(*) as total_users,
                        MAX(imported_at) as derniere_sync,
                        COUNT(CASE WHEN imported_at >= CURRENT_TIMESTAMP - INTERVAL '1 hour' THEN 1 END) as sync_recente,
                        MIN(imported_at) as premiere_import,
                        MAX(imported_at) as dernier_import
                    FROM raw_data.sharepoint_users
                """)
                
                stats = cursor.fetchone()
                
                return {
                    'total_users': stats['total_users'] if stats else 0,
                    'derniere_sync': stats['derniere_sync'].isoformat() if stats and stats['derniere_sync'] else None,
                    'sync_recente': stats['sync_recente'] if stats else 0,
                    'premiere_import': stats['premiere_import'].isoformat() if stats and stats['premiere_import'] else None,
                    'dernier_import': stats['dernier_import'].isoformat() if stats and stats['dernier_import'] else None,
                    'status': 'ok' if stats and stats['sync_recente'] > 0 else 'needs_sync'
                }
                
        except Exception as e:
            logger.error(f"❌ Erreur statut utilisateurs: {e}")
            return {
                'error': f'Erreur lors de la récupération du statut: {str(e)}'
            }
    
    # ============================================================
    # ÉTATS D'AVANCEMENT (Status Reports)
    # ============================================================
    
    def get_all_project_site_ids(self) -> List[str]:
        """Récupère tous les IDs de sous-sites de projets depuis la base de données"""
        try:
            with get_db_connection() as conn:
                cursor = conn.cursor()
                cursor.execute("""
                    SELECT DISTINCT 
                        SPLIT_PART(SPLIT_PART(site_url, 'asap.stjn.local/', 2), '?', 1) as site_id
                    FROM raw_data.sharepoint_projets
                    WHERE site_url IS NOT NULL 
                    AND site_url LIKE '%%asap.stjn.local/%%'
                """)
                rows = cursor.fetchall()
                site_ids = [row[0].strip('/') for row in rows if row[0] and row[0].strip('/').isdigit()]
                site_ids.sort(key=lambda x: int(x))
                logger.info(f"📋 get_all_project_site_ids: {len(site_ids)} sites trouvés")
                return site_ids
        except Exception as e:
            logger.error(f"❌ Erreur récupération des site IDs: {e}")
            import traceback
            logger.error(traceback.format_exc())
            return []
    
    def import_all_etats_avancement(self, **kwargs) -> Dict[str, Any]:
        """
        Importe les états d'avancement de TOUS les projets SharePoint, et,
        pour chaque site, les 5 listes filles qui composent l'écran
        "État d'avancement" (Phases, Jalons réf., Statut jalons / CFV / coûts).

        Args:
            **kwargs:
              - top_per_site (int): max items par liste et par site (defaut 5000)
              - include_related (bool): inclure les listes filles (defaut True)

        Returns:
            Résumé de l'import global, avec compteurs par liste fille.
        """
        try:
            include_related = kwargs.get('include_related', True)
            top_per_site = kwargs.get('top_per_site', 5000)

            logger.info(f"🚀 Import global états d'avancement (related={include_related})")

            site_ids = self.get_all_project_site_ids()
            logger.info(f"📋 {len(site_ids)} sites de projets trouvés")

            if not site_ids:
                return {
                    'success': True,
                    'message': 'Aucun site de projet trouvé dans la base',
                    'total_imported': 0,
                    'sites_processed': 0,
                    'sites_with_data': 0,
                    'errors': [],
                    'related_counts': {}
                }

            total_imported = 0
            sites_with_data = 0
            all_errors = []
            related_counts = {k: 0 for k in self.RELATED_LISTS.keys()}

            for i, site_id in enumerate(site_ids):
                # 1. États d'avancement (table principale)
                try:
                    logger.info(f"📊 [{i+1}/{len(site_ids)}] site {site_id} — états")
                    result = self.import_etats_avancement_from_sharepoint(
                        site_id=site_id,
                        top=top_per_site,
                        skip_missing_list=True
                    )
                    if result.get('imported_count', 0) > 0:
                        total_imported += result['imported_count']
                        sites_with_data += 1
                    if result.get('errors'):
                        all_errors.extend(result['errors'])
                except Exception as e:
                    all_errors.append(f"site {site_id} états: {e}")
                    logger.warning(f"⚠️ site {site_id} états: {e}")

                # 2. Listes filles (phases, jalons_ref, statut_jalons, statut_cfv, statut_couts)
                if include_related:
                    for list_key in self.RELATED_LISTS.keys():
                        try:
                            rel = self.import_related_list(
                                list_key, site_id,
                                top=top_per_site,
                                skip_missing_list=True
                            )
                            related_counts[list_key] += rel.get('imported_count', 0)
                            if rel.get('errors'):
                                all_errors.extend(
                                    f"site {site_id} {list_key}: {err}" for err in rel['errors'][:5]
                                )
                        except Exception as e:
                            all_errors.append(f"site {site_id} {list_key}: {e}")
                            logger.warning(f"⚠️ site {site_id} {list_key}: {e}")

            total_related = sum(related_counts.values())
            logger.info(
                f"✅ Import global terminé: {total_imported} états + "
                f"{total_related} lignes filles sur {sites_with_data} sites"
            )

            return {
                'success': True,
                'message': (
                    f"Import terminé: {total_imported} états + {total_related} lignes liées "
                    f"sur {sites_with_data}/{len(site_ids)} sites"
                ),
                'total_imported': total_imported,
                'sites_processed': len(site_ids),
                'sites_with_data': sites_with_data,
                'errors': all_errors[:50],
                'related_counts': related_counts
            }

        except Exception as e:
            logger.error(f"❌ Erreur lors de l'import global: {e}")
            raise
    
    def import_etats_avancement_from_sharepoint(self, site_id: str = "863", **kwargs) -> Dict[str, Any]:
        """
        Importe les états d'avancement depuis SharePoint vers raw_data.sharepoint_etats_avancement
        
        Args:
            site_id: ID du sous-site SharePoint (ex: "863")
            **kwargs: Paramètres optionnels (top, filter, etc.)
            
        Returns:
            Résumé de l'import
        """
        try:
            logger.info(f"🚀 Début de l'import des états d'avancement SharePoint (site: {site_id})")
            
            # 1. Récupérer les données depuis SharePoint
            etats_data = self._fetch_sharepoint_etats_avancement(site_id, **kwargs)
            
            if not etats_data:
                return {
                    'success': True,
                    'message': 'Aucun état d\'avancement trouvé dans SharePoint',
                    'imported_count': 0,
                    'errors': [],
                    'db_saved': False
                }
            
            logger.info(f"📋 {len(etats_data)} états d'avancement récupérés depuis SharePoint")
            
            # 2. Tenter d'importer dans la table raw_data.sharepoint_etats_avancement
            try:
                import_result = self._import_etats_avancement_to_database(etats_data, site_id)
                logger.info(f"✅ Import terminé: {import_result['imported_count']} états sauvegardés en DB")
                
                return {
                    'success': True,
                    'imported_count': import_result['imported_count'],
                    'errors': import_result['errors'],
                    'db_saved': True,
                    'etats_data': etats_data[:5]  # Retourner un échantillon
                }
            except Exception as db_error:
                logger.warning(f"⚠️ Impossible de sauvegarder en DB: {db_error}")
                logger.info(f"✅ États récupérés de SharePoint (non sauvegardés en DB)")
                
                return {
                    'success': True,
                    'imported_count': len(etats_data),
                    'errors': [f"Base de données non accessible: {str(db_error)}"],
                    'db_saved': False,
                    'etats_data': etats_data[:10],
                    'total_fetched': len(etats_data),
                    'message': 'États récupérés depuis SharePoint mais non sauvegardés en DB'
                }
            
        except Exception as e:
            logger.error(f"❌ Erreur lors de l'import SharePoint: {e}")
            raise
    
    def _fetch_sharepoint_etats_avancement(self, site_id: str, **kwargs) -> List[Dict[str, Any]]:
        """Récupère les états d'avancement depuis l'API SharePoint avec pagination"""
        try:
            # Essayer d'abord par le titre de la liste (plus universel)
            # Les listes "Status Reports" peuvent avoir des GUIDs différents par site
            list_title = kwargs.get('list_title', "États d'avancement")
            list_guid = kwargs.get('list_guid')
            skip_missing_list = kwargs.get('skip_missing_list', False)
            
            if list_guid:
                url = f"{self.sharepoint_base_url}/{site_id}/_api/web/lists(guid'{list_guid}')/items"
            else:
                escaped_title = list_title.replace("'", "''")
                url = f"{self.sharepoint_base_url}/{site_id}/_api/web/lists/getByTitle('{escaped_title}')/items"
            
            max_limit = kwargs.get('top', 5000)
            page_size = 100
            
            params = {
                '$top': page_size,
                '$orderby': kwargs.get('orderby', 'ID')
            }
            
            if kwargs.get('filter'):
                params['$filter'] = kwargs['filter']
            
            if kwargs.get('select'):
                params['$select'] = kwargs['select']
            
            all_etats = []
            current_url = url
            fetched_count = 0
            
            logger.info(f"🔗 Début récupération États d'avancement SharePoint (site: {site_id}, max: {max_limit})")
            
            while current_url and fetched_count < max_limit:
                logger.debug(f"📋 Requête page {len(all_etats)//page_size + 1}: {current_url[:80]}...")
                
                if current_url == url:
                    response = self.session.get(current_url, params=params, timeout=30)
                else:
                    response = self.session.get(current_url, timeout=30)
                
                # Lever une exception HTTP si erreur
                response.raise_for_status()
                data = response.json()
                
                etats = data.get('d', {}).get('results', [])
                
                if not etats:
                    logger.info("📋 Aucun état dans cette page, fin de pagination")
                    break
                
                all_etats.extend(etats)
                fetched_count += len(etats)
                logger.info(f"✅ {len(etats)} états récupérés (total: {len(all_etats)})")
                
                next_url = data.get('d', {}).get('__next')
                if next_url:
                    current_url = next_url
                    logger.info(f"➡️ Page suivante disponible")
                else:
                    logger.info("✅ Dernière page atteinte")
                    break
                
                if fetched_count >= max_limit:
                    logger.info(f"⚠️ Limite de {max_limit} atteinte")
                    break
            
            logger.info(f"✅ Total final: {len(all_etats)} états d'avancement récupérés")
            return all_etats[:max_limit]
            
        except requests.exceptions.HTTPError as e:
            # Gérer les erreurs 404 (liste non trouvée)
            if e.response is not None and e.response.status_code == 404:
                if skip_missing_list:
                    logger.debug(f"📋 Site {site_id}: liste Status Reports non trouvée (ignoré)")
                    return []
                else:
                    logger.warning(f"⚠️ Site {site_id}: liste Status Reports non trouvée")
                    raise Exception(f"Liste Status Reports non trouvée pour le site {site_id}")
            logger.error(f"❌ Erreur HTTP SharePoint: {e}")
            raise Exception(f"Erreur HTTP SharePoint: {e}")
        except requests.exceptions.RequestException as e:
            logger.error(f"❌ Erreur connexion SharePoint: {e}")
            if skip_missing_list:
                return []
            raise Exception(f"Erreur de connexion à SharePoint: {e}")
        except Exception as e:
            logger.error(f"❌ Erreur inattendue: {e}")
            if skip_missing_list:
                return []
            raise
    
    def _import_etats_avancement_to_database(self, etats_data: List[Dict[str, Any]], site_id: str) -> Dict[str, Any]:
        """Importe les états d'avancement dans raw_data.sharepoint_etats_avancement"""
        imported_count = 0
        errors = []
        
        try:
            with get_db_connection() as conn:
                cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
                
                for etat in etats_data:
                    try:
                        etat_data = self._prepare_etat_avancement_data(etat, site_id)
                        
                        cursor.execute("""
                            INSERT INTO raw_data.sharepoint_etats_avancement (
                                sharepoint_id, title, status_date, percent_completed,
                                global_status, health, planning, cost, update_text,
                                current_phase_id, end_project_mark,
                                created, modified,
                                author_id, editor_id,
                                imported_at, site_id, raw_data
                            )
                            VALUES (
                                %(sharepoint_id)s, %(title)s, %(status_date)s, %(percent_completed)s,
                                %(global_status)s, %(health)s, %(planning)s, %(cost)s, %(update_text)s,
                                %(current_phase_id)s, %(end_project_mark)s,
                                %(created)s, %(modified)s,
                                %(author_id)s, %(editor_id)s,
                                %(imported_at)s, %(site_id)s, %(raw_data)s
                            )
                            ON CONFLICT (sharepoint_id, site_id)
                            DO UPDATE SET
                                title = EXCLUDED.title,
                                status_date = EXCLUDED.status_date,
                                percent_completed = EXCLUDED.percent_completed,
                                global_status = EXCLUDED.global_status,
                                health = EXCLUDED.health,
                                planning = EXCLUDED.planning,
                                cost = EXCLUDED.cost,
                                update_text = EXCLUDED.update_text,
                                current_phase_id = EXCLUDED.current_phase_id,
                                end_project_mark = EXCLUDED.end_project_mark,
                                created = EXCLUDED.created,
                                modified = EXCLUDED.modified,
                                author_id = EXCLUDED.author_id,
                                editor_id = EXCLUDED.editor_id,
                                imported_at = EXCLUDED.imported_at,
                                raw_data = EXCLUDED.raw_data
                        """, etat_data)
                        
                        imported_count += 1
                        logger.debug(f"✅ État {etat_data['sharepoint_id']} traité")
                        
                    except Exception as e:
                        error_msg = f"Erreur état {etat.get('ID', 'Unknown')}: {e}"
                        logger.error(f"❌ {error_msg}")
                        errors.append(error_msg)
                
                conn.commit()
                logger.info(f"✅ {imported_count} états d'avancement importés en base")
                
        except Exception as e:
            logger.error(f"❌ Erreur import base de données: {e}")
            raise
        
        return {
            'imported_count': imported_count,
            'errors': errors
        }
    
    def _prepare_etat_avancement_data(self, etat: Dict[str, Any], site_id: str) -> Dict[str, Any]:
        """Prépare les données d'un état d'avancement pour l'insertion"""
        
        def parse_date(date_str):
            if not date_str or date_str == 'null':
                return None
            try:
                return datetime.fromisoformat(date_str.replace('Z', '+00:00'))
            except:
                return None
        
        def get_numeric(value):
            if value is None or value == 'null':
                return None
            try:
                return float(value)
            except:
                return None
        
        def get_int(value):
            if value is None or value == 'null':
                return None
            try:
                return int(value)
            except:
                return None
        
        def get_bool(value):
            if value is None or value == 'null':
                return False
            if isinstance(value, bool):
                return value
            return str(value).lower() in ('true', '1', 'yes')
        
        import uuid as uuid_module
        
        guid_str = etat.get('GUID')
        guid_uuid = None
        if guid_str:
            try:
                guid_uuid = uuid_module.UUID(str(guid_str))
            except:
                pass
        
        return {
            'sharepoint_id': etat.get('ID') or etat.get('Id'),
            'title': etat.get('Title'),
            'status_date': parse_date(etat.get('Status_x0020_Date')),
            'percent_completed': get_numeric(etat.get('OData__x0025__x0020_Completed')),
            'global_status': etat.get('Global_x0020_Status'),
            'health': etat.get('Health'),
            'planning': etat.get('Planning'),
            'cost': etat.get('Cost'),
            'update_text': etat.get('Update'),
            'current_phase_id': get_int(etat.get('Current_x0020_PhaseId')),
            'end_project_mark': etat.get('EndProjectMark'),
            'content_type_id': etat.get('ContentTypeId'),
            'guid': guid_uuid,
            'created': parse_date(etat.get('Created')),
            'modified': parse_date(etat.get('Modified')),
            'author_id': get_int(etat.get('AuthorId')),
            'editor_id': get_int(etat.get('EditorId')),
            'ui_version_string': etat.get('OData__UIVersionString'),
            'attachments': get_bool(etat.get('Attachments')),
            'file_system_object_type': get_int(etat.get('FileSystemObjectType')),
            'imported_at': datetime.now(),
            'site_id': site_id,
            'raw_data': json.dumps(etat)
        }
    
    def test_etats_avancement_connection(self, site_id: str = "863", list_guid: str = "0143FA81-887F-49BC-9878-C1BF871D7F3B") -> Dict[str, Any]:
        """Teste la connexion à la liste des états d'avancement SharePoint"""
        try:
            url = f"{self.sharepoint_base_url}/{site_id}/_api/web/lists(guid'{list_guid}')/items"
            
            response = self.session.get(url, params={'$top': 1}, timeout=10)
            response.raise_for_status()
            
            data = response.json()
            etats = data.get('d', {}).get('results', [])
            
            return {
                'success': True,
                'message': 'Connexion SharePoint États d\'avancement OK',
                'url': url,
                'site_id': site_id,
                'list_guid': list_guid,
                'sample_count': len(etats),
                'status_code': response.status_code,
                'sample_data': etats[0] if etats else None
            }
            
        except requests.exceptions.RequestException as e:
            return {
                'success': False,
                'error': f'Erreur de connexion: {str(e)}'
            }
        except Exception as e:
            return {
                'success': False,
                'error': f'Erreur: {str(e)}'
            }
    
    def get_etats_avancement_status(self) -> Dict[str, Any]:
        """Retourne le statut de la table raw_data.sharepoint_etats_avancement"""
        try:
            with get_db_connection() as conn:
                cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
                
                cursor.execute("""
                    SELECT 
                        COUNT(*) as total_etats,
                        MAX(imported_at) as derniere_sync,
                        COUNT(CASE WHEN imported_at >= CURRENT_TIMESTAMP - INTERVAL '1 hour' THEN 1 END) as sync_recente,
                        MIN(imported_at) as premiere_import,
                        MAX(imported_at) as dernier_import,
                        COUNT(DISTINCT site_id) as nb_sites
                    FROM raw_data.sharepoint_etats_avancement
                """)
                
                stats = cursor.fetchone()
                
                return {
                    'total_etats': stats['total_etats'] if stats else 0,
                    'derniere_sync': stats['derniere_sync'].isoformat() if stats and stats['derniere_sync'] else None,
                    'sync_recente': stats['sync_recente'] if stats else 0,
                    'premiere_import': stats['premiere_import'].isoformat() if stats and stats['premiere_import'] else None,
                    'dernier_import': stats['dernier_import'].isoformat() if stats and stats['dernier_import'] else None,
                    'nb_sites': stats['nb_sites'] if stats else 0,
                    'status': 'ok' if stats and stats['sync_recente'] > 0 else 'needs_sync'
                }
                
        except Exception as e:
            logger.error(f"❌ Erreur statut états d'avancement: {e}")
            return {
                'error': f'Erreur lors de la récupération du statut: {str(e)}'
            }

    # ============================================================
    # IMPORT GENERIQUE DES LISTES SHAREPOINT (Phases, Jalons, CFV, Couts...)
    # ============================================================

    # Catalogue des 5 listes filles a importer.
    # On utilise le TITRE de la liste (pas le GUID) parce que chaque site
    # SharePoint a des GUIDs differents pour les memes listes.
    RELATED_LISTS = {
        'phases': {
            'title':  'Phases',
            'table':  'raw_data.sharepoint_phases',
            'label':  'Phases (referentiel)',
        },
        'jalons_ref': {
            'title':  'Jalons',
            'table':  'raw_data.sharepoint_jalons_ref',
            'label':  'Jalons (referentiel P1..P6)',
            # Résout FieldValuesAsText (libellés des lookups, ex. Phase) au lieu d'un lien __deferred
            'expand': 'FieldValuesAsText',
        },
        'statut_jalons': {
            'title':  'Statut des jalons',
            'table':  'raw_data.sharepoint_statut_jalons',
            'label':  'Statut des jalons',
        },
        'statut_cfv': {
            'title':  'Statut des CFV',
            'table':  'raw_data.sharepoint_statut_cfv',
            'label':  'Statut des CFV',
        },
        'statut_couts': {
            'title':  'Statut des coûts',
            'table':  'raw_data.sharepoint_statut_couts',
            'label':  'Statut des couts',
        },
    }

    def _fetch_list_items_generic(self, site_id: str, list_title: str, **kwargs) -> List[Dict[str, Any]]:
        """Recupere tous les items d'une liste SharePoint via son TITRE (cross-site)."""
        page_size = kwargs.get('page_size', 100)
        max_limit = kwargs.get('top', 5000)
        skip_missing = kwargs.get('skip_missing_list', False)

        escaped_title = list_title.replace("'", "''")
        url = f"{self.sharepoint_base_url}/{site_id}/_api/web/lists/getByTitle('{escaped_title}')/items"
        params = {'$top': page_size, '$orderby': kwargs.get('orderby', 'ID')}
        if kwargs.get('filter'):
            params['$filter'] = kwargs['filter']
        # $expand pour résoudre les champs lookup / FieldValuesAsText (libellés) au lieu de liens __deferred
        if kwargs.get('expand'):
            params['$expand'] = kwargs['expand']

        all_items: List[Dict[str, Any]] = []
        current_url = url
        try:
            while current_url and len(all_items) < max_limit:
                if current_url == url:
                    response = self.session.get(current_url, params=params, timeout=30)
                else:
                    response = self.session.get(current_url, timeout=30)
                response.raise_for_status()
                data = response.json()
                items = data.get('d', {}).get('results', [])
                if not items:
                    break
                all_items.extend(items)
                next_url = data.get('d', {}).get('__next')
                if not next_url:
                    break
                current_url = next_url
            return all_items[:max_limit]
        except requests.exceptions.HTTPError as e:
            if e.response is not None and e.response.status_code == 404 and skip_missing:
                return []
            logger.error(f"❌ HTTP '{list_title}' site {site_id}: {e}")
            raise
        except requests.exceptions.RequestException as e:
            if skip_missing:
                return []
            logger.error(f"❌ Connexion SharePoint '{list_title}' site {site_id}: {e}")
            raise

    def _prepare_generic_item(self, item: Dict[str, Any], site_id: str) -> Dict[str, Any]:
        """Extrait les colonnes communes (id, title, dates, ids auteur) + raw JSONB."""
        import uuid as uuid_module

        def parse_dt(v):
            if not v or v == 'null':
                return None
            try:
                return datetime.fromisoformat(str(v).replace('Z', '+00:00'))
            except Exception:
                return None

        def to_int(v):
            try:
                return int(v) if v not in (None, '', 'null') else None
            except (TypeError, ValueError):
                return None

        guid_val = item.get('GUID')
        guid_uuid = None
        if guid_val:
            try:
                guid_uuid = uuid_module.UUID(str(guid_val))
            except Exception:
                pass

        return {
            'sharepoint_id': item.get('ID') or item.get('Id'),
            'site_id':       site_id,
            'title':         item.get('Title'),
            'guid':          guid_uuid,
            'created':       parse_dt(item.get('Created')),
            'modified':      parse_dt(item.get('Modified')),
            'author_id':     to_int(item.get('AuthorId')),
            'editor_id':     to_int(item.get('EditorId')),
            'imported_at':   datetime.now(),
            'raw_data':      json.dumps(item),
        }

    def _upsert_generic_items(self, table: str, items: List[Dict[str, Any]], site_id: str) -> Dict[str, Any]:
        """Insere/met a jour des items dans une table generique (raw_data + colonnes communes)."""
        if not items:
            return {'imported_count': 0, 'errors': []}

        imported = 0
        errors: List[str] = []
        sql = f"""
            INSERT INTO {table} (
                sharepoint_id, site_id, title, guid,
                created, modified, author_id, editor_id,
                imported_at, raw_data
            ) VALUES (
                %(sharepoint_id)s, %(site_id)s, %(title)s, %(guid)s,
                %(created)s, %(modified)s, %(author_id)s, %(editor_id)s,
                %(imported_at)s, %(raw_data)s
            )
            ON CONFLICT (sharepoint_id, site_id) DO UPDATE SET
                title       = EXCLUDED.title,
                guid        = EXCLUDED.guid,
                created     = EXCLUDED.created,
                modified    = EXCLUDED.modified,
                author_id   = EXCLUDED.author_id,
                editor_id   = EXCLUDED.editor_id,
                imported_at = EXCLUDED.imported_at,
                raw_data    = EXCLUDED.raw_data
        """
        try:
            with get_db_connection() as conn:
                with conn.cursor() as cur:
                    for it in items:
                        try:
                            row = self._prepare_generic_item(it, site_id)
                            if row['sharepoint_id'] is None:
                                continue
                            cur.execute(sql, row)
                            imported += 1
                        except Exception as e:
                            errors.append(f"item {it.get('ID') or it.get('Id')}: {e}")
                conn.commit()
        except Exception as e:
            logger.error(f"❌ Upsert {table}: {e}")
            raise
        return {'imported_count': imported, 'errors': errors}

    # =====================================================================
    # Projets à reprendre : liste SharePoint racine (par GUID) -> raw_data.sharepoint_project_to_save
    # =====================================================================
    PROJETS_A_REPRENDRE_GUID = '7a38eb49-5b72-418a-8966-184088a3360d'
    # Colonnes de la table cible = libellés d'affichage SharePoint (ordre sans importance)
    PROJETS_A_REPRENDRE_COLUMNS = [
        'Numéro du projet', 'URL du site', 'Nom du projet', 'Chef de projet',
        'Correspondant/ Client du projet', 'Acheteur CAPEX', '% Complété', 'Passage porte',
        'Statut Global', 'Santé', 'Coût', 'Planning', 'Numéro de crédit', 'Budget Initial',
        'Budget Total SAP', 'Engagé', 'Réceptionné', 'Pris en charge', 'Reste à engager',
        'Date de début', 'P0', 'P1', 'P2', 'P3', 'P4', 'P6', 'Date ouverture crédit',
        'Date de fin estimée', "Dernière MAJ de l'état d'avancement", 'État CFV Conception',
        'Date CFV Conception', 'État CFV Mise en service', 'Date CFV Mise en service',
        'État CFV Achèvement industriel', 'Date CFV Achèvement industriel',
        'Correspondant Maintenance', 'Phase', 'Budget demandé', 'Budget 1ère P3',
        'Equipe projet', 'Secteur', 'Site', 'Budget EX SAP', 'Budget IM SAP',
        'Date du dernier jalon passé', 'Priorité', 'Sponsor', "Type d'élément", "Chemin d'accès",
    ]

    def import_projets_a_reprendre(self, **kwargs) -> Dict[str, Any]:
        """Rafraîchit raw_data.sharepoint_project_to_save depuis la liste SharePoint (par GUID).

        L'API renvoie les champs sous leur NOM INTERNE (Num_x00e9_ro_x0020_...), alors que la
        table cible utilise les libellés d'affichage. On résout donc :
          1. le mapping libellé -> nom interne via /fields
          2. les valeurs AFFICHÉES (personnes résolues, dates formatées, %) via
             $expand=FieldValuesAsText (clés = nom interne, préfixe 'OData_' possible)
        Puis TRUNCATE + INSERT (la table est un snapshot de référence).
        """
        base = f"{self.sharepoint_base_url}/_api/web/lists(guid'{self.PROJETS_A_REPRENDRE_GUID}')"
        max_limit = kwargs.get('top', 5000)

        # 1. Mapping libellé d'affichage -> nom interne
        resp = self.session.get(f"{base}/fields", params={'$select': 'Title,InternalName,Hidden'}, timeout=30)
        resp.raise_for_status()
        title_to_internal: Dict[str, str] = {}
        for f in resp.json().get('d', {}).get('results', []):
            title = f.get('Title')
            internal = f.get('InternalName')
            if title and internal and not f.get('Hidden') and title not in title_to_internal:
                title_to_internal[title] = internal

        unresolved = [c for c in self.PROJETS_A_REPRENDRE_COLUMNS if c not in title_to_internal]
        if unresolved:
            logger.warning(f"⚠️ Colonnes sans champ SharePoint correspondant (resteront NULL): {unresolved}")

        # 2. Items paginés avec les valeurs affichées
        items: List[Dict[str, Any]] = []
        url = f"{base}/items"
        params = {'$top': 100, '$expand': 'FieldValuesAsText', '$orderby': 'ID'}
        first = True
        while url and len(items) < max_limit:
            r = self.session.get(url, params=params if first else None, timeout=60)
            first = False
            r.raise_for_status()
            d = r.json().get('d', {})
            batch = d.get('results', [])
            if not batch:
                break
            items.extend(batch)
            url = d.get('__next')

        logger.info(f"📥 Projets à reprendre : {len(items)} items récupérés depuis SharePoint")

        # 3. Constitution des lignes (valeur affichée prioritaire, fallback valeur brute)
        rows: List[Dict[str, Any]] = []
        for item in items:
            fvat_raw = item.get('FieldValuesAsText') or {}
            # normalise les clés : 'OData_' + interne -> interne
            fvat = {}
            for k, v in fvat_raw.items():
                if not isinstance(v, (str, int, float)):
                    continue
                fvat[k[6:] if k.startswith('OData_') else k] = v
            row = {}
            for col in self.PROJETS_A_REPRENDRE_COLUMNS:
                internal = title_to_internal.get(col)
                val = None
                if internal:
                    val = fvat.get(internal)
                    if val in (None, ''):
                        raw = item.get(internal)
                        if isinstance(raw, (str, int, float)) and not isinstance(raw, bool):
                            val = raw
                s = str(val).strip() if val is not None else ''
                row[col] = s if s != '' else None
            rows.append(row)

        # 4. TRUNCATE + INSERT (identifiants quotés, '%' doublé pour psycopg2)
        def q(ident: str) -> str:
            return '"' + ident.replace('"', '""').replace('%', '%%') + '"'

        cols_sql = ', '.join(q(c) for c in self.PROJETS_A_REPRENDRE_COLUMNS) + ', source_file, loaded_at'
        placeholders = ', '.join(['%s'] * len(self.PROJETS_A_REPRENDRE_COLUMNS)) + ', %s, now()'
        insert_sql = f'INSERT INTO raw_data.sharepoint_project_to_save ({cols_sql}) VALUES ({placeholders})'
        source = f'sharepoint_api:{self.PROJETS_A_REPRENDRE_GUID}'

        imported = 0
        with get_db_connection() as conn:
            with conn.cursor() as cur:
                cur.execute('TRUNCATE TABLE raw_data.sharepoint_project_to_save')
                for row in rows:
                    cur.execute(insert_sql, [row[c] for c in self.PROJETS_A_REPRENDRE_COLUMNS] + [source])
                    imported += 1
            conn.commit()

        logger.info(f"✅ raw_data.sharepoint_project_to_save rechargée : {imported} lignes")
        return {
            'success': True,
            'fetched_count': len(items),
            'imported_count': imported,
            'unresolved_columns': unresolved,
        }

    def import_related_list(self, list_key: str, site_id: str, **kwargs) -> Dict[str, Any]:
        """Importe UNE liste fille pour UN site (phases, jalons_ref, statut_jalons, statut_cfv, statut_couts)."""
        if list_key not in self.RELATED_LISTS:
            raise ValueError(f"Liste inconnue: {list_key} (attendu: {list(self.RELATED_LISTS.keys())})")
        meta = self.RELATED_LISTS[list_key]
        logger.info(f"📥 Import {meta['label']} pour site {site_id}")
        fetch_kwargs = dict(kwargs)
        if meta.get('expand') and 'expand' not in fetch_kwargs:
            fetch_kwargs['expand'] = meta['expand']
        items = self._fetch_list_items_generic(site_id, meta['title'], **fetch_kwargs)
        result = self._upsert_generic_items(meta['table'], items, site_id)
        return {
            'success':        True,
            'list_key':       list_key,
            'list_label':     meta['label'],
            'site_id':        site_id,
            'fetched_count':  len(items),
            'imported_count': result['imported_count'],
            'errors':         result['errors'],
        }

    def import_related_list_all_sites(self, list_key: str, **kwargs) -> Dict[str, Any]:
        """Importe UNE liste fille sur TOUS les sites projet."""
        if list_key not in self.RELATED_LISTS:
            raise ValueError(f"Liste inconnue: {list_key}")
        meta = self.RELATED_LISTS[list_key]
        site_ids = self.get_all_project_site_ids()
        logger.info(f"📥 Import {meta['label']} sur {len(site_ids)} sites")

        top_per_site = kwargs.get('top_per_site', 5000)
        total_imported = 0
        sites_with_data = 0
        all_errors: List[str] = []

        for i, site_id in enumerate(site_ids):
            try:
                items = self._fetch_list_items_generic(
                    site_id, meta['title'],
                    top=top_per_site,
                    skip_missing_list=True
                )
                if not items:
                    continue
                result = self._upsert_generic_items(meta['table'], items, site_id)
                if result['imported_count'] > 0:
                    sites_with_data += 1
                    total_imported += result['imported_count']
                if result['errors']:
                    all_errors.extend(result['errors'])
            except Exception as e:
                all_errors.append(f"site {site_id}: {e}")
                logger.warning(f"⚠️ Site {site_id} ({list_key}): {e}")

        return {
            'success':         True,
            'list_key':        list_key,
            'list_label':      meta['label'],
            'total_imported':  total_imported,
            'sites_processed': len(site_ids),
            'sites_with_data': sites_with_data,
            'errors':          all_errors[:50],
        }

    def import_all_etat_avancement_related(self, **kwargs) -> Dict[str, Any]:
        """Bouton 'tout importer' : les 5 listes filles sur tous les sites."""
        results = {}
        for key in self.RELATED_LISTS.keys():
            try:
                results[key] = self.import_related_list_all_sites(key, **kwargs)
            except Exception as e:
                results[key] = {'success': False, 'error': str(e)}
        return {'success': True, 'results': results}