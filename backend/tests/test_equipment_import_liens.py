"""Import « Lien equipement - article » : lecture du fichier et parametres envoyes a la base (hors ligne)."""
import io
import sys
from unittest.mock import MagicMock, patch

from openpyxl import Workbook

sys.modules.setdefault('requests_ntlm', MagicMock())  # dependance du paquet api absente hors conteneur


def _fichier():
    wb = Workbook()
    ws = wb.active
    ws.append(['N° équipement', 'N° article', 'N° série'])
    ws.append([126332, 619068, 'EH-378-NM'])   # article hors SAP
    ws.append([125197, 614335, 259])            # numerique -> texte
    ws.append([123669, 619077, None])           # serie vide : inchangee
    ws.append([999999, None, None])             # rien a ecrire
    ws.append([None, 614335, 'X'])              # equipement vide
    ws.append([123060, None, 'A' * 19])         # serie trop longue
    b = io.BytesIO()
    wb.save(b)
    b.seek(0)
    return b


def test_import_liens_lit_le_fichier_et_rapporte():
    from api import equipment_browser as eb
    app = __import__('flask').Flask(__name__)
    app.config['JWT_SECRET_KEY'] = 'x' * 32
    from flask_jwt_extended import JWTManager, create_access_token
    JWTManager(app)
    app.register_blueprint(eb.equipment_browser_blueprint, url_prefix='/eq')
    session = MagicMock()
    appels = []

    def execute(sql, params=None):
        appels.append(params)
        r = MagicMock()
        if 'raw_data.mara' in str(sql):
            r.scalars.return_value = ['000000000000614335']
        else:
            r.scalars.return_value = ['000000000000126332', '000000000000125197', '000000000000123669']
        return r
    session.execute.side_effect = execute
    with patch.object(eb.db, 'session', session), \
            patch('api.maintenance_snapshots.active_job_conflict', return_value=None), app.app_context():
        jeton = create_access_token(identity='1')
        rep = app.test_client().post('/eq/import-liens', data={'file': (_fichier(), 'liens.xlsx')},
                                     headers={'Authorization': f'Bearer {jeton}'})
    assert rep.status_code == 200, rep.get_json()
    d = rep.get_json()
    assert d['mis_a_jour'] == 3 and d['lignes'] == 5
    assert d['articles_hors_sap'] == ['619068', '619077']
    maj = appels[-1]
    lignes = dict(zip(maj['k'], zip(maj['a'], maj['s'])))
    assert lignes['000000000000125197'] == ('614335', '259')
    assert lignes['000000000000123669'] == ('619077', '')
    assert lignes['000000000000123060'] == ('', '')
    motifs = {(r['ligne'], r['motif'][:12]) for r in d['rejets']}
    assert (6, 'N° équipemen') in motifs and (5, 'Ni article n') in motifs and (7, 'Ni article n') in motifs
    assert any(r['ligne'] == 7 and '18 caract' in r['motif'] for r in d['rejets'])
