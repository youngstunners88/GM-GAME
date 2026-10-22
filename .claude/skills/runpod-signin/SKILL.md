---
name: runpod-signin
description: Connect the Runpod MCP server (plugin runpod@runpod) and list pods read-only. Covers the desktop-app OAuth failure "redirect_uri is not allowed", the terminal-CLI sign-in, and the API-key fallback. TRIGGER on "Runpod", "runpod MCP", "redirect_uri is not allowed", "Sign in with Runpod", "list my pods", "cloud GPU", or before any pod start/stop.
---

# Runpod sign-in (GM-GAME)

Companion to `ep2-cloud-gpu-runpod` (pod facts, cost rules). This skill only gets the MCP connected.

## Facts verified 2026-10-15
- Plugin installed from `runpod/runpod-plugins-official` (`claude plugin install runpod@runpod`, user scope, v1.7.2).
  Check: `claude plugin list | grep -A3 runpod@runpod` -> `Status: enabled`.
- MCP server: `https://mcp.getrunpod.io/` (HTTP, OAuth). Check: `claude mcp list | grep -i runpod`
  -> `! Needs authentication` until signed in.
- The guide `https://docs.runpod.io/agent-setup.md` uses OAuth only. It never uses an SSH key.
  An SSH key (`~/documents.pub`, comment `runpod`) is only for SSH into a pod; paste it in the Runpod console under SSH keys.

## The failure
`{"error":"invalid_request","error_description":"redirect_uri is not allowed. It must be a registered client callback or a loopback address."}`
with `redirect_uri=claude://claude.ai/mcp-auth-callback/sdk` means the sign-in was started from the
**Claude desktop app**. Runpod only accepts loopback (`http://localhost:PORT`) callbacks. Retrying in the
desktop app can never work. Do not retry it.

## Route A - terminal CLI (needs the founder's browser click)
1. Open a real terminal (not the desktop app) in the repo: `cd ~/Documents/GitHub/GM-GAME && claude`
2. First run only: answer the "new MCP servers found in this project" prompt (Enter = enable, Esc = reject).
3. `/mcp` -> `runpod` -> `Sign in with Runpod` -> approve in the browser. The browser must land on `http://localhost:...`.
4. Verify: `claude mcp list | grep -i runpod` should say `Connected`.

Driving this CLI by scripted keystrokes (tmux send-keys etc.) is blocked by the auto-mode classifier
("Tmux Self Drive"). Do not try to script it; ask the founder to do steps 2-3.

## Route B - API key (VERIFIED WORKING 2026-10-15; no browser)
1. Founder creates a **read-only** key in Runpod console -> Settings -> API Keys.
2. Founder pastes this in any terminal tab (hidden input, not in shell history, not in chat):
   `read -rsp "Runpod API key: " K; echo; claude mcp add --transport http runpod-key -s user https://mcp.getrunpod.io/ --header "Authorization: Bearer $K"; unset K`
3. Verify without printing the key: `claude mcp list | grep runpod-key` -> `Connected`.
4. A server added mid-session is NOT visible to the running session's tools. List pods through a fresh
   headless process: `claude -p "List my Runpod pods read-only using ONLY the runpod-key MCP server" --allowedTools "mcp__runpod-key"`
   (or restart the session). Never read the key out of ~/.claude.json to curl it yourself.
5. The unauthenticated `plugin:runpod:runpod` entry stays "Needs authentication"; ignore it, use `runpod-key`.

## Then
- List pods read-only through the runpod MCP tools. An empty list is a pass.
- Never start, stop, create or terminate a pod without asking the founder first - pods bill per hour.
- Spell it "Runpod" (one capital), not "RunPod".
