"""Lecture du fichier d'import de l'ecran Ressources (sans base)."""
import pytest

from api.resource_detail_file import lire_fichier, preparer_import


def test_csv_libelles_et_noms_techniques():
    csv = ('N° séquence;resource_id;Type de ressource;Utilisée en maintenance;Taux d\'utilisation (%)\n'
           '13;SJ-MSCT-MECA;person_group;oui;100,5\n'
           ';NOUVEAU;PERSON;FALSE;\n').encode('cp1252')
    colonnes, lignes, erreurs = preparer_import(lire_fichier('r.csv', csv))
    assert erreurs == []
    assert colonnes == ['resource_id', 'resource_type_db', 'used_in_maintenance_db', 'utilization']
    (l1, seq1, v1), (_, seq2, v2) = lignes
    assert (l1, int(seq1), v1['resource_type_db'], v1['used_in_maintenance_db'], float(v1['utilization'])) \
        == (2, 13, 'PERSON_GROUP', 'TRUE', 100.5)
    assert seq2 is None and v2['utilization'] is None and v2['used_in_maintenance_db'] == 'FALSE'


def test_erreurs_par_ligne():
    csv = b'resource_seq,resource_type_db,used_in_service_db\nabc,PERSON,TRUE\n2,MACHINE,TRUE\n3,PERSON,peut-etre\n'
    _, lignes, erreurs = preparer_import(lire_fichier('r.csv', csv))
    assert lignes == [] and [e['ligne'] for e in erreurs] == [2, 3, 4]


def test_sans_cle():
    with pytest.raises(ValueError):
        preparer_import(lire_fichier('r.csv', b'description\nx\n'))
