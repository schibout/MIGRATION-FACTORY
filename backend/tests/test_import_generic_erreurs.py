"""Message d'erreur d'une ligne d'import : colonne fautive nommee, SQL et donnees jamais recopies (sans base)."""
from services.import_mapping_service import message_erreur_ligne, refus_vidage

SOURCES = ['BLOCKED', 'VALID_DATE', 'IBAN']
CIBLES = ['blocked_for_use', 'bank_account_valid_date', 'account']
TYPES = {'blocked_for_use': 'character varying', 'bank_account_valid_date': 'date', 'account': 'character varying'}
VALEURS = ['False', 'False', 'FR7600000000000']


def test_nomme_la_colonne_du_bon_type_sans_recopier_la_requete():
    erreur = Exception('invalid input syntax for type date: "False"\nLINE 1: ...VALUES (\'FR7600000000000\', \'False\')')
    message = message_erreur_ligne(erreur, SOURCES, CIBLES, VALEURS, TYPES)
    assert message == ('invalid input syntax for type date: "False" '
                       '(colonne du fichier "VALID_DATE", colonne cible "bank_account_valid_date")')


def test_erreur_sans_valeur_identifiable_garde_la_premiere_ligne():
    erreur = Exception('value too long for type character varying(5)\nLINE 1: INSERT INTO ...')
    assert message_erreur_ligne(erreur, SOURCES, CIBLES, VALEURS, TYPES) == 'value too long for type character varying(5)'


def test_vidage_limite_aux_tables_alimentees_par_fichier():
    assert refus_vidage("public", False, True)
    assert refus_vidage("raw_data", True, True)
    assert refus_vidage("clean_data", False, False)
    assert refus_vidage("raw_data", False, True) is None
    assert refus_vidage("clean_data", True, True) is None  # part_catalog n est pas une table SAP brute
