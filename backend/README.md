# Migration Factory API

Backend Flask pour la gestion des extractions SAP et l'export de données vers PostgreSQL.

## Architecture

Cette API RESTful sert d'interface entre les scripts d'extraction SAP et la base de données PostgreSQL, ainsi que de couche d'API pour l'interface web de Migration Factory.

![Architecture](https://mermaid.ink/img/pako:eNp1kk1PwzAMhv9KlBMgVd32AbsAElcOSEicKi5u4q2R8jFsKW0R_3278VYxDfbi2H728mvnCJrVCBK29-3-g7FKKdcQZ5yXwGgN-x44E-ZIuXcOQkPcWGmZ0c7CMPJYd4VhpEtXKsMJOYwjzdV9INYUB_o7jglFebnGpQbnr-Ow1JVrXBu38KPx13q12s53OGnckWqXpkRl_JE5Lm3DnOtZeWHQVyynBqbBPrJSpqZkB4tVN-ffuIa7xUINUhZDC9q4VdftU3rShgnPbOFKXdvmEmofsjWEb__yavPZ64ZBqI1GbVFDWKpFCGF6p9-bSAzaIhK5RYKEJzL0_STw3N-9LcpG0TxDpZgshQTS0Ew_YZpF6SJKom0aJWkSp2mcbCZ5dE3jeLdJVzssJZyCBonXbVXXu8QA8Qy8QDSBNErSdOuXRL2Ot-MFIHAyOw?type=png)

### Composants principaux

- **API RESTful**: Gère les requêtes HTTP et orchestration des services
- **Services d'extraction**: Interface avec les scripts existants
- **Services de données**: Gestion de l'accès à PostgreSQL et export des données
- **Authentification JWT**: Sécurisation de l'API via tokens

## Fonctionnalités

- ✅ Authentification et gestion des utilisateurs
- ✅ Déclenchement et monitoring des extractions SAP
- ✅ Consultation et filtrage des données en base PostgreSQL
- ✅ Export de données au format CSV et Excel avec options avancées
- ✅ API REST documentée via OpenAPI/Swagger
- ✅ Logging et tracking des actions
- ✅ Rate limiting et protection contre les abus

## Prérequis

- Python 3.9+
- PostgreSQL 12+
- Accès aux scripts d'extraction SAP (`migrationFactory/sap_extraction/`)
- Docker (optionnel pour le déploiement)

## Installation

### Développement local

1. Cloner le dépôt:
```bash
git clone <repository-url>
cd backend
```

2. Créer un environnement virtuel:
```bash
python -m venv venv
source venv/bin/activate  # Linux/Mac
# ou
venv\Scripts\activate     # Windows
```

3. Installer les dépendances:
```bash
pip install -r requirements.txt
```

4. Configurer les variables d'environnement:
```bash
cp .env.example .env
# Modifier .env selon votre environnement
```

5. Lancer le serveur de développement:
```bash
flask run --debug
```

L'API sera accessible à l'adresse: http://localhost:5000

### Déploiement Docker

1. Construire l'image:
```bash
docker build -t migration-factory-api .
```

2. Lancer le conteneur:
```bash
docker run -p 5000:5000 \
  -v /chemin/absolu/vers/sap_extraction:/app/sap_extraction \
  -e DATABASE_URI=postgresql://user:password@postgres-host:5432/sap_migration \
  -e SAP_EXTRACTION_PATH=/app/sap_extraction \
  -e SECRET_KEY=your-secret-key \
  migration-factory-api
```

## Documentation API

La documentation complète de l'API est disponible au format Swagger/OpenAPI.

Pour visualiser la documentation:
1. Démarrer le serveur
2. Accéder à l'interface Swagger UI: http://localhost:5000/api/docs

## Architecture du code

```
backend/
├── app.py                 # Point d'entrée de l'application
├── config/                # Configuration
│   ├── __init__.py
│   └── settings.py        # Paramètres par environnement
├── api/                   # Endpoints API
│   ├── __init__.py
│   ├── auth.py            # Endpoints d'authentification
│   ├── extraction.py      # Endpoints pour les extractions
│   └── data.py            # Endpoints pour les données et exports
├── services/              # Logique métier
│   ├── __init__.py
│   ├── extraction_service.py  # Service d'extraction
│   └── data_service.py    # Service d'accès et export des données
├── models/                # Modèles SQLAlchemy
│   ├── __init__.py
│   └── user.py            # Modèle utilisateur
├── utils/                 # Utilitaires
│   ├── __init__.py
│   └── validators.py      # Validation des entrées utilisateur
├── Dockerfile             # Configuration Docker
├── requirements.txt       # Dépendances Python
└── swagger.json           # Documentation OpenAPI/Swagger
```

## Optimisations implémentées

1. **Performance**:
   - Streaming des réponses pour les exports volumineux
   - Extraction par lots des données (chunking)
   - Cache de schéma pour les tables
   - Pool de connexions SQLAlchemy optimisé

2. **Sécurité**:
   - Validation stricte des entrées utilisateur
   - Prévention des injections SQL
   - Rate limiting
   - Authentification JWT avec refresh tokens
   - Sanitization des données

3. **Évolutivité**:
   - Architecture modulaire
   - Extraction asynchrone en tâches de fond
   - Gestion des tâches longues

## Tests

Exécuter les tests unitaires:
```bash
pytest
```

Avec couverture:
```bash
pytest --cov=.
```

## Contribution

1. Créez une branche pour votre fonctionnalité (`git checkout -b feature/amazing-feature`)
2. Committez vos changements (`git commit -m 'Add some amazing feature'`)
3. Poussez vers la branche (`git push origin feature/amazing-feature`)
4. Ouvrez une Pull Request

## Licence

Propriétaire - Tous droits réservés 