# Script PowerShell pour mettre à jour la procédure sp_insert_customer_delivery_tax_info_from_sap
# Ce script corrige l'erreur de type NUMERIC pour TAX_BOOK_TYPE

Write-Host "🔄 Mise à jour de la procédure sp_insert_customer_delivery_tax_info_from_sap..." -ForegroundColor Yellow

# Paramètres de connexion PostgreSQL
$env:PGPASSWORD = "your_password_here"  # Remplacez par votre mot de passe PostgreSQL

try {
    # Exécution de la procédure mise à jour
    & "C:\Program Files\PostgreSQL\15\bin\psql.exe" -h localhost -p 5432 -U postgres -d sap_migration_db -f "sql\customer\sp_insert_customer_delivery_tax_info_from_sap.sql"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Procédure mise à jour avec succès !" -ForegroundColor Green
        Write-Host "🔧 Corrections appliquées :" -ForegroundColor Cyan
        Write-Host "   - TAX_BOOK_TYPE utilise maintenant NULL au lieu de chaîne vide" -ForegroundColor White
        Write-Host "   - Suppression de la jointure inutile avec ADRC" -ForegroundColor White
        Write-Host "   - Ajout de COALESCE pour gérer les valeurs NULL" -ForegroundColor White
    } else {
        Write-Host "❌ Erreur lors de la mise à jour de la procédure" -ForegroundColor Red
        Write-Host "Code de sortie: $LASTEXITCODE" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Erreur lors de l'exécution du script: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "💡 Assurez-vous que PostgreSQL est installé et que le chemin psql.exe est correct" -ForegroundColor Yellow
}

Write-Host "`n🎯 Vous pouvez maintenant relancer l'ETL Customer pour continuer le processus." -ForegroundColor Green

