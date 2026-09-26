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
  BROWSER_USE_API_KEY FIRECRAWL_API_KEY TINYFISH_API_KEY \
  FILMERA_API_KEY MONID_API_KEY B_AI_API_KEY \
  MINSTRAL_API_KEY MINSTRAL_API_KEY2 \
  POLYGRES_API_KEY TREQ_API_KEY \
  CLOUDFLARE_API_KEY2 ITCH_API_KEY BUTLER_API_KEY
do
  if [ -n "${!v}" ]; then echo "$v=set"; else echo "$v=missing"; fi
done
claude mcp list 2>/dev/null || true
```
