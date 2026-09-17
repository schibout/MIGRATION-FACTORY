"""Chargement de la migration 079 (classification IBAU) DANS la transaction
d'un test, pour ne dependre ni de son application en base ni y laisser
quoi que ce soit.

Delimiteurs BEGIN;/COMMIT; retires ligne a ligne : sinon le COMMIT du fichier
validerait tout ce que le test a ecrit (cf. incident migration 076).
Le depot n'est pas monte dans le conteneur backend (/app = backend/ seul) :
sans le fichier, on se rabat sur la fonction deja deployee, ou on saute.
"""
import os

import pytest

BACKEND = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MIGRATION_079 = os.path.join(os.path.dirname(BACKEND), 'migrations', '079_classification_ibau.sql')


def charger_migration_079(cur):
    try:
        with open(MIGRATION_079, encoding='utf-8') as f:
            sql = '\n'.join('' if line.strip() in ('BEGIN;', 'COMMIT;') else line for line in f)
    except FileNotFoundError:
        cur.execute("SELECT 1 FROM pg_proc WHERE proname = 'classifier_ibau_article'")
        if cur.fetchone() is None:
            pytest.skip(f'migration 079 introuvable ({MIGRATION_079}) et fonction absente de la base')
        return
    cur.execute(sql)
