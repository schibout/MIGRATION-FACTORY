#!/usr/bin/env bash
# Shared installer functions. Sourced by the two repository entrypoints.

ai_die() { printf 'Erreur : %s\n' "$*" >&2; exit 1; }

ai_usage() {
  cat <<EOF
Usage: bash install_${AI_ASSISTANT}.sh [options]

Installe le CLI si absent, les plugins essentiels et synchronise les skills
du depot. Aucune connexion aux comptes ou a PostgreSQL n'est effectuee.

  --dry-run          Afficher les actions sans ecriture, commande CLI ni reseau.
  --configure-only   Synchroniser seulement les skills du depot (Python 3.11+).
  --skip-cli         Exiger un CLI deja installe, sans le mettre a jour.
  --update-cli       Reinstaller le CLI stable meme s'il est deja present.
  --vscode           Installer aussi les extensions VS Code officielles utiles.
  --design           Ajouter frontend-design au profil de plugins essentiels.
  -h, --help         Afficher cette aide.

Prerequis : Bash, Git, Node.js 20+ / npm et Python 3.11+.
CLI Claude natif stable ; CLI Codex via npm @openai/codex@latest.
Les parametres personnels sont sauvegardes avant les commandes d'installation.
EOF
}

ai_run() {
  printf '+'
  printf ' %q' "$@"
  printf '\n'
  if (( ! AI_DRY_RUN )); then "$@"; fi
}

ai_require() {
  command -v "$1" >/dev/null 2>&1 || ai_die "Commande '$1' absente. $2"
}

ai_python() {
  if (( AI_DRY_RUN )); then AI_PYTHON=python3; return; fi
  if command -v python3 >/dev/null 2>&1; then AI_PYTHON=python3
  elif command -v python >/dev/null 2>&1; then AI_PYTHON=python
  else ai_die 'Installer Python 3.11+ puis relancer.'; fi
  "$AI_PYTHON" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 11) else "Python 3.11+ requis")'
}

ai_backup() {
  # Content is copied without being read into shell output. shutil preserves
  # metadata and refuses silent collisions via a unique timestamp directory.
  if (( AI_DRY_RUN )); then
    printf 'Sauvegarde des configurations personnelles existantes (%s).\n' "$AI_ASSISTANT"
    return
  fi
  "$AI_PYTHON" -c '
from datetime import datetime, timezone
from pathlib import Path
import os, shutil, sys
home = Path.home()
tool = sys.argv[1]
if tool == "claude":
    directory = Path(os.environ.get("CLAUDE_CONFIG_DIR", home / ".claude"))
    paths = [directory / "settings.json", home / ".claude.json"]
else:
    directory = Path(os.environ.get("CODEX_HOME", home / ".codex"))
    paths = [directory / "config.toml"]
existing = [p for p in paths if p.is_file()]
if existing:
    dest = home / ".migration-factory" / "backups" / (datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ") + "-" + tool)
    dest.mkdir(parents=True, mode=0o700)
    for p in existing:
        target = dest / p.name
        shutil.copy2(p, target)
        target.chmod(0o600)
    print("Sauvegarde :", dest)
' "$AI_ASSISTANT"
}

ai_install_claude_cli() {
  if [[ ${OSTYPE:-} == msys* || ${OSTYPE:-} == cygwin* ]]; then
    (( AI_DRY_RUN )) || ai_require powershell.exe 'Utiliser Git Bash ou WSL.'
    ai_run powershell.exe -NoProfile -NonInteractive -Command \
      '& ([scriptblock]::Create((Invoke-RestMethod https://claude.ai/install.ps1))) stable'
  else
    (( AI_DRY_RUN )) || ai_require curl 'Installer curl.'
    if (( AI_DRY_RUN )); then
      printf '+ Telecharger https://claude.ai/install.sh puis executer avec bash stable\n'
    else
      local task_installer
      task_installer="$(mktemp "${TMPDIR:-/tmp}/migration-factory-claude.XXXXXX")"
      if ! curl -fLsS https://claude.ai/install.sh -o "$task_installer"; then
        rm -f -- "$task_installer"
        ai_die 'Telechargement du CLI Claude impossible.'
      fi
      local task_status=0
      bash "$task_installer" stable || task_status=$?
      rm -f -- "$task_installer"
      (( task_status == 0 )) || ai_die 'Installation du CLI Claude en echec.'
    fi
  fi
  # The native installer does not update the current parent shell PATH.
  if (( ! AI_DRY_RUN )); then
    export PATH="$HOME/.local/bin:$PATH"
    hash -r
  fi
}

ai_install_cli() {
  if command -v "$AI_ASSISTANT" >/dev/null 2>&1 && (( ! AI_UPDATE_CLI )); then
    printf 'CLI %s deja disponible ; version conservee.\n' "$AI_ASSISTANT"
    return
  fi
  (( ! AI_SKIP_CLI )) || ai_die "CLI $AI_ASSISTANT absent du PATH ; retirer --skip-cli pour l'installer."
  if [[ $AI_ASSISTANT == claude ]]; then
    ai_install_claude_cli
  else
    ai_run npm install -g @openai/codex@latest
    (( AI_DRY_RUN )) || hash -r
  fi
  if (( ! AI_DRY_RUN )); then
    ai_require "$AI_ASSISTANT" 'Ouvrir un nouveau terminal et verifier le PATH.'
  fi
}

ai_check_cli_api() {
  if (( AI_DRY_RUN )); then return; fi
  if [[ $AI_ASSISTANT == claude ]]; then
    claude plugin install --help >/dev/null 2>&1 || ai_die 'CLI Claude incompatible : commande plugin install indisponible ; relancer avec --update-cli.'
  else
    codex plugin add --help >/dev/null 2>&1 || ai_die 'CLI Codex incompatible : commande plugin add indisponible ; relancer avec --update-cli.'
  fi
}

ai_marketplace_exists() {
  local task_listing task_status=0
  if ! task_listing="$("$AI_ASSISTANT" plugin marketplace list --json)"; then
    ai_die 'Impossible de lire les marketplaces configurees.'
  fi
  printf '%s' "$task_listing" | "$AI_PYTHON" -c '
import json, sys
try:
    data = json.load(sys.stdin)
    entries = data if isinstance(data, list) else data["marketplaces"]
    if not isinstance(entries, list):
        raise ValueError("Liste de marketplaces invalide")
    sys.exit(0 if any(p.get("name") == "claude-plugins-official" for p in entries) else 1)
except (ValueError, KeyError, TypeError) as exc:
    print("Liste de marketplaces invalide :", type(exc).__name__, file=sys.stderr)
    sys.exit(2)
' || task_status=$?
  (( task_status < 2 )) || ai_die 'Format de liste incompatible avec ce CLI ; le mettre a jour.'
  return "$task_status"
}

ai_install_plugins() {
  local task_plugin
  if (( AI_DRY_RUN )); then
    ai_run "$AI_ASSISTANT" plugin marketplace add anthropics/claude-plugins-official
  elif ai_marketplace_exists; then
    printf 'Marketplace claude-plugins-official deja configuree.\n'
  else
    ai_run "$AI_ASSISTANT" plugin marketplace add anthropics/claude-plugins-official
  fi
  if [[ $AI_ASSISTANT == claude ]]; then
    # Installing an existing plugin is supported by the native CLI; failures
    # propagate rather than being treated as "already installed".
    for task_plugin in playwright code-review context7; do
      ai_run claude plugin install "$task_plugin@claude-plugins-official" --scope project
    done
    if (( AI_DESIGN )); then
      ai_run claude plugin install frontend-design@claude-plugins-official --scope local
    fi
  else
    for task_plugin in playwright code-review; do
      ai_run codex plugin add "$task_plugin@claude-plugins-official"
    done
    # `codex mcp add` may immediately start OAuth and block unattended setup.
    # Configure the same HTTP server without making a network/auth request.
    ai_run "$AI_PYTHON" "$AI_REPO_ROOT/scripts/ai/configure_context7.py"
    if (( AI_DESIGN )); then
      ai_run codex plugin add frontend-design@claude-plugins-official
    fi
  fi
}

ai_install_vscode() {
  (( AI_DRY_RUN )) || ai_require code 'Installer VS Code et ajouter sa commande code au PATH.'
  local task_extension
  for task_extension in ms-python.python ms-python.vscode-pylance ms-python.debugpy \
    ms-python.black-formatter ms-python.flake8 esbenp.prettier-vscode dbaeumer.vscode-eslint; do
    ai_run code --install-extension "$task_extension"
  done
  if [[ $AI_ASSISTANT == claude ]]; then
    ai_run code --install-extension anthropic.claude-code
  else
    ai_run code --install-extension openai.chatgpt
  fi
}

ai_install_main() {
  AI_ASSISTANT=$1; shift
  AI_DRY_RUN=0 AI_CONFIGURE_ONLY=0 AI_SKIP_CLI=0 AI_UPDATE_CLI=0 AI_VSCODE=0 AI_DESIGN=0
  while (( $# )); do
    case "$1" in
      --dry-run) AI_DRY_RUN=1 ;;
      --configure-only) AI_CONFIGURE_ONLY=1 ;;
      --skip-cli) AI_SKIP_CLI=1 ;;
      --update-cli) AI_UPDATE_CLI=1 ;;
      --vscode) AI_VSCODE=1 ;;
      --design) AI_DESIGN=1 ;;
      -h|--help) ai_usage; return ;;
      *) ai_die "Option inconnue : $1 (voir --help)." ;;
    esac
    shift
  done
  (( ! AI_SKIP_CLI || ! AI_UPDATE_CLI )) || ai_die '--skip-cli et --update-cli sont incompatibles.'
  (( ! AI_CONFIGURE_ONLY || (! AI_UPDATE_CLI && ! AI_VSCODE && ! AI_DESIGN) )) || ai_die '--configure-only est incompatible avec --update-cli, --vscode ou --design.'
  cd -- "$AI_REPO_ROOT"
  ai_python
  if (( ! AI_CONFIGURE_ONLY )); then
    if (( ! AI_DRY_RUN )); then
      ai_require git 'Installer Git.'
      ai_require node 'Installer Node.js 20+ et npm.'
      ai_require npm 'Installer Node.js 20+ et npm.'
      node -e 'if (Number(process.versions.node.split(".")[0]) < 20) { console.error("Node.js 20+ requis"); process.exit(1); }'
    fi
    ai_backup
    ai_install_cli
    ai_check_cli_api
    ai_install_plugins
    if (( AI_VSCODE )); then ai_install_vscode; fi
  fi
  ai_run "$AI_PYTHON" "$AI_REPO_ROOT/scripts/ai/sync_skills.py"
  if (( AI_DRY_RUN )); then
    printf 'Simulation terminee ; aucun changement effectue.\n'
  else
    printf 'Installation terminee pour %s.\n' "$AI_ASSISTANT"
    if (( ! AI_CONFIGURE_ONLY )); then
      ai_run "$AI_ASSISTANT" --version
      printf 'Ouvrir une session %s pour se connecter et verifier les plugins.\n' "$AI_ASSISTANT"
    fi
  fi
}
