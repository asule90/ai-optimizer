# ADR-001: Graphify setup — git hooks and MCP Python resolution

## Status

Accepted

## Context

When `DOCS_TOOL=graphify`, `setup.sh` was incomplete in two ways:

1. **Git hooks** — QMD installs `.git/hooks/post-commit` directly, but Graphify setup only ran `graphify install` (global Claude skill) and `graphify cursor install` (Cursor rule). Graphify's post-commit hook lives behind a separate command: `graphify hook install`. Users expected automatic graph rebuilds after commits, mirroring QMD's embedding refresh.

2. **MCP failures** — `resolve_graphify_python()` returned the first Python where `import graphify` succeeded. On systems with `pip --user graphifyy` (no `[mcp]` extra) **and** a pipx install of `graphifyy[mcp]`, setup registered `/usr/bin/python3` in `~/.cursor/mcp.json`. That interpreter cannot `import graphify.serve` (missing `mcp` package), causing Cursor MCP errors:

```
ImportError: mcp not installed. Run: pip install "graphifyy[mcp]"
```

```
setup.sh flow (before)
──────────────────────
install_graphify_cli
  └─ ensure_graphify_mcp_extra (may fix pipx, but...)
resolve_graphify_python
  └─ picks system python3 (import graphify ✓, import graphify.serve ✗)
merge_graphify_into_cursor_mcp  →  MCP broken

setup.sh flow (after)
─────────────────────
install_graphify_cli
graphify hook install             →  post-commit rebuild
ensure_graphify_mcp_extra
resolve_graphify_python
  └─ prefers pipx/uv python with graphify.serve ✓
merge_graphify_into_cursor_mcp  →  MCP works
```

## Decision

1. Call `graphify hook install` from `setup_graphify()` when `.git` exists (same guard pattern as QMD).
2. Add `graphify_python_can_serve()` helper and rewrite `resolve_graphify_python()` to prefer interpreters that can `import graphify.serve` (pipx/uv venvs first, then graphify shebang companion, then system Python).
3. Call `ensure_graphify_mcp_extra` immediately before MCP registration and warn if the chosen interpreter still cannot serve.
4. Document post-commit hook behavior in README and AGENTS.md snippet.

## Consequences

**Positive**

- Graphify setup parity with QMD for git hook automation.
- MCP registration uses the correct isolated Python when pipx/uv `[mcp]` install exists alongside a bare `pip --user` graphifyy.
- Clear warning when no serve-capable interpreter is found.

**Trade-offs**

- `graphify hook install` appends to an existing `post-commit` hook if present (Graphify upstream behavior) — fine when switching from QMD is not supported (mutually exclusive tools).
- Fallback path still registers a non-serve Python if nothing else works; user sees explicit warning.

## Related

- `setup.sh` — `setup_graphify()`, `resolve_graphify_python()`, `graphify_python_can_serve()`
- [Graphify hooks reference](https://github.com/Graphify-Labs/graphify) — `graphify hook install`
- README — Choosing QMD vs Graphify, Graphify section
