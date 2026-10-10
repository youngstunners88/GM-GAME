---
name: gm-game-tool-roster
description: Always-on map of founder env keys, MCP, CLI. TRIGGER on any art, 3D, capture, voice, scrape, vote, deploy, Meshy, MuAPI, Episode 2. Read keys from the environment. Never print values. Never ask the founder to paste a key.
---

# Awareness

On session start, presence-check only (print set/missing, never the value):

```bash
for v in \
  OPENROUTER_API_KEY OPENROUTER_2 \
  TYPESAFE_API TYPESAFE_API_KEY \
  MESHY_API_KEY TRIPO_API_KEY RODIN_API_KEY HYPER3D_API_KEY \
  MUAPI_API_KEY PIXELLAB_SECRET \
  ELEVENLABS_API_KEY ELEVENLABS_API \
  BROWSER_USE_API_KEY FIRECRAWL FIRECRAWLAPIKEY FIRECRAWL_API_KEY TINYFISH_API_KEY \
  FILMERA_API_KEY MONID_API_KEY B_AI_API_KEY \
  MINSTRAL_API_KEY MINSTRAL_API_KEY2 \
  POLYGRES_API_KEY TREQ_API_KEY \
  CLOUDFLARE_API_KEY2 ITCH_API_KEY BUTLER_API_KEY
do
  if [ -n "${!v}" ]; then echo "$v=set"; else echo "$v=missing"; fi
done
claude mcp list 2>/dev/null || true
```

# CLIs and SDKs (founder's setup doc 2026-10-10, Drive "setup" 1JEYh3Un...) - installed and checked in this container

| tool | install | auth (env only, never print) | use for | status 2026-10-10 |
|---|---|---|---|---|
| `muapi` (Muapi CLI) | `pip install muapi-cli` (the npm package's binary download 404s) | `MUAPI_API_KEY` | `muapi run <model>`: images/video/audio; our scripted path is `tools/ep2_forge/muapi_ref.py` + `muapi_3d.py` | works |
| `monid` | `npm i -g @monid-ai/cli@latest` | `monid keys add --key "$MONID_API_KEY" --label env` once | `monid discover -q "<task>"` before writing any scraper / data fetch; it lists paid endpoints with prices | works; it does NOT reach Tripo Studio share links |
| `elevenlabs` | `npm i -g @elevenlabs/cli` (link `bin/cli.js` to `/opt/node22/bin/elevenlabs` if npm leaves no bin) | `ELEVENLABS_API_KEY` | agents/voices from the CLI; our SFX path stays `scripts/generate_audio.py` | installed |
| `tripo` | preinstalled | `TRIPO_API_KEY` | Tripo API tasks. **Studio share links (studio.tripo3d.ai/3d-model/...) are not API tasks**: ask for the GLB in Drive | works for API tasks |
| `firecrawl` | preinstalled | `FIRECRAWL_API_KEY` | scrape a page (the Firecrawl MCP here returned "Invalid token") | CLI present |
| browser-use / tinyfish | SDK (`pip install browser-use-sdk`, `tinyfish`) | `BROWSER_USE_API_KEY`, `TINYFISH_API_KEY` | remote browser agents | keys set, not wired |

Pairing rule (founder: "key tools that we can pair with Jev to improve the quality of our creativity"): a generator (Muapi / Tripo /
Blender / ElevenLabs) makes candidates -> we MEASURE them (`tools/ep2_forge/ref_metrics.py`, render brightness profiles, test gates)
-> Jev (`~typesafe/jev-latest`) and `microsoft/microsoft-decision-1` choose on the numbers (`node scripts/jev.mjs`) -> Astra reviews
the pictures. Worked examples: the woods light grade (both chose golden hour on a 12-number closeness table) and the rifle logo gate
(ring gone / no holes / not enlarged, both yes).
