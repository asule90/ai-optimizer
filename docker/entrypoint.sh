#!/usr/bin/env bash
set -euo pipefail

if [[ -d /workspace/.git ]]; then
  git config --global --add safe.directory /workspace >/dev/null 2>&1 || true
fi

export PATH="/usr/local/go/bin:/usr/local/bin:${HOME}/go/bin:${HOME}/.local/bin:${PATH}"

# Bind mounts (auth.json, ./docker/local, ./docker/go, ./docker/cache) often
# create host dirs as root. Fix ownership so testuser can write before mkdir.
fix_writable_dir() {
  local dir="$1"
  if [[ -d "$dir" ]] && [[ ! -w "$dir" ]]; then
    sudo chown -R "$(id -u):$(id -g)" "$dir" || true
  fi
}

# Official installer puts Cursor under ~/.local; ./docker/local bind-mount hides
# the image copy. Seed from /opt/cursor-agent (baked in Dockerfile) when missing.
seed_cursor_cli_into_local() {
  local opt_src="/opt/cursor-agent"
  local share_dst="${HOME}/.local/share/cursor-agent"
  local ver_bin=""

  [[ -d "$opt_src" ]] || return 0

  mkdir -p "${HOME}/.local/share" "${HOME}/.local/bin"

  if [[ ! -e "${HOME}/.local/bin/agent" && ! -e "${HOME}/.local/bin/cursor-agent" ]]; then
    if [[ ! -d "$share_dst" ]]; then
      echo "📦 Seeding Cursor CLI into ~/.local from /opt/cursor-agent..."
      cp -a "$opt_src" "$share_dst"
    fi
    ver_bin="$(find "$share_dst/versions" -maxdepth 2 -type f -name cursor-agent 2>/dev/null | sort | tail -1 || true)"
    if [[ -n "$ver_bin" ]]; then
      ln -sfn "$ver_bin" "${HOME}/.local/bin/agent"
      ln -sfn "$ver_bin" "${HOME}/.local/bin/cursor-agent"
    fi
  fi
}

config_dir="${HOME}/.config"
fix_writable_dir "$config_dir"
fix_writable_dir "${HOME}/.local"
fix_writable_dir "${HOME}/.cache"
fix_writable_dir "${HOME}/go"

mkdir -p \
  "${config_dir}/rtk" \
  "${config_dir}/cursor" \
  "${HOME}/.cursor/rules" \
  "${HOME}/.claude" \
  "${HOME}/.gemini" \
  "${HOME}/.local/bin" \
  "${HOME}/.cache" \
  "${HOME}/go/bin"

seed_cursor_cli_into_local

exec /usr/bin/tini -s -- "$@"
