# LEVEL DEPTH — Task #23 as a Value-Stack Play

Level depth reframed per the coach's framework: these are not "more
platforming" (📖 Book Layer) — every mechanic either **learns from player
data** (🎮 Video Game Layer) or **bakes in SmokeRing domain knowledge**
(🎬 Movie Layer). Companion docs: `LAYER_SHIFT.md` (the framework),
`AGENTMAIL_SETUP.md` (where the same data feeds email).

**Additive only:** wallet connect, the Oracle handler, AgentMail engine, CI,
and the security model are untouched. Everything below degrades gracefully —
no backend/wallet means the authored Book-Layer level, exactly as shipped.

---

## Feature → layer map

| Feature | Layer | Why it can't be commoditized |
|---|---|---|
| **Dynamic difficulty** (`src/autoload/difficulty_manager.gd`) | 🎮 Video Game | The level tunes itself from THIS player's death heatmap — invisible, per-player, data-fed. A copied level ships without the data loop. |
| **Secret walls** (`src/level/secret_wall.gd`) | 🎮 Video Game | Discovery surfaces COMMUNITY-submitted lore (served least-first, so it stays fresh), crypto Smoke Tips, referral codes; wallet holders find Diamond Shards (20%). The content compounds with the community. |
| **Ladders & one-way platforms** (`ladder.gd`, `one_way_platform.gd`) | 🎬 Movie | Standard mechanics, but PLACED with player psychology + our heatmap: ladders are escape routes out of the two deadliest pit approaches; one-ways build the risk/reward route split. |
| **Three routes per section** (Speedrunner / Casual / Explorer) | 🎬 Movie | Speedrunner: high one-way chain, coin-rich, runs past the flies. Casual: the authored ground route. Explorer: secret walls + Hall of Blaze. Route design = knowing what each player archetype wants. |
| **Token-gated boss phases** (`auditor.gd`) | 🎬 Movie | DIAMONDS → "Diamond Surge" (reflectable shards, skill-shot damage). GoldMine → "Gold Rush" (golden safe platforms at phase 3). SMOKE → Blaze lasts 2× in the fight. The fight LOOKS different for holders; non-holders get the exact shipped 3-phase fight, no penalty. |
| **Snapshot Moments** (`checkpoint.gd`) | 🎬 Movie | Section-end camera beat + F12/P share with a pre-filled X post — the level itself is a marketing surface. |
| **Hall of Blaze + graffiti wall** (`hall_of_blaze.gd`) | 🎬/🎮 | Token-gated easter room: top community lore painted in-world + weekly top-10 silhouettes from the backend. Community data becomes level dressing. |
| **Analytics pipeline** (`/event`, `/player-analytics`) | 🎮 Video Game | Every significant action feeds difficulty, the founder digest, and future Oracle context. The game improves from the data it generates. |

## Dynamic difficulty rules (invisible by design — no UI ever announces them)

| Signal (from `/player-analytics`) | Adjustment |
|---|---|
| Died to Tax Collector > 3× | Tax Collector patrol speed −15% |
| Died to boulders > 2× | 1-second smoke-puff warning before boulders roll |
| Avg completion time > 5 min | One extra mid-level checkpoint |
| Retry count > 10 | Hint Leaf spawns — touch it and the checkpoint route glows 5 s |

Flow: `LevelBase._ready()` → `DifficultyManager.refresh()` (async, non-blocking;
level starts with neutral defaults) → `tuning_ready` → retro-apply to live
enemies (per-enemy meta guard prevents double-scaling). Offline/new player →
all defaults → the authored level.

## Analytics schema (backend KV, all rate-limited per-IP)

**`POST /event`** `{player_id, event_type, event_data}` — allowed types:
`death` (`{enemy}` or `{obstacle}`), `level_complete` (`{seconds}`), `retry`,
`powerup_used`, `secret_found`, `boss_phase_reached`, `lore_read`,
`share_clicked`, `referral_code_used`. 120/min/IP; unknown types rejected.

Storage: `pstats:<player_id>` →
```json
{ "deaths_by_enemy": {"tax": 4}, "deaths_by_obstacle": {"pit": 2},
  "session_times": [312, 288], "retry_count": 11,
  "counters": {"secret_found": 3}, "updated_at": 0 }
```
90-day TTL; pseudonymous (client-generated random player id — no PII).
Weekly aggregates: `evtagg:<week>:<type>` counters (feed founder digest +
the Kimi realm-news blurb).

**`GET /player-analytics?player_id=`** → `{deaths_by_enemy, deaths_by_obstacle,
avg_completion_time, retry_count}` (30/min/IP).
**`GET /community-lore`** → least-served approved snippet, marked served
(30/min/IP). **`GET /hall-of-blaze`** → weekly top-10, truncated addresses.

Game-side emitters: `Web3Bridge.report_metric()` — deaths attributed via
`GameManager.last_damage_source` (stamped by enemies/hazards/boss) or the
active boss id; pit deaths as `{obstacle:"pit"}`; respawns fire `retry`;
`GameManager.activate_power_up` fires `powerup_used`; checkpoints fire
`share_clicked` on snapshot shares; secret walls fire `secret_found`/`lore_read`.

## Kimi K3 (OpenRouter) — the credit-efficiency layer

Verified live slug: **`moonshotai/kimi-k3`** (reasoning model — clients set
`reasoning: {effort:"low"}` and budget ≥1200 tokens or content comes back null;
both clients also fall back to the reasoning text).

| Use | Where | Cost shape |
|---|---|---|
| Support-triage LLM tier (Mistral → **Kimi** → Grok) | `backend/marketing.js::llmChat` | per support email, only when Mistral absent/down — today that makes Kimi the working primary |
| Weekly "realm news" digest blurb | `backend/marketing.js::weeklyDigests` | **1 call/week**, KV-cached, reused in every subscriber's email — never per-player |
| Pre-merge GDScript review | `scripts/kimi-review.sh [files|--changed]` | ~1 call/file, advisory; offloads first-pass review to cheap tokens |

Oracle NPC fallback was deliberately NOT wired: the `/oracle` handler is on
the do-not-touch list (constraints). Wiring Kimi behind it is a 5-line change
awaiting explicit approval.

Env: `OPENROUTER_API_KEY` (Worker secret + local env — **validated live**,
HTTP 200). Optional `KIMI_MODEL` override.

## New scenes / files

Game: `src/autoload/difficulty_manager.gd` (autoload), `src/level/secret_wall.*`,
`src/level/ladder.*`, `src/level/one_way_platform.*`, `src/level/hall_of_blaze.*`;
extended: `player.gd` (CLIMB state + death metrics), `auditor.gd` (token phases),
`checkpoint.gd` (snapshot), `level_base.gd` (tuning + hint leaf),
`level_01_smoke_realm.gd` (route placement), `enemy_base/tax_collector/
fly_swarm/rolling_boulder` (attribution + adaptive hooks), `project.godot`
(move_up/move_down actions, DifficultyManager autoload).
Backend: `kimi_client.js` + 4 routes in `marketing.js`.

## Privacy / security posture

Same rules as Section F/G of `GAME_SECURITY_CHECKLIST.md`: pseudonymous ids
only, per-IP rate limits on every new route, event-type allowlist, bounded
payload fields, 90-day TTL on per-player stats, no PII in any event. The
sentinel runs on every ship as always.
