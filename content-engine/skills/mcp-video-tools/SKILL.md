---
name: mcp-video-tools
description: Wire FilmEra MCP, Browser Use MCP, video-use, jev-ultrafast, and openjev into production. Use when researching references, capturing web motion, or driving video tool APIs from Claude Code.
---

# MCP + video tools

## Add (once per machine)
```
claude mcp add --transport http filmera https://www.filmera.ai/api/mcp
claude mcp add browser-use -- uvx --from 'browser-use[cli]' browser-use --mcp
```

## Use
- FilmEra: generation / film tool surface when the MCP is live
- Browser Use: scrape public references, check LilBlunt.win and Gitbook copy,
  collect launch-page facts
- video-use / jev-ultrafast / openjev: prefer these over writing a new
  browser/video harness

## Rules
- Never paste API keys into markdown
- Prefer public pages already listed in CLAUDE.md
- Log MCP failures in STATUS.md instead of faking a render
- Run `/env-secrets-and-apis` (repo skill) before claiming a key is missing
