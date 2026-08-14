@echo off
setlocal
title Tunnel SSH - Hermes / Open WebUI

REM ==============================
REM Configuration
REM ==============================

set SERVER_IP=37.187.157.56
set SSH_USER=ubuntu

REM Le SSH du serveur OVH ecoute sur 65002, pas sur 22
set SSH_PORT=65002

REM Cle privee utilisee pour ce serveur (ed25519, sans passphrase)
REM L'ancienne cle RSA reste acceptee par le serveur : en cas de souci,
REM remettre  set SSH_KEY=C:\Users\admin\.ssh\id_ovh_rsa
set SSH_KEY=C:\Users\samir.chibout\.ssh\id_ed25519

REM ==============================
REM Tunnels locaux
REM ==============================
REM 9119 = Dashboard Hermes (supervision : sessions, journaux, cles API)
REM        A ouvrir avec l'IP http://127.0.0.1:9119 et PAS http://localhost:9119 :
REM        le dashboard refuse un en-tete Host qui ne correspond pas a son bind
REM        ("Invalid Host header"), et localhost peut resoudre en ::1 (IPv6)
REM        alors que ssh -L n'ecoute qu'en IPv4.
REM 8787 = Hermes WebUI  (l'interface a ouvrir dans le navigateur)
REM 8642 = API Hermes    (pas une page web : sert aux appels API)
REM 5433 = PostgreSQL du serveur (distant 5432) — client SQL / chatBotIA

REM Ports locaux utilises par le tunnel (verifies avant ouverture)
set LOCAL_PORTS=9119,8787,8642,5433

REM Signature utilisee pour retrouver / tuer le process ssh du tunnel
set TUNNEL_TAG=8642:127.0.0.1:8642
set TUNNEL_TITLE=Tunnel SSH Hermes - NE PAS FERMER

set ACTION=%~1
if /i "%ACTION%"=="open"   goto :open
if /i "%ACTION%"=="close"  goto :close
if /i "%ACTION%"=="status" goto :status
if /i "%ACTION%"=="shell"  goto :shell
goto :usage


REM ==============================================================
:open
call :getpid
if defined TUNNEL_PID (
  echo.
  echo Le tunnel est deja ouvert ^(PID %TUNNEL_PID%^).
  echo   Dashboard    : http://127.0.0.1:9119   ^<-- supervision ^(IP obligatoire^)
  echo   Hermes WebUI : http://localhost:8787   ^<-- l'interface de chat
  echo   API Hermes   : http://localhost:8642   ^(API, pas une page web^)
  echo   PostgreSQL   : localhost:5433          ^(distant 127.0.0.1:5432^)
  echo.
  goto :end
)

REM Un port local deja pris ferait echouer tout le tunnel
REM ^(ExitOnForwardFailure^) : on previent avant de lancer ssh.
REM Sous Windows, ssh affiche alors "bind: Permission denied", pas "port deja utilise".
call :getbusy
if defined BUSY_PORTS (
  echo.
  echo Impossible d'ouvrir le tunnel : port^(s^) local^(aux^) deja utilise^(s^) : %BUSY_PORTS%
  echo.
  echo Sans doute un autre tunnel SSH lance a la main. Pour voir qui :
  echo   netstat -ano ^| findstr "%BUSY_PORTS%"
  echo Puis : Stop-Process -Id ^<PID^> -Force   ^(PowerShell^)
  echo.
  goto :end
)

echo.
echo ==========================================
echo  Ouverture du tunnel SSH vers %SERVER_IP%
echo ==========================================
echo.

REM -N : pas de shell distant, uniquement les redirections de ports
REM Une fenetre separee s'ouvre : elle sert a saisir la passphrase / le mot de passe.
REM Si tu utilises une cle sans passphrase, remplace  start "%TUNNEL_TITLE%"
REM par  start "%TUNNEL_TITLE%" /min  pour la garder minimisee.
start "%TUNNEL_TITLE%" ssh -N -p %SSH_PORT% -i "%SSH_KEY%" ^
  -o ExitOnForwardFailure=yes ^
  -o ServerAliveInterval=30 ^
  -L 9119:127.0.0.1:9119 ^
  -L 8787:127.0.0.1:8787 ^
  -L 8642:127.0.0.1:8642 ^
  -L 5433:127.0.0.1:5432 ^
  %SSH_USER%@%SERVER_IP%

REM Laisse le temps a ssh de demarrer / d'echouer
timeout /t 3 /nobreak >nul

call :getpid
if defined TUNNEL_PID (
  echo Tunnel ouvert ^(PID %TUNNEL_PID%^).
  echo.
  echo   Dashboard    : http://127.0.0.1:9119   ^<-- supervision ^(IP obligatoire^)
  echo   Hermes WebUI : http://localhost:8787   ^<-- l'interface de chat
  echo   API Hermes   : http://localhost:8642   ^(API, pas une page web^)
  echo   PostgreSQL   : localhost:5433          ^(distant 127.0.0.1:5432^)
  echo.
  echo Pour fermer : ssh.bat close
) else (
  echo Le tunnel n'a pas pu etre etabli.
  echo Regarde la fenetre "%TUNNEL_TITLE%" pour le message d'erreur
  echo ^(mot de passe, cle, port deja utilise...^).
)
echo.
goto :end


REM ==============================================================
:close
call :getpid
if not defined TUNNEL_PID (
  echo.
  echo Aucun tunnel SSH en cours.
  echo.
  goto :end
)

echo.
echo Fermeture du tunnel SSH ^(PID %TUNNEL_PID%^)...
powershell -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'ssh.exe' -and $_.CommandLine -like '*%TUNNEL_TAG%*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }" >nul 2>&1

timeout /t 1 /nobreak >nul
call :getpid
if defined TUNNEL_PID (
  echo Echec : le process %TUNNEL_PID% tourne toujours.
) else (
  echo Tunnel SSH ferme.
)
echo.
goto :end


REM ==============================================================
:status
call :getpid
echo.
if defined TUNNEL_PID (
  echo Tunnel SSH OUVERT ^(PID %TUNNEL_PID%^)
  echo   Dashboard    : http://127.0.0.1:9119   ^<-- supervision ^(IP obligatoire^)
  echo   Hermes WebUI : http://localhost:8787   ^<-- l'interface de chat
  echo   API Hermes   : http://localhost:8642   ^(API, pas une page web^)
  echo   PostgreSQL   : localhost:5433          ^(distant 127.0.0.1:5432^)
) else (
  echo Tunnel SSH FERME.
)
echo.
goto :end


REM ==============================================================
REM Session SSH interactive (shell distant), sans redirection de ports.
REM Bloque cette fenetre jusqu'a ce que tu tapes "exit" cote serveur.
:shell
echo.
echo Connexion a %SSH_USER%@%SERVER_IP% ^(port %SSH_PORT%^)...
echo Tape "exit" pour revenir.
echo.
ssh -p %SSH_PORT% -i "%SSH_KEY%" %SSH_USER%@%SERVER_IP%
goto :end


REM ==============================================================
:usage
echo.
echo Usage :
echo   ssh.bat open     Ouvre le tunnel SSH vers %SERVER_IP%
echo   ssh.bat close    Ferme le tunnel SSH
echo   ssh.bat status   Affiche l'etat du tunnel
echo   ssh.bat shell    Ouvre une session SSH interactive ^(sans tunnel^)
echo.
echo Ports rediriges : 9119 ^(Dashboard^), 8787 ^(Hermes WebUI^), 8642 ^(API^), 5433 ^(PostgreSQL^)
echo Serveur         : %SSH_USER%@%SERVER_IP% port %SSH_PORT%
echo.
goto :end


REM ==============================================================
REM Recherche le PID du process ssh.exe portant notre redirection
:getpid
set TUNNEL_PID=
for /f "usebackq delims=" %%P in (`powershell -NoProfile -Command "Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'ssh.exe' -and $_.CommandLine -like '*%TUNNEL_TAG%*' } | ForEach-Object { $_.ProcessId }"`) do set TUNNEL_PID=%%P
exit /b 0


REM Liste les ports locaux du tunnel qui sont deja en ecoute
:getbusy
set BUSY_PORTS=
for /f "usebackq delims=" %%B in (`powershell -NoProfile -Command "$b = @(%LOCAL_PORTS%) | Where-Object { Get-NetTCPConnection -LocalPort $_ -State Listen -ErrorAction SilentlyContinue }; if ($b) { $b -join ' ' }"`) do set BUSY_PORTS=%%B
exit /b 0


:end
endlocal
