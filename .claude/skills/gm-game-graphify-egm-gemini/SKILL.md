---
name: gm-game-graphify-egm-gemini
description: When and how to use the three tools the founder installed on 2026-11-03 - graphify (knowledge graph of code/docs), the EGM plugin (Elephant-Goldfish spec drafting + zero-context review) and the gemini-api CLI (Gemini text/image/TTS/video/analyze). TRIGGER on "graphify", "/graphify", "EGM", "elephant goldfish", "egm-draft/egm-review", "gemini-api", "use Gemini", or before a multi-system design (spec first) or a structural "what touches X across tools/docs" question.
---

# graphify · EGM · gemini-api (founder toolkit, 2026-11-03)

Installed by the founder's request ("leverage these tools moving on wherever there is a need"). None of them replaces a
gate, a test or live proof - they are aids. Claude still owns the diagnosis, the commit and every "FIXED" claim
(CLAUDE.md MODEL ROLE SPLIT).

## Install (a fresh cloud container loses them)
```bash
uv tool install graphifyy && graphify install          # CLI + the `graphify` skill in ~/.claude/skills
claude plugin marketplace add google/elephant-goldfish-model && claude plugin install egm@egm
# gemini-api: the upstream install.sh asks api.github.com for "latest", which the proxy refuses (403) -> pin the tag:
V=$(git ls-remote --tags https://github.com/google-gemini/gemini-api-cli.git | grep -oE 'v[0-9.]+$' | sort -V | tail -1)
curl -fsSL https://raw.githubusercontent.com/google-gemini/gemini-api-cli/main/scripts/install.sh -o /tmp/gi.sh
GEMINI_VERSION=$V GEMINI_INSTALL_DIR=$HOME/.local/bin bash /tmp/gi.sh
```
`GEMINI_API_KEY` comes from the environment's Environment Variables field. Never write a key into a file or command line.

## graphify - when it earns its cost
- **It does NOT parse GDScript.** Measured 2026-11-03: `graphify update src` extracted only the `.md` and `.py` files
  (92 md + 123 py nodes, zero `.gd`). For game code, `grep` + the context manifests stay the fast path.
- Use it for **`tools/` (Python Blender/forge pipelines), `scripts/` and the design/founder docs**, e.g.
  "which tool scripts touch the town kit?" or "which docs still describe X?" (stale-doc sweeps like the Gold Panner purge).
- Code extraction is free (AST, no LLM). Doc/image semantic extraction uses Gemini when `GEMINI_API_KEY` is set
  (it is - but see the free-tier limit below), otherwise the session itself.
- **Never write its output inside `src/`** - Godot would import `graphify-out/` into the pack. Run it from the repo root on
  a path outside `src/` (e.g. `graphify update tools`), and keep `graphify-out/` out of git (`.gitignore`).
- Then: `graphify query "<question>"`, `graphify affected "<node>"`, `graphify god-nodes`.

## EGM (Elephant-Goldfish Model) - spec before code
Skills: `egm:egm-brainstorm`, `egm:egm-draft`, `egm:egm-review`, `egm:egm-review-loop`, `egm:egm-resolve`, `egm:egm-drift-report`,
`egm:egm-bootstrap`.
- Use for a **multi-system feature that needs design decisions first** (a new chamber, a new economy path, a story-order
  change across several beats): `egm-draft` writes the spec with project context, `egm-review` stress-tests it with
  zero-context reviewers. The founder approves the trade-offs; then implement.
- **Not** for a clear bug fix or a founder doc that already locks the design (e.g. the 2026-11-03 license reframe: its text
  is the spec - implement it verbatim).
- `egm-drift-report` is a cheap way to check a design doc in `design/` against the code after a big change.
- `egm-bootstrap` writes README.md files across a subtree - do not run it over `src/` (the workspace CONTEXT.md files are
  the convention here; see `context-md-upkeep`).

## gemini-api - cheap second model / media
- `gemini-api analyze <file> "<question>"` - images, audio, video, PDFs (a cheap first read of a founder video or a stack of
  captures, like DeepSeek triage: **a lead, not a fact**).
- `gemini-api image`, `music`, `tts`, `video`, `generate`; add `--dry-run` to preview a call without spending.
- **Image generation is NOT available on the free tier** (measured 2026-11-03: `gemini-nano-banana-2.1`, `gemini-3.1-flash-image`,
  `gemini-3.1-flash-lite-image`, `gemini-3-pro-image` all answer `limit: 0` - "credits refreshed" does not change it; a paid tier
  does). For images use Muapi GPT Image 2 (`tools/ep2_film/muapi_film.py`, ~$0.06 per 1K image) - the license prints were made so.
- **Free tier text: 20 requests/day per model** (hit on 2026-11-03: `429 rate_limit_error`). Batch questions into one call;
  fall back to DeepSeek V4.1 Flash (`scripts/or-call.mjs`) for volume triage.
- Character voices stay on ElevenLabs (`scripts/generate-town-audio.mjs`) - never swap a cast voice to Gemini TTS.

## ElevenLabs keys (learned on the same turn)
Voices live on different accounts. `elevenlabs-client.mjs` reads `ELEVENLABS_API_KEY` (+ `ELEVENLABS_API_KEY_<n>`) unless
`ELEVENLABS_KEY_BINDING` names another variable. Measured 2026-11-03: Mike Dean (`CfxYdK3WmF3bmrvyLAiU`) is on
`ELEVENLABS_OPEN_API`, Inferno (`uWE48TmsTuIjyh2ifoNL`) on `ELEVENLABS_API`, Utah (`LeIvuXkiWRYkY1ThkAdG`) on `ELEVENLABS` (2026-11-04). Probe without printing a key:
`curl -s -o /dev/null -w "%{http_code}" -H "xi-api-key: ${!K}" https://api.elevenlabs.io/v1/voices/<id>` (200 = that key owns it), then
`ELEVENLABS_KEY_BINDING=<K> node scripts/generate-town-audio.mjs --generate --speakers <speaker>`.
