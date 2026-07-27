"""
Tests du service de snapshots maintenance (services/maintenance_snapshot_service.py).

Aucune base n'est requise : la connexion psycopg2 est simulee et l'on verifie le
SQL reellement emis (nommage des copies, ordre purge/insertion, contraintes
differees, appariement des colonnes par nom).
"""
from unittest.mock import patch

import pytest

from services import maintenance_snapshot_service as svc


# --------------------------------------------------------------------------- #
# Doublure de connexion psycopg2
# --------------------------------------------------------------------------- #
class FakeCursor:
    """Cursor minimal : enregistre le SQL emis et rejoue des resultats scriptes."""

    def __init__(self, conn):
        self.conn = conn
        self.rowcount = 0

    def __enter__(self):
        return self

    def __exit__(self, *_):
        return False

    def execute(self, query, params=None):
        # repr() rend lisibles aussi bien les str que les psycopg2.sql.Composed.
        self.conn.executed.append((repr(query), params))
        self.conn.last_query = repr(query)
        self.rowcount = self.conn.rowcount_for(self.conn.last_query)

    def fetchone(self):
        # PostgreSQL renvoie toujours une ligne pour les SELECT scalaires du
        # service : par defaut (None,) et non None, comme en conditions reelles.
        return self.conn.next_result(default=(None,))

    def fetchall(self):
        return self.conn.next_result(default=[])

    def close(self):
        pass


class FakeConn:
    def __init__(self, results=None, rowcount=0):
        self.executed = []
        self.results = list(results or [])
        self.last_query = ''
        self.committed = 0
        self.rolled_back = 0
        self._rowcount = rowcount

    def cursor(self, **_kwargs):
        return FakeCursor(self)

    def commit(self):
        self.committed += 1

    def rollback(self):
        self.rolled_back += 1

    def close(self):
        pass

    def next_result(self, default=None):
        return self.results.pop(0) if self.results else default

    def rowcount_for(self, _query):
        return self._rowcount

    # -- aides d'assertion --
    def queries(self):
        return [q for q, _ in self.executed]

    def find(self, *fragments):
        """Requetes contenant TOUS les fragments donnes."""
        return [q for q in self.queries() if all(f in q for f in fragments)]


def _patch_conn(conn):
    """Patch le context manager get_db_connection utilise par le service."""
    class _Ctx:
        def __enter__(self_inner):
            return conn

        def __exit__(self_inner, *_):
            return False

    return patch.object(svc, 'get_db_connection', lambda: _Ctx())


# --------------------------------------------------------------------------- #
# Perimetre et nommage
# --------------------------------------------------------------------------- #
def test_perimetre_couvre_maintenance_object_et_les_tables_raw_editables():
    tables = dict.fromkeys(f"{s}.{t}" for s, t in svc.SNAPSHOT_TABLES)
    # L'ecran IH02 : table applicative principale
    assert 'clean_data.maintenance_object' in tables
    # Les ecrans Hierarchie / Equipements / Articles ecrivent encore dans raw_data
    for table in ('raw_data.iflot', 'raw_data.iflotx', 'raw_data.equi',
                  'raw_data.eqkt', 'raw_data.mara', 'raw_data.makt'):
        assert table in tables, f"{table} doit etre snapshotee"


def test_maintenance_object_est_restauree_en_premier():
    """L'ordre pilote la restauration : la table applicative d'abord."""
    assert svc.SNAPSHOT_TABLES[0] == ('clean_data', 'maintenance_object')


def test_nom_de_copie_prefixe_par_id_et_schema():
    """Le schema fait partie du nom : evite toute collision clean_data / raw_data."""
    assert svc._copy_table_name(12, 'raw_data', 'iflot') == 's12_raw_data_iflot'
    assert svc._copy_table_name(12, 'clean_data', 'iflot') == 's12_clean_data_iflot'


# --------------------------------------------------------------------------- #
# Creation
# --------------------------------------------------------------------------- #
def test_creation_refuse_un_nom_vide():
    with pytest.raises(svc.SnapshotError):
        svc.create_snapshot('   ')


def test_creation_refuse_un_type_inconnu():
    with pytest.raises(svc.SnapshotError):
        svc.create_snapshot('etat', kind='BOGUS')


def test_creation_copie_chaque_table_du_perimetre():
    nb_tables = len(svc.SNAPSHOT_TABLES)
    # id du snapshot, puis pour chaque table : to_regclass -> True ; puis taille
    results = [(7,)] + [(True,)] * nb_tables + [(4096,)]
    conn = FakeConn(results=results, rowcount=10)

    with _patch_conn(conn), patch.object(svc, 'get_snapshot', return_value={'id': 7}):
        svc.create_snapshot('Avant reprise des ateliers', user='samir')

    creations = conn.find('CREATE TABLE')
    assert len(creations) == nb_tables
    assert any("'s7_clean_data_maintenance_object'" in q for q in creations)
    assert any("'snapshots'" in q for q in creations)


def test_creation_ignore_une_table_absente_de_la_base():
    """Une table du perimetre absente ne doit pas faire echouer la sauvegarde."""
    nb_tables = len(svc.SNAPSHOT_TABLES)
    results = [(7,)] + [(False,)] * nb_tables + [(0,)]
    conn = FakeConn(results=results)

    with _patch_conn(conn), patch.object(svc, 'get_snapshot', return_value={'id': 7}):
        svc.create_snapshot('etat', user='samir')

    assert conn.find('CREATE TABLE') == []
    assert conn.find('UPDATE public.maintenance_snapshots', 'READY')


def test_creation_en_echec_marque_failed_et_nettoie():
    conn = FakeConn(results=[(7,)])

    def _boom(*_a, **_k):
        raise RuntimeError('disque plein')

    with _patch_conn(conn), patch.object(svc, '_table_exists', side_effect=_boom):
        with pytest.raises(svc.SnapshotError):
            svc.create_snapshot('etat')

    assert conn.rolled_back >= 1
    assert conn.find('UPDATE public.maintenance_snapshots', 'FAILED')


# --------------------------------------------------------------------------- #
# Restauration
# --------------------------------------------------------------------------- #
def test_restauration_refuse_un_snapshot_introuvable():
    with patch.object(svc, 'get_snapshot', return_value=None):
        with pytest.raises(svc.SnapshotError):
            svc.restore_snapshot(1)


def test_restauration_refuse_un_snapshot_non_pret():
    snap = {'id': 1, 'name': 'x', 'status': 'FAILED'}
    with patch.object(svc, 'get_snapshot', return_value=snap):
        with pytest.raises(svc.SnapshotError):
            svc.restore_snapshot(1)


def _restore_conn(nb_tables):
    """Resultats scriptes pour une restauration : existence copie/cible,
    colonnes, puis sequences."""
    results = []
    for _ in range(nb_tables):
        results += [
            (True,),               # copie presente
            (True,),               # table cible presente
            [('id',), ('code',)],  # colonnes de la copie
            [('id',), ('code',)],  # colonnes de la cible
        ]
    return FakeConn(results=results)


def test_restauration_differe_les_contraintes_et_purge_avant_insertion():
    snap = {'id': 3, 'name': 'Etat du 12/07', 'status': 'READY', 'created_at': None}
    nb_tables = len(svc.SNAPSHOT_TABLES)
    conn = _restore_conn(nb_tables)

    with patch.object(svc, 'get_snapshot', return_value=snap), _patch_conn(conn):
        svc.restore_snapshot(3, user='samir', auto_backup=False)

    queries = conn.queries()
    # Les FK auto-referencantes de maintenance_object imposent le mode differe
    assert any('SET CONSTRAINTS ALL DEFERRED' in q for q in queries)

    deletes = [i for i, q in enumerate(queries) if 'DELETE FROM' in q]
    inserts = [i for i, q in enumerate(queries) if 'INSERT INTO' in q]
    assert deletes and inserts
    # TOUTES les purges precedent TOUTES les insertions (evite les conflits de FK)
    assert max(deletes) < min(inserts)


def test_restauration_recale_les_sequences():
    """Les id sont reinseres tels quels : la sequence doit suivre."""
    snap = {'id': 3, 'name': 'x', 'status': 'READY', 'created_at': None}
    conn = _restore_conn(len(svc.SNAPSHOT_TABLES))

    with patch.object(svc, 'get_snapshot', return_value=snap), _patch_conn(conn):
        svc.restore_snapshot(3, auto_backup=False)

    assert conn.find('pg_get_serial_sequence')


def test_restauration_prend_une_sauvegarde_de_securite_par_defaut():
    snap = {'id': 3, 'name': 'x', 'status': 'READY', 'created_at': None}
    conn = _restore_conn(len(svc.SNAPSHOT_TABLES))

    with patch.object(svc, 'get_snapshot', return_value=snap), _patch_conn(conn), \
            patch.object(svc, 'create_snapshot', return_value={'id': 99}) as create:
        result = svc.restore_snapshot(3, user='samir')

    assert create.call_count == 1
    assert create.call_args.kwargs['kind'] == 'AUTO_PRE_RESTORE'
    assert result['safety_snapshot_id'] == 99


def test_restauration_apparie_les_colonnes_par_nom():
    """Une colonne ajoutee apres coup ne doit pas invalider les vieux snapshots."""
    snap = {'id': 3, 'name': 'x', 'status': 'READY', 'created_at': None}
    results = []
    for _ in range(len(svc.SNAPSHOT_TABLES)):
        results += [
            (True,), (True,),
            [('id',), ('code',)],                  # copie : 2 colonnes
            [('id',), ('code',), ('nouvelle',)],   # cible : 3 colonnes
        ]
    conn = FakeConn(results=results)

    with patch.object(svc, 'get_snapshot', return_value=snap), _patch_conn(conn):
        svc.restore_snapshot(3, auto_backup=False)

    inserts = conn.find('INSERT INTO')
    assert inserts
    # La colonne absente de la copie n'est pas listee dans l'INSERT
    assert all("'nouvelle'" not in q for q in inserts)


# --------------------------------------------------------------------------- #
# Suppression / menage
# --------------------------------------------------------------------------- #
def test_suppression_refusee_si_operation_en_cours():
    conn = FakeConn(results=[(1,)])  # un job actif reference ce snapshot
    with _patch_conn(conn):
        with pytest.raises(svc.SnapshotError):
            svc.delete_snapshot(5)


def test_cleanup_conserve_les_n_derniers_automatiques():
    conn = FakeConn(results=[[(11,), (12,)]])
    with _patch_conn(conn):
        nb = svc.cleanup_auto_snapshots(keep=5)

    assert nb == 2
    # Le garde-fou porte bien sur les seuls snapshots automatiques
    purge = conn.find('AUTO_PRE_RESTORE', 'OFFSET')
    assert purge, "la selection doit se limiter aux snapshots automatiques"
