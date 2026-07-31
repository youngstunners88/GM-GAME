<!-- dispatched: moonshotai/kimi-k3
     prompt: prompts/kimi-font-ui-audit.md
     files inlined: 6
     tokens: 9934 in / 23232 out
     cost: $0.3783
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
### src/ui/main_menu.tscn

- **main_menu.tscn:41** — TitleLabel — font 48 — YES, too small: ≈24 CSS px/line on a phone (≈0.5× scale) — a title should be the largest thing on screen — **72**.
- **main_menu.tscn:47** — SubtitleLabel "THE SMOKE REALM" — font 24 — YES: ≈12 CSS px — **32** (or delete; see redundancy below).
- **main_menu.tscn:54** — PlayButton — font 28 — YES: ≈14 CSS px for the primary CTA — **34**.
- **main_menu.tscn:60** — ContinueButton — font 28 — YES: same — **34**.
- **main_menu.tscn:67** — QuitButton — font 28 — YES: same — **34**.
- Play/Continue/Quit have **no custom_minimum_size** — auto-height ≈ font+~16 ≈ 45 design ≈ ~23 CSS px, below the 44px thumb floor — add `custom_minimum_size = Vector2(280, 72)` on all three.
- **main_menu.tscn:30-33** — VBoxContainer fixed offsets ±200/±150 (400×300 box) — positionally safe (anchored center, no off-screen), but the bumped content (two-line 72 title + 3×72 buttons + separation ≈ 470px) overflows the 300px box and clips top/bottom — widen vertical offsets to ≈ ±260 when bumping.

### src/ui/main_menu.gd

- **main_menu.gd:68-69** — 9 layer-shift buttons — font 20, min 300×46 — YES: ≈10 CSS px text, ≈23 CSS px tall target — **font 26, min (320, 64)**.
- **main_menu.gd:89** — row reposition hardcodes 54px/button pitch (= 46 height + 8 separation). If min height → 64, pitch = 72; leaving 54 re-creates the clipped-off-screen column bug. Update the constant with the size.
- **main_menu.gd:172** — invite dialog body Label — default 16 (no override) — YES: ≈8 CSS px — **22** via font-size override.
- **main_menu.gd:168-169** — dialog title / OK button / "Invite sent!" note (:186) — default 16 — YES — **22**.
- **main_menu.gd:175** — invite LineEdit min (320, 36) — 36 tall ≈ 18 CSS px — below thumb floor — **(320, 56)**.
- **main_menu.gd:241** — version tag Label — default 16, alpha 0.5 — borderline (decorative, ≈8 CSS px) — **18** or leave; lowest priority in the dump.

### src/ui/hud.tscn

- **hud.tscn:27** — ScoreLabel — font 24 — YES: ≈12 CSS px for the primary readout — **30**.
- **hud.tscn:35 / 40 / 45 / 50 / 55 / 60 / 65** — Coin / Ring / Gold / wBTC / XAUT / Diamond / Smoke labels — font 20 — YES: ≈10 CSS px — **26** (28 better; note the left column is 9 labels + hearts + 2 bars, so total stack height grows ~40%).
- **hud.tscn:70** — PowerUpLabel — font 20 — YES: same — **26**.
- **hud.gd:45** — heart pips min 22×22 — ≈11 CSS px, small but non-interactive — **28×28**.
- PowerUpBar / VestingBar (hud.tscn:73-84) — no text, but default ProgressBar height ≈ a 5-8 CSS px sliver on phone — set `custom_minimum_size.y ≈ 24`.

### src/ui/hud.gd

- **hud.gd:56** — lives label — font 22 — YES: ≈11 CSS px — **28** (also has outline — good).
- **hud.gd:74** — combo label — font 32 — NO (borderline): ≈16 CSS px, transient pop with 6px black outline — keep 32, optional 36.
- **hud.gd:125** — control hint — font 18 — YES: ≈9 CSS px — **26**. (Also it's keyboard help on a touch device — consider swapping copy or hiding on mobile.)
- **hud.gd:195** — "YOU DIED" — font 48 — NO: ≈24 CSS px is fine — keep, but add the outline overrides used at :57-58 (currently none, sits over gameplay).
- **hud.gd:217** — auction toast — font 28 — borderline YES: ≈14 CSS px, no outline, over gameplay — **32** + outline.
- **hud.gd:230** — certificate toast — font 24 — YES: ≈12 CSS px, no outline — **28** + outline.

### src/ui/email_signup_panel.tscn

- **email_signup_panel.tscn:40** — panel Title — font 24 — YES: ≈12 CSS px — **32**.
- **email_signup_panel.tscn:45** — Blurb — font 14 — YES, worst explicit size in the dump: ≈7 CSS px — **22** (autowrap already on).
- **email_signup_panel.tscn:47-49, 51-53** — Name / Email LineEdits — no override → default 16 — YES: ≈8 CSS px, incl. placeholder — **22**, and add `custom_minimum_size.y = 56` (default height ≈34 → 17 CSS px, below thumb floor).
- **email_signup_panel.tscn:55-56** — Consent CheckBox — default 16 — YES — **22**; default row height ≈30 (15 CSS px) — min height **56**.
- **email_signup_panel.tscn:61** — Status label — font 14 — YES — **20**.
- **email_signup_panel.tscn:69** — JoinBtn — text default 16 (YES → **24**), min 160×44 → 22 CSS px tall target (YES → **(160, 64)**).
- **email_signup_panel.tscn:73** — SkipBtn — same — **font 24, min (120, 64)**.
- Panel fixed offsets ±300/±220 (:21-24) stay on-screen (center-anchored), but with the bumps above the content ≈ fills 440px — grow to ≈ ±260 vertical if the Status line wraps.

### src/ui/crypto_onboarding.gd

- **crypto_onboarding.tscn was not provided** — I cannot audit the onboarding panel's title/body font sizes or the CloseBtn / RabbyBtn / LearnBtn tap targets (ask #2). Need that file.
- **crypto_onboarding.gd:29** — Lil Blunt sprite at fixed `(700, 46)` in panel-local space — can't verify without the .tscn: if the panel is 600 wide like the email panel, x=700 overflows 100px past its right edge over the dimmed menu. Verify against actual panel width.
- **crypto_onboarding.gd:59-73** — "Learn More" AcceptDialog — title, ~20 lines of dialog_text, OK button all at default 16 — YES: ≈8 CSS px of dense copy — **20-22** font-size override.

---

### 1. Title redundancy/conflict (flagged)

- main_menu.tscn:42 sets TitleLabel text "LIL BLUNT" — **dead**, always overwritten at **main_menu.gd:17** to `"LIL BLUNT\nTHE SMOKE REALM"`.
- Result: "THE SMOKE REALM" renders **twice** — as line 2 of TitleLabel at 48 and again as SubtitleLabel at 24 (tscn:48).
- Minimal fix, pick one: (a) delete line 17, keep SubtitleLabel bumped to 32; or (b) keep the two-line title at **64-72** and delete SubtitleLabel from the .tscn. Prefer (b) — bigger title.
- Side note: the pulse tween (main_menu.gd:30-32) scales the label from default pivot (0,0), so the two-line block visibly grows right/down; set `pivot_offset` to center if it bothers you.

### 2. Tap targets vs ~44px (phone CSS px)

Everything interactive fails on phone: PLAY/CONTINUE/QUIT ≈23px, layer-shift column ≈23px, Join/Skip 22px, LineEdits ≈17px, Consent CheckBox ≈15px, invite input 18px. Recommended heights are inline above (64-72 design ≈ 32-36 CSS px; full 44px compliance needs ≈80 design — 64 is the minimal bump that doesn't re-break the layer-shift column's 720px budget).

### 3. Fixed-position risks

- **hud.gd:194, 216, 229** — `get_viewport().size` used for YOU DIED + both toasts, while everything else uses `get_viewport().get_visible_rect().size` (:59, :73, :129). With `canvas_items`+`expand` these disagree on any window that isn't exactly 1280×720 (i.e., every phone) — the three popups land off-center or off-screen. Switch all three to `get_visible_rect().size`.
- **main_menu.gd:89** — hardcoded 54px pitch (see above); also on a portrait phone the expanded viewport is ~2770 design px tall, so the column parks at y≈2280, far below the centered menu, with ~90×14 CSS px buttons. Landscape-first game, but flag it.
- **crypto_onboarding.gd:29** — sprite x=700 unverifiable without the .tscn (above).
- hud.gd:59 (:59 lives at w−150), :130 (hint at vw.y−48), main_menu.gd:245 (version) — all computed from the visible rect, stay on-screen; hint's bottom-48 may sit under phone browser chrome/home indicator — minor.

### 4. Contrast

- **hud.tscn:27, 35, 40, 45, 50, 55, 60, 65, 70** — all 9 HUD labels are near-white default color with **no outline/plate**, drawn directly over gameplay art — worst contrast issue. Minimal fix: add `outline_size 4-6` + black `font_outline_color`, copying the exact overrides already at hud.gd:57-58.
- **hud.gd:191-195 (YOU DIED), :213-217 (auction), :226-230 (certificate)** — same: bright text, no outline, over gameplay. Add the same outline pair.
- **main_menu.gd:241-242** — version tag at 50% alpha over the forest art, no outline — acceptable for a version stamp; add outline if you bump it to 18.
- OK as-is: menu title/buttons sit over a 0.6 black overlay (main_menu.gd:204); layer-shift buttons have 0.82-alpha plates (:71); email/onboarding panels sit on 0.7 Shade + Panel.

### Missing / assumptions

- **src/ui/crypto_onboarding.tscn** — needed for the onboarding half of ask #2 and the sprite check. Not in the dump.
- **src/ui/email_signup_panel.gd** — not provided; may contain additional in-code size overrides not visible here.
- No theme .tres in the dump → everything without an explicit override assumed at Godot's built-in default **16**.
- Scale key used above: phone landscape (e.g. 844×390 CSS px window, aspect=expand) ≈ **0.5×** design→CSS px; portrait ≈ 0.3×, so landscape numbers are the best case.