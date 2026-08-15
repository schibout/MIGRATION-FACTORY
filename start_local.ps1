<#
    Migration Factory — demarrage LOCAL (poste Windows, sans Docker)

    Ouvre backend Flask (127.0.0.1:5000) et frontend Vite (127.0.0.1:3100)
    dans deux fenetres PowerShell separees.

    PREREQUIS : le tunnel SSH doit etre ouvert AVANT
        .\ssh_taskForce.bat open
    Il expose la base de PRODUCTION sur 127.0.0.1:5433 (cf. .env).

    Pourquoi pas docker-compose ? Sur ce poste le registre Docker Hub coupe le
    telechargement des blobs (EOF), aucune image de base n'est recuperable.
    Voir docker-compose.override.yml pour repasser sur Docker le jour ou ca
    remarche.

    Usage :  .\start_local.ps1
#>

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

# --- Verifications prealables ------------------------------------------------
if (-not (Test-Path "$root\.env")) {
    throw "Fichier .env absent : le backend n'aurait ni base ni secrets."
}

$tunnel = Get-NetTCPConnection -LocalPort 5433 -State Listen -ErrorAction SilentlyContinue
if (-not $tunnel) {
    Write-Warning "Aucun tunnel SSH sur le port 5433. Lancez d'abord : .\ssh_taskForce.bat open"
    Write-Warning "Le backend demarrera, mais /health rapportera la base en erreur."
}

$venvPython = "$root\backend\.venv\Scripts\python.exe"
if (-not (Test-Path $venvPython)) {
    throw "venv backend absent. Creez-le : python -m venv backend\.venv puis installez les dependances."
}

if (-not (Test-Path "$root\frontend\node_modules")) {
    throw "node_modules absent. Lancez : npm --prefix frontend install"
}

# --- Lancement ---------------------------------------------------------------
# On passe par le CLI flask et non `python app.py` : app.py force host='0.0.0.0',
# ce qui exposerait au reseau d'entreprise un backend connecte a la base de
# PRODUCTION. Le CLI permet de rester sur la loopback, comme le conteneur en prod
# (docker-compose.yml bind "127.0.0.1:5000:5000").
Write-Host "Demarrage du backend Flask (127.0.0.1:5000)..." -ForegroundColor Cyan
Start-Process powershell -ArgumentList @(
    '-NoExit', '-Command',
    "Set-Location '$root\backend'; `$env:PYTHONIOENCODING='utf-8'; `$env:FLASK_APP='app'; " +
    "& '$venvPython' -m flask run --host 127.0.0.1 --port 5000 --no-reload"
)

Write-Host "Demarrage du frontend Vite (127.0.0.1:3100)..." -ForegroundColor Cyan
Start-Process powershell -ArgumentList @(
    '-NoExit', '-Command',
    "npm --prefix '$root\frontend' run dev -- --port 3100 --host 127.0.0.1"
)

Write-Host ""
Write-Host "Application : http://127.0.0.1:3100" -ForegroundColor Green
Write-Host "API         : http://127.0.0.1:5000/health" -ForegroundColor Green
Write-Host "Fermez les deux fenetres PowerShell pour arreter." -ForegroundColor DarkGray
