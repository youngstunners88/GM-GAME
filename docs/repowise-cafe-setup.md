# Repowise + Claude Code (Cafe / Mobile Workflow)

You mostly work from mobile. When you get a computer (internet cafe or otherwise), use this card.

## Goal

Give Claude Code a local codebase index so it stops re-grepping the whole repo every task.

## One-time per machine (5–10 min)

```bash
# 1. Install (needs Python 3.11+)
pip install repowise

# 2. From the GM-GAME root
cd /path/to/GM-GAME

# 3. Build index — NO API key required
repowise init --no-prose -y

# 4. Confirm Claude Code can see the MCP server
claude mcp list
```

Project MCP config is already committed in `.mcp.json`:

```json
{
  "mcpServers": {
    "repowise": {
      "command": "repowise",
      "args": ["mcp"]
    }
  }
}
```

Claude Code reads that automatically when you open the repo.

## Every cafe session (30 seconds)

```bash
cd /path/to/GM-GAME
git pull

# If the index is missing or very stale:
repowise init --no-prose -y
# or just:
repowise update
```

Then start Claude Code as usual. It will spawn `repowise mcp` via stdio.

## What Claude can call

Useful tools once the MCP is live:

| Tool | Use when |
|------|----------|
| `get_overview` | First look at architecture / hotspots |
| `get_context` | Before editing a file or system |
| `get_risk` | Before changing something important |
| `get_why` | Before structural changes |
| `search_codebase` | Finding symbols / concepts |
| `get_health` | Finding risky or messy files |

## Mobile reality

- The index (`.repowise/`) is **local**. It does not live in git and is not on your phone.
- You cannot usefully run the MCP from pure mobile.
- On mobile, keep using Claude Code + your existing skills (`smoke-realm-architect`, manifests, etc.).
- On a computer, the MCP becomes the fast context layer on top of those skills.

## If the cafe PC has no Python / pip

```bash
# Quick path on many Linux cafe machines
python3 -m pip install --user repowise
export PATH="$HOME/.local/bin:$PATH"
repowise --version
```

If you cannot install anything, skip Repowise for that session and work with the normal Claude Code + skill stack.

## Do not commit

Never commit `.repowise/`. It is machine-local and regenerable.
