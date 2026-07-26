"""
Utilitaires de validation pour le système d'import et autres fonctionnalités
"""

import re
import os
from typing import Dict, List, Any, Tuple


def validate_file_name(filename: str) -> Dict[str, Any]:
    """
    Valide un nom de fichier
    
    Args:
        filename: Nom du fichier à valider
        
    Returns:
        Dict avec is_valid (bool) et errors (list)
    """
    errors = []
    
    if not filename:
        errors.append("Nom de fichier vide")
        return {"is_valid": False, "errors": errors}
    
    # Vérifier la longueur
    if len(filename) > 255:
        errors.append("Nom de fichier trop long (max 255 caractères)")
    
    # Vérifier les caractères dangereux
    dangerous_chars = ['<', '>', ':', '"', '|', '?', '*', '\0']
    for char in dangerous_chars:
        if char in filename:
            errors.append(f"Caractère non autorisé: {char}")
    
    # Vérifier les noms réservés Windows
    reserved_names = ['CON', 'PRN', 'AUX', 'NUL', 'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9', 'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9']
    name_without_ext = os.path.splitext(filename)[0].upper()
    if name_without_ext in reserved_names:
        errors.append("Nom de fichier réservé par le système")
    
    # Vérifier l'extension
    if '.' not in filename:
        errors.append("Extension de fichier manquante")
    else:
        ext = filename.split('.')[-1].lower()
        allowed_extensions = ['csv', 'xlsx', 'xls']
        if ext not in allowed_extensions:
            errors.append(f"Extension non autorisée: {ext}. Extensions autorisées: {', '.join(allowed_extensions)}")
    
    return {
        "is_valid": len(errors) == 0,
        "errors": errors
    }


def sanitize_file_name(filename: str) -> str:
    """
    Nettoie un nom de fichier en supprimant/remplaçant les caractères dangereux
    
    Args:
        filename: Nom de fichier à nettoyer
        
    Returns:
        Nom de fichier nettoyé
    """
    if not filename:
        return "unnamed_file"
    
    # Remplacer les caractères dangereux par des underscores
    dangerous_chars = ['<', '>', ':', '"', '|', '?', '*', '\0', '/', '\\']
    for char in dangerous_chars:
        filename = filename.replace(char, '_')
    
    # Supprimer les espaces en début/fin
    filename = filename.strip()
    
    # Remplacer les espaces multiples par un seul underscore
    filename = re.sub(r'\s+', '_', filename)
    
    # Limiter la longueur
    if len(filename) > 200:
        name, ext = os.path.splitext(filename)
        filename = name[:200-len(ext)] + ext
    
    # S'assurer qu'il y a au moins un caractère
    if not filename or filename == '.':
        filename = "unnamed_file.txt"
    
    return filename


def format_file_size(size_bytes: int) -> str:
    """
    Formate une taille de fichier en unités lisibles
    
    Args:
        size_bytes: Taille en bytes
        
    Returns:
        Taille formatée (ex: "1.5 MB")
    """
    if size_bytes == 0:
        return "0 B"
    
    units = ['B', 'KB', 'MB', 'GB', 'TB']
    size = float(size_bytes)
    unit_index = 0
    
    while size >= 1024.0 and unit_index < len(units) - 1:
        size /= 1024.0
        unit_index += 1
    
    if unit_index == 0:
        return f"{int(size)} {units[unit_index]}"
    else:
        return f"{size:.1f} {units[unit_index]}"


def validate_file_size(size_bytes: int, max_size: int) -> bool:
    """
    Valide la taille d'un fichier
    
    Args:
        size_bytes: Taille du fichier en bytes
        max_size: Taille maximale autorisée en bytes
        
    Returns:
        True si la taille est valide
    """
    return 0 < size_bytes <= max_size


def validate_file_format(file_format: str, allowed_formats: List[str]) -> bool:
    """
    Valide le format d'un fichier
    
    Args:
        file_format: Extension du fichier
        allowed_formats: Liste des formats autorisés
        
    Returns:
        True si le format est autorisé
    """
    return file_format.lower() in [fmt.lower() for fmt in allowed_formats]


# Validators existants pour compatibilité

def validate_pagination(page: int, per_page: int, max_per_page: int = 1000) -> Tuple[int, int]:
    """
    Valide et normalise les paramètres de pagination
    
    Args:
        page: Numéro de page
        per_page: Éléments par page
        max_per_page: Maximum d'éléments par page autorisé
        
    Returns:
        Tuple (page, per_page) validé
    """
    page = max(1, page) if page else 1
    per_page = min(max(1, per_page), max_per_page) if per_page else 20
    return page, per_page


def validate_table_name(table_name: str) -> bool:
    """
    Valide un nom de table SQL
    
    Args:
        table_name: Nom de la table
        
    Returns:
        True si le nom est valide
    """
    if not table_name:
        return False
    
    # Vérifier que le nom ne contient que des caractères autorisés
    pattern = r'^[a-zA-Z_][a-zA-Z0-9_]*$'
    return bool(re.match(pattern, table_name))


def validate_fields(fields: List[str]) -> bool:
    """
    Valide une liste de noms de champs
    
    Args:
        fields: Liste des noms de champs
        
    Returns:
        True si tous les noms sont valides
    """
    if not fields:
        return False
    
    for field in fields:
        if not validate_table_name(field):  # Même règles que les tables
            return False
    
    return True


def sanitize_filter_value(value: str) -> str:
    """
    Nettoie une valeur de filtre pour éviter les injections SQL
    
    Args:
        value: Valeur à nettoyer
        
    Returns:
        Valeur nettoyée
    """
    if not value:
        return ""
    
    # Supprimer les caractères potentiellement dangereux
    value = str(value)
    value = value.replace("'", "''")  # Échapper les apostrophes
    value = value.replace(";", "")    # Supprimer les points-virgules
    value = value.replace("--", "")   # Supprimer les commentaires SQL
    
    return value 