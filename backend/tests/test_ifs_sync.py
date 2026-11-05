"""Boutons Calculer / Synchroniser des ecrans Donnees IFS (sans base ni SAP ni ASAP)."""
from unittest import mock

import pytest
from flask import Flask

from api import (ifs_consultation, ifs_data_clients, ifs_data_operations, ifs_data_pm_actions, ifs_data_projets,
                 ifs_data_ressources, ifs_data_structure, maintenance_snapshots, sap_articles)


@pytest.fixture
def lancer(monkeypatch):
    """Appelle le POST /sync d'un ecran : (reponse, parametres donnes a _start_sync)."""
    appels = {}

    def start_sync(key, tables, cible, load, extraire=True):
        appels.update(key=key, tables=tables, load=load, extraire=extraire)
        return 'lance', 202

    monkeypatch.setattr(ifs_consultation, '_start_sync', start_sync)
    monkeypatch.setattr(ifs_consultation, 'get_jwt_identity', lambda: 'moi')

    def appel(ecran, source):
        vue = ecran.lancer_sync
        with Flask(__name__).test_request_context(json={'source': source}):
            return vue.__wrapped__(), appels
    return appel


@pytest.mark.parametrize('ecran, module', [
    (ifs_data_clients, 'etl_file_customer.py'),
    (ifs_data_operations, 'etl_operation.py'),
    (ifs_data_pm_actions, 'etl_pm_action.py'),
    (ifs_data_projets, 'etl_project.py'),
    (ifs_data_ressources, 'etl_maintenance_resource.py'),
    (ifs_data_structure, 'etl_equipment_functional.py'),
])
def test_calculer_lance_le_module_sans_source_externe(lancer, monkeypatch, ecran, module):
    charge = mock.Mock()
    monkeypatch.setattr(ifs_consultation, '_charger_modules', charge)
    asap = mock.Mock()
    jobs = mock.Mock()
    monkeypatch.setattr(ifs_data_projets, '_service_asap', asap)
    monkeypatch.setattr(ifs_data_structure, '_jobs', jobs)
    monkeypatch.setattr(maintenance_snapshots, 'active_job_conflict', lambda: None)
    reponse, appels = lancer(ecran, 'mf')
    assert reponse == ('lance', 202)
    assert appels['extraire'] is False
    conn = mock.MagicMock()
    appels['load'](conn)
    assert charge.call_args.args[2] == [module]
    asap.assert_not_called()  # Calculer n'appelle ni ASAP ni le rechargement SAP
    jobs.assert_not_called()
    assert conn.execute.called  # le compteur de l'ecran est relu apres le module


@pytest.mark.parametrize('ecran, tables', [
    (ifs_data_clients, {'KNA1', 'KNB1', 'KNVV', 'KNBK', 'ADRC', 'ADR2', 'ADR3', 'ADR6', 'T005T'}),
    (ifs_data_operations, {'AUFK', 'AFKO', 'AFIH', 'AFVC', 'AFVV', 'AFRU', 'CRHD', 'ILOA', 'JEST', 'RESB'}),
])
def test_synchroniser_sap_extrait_les_tables_du_module(lancer, ecran, tables):
    reponse, appels = lancer(ecran, 'sap')
    assert reponse == ('lance', 202)
    assert appels['extraire'] is True
    assert set(appels['tables']) == tables


@pytest.mark.parametrize('ecran', [ifs_data_pm_actions, ifs_data_ressources])
def test_source_fichier_refuse_la_synchronisation(lancer, ecran):
    (reponse, code), appels = lancer(ecran, 'sap')
    assert code == 400
    assert not appels


def _service_asap(**reponses):
    service = mock.MagicMock()
    for nom in ('import_projets_from_sharepoint', 'import_users_from_sharepoint', 'import_projets_a_reprendre',
                'import_all_etats_avancement'):
        getattr(service, nom).return_value = reponses.get(nom, {'success': True, 'db_saved': True})
    return service


def _synchroniser_asap(lancer, monkeypatch, service):
    charge = mock.Mock()
    monkeypatch.setattr(ifs_consultation, '_charger_modules', charge)
    monkeypatch.setattr(ifs_data_projets, '_write_status', mock.Mock())
    monkeypatch.setattr(ifs_data_projets, '_service_asap', lambda: service)
    _, appels = lancer(ifs_data_projets, 'sap')
    assert appels['extraire'] is False  # ASAP n'est pas une extraction SAP
    return appels['load'], charge


def test_synchroniser_asap_importe_puis_lance_le_module(lancer, monkeypatch):
    service = _service_asap()
    load, charge = _synchroniser_asap(lancer, monkeypatch, service)
    load(mock.MagicMock())
    service.import_projets_from_sharepoint.assert_called_once()
    service.import_users_from_sharepoint.assert_called_once()
    service.import_projets_a_reprendre.assert_called_once()
    service.import_all_etats_avancement.assert_called_once()
    charge.assert_called_once()


@pytest.mark.parametrize('nom', ['import_projets_from_sharepoint', 'import_users_from_sharepoint',
                                 'import_projets_a_reprendre', 'import_all_etats_avancement'])
@pytest.mark.parametrize('echec', [{'success': False, 'errors': ['boum']}, {'success': True, 'db_saved': False}])
def test_import_asap_rate_n_enchaine_pas_le_module(lancer, monkeypatch, nom, echec):
    # success True / db_saved False : rien n'est en base, l'ETL repartirait sur d'anciennes donnees
    load, charge = _synchroniser_asap(lancer, monkeypatch, _service_asap(**{nom: echec}))
    with pytest.raises(RuntimeError):
        load(mock.MagicMock())
    charge.assert_not_called()


def _rechargement(monkeypatch, etats):
    jobs = mock.MagicMock()
    jobs.create_job.return_value = {'id': 7}
    jobs.get_job.side_effect = etats
    monkeypatch.setattr(ifs_data_structure, '_jobs', lambda: jobs)
    monkeypatch.setattr(ifs_data_structure, '_write_status', mock.Mock())
    monkeypatch.setattr(ifs_data_structure.time, 'sleep', lambda _: None)
    return jobs


def test_structure_passe_par_la_fusion_qui_preserve_les_saisies(monkeypatch):
    jobs = _rechargement(monkeypatch, [{'status': 'RUNNING', 'progress': 50, 'current_step': 'x'},
                                       {'status': 'DONE', 'progress': 100, 'current_step': 'y'}])
    with Flask(__name__).app_context():
        ifs_data_structure._recharger_maintenance('cle', 'moi')
    assert jobs.create_job.call_args.args == ('RELOAD', {'mode': 'merge', 'with_extraction': True})
    assert jobs.create_job.call_args.kwargs == {'user': 'moi'}


def test_structure_job_en_echec_n_enchaine_pas_le_module(monkeypatch):
    _rechargement(monkeypatch, [{'status': 'ERROR', 'progress': 5, 'current_step': 'x', 'error_message': 'boum'}])
    with Flask(__name__).app_context(), pytest.raises(RuntimeError, match='boum'):
        ifs_data_structure._recharger_maintenance('cle', 'moi')


@pytest.mark.parametrize('source', ['mf', 'sap'])
def test_structure_refuse_si_une_operation_maintenance_tourne(lancer, monkeypatch, source):
    monkeypatch.setattr(maintenance_snapshots, 'active_job_conflict', lambda: ('occupe', 409))
    reponse, appels = lancer(ifs_data_structure, source)
    assert reponse == ('occupe', 409)
    assert not appels


def test_module_inactif_ou_absent_ne_passe_pas_pour_un_succes():
    conn = mock.MagicMock()
    conn.execute.return_value.mappings.return_value.all.return_value = []
    with pytest.raises(RuntimeError, match='etl_absent.py'):
        sap_articles._charger_modules(conn, 'cle', ['etl_absent.py'])
