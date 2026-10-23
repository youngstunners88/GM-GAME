# Lil Blunt Adventure — Godot 4.3 2D Platformer

I am building a complete Godot 4.3 2D platformer for my client **Rich**, founder of three interconnected crypto projects: **SmokeRing** (SMOKE token / Lil Blunt mascot), **DIAMONDS** (ETH rewards protocol), and **GoldMine** (gamified DeFi mining). The game stars **Lil Blunt**, an anthropomorphic chill weed nugget character, in a retro 16-bit pixel art style inspired by classic Super Mario / GBA side-scrollers with light RPG progression.

## Client Ecosystem Context
- **SmokeRing**: OFT token on BASE, ETH, BSC, PulseChain. Lil Blunt is the brand mascot (muscular green weed character, FOMO rocket imagery). "Blaze Mode" is a core game mechanic.
- **DIAMONDS**: ETH rewards protocol with three payout pools. Diamond imagery. Diamond Shards = invincibility shield power-up. Ethereum rings = collectible nod to ETH rewards.
- **GoldMine**: Wild West gold rush DeFi platform. 100-day miners, Fort Knox staking, GOLD Rush Auctions. Gold coins = main collectible. Tax Collector enemies = crypto tax/FUD metaphor.

## Game Identity
- **Hero**: Lil Blunt — small, cute, chill, friendly, cool. NOT aggressive.
- **Core Abilities**: Run, jump, double jump.
- **Power-ups**: 
  - Weed Leaves / Blunt Buds → Blaze Mode (faster movement, higher jumps, auto-puff defensive smoke clouds that damage enemies)
  - Magic Mushrooms → Grow bigger and stronger, break certain blocks
  - Diamond Shards → Diamond shield (invincibility + damaging aura)
- **Level 1 Theme**: The Smoke Realm — colorful, hazy, trippy forest/swamp. Floating smoke clouds as platforms. Giant leaves, mushrooms, glowing flowers.
- **Collectibles**: Ethereum rings (golden glowing rings), regular small coins.
- **Enemies**: Greedy Tax Collector creatures, Annoying Fly swarms, Rolling boulders, Hostile vines (non-weed-themed).
- **End of Level**: Simple boss arena.
- **Systems**: Health system, score/collectible counter, basic enemy AI, proper level design with secrets and flow.

## Workspaces
- `/design` — Game design, level layouts, mechanics specs, lore integration, boss design
- `/assets` — Pixel art direction, sprite specs, audio direction, tileset definitions, animation frame guides
- `/src` — Godot 4.3 engine work: GDScript, scenes, nodes, physics, UI, game state
- `/docs` — Game documentation, marketing copy, changelogs, build instructions

## ⭐ CONTEXT-MANIFEST RULE (read before starting work)
Start every task by reading `.claude/context-manifests/default.md`, then the
manifest matching the domain (`shooter.md`, `icp.md`). Load only what the
manifest lists. **Never load the full repo** — at 100+ source files that spends
the context window before any work happens.

The manifests also carry the traps that cost real time to rediscover: that
`gdparse` is syntax-only and passes files a real export rejects, that the
security sentinel scans `git ls-files` so running it pre-`git add` scans
nothing, and that the circulating `@icp-cli/cli` install command points at a
package that doesn't exist. If a manifest path 404s, fix the manifest in the
same commit — a manifest that lies is worse than none.

## Routing
Logan's Lake and the supplied Logan model: `.claude/skills/ep2-logans-lake/SKILL.md` → `design/ep2/lake/LOGANS_LAKE_LOCK.md`. The older lake fishing/vesting spec is superseded. Pinned Blender toolkit: `gm-blender-godot`; all-file audit: `docs/research/blender-skills/README.md`.

| Task | Go to | Read | Skills |
|------|-------|------|--------|
| **Jev 1.14 / TypeSafe / efficient decisions / image acceptance** | `scripts/jev.mjs` | `.claude/skills/jev-1-14-routing/SKILL.md` | `jev-1-14-routing` |
| **Episode 2 town feels empty / one block; add avenues, doors, windows, people, horses, dogs, chickens or instruments** | `design/ep2/town/`, `tools/ep2_town/` | `.claude/skills/ep2-living-town/SKILL.md` | `ep2-living-town`, `ep2-town-streets`, `ep2-town-facades`, `ep2-town-background-life`, `ep2-town-proof` |
| **Logan / Logan's Lake / liquidity / still water / LP face / "investigate" / the lake feeding the day-88 river; Logan.glb or Logan.JPG** | `src/episode2/chamber/` (new `logans_lake.gd`), `design/ep2/lake/` | `.claude/skills/ep2-logans-lake/SKILL.md` | `ep2-logans-lake`, `ep2-logan-character`, `ep2-lake-water-build`, `ep2-blender-skills-bridge` |
| **Armory "too close to Main Street" / "next storefront" / more than one street / side lane; moving or adding town buildings; any Blender/bpy/GLB kit piece, rig or clip for Episode 2** | `tools/ep2_town/armory_offmain_probe.py` (measure first), then `src/episode2/chamber/ep2_gold_town.gd` `LAYOUT` | `.claude/skills/ep2-armory-off-main/SKILL.md` | `ep2-armory-off-main`, `ep2-sightline-proof`, `ep2-side-lane-build`, `ep2-blender-skills-bridge` (+ installed `blender-*`) |
| **"It is on master but the founder does not see it" / town people, Rich & Utah puppets, doors+windows, Logan's Lake unreachable, Gail house; any release gate for the Episode 2 cast** | `scripts/check-ep2-extras-pack.sh`, `scripts/live-itch-probe.mjs` | `.claude/skills/ship-gap-diagnosis/SKILL.md` | `ship-gap-diagnosis`, `ep2-townfolk-presence`, `ep2-doors-windows`, `always-ship-live` |
| **Shrink a character GLB; pack over 190 MiB; gltfpack/meshoptimizer/UniForge3D** | `tools/ep2_forge/pck_report.py`, `gltfpack_safe.sh` | `.claude/skills/ep2-3d-tools/SKILL.md` | `ep2-3d-tools` |
| Design a level, mechanic, or boss | /design | CONTEXT.md | — |
| Create art/audio specs or style guide | /assets | CONTEXT.md | pixel-art-skill |
| Write code, build scenes, configure engine | /src | `.claude/context-manifests/default.md` | gdscript-skill |
| Write docs, marketing, or changelogs | /docs | CONTEXT.md | — |
| **Keep CONTEXT.md files / routing true; founder setup or toolkit doc** | update the workspace CONTEXT.md + tool roster | `assets/CONTEXT.md`, `src/CONTEXT.md`, `docs/CONTEXT.md` | `context-md-upkeep`, `gm-game-tool-roster` |
| **Touch / mobile / tablet controls, joystick, thumb buttons, "controls cover the screen", cannot play on a phone** | `src/input/mobile/` (`MobileLayoutManager` autoload) | `.claude/skills/gm-game-mobile-touch-experience/SKILL.md`, `docs/architecture/adr-mobile-touch-controls.md` | `gm-game-mobile-touch-experience` |
| **Blaze Rush on a phone / tap to jump / "taps do nothing" / Blaze pause card / exit Blaze / Blaze portrait or tablet / candles unfair / music restarts after Blaze** | `src/dashmode/blaze_rush.gd`, `blaze_pause.gd`, `blaze_tap_cue.gd`, `blaze_framing.gd`, `src/input/mobile/virtual_tap_field.gd` | `.claude/skills/gm-game-blaze-rush-mobile/SKILL.md`, `docs/architecture/adr-blaze-rush-mobile.md`, `blaze-rush-lifecycle` | `gm-game-blaze-rush-mobile`, `gm-game-mobile-touch-experience`, `blaze-rush-lifecycle` |
| **Episode 2 runner or hideout on a phone / swipe to hop, jump, duck / look pad / RUN FAILED retry or home on touch / film skip on touch / "turn your phone" / a key name written in an Episode 2 HUD** | `src/episode2/session/ep2_session_root.gd` (`touch_profile()`), `src/episode2/ep2_entry.gd`, `src/episode2/ep2_touch_overlay.gd`, `src/input/mobile/layouts/ep2_*` | `.claude/skills/ep2-mobile-touch/SKILL.md` | `ep2-mobile-touch`, `gm-game-mobile-touch-experience`, `ep2-free-roam-controls`, `gm-game-episode2-runner-combat` |
| **Episode 1 -> Episode 2 transition on a phone / hand-off smoothness / freeze or black or blue screen before Episode 2 / loading card / music blip at the film end / menu -> Episode 2 stall** | `src/autoload/transition_director.gd`, `src/autoload/scene_router.gd`, `src/level/stage3_boss_defeat_cutscene.gd`, `scripts/mobile-transition-probe.mjs` | `.claude/skills/gm-game-mobile-seamless-transitions/SKILL.md`, `.claude/skills/ep2-seamless-transition/SKILL.md` | `gm-game-mobile-seamless-transitions`, `ep2-seamless-transition`, `ep2-no-blackouts`, `ep2-film-always-plays`, `ep2-state-transition-audit` |
| **Prove a touch flow in a browser / Playwright or CDP touch / `?blaze=N` `?ep2=1` warps / gm_harness / `ep2gate=skip` / `window.__gm` beacon / mutation-check a new gate / "is it live on a phone"** | `scripts/lib/pw.mjs`, `scripts/cdp-touch-probe.mjs`, `scripts/mobile-transition-probe.mjs`, `scripts/check-harness-hooks.py`, `src/debug/harness_hooks.gd` | `.claude/skills/gm-game-touch-flow-verification/SKILL.md` | `gm-game-touch-flow-verification`, `always-ship-live`, `live-itch-terminal-proof` |
| **Founder reports smudges / blotches / blemishes** | **`blotch-hunter` agent** | `scripts/blotch-oracle.json` | `blotch-forensics`, `blotch-repair-gate` |
| **Founder sends an aesthetic target for a room ("this is the aesthetic I want", rework the lift / walkway / cave)** | target -> Muapi refs -> Tripo + Blender kit -> graded captures -> Jev + Microsoft decisions | `.claude/skills/ep2-set-piece-forge/SKILL.md` | `ep2-set-piece-forge` |
| **Blackouts / stop-start / checkpoints between hideout, lift and woods; "one motion"** | build the next chamber behind the current one, swap in one frame | `.claude/skills/ep2-no-blackouts/SKILL.md` | `ep2-no-blackouts` |
| **Rifle invisible / can't see the gun in first person** | measure the pose, carry pose stays in frame (spyglass-only pose is below it) | `.claude/skills/ep2-rifle-always-visible/SKILL.md` | `ep2-rifle-always-visible` |
| **Winchester GM logo ring / brown circle / holes on top of the gun** | delete the ring, never enlarge | `.claude/skills/ep2-winchester-logo/SKILL.md` | `ep2-winchester-logo` |
| **Founder's Winchester GLB / hand-on-gun clips** | Drive GLB -> Blender | `.claude/skills/ep2-founder-weapon-glb/SKILL.md`, `ep2-blender-handling-clips/SKILL.md` | `ep2-founder-weapon-glb`, `ep2-blender-handling-clips` |
| **Model looks see-through / hollow / a black square at the lens** | double-sided + ray audit + Jev | `.claude/skills/ep2-solid-models/SKILL.md` | `ep2-solid-models` |
| **Film does not play / skips / glitches** | films must always play | `.claude/skills/ep2-film-always-plays/SKILL.md` | `ep2-film-always-plays` |
| **Hands/targets/wall look cheap** | Blender GLBs | `.claude/skills/ep2-blender-props/SKILL.md` | `ep2-blender-props` |
| **Rifle/prop "not photoreal", improve a Tripo/Meshy GLB in Blender** | headless render only (GUI MCP froze + crashed Blender) | `.claude/skills/ep2-rifle-realism/SKILL.md`, `blender-headless-render-safety/SKILL.md` | `ep2-rifle-realism`, `blender-headless-render-safety` |
| **Bears not alive / no awareness / bear personalities / road ambush on the quad / woods too small** | bear kit + brain + woods specs; walking behind Inferno must stay silent (test) | `.claude/skills/ep2-living-woods/SKILL.md` ("Implemented") | `ep2-living-woods`, `ep2-bear-awareness` |
| **Bull/bears move statically / incorrect rifle grip / hands miss bow, book or quad / guided-video transcript** | `design/ep2/motion/` contract + existing rigs; guide timing -> rest-aware motion -> independent contact -> runtime proof | `.claude/skills/ep2-character-performance/SKILL.md` | `ep2-character-performance`, `ep2-performance-guides`, `ep2-rest-aware-retargeting`, `ep2-prop-contact-animation`, `ep2-character-motion-qa` |
| **Gun looks darker / dark navy outdoors** | the sun lights the held gun by direction; viewmodel key light, never a colour change | `.claude/skills/ep2-rifle-always-visible/SKILL.md` | `ep2-rifle-always-visible` |
| **Long session / context filling / "token burn" / DietCode / ScaleDown / reading STATUS.md or logs** | cheap reads (grep + offset), quiet gates, STATUS.md head only | `.claude/skills/token-efficiency/SKILL.md` | `token-efficiency` |
| **Pack-size trim, export `exclude_filter`, `.import` / compression, material or lighting change, "remove unused" cleanup; founder says "why did you change my X" / "highlighted" / things went white** | prove the change is invisible to the player: texture probe + before/after captures | `.claude/skills/ship-visual-proof/SKILL.md` | `ship-visual-proof` |
| **Rich & Utah's Armory: two storeys, entry, windows, weaponry, horse inside; Rich/Utah Tripo models, detailed motion (Runpod), autonomy** | `src/episode2/chamber/ep2_gold_town.gd`, `tools/ep2_blender/build_town_kit.py`, `src/episode2/actors/ep2_town_folk.gd`; Blender skills in `~/.claude/skills/blender-*` (EL4CTEO/blender-skills) | `.claude/skills/ep2-armory-two-story/SKILL.md` | `ep2-armory-two-story`, `ep2-tripo-folk-to-game`, `ep2-runpod-motion-lab`, `ep2-armory-npc-autonomy` |
| **Sharps 1874 / Buffalo Gun, Colt Gatling, "Rich and Utah introduce Lil Blunt to the guns", mounted gun, the long rifle** | `src/episode2/actors/ep2_gatling_post.gd`, `ep2_armory_intro.gd`, `tools/ep2_blender/armory_kit.py`, `gold_town.gd` (mounted mode) | `.claude/skills/ep2-armory-guns/SKILL.md` | `ep2-armory-guns`, `ep2-armory-two-story`, `ep2-armory-npc-autonomy` |
| **The bow / bow and arrow, draw-loose-nock, bow sound, GM logo on the bow, "medieval bow", the weapon selection tab cards / icons, "the Remington has no hand"** | `src/episode2/chamber/ep2_bow_view.gd`, `ep2_viewmodel.gd`, `tools/ep2_blender/build_founder_bow.py`, `render_weapon_icons.py` | `.claude/skills/ep2-founder-bow/SKILL.md`, `.claude/skills/ep2-weapon-selector-icons/SKILL.md` | `ep2-founder-bow`, `ep2-weapon-selector-icons`, `ep2-bow`, `ep2-winchester-logo` |
| **Jack Hammer / Jackson Mccree (his look: mean, eye patch), the bounty, XAUt, "ask the Sheriff for a job", buying a horse at the stables, the ride-and-shoot trail, the auction ride, the main antagonist** | `src/episode2/story/ep2_jack_hammer.gd`, `ep2_jack_hammer_arc.gd`, `design/ep2/jack_hammer/` | `.claude/skills/ep2-jack-hammer-narrative/SKILL.md`, `ep2-jack-hammer-dialogue`, `ep2-horse-trail-set-piece` | `ep2-jack-hammer-narrative`, `ep2-jack-hammer-dialogue`, `ep2-horse-trail-set-piece`, `ep2-jack-hammer-character`, `ep2-jailhouse`, `ep2-sheriff-jake` |
| **Town windows/doors blank, "no windows", buildings look empty; townsmen/townswomen, the town has no people** | `tools/ep2_blender/build_town_kit.py`, `tools/ep2_blender/build_townfolk.py`, `src/episode2/actors/ep2_town_people.gd` | `.claude/skills/gm-game-episode2-town-windows-doors/SKILL.md`, `.claude/skills/ep2-town-people/SKILL.md` | `gm-game-episode2-town-windows-doors`, `ep2-town-people` |
| **"[EP2] extras failed", the new town/Armory does not show on itch, streamed pack, "is it live"** | `src/episode2/ep2_extras.gd`, `scripts/extras-gzip-check.sh`, `scripts/live-itch-probe.mjs` | `.claude/skills/ep2-streamed-extras-web/SKILL.md`, `.claude/skills/live-itch-terminal-proof/SKILL.md` | `ep2-streamed-extras-web`, `live-itch-terminal-proof` |
| **Jailhouse, accomplice, "who brought the bears", the Sheriff's prisoner, investigation hook; Mixamo / humanoid animation / Runpod character** | `tools/ep2_blender/build_jailhouse.py`, `src/episode2/chamber/gold_town.gd` (Beat.JAIL_TIP/JAIL), `tools/ep2_motion/mixamo_dl.py` | `.claude/skills/ep2-jailhouse/SKILL.md`, `.claude/skills/ep2-mixamo-pipeline/SKILL.md` | `ep2-jailhouse`, `ep2-mixamo-pipeline` |
| **Founder says something LOOKS wrong / "check for yourself"** | capture it yourself first | `.claude/skills/see-it-yourself/SKILL.md` | `see-it-yourself`, `ep2-reference-match-loop` |

**After the hideout (lava river, mine lift, bear woods, quad bike, spy on the bears, "the next scene is not the runner") go through `ep2-interlude-chain`** (`.claude/skills/ep2-interlude-chain/SKILL.md`).

**THE GAME IS A FIRST-PERSON SHOOTER. The founder's 2026-10-10 clarification adds the personal armory: Winchester 1886 and golden Remington 1875, quick switching, finite ammunition and future collected bear arrows. Keep the equipped firearm in Lil Blunt's hands; the Winchester is the initial/default rifle, not a ban on selecting the earned Remington. Never silently unarm him or use a third-person follow camera. New story rooms extend `Ep2Interlude` (`src/episode2/chamber/interlude_base.gd`); its current Winchester-only viewmodel needs the armory integration before switching is playable.**

**Living woods / personal armory / Inferno lookout / bear awareness / corpse arrows / checkpoint retry / noisy quad escape / mountain binoculars:** use `.claude/skills/ep2-living-woods/SKILL.md` and `design/ep2/LIVING_WOODS_CONTRACT.md`, then the component skill named there. This is the founder's updated convention for the hideout-to-lookout slice: dangerous, varied encounters restart at the surface elevator exit; dead bears remain searchable; Bull physically brushes camouflage off the quad. The skills are preparation, not an implemented feature. Preserve concurrent Claude world foundations. Later Fort Knox plot/rescue rules remain in effect; a failed encounter attempt does not permanently kill Bull.

**Surface -> town (founder lock 2026-10-14): the quad ride out of the woods into the gold-rush town, Inferno leaving "to see a Blondie", the certificate office with the founder's Sheriff and Minister Mike Dean (JakeX was cancelled), the bar (whiskey, a quarter Bitcoin, the witnessed draw for the map to the auction), Bull arriving after the draw - READ `PROMPT_EPISODE2_SURFACE_TO_TOWN_DRAW_SPEC.md` FIRST and go through `ep2-surface-to-town`** (then `ep2-gold-rush-town` for the look - target `artifacts/episode2-gold-mine/references/founder_2026-10-13_town/goldmine_town_target.jpg` - `ep2-sheriff-jake`, `ep2-quickdraw-duel`). It supersedes "immediate town arrival / direct Fort Knox express"; the Fort Knox locks below still hold downstream of the bar.

**Episode 2 world-building after the woods (Fort Knox, the decoy, the quad claim, Inferno's sacrifice, AwesomeX, the rescue, the spy point/vault approach/return trail) READS `PROMPT_EPISODE2_FORT_KNOX_AWESOMEX_FOUNDATION.md` FIRST and goes through `ep2-fort-knox-arc`** (`.claude/skills/ep2-fort-knox-arc/SKILL.md`: the locked run order, cast lock, prep-only rule, 3-heart cap, no Diamonds, one quad then none, AwesomeX is a dragon with machine guns, Bull is rescued not killed). Its gate is `tests/ep2_fort_knox_arc_test.tscn`. **Hyper-real scenes and props (reference stills from Muapi GPT Image 2 -> headless Blender / Meshy / Tripo -> engine capture graded against the reference with Jev numbers, DeepSeek triage and an Astra review) go through `ep2-hyperreal-scene-pipeline`** (`.claude/skills/ep2-hyperreal-scene-pipeline/SKILL.md`; briefs in `tools/ep2_forge/fort_knox_refs.json`, generator `tools/ep2_forge/muapi_ref.py`, metrics `tools/ep2_forge/ref_metrics.py`; **image -> 3D model is pay-per-call through Muapi** - Tripo H3.1 / Meshy 6-7, `tools/ep2_forge/muapi_3d.py` + `ai_vehicle_to_game.py`, see the skill: the flame quad went from 4/10 kit-bashed to 6/10 this way).

Episode 2 sessions load gm-game-tool-roster + gm-game-episode2-runner-combat.
Episode 2 feature work follows `ep2-layered-production` (illustration → wire spec → design imagery → 3D → motion/emotion, each gated); unknowns go to `ep2-3d-strategy-research` before a second bisection round. Any 3D model or meshy.ai link goes through `ep2-meshy-studio` (Meshy CLI + MCP, key from env). A founder feedback doc / Drive images / meshy.ai links go through `ep2-founder-intake`; a visual change is proven with `ep2-reference-match-loop` (screen vs his target image on one board) before it is called done. Voice/creature sounds and reactions go through `ep2-voice-barks`. The hideout Winchester's sound goes through `ep2-winchester-sound`; Inferno Bull's rifle/whiskey visibility goes through `ep2-bull-props-visible`; any film -> gameplay music continuation goes through `ep2-theme-song-handoff`. The target-practice lesson goes through `ep2-range-lesson`, first-person weapon feel through `ep2-fps-shooter-feel`, film loudness through `ep2-film-loudness`, "get it down to a T" through `ep2-gauntlet-loop`, handing work to a stronger model through `ep2-expert-delegation`. The target wall's protocol-logo/bear targets and the back-wall range go through `ep2-range-lesson`; a cutscene repeating itself in dialogue goes through `ep2-narrative-canon` (the narrative memory layer); music drowning speech goes through `ep2-voice-duck`; the hideout's dark-prop legibility goes through `ep2-environment-legibility`. Cutscenes / films / slow-mo story transitions go through `ep2-cinematic-cutscene`; regions, factions, lore and the shooter-RPG world go through `ep2-western-world-forge` (`design/world/WORLD_BIBLE.md`).

## Naming Conventions
- Levels: `level-[number]_[realm-name].tscn` (e.g., `level-01_smoke-realm.tscn`)
- Scripts: `snake_case.gd`
- Scenes: `PascalCase.tscn`
- Assets: `[type]_[entity]_[action]_[frame].[ext]` (e.g., `sprite_lil-blunt_run_01.png`)
- Design docs: `[topic]_design.md`
- Docs: `[topic]_doc.md`

## Global Rules
- Never hardcode real wallet addresses or contract addresses in game code. Use `config.json` if needed.
- All weed-related content must be positive, chill, and symbiotic to Lil Blunt. No aggressive or stereotypical drug imagery.
- Enemies must NOT be weed-themed. Approved enemy types: Tax Collectors, Fly swarms, Rolling boulders, Hostile vines.
- Code must be well-commented, modular, and follow Godot 4.3 best practices.
- The game must feel fun, polished, and true to Lil Blunt's chill personality.

## Deployment (itch.io is primary)
- **Primary platform: itch.io** — https://youngstunners88.itch.io/smokerealm
  Game-native CDN, no cold starts, discovery + analytics. Vercel is a mirror only.
- CI (`.github/workflows/export-game.yml`) exports on every push to
  `master`/`claude/**`, packages an itch-ready zip artifact, and auto-deploys
  via butler when the `BUTLER_API_KEY` repo secret is set.
- **ITCH URL CHANGED (founder, 2026-10-01):** the game page is now
  **https://youngstunners88.itch.io/smokerealm** (butler target
  `youngstunners88/smokerealm:html5`). The old `lil-blunt-adventure` slug no
  longer exists; butler fails with `invalid game` if anything still points at it.
  Never reintroduce the old slug.
- **Web export MUST stay non-threaded** (`variant/thread_support=false`).
  Threaded builds need SharedArrayBuffer and silently fail to boot on itch.io,
  in iframes, and on some mobile browsers. This was the root cause of the
  "game sometimes doesn't play" bug — never regress it.
- Full pipeline, page setup, and verification gates: `/itch-deploy` skill.

## ⭐ PARALLEL-SESSION RULE (only master is live)
Several sessions build different parts of the game at once, each on its own branch.
**Only `master` deploys to itch.** Work that is only on a branch does not exist for
players — this stranded the title screen, the smoke bombs and the Episode 2 runner.
1. **Start of session:** `git merge origin/master` into your branch before building
   (the SessionStart hook prints how far behind you are).
2. **End of every verified change:** `scripts/ship-to-master.sh` — merges master in,
   runs the gates, then fast-forwards master. Never force-push master.
3. **On a merge conflict, keep BOTH sessions' features.** Another session's work is not
   yours to drop; if two implementations of the same thing collide, integrate them.
4. Say "live" only after master's CI deploy lands and the BUILD tag matches.

## ⭐ RATE-LIMIT RULE (offload heavy coding)
When the session's rate limit is tight, send large, well-specified coding work to
Claude Opus 5.5 on OpenRouter with `scripts/opus-offload.mjs` (see the `opus-offload`
skill). The session writes the brief and reviews the diff; the offload reads and
writes the files. Metered on OpenRouter: ~$4 in / $20 out per million tokens.

## ⭐ VAULT-LOG RULE (founder, 2026-10-18 - every session, no exceptions)
Log all work in the Obsidian vault **`GM Game/`** inside this repo (git-excluded; NOT `~/Documents/ComfyUI/comfyUI work`,
which is the Quiet Money vault). Each working turn: extend `GM Game/Work Log/<date>.md`, link it from `GM Game/Work Log.md`,
keep per-topic notes in `GM Game/Projects/` (Revolver, Bears, Train, Lake, Horses...), connect notes with `[[wikilinks]]`
(memory + knowledge graph), and record SHAs, status (IN CODE / WIRED / SEEN / SHIPPED) and open items.

## ⭐ ALWAYS-SHIP RULE (never forget)
After **every significant** change to the game, in the same working session:
1. **Update `STATUS.md`** — the client's living report (what changed, what
   works, what's next). It is the single page the client checks for progress.
2. **Commit** with a clear message referencing the change.
3. **Push** to the working branch. Never end a turn with unpushed game changes.
4. **Keep the repo homepage current**: the client looks at
   https://github.com/youngstunners88/GM-GAME — that shows the **default
   branch (master)**. After each verified milestone, merge the working branch
   into master (merge PR or fast-forward master) so the full codebase is
   always visible there, not hidden on a feature branch.
This is mandatory, not optional — the client relies on always-current state.
The Stop hook re-checks for uncommitted/unpushed work as a backstop.

## ⭐ FOUNDER-LOCKED FRONT PAGE RULE (never change without his say-so)
The title screen is **founder-approved and locked**. It stays exactly as it is
**no matter what, unless the founder explicitly says otherwise** — he builds in
several sessions in parallel, and it has already been lost once to another
session's branch deploying over it.

Locked files (single source: `scripts/front-page-lock.sh list`):
`src/ui/main_menu.gd`, `src/ui/main_menu.tscn`,
`src/assets/backgrounds/bg_menu_gm_keyart.jpg` (his GM key art),
`src/assets/music/menu_mist_theme.mp3` (his MistMenu track),
`src/assets/shaders/title_smoke_flow.gdshader` (the flowing smoke).

Enforced three ways — do not work around any of them:
1. **Session hook** (`.claude/hooks/guard-front-page.sh`): any edit to a locked
   file raises a permission prompt. Only approve it if the founder asked.
2. **CI** (`scripts/front-page-lock.sh check` in `export-game.yml`): a changed
   locked file fails the build, and a failed master build never deploys.
3. **This rule.**

If the founder *does* ask for a front-page change: make it, run
`scripts/front-page-lock.sh update` in the **same commit**, and say in the
commit message that the founder approved it. Never "fix" a failing lock check
by re-fingerprinting unrequested changes — restore the files instead:
`git checkout origin/master -- $(scripts/front-page-lock.sh list)`.

## ⭐ BLOTCH RULE (the founder's longest-running bug — read before touching art)

The "green smudges" report has recurred since 2026-08-20. It cost a month, two
destroyed background plates, and five detectors that all reported the game
clean. It has a **dedicated agent** — `blotch-hunter` — and two skills,
`blotch-forensics` (where does it live) and `blotch-repair-gate` (what you may
do, and what FIXED requires). Route every smudge/blotch/blemish/smear report to
them instead of improvising.

**ROOT CAUSE FOUND 2026-09-23:** the fixed-position smudges were the IDLE
scene-transition overlay (`scene_transition.gd` autoload + `transition_wipe.gdshader`).
At `progress = 0` its smoothstep was non-zero wherever the noise mask < 0.12,
so it painted permanent dark green/purple (smoke) or amber (gold) blobs on
EVERY screen, menu included. Blob positions come from a GPU-precision-dependent
sin() hash — on the founder's GPU they sat in the sky; on the bot's software
renderer they hid under the HUD. L2 Blaze looked clean because its DIAMOND wipe
residue is dark blue on a dark blue scene. Fixed (shader `step` guard + rect
hidden while idle) and gated in `check-green-vfx.py`, which now also scans
`.tscn` files (the L1 cloud platforms and dash trail were translucent green in
scene files the gate never read). If smudges are ever reported again, check
every full-screen autoload overlay's IDLE state first.

Three things that must never be re-litigated:

1. **It is not green.** Measured, the patches multiply the sky by R ×0.86,
   G ×0.89, B ×0.83 — a near-neutral darkening that only *reads* green on a
   warm sky. Every detector that tested `G > R and G > B` found nothing and was
   wrong. Test channel ratios, never a colour name.
2. **`scripts/blotch-oracle.json` is the founder's graded matrix**, and
   `l2_blaze` is graded CLEAN while the other five scenes are blotched. That
   single row kills any theory blaming his GPU, monitor, browser or screenshot
   tool — none of those skip exactly one scene. `scripts/blotch-analyze.py`
   self-grades against it and exits non-zero when uncalibrated. An uncalibrated
   detector has no opinion.
3. **Measure before you change.** Never modify a plate, sprite or VFX without a
   measurement naming that exact file as the carrier, and never soften or blur
   something the founder asked to have removed — that was done once and bought a
   month of re-reports.

One command: `bash scripts/blotch-hunt.sh`.

## ⭐ SECURITY-GATE RULE (autonomous — no prompt required)
Security scanning runs **without being asked, every time**, at three layers:
1. **Mid-session, proactively**: the `game-security-sentinel` skill
   (`.claude/skills/game-security-sentinel/SKILL.md`) activates itself the
   moment you're about to touch secrets, wallet/crypto UI, dynamic execution
   (`OS.execute`, `Expression`, `JavaScriptBridge.eval`), file I/O, deploy
   config, or CI — read its "When to activate" section, it is not optional
   and does not require the user to say "run a security check."
2. **Every release**: `scripts/release-game.sh` Step 1/6 runs
   `scripts/security-sentinel.sh` and blocks the pipeline on any
   critical/high finding. Never remove or bypass this step to "get a release
   out faster."
3. **Every CI push**: `.github/workflows/export-game.yml` runs both
   `gitleaks` (full-history secret scan) and `scripts/security-sentinel.sh`
   (working-tree checks) independent of any chat session existing at all.

All three layers call the **same script** (`scripts/security-sentinel.sh`) —
there is exactly one implementation of these checks, not three copies that
can drift. The full checklist and adaptation reasoning live in
`docs/security/GAME_SECURITY_CHECKLIST.md` (why most of a general SaaS
checklist is N/A for a client-only static-hosted game — no backend/DB/auth/
payments exist today). Append every audit run to `docs/security/audit-log.md`
(the sentinel's `--log` flag does this automatically).

**The moment any of these change, re-audit the N/A items in that checklist
immediately, unprompted**: a real backend, user accounts, a leaderboard,
real payments, or multiplayer. Those items are N/A *because* the
architecture doesn't have the surface yet, not permanently.

`/security-audit` (full mode) is the deeper engine-level companion — run it
before major milestones, not just routine ships. See the sentinel skill's
"Relationship to /security-audit" section for how the two divide labor.

## ⭐ MODEL ROLE SPLIT (cost-aware — read before dispatching anything)

Claude owns the repo, the commits, STATUS.md and every gate. Other models
produce **advice that must be verified**, never changes that land unreviewed.

| Model | OpenRouter ID | Use it for | Rate |
|---|---|---|---|
| **GPT-6 Astra** | `openai/gpt-6-astra` | **Art-direction fidelity review only** — grading a REAL screenshot against the founder references — plus world-building brainstorming where a second creative opinion earns its cost. Accepts image input. | **$10 / $50** per 1M |
| **DeepSeek V4.1 Flash** | `deepseek/deepseek-v4.1-flash` | **Cheap first-pass diagnosis/triage** — combing long logs, big diffs, or a stack of screenshots for candidates before Claude spends its own context verifying them; rubber-duck audits of a script Claude already wrote. Its output is a lead, not a fact — Claude re-derives and confirms every claim against the real files/live build before it informs any commit or STATUS entry. Verified live 2026-09-19 (real dispatch through `scripts/or-call.mjs`, real OpenRouter catalog entry, not assumed). | **$0.15 / $0.60** per 1M |
| **claude-sonnet-5** | — | Pipeline scaffolding, skill authoring, headless scripts (bpy/trimesh), Godot integration, test gates. Most of the asset-pipeline work. | — |
| **claude-opus-4-8 / Opus tier** | — | Asset-pipeline debugging with hidden coupling: a GLB importing with flipped normals, a rig deforming wrong, an API returning malformed data. | — |

**Astra is 5-10x Sonnet per token. Do not use it for routine code, tests, or
mechanical plumbing.** A four-image fidelity review costs ~$0.14-0.20; that is
worth it, and a code review at those rates is not.

**DeepSeek V4.1 Flash is ~65x cheaper than Astra and has a 1M-token context** —
reach for it whenever a task is mostly *volume* (scan every frame, every log
line, every diff hunk) rather than judgment. It never touches the repo and
never gets the final word: Claude still owns the diagnosis, the fix, the
commit, and every "FIXED" claim, per the rule at the top of this section. This
does not relax `live-build-proof` — a DeepSeek read of a screenshot is not a
substitute for Claude's own live-itch verification.

| **Jev (TypeSafe)** | `jev-1.14` direct TypeSafe; `typesafe/jev-1.14` on explicit OpenRouter | **Ship/block DECISIONS on numbers.** Not a chat model — it answers structured questions and defaults to `POST https://api.typesafe.ai/v1/systemone`; explicit OpenRouter uses `/api/alpha/decisions`. Question types: `noul` (0-1 likelihood), `choice` (+`criteria`), `score`. Every question needs `instructions`. Record actual returned usage/cost; 1.14 pricing is unverified here. | verify current pricing |

**CORRECTION (2026-09-20).** A previous version of this file stated that no
"typesafe"/"jev" model existed, on the strength of a `GET /v1/models` grep. That
was WRONG and it cost the founder real time. Decisions models are NOT listed in
`/v1/models`. The catalog is not proof of absence — only a real HTTP call to the
right endpoint is. Verified working; a 400 from that endpoint is a SCHEMA error
(it names the missing field), never "model does not exist".

**Jev 1.14 routing (founder, 2026-10-15):** read `.claude/skills/jev-1-14-routing/SKILL.md`. Keep deterministic checks local; use small batched typed decisions via direct TypeSafe, as the user explicitly selected after adding TYPESAFE. OpenRouter is an explicit compatibility option with its own key. The old 1.13 base64-as-text experiment is historical, not a ban on the new image feature. Proper image bytes use the upstream documented asset encoding; A live API response and paired image controls must succeed before claiming vision verification; OpenRouter image forwarding needs separate proof. Current provider access/context docs are blocked; do not invent limits or verdicts.

Dispatch with `scripts/or-call.mjs`, which carries every guard that matters —
`@include` file inlining, abort-before-spending on a missing path, live `/models`
pricing with `--dry-run`, HTTPS_PROXY handling, and an input-modality check so an
image never gets silently dropped by a text-only model:

```bash
node scripts/or-call.mjs openai/gpt-6-astra <prompt.md> <out.md> --image <shot.png> --image <ref.jpg>
```

`OPENROUTER_API_KEY` lives in the environment's **Environment Variables** field.
Never inline a key in a script, a committed file, or a log line.

Full workflow: the `art-direction-fidelity-check` skill.

## ⭐ MODEL-ADVICE RULE
End **every** response to the client with a one-line recommendation of which
Claude model to use for the likely next task, with a short reason. Guide:
- **claude-opus-4-8 (or Fable/Opus tier)** — debugging unknowns, architecture,
  multi-system integration, art-pipeline work, anything with hidden root causes.
- **claude-sonnet-5** — well-scoped implementation: new levels from existing
  patterns, tuning constants, docs, routine asset wiring.
- **claude-haiku-4-5** — trivial one-file tweaks, copy edits, quick questions.

## ⭐ ALWAYS-SHIP-LIVE GATE (founder, 2026-10-01 — "you must ALWAYS ship")
Every turn that touches the repo ends with skill `always-ship-live`: `bash scripts/ship-check.sh` (it prints the
current itch URL and fails on uncommitted work, unpushed commits and retired slugs), commit, push,
`scripts/ship-to-master.sh`, then PROVE master's CI deployed (GitHub MCP: run success + "Deploy to itch.io via
butler" success + log "Pushed to ..."). Say "live" only after that proof; before it say "pushed / deploying".

## ⭐ FOUNDER SHIP RULE (ALWAYS — founder, 2026-09-25)
SHIP EVERYTHING. Every change is committed, pushed and shipped to master via
`scripts/ship-to-master.sh`, every time. No gate votes block a ship, and none are
reported to the founder. Keep replies to the founder short (token budget).

## ⭐ NFT RULE (founder, 2026-10-04)
Six soulbound NFTs: per stage one for defeating the boss, one for passing the protocol test. Issuance date/time is recorded on
**ICP** (canister clock) and shown only after the canister confirms it. One contract for game + canister + smokegame.win:
`docs/nft/NFT_CONTRACT.md`; skills `gm-game-nft-collection`, `gm-game-nft-icp-issuance`, `gm-game-nft-congrats`. Never add/rename ids,
never fake a chain time, never publish Caffeine builds for the founder.

## ⭐ LEVEL-1 SONG RULE (clarified by the founder, 2026-09-30)
"Song A first" (`level01_theme_always_first.mp3`) means: whenever the game is **played from the title
screen**, that song plays first. It does NOT mean every time Level 1 loads. Coming back out of Blaze Rush, the
Smoke Lounge, an education room or any other side area resumes/shuffles whatever music is appropriate.
Implemented by `AudioManager.launched_from_title()` in `level_01_smoke_realm.gd`. Education rooms play the
founder's `education_stage1/2/3.mp3` with a fade in on entry and a fade out on leaving.
