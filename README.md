# AI Optimizer

## token compression

Run from a **project root** (repo with `.git`; the script will create `docs/` if missing):

```bash
cd /path/to/your-repo
bash ~/ASULE/repo/personal-workspace-setup/setup-ai-compression.sh
```

Non-interactive example (Cursor CLI):

```bash
AGENT=cursor ENABLE_ICM=yes CAVEMAN_LEVEL=lite bash setup-ai-compression.sh
```

| Tool | Cursor / Cursor CLI setup |
|------|---------------------------|
| RTK | `rtk init -g --agent cursor` → `~/.cursor/hooks.json` |
| ICM | `icm init --mode mcp` + `icm init --mode skill` → MCP + `~/.cursor/rules/icm.mdc` (not hooks) |
| Caveman | skill + `~/.cursor/rules/compression.mdc` (default: lite) |
| QMD | collection `<repo>-docs`, embed, `post-commit` hook |

See [ICM integrations](https://github.com/rtk-ai/icm/blob/main/docs/integrations.md) for per-agent details.

## How `setup-ai-compression.sh` works

At a high level, the script wires up four layers so your AI agent spends fewer tokens on noisy context and more tokens on the parts that matter:

1. Install/initialize **RTK**, so command output is compressed before it reaches the agent.
2. Optionally install/initialize **ICM** for persistent, cross-tool memory (Cursor uses MCP + rules; hooks are mainly for other agents).
3. Install **Caveman** and write a Cursor rule (`~/.cursor/rules/compression.mdc`) so replies follow a compact style.
4. Register `docs/**/*.md` with **QMD**, build embeddings (`qmd embed`), and keep them fresh via a `.git/hooks/post-commit` hook.

## How the 4 tools affect AI model work

`RTK` (token-efficient inputs)
: `rtk init -g --agent cursor` configures Cursor-side hooks (`~/.cursor/hooks.json`).
: Effect: large CLI/Shell outputs get compressed before the model sees them, reducing noise and token burn when you run commands locally.

`ICM` (cross-session memory)
: When `ENABLE_ICM=yes`, the script runs `icm init` in Cursor-specific modes:
: - `icm init --mode mcp` (exposes ICM via `~/.cursor/mcp.json`)
: - `icm init --mode skill` (adds the rule `~/.cursor/rules/icm.mdc`)
: Effect: the model can recall/store durable “decisions” and “context” across chats and tools (using `icm_memory_recall` / `icm_memory_store` or `icm recall` / `icm store`), instead of rediscovering the same info repeatedly.

`Caveman` (token-efficient outputs)
: The script writes the Cursor rule `~/.cursor/rules/compression.mdc` with a default reply style like `caveman lite` (controlled by `CAVEMAN_LEVEL`).
: Effect: the agent tends to answer in a tighter, lower-token format, while also steering the agent toward the “right” utilities (prefer `qmd search`, prefer `rtk read`, and avoid stacking redundant compression).

`QMD` (project grounding via semantic search)
: The script creates/registers a QMD collection named like `<repo>-docs` for `docs/` (mask `**/*.md`), then runs `qmd update` and `qmd embed` when markdown exists.
: It also installs a Git hook (`.git/hooks/post-commit`) so new/changed `docs/**/*.md` stays indexed.
: Effect: instead of pasting whole files into the model, you can use `qmd search` / `qmd query -c <collection>` to retrieve relevant doc snippets semantically—improving accuracy and lowering context size.
