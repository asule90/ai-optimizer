#!/usr/bin/env bash
set -euo pipefail

if [[ -d /workspace/.git ]]; then
  git config --global --add safe.directory /workspace >/dev/null 2>&1 || true
fi

export PATH="/usr/local/go/bin:${HOME}/go/bin:${HOME}/.local/bin:${PATH}"

# Docker file bind-mounts (e.g. auth.json → ~/.config/cursor/auth.json) create
# intermediate dirs as root. Fix ownership so RTK/ICM can write under ~/.config.
config_dir="${HOME}/.config"
if [[ -d "$config_dir" ]] && [[ ! -w "$config_dir" ]]; then
  sudo chown -R "$(id -u):$(id -g)" "$config_dir" || true
fi

mkdir -p \
  "${config_dir}/rtk" \
  "${config_dir}/cursor" \
  "${HOME}/.cursor/rules" \
  "${HOME}/.claude" \
  "${HOME}/.gemini" \
  "${HOME}/.local/bin"

exec /usr/bin/tini -s -- "$@"
