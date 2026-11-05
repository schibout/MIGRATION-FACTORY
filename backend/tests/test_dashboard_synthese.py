"""Logique du tableau de bord et journal ETL (sans base)."""
import re
from datetime import date, timedelta
from pathlib import Path
from types import SimpleNamespace

import pytest

from services import etl_journal
from services.dashboard_synthese import mois_glissants, series_controles, statut_extraction, synthese

J = date(2026, 11, 5)


def mesure(jour, ecran, code, n, label=None):
    return {'jour': jour, 'ecran': ecran, 'code': code, 'label': label or code, 'anomalies': n}


@pytest.mark.parametrize('statut, ancien, attendu', [
    ('COMPLETED', False, 'reussie'),
    ('completed', True, 'reussie'),
    ('COMPLETED_WITH_ERRORS', False, 'avec_erreurs'),
    ('cancelled', False, 'annulee'),
    ('RUNNING', True, 'interrompue'),   # jamais clos : ne doit pas s'afficher « en cours »
    ('running', False, 'en_cours'),
    ('pending', True, 'interrompue'),
    ('pending', False, 'en_cours'),
    ('FAILED', False, 'echec'),
    (None, False, 'echec'),
])
def test_statut_extraction(statut, ancien, attendu):
    assert statut_extraction(statut, ancien) == attendu


def test_mois_glissants_passe_le_changement_d_annee():
    assert mois_glissants(date(2026, 2, 28), 4) == ['2025-11', '2025-12', '2026-01', '2026-02']


def test_premiere_mesure_sans_ecart():
    domaines, a_traiter, historique = synthese([mesure(J, 'clients', 'a', 5), mesure(J, 'clients', 'b', 0)])
    assert domaines['clients']['controles'] == 2
    assert domaines['clients']['ko'] == 1
    assert domaines['clients']['anomalies'] == 5
    assert domaines['clients']['delta_precedent'] is None
    assert domaines['clients']['delta_7j'] is None
    assert a_traiter[0]['delta'] is None
    assert historique == [{'jour': J.isoformat(), 'ecran': 'clients', 'ko': 1, 'anomalies': 5}]


def test_ecarts_precedent_et_semaine():
    lignes = [mesure(J - timedelta(days=10), 'clients', 'a', 100),
              mesure(J - timedelta(days=7), 'clients', 'a', 90),
              mesure(J - timedelta(days=2), 'clients', 'a', 40),
              mesure(J, 'clients', 'a', 50)]
    domaine = synthese(lignes)[0]['clients']
    assert domaine['delta_precedent'] == 10
    assert domaine['delta_7j'] == -40


def test_sans_mesure_vieille_de_7_jours_pas_d_ecart_hebdo():
    lignes = [mesure(J - timedelta(days=6), 'clients', 'a', 90), mesure(J, 'clients', 'a', 50)]
    domaine = synthese(lignes)[0]['clients']
    assert domaine['delta_precedent'] == -40
    assert domaine['delta_7j'] is None


def test_controle_nouveau_ne_fausse_pas_l_ecart():
    # Un controle ajoute aujourd'hui n'est pas une hausse de 500 anomalies
    lignes = [mesure(J - timedelta(days=1), 'clients', 'a', 10),
              mesure(J, 'clients', 'a', 10), mesure(J, 'clients', 'nouveau', 500)]
    assert synthese(lignes)[0]['clients']['delta_precedent'] == 0


def test_controle_en_erreur_n_est_pas_compte_comme_zero():
    lignes = [mesure(J - timedelta(days=1), 'clients', 'a', 10), mesure(J - timedelta(days=1), 'clients', 'b', 7),
              mesure(J, 'clients', 'a', 10), mesure(J, 'clients', 'b', None)]
    domaine = synthese(lignes)[0]['clients']
    assert domaine['en_erreur'] == 1
    assert domaine['ko'] == 1
    assert domaine['anomalies'] == 10
    assert domaine['delta_precedent'] == 0  # et non -7 : le controle n'a pas ete mesure


def test_principale_anomalie():
    lignes = [mesure(J, 'articles', 'a', 3, 'Petit'), mesure(J, 'articles', 'b', 300, 'Grand')]
    assert synthese(lignes)[0]['articles']['principale'] == {'label': 'Grand', 'n': 300}


def test_a_traiter_met_les_hausses_en_premier():
    hier = J - timedelta(days=1)
    lignes = [mesure(hier, 'x', 'gros_stable', 1000), mesure(J, 'x', 'gros_stable', 1000),
              mesure(hier, 'x', 'petit_hausse', 1), mesure(J, 'x', 'petit_hausse', 9),
              mesure(hier, 'x', 'corrige', 5), mesure(J, 'x', 'corrige', 0)]
    a_traiter = synthese(lignes)[1]
    assert [a['code'] for a in a_traiter] == ['petit_hausse', 'gros_stable']


def test_series_controles_limite_et_ordre_stable():
    lignes = [mesure(J, 'x', f'c{i}', i) for i in range(9)] + [mesure(J, 'y', 'autre', 99)]
    resultat = series_controles(lignes, 'x', limite=3)
    assert [s['code'] for s in resultat['series']] == ['c6', 'c7', 'c8']  # les plus lourds, tries par code
    assert resultat['masques'] == 5  # c1 a c5 ; c0 n'a jamais eu d'anomalie


def test_toutes_les_routes_exigent_la_permission():
    # Lecture du source : importer api.dashboard charge tout le paquet api et ses dependances
    source = (Path(__file__).parent.parent / 'api' / 'dashboard.py').read_text(encoding='utf-8')
    routes = re.findall(r"@dashboard_blueprint\.route\(.*\)\n(.*)\n", source)
    assert len(routes) == 3
    assert set(routes) == {"@require_permission('view_dashboards')"}


def _module(run_etl):
    return SimpleNamespace(run_etl=run_etl)


@pytest.fixture
def ecritures(monkeypatch):
    lignes = []
    monkeypatch.setattr(etl_journal, '_inserer', lambda *a: lignes.append(a))
    return lignes


def test_journal_succes(ecritures):
    resultat = etl_journal.run_etl_journalise(_module(lambda x: {'success': True, 'records_processed': 12, 'x': x}),
                                              'etl_a.py', x=1)
    assert resultat['x'] == 1
    assert ecritures[0][0] == 'etl_a.py'
    assert ecritures[0][2:] == ('SUCCESS', 12, None)


def test_journal_echec_rapporte(ecritures):
    etl_journal.run_etl_journalise(_module(lambda: {'success': False, 'error': 'boum'}), 'etl_a.py')
    assert ecritures[0][2:] == ('ERROR', 0, 'boum')


def test_journal_exception_propagee(ecritures):
    def casse():
        raise ValueError('boum')
    with pytest.raises(ValueError):
        etl_journal.run_etl_journalise(_module(casse), 'etl_a.py')
    assert ecritures[0][2:] == ('ERROR', 0, 'boum')


def test_panne_du_journal_ne_casse_pas_le_chargement(monkeypatch):
    def panne(*_):
        raise OSError('base indisponible')
    monkeypatch.setattr(etl_journal, '_inserer', panne)
    assert etl_journal.run_etl_journalise(_module(lambda: {'success': True}), 'etl_a.py') == {'success': True}
