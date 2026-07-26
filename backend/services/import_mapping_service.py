"""
Service for intelligent column mapping between source files and target database tables.
Provides smart auto-matching based on column names, types, and patterns.
"""

from typing import Dict, Any, List, Optional, Tuple
from difflib import SequenceMatcher
import re
from datetime import datetime


class ImportMappingService:
    """Service for managing column mappings in generic imports."""

    # Type compatibility mappings
    TEXT_TYPES = {'text', 'varchar', 'character varying', 'char', 'string', 'nvarchar'}
    NUMERIC_TYPES = {'integer', 'bigint', 'smallint', 'numeric', 'decimal', 'real', 
                    'double precision', 'float', 'int', 'number'}
    DATE_TYPES = {'date', 'timestamp', 'timestamp without time zone', 
                 'timestamp with time zone', 'datetime', 'time'}
    BOOLEAN_TYPES = {'boolean', 'bool', 'bit'}

    # Common column name variations/synonyms
    COLUMN_SYNONYMS = {
        'id': ['identifier', 'code', 'key', 'pk'],
        'name': ['nom', 'label', 'title', 'libelle', 'designation'],
        'description': ['desc', 'descr', 'detail', 'details', 'comment', 'comments', 'remarque'],
        'date': ['dt', 'created', 'modified', 'updated'],
        'email': ['mail', 'e-mail', 'courriel'],
        'phone': ['tel', 'telephone', 'mobile', 'fax'],
        'address': ['adresse', 'addr', 'street', 'rue'],
        'city': ['ville', 'town'],
        'country': ['pays', 'nation'],
        'price': ['prix', 'cost', 'amount', 'montant', 'tarif'],
        'quantity': ['qty', 'qte', 'quantite', 'count', 'nombre'],
        'status': ['statut', 'state', 'etat'],
        'type': ['category', 'categorie', 'kind', 'genre'],
        'user': ['utilisateur', 'owner', 'created_by', 'modified_by'],
        'number': ['num', 'no', 'numero'],
    }

    def __init__(self):
        # Build reverse lookup for synonyms
        self._synonym_lookup = {}
        for base, synonyms in self.COLUMN_SYNONYMS.items():
            self._synonym_lookup[base] = base
            for syn in synonyms:
                self._synonym_lookup[syn] = base

    def calculate_similarity(self, str1: str, str2: str) -> float:
        """
        Calculate similarity between two strings.
        Returns a value between 0 and 1.
        """
        # Normalize strings
        s1 = self._normalize_column_name(str1)
        s2 = self._normalize_column_name(str2)
        
        return SequenceMatcher(None, s1, s2).ratio()

    def _normalize_column_name(self, name: str) -> str:
        """Normalize a column name for comparison."""
        # Convert to lowercase
        normalized = name.lower()
        # Remove common prefixes/suffixes
        prefixes_to_remove = ['col_', 'fld_', 'field_', 'f_', 'c_']
        for prefix in prefixes_to_remove:
            if normalized.startswith(prefix):
                normalized = normalized[len(prefix):]
        # Remove underscores, dashes, spaces
        normalized = re.sub(r'[_\-\s]+', '', normalized)
        return normalized

    def _get_base_concept(self, name: str) -> Optional[str]:
        """Get the base concept from a column name using synonyms."""
        normalized = self._normalize_column_name(name)
        
        # Check direct match
        if normalized in self._synonym_lookup:
            return self._synonym_lookup[normalized]
        
        # Check if name contains a known synonym
        for syn, base in self._synonym_lookup.items():
            if syn in normalized or normalized in syn:
                return base
        
        return None

    def are_types_compatible(self, source_type: str, target_type: str) -> bool:
        """Check if source and target types are compatible for data transfer."""
        source = source_type.lower()
        target = target_type.lower()
        
        # Same type family
        if source in self.TEXT_TYPES and target in self.TEXT_TYPES:
            return True
        if source in self.NUMERIC_TYPES and target in self.NUMERIC_TYPES:
            return True
        if source in self.DATE_TYPES and target in self.DATE_TYPES:
            return True
        if source in self.BOOLEAN_TYPES and target in self.BOOLEAN_TYPES:
            return True
        
        # Text can go to anything (with conversion)
        if source in self.TEXT_TYPES:
            return True
        
        # Numeric to text is ok
        if source in self.NUMERIC_TYPES and target in self.TEXT_TYPES:
            return True
        
        return False

    def calculate_match_score(
        self, 
        source_col: Dict[str, Any], 
        target_col: Dict[str, Any]
    ) -> int:
        """
        Calculate a match score between a source column and target column.
        Score ranges from 0 to 100.
        """
        source_name = source_col.get('name', '')
        target_name = target_col.get('name', '')
        source_type = source_col.get('detectedType', 'text')
        target_type = target_col.get('data_type', 'text')
        
        score = 0
        
        # Exact match (case insensitive)
        if source_name.lower() == target_name.lower():
            score = 100
        # Exact match after normalization
        elif self._normalize_column_name(source_name) == self._normalize_column_name(target_name):
            score = 95
        else:
            # Check semantic similarity via synonyms
            source_concept = self._get_base_concept(source_name)
            target_concept = self._get_base_concept(target_name)
            
            if source_concept and target_concept and source_concept == target_concept:
                score = 80
            # Contains match
            elif (source_name.lower() in target_name.lower() or 
                  target_name.lower() in source_name.lower()):
                score = 70
            else:
                # String similarity
                similarity = self.calculate_similarity(source_name, target_name)
                if similarity > 0.8:
                    score = int(similarity * 75)
                elif similarity > 0.6:
                    score = int(similarity * 60)
                elif similarity > 0.4:
                    score = int(similarity * 40)
        
        # Type compatibility bonus
        if score > 0 and self.are_types_compatible(source_type, target_type):
            score = min(100, score + 10)
        elif score > 0 and not self.are_types_compatible(source_type, target_type):
            score = max(0, score - 20)  # Penalty for incompatible types
        
        return score

    def suggest_mapping(
        self, 
        source_columns: List[Dict[str, Any]], 
        target_columns: List[Dict[str, Any]],
        threshold: int = 40
    ) -> List[Dict[str, Any]]:
        """
        Generate mapping suggestions between source and target columns.
        
        Args:
            source_columns: List of source column info dicts
            target_columns: List of target column info dicts
            threshold: Minimum score to consider a match
            
        Returns:
            List of mapping suggestions with confidence scores
        """
        mappings = []
        used_targets = set()
        
        # First pass: find best matches for each source
        source_scores = []
        for source in source_columns:
            best_match = None
            best_score = 0
            
            for target in target_columns:
                score = self.calculate_match_score(source, target)
                if score > best_score:
                    best_score = score
                    best_match = target['name']
            
            source_scores.append({
                'source': source,
                'best_match': best_match,
                'best_score': best_score
            })
        
        # Sort by score (highest first) to resolve conflicts
        source_scores.sort(key=lambda x: x['best_score'], reverse=True)
        
        # Second pass: assign mappings, avoiding duplicates
        final_mappings = {}
        for item in source_scores:
            source = item['source']
            best_match = item['best_match']
            best_score = item['best_score']
            
            # If the target is already used, find next best
            if best_match in used_targets:
                best_match = None
                best_score = 0
                for target in target_columns:
                    if target['name'] in used_targets:
                        continue
                    score = self.calculate_match_score(source, target)
                    if score > best_score:
                        best_score = score
                        best_match = target['name']
            
            target_info = next((t for t in target_columns if t['name'] == best_match), None)
            
            mapping = {
                'source': source['name'],
                'sourceType': source.get('detectedType', 'text'),
                'target': best_match if best_score >= threshold else None,
                'targetType': target_info.get('data_type') if target_info else None,
                'confidence': best_score if best_score >= threshold else 0,
                'autoMapped': best_score >= 50,
                'ignored': False
            }
            
            if best_match and best_score >= threshold:
                used_targets.add(best_match)
            
            final_mappings[source['name']] = mapping
        
        # Restore original order
        return [final_mappings[s['name']] for s in source_columns]

    def detect_column_type(self, values: List[Any]) -> str:
        """
        Detect the data type of a column based on sample values.
        """
        non_null_values = [v for v in values if v is not None and str(v).strip() != '']
        
        if not non_null_values:
            return 'text'
        
        sample_size = min(100, len(non_null_values))
        sample = non_null_values[:sample_size]
        
        # Test for numeric
        numeric_count = 0
        integer_count = 0
        for v in sample:
            try:
                val = float(str(v).replace(',', '.').replace(' ', ''))
                numeric_count += 1
                if val.is_integer():
                    integer_count += 1
            except (ValueError, TypeError):
                pass
        
        if numeric_count == len(sample):
            return 'integer' if integer_count == len(sample) else 'numeric'
        
        # Test for dates
        date_formats = ['%Y-%m-%d', '%d/%m/%Y', '%d-%m-%Y', '%Y/%m/%d', '%d.%m.%Y',
                       '%Y-%m-%d %H:%M:%S', '%d/%m/%Y %H:%M:%S']
        for fmt in date_formats:
            date_count = 0
            for v in sample[:20]:  # Test fewer for dates
                try:
                    datetime.strptime(str(v).strip(), fmt)
                    date_count += 1
                except ValueError:
                    break
            if date_count == min(20, len(sample)):
                return 'date'
        
        # Test for booleans
        bool_values = {'true', 'false', '1', '0', 'yes', 'no', 'oui', 'non', 'vrai', 'faux', 'y', 'n'}
        if all(str(v).lower().strip() in bool_values for v in sample[:50]):
            return 'boolean'
        
        return 'text'

    def validate_mapping(
        self, 
        mapping: Dict[str, Any], 
        source_data: List[Any],
        target_column: Dict[str, Any]
    ) -> Tuple[bool, List[str]]:
        """
        Validate a single column mapping.
        
        Returns:
            Tuple of (is_valid, list of error messages)
        """
        errors = []
        
        source_col = mapping.get('source')
        target_col = mapping.get('target')
        
        if not target_col:
            return True, []  # Unmapped columns are ok
        
        # Check null values for required columns
        is_required = target_column.get('is_nullable') == 'NO' and not target_column.get('column_default')
        null_count = sum(1 for v in source_data if v is None or str(v).strip() == '')
        
        if is_required and null_count > 0:
            errors.append(f'{null_count} valeurs nulles pour la colonne requise "{target_col}"')
        
        # Check string length
        max_length = target_column.get('character_maximum_length')
        if max_length:
            too_long = sum(1 for v in source_data if v and len(str(v)) > max_length)
            if too_long > 0:
                errors.append(f'{too_long} valeurs dépassent la longueur max ({max_length}) pour "{target_col}"')
        
        return len(errors) == 0, errors


# Singleton instance
_mapping_service = None

def get_mapping_service() -> ImportMappingService:
    """Get or create the mapping service singleton."""
    global _mapping_service
    if _mapping_service is None:
        _mapping_service = ImportMappingService()
    return _mapping_service
