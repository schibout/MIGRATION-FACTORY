#!/bin/bash

# Paramètres de connexion
DB_USER="postgres"
DB_PASSWORD="trimet2025"
DB_HOST="10.190.100.58"
DB_PORT="5432"
DB_NAME="sap_migration_db"

# Chemin du fichier à importer (mettre le bon nom de fichier ici)
# Exemple : sap_migration_db_20250701_093015.dump
DUMP_FILE="./sap_migration_db_latest.dump"  # Modifie ce nom si besoin

# Export du mot de passe pour pg_restore
export PGPASSWORD="$DB_PASSWORD"

# (Re)créer la base (optionnel, mais utile pour une restauration propre)
echo "📌 Création de la base : $DB_NAME (si elle existe déjà, elle sera supprimée)"
dropdb -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" "$DB_NAME"
createdb -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" "$DB_NAME"

# Lancer la restauration
echo "🔄 Restauration à partir du fichier : $DUMP_FILE"
pg_restore -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -v "$DUMP_FILE"

# Vérification
if [ $? -eq 0 ]; then
    echo "✅ Restauration PostgreSQL terminée avec succès"
else
    echo "❌ Échec de la restauration PostgreSQL"
fi

# Nettoyage
unset PGPASSWORD
