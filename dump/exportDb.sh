#!/bin/bash

# Paramètres de connexion
DB_USER="postgres"
DB_PASSWORD="trimet2025"
DB_HOST="10.190.100.58"
DB_PORT="5432"
DB_NAME="sap_migration_db"

# Dossier de destination du dump
export BACKUP_DIR="$(pwd)"
# Nom du fichier avec horodatage
export BACKUP_FILE="$BACKUP_DIR/${DB_NAME}_$(date +%Y%m%d_%H%M%S).dump"

# Export de la variable de mot de passe
export PGPASSWORD="$DB_PASSWORD"

# Lancer le dump
pg_dump -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" -F c -b -v -f "$BACKUP_FILE" "$DB_NAME"

# Vérification du résultat
if [ $? -eq 0 ]; then
    echo "✅ Dump PostgreSQL terminé avec succès : $BACKUP_FILE"
else
    echo "❌ Échec du dump PostgreSQL"
fi

# Nettoyage de la variable de mot de passe
unset PGPASSWORD
