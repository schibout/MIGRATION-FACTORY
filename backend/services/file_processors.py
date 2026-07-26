"""
Processeurs de fichiers pour le système d'import
Gestion du traitement de différents types de fichiers (CSV, Excel)
"""

import pandas as pd
import numpy as np
from abc import ABC, abstractmethod
from typing import Dict, List, Any, Optional, Tuple
import logging
import re
from datetime import datetime
import json

logger = logging.getLogger(__name__)


class BaseFileProcessor(ABC):
    """
    Classe abstraite de base pour tous les processeurs de fichiers
    """
    
    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.stats = {
            'total_rows': 0,
            'processed_rows': 0,
            'success_rows': 0,
            'error_rows': 0,
            'warnings': 0
        }
        self.required_columns = config.get('required_columns', [])
        self.optional_columns = config.get('optional_columns', [])
        self.target_table = config.get('target_table', '')
        self.target_schema = config.get('target_schema', 'public')
    
    def read_file(self, file_path: str, file_format: str) -> pd.DataFrame:
        """
        Lit un fichier et retourne un DataFrame
        
        Args:
            file_path: Chemin vers le fichier
            file_format: Format du fichier (csv, xlsx, xls)
            
        Returns:
            DataFrame pandas
        """
        try:
            if file_format.lower() == 'csv':
                # Essayer différents encodages et séparateurs
                for encoding in ['utf-8', 'latin-1', 'cp1252']:
                    try:
                        for sep in [',', ';', '\t']:
                            try:
                                df = pd.read_csv(file_path, encoding=encoding, sep=sep)
                                if len(df.columns) > 1:  # Si on trouve plusieurs colonnes
                                    logger.info(f"Fichier CSV lu avec encodage {encoding} et séparateur '{sep}'")
                                    return df
                            except:
                                continue
                        # Si aucun séparateur ne fonctionne, utiliser la virgule par défaut
                        df = pd.read_csv(file_path, encoding=encoding)
                        logger.info(f"Fichier CSV lu avec encodage {encoding}")
                        return df
                    except UnicodeDecodeError:
                        continue
                # Si tous les encodages échouent
                raise ValueError("Impossible de lire le fichier CSV avec les encodages supportés")
            
            elif file_format.lower() in ['xlsx', 'xls']:
                df = pd.read_excel(file_path, engine='openpyxl' if file_format.lower() == 'xlsx' else 'xlrd')
                logger.info(f"Fichier Excel lu avec succès")
                return df
            
            else:
                raise ValueError(f"Format de fichier non supporté: {file_format}")
                
        except Exception as e:
            logger.error(f"Erreur lecture fichier {file_path}: {e}")
            raise
    
    def validate_columns(self, df: pd.DataFrame) -> List[str]:
        """
        Valide que les colonnes requises sont présentes
        
        Args:
            df: DataFrame à valider
            
        Returns:
            Liste des erreurs de validation
        """
        errors = []
        df_columns = [col.strip().lower() for col in df.columns]
        
        # Vérifier les colonnes requises
        for required_col in self.required_columns:
            if required_col.lower() not in df_columns:
                errors.append(f"Colonne requise manquante: {required_col}")
        
        # Logs des colonnes détectées
        logger.info(f"Colonnes détectées: {list(df.columns)}")
        logger.info(f"Colonnes requises: {self.required_columns}")
        
        return errors
    
    def clean_dataframe(self, df: pd.DataFrame) -> pd.DataFrame:
        """
        Nettoie le DataFrame (supprime les lignes/colonnes vides, etc.)
        
        Args:
            df: DataFrame à nettoyer
            
        Returns:
            DataFrame nettoyé
        """
        # Supprimer les colonnes entièrement vides
        df = df.dropna(axis=1, how='all')
        
        # Supprimer les lignes entièrement vides
        df = df.dropna(axis=0, how='all')
        
        # Nettoyer les noms de colonnes
        df.columns = [col.strip() for col in df.columns]
        
        # Réinitialiser l'index
        df = df.reset_index(drop=True)
        
        return df
    
    @abstractmethod
    def validate_row(self, row: pd.Series, row_number: int) -> Dict[str, Any]:
        """
        Valide une ligne de données
        
        Args:
            row: Ligne de données
            row_number: Numéro de la ligne
            
        Returns:
            Dictionnaire avec les résultats de validation
        """
        pass
    
    @abstractmethod
    def transform_row(self, row: pd.Series) -> Dict[str, Any]:
        """
        Transforme une ligne de données
        
        Args:
            row: Ligne de données
            
        Returns:
            Dictionnaire avec les données transformées
        """
        pass
    
    def process_dataframe(self, df: pd.DataFrame) -> List[Dict[str, Any]]:
        """
        Traite un DataFrame complet
        
        Args:
            df: DataFrame à traiter
            
        Returns:
            Liste des résultats de traitement
        """
        results = []
        
        # Nettoyer le DataFrame
        df = self.clean_dataframe(df)
        
        self.stats['total_rows'] = len(df)
        
        for index, row in df.iterrows():
            row_number = index + 1
            self.stats['processed_rows'] += 1
            
            # Valider la ligne
            validation_result = self.validate_row(row, row_number)
            
            result = {
                'row_number': row_number,
                'status': 'success',
                'original_data': row.to_dict(),
                'transformed_data': None,
                'validation_errors': validation_result.get('errors', []),
                'business_errors': validation_result.get('business_errors', []),
                'warnings': validation_result.get('warnings', [])
            }
            
            if validation_result['is_valid']:
                try:
                    # Transformer la ligne
                    transformed_data = self.transform_row(row)
                    result['transformed_data'] = transformed_data
                    self.stats['success_rows'] += 1
                except Exception as e:
                    result['status'] = 'error'
                    result['business_errors'].append(f"Erreur de transformation: {str(e)}")
                    self.stats['error_rows'] += 1
            else:
                result['status'] = 'error'
                self.stats['error_rows'] += 1
            
            if result['warnings']:
                self.stats['warnings'] += len(result['warnings'])
            
            results.append(result)
        
        logger.info(f"Traitement terminé: {self.stats['success_rows']}/{self.stats['total_rows']} réussis")
        return results


class CustomerProcessor(BaseFileProcessor):
    """
    Processeur pour les fichiers de clients
    """
    
    def validate_row(self, row: pd.Series, row_number: int) -> Dict[str, Any]:
        """
        Valide une ligne de données client
        """
        errors = []
        warnings = []
        business_errors = []
        
        # Validation du nom (requis)
        name = str(row.get('name', '')).strip()
        if not name or name.lower() in ['', 'nan', 'null']:
            errors.append("Le nom du client est requis")
        elif len(name) > 100:
            warnings.append("Le nom du client est très long (>100 caractères)")
        
        # Validation de l'email (requis)
        email = str(row.get('email', '')).strip()
        if not email or email.lower() in ['', 'nan', 'null']:
            errors.append("L'email du client est requis")
        else:
            # Validation format email
            email_pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
            if not re.match(email_pattern, email):
                errors.append("Format d'email invalide")
        
        # Validation du téléphone (optionnel)
        phone = str(row.get('phone', '')).strip()
        if phone and phone.lower() not in ['', 'nan', 'null']:
            # Nettoyer le numéro (garder seulement chiffres, +, -, espaces, parenthèses)
            clean_phone = re.sub(r'[^\d+\-\s\(\)]', '', phone)
            if len(clean_phone) < 10:
                warnings.append("Numéro de téléphone potentiellement trop court")
        
        return {
            'is_valid': len(errors) == 0,
            'errors': errors,
            'warnings': warnings,
            'business_errors': business_errors
        }
    
    def transform_row(self, row: pd.Series) -> Dict[str, Any]:
        """
        Transforme une ligne de données client
        """
        # Mapping des colonnes
        transformed = {
            'name': str(row.get('name', '')).strip(),
            'email': str(row.get('email', '')).strip().lower(),
            'phone': self._clean_phone(str(row.get('phone', '')).strip()),
            'address': str(row.get('address', '')).strip(),
            'city': str(row.get('city', '')).strip(),
            'country': str(row.get('country', 'FR')).strip().upper(),
            'created_at': datetime.now(),
            'is_active': True
        }
        
        # Supprimer les valeurs vides/nulles
        for key, value in list(transformed.items()):
            if isinstance(value, str) and value.lower() in ['', 'nan', 'null']:
                transformed[key] = None
        
        return transformed
    
    def _clean_phone(self, phone: str) -> str:
        """Nettoie un numéro de téléphone"""
        if not phone or phone.lower() in ['', 'nan', 'null']:
            return None
        
        # Garder seulement les chiffres et le + initial
        cleaned = re.sub(r'[^\d+]', '', phone)
        
        # Si ça commence par 0 et pas de +, ajouter +33 pour la France
        if cleaned.startswith('0') and not cleaned.startswith('+'):
            cleaned = '+33' + cleaned[1:]
        
        return cleaned if len(cleaned) >= 10 else None


class ProductProcessor(BaseFileProcessor):
    """
    Processeur pour les fichiers de produits
    """
    
    def validate_row(self, row: pd.Series, row_number: int) -> Dict[str, Any]:
        """
        Valide une ligne de données produit
        """
        errors = []
        warnings = []
        business_errors = []
        
        # Validation du code produit (requis et unique)
        code = str(row.get('code', '')).strip()
        if not code or code.lower() in ['', 'nan', 'null']:
            errors.append("Le code produit est requis")
        elif len(code) > 50:
            warnings.append("Le code produit est très long (>50 caractères)")
        
        # Validation du nom (requis)
        name = str(row.get('name', '')).strip()
        if not name or name.lower() in ['', 'nan', 'null']:
            errors.append("Le nom du produit est requis")
        
        # Validation du prix (requis et numérique)
        price = row.get('price', '')
        try:
            price_float = float(str(price).replace(',', '.'))
            if price_float < 0:
                errors.append("Le prix ne peut pas être négatif")
            elif price_float > 999999:
                warnings.append("Prix très élevé (>999,999)")
        except (ValueError, TypeError):
            errors.append("Le prix doit être un nombre valide")
        
        # Validation de la quantité (optionnel)
        quantity = row.get('quantity', '')
        if quantity and str(quantity).lower() not in ['', 'nan', 'null']:
            try:
                qty_int = int(float(str(quantity)))
                if qty_int < 0:
                    warnings.append("Quantité négative")
            except (ValueError, TypeError):
                warnings.append("Quantité invalide")
        
        return {
            'is_valid': len(errors) == 0,
            'errors': errors,
            'warnings': warnings,
            'business_errors': business_errors
        }
    
    def transform_row(self, row: pd.Series) -> Dict[str, Any]:
        """
        Transforme une ligne de données produit
        """
        # Nettoyer et convertir le prix
        price = row.get('price', 0)
        try:
            price = float(str(price).replace(',', '.'))
        except:
            price = 0.0
        
        # Nettoyer et convertir la quantité
        quantity = row.get('quantity', 0)
        try:
            quantity = int(float(str(quantity)))
        except:
            quantity = 0
        
        transformed = {
            'code': str(row.get('code', '')).strip().upper(),
            'name': str(row.get('name', '')).strip(),
            'description': str(row.get('description', '')).strip(),
            'price': price,
            'quantity': quantity,
            'category': str(row.get('category', 'General')).strip(),
            'unit': str(row.get('unit', 'unit')).strip(),
            'created_at': datetime.now(),
            'is_active': True
        }
        
        # Supprimer les valeurs vides/nulles
        for key, value in list(transformed.items()):
            if isinstance(value, str) and value.lower() in ['', 'nan', 'null']:
                if key in ['category', 'unit']:
                    continue  # Garder les valeurs par défaut
                transformed[key] = None
        
        return transformed


class OrderProcessor(BaseFileProcessor):
    """
    Processeur pour les fichiers de commandes
    """
    
    def validate_row(self, row: pd.Series, row_number: int) -> Dict[str, Any]:
        """
        Valide une ligne de données commande
        """
        errors = []
        warnings = []
        business_errors = []
        
        # Validation du numéro de commande (requis)
        order_number = str(row.get('order_number', '')).strip()
        if not order_number or order_number.lower() in ['', 'nan', 'null']:
            errors.append("Le numéro de commande est requis")
        
        # Validation du client (requis)
        customer_id = str(row.get('customer_id', '')).strip()
        if not customer_id or customer_id.lower() in ['', 'nan', 'null']:
            errors.append("L'ID client est requis")
        
        # Validation du total (requis et numérique)
        total = row.get('total', '')
        try:
            total_float = float(str(total).replace(',', '.'))
            if total_float < 0:
                errors.append("Le total ne peut pas être négatif")
        except (ValueError, TypeError):
            errors.append("Le total doit être un nombre valide")
        
        # Validation de la date (optionnel)
        order_date = row.get('order_date', '')
        if order_date and str(order_date).lower() not in ['', 'nan', 'null']:
            try:
                pd.to_datetime(order_date)
            except:
                warnings.append("Format de date invalide")
        
        return {
            'is_valid': len(errors) == 0,
            'errors': errors,
            'warnings': warnings,
            'business_errors': business_errors
        }
    
    def transform_row(self, row: pd.Series) -> Dict[str, Any]:
        """
        Transforme une ligne de données commande
        """
        # Nettoyer et convertir le total
        total = row.get('total', 0)
        try:
            total = float(str(total).replace(',', '.'))
        except:
            total = 0.0
        
        # Nettoyer et convertir la date
        order_date = row.get('order_date', '')
        try:
            order_date = pd.to_datetime(order_date)
        except:
            order_date = datetime.now()
        
        transformed = {
            'order_number': str(row.get('order_number', '')).strip().upper(),
            'customer_id': str(row.get('customer_id', '')).strip(),
            'total': total,
            'order_date': order_date,
            'status': str(row.get('status', 'pending')).strip().lower(),
            'notes': str(row.get('notes', '')).strip(),
            'created_at': datetime.now(),
            'updated_at': datetime.now()
        }
        
        # Supprimer les valeurs vides/nulles
        for key, value in list(transformed.items()):
            if isinstance(value, str) and value.lower() in ['', 'nan', 'null']:
                if key in ['status']:
                    continue  # Garder les valeurs par défaut
                transformed[key] = None
        
        return transformed


class CustomerInfoProcessor(BaseFileProcessor):
    """
    Processeur spécialisé pour les fichiers d'informations clients IFS
    Traite les fichiers avec colonnes détaillées (Mnémonique, Customer ID, Name, etc.)
    """
    
    def __init__(self, config: Dict[str, Any]):
        super().__init__(config)
        # Mapping des colonnes du fichier CSV vers les colonnes de la base
        self.column_mapping = {
            'mnémonique': 'customer_code',
            'mnemonic': 'customer_code',
            'customer id': 'customer_id',
            'customer_id': 'customer_id',
            'name': 'name',
            'nom': 'name',
            'date': 'creation_date',
            'customer asso': 'association_no',
            'customer_asso': 'association_no',
            'customer party': 'party',
            'customer_party': 'party',
            'customer domaine': 'default_domain',
            'customer_domaine': 'default_domain',
            'customer langue': 'language_code',
            'customer_langue': 'language_code',
            'customer id langue': 'language_code',
            'customer pays': 'country',
            'customer_pays': 'country',
            'customer id pays': 'country_code',
            'customer_id_pays': 'country_code',
            'customer corporate': 'corporate_form',
            'customer_corporate': 'corporate_form',
            'customer id ref': 'reference_id',
            'customer_id_ref': 'reference_id',
            'customer ref valid': 'reference_validation',
            'customer_ref_valid': 'reference_validation',
            'customer picture': 'picture_id',
            'customer_picture': 'picture_id',
            'customer one time': 'one_time_customer',
            'customer_one_time': 'one_time_customer',
            'customer one time db': 'one_time_db',
            'customer_one_time_db': 'one_time_db',
            'customer categorie': 'category',
            'customer_categorie': 'category',
            'customer id categorie': 'category_id',
            'customer_id_categorie': 'category_id',
            'customer btob': 'b2b_customer',
            'customer_btob': 'b2b_customer',
            'customer btob id': 'b2b_customer_id',
            'customer_btob_id': 'b2b_customer_id',
            'customer taxe type': 'tax_type',
            'customer_taxe_type': 'tax_type',
            'customer business': 'business_type',
            'customer_business': 'business_type',
            'customer date reg': 'registration_date',
            'customer_date_reg': 'registration_date'
        }
    
    def _normalize_column_name(self, col_name: str) -> str:
        """Normalise un nom de colonne pour le mapping"""
        return col_name.strip().lower()
    
    def _get_mapped_column(self, original_column: str) -> str:
        """Récupère le nom de colonne mappé"""
        normalized = self._normalize_column_name(original_column)
        return self.column_mapping.get(normalized, original_column)
    
    def validate_row(self, row: pd.Series, row_number: int) -> Dict[str, Any]:
        """
        Valide une ligne de données client IFS
        """
        errors = []
        warnings = []
        business_errors = []
        
        # Créer un mapping des données pour faciliter l'accès
        mapped_data = {}
        for col_name, value in row.items():
            mapped_col = self._get_mapped_column(col_name)
            mapped_data[mapped_col] = value
        
        # Validation Customer ID (requis)
        customer_id = str(mapped_data.get('customer_id', '')).strip()
        if not customer_id or customer_id.lower() in ['', 'nan', 'null']:
            errors.append("Customer ID est requis")
        elif len(customer_id) > 20:
            errors.append("Customer ID trop long (max 20 caractères)")
        
        # Validation Name (requis)
        name = str(mapped_data.get('name', '')).strip()
        if not name or name.lower() in ['', 'nan', 'null']:
            errors.append("Le nom du client est requis")
        elif len(name) > 100:
            warnings.append("Le nom du client est très long (>100 caractères)")
        
        # Validation Customer Code/Mnémonique (requis pour l'unicité)
        customer_code = str(mapped_data.get('customer_code', '')).strip()
        if not customer_code or customer_code.lower() in ['', 'nan', 'null']:
            errors.append("Le code client (Mnémonique) est requis")
        elif len(customer_code) > 50:
            warnings.append("Le code client est très long (>50 caractères)")
        
        # Validation des valeurs booléennes
        boolean_fields = ['one_time_customer', 'one_time_db', 'b2b_customer']
        for field in boolean_fields:
            value = str(mapped_data.get(field, '')).strip().lower()
            if value and value not in ['', 'nan', 'null', 'true', 'false', 'vrai', 'faux', '1', '0']:
                warnings.append(f"Valeur booléenne invalide pour {field}: {value}")
        
        # Validation codes pays (2 caractères)
        country_code = str(mapped_data.get('country_code', '')).strip()
        if country_code and len(country_code) != 2:
            warnings.append("Le code pays doit faire 2 caractères")
        
        # Validation langue (2-5 caractères)
        language_code = str(mapped_data.get('language_code', '')).strip()
        if language_code and (len(language_code) < 2 or len(language_code) > 5):
            warnings.append("Le code langue doit faire entre 2 et 5 caractères")
        
        # Validation domaine (max 5 caractères selon config)
        default_domain = str(mapped_data.get('default_domain', '')).strip()
        if default_domain and len(default_domain) > 5:
            warnings.append("Le domaine par défaut est trop long (max 5 caractères)")
        
        # Validation des dates
        date_fields = ['creation_date', 'registration_date']
        for field in date_fields:
            date_value = mapped_data.get(field, '')
            if date_value and str(date_value).lower() not in ['', 'nan', 'null']:
                try:
                    pd.to_datetime(date_value)
                except:
                    warnings.append(f"Format de date invalide pour {field}: {date_value}")
        
        return {
            'is_valid': len(errors) == 0,
            'errors': errors,
            'warnings': warnings,
            'business_errors': business_errors
        }
    
    def transform_row(self, row: pd.Series) -> Dict[str, Any]:
        """
        Transforme une ligne de données client IFS
        """
        # Créer un mapping des données
        mapped_data = {}
        for col_name, value in row.items():
            mapped_col = self._get_mapped_column(col_name)
            mapped_data[mapped_col] = value
        
        # Fonction utilitaire pour nettoyer les valeurs booléennes
        def clean_boolean(value, default=False):
            if not value or str(value).lower() in ['', 'nan', 'null']:
                return default
            str_value = str(value).strip().lower()
            return str_value in ['true', 'vrai', '1', 'oui', 'yes']
        
        # Fonction utilitaire pour nettoyer les dates
        def clean_date(value):
            if not value or str(value).lower() in ['', 'nan', 'null']:
                return None
            try:
                return pd.to_datetime(value).strftime('%Y-%m-%d')
            except:
                return None
        
        # Construire l'objet transformé selon la structure IFS
        transformed = {
            # Colonnes principales requises
            'customer_id': str(mapped_data.get('customer_id', '')).strip(),
            'name': str(mapped_data.get('name', '')).strip(),
            
            # Informations de base
            'customer_code': str(mapped_data.get('customer_code', '')).strip().upper(),
            'creation_date': clean_date(mapped_data.get('creation_date')),
            'registration_date': clean_date(mapped_data.get('registration_date')),
            
            # Informations organisationnelles
            'association_no': str(mapped_data.get('association_no', '')).strip() or None,
            'party': str(mapped_data.get('party', '')).strip() or 'CUSTOMER',
            'default_domain': str(mapped_data.get('default_domain', '')).strip() or None,
            
            # Informations géographiques et linguistiques
            'country': str(mapped_data.get('country', '')).strip() or None,
            'country_code': str(mapped_data.get('country_code', '')).strip().upper() or None,
            'language_code': str(mapped_data.get('language_code', '')).strip().lower() or None,
            
            # Informations business
            'corporate_form': str(mapped_data.get('corporate_form', '')).strip() or None,
            'business_type': str(mapped_data.get('business_type', '')).strip() or None,
            'tax_type': str(mapped_data.get('tax_type', '')).strip() or None,
            
            # Références et validations
            'reference_id': str(mapped_data.get('reference_id', '')).strip() or None,
            'reference_validation': str(mapped_data.get('reference_validation', '')).strip() or None,
            'picture_id': str(mapped_data.get('picture_id', '')).strip() or None,
            
            # Catégorisation
            'category': str(mapped_data.get('category', '')).strip() or 'CUSTOMER',
            'category_id': str(mapped_data.get('category_id', '')).strip() or None,
            
            # Flags booléens
            'one_time_customer': clean_boolean(mapped_data.get('one_time_customer'), False),
            'one_time_db': clean_boolean(mapped_data.get('one_time_db'), False),
            'b2b_customer': clean_boolean(mapped_data.get('b2b_customer'), True),
            'b2b_customer_id': str(mapped_data.get('b2b_customer_id', '')).strip() or None,
            
            # Métadonnées système
            'created_at': datetime.now(),
            'updated_at': datetime.now(),
            'is_active': True,
            'import_source': 'csv_import'
        }
        
        # Nettoyer les valeurs vides/nulles finales
        for key, value in list(transformed.items()):
            if isinstance(value, str) and value.lower() in ['', 'nan', 'null']:
                # Garder les valeurs par défaut pour certains champs
                if key in ['party', 'category']:
                    continue
                transformed[key] = None
        
        return transformed


class RawDataProcessor(BaseFileProcessor):
    """
    Processeur simplifié pour import brut de données CSV vers raw_data
    Aucune validation complexe, mapping direct des colonnes
    """
    
    def __init__(self, config: Dict[str, Any]):
        super().__init__(config)
        self.separator = config.get('separator', ';')
        self.encoding = config.get('encoding', 'utf-8')
        self.has_header = config.get('has_header', True)
        self.skip_rows = config.get('skip_rows', 0)
        self.target_table = config.get('target_table', 'customer_info')
        self.target_schema = config.get('target_schema', 'raw_data')
    
    def process_file(self, file_path: str) -> Tuple[pd.DataFrame, Dict[str, Any]]:
        """
        Traite le fichier CSV en mode brut - aucune validation complexe
        """
        try:
            logger.info(f"Début du traitement du fichier: {file_path}")
            
            # Lecture du fichier avec les paramètres de la config
            df = pd.read_csv(
                file_path,
                sep=self.separator,
                encoding=self.encoding,
                header=0 if self.has_header else None,
                skiprows=self.skip_rows,
                dtype=str  # Tout en string pour éviter les erreurs de type
            )
            
            logger.info(f"Fichier lu: {len(df)} lignes, {len(df.columns)} colonnes")
            
            # Normalisation des noms de colonnes (snake_case)
            df.columns = [self._normalize_column_name(col) for col in df.columns]
            
            # Nettoyage des données de base
            df = self._clean_data(df)
            
            # Ajout des colonnes techniques
            df['import_date'] = datetime.now()
            df['import_file_name'] = file_path.split('/')[-1].split('\\')[-1]  # Compatible Windows/Linux
            df['import_batch_id'] = f"batch_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
            
            # Mise à jour des statistiques
            self.stats['total_rows'] = len(df)
            self.stats['processed_rows'] = len(df)
            self.stats['success_rows'] = len(df)
            
            logger.info(f"Traitement terminé: {self.stats['success_rows']} lignes traitées")
            
            return df, self.stats
            
        except Exception as e:
            logger.error(f"Erreur lors du traitement du fichier: {e}")
            self.stats['error_rows'] = self.stats.get('total_rows', 0)
            raise
    
    def _normalize_column_name(self, col_name: str) -> str:
        """
        Convertit les noms de colonnes CSV en noms de colonnes DB
        """
        # Mapping spécifique pour customer_info
        mappings = {
            'Mnémonique': 'mnemonique',
            'Customer ID': 'customer_id', 
            'Name': 'name',
            'Date': 'date_creation',
            'Customer Asso': 'customer_asso',
            'Customer Party': 'customer_party',
            'Customer Domaine': 'customer_domaine',
            'Customer Langue': 'customer_langue',
            'Customer ID Langue': 'customer_id_langue',
            'Customer Pays': 'customer_pays',
            'Customer ID Pays': 'customer_id_pays',
            'Customer ID Party': 'customer_id_party',
            'Customer Corporate': 'customer_corporate',
            'Customer Id REF': 'customer_id_ref',
            'Customer REF Valid': 'customer_ref_valid',
            'Customer REF ID Valid': 'customer_ref_id_valid',
            'Customer Picture': 'customer_picture',
            'Customer One time': 'customer_one_time',
            'Customer One time DB': 'customer_one_time_db',
            'Customer Categorie': 'customer_categorie',
            'Customer ID Categorie': 'customer_id_categorie',
            'Customer BtoB': 'customer_btob',
            'Customer BtoB ID': 'customer_btob_id',
            'Customer Taxe Type': 'customer_taxe_type',
            'Customer Business': 'customer_business',
            'Customer Date Reg': 'customer_date_reg'
        }
        
        return mappings.get(col_name, col_name.lower().replace(' ', '_'))
    
    def _clean_data(self, df: pd.DataFrame) -> pd.DataFrame:
        """
        Nettoyage de base des données
        """
        # Suppression des lignes complètement vides
        df = df.dropna(how='all')
        
        # Conversion des dates
        date_columns = ['date_creation', 'customer_date_reg']
        for col in date_columns:
            if col in df.columns:
                df[col] = pd.to_datetime(df[col], errors='coerce', dayfirst=True)
        
        # Nettoyage des chaînes de caractères
        string_columns = df.select_dtypes(include=['object']).columns
        for col in string_columns:
            if col not in ['date_creation', 'customer_date_reg']:  # Éviter les colonnes de dates
                # Nettoyer les valeurs problématiques et convertir en chaînes
                df[col] = df[col].apply(
                    lambda x: '' if x is None or pd.isna(x) or str(x).lower() in ['none', 'nan', 'null'] else str(x)
                ).str.strip()
        
        return df

    def validate_data(self, df: pd.DataFrame) -> Tuple[pd.DataFrame, List[Dict[str, Any]]]:
        """
        Validation minimale - juste vérifier que les colonnes critiques existent
        """
        warnings = []
        
        # Vérifications de base
        if 'customer_id' not in df.columns:
            warnings.append({
                'type': 'missing_column',
                'message': 'Colonne customer_id manquante',
                'severity': 'warning'
            })
        
        if 'name' not in df.columns:
            warnings.append({
                'type': 'missing_column', 
                'message': 'Colonne name manquante',
                'severity': 'warning'
            })
        
        # Compter les lignes avec des données critiques manquantes
        if 'customer_id' in df.columns:
            missing_ids = df['customer_id'].isna().sum()
            if missing_ids > 0:
                warnings.append({
                    'type': 'missing_data',
                    'message': f'{missing_ids} lignes sans customer_id',
                    'severity': 'warning'
                })
        
        return df, warnings


class FileProcessorFactory:
    """
    Factory pour créer les processeurs appropriés selon le type de fichier
    """
    
    @staticmethod
    def create_processor(file_type: str, config: Dict[str, Any]) -> BaseFileProcessor:
        """
        Crée un processeur selon le type de fichier
        
        Args:
            file_type: Type de fichier (customers, products, orders, customer_info)
            config: Configuration du processeur
            
        Returns:
            Instance du processeur approprié
        """
        processors = {
            'customers': CustomerInfoProcessor,  # Ancien processeur
            'customer_info': RawDataProcessor,   # Nouveau processeur simplifié
            'products': ProductProcessor,
            'orders': OrderProcessor
        }
        
        processor_class = processors.get(file_type.lower())
        if not processor_class:
            raise ValueError(f"Type de fichier non supporté: {file_type}")
        
        return processor_class(config)
    
    @staticmethod
    def create_processor_by_class_name(class_name: str, config: Dict[str, Any]) -> BaseFileProcessor:
        """
        Crée un processeur selon le nom de la classe
        
        Args:
            class_name: Nom de la classe processeur
            config: Configuration du processeur
            
        Returns:
            Instance du processeur approprié
        """
        processors = {
            'CustomerProcessor': CustomerProcessor,
            'CustomerInfoProcessor': CustomerInfoProcessor,
            'ProductProcessor': ProductProcessor,
            'OrderProcessor': OrderProcessor,
            'RawDataProcessor': RawDataProcessor  # Nouveau processeur
        }
        
        processor_class = processors.get(class_name)
        if not processor_class:
            raise ValueError(f"Classe processeur non supportée: {class_name}")
        
        return processor_class(config)
    
    @staticmethod
    def get_supported_types() -> List[str]:
        """
        Retourne la liste des types de fichiers supportés
        """
        return ['customers', 'customer_info', 'products', 'orders'] 