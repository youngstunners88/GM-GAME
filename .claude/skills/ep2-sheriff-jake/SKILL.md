---
name: ep2-sheriff-jake
description: The GoldMine town's lawman and certificate minister (founder, 2026-10-14) - the founder's OWN Sheriff (weathered, grey-bearded, long coat, pipe) and Minister Mike Dean (robot-headed chibi in black clerical coat, cross pendant), who issues the certificate. JakeX was CANCELLED - never reintroduce him. Use for the certificate office, the witness, their models, voices and lines. (Skill name kept for routing; it covers both characters.)
---

# Cast lock (founder 2026-10-14: "replace JakeX with the sheriff I made ... The minister is Minister Mike Dean")

**JakeX / "Sheriff Jake" is cancelled.** No curly-haired child-face, no neon "jakeX" hatband, no cigarette. Any leftover `jake`
file, `vo_jake_*` id or `get_jake` is a bug - delete it.

| Who | Look (founder art: `artifacts/episode2-gold-mine/references/founder_2026-10-14_cast/`) | Role |
|---|---|---|
| **The Sheriff** | weathered older man, grey beard, wide-brim hat, scarf, star on a waistcoat, long dusty coat, gun belt, tall boots, **a pipe** with a curl of smoke | Greets Lil Blunt at the certificate office, lays out the rules, later the **witness** of the draw and the one who instructs both men to listen for the town bell / calls fair and square. Gruff, fair, few words. |
| **Minister Mike Dean** | small robot-headed chibi: blue-steel face, glowing orange eyes, red ear-cups, black flat-brim hat, black clerical coat, white collar, gold cross, robot hands. Real person behind him: Mike Dean, creator of titanxhub.com and a long-time TitanX proponent (x.com/MikeDeanLive). | Behind the certificate counter; **issues the certificate**, with the book open. Dignified, kind, a little ceremonial. |

Handle Minister Mike Dean respectfully: a tribute, never a joke at his expense. The Minister is a robot - no drug gags, no money
claims. Rules he states stay faithful to the GoldMine whitepaper (in your name, cannot be sold on, cannot be traded, bring your
share); **no invented numbers**; no wallet/contract addresses.

# Where it lives

- `src/episode2/chamber/gold_town.gd`: `SHERIFF_MODEL` / `MINISTER_MODEL` (`town/sheriff.glb`, `town/minister.glb`), `SHERIFF_HEIGHT`
  1.78, `MINISTER_HEIGHT` 1.5, `SHERIFF_OFFICE_AT`, `MINISTER_DESK`, getters `get_sheriff()` / `get_minister()`. Both are `Ep2TownFolk`
  (static model, bob/sway + baked arm poses - no rig).
- Office order: `vo_sheriff_1` -> `vo_lb_cert1` -> `vo_sheriff_2` (rules) -> look to the Minister -> `vo_minister_1` -> look back ->
  `vo_sheriff_3` (to the saloon). Draw: `vo_sheriff_witness/foul/lose/win`; the town bell is the sole draw signal.
- Town replacement voices: `.agents/skills/ep2-town-voices/SKILL.md` (offline bank + extras). Legacy non-town voices: ElevenLabs via `scripts/generate_audio.py` (see `ep2-voice-barks`); manifest ids in `assets/audio-manifest.json`.
  Re-encode to mono 64k; delete stray `*.mp3` the generator leaves outside `src/assets/sounds/voice/`.
- Models: founder art -> Tripo multiview (`muapi_3d.py run tripo3d-h31-multiview-to-3d`) -> `ep2-founder-model-bake` (T-pose arms
  lowered, decimate with UV delimit, 1K textures). Tripo characters face +X: check with `tools/ep2_shots/glb_preview.tscn`.
- Gate: `tests/ep2_gold_town_test.tscn`; look: `tools/ep2_shots/town_beats_shot.tscn` (shots 3, 3b, 3c).

# Rules

- The town has no bears and no Jake. Everyone in it is human or Minister Mike Dean.
- The Sheriff is an adult lawman; the pipe is a period prop with a thin smoke curl, never glamorised.
- Never put a real person's face on a model beyond the founder's own art.
