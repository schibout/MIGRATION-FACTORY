# 1. Installer Ollama
curl -fsSL https://ollama.com/install.sh | sh

# 2. Télécharger le modèle (≈ 4,7 Go)
ollama pull qwen2.5-coder:7b

# 2bis. Télécharger le modèle d'embeddings pour la recherche sémantique (≈ 1,2 Go)
#       Utilisé par l'Assistant IA (RAG sémantique + cache). Dimension 1024.
ollama pull bge-m3

# 3. Configurer le service pour la VM 4 cœurs
sudo mkdir -p /etc/systemd/system/ollama.service.d
sudo tee /etc/systemd/system/ollama.service.d/override.conf << 'EOF'
[Service]
Environment="OLLAMA_NUM_THREADS=4"
Environment="OLLAMA_KEEP_ALIVE=24h"
Environment="OLLAMA_HOST=0.0.0.0:11434"
EOF

sudo systemctl daemon-reload
sudo systemctl restart ollama

# 4. Vérifier que le service tourne
systemctl status ollama
curl http://localhost:11434/api/tags

# 5. Test de vitesse (noter le "eval rate" en fin de sortie)
ollama run qwen2.5-coder:7b --verbose \
  "Génère une requête PostgreSQL pour compter les lignes de la table lfa1 où mandt='700'"

# 6. Pré-charger le modèle en RAM (optionnel, évite la latence au 1er appel)
curl http://localhost:11434/api/generate -d '{"model":"qwen2.5-coder:7b","keep_alive":"24h"}'

# 7. Recherche sémantique (pgvector) :
#    a) Installer l'extension pgvector côté serveur PostgreSQL, puis appliquer la migration :
#       psql -h 10.190.100.58 -U postgres -d sap_migration_db -f migrations/015_create_ai_embeddings.sql
#    b) Construire l'index vectoriel (tables du dictionnaire + exemples few-shot) :
#       cd backend && python build_ai_index.py

# 8. Traitement en arrière-plan (file de jobs) :
#    Appliquer la migration créant la table public.ai_jobs :
#       psql -h 10.190.100.58 -U postgres -d sap_migration_db -f migrations/016_create_ai_jobs.sql
#    Le worker démarre automatiquement avec l'application (AI_JOBS_ENABLED=true).