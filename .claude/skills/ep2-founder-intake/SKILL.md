---
name: ep2-founder-intake
description: Turn a founder feedback Google Doc (text + Drive images + meshy.ai share links) into references, assets, and a complaint ledger with proof — in one pass, without asking him again. TRIGGER when the founder pastes a docs.google.com link, drive.google.com file links or meshy.ai/s/ links, or says "improve your work" / "this is what I want it to look like" / "build the necessary skills for this".
---

# Why (2026-09-29)
Every founder doc so far was read once, half-acted-on, and re-sent angrier ("How could you possibly
believe this is acceptable!!!"). The doc IS the spec: each sentence is a defect or a target, each link
is a reference or an asset. Intake must be complete and mechanical so nothing is dropped.

# Steps
1. **Read the doc**: Drive MCP `read_file_content` (load with ToolSearch `select:mcp__Google_Drive__read_file_content`).
   The file id is in the URL between `/d/` and `/edit`. Copy it exactly (a mistyped id can still resolve).
2. **Split into a ledger** — one row per complaint / target / link. Create
   `docs/founder-feedback/<date>_<topic>.md`: `# | founder said (quote) | what was wrong (measured) | fix | proof`.
   Proof column starts empty; it is filled with a test name or a capture board (see reference-match-loop).
   A complaint with no proof is still open. Swearing is signal: it marks the priority order.
3. **Drive images** (`drive.google.com/file/d/<id>`): `download_file_content`. Results over ~1 MB are
   written to `…/tool-results/*.txt` (JSON `{content: base64}`); decode with PIL, never read them into context:
   `json.load(f)['content'] → base64.b64decode → Image.open → thumbnail(1800) → save`.
   Save to `artifacts/episode2-gold-mine/references/founder_<date>/REF_<what>.jpg`, then LOOK at each.
   Files > 10 MB return "too large": say so once, continue with what you have. Never use another
   tool's access token to fetch them.
4. **Meshy share links**: `python3 tools/meshy/pull_share.py <code> --remesh 25000 --name <n>`
   (share → task → remesh 5 cr → shrink → contact sheet in `.farm/share/<n>/`). LOOK at `sheet.png`.
   Baked-weapon character? → posed hero (`ep2-motion-emotion`). Multi-object scene? → k-means split
   (`ep2-meshy-studio`). Two tracks when the ask says three? → reject it and say why in the ledger.
5. **Classify each asset**: TARGET LOOK (what the whole frame must resemble) · POSE (character in a state)
   · SET PIECE (tunnel/rails) · ENEMY · ISOLATED REFERENCE (the founder's "if it helps" images).
   Only TARGET LOOK becomes the acceptance picture for the match loop.
6. **Install + gate**: put game-sized GLBs in `src/episode2/assets/` under a game name, record provenance in
   `founder_meshy_sources.json`, keep the web pack under 190 MiB (`scripts/ep2-local-export.sh` prints it).
7. **Close the ledger**: run `ep2-reference-match-loop` against the TARGET LOOK image; fill every Proof cell;
   only then say a complaint is fixed.

# Rules
- Never ask the founder to re-send a link or paste a key; every link above is fetchable here.
- Never quote a model's grade as fact — look at the board yourself.
- A founder-made model beats anything we generate. Use theirs first (`ep2-meshy-studio` rule zero).
- Add a REGRESSION TEST for each complaint that a machine can check (visible weapons, coin material, scale).
