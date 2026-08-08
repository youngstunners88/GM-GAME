# Analytics Event Schema — PostHog

**Status:** wired 2026-07-30. Web export only.
**Implementation:** `src/autoload/analytics.gd` (autoload `Analytics`).
**Config:** `config.json` → `analytics` block.

---

## The one design decision that matters

**We did not add new analytics call sites.** The game already had a complete
telemetry layer in `Web3Bridge`:

| Function | Purpose | Existing consumer |
|---|---|---|
| `track(event)` | UI / funnel clicks | backend `/track` |
| `report_event(event, data)` | Milestone events | backend `/events`, AgentMail digest |
| `report_metric(type, data)` | Granular gameplay metrics | backend `/event`, DifficultyManager |

All three already used a pseudonymous UUID, already queued offline, and
already avoided PII. Adding a parallel set of PostHog calls would have created
two event taxonomies that drift apart within a month.

Instead each of those three functions now calls `Analytics.capture(...)`.
**One list of events, two destinations.** Adding a new event anywhere in the
game automatically reaches PostHog with no extra wiring.

### Two subtleties worth knowing

1. **The capture fires BEFORE the `has_backend()` early-return.** The game's
   own backend is optional; if analytics sat behind that guard it would
   silently switch itself off whenever `backend_base_url` was unset — working
   in dev, dead in a deploy that didn't configure the backend.
2. **`track()` events are prefixed `ui_`.** `"level_complete"` exists both as a
   victory-screen *button click* (`track`) and as a real *level clear*
   (`report_metric`). Without the prefix those two collapse into one number
   and the funnel becomes meaningless.

---

## Events

Names are whitelisted to `^[a-z0-9_]+$` before reaching JS; anything else is
dropped silently.

### Gameplay milestones (`report_event`)
| Event | Properties | Fires when |
|---|---|---|
| `play_start` | — | PLAY or CONTINUE pressed |
| `boss_defeat` | `boss`, `score`, `first_time` | A boss dies |
| `wallet_connect` | — | Wallet connected from the menu |

### Granular metrics (`report_metric`)
| Event | Properties | Fires when |
|---|---|---|
| `death` | `obstacle` (e.g. `pit`) or boss id | Player dies |
| `level_complete` | `seconds` | Level cleared |
| `powerup_used` | `type` | Power-up consumed |
| `secret_found` | — | Secret wall broken |
| `boss_phase_reached` | `boss`, `phase` | Boss phase escalates |
| `retry` | — | Retry after death |
| `onboarding_viewed` / `onboarding_dismissed` / `onboarding_wallet_clicked` | — | Crypto onboarding funnel |

### UI funnel (`track`, all prefixed `ui_`)
`ui_menu_oracle`, `ui_menu_leaderboard`, `ui_menu_lore`, `ui_menu_join`,
`ui_menu_follow_x`, `ui_menu_invite`, `ui_menu_connect_wallet`,
`ui_menu_onboarding`, `ui_level_complete`, `ui_badge_claim_click`,
`ui_score_submit_click`, `ui_view_nft_click`, `ui_shooter_prototype_open`,
`ui_lore_submit`, `ui_oracle_opened`, `ui_email_skip`, `ui_onboarding_rabby`,
`ui_onboarding_learn_more`

### Automatic
`distinct_id` — `Web3Bridge.player_id()`, a locally generated random UUID.

---

## Privacy posture

Deliberate. Do not loosen without asking the owner.

- **No PII.** No email, no name, no IP-derived identity.
- **No wallet address**, even though the game knows it. A wallet address is a
  real, permanent financial identifier and linking it to behavioural analytics
  is exactly the kind of thing this project should not do.
- **`person_profiles: "identified_only"`** and we never call `identify()`, so
  PostHog builds no person profiles from anonymous traffic.
- **Autocapture OFF, session recording OFF, pageview capture OFF.** Only the
  explicit events above are sent.
- **Fails quiet.** No token, non-web platform, CSP block, ad-blocker — every
  path is a no-op. Analytics must never be able to break the game.

---

## ⚠️ CSP — the thing that would have silently killed this

The shipped Content-Security-Policy was `connect-src 'self'`. PostHog would
have been blocked in the browser and **every event dropped, with the GDScript
looking perfectly healthy** — the same "looks real, does nothing" class of bug
that has bitten this project repeatedly.

`script-src` and `connect-src` now allow `https://us.i.posthog.com` and
`https://us-assets.i.posthog.com` in **all three** header files:

- `vercel.json`
- `netlify.toml`
- `web/_headers` (Cloudflare Pages)

**If you change the PostHog host, change all three.** itch.io serves its own
headers and is not affected.

---

## Setup / what still needs a human

| Item | Status |
|---|---|
| `POSTHOG_TOKEN` (`phc_…` project write key) | present in this environment's secrets |
| `POSTHOG_PROJECT_ID` | present |
| `config.json` → `analytics.posthog_token` | **empty in the repo on purpose** |
| CI injection of the token at export time | **NOT YET WIRED — see below** |

The token is intentionally not committed. Until it is injected, `_enabled`
stays false and no analytics are sent. To activate, either:

1. Paste the `phc_` key into `config.json` → `analytics.posthog_token` (it is
   a public, append-only write key — this is safe, it is what ships in the
   `<script>` tag of every PostHog-using website), **or**
2. Add a CI step that writes `$POSTHOG_TOKEN` into `config.json` before the
   Godot export runs (config.json is force-included in the pck via
   `export_presets.cfg`, so it must be written *before* export, not after).

Also human-only: creating the PostHog dashboards/insights for these events.

## Why the official wizard was not used

`npx @posthog/wizard@latest` requires a **personal** API key (`phx_…`) for
auth; the secret available here is the project write key (`phc_…`). The wizard
also detects and patches JS/TS frameworks (Next.js, React, Svelte). This
project is Godot/GDScript with a generated HTML shell — there is no framework
for it to patch, and any file it wrote into `web/game/` would be destroyed by
the next export. The integration is therefore done from GDScript, which
survives re-export because it lives in the pck.
