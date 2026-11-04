"""Garde-fous de la configuration de l'ecran Donnees IFS > Fournisseurs (sans base)."""
from api.ifs_fournisseurs import CONTROLES, ONGLETS, TABLES


def test_chaque_table_est_dans_un_onglet():
    affichees = {k for sources in ONGLETS.values() for k in sources}
    assert set(TABLES) <= affichees
    assert affichees <= set(TABLES) | set(CONTROLES) | {'synthese'}


def test_nom_de_feuille_excel_valide_et_unique():
    # La cle sert de titre de feuille : au-dela de 31 caracteres, Excel la tronquerait
    # et supplier_info_address / supplier_info_address_type entreraient en collision.
    for sources in ONGLETS.values():
        assert all(len(k) <= 31 for k in sources)
        assert len(set(sources)) == len(sources)
