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
  3. Build graph if needed: `/graphify .`
  4. open file://wsl.localhost/Debian/home/sule/ASULE/repo/ai-optimizer/go-project/graphify-out/graph.html
  5. verify MCP tool query_graph: "Why does New() connect App HTTP Bootstrap to Clock Provider, Ping Feature Stack, Notifier Subscriber, Cobra Config Serve?"
  6. show `rtk gain`