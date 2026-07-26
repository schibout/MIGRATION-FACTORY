#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
Module utilitaire pour standardiser le traitement des valeurs nulles pour différents types de données.
Utilisé par les modules ETL pour assurer la cohérence des données importées.

Règles de standardisation:
- VARCHAR/TEXT : NULL -> "" (chaîne vide)
- NUMERIC/INTEGER/DECIMAL : NULL -> 0
- BOOLEAN : NULL -> False
- DATE/TIMESTAMP : NULL -> None (garde None pour les dates nulles)
"""

import pandas as pd
import numpy as np
import logging
from typing import Dict, Any, List, Union, Optional
from sqlalchemy import create_engine, inspect, Column, text

# Configuration du logging
logger = logging.getLogger(__name__)

class DataSanitizer:
    """
    Classe utilitaire pour standardiser les valeurs nulles et invalides dans les données
    avant importation/exportation vers/depuis la base de données.
    """
    
    @staticmethod
    def get_column_types(engine, table_name: str, schema: str = 'public') -> Dict[str, Dict[str, Any]]:
        """
        Récupère les types de colonnes et leurs contraintes pour une table donnée
        
        Args:
            engine: Connexion SQLAlchemy
            table_name: Nom de la table
            schema: Schéma de la table (défaut: 'public')
            
        Returns:
            Dictionnaire {nom_colonne: {type: type_colonne, max_length: longueur_max, ...}}
        """
        try:
            inspector = inspect(engine)
            columns = inspector.get_columns(table_name, schema)
            column_info = {}
            
            for col in columns:
                col_type = str(col['type'])
                col_name = col['name']
                
                # Initialisation des informations de colonne
                column_info[col_name] = {
                    'type': col_type,
                    'max_length': None,
                    'nullable': col.get('nullable', True)
                }
                
                # Extraire la longueur maximale pour les types character varying
                if 'character varying' in col_type or 'varchar' in col_type:
                    # Extraction de la longueur entre parenthèses
                    import re
                    match = re.search(r'\((\d+)\)', col_type)
                    if match:
                        max_length = int(match.group(1))
                        column_info[col_name]['max_length'] = max_length
                        logger.debug(f"Colonne {col_name}: longueur max = {max_length}")
            
            # Si certaines colonnes n'ont pas de longueur maximale définie, essayer de les récupérer
            # via information_schema pour plus de précision
            try:
                missing_lengths = [col for col, info in column_info.items() 
                                  if info['max_length'] is None and 
                                  ('varchar' in info['type'].lower() or 'character' in info['type'].lower())]
                
                if missing_lengths:
                    with engine.connect() as conn:
                        query = text("""
                            SELECT column_name, character_maximum_length
                            FROM information_schema.columns
                            WHERE table_schema = :schema
                            AND table_name = :table_name
                            AND column_name IN :column_names
                        """)
                        
                        result = conn.execute(query, {
                            'schema': schema,
                            'table_name': table_name,
                            'column_names': tuple(missing_lengths)
                        })
                        
                        for row in result:
                            col_name = row[0]
                            max_length = row[1]
                            if max_length is not None:
                                column_info[col_name]['max_length'] = max_length
                                logger.debug(f"Colonne {col_name}: longueur max (from info_schema) = {max_length}")
            
            except Exception as e:
                logger.warning(f"Impossible de récupérer les longueurs supplémentaires via information_schema: {str(e)}")
            
            logger.info(f"Types et contraintes de colonnes récupérés pour {len(column_info)} colonnes")
            return column_info
            
        except Exception as e:
            logger.error(f"Erreur lors de la récupération des types de colonnes: {str(e)}")
            return {}

    @staticmethod
    def truncate_string(value: str, max_length: int) -> str:
        """
        Tronque une chaîne si elle dépasse la longueur maximale
        
        Args:
            value: Chaîne à tronquer
            max_length: Longueur maximale
            
        Returns:
            Chaîne tronquée si nécessaire
        """
        if not isinstance(value, str) or max_length is None:
            return value
            
        if len(value) > max_length:
            logger.debug(f"Troncature de la chaîne '{value}' à {max_length} caractères")
            return value[:max_length]
            
        return value
    
    @staticmethod
    def sanitize_dataframe(df: pd.DataFrame, column_types: Dict[str, Dict[str, Any]]) -> pd.DataFrame:
        """
        Standardise les valeurs nulles ou invalides dans un DataFrame selon le type de chaque colonne
        
        Args:
            df: DataFrame à nettoyer
            column_types: Dictionnaire des infos de colonnes {nom_colonne: {type, max_length, ...}}
            
        Returns:
            DataFrame nettoyé
        """
        df_copy = df.copy()
        
        for col_name, col_info in column_types.items():
            if col_name not in df_copy.columns:
                continue
                
            # Extraction des infos de colonne
            col_type = col_info['type'].lower()
            max_length = col_info.get('max_length')
            
            # 1. Types VARCHAR/TEXT
            if any(t in col_type for t in ['varchar', 'char', 'text']):
                # Valeur par défaut pour NULL : chaîne vide
                default_value = ''
                
                # Remplacer les valeurs NULL par une chaîne vide
                df_copy[col_name] = df_copy[col_name].fillna(default_value)
                
                # Tronquer les chaînes trop longues
                if max_length is not None:
                    df_copy[col_name] = df_copy[col_name].apply(
                        lambda x: DataSanitizer.truncate_string(x, max_length)
                    )
                
                # Convertir en str mais gérer les valeurs None/NaN/null/NULL
                df_copy[col_name] = df_copy[col_name].apply(
                    lambda x: '' if x is None or pd.isna(x) or str(x).lower() in ['none', 'null'] else str(x)
                )
                
            # 2. Types NUMERIC
            elif any(t in col_type for t in ['numeric', 'decimal', 'int', 'float', 'double']):
                # Remplacer les chaînes vides par NaN d'abord
                df_copy[col_name] = df_copy[col_name].replace('', np.nan)
                # Puis remplacer NaN par 0
                df_copy[col_name] = df_copy[col_name].fillna(0)
                
            # 3. Types BOOLEAN
            elif 'boolean' in col_type or 'bool' in col_type:
                df_copy[col_name] = df_copy[col_name].fillna(False)
                
            # 4. Types DATE/TIMESTAMP
            elif any(t in col_type for t in ['date', 'timestamp', 'time']):
                # Pour les dates, on garde None
                df_copy[col_name] = df_copy[col_name].replace({pd.NaT: None})
        
        return df_copy
    
    @staticmethod
    def sanitize_dictionary(data: Dict[str, Any], column_types: Dict[str, Dict[str, Any]]) -> Dict[str, Any]:
        """
        Standardise les valeurs nulles ou invalides dans un dictionnaire selon le type de chaque colonne
        
        Args:
            data: Dictionnaire à nettoyer {nom_colonne: valeur}
            column_types: Dictionnaire des infos de colonnes {nom_colonne: {type, max_length, ...}}
            
        Returns:
            Dictionnaire nettoyé
        """
        result = {}
        
        for col_name, value in data.items():
            # Si la colonne n'existe pas dans les types connus, garder la valeur telle quelle
            if col_name not in column_types:
                result[col_name] = value
                continue
            
            col_info = column_types[col_name]
            col_type = col_info['type'].lower()
            max_length = col_info.get('max_length')
            
            # Si la valeur n'est pas NULL, vérifier si elle nécessite une troncature
            if value is not None:
                if isinstance(value, str) and max_length is not None:
                    result[col_name] = DataSanitizer.truncate_string(value, max_length)
                else:
                    result[col_name] = value
                continue
            
            # Traitement des valeurs NULL selon le type
            # 1. Types VARCHAR/TEXT
            if any(t in col_type for t in ['varchar', 'char', 'text']):
                # Utiliser une chaîne vide pour les valeurs NULL
                result[col_name] = ''
                
            # 2. Types NUMERIC
            elif any(t in col_type for t in ['numeric', 'decimal', 'int', 'float', 'double']):
                result[col_name] = 0
                
            # 3. Types BOOLEAN
            elif 'boolean' in col_type or 'bool' in col_type:
                result[col_name] = False
                
            # 4. Types DATE/TIMESTAMP
            elif any(t in col_type for t in ['date', 'timestamp', 'time']):
                result[col_name] = None
            
            # Type inconnu, conserver None
            else:
                result[col_name] = None
        
        return result
    
    @staticmethod
    def sanitize_list(data_list: List[Dict[str, Any]], column_types: Dict[str, Dict[str, Any]]) -> List[Dict[str, Any]]:
        """
        Standardise les valeurs nulles ou invalides dans une liste de dictionnaires
        
        Args:
            data_list: Liste de dictionnaires à nettoyer
            column_types: Dictionnaire des infos de colonnes {nom_colonne: {type, max_length, ...}}
            
        Returns:
            Liste de dictionnaires nettoyée
        """
        return [DataSanitizer.sanitize_dictionary(item, column_types) for item in data_list]
    
    @staticmethod
    def sanitize_value(value: Any, column_type: str, max_length: int = None) -> Any:
        """
        Standardise une valeur unique selon son type de colonne
        
        Args:
            value: Valeur à standardiser
            column_type: Type de colonne (varchar, numeric, boolean, etc.)
            max_length: Longueur maximale pour les types chaîne
            
        Returns:
            Valeur standardisée
        """
        if value is not None:
            # Si c'est une chaîne, vérifier la troncature
            if isinstance(value, str) and max_length is not None:
                return DataSanitizer.truncate_string(value, max_length)
            return value
            
        col_type_lower = column_type.lower()
        
        # 1. Types VARCHAR/TEXT
        if any(t in col_type_lower for t in ['varchar', 'char', 'text']):
            # Utiliser une chaîne vide pour les valeurs NULL
            return ''
            
        # 2. Types NUMERIC
        elif any(t in col_type_lower for t in ['numeric', 'decimal', 'int', 'float', 'double']):
            return 0
            
        # 3. Types BOOLEAN
        elif 'boolean' in col_type_lower or 'bool' in col_type_lower:
            return False
            
        # 4. Types DATE/TIMESTAMP
        elif any(t in col_type_lower for t in ['date', 'timestamp', 'time']):
            return None
        
        # Type inconnu, conserver None
        return None 