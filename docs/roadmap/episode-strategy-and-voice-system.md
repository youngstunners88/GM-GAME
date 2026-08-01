# Episode strategy + Lil Blunt voice system

Status: architecture note (roadmap), not an ADR — no binding engine
decision is made here beyond naming/placement conventions for future work.
Written per the founder's Layer Strategy prompt (2026-08-04) so any agent
picking up Episode 2 or voice work starts from the same picture.

## Coach frame (why this doc exists)

Build at the right layer of abstraction:
- **Layer 1 — Book**: same experience for everyone; easy to copy.
- **Layer 2 — Movie**: context-specific flows (this project's data, brand,
  process).
- **Layer 3 — Video game**: systems that respond to *this* player; hard to
  replicate; where durable value lives.

Do not invest in Layer-1 duplicates (generic chatbot, generic meme mint,
generic social spam) when Layer 2/3 work is available instead.

## Episode map (canonical)

| | **Episode 1 (now)** | **Episode 2 (roadmap)** |
|--|---|---|
| Content | All three stages already built (Smoke Realm, Crystal Caverns, Gold Rush) + Blaze Rush + current bosses | Next quest arc / new sections |
| Lead character | Lil Blunt only, playable protagonist | Lil Blunt still protagonist |
| Guest / meme characters | None | Companions/cameos in specific sections (Pepe-adjacent, Doge/Shiba energy, BONK, CashCat, Floki, Pulse Teddy, etc.) — **not** co-protagonists |
| Lil Blunt voice | Yes — all episodes | Yes — all episodes |
| Goal | Solid, shareable Layer 1 + start Layer 2/3 hooks | Attention + deeper Layer 3 (guests, new sinks, richer companion memory) |

**Rule:** Episode 2 guests never replace Lil Blunt's identity. They appear
in his world for marketing and variety, and (per the source prompt) may get
their own short reacts later — they do not take over the companion-
conversation slot unless a future design explicitly adds a second voice
channel.

Episode 1 = the currently shipped/in-PR game (this PR, #12). Episode 1
residual polish (torch, stomp, chase feel, Level 3 ladder — see
`docs/session-logs/2026-08-03-residuals-torch-stomp-chase-ladder.md`) is
Episode 1 work, not Episode 2.

## Lil Blunt voice system (complete definition)

"Voice" on this project is not "play a random TTS line." It has two
channels:

### A. Companion conversation (Layer 3, later)

Player can talk with Lil Blunt (mic and/or text) during play / Lounge /
safe hubs. He answers in character, aware of live game state (below).
Architecture target: a realtime STT→LLM→TTS shell (StreamCore or
equivalent) with ElevenLabs as the TTS voice for consistency. Graceful
degradation: voice server down → text subtitle / silence; game stays fully
playable. **Not built this session** — deferred by design until Episode 1
residuals allow the effort.

### B. Action onomatopoeia / reactive VO (Layer 1-2, ships earlier)

Short, punchy vocalizations on *pronounced* actions only. Pre-baked/
low-latency clips triggered from game events. Ships without the full
conversational backend — this is the part that's actually feasible in
Episode 1's current architecture.

**Do not** VO every coin, footstep, or UI click — only readable, emotional
moments.

### Personality constraints

Friendly, optimistic, chill, protective of community. Stoner-adjacent humor
without blocking accessibility (subtitles always available). Never invents
financial promises or "guaranteed gains."

### Tech placement

| Piece | Tooling | Layer |
|---|---|---|
| Character voice quality | ElevenLabs (primary) | Book→Movie voice asset |
| Local clone experiments | Audio8, staging only | Lab |
| Live talk + barge-in | StreamCore (or equiv.) + game-state tools | Layer 3 shell |
| Action onomatopoeia | Event hooks → short clips via existing `AudioManager.play_voice()` | Episode 1 capable |
| Subtitles / accessibility | Always on for spoken lines | Required |

**The Godot client never holds provider API keys** — a voice server/worker
owns them, same rule as the rest of this project's key handling.

## Action VO hook inventory (names only — no synthesis this session)

`AudioManager.play_voice(name: String)` already exists (used today for
`stage1_intro`, `boss1_intro`, `victory`, etc.) — single-slot, ducks music,
plays over `SFX` bus. It's a **single active voice line at a time**: a new
call cuts off whatever's playing. That's a feature for barks, not a bug —
readability of the newest, most relevant reaction beats letting two lines
overlap into mush.

Proposed hook names (call sites TBD, no wiring done this session):

| Event | Hook name (`play_voice(...)`) | Notes |
|---|---|---|
| Hurt / damage taken | `hurt_light` | Short "ow"/wince. Fires from `Player.take_damage()`. Must not spam on multi-hit frames — same debounce pattern `hurt`/damage-flicker already uses. |
| Death / last hit | `hurt_death` | Distinct line from `hurt_light`, not a louder version of it. |
| Attack — axe/throw connects | `attack_excite` | Only on a **connecting** throw, not every button press — ties to the existing hit-confirm path, not the input event. |
| Jump / big landing (optional) | `land_big` | Only wire if it reads clearly over landing SFX; skip if noisy — matches the source prompt's own caveat. |
| Collect major token/power-up | `collect_major` | Blaze/Big/Diamond pickups, not regular coins. |
| Boss phase / big success | `boss_hype` | Rare — phase-up or boss kill only. |
| Climb start / ladder top (optional) | `climb_start` | Only if it doesn't spam on short repeated climbs. |

No ElevenLabs batch generation happens from this doc alone — scope this to
a future session once the founder expands scope, per the source prompt's
explicit "no asset generation... unless founder expands scope."

## Companion state API sketch (read-only fields, for future StreamCore work)

When Lil Blunt speaks as companion, the LLM/tool layer needs read access to
at least:

- `level_id` / `stage_number` (current level/stage/episode)
- `progress_phase` — early / mid / boss arena (derivable from boss-trigger
  state already tracked per level, e.g. `_boss_arena_active`)
- `recent_outcome` — last death, boss damage dealt, soft-lock risk if
  detectable
- `active_power_ups` — Blaze / Big / Diamond etc. (already tracked in
  `GameManager`), **without leaking spoilers** the player hasn't earned yet
- `in_blaze_rush: bool` — main campaign vs. the secret bonus mode
- Simple flags: `first_run`, `returned_from_blaze_rush`, `low_lives`

Safe tool surface: **read-only** game state only. No wallet keys, no
private credentials, no silent on-chain actions triggered from voice. This
sketch is not an implementation — no StreamCore deploy, no live tool
wiring — it exists so a future session knows what fields to expose without
re-deriving the list from scratch.

## Layer placement of other roadmap pieces

| Feature | Layer | Rule |
|---|---|---|
| Solid 3-stage play, mobile, bosses, Blaze Rush exit | 1 | Finish residuals; give away great free play |
| AgentMail + Agent-Reach listen | 2 | Marketing flow; Reach stays read-only |
| PostHog / Sentry → balance decisions | 2→3 | Data that improves *this* game |
| Scoreboard / ICP identity | 2-3 | Compound progress specific to this project's rails |
| NFT burn sinks (boosts, routes, seasons) | 3 | Utility inside this loop; ICP-first |
| Meme guests | 2 discovery + Episode 2 content | Cameos only; original art; no third-party IP mint |
| Generic "AI posts on X" | Book trap | Do not build |
| Generic chatbot with no game state | Book trap | Do not build |

## Non-goals for this session

No Episode 2 guest implementation, no live StreamCore deploy, no NFT
contract deploy, no Audio8 synthesis, no ElevenLabs batch generation. This
doc is the reference point for when the founder expands scope on any of
those.
