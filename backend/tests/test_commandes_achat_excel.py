"""Purchase order workbook contract, with a simulated database session."""
from importlib.util import module_from_spec, spec_from_file_location
from io import BytesIO
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import Mock

from flask import Flask
from flask_jwt_extended import JWTManager, create_access_token
from openpyxl import load_workbook


def test_purchase_order_excel_control_columns(monkeypatch):
    # Load this blueprint alone, as in test_finance_articles_filtres.
    spec = spec_from_file_location("finance_excel", Path(__file__).resolve().parents[1] / "api/finance.py")
    finance = module_from_spec(spec)
    spec.loader.exec_module(finance)
    session = Mock()
    monkeypatch.setattr(finance, "db", SimpleNamespace(session=session))
    values = {"num_commande_sap": "4500000001", "article_sap": "ART-1"}
    controls = {
        "Envoyé vers IFS": "OUI",
        "Article dans Master Part (prod IFS)": "NON",
        "Fournisseur dans référentiel": "OUI",
        "Fournisseur facturation dans référentiel": "NON",
    }
    row = [values.get(name) for name in finance.CA_COLONNES] + list(controls.values())
    session.execute.return_value.all.return_value = [row]

    app = Flask(__name__)
    app.config.update(TESTING=True, JWT_SECRET_KEY="offline-purchase-order-workbook-test")
    JWTManager(app)
    app.register_blueprint(finance.finance_blueprint, url_prefix="/api/v1/finance")
    with app.app_context():
        token = create_access_token(identity="test")
    response = app.test_client().get("/api/v1/finance/commandes-achat/export.xlsx",
                                     headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 200
    sql = str(session.execute.call_args.args[0])
    assert "part_catalog" not in sql.lower()
    assert "mater_part_prod" in sql.lower()

    workbook = load_workbook(BytesIO(response.data), read_only=True)
    try:
        headers, data = workbook["Commandes d'achat"].values
        assert headers == tuple(label for _, label in finance.CA_LIBELLES) + tuple(controls)
        assert all("part_catalog" not in label.lower() for label in headers)
        record = dict(zip(headers, data))
        assert record["Article SAP"] == "ART-1"
        assert {label: record[label] for label in controls} == controls
    finally:
        workbook.close()
