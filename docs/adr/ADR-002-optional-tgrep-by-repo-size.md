# ADR-002: Optional tgrep install with repo-size guidance

## Status

Accepted

## Context

The AI optimizer stack (RTK, ICM/Mem0, QMD/Graphify) already covers token compression, memory, and structured context. [microsoft/tgrep](https://github.com/microsoft/tgrep) adds trigram-indexed regex search with an optional server — valuable on large trees where ripgrep scans every file per query, but unnecessary overhead on small repos (index build, `.tgrep/` storage, optional background `serve`).

Users asked to adopt tgrep in `setup.sh` without making it mandatory or displacing the existing docs/memory choices.

## Decision

1. Add an **optional** post-setup step in `setup.sh` (orthogonal to `DOCS_TOOL` and `MEMORY_TOOL`).
2. **Estimate file count** (`git ls-files` when in a git repo; otherwise a pruned `find`) and print size hints:
   - &lt; 3,000 files — small; ripgrep usually sufficient
   - 3,000–9,999 — medium; optional benefit
   - ≥ 10,000 — large; tgrep often worth it
3. **User choice** via interactive prompt or `INSTALL_TGREP=yes|no` (non-interactive defaults to skip unless `INSTALL_TGREP=yes`).
4. **Install order**: existing `tgrep` → Homebrew → GitHub Release binary (`gh` or curl + API) → optional `cargo install`.
5. On success: append `.tgrep/` to `.gitignore`, write `~/.cursor/rules/tgrep.mdc`, extend `compression.mdc` and `AGENTS.md`, optional `BUILD_TGREP_INDEX` / `TGREP_START_SERVE`.

```
setup.sh flow (tgrep)
─────────────────────
RTK + memory + docs tool
        │
        ▼
estimate_searchable_file_count → size hint
        │
        ▼
INSTALL_TGREP / prompt ──no──► skip
        │
       yes
        ▼
install_tgrep_cli → gitignore → rules → optional index/serve
```

## Consequences

- **Pros**: Large monorepo users get a guided path to faster agent grep without changing QMD vs Graphify semantics; small projects are nudged toward skipping.
- **Cons**: File count is approximate (tracked files only in git repos understates untracked trees); background `serve` is opt-in only to avoid surprising long-lived processes in CI.
- **Ops**: Release install needs network; cargo fallback is slow and requires Rust.

## Related

- [tgrep AGENTS.md](https://github.com/microsoft/tgrep/blob/main/AGENTS.md)
- ADR-001 (Graphify setup hooks and MCP Python)
