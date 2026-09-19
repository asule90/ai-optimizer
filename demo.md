- start video record
- `dco run --rm --service-ports setup-test`
- cd [lang]-project
- run `setup.sh`
- enter agent cli
- check mcp list
- `/run-everything` to speed up demo
- init project
- check ~/.local directory containing icm cache
- Next steps for Cursor / Cursor CLI:
  1. Allow Shell(rtk) in ~/.cursor/cli-config.json if using allowlist mode.
  2. Verify ICM: icm recall "project setup"
  3. Build graph if needed: `graphify .`  → then verify MCP tool query_graph