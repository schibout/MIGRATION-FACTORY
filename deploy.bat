@echo off
setlocal
REM =====================================================================
REM deploy.bat - Pousse la branche courante sur GitHub puis redeploie le serveur.
REM
REM   deploy.bat              push + ssh migration + git pull + deploiement incremental
REM   deploy.bat --build      idem, en forcant le rebuild des images
REM   deploy.bat --force      redeploie meme sans nouveau commit
REM
REM Les options sont transmises telles quelles a deploy.sh sur le serveur, qui fait
REM le "git pull --ff-only" puis ne redemarre que les services touches par le diff.
REM L'hote "migration" vient de ~/.ssh/config (root@10.190.100.58).
REM Seul ce qui est COMMITE part : les modifications locales non commitees restent ici.
REM =====================================================================

set SSH_HOST=migration
set REMOTE_DIR=/root/migration-Factory

cd /d "%~dp0"

for /f "delims=" %%B in ('git branch --show-current') do set BRANCH=%%B
echo.
echo === 1/2 git push origin %BRANCH% ===
git status --short | findstr . >nul && echo [WARN] Modifications non commitees : elles ne seront PAS deployees.
git push origin %BRANCH%
if errorlevel 1 (
  echo [ERREUR] git push a echoue, deploiement annule.
  exit /b 1
)

echo.
echo === 2/2 ssh %SSH_HOST% : git pull + deploiement dans %REMOTE_DIR% ===
ssh %SSH_HOST% "cd %REMOTE_DIR% && ./deploy.sh %*"
if errorlevel 1 (
  echo [ERREUR] Le deploiement distant a echoue.
  exit /b 1
)

echo.
echo Deploiement termine : http://10.190.100.58:8081/
endlocal
