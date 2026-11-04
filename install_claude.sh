#!/usr/bin/env bash
# Installation du profil Claude Code de Migration Factory.
set -euo pipefail
AI_REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export AI_REPO_ROOT
# shellcheck source=scripts/ai/install_common.sh
source "$AI_REPO_ROOT/scripts/ai/install_common.sh"
ai_install_main claude "$@"
