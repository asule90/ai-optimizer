#!/usr/bin/env bash
# Setup RTK, ICM, Caveman, and QMD for AI agent token compression.
# Run from the project root (where .git / docs / AGENTS.md live).
#
# Cursor / Cursor CLI: ICM uses MCP (~/.cursor/mcp.json) + rule (~/.cursor/rules/icm.mdc).
# Hooks (icm init --mode hook) are for Claude Code, Gemini, Codex, Copilot, OpenCode — not Cursor.
#
# Optional env (non-interactive):
#   AGENT=cursor|github-copilot|antigravity
#   ENABLE_ICM=yes|no
#   CAVEMAN_LEVEL=lite|full|ultra|wenyan  (default: lite for Cursor compression rule)
#   AUTO_INSTALL_PREREQS=yes|no  — approve all system prerequisite installs
#   INSTALL_NODEJS=yes|no        — Node.js 22+ via package manager (sudo)
#   INSTALL_APT_PACKAGES=yes|no  — apt packages such as pipx (sudo)
#   ALLOW_SUDO=yes|no            — sudo for npm global installs / permission fixes
#   SKIP_AGENT_CHECK=yes|no      — skip Cursor/Copilot/Antigravity install verification (e.g. Docker)
set -e

# -------------------------------
# PERMISSION HELPERS
# -------------------------------

is_interactive() {
  [[ -t 0 ]]
}

env_is_yes() {
  case "${1:-}" in
    yes|Yes|YES|y|Y|1|true|TRUE) return 0 ;;
    *) return 1 ;;
  esac
}

env_is_no() {
  case "${1:-}" in
    no|No|NO|n|N|0|false|FALSE) return 0 ;;
    *) return 1 ;;
  esac
}

# ask_permission "description" [ENV_VAR]
# Returns 0 if approved. Honors ENV_VAR, then AUTO_INSTALL_PREREQS, then interactive prompt.
ask_permission() {
  local description="$1"
  local env_var="${2:-}"

  if [[ -n "$env_var" ]]; then
    local env_val="${!env_var:-}"
    if env_is_yes "$env_val"; then
      return 0
    fi
    if env_is_no "$env_val"; then
      return 1
    fi
  fi

  if [[ -n "${AUTO_INSTALL_PREREQS:-}" ]]; then
    if env_is_yes "${AUTO_INSTALL_PREREQS}"; then
      return 0
    fi
    if env_is_no "${AUTO_INSTALL_PREREQS}"; then
      return 1
    fi
  fi

  if ! is_interactive; then
    echo "❌ Permission required (non-interactive): ${description}"
    if [[ -n "$env_var" ]]; then
      echo "   Set ${env_var}=yes or AUTO_INSTALL_PREREQS=yes, then re-run."
    else
      echo "   Set AUTO_INSTALL_PREREQS=yes, then re-run."
    fi
    return 1
  fi

  echo ""
  echo "🔐 Permission required: ${description}"
  select _choice in "No" "Yes"; do
    case "$_choice" in
      Yes) return 0 ;;
      No)  return 1 ;;
    esac
  done
}

sudo_cmd() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
    return $?
  fi
  if ! command -v sudo &> /dev/null; then
    echo "❌ sudo is required but not installed."
    return 1
  fi
  sudo "$@"
}

ensure_path_contains() {
  local dir="$1"
  if [ -n "$dir" ] && [ -d "$dir" ] && [[ ":$PATH:" != *":$dir:"* ]]; then
    export PATH="${dir}:$PATH"
  fi
}

# RTK, ICM, Graphify, and Antigravity CLI install into ~/.local/bin.
ensure_local_bin_on_path() {
  ensure_path_contains "$HOME/.local/bin"
}

require_command() {
  local cmd="$1"
  local hint="$2"
  ensure_local_bin_on_path
  if ! command -v "$cmd" &> /dev/null; then
    echo "❌ ${cmd} not found on PATH."
    echo "   ${hint}"
    exit 1
  fi
}

ensure_agent_home_dirs() {
  mkdir -p "$HOME/.local/bin"

  case "$AGENT" in
    cursor|github-copilot)
      mkdir -p "$HOME/.cursor/rules"
      # RTK global Cursor init still writes Claude awareness files under ~/.claude
      # on fresh machines; create it so rtk init does not fail (rtk-ai/rtk#1465).
      mkdir -p "$HOME/.claude"
      ;;
    antigravity)
      mkdir -p "$HOME/.gemini"
      ;;
  esac
}

agent_cursor_installed() {
  command -v cursor &>/dev/null && return 0
  command -v agent &>/dev/null && return 0
  [[ -x /opt/cursor.AppImage ]] && return 0
  [[ -f "$HOME/.cursor/cli-config.json" ]] && return 0
  return 1
}

agent_copilot_installed() {
  command -v code &>/dev/null && return 0
  command -v copilot &>/dev/null && return 0
  [[ -d "${XDG_CONFIG_HOME:-$HOME/.config}/Code/User" ]] && return 0
  [[ -d "$HOME/Library/Application Support/Code/User" ]] && return 0
  return 1
}

agent_antigravity_installed() {
  command -v agy &>/dev/null && return 0
  [[ -d "$HOME/.gemini/antigravity-cli" ]] && return 0
  return 1
}

require_agent_installed() {
  if env_is_yes "${SKIP_AGENT_CHECK:-}"; then
    echo "⏭️ Skipping agent install check (SKIP_AGENT_CHECK=yes)."
    return 0
  fi

  case "$AGENT" in
    cursor)
      if agent_cursor_installed; then
        if command -v cursor &>/dev/null; then
          echo "✅ Cursor detected ($(command -v cursor))."
        elif command -v agent &>/dev/null; then
          echo "✅ Cursor CLI detected ($(command -v agent))."
        else
          echo "✅ Cursor detected (~/.cursor or AppImage)."
        fi
        return 0
      fi
      echo "❌ Cursor is not installed (or not detectable on this machine)."
      echo ""
      echo "Install Cursor first, then re-run this script:"
      echo "  • Cursor IDE — https://cursor.com/download"
      echo "  • Cursor CLI   — curl https://cursor.com/install -fsS | bash"
      echo "                   then: export PATH=\"\$HOME/.local/bin:\$PATH\" && agent --version"
      exit 1
      ;;
    github-copilot)
      if agent_copilot_installed; then
        if command -v code &>/dev/null; then
          echo "✅ VS Code detected ($(command -v code))."
        elif command -v copilot &>/dev/null; then
          echo "✅ GitHub Copilot CLI detected ($(command -v copilot))."
        else
          echo "✅ VS Code / Copilot config detected."
        fi
        return 0
      fi
      echo "❌ GitHub Copilot environment is not installed (or not detectable)."
      echo ""
      echo "Install GitHub Copilot first, then re-run this script:"
      echo "  • VS Code + GitHub Copilot extension — https://code.visualstudio.com/"
      echo "  • GitHub Copilot CLI — https://docs.github.com/en/copilot/how-tos/set-up/install-copilot-cli"
      exit 1
      ;;
    antigravity)
      if agent_antigravity_installed; then
        echo "✅ Antigravity CLI detected ($(command -v agy 2>/dev/null || echo ~/.gemini/antigravity-cli))."
        return 0
      fi
      echo "❌ Antigravity CLI (agy) is not installed."
      echo ""
      echo "Install Antigravity CLI first, then re-run this script:"
      echo "  curl -fsSL https://antigravity.google/cli/install.sh | bash"
      echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
      echo "  agy --version"
      exit 1
      ;;
  esac
}

echo "🚀 AI Compression Setup (RTK + ICM + Caveman + QMD)"
echo "===================================================="

# -------------------------------
# AGENT SELECTION
# -------------------------------

if [[ -n "${AGENT:-}" ]]; then
  echo "Using AGENT=${AGENT} from environment."
else
  echo "Which AI agent are you using?"
  agents=("github-copilot" "cursor" "antigravity")
  select AGENT in "${agents[@]}"; do
    [[ -n "$AGENT" ]] && break
  done
fi

# Back-compat: older configs used AGENT=gemini. Treat it as Antigravity now.
if [[ "${AGENT:-}" == "gemini" ]]; then
  echo "ℹ️  Mapping AGENT=gemini -> AGENT=antigravity"
  AGENT="antigravity"
fi

case $AGENT in
  github-copilot) RTK_FLAG="--copilot" ;;
  cursor)         RTK_FLAG="--agent cursor" ;;
  antigravity)    RTK_FLAG="--agent antigravity" ;;
  *)
    echo "❌ Unknown AGENT: $AGENT"
    exit 1
    ;;
esac

require_agent_installed

# -------------------------------
# ICM (agent-specific; see https://github.com/rtk-ai/icm/docs/integrations.md)
# -------------------------------

icm_default_for_agent() {
  case "$AGENT" in
    cursor) echo "yes" ;;
    *)      echo "no" ;;
  esac
}

if [[ -n "${ENABLE_ICM:-}" ]]; then
  echo "Using ENABLE_ICM=${ENABLE_ICM} from environment."
else
  default_icm="$(icm_default_for_agent)"
  if [[ "$AGENT" == "cursor" ]]; then
    echo "Enable ICM for Cursor? (MCP server + ~/.cursor/rules/icm.mdc — not shell hooks)"
    echo "  Hooks auto-extract only for Claude Code / Gemini / Codex / Copilot CLI."
  else
    echo "Enable ICM? (mode depends on agent; may require ~/.gemini write access for some tools)"
  fi
  icm_prompt_default="No"
  [[ "$default_icm" == "yes" ]] && icm_prompt_default="Yes"
  select ICM_CHOICE in "No" "Yes"; do
    case "$ICM_CHOICE" in
      Yes) ENABLE_ICM="yes"; break ;;
      No)  ENABLE_ICM="no"; break ;;
    esac
  done
fi

# -------------------------------
# GLOBAL: RTK
# -------------------------------

if ! command -v rtk &> /dev/null; then
  echo "📦 Installing RTK..."
  curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
else
  echo "✅ RTK already installed."
fi
ensure_local_bin_on_path
require_command rtk "RTK installs to ~/.local/bin. Run: export PATH=\"\$HOME/.local/bin:\$PATH\""
ensure_agent_home_dirs

echo "🔧 Configuring RTK for ${AGENT}..."
if [[ "$AGENT" == "antigravity" ]]; then
  rtk init $RTK_FLAG
else
  rtk init -g $RTK_FLAG
fi

# -------------------------------
# GLOBAL: ICM
# -------------------------------

ensure_gemini_settings_path() {
  local gemini_dir="$HOME/.gemini"
  mkdir -p "$gemini_dir"
  if [ ! -w "$gemini_dir" ]; then
    echo "⚠️ $gemini_dir is not writable by $(whoami)."
    if ask_permission "Fix ownership/permissions for ${gemini_dir}? (requires sudo)" "ALLOW_SUDO"; then
      echo "🔧 Attempting to fix ownership/permissions for $gemini_dir..."
      sudo_cmd chown -R "$(id -u):$(id -g)" "$gemini_dir"
      chmod u+rwx "$gemini_dir"
    fi
  fi
  if [ ! -w "$gemini_dir" ]; then
    echo "❌ Cannot write to $gemini_dir."
    echo "👉 Run: sudo chown -R $(id -u):$(id -g) $gemini_dir"
    exit 1
  fi
}

install_icm_if_missing() {
  if command -v icm &> /dev/null; then
    echo "✅ ICM already installed ($(icm --version 2>/dev/null || true))."
    return 0
  fi
  echo "📦 Installing ICM..."
  curl -fsSL https://raw.githubusercontent.com/rtk-ai/icm/main/install.sh | sh
  ensure_local_bin_on_path
}

icm_init_force=()
if icm init --help 2>&1 | grep -q -- '--force'; then
  icm_init_force=(--force)
fi

setup_icm_for_agent() {
  install_icm_if_missing
  require_command icm "ICM installs to ~/.local/bin. Run: export PATH=\"\$HOME/.local/bin:\$PATH\""

  case "$AGENT" in
    cursor)
      echo "🔧 ICM for Cursor: MCP (~/.cursor/mcp.json) + rule (~/.cursor/rules/icm.mdc)..."
      icm init --mode mcp "${icm_init_force[@]}"
      icm init --mode skill "${icm_init_force[@]}"
      if [[ -f "$HOME/.cursor/mcp.json" ]] && ! grep -q '"icm"' "$HOME/.cursor/mcp.json" 2>/dev/null; then
        echo "⚠️ ~/.cursor/mcp.json exists but may not list icm — check manually or re-run: icm init --mode mcp"
      fi
      if [[ ! -f "$HOME/.cursor/rules/icm.mdc" ]]; then
        echo "⚠️ Expected ~/.cursor/rules/icm.mdc — re-run: icm init --mode skill"
      else
        echo "✅ ICM Cursor rule: ~/.cursor/rules/icm.mdc"
      fi
      echo ""
      echo "ℹ️  Cursor does not use icm hook (post/compact/prompt). Memory via MCP or: icm recall / icm store"
      echo "   Restart Cursor / Cursor CLI after MCP config changes."
      ;;
    antigravity)
      ensure_gemini_settings_path
      echo "🔧 ICM for Antigravity CLI: MCP + CLI instructions..."
      icm init --mode mcp "${icm_init_force[@]}"
      icm init --mode cli "${icm_init_force[@]}"
      ;;
    github-copilot)
      echo "🔧 ICM for GitHub Copilot: MCP + copilot-instructions..."
      icm init --mode mcp "${icm_init_force[@]}"
      icm init --mode cli "${icm_init_force[@]}"
      ;;
  esac

  if [[ "$AGENT" == "cursor" ]]; then
    echo ""
    echo "Also install ICM hooks for Claude Code / Gemini / Codex? (optional; not used by Cursor)"
    if [[ -n "${ENABLE_ICM_HOOKS:-}" ]]; then
      echo "Using ENABLE_ICM_HOOKS=${ENABLE_ICM_HOOKS} from environment."
    else
      select HOOKS_CHOICE in "No" "Yes"; do
        case "$HOOKS_CHOICE" in
          Yes) ENABLE_ICM_HOOKS="yes"; break ;;
          No)  ENABLE_ICM_HOOKS="no"; break ;;
        esac
      done
    fi
    if [[ "${ENABLE_ICM_HOOKS:-no}" == "yes" ]]; then
      ensure_gemini_settings_path
      echo "🔧 ICM hook mode (Claude Code, Gemini, Codex, Copilot CLI, OpenCode)..."
      icm init --mode hook "${icm_init_force[@]}"
    fi
  else
    ensure_gemini_settings_path
    echo "🔧 ICM hook mode (Claude Code, Gemini, Codex, Copilot CLI, OpenCode)..."
    icm init --mode hook "${icm_init_force[@]}"
  fi
}

if [[ "$ENABLE_ICM" == "yes" ]]; then
  setup_icm_for_agent
else
  echo "⏭️ Skipping ICM initialization."
fi

# -------------------------------
# Cursor: compression rule (RTK + QMD + caveman lite) — separate from icm.mdc
# -------------------------------

CAVEMAN_LEVEL="${CAVEMAN_LEVEL:-lite}"

write_cursor_compression_rule() {
  [[ "$AGENT" == "cursor" ]] || return 0
  local rules_dir="$HOME/.cursor/rules"
  local rule_file="$rules_dir/compression.mdc"
  mkdir -p "$rules_dir"
  echo "📝 Writing Cursor rule: $rule_file (caveman ${CAVEMAN_LEVEL}, QMD, RTK)..."
  cat > "$rule_file" << EOF
---
description: Token compression defaults (RTK, QMD, caveman ${CAVEMAN_LEVEL})
alwaysApply: true
---

## Compression defaults

- Default reply style: **caveman ${CAVEMAN_LEVEL}** — tight prose, no filler; keep grammar, code blocks, and error strings exact.
- Project documentation: prefer \`qmd search\` / \`qmd query -c ${QMD_COLLECTION}\` (collection \`qmd://${QMD_COLLECTION}\`) before reading many \`.md\` files.
- Large shell file reads: prefer \`rtk read\` over \`cat\` / \`head\` when using Shell.
- Cross-session memory: use ICM MCP tools (\`icm_memory_recall\`, \`icm_memory_store\`) or CLI (\`icm recall\`, \`icm store\`). Same SQLite DB across all tools.
- Do not stack redundant compression (RTK already compresses Shell output via hooks).
EOF
  echo "✅ Cursor compression rule installed."
}

# -------------------------------
# QMD
# -------------------------------

node_npm_ready() {
  local node_major="0"
  if command -v node &> /dev/null; then
    node_major="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
  fi
  command -v npm &> /dev/null && command -v node &> /dev/null && [ "$node_major" -ge 22 ]
}

ensure_node_npm() {
  local node_major="0"
  if command -v node &> /dev/null; then
    node_major="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
  fi
  if node_npm_ready; then
    return 0
  fi

  if command -v node &> /dev/null || command -v npm &> /dev/null; then
    echo "⚠️ Node.js/npm found but version ${node_major:-unknown} is below 22 (QMD requires 22+)."
  else
    echo "⚠️ Node.js/npm not found (QMD requires Node.js 22+)."
  fi

  if ! ask_permission "Install or upgrade Node.js 22+ via system package manager? (requires sudo)" "INSTALL_NODEJS"; then
    echo "❌ Node.js/npm 22+ is required for QMD."
    echo "   Install manually, or re-run with INSTALL_NODEJS=yes (or AUTO_INSTALL_PREREQS=yes)."
    exit 1
  fi

  echo "📦 Installing/upgrading Node.js/npm prerequisites..."
  if command -v apt-get &> /dev/null; then
    sudo_cmd apt-get update
    sudo_cmd apt-get install -y ca-certificates curl gnupg
    sudo_cmd mkdir -p /etc/apt/keyrings
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo_cmd gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" | sudo_cmd tee /etc/apt/sources.list.d/nodesource.list > /dev/null
    sudo_cmd apt-get update
    sudo_cmd apt-get install -y nodejs
  elif command -v dnf &> /dev/null; then
    sudo_cmd dnf install -y nodejs npm
  elif command -v yum &> /dev/null; then
    sudo_cmd yum install -y nodejs npm
  elif command -v pacman &> /dev/null; then
    sudo_cmd pacman -Sy --noconfirm nodejs npm
  elif command -v zypper &> /dev/null; then
    sudo_cmd zypper --non-interactive install nodejs npm
  else
    echo "❌ Unsupported package manager. Install Node.js 22+ manually, then re-run."
    exit 1
  fi
  node_major="0"
  if command -v node &> /dev/null; then
    node_major="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
  fi
  if ! command -v npm &> /dev/null || ! command -v node &> /dev/null || [ "$node_major" -lt 22 ]; then
    echo "❌ Node.js/npm 22+ installation did not complete successfully."
    exit 1
  fi
}

ensure_user_writable_npm_prefix() {
  local npm_prefix
  npm_prefix="$(npm config get prefix 2>/dev/null || true)"
  if [ -n "$npm_prefix" ] && [ -w "$npm_prefix" ]; then
    return 0
  fi

  local user_prefix="$HOME/.npm-global"
  echo "🔧 Configuring user-writable npm prefix: ${user_prefix}"
  mkdir -p "$user_prefix"
  npm config set prefix "$user_prefix"
  ensure_npm_prefix_bin_on_path
  npm_prefix="$(npm config get prefix 2>/dev/null || true)"
  [ -n "$npm_prefix" ] && [ -w "$npm_prefix" ]
}

install_global_npm_package() {
  local package_name="$1"
  local npm_prefix

  ensure_user_writable_npm_prefix || true
  npm_prefix="$(npm config get prefix 2>/dev/null || true)"
  if [ -n "$npm_prefix" ] && [ -w "$npm_prefix" ]; then
    npm install -g "$package_name"
    ensure_npm_prefix_bin_on_path
    return 0
  fi

  if ask_permission "Install npm package '${package_name}' globally with sudo? (prefix: ${npm_prefix:-unknown})" "ALLOW_SUDO"; then
    sudo_cmd npm install -g "$package_name"
    ensure_npm_prefix_bin_on_path
    return 0
  fi

  echo "❌ Cannot install '${package_name}' globally: npm prefix '${npm_prefix}' is not writable."
  echo "   Fix prefix manually (npm config set prefix \"\$HOME/.npm-global\") or re-run with ALLOW_SUDO=yes."
  exit 1
}

ensure_npm_prefix_bin_on_path() {
  local npm_prefix
  local npm_bin_dir
  npm_prefix="$(npm config get prefix 2>/dev/null || true)"
  npm_bin_dir="${npm_prefix}/bin"

  # Some npm prefix setups (common fix for EACCES) install CLIs into a user dir
  # like "$HOME/.npm-global/bin". Make sure it's reachable for later steps.
  if [ -d "$npm_bin_dir" ] && [[ ":$PATH:" != *":$npm_bin_dir:"* ]]; then
    export PATH="${npm_bin_dir}:$PATH"
  fi
}

qmd_docs_have_markdown() {
  [[ -d docs ]] && find docs -type f -name '*.md' -print -quit | grep -q .
}

PROJECT_SLUG="$(basename "$PWD" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-')"
PROJECT_SLUG="${PROJECT_SLUG%-}"
QMD_COLLECTION="${PROJECT_SLUG:-project}-docs"

export NODE_NO_WARNINGS=1
ensure_node_npm
ensure_npm_prefix_bin_on_path

if ! command -v qmd &> /dev/null; then
  echo "📦 Installing QMD globally..."
  install_global_npm_package @tobilu/qmd
else
  echo "✅ QMD already installed."
fi

# Antigravity CLI (agy) must already be installed — verified in require_agent_installed.
if [[ "$AGENT" == "antigravity" ]]; then
  ensure_local_bin_on_path
  require_command agy "Install Antigravity CLI first: curl -fsSL https://antigravity.google/cli/install.sh | bash"
fi

if [[ ! -d docs ]]; then
  echo "📂 No docs/ directory found. Create one?"
  select yn in "Yes" "No"; do
    case $yn in
      Yes) mkdir -p docs; echo "➡️ Created docs/ directory."; break ;;
      No)  echo "⏭️ Skipping docs creation."; break ;;
    esac
  done
fi

if [[ -d docs ]]; then
  if ! qmd collection list 2>/dev/null | grep -Eq "(^|[[:space:]])${QMD_COLLECTION}([[:space:]]|$)"; then
    echo "📚 Adding docs/ as QMD collection '${QMD_COLLECTION}'..."
    qmd collection add ./docs --name "$QMD_COLLECTION" --mask "**/*.md"
    echo "📝 Adding context for collection '${QMD_COLLECTION}'..."
    qmd context add "qmd://${QMD_COLLECTION}" "Project documentation and notes"
  else
    echo "✅ QMD collection '${QMD_COLLECTION}' already exists."
  fi

  if qmd_docs_have_markdown; then
    echo "🔄 Updating '${QMD_COLLECTION}' for semantic search..."
    qmd_path_prefix=""
    if [[ -x /usr/bin/node ]] && /usr/bin/node -p 'process.versions.node.split(".")[0]' 2>/dev/null | grep -qE '^2[2-9]|[3-9][0-9]'; then
      qmd_path_prefix="PATH=/usr/bin:"
    fi
    PATH="${qmd_path_prefix}${PATH}" qmd update
    PATH="${qmd_path_prefix}${PATH}" qmd embed
  else
    echo "⚠️ No markdown under docs/ yet. Skipping embed."
    echo "   When docs exist, run: qmd update && qmd embed"
  fi
fi

HOOK_FILE=".git/hooks/post-commit"
if [[ -d .git ]]; then
  echo "🔧 Setting up Git hook for QMD re-embedding..."
  mkdir -p .git/hooks
  cat << EOF > "$HOOK_FILE"
#!/bin/sh
# Auto re-embed docs with QMD after each commit (${QMD_COLLECTION})
if command -v qmd >/dev/null 2>&1; then
  if [ -d "docs" ] && find docs -type f -name '*.md' -print -quit | grep -q .; then
    if [ -x /usr/bin/node ]; then
      export PATH="/usr/bin:\$PATH"
    fi
    echo "🔄 Updating QMD collection '${QMD_COLLECTION}' and embeddings..."
    qmd update
    qmd embed
  fi
fi
EOF
  chmod +x "$HOOK_FILE"
  echo "✅ Git hook installed: .git/hooks/post-commit"
else
  echo "⚠️ No .git directory found. Skipping Git hook setup."
fi

# -------------------------------
# Caveman skill
# -------------------------------

echo ""
echo "📁 Setting up Caveman skill..."

SKILL_DIR="$HOME/.agents/skills/caveman"
if [[ -d "$SKILL_DIR" ]]; then
  echo "✅ Caveman already installed ($SKILL_DIR)."
else
  echo "➡️ Adding Caveman skill for $AGENT..."
  npx skills add JuliusBrussee/caveman -a "$AGENT" -y 2>/dev/null || npx skills add JuliusBrussee/caveman -a "$AGENT"
fi

# -------------------------------
# Graphify (optional)
# -------------------------------

GRAPHIFY_ENABLED="no"
if [[ -n "${ENABLE_GRAPHIFY:-}" ]]; then
  GRAPHIFY_ENABLED="${ENABLE_GRAPHIFY}"
  echo "Using ENABLE_GRAPHIFY=${ENABLE_GRAPHIFY} from environment."
else
  echo "Install Graphify? (knowledge graph over code/docs; uses pipx on Debian/WSL)"
  select GRAPHIFY_CHOICE in "No" "Yes"; do
    case "$GRAPHIFY_CHOICE" in
      Yes) GRAPHIFY_ENABLED="yes"; break ;;
      No)  GRAPHIFY_ENABLED="no"; break ;;
    esac
  done
fi

GRAPHIFY_AGENTS_SNIPPET=""
ensure_python_for_graphify() {
  # Graphify requires Python 3.10+. We only check that python3 exists and try; pip will fail if version is too old.
  command -v python3 >/dev/null 2>&1
}

apt_install_packages() {
  local packages=("$@")
  if ! command -v apt-get &> /dev/null; then
    return 1
  fi
  if ! ask_permission "Install apt packages via sudo: ${packages[*]}?" "INSTALL_APT_PACKAGES"; then
    echo "⏭️ Skipping apt install: ${packages[*]}"
    return 1
  fi
  sudo_cmd apt-get update
  sudo_cmd apt-get install -y "${packages[@]}"
}

ensure_pipx() {
  if command -v pipx &> /dev/null; then
    return 0
  fi
  echo "📦 pipx not found; installing (recommended for Graphify on PEP 668 / Debian Python)..."
  apt_install_packages pipx || return 1
  command -v pipx &> /dev/null
}

write_cursor_graphify_rule() {
  [[ "$AGENT" == "cursor" ]] || return 0
  local rules_dir="$HOME/.cursor/rules"
  local rule_file="$rules_dir/graphify.mdc"
  mkdir -p "$rules_dir"
  echo "📝 Writing Cursor rule: $rule_file (Graphify)"
  cat > "$rule_file" << EOF
---
description: Graphify integration defaults (knowledge graph)
alwaysApply: true
---

## Graphify (knowledge graph)

- Build once per codebase: \`graphify .\` → \`graphify-out/graph.json\`
- Query relationships:
  - \`graphify query "<question>"\`
  - \`graphify path "<From>" "<To>"\`
  - \`graphify explain "<Node>"\`

When asked about how modules/files/definitions relate, prefer Graphify (graph queries) over grepping for ad-hoc answers.
EOF
}

install_graphify_cli() {
  # PyPI package is graphifyy; CLI command is graphify.
  if command -v graphify &> /dev/null; then
    echo "✅ Graphify already present: $(command -v graphify)"
    return 0
  fi

  ensure_local_bin_on_path

  if ensure_pipx; then
    echo "📦 Installing Graphify via pipx (graphifyy)..."
    if pipx install graphifyy; then
      return 0
    fi
    echo "⚠️ pipx install failed; trying pipx upgrade..."
    pipx upgrade graphifyy 2>/dev/null && return 0
  fi

  if command -v uv &> /dev/null; then
    echo "📦 Installing Graphify via uv tool (graphifyy)..."
    uv tool install graphifyy && return 0
  fi

  # Last resort: plain pip only when the environment is not PEP 668–managed.
  if python3 -m pip --version >/dev/null 2>&1; then
    echo "📦 Installing Graphify via pip --user (graphifyy)..."
    if python3 -m pip install --user --upgrade graphifyy 2>/dev/null; then
      return 0
    fi
  fi

  echo "⚠️ Failed to install graphifyy."
  echo "   On Debian/Ubuntu/WSL, install pipx and retry: sudo apt install pipx && pipx install graphifyy"
  return 1
}

install_graphify() {
  if ! ensure_python_for_graphify; then
    echo "⚠️ Python3 not found; skipping Graphify installation."
    return 0
  fi

  if ! install_graphify_cli; then
    echo "⚠️ Skipping Graphify."
    return 0
  fi

  ensure_local_bin_on_path
  if ! command -v graphify &> /dev/null; then
    echo "⚠️ graphify not on PATH after install. Add ~/.local/bin to PATH and re-run."
    return 0
  fi

  echo "🔧 Running: graphify install"
  graphify install || echo "⚠️ graphify install failed; you can re-run manually later."

  if [[ "$AGENT" == "cursor" ]]; then
    echo "🔧 Configuring Cursor integration: graphify cursor install"
    graphify cursor install || echo "⚠️ graphify cursor install failed; check Cursor rule manually."
    write_cursor_graphify_rule
  fi
}

if [[ "$GRAPHIFY_ENABLED" == "yes" ]]; then
  echo ""
  echo "📁 Setting up Graphify..."
  install_graphify
  GRAPHIFY_AGENTS_SNIPPET=$'- **Graphify**  \n  Local knowledge graph over code/docs/media. Build once with `graphify .` (writes `graphify-out/graph.json`) then ask `graphify query` / `graphify path` about relationships. (Cursor: rule enabled via `.cursor/rules/graphify.mdc`.)\n'
else
  echo ""
  echo "⏭️ Skipping Graphify installation."
fi

write_cursor_compression_rule

# -------------------------------
# GEMINI.md / AGENTS.md
# -------------------------------

write_agents_compression_section() {
  local target="$1"
  if [[ "$AGENT" == "antigravity" ]]; then
    cat << EOF >> "$target"

## Compression Utilities

The following utilities are available in this environment. Agents should consider them core tools and utilize them when possible to optimize context, memory, and token usage.

- **RTK**  
  Token-compression CLI proxy (60-90% savings). Configured locally in this project workspace (no global flag).

- **ICM**  
  Permanent cross-tool memory (SQLite). Stored globally at \`~/.gemini\` and automatically hooked into the agent to recall/store context.

- **Caveman**  
  Skill at \`~/.agents/skills/caveman\` (or \`~/.gemini/skills/\`). Default reply compression: **${CAVEMAN_LEVEL}** for concise, direct responses.

- **QMD**  
  Semantic search over \`docs/**\`. Collection: \`${QMD_COLLECTION}\` → \`qmd://${QMD_COLLECTION}\`. Prefer \`qmd search\` / \`qmd query -c ${QMD_COLLECTION}\` before bulk \`.md\` reads.

${GRAPHIFY_AGENTS_SNIPPET}
---

## Antigravity CLI & Workspace Guidelines

- **Workspace Rules (\`GEMINI.md\` / \`AGENTS.md\`)**: The agent automatically consults rules defined in the workspace root on startup.
- **Context Control**: Proactively use \`@\` to import specific file paths in prompts to minimize token overhead.
- **Execution Flow**: Follow the autonomous loop: **Exploration** (codebase research) → **Planning** (draft plan) → **Execution** (make changes).
- **Terminal Sandbox**: Shell commands run in a secure terminal sandbox. Safety boundaries can be tuned in \`~/.gemini/antigravity-cli/settings.json\`.
EOF
  else
    cat << EOF >> "$target"

## Compression Utilities

The following utilities are available in this environment. Agents should consider them core tools and utilize them when possible to optimize context, memory, and token usage.

- **RTK**  
  Global utility for compressing CLI outputs before they reach the agent. Cursor: \`rtk hook cursor\` on Shell (via \`rtk init --agent cursor\`).

- **ICM**  
  Permanent cross-tool memory (SQLite). **Cursor:** MCP (\`~/.cursor/mcp.json\`) + rule (\`~/.cursor/rules/icm.mdc\`) — use \`icm_memory_recall\` / \`icm_memory_store\` or \`icm recall\` / \`icm store\`. Hooks (auto-extract) apply to Claude Code / Gemini / Codex, not Cursor.

- **Caveman**  
  Skill at \`~/.agents/skills/caveman\`. Default reply compression: **${CAVEMAN_LEVEL}** (see \`~/.cursor/rules/compression.mdc\` on Cursor).

- **QMD**  
  Semantic search over \`docs/**\`. Collection: \`${QMD_COLLECTION}\` → \`qmd://${QMD_COLLECTION}\`. Prefer \`qmd search\` / \`qmd query -c ${QMD_COLLECTION}\` before bulk \`.md\` reads.

${GRAPHIFY_AGENTS_SNIPPET}
---

## Usage Notes

- Use QMD for project documentation; RTK for heavy Shell output; ICM for decisions/errors across sessions.
- QMD embeddings refresh via \`.git/hooks/post-commit\` when \`docs/**\` markdown changes.
- After adding docs, run: \`qmd update && qmd embed\`
EOF
  fi
}

RULE_FILE="AGENTS.md"
if [[ -f "GEMINI.md" ]]; then
  RULE_FILE="GEMINI.md"
elif [[ "$AGENT" == "antigravity" ]]; then
  RULE_FILE="GEMINI.md"
fi

if [[ ! -f "$RULE_FILE" ]]; then
  echo "📄 Creating $RULE_FILE..."
  {
    echo "# $RULE_FILE"
    echo ""
  } > "$RULE_FILE"
  write_agents_compression_section "$RULE_FILE"
elif ! grep -q "## Compression Utilities" "$RULE_FILE"; then
  echo "📄 Appending compression section to $RULE_FILE..."
  write_agents_compression_section "$RULE_FILE"
elif grep -q "^- RTK$" "$RULE_FILE" 2>/dev/null || grep -q "^- ICM$" "$RULE_FILE" 2>/dev/null; then
  echo "📄 Upgrading minimal Compression Utilities section in $RULE_FILE..."
  # Replace minimal 4-bullet block with full section (best-effort).
  awk '
    /^## Compression Utilities/ { skip=1; next }
    skip && /^## / { skip=0 }
    skip && /^---/ { next }
    skip && /^$/ { next }
    skip && /^- / { next }
    skip && /^$/ { next }
    !skip { print }
  ' "$RULE_FILE" > "${RULE_FILE}.tmp" && mv "${RULE_FILE}.tmp" "$RULE_FILE"
  write_agents_compression_section "$RULE_FILE"
else
  echo "✅ $RULE_FILE already has a Compression Utilities section."
fi

# -------------------------------
# Summary
# -------------------------------

echo ""
echo "🎉 Setup complete for agent: ${AGENT}"
echo "   QMD collection: ${QMD_COLLECTION} (qmd://${QMD_COLLECTION})"
echo ""

if command -v qmd &> /dev/null; then
  echo "📊 QMD status:"
  qmd status 2>&1 | sed 's/^/   /' || true
  if qmd status 2>&1 | grep -qi "pending\|0 embedded\|need embedding"; then
    echo "   👉 Run: qmd update && qmd embed"
  fi
  echo ""
fi

if [[ "$ENABLE_ICM" == "yes" ]] && command -v icm &> /dev/null; then
  echo "📊 ICM doctor (integration health):"
  icm doctor 2>&1 | sed 's/^/   /' || true
  echo ""
fi

if [[ "$AGENT" == "cursor" ]]; then
  echo "Next steps for Cursor / Cursor CLI:"
  echo "  1. Restart Cursor so MCP picks up ~/.cursor/mcp.json (icm serve)."
  echo "  2. Allow Shell(rtk), Shell(icm), Shell(qmd) in ~/.cursor/cli-config.json if using allowlist mode."
  echo "  3. Verify: icm recall \"project setup\"  |  qmd search \"topic\" -c ${QMD_COLLECTION}"
  if [[ "$GRAPHIFY_ENABLED" == "yes" ]]; then
    echo "  4. (Optional) Build Graphify graph: graphify ."
  fi
fi
