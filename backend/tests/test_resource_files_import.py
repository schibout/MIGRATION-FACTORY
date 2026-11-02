"""Lecture des fichiers d'import des ecrans Ressources (sans base)."""
from datetime import date

import pytest

from api.resource_files import TABLES, lire_fichier, preparer_import

DETAIL, DISPO, PARENT = TABLES['detail-file'], TABLES['availability'], TABLES['parent']


def test_csv_libelles_et_noms_techniques():
    csv = ('N°;resource_id;Type de ressource;Utilisée en maintenance;Taux d\'utilisation (%)\n'
           '13;SJ-MSCT-MECA;person_group;oui;100,5\n'
           ';NOUVEAU;PERSON;FALSE;\n').encode('cp1252')
    colonnes, lignes, erreurs = preparer_import(DETAIL, lire_fichier('r.csv', csv))
    assert erreurs == []
    assert colonnes == ['resource_id', 'resource_type_db', 'used_in_maintenance_db', 'utilization']
    (l1, cle1, v1), (_, cle2, v2) = lignes
    assert (l1, int(cle1['resource_seq']), v1['resource_type_db'], v1['used_in_maintenance_db'], float(v1['utilization'])) \
        == (2, 13, 'PERSON_GROUP', 'TRUE', 100.5)
    assert cle2 is None and v2['utilization'] is None and v2['used_in_maintenance_db'] == 'FALSE'


def test_erreurs_par_ligne():
    csv = b'resource_seq,resource_type_db,used_in_service_db\nabc,PERSON,TRUE\n2,MACHINE,TRUE\n3,PERSON,peut-etre\n'
    _, lignes, erreurs = preparer_import(DETAIL, lire_fichier('r.csv', csv))
    assert lignes == [] and [e['ligne'] for e in erreurs] == [2, 3, 4]


def test_sans_cle():
    with pytest.raises(ValueError):
        preparer_import(DETAIL, lire_fichier('r.csv', b'description\nx\n'))


def test_dates_et_cle_composee():
    _, lignes, erreurs = preparer_import(DISPO, lire_fichier('d.csv', b'N\xb0;Date de d\xe9but;end_date\n5;31/12/2021;2022-01-31\n'))
    assert erreurs == [] and lignes[0][2] == {'start_date': date(2021, 12, 31), 'end_date': date(2022, 1, 31)}
    _, lignes, erreurs = preparer_import(PARENT, lire_fichier('p.csv', b'resource_parent_seq;resource_seq\n10;90\n;91\n'))
    assert [int(v) for v in lignes[0][1].values()] == [10, 90] and erreurs[0]['ligne'] == 3


def test_verifs_disponibilite():
    verifs = DISPO['verifs']
    assert any(v({'start_date': date(2022, 1, 2), 'end_date': date(2022, 1, 1)}) for v in verifs)
    assert any(v({'available_percentage': 120}) for v in verifs)
    assert not any(v({'available_percentage': 50, 'efficiency': 100}) for v in verifs)
