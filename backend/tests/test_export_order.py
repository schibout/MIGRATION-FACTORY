"""Exports hierarchiques IFS : le fichier liste les parents avant les enfants (ORDER BY sequence)."""
from unittest.mock import patch

from services.export_service import ExportService


def _query(table, existing):
    with patch.object(ExportService, '_get_existing_columns', return_value=existing):
        return ExportService().build_dynamic_query(table, 'clean_data', 'MCH_CODE, SPARE_SEQ, MCH_SPARE_SEQ, EQUIPMENT_OBJECT_SEQ')


def test_tri_par_sequence_des_exports_hierarchiques():
    cols = {'mch_code', 'spare_seq', 'mch_spare_seq', 'equipment_object_seq'}
    assert _query('equipment_functional', cols).endswith('ORDER BY "equipment_object_seq"')
    assert _query('equipment_serial', cols).endswith('ORDER BY "equipment_object_seq"')
    assert _query('equipment_object_spare', cols).endswith('ORDER BY "mch_spare_seq"')
    assert _query('equipment_spare_structure', cols).endswith('ORDER BY "spare_seq"')


def test_pas_de_tri_ailleurs_ni_sur_colonne_absente():
    assert 'ORDER BY' not in _query('supplier_info', {'mch_code'})
    assert 'ORDER BY' not in _query('equipment_object_spare', {'mch_code'})
