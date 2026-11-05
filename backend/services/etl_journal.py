"""Journal des chargements ETL (public.etl_execution_log) : etat persistant, lu par le tableau de bord.

Connexion psycopg2 dediee : les threads de chargement n'ont pas forcement de contexte Flask, et la ligne
doit survivre au rollback d'un chargement en echec.
"""
import logging
from datetime import datetime

logger = logging.getLogger(__name__)


def _inserer(nom, debut, statut, lignes, erreur):
    import psycopg2

    from config.database import get_etl_db_params

    connexion = psycopg2.connect(**get_etl_db_params())
    try:
        with connexion, connexion.cursor() as cur:
            cur.execute(
                'INSERT INTO public.etl_execution_log (process_name, start_time, end_time, status, '
                'records_processed, error_message, created_by) VALUES (%s, %s, now(), %s, %s, %s, %s)',
                (nom, debut, statut, lignes, erreur, 'application'))
    finally:
        connexion.close()


def _journaliser(nom, debut, statut, lignes, erreur):
    try:
        _inserer(nom, debut, statut, lignes, erreur)
    except Exception as e:  # le journal ne doit jamais faire echouer un chargement
        logger.error(f'Journal ETL non ecrit pour {nom} : {e}')


def run_etl_journalise(module, nom, **params):
    """Appelle module.run_etl(**params) et journalise son issue ; le resultat ou l'exception passent tels quels."""
    debut = datetime.now()
    try:
        resultat = module.run_etl(**params)
    except Exception as e:
        _journaliser(nom, debut, 'ERROR', 0, str(e))
        raise
    reussi = resultat.get('success')
    _journaliser(nom, debut, 'SUCCESS' if reussi else 'ERROR', int(resultat.get('records_processed') or 0),
                 None if reussi else str(resultat.get('error', 'erreur inconnue')))
    return resultat
