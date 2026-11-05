"""Garde-fous de la configuration des ecrans Donnees IFS Fournisseurs, Articles et Structure (sans base)."""
import pytest

from api import ifs_data_articles, ifs_data_structure, ifs_fournisseurs

ECRANS = [ifs_fournisseurs, ifs_data_articles, ifs_data_structure]


@pytest.mark.parametrize('ecran', ECRANS)
def test_chaque_table_est_dans_un_onglet(ecran):
    affichees = {k for sources in ecran.ONGLETS.values() for k in sources}
    assert set(ecran.TABLES) <= affichees
    assert affichees <= set(ecran.TABLES) | set(ecran.CONTROLES) | {'synthese'}


@pytest.mark.parametrize('ecran', ECRANS)
def test_nom_de_feuille_excel_valide_et_unique(ecran):
    # La cle sert de titre de feuille : au-dela de 31 caracteres, Excel la tronquerait
    # et supplier_info_address / supplier_info_address_type entreraient en collision.
    for sources in ecran.ONGLETS.values():
        assert all(len(k) <= 31 for k in sources)
        assert len(set(sources)) == len(sources)
