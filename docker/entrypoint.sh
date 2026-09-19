#!/usr/bin/env bash
set -euo pipefail

if [[ -d /workspace/.git ]]; then
  git config --global --add safe.directory /workspace >/dev/null 2>&1 || true
fi

export PATH="${HOME}/.local/bin:${PATH}"
mkdir -p "${HOME}/.cursor/rules" "${HOME}/.claude" "${HOME}/.gemini"

exec /usr/bin/tini -s -- "$@"
