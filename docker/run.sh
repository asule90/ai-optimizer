#!/usr/bin/env bash
# Helper for the Docker test environment.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

usage() {
  cat <<'EOF'
Usage:
  docker/run.sh shell                 Open interactive shell (default)
  docker/run.sh setup                 Run setup.sh interactively
  docker/run.sh setup-auto            Run setup with AUTO_INSTALL_PREREQS=yes
  docker/run.sh rebuild               Rebuild image from scratch
  docker/run.sh reset                 Remove container image and volumes

Examples:
  docker/run.sh shell
  docker/run.sh setup
  AGENT=antigravity docker/run.sh setup-auto
EOF
}

ensure_compose() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "docker is not installed or not on PATH." >&2
    exit 1
  fi
  if ! docker compose version >/dev/null 2>&1; then
    echo "docker compose plugin is required." >&2
    exit 1
  fi
}

cmd="${1:-shell}"
shift || true

ensure_compose

case "$cmd" in
  shell)
    docker compose run --rm setup-test "$@"
    ;;
  setup)
    docker compose run --rm setup-test bash -lc 'bash setup.sh'
    ;;
  setup-auto)
    docker compose run --rm \
      -e AUTO_INSTALL_PREREQS=yes \
      -e INSTALL_NODEJS=yes \
      -e INSTALL_APT_PACKAGES=yes \
      -e ALLOW_SUDO=yes \
      -e SKIP_AGENT_CHECK=yes \
      setup-test bash -lc 'bash setup.sh'
    ;;
  rebuild)
    docker compose build --no-cache setup-test
    ;;
  reset)
    docker compose down --rmi local -v
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    echo "Unknown command: $cmd" >&2
    usage
    exit 1
    ;;
esac
