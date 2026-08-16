# FOUNDER DIRECTIVE — Critical Live Fails (Vault Music + Bosses + Dialogue + Video)

**Status**: Binding  
**Date**: 2026-08-16  
**Source**: Founder (Rich / youngstunners88)  
**Priority**: Immediate.

---

## MANDATORY — Multi-model via OpenRouter (every session, no exceptions)

**Founder rule:** Every session from now on MUST use the OpenRouter models we have been using. Solo Claude is not allowed.

| Model | Via | Role |
|-------|-----|------|
| **Claude Code** | Lead | Owns commits, gates, STATUS, final code |
| **Kimi K3** (`moonshotai/kimi-k3`) | OpenRouter | GDScript sweeps, chase physics, input conflict, gate discrimination |
| **Grok 4.5** (latest Grok on OpenRouter) | OpenRouter | Feel notes, aesthetics, video/cover fit, dialogue UX, playtest pressure |

Dispatch before large edits. Integrate only after gates. Claude remains sole owner of the repo. Key is already in secrets — use it.

See also: `MULTI_MODEL_ORCHESTRATION.md` and skill `gm-game-multi-model-orchestrator`.

---

## Dual-subscription context

The founder’s **original Claude subscription has returned**. Another session may be running on the other subscription.

| Rule | Action |
|------|--------|
| Coordination | Always `git fetch origin` first. Work on a **named branch** (e.g. `claude/vault-music-fix`). Do **not** force-push master. Prefer sequential merges via PR. |
| Overlap | If the other session has already touched `vault_realm.gd`, music assets, or boss chase files, stop, STATUS-note the conflict risk, and coordinate rather than overwrite. |
| Scope | This prompt is the truth for the residuals below. |

**Repo:** `youngstunners88/GM-GAME`  
**Live:** https://youngstunners88.itch.io/lil-blunt-adventure  
**Engine:** Godot 4.3 · non-threaded HTML5 · $SMOKE / $DIAMONDS / $GOLD

Hard-refresh itch before any FIXED claim. Deploy via butler when CI is green.

---

## 0. VAULT MUSIC IS WRONG — THIS WAS A SIMPLE TASK

**Founder (verbatim):**  
“The music for the Diamond Vault is incorrect!!!!!!! The music for the The Fort Knox is incorrect!!!! This was a fucking simple task!!!!!!!!”

### What is currently shipped (WRONG)

In `src/level/vault_realm.gd` the vaults play the **parent stage themes**:

```gdscript
# CURRENT (WRONG) — replace this
if _diamonds:
    AudioManager.play_playlist([
        "res://src/assets/music/level02_theme.ogg",
        "res://src/assets/music/level02_theme_alt.ogg"])
else:
    AudioManager.play_playlist([
        "res://src/assets/music/level03_theme.ogg",
        "res://src/assets/music/level03_theme_alt.ogg"])
```

That is **not** what the founder asked for. Do not defend it. Replace it.

### What the founder supplied and required

| File (founder drop / attachments) | Target path in repo | Where it plays |
|-----------------------------------|---------------------|----------------|
| `Diamondsareforever.mp3` | `res://src/assets/music/diamonds_are_forever.mp3` | **Diamond Vault only** — exclusive, looping while inside |
| `Goldmine.mp3` | `res://src/assets/music/goldmine.mp3` | **Fort Knox only** — exclusive, looping while inside |

### Required behaviour (exact)

1. Copy both MP3s into `res://src/assets/music/` if they are not already there.
2. **Diamond Vault** (`protocol == "diamonds"`):
   - On entry → stop previous music → start `diamonds_are_forever.mp3` **looping**
   - On exit → restore the Stage 2 (Crystal Caverns) music
   - Must **never** play outside the Diamond Vault
3. **Fort Knox** (`protocol == "gold"`):
   - On entry → stop previous music → start `goldmine.mp3` **looping**
   - On exit → restore the Stage 3 (Gold Rush) music
   - Must **never** play outside Fort Knox
4. Wire through `AudioManager` so volume / crossfade behaviour matches the rest of the game.
5. Do **not** fall back to `level02_theme` / `level03_theme` for the vaults. The exclusive tracks are the product.

This was the original DoD in `PROMPT_SMOKE_LOUNGE_INTRO_VIDEO_AND_VAULT_MUSIC.md`. It was implemented incorrectly (parent themes instead of exclusive tracks). Fix it now. No content debate.

---

## Assets / links this turn

| Item | Detail |
|------|--------|
| Correct Smoke Lounge video | Google Drive: https://drive.google.com/file/d/1H-Ob6SJQxgj2TvMLFPMQA3S48fIwZaBp/view?usp=sharing |
| Requirement | Correct aspect ratio. Plays **once**. Covers **entire screen**. Muted (lounge music continues). |
| `Diamondsareforever.mp3` | Exclusive Diamond Vault track |
| `Goldmine.mp3` | Exclusive Fort Knox track |

Previous portrait / wrong-ratio clips are rejected. The landscape clip from PR #34 is also rejected by the founder. Download the Drive file, convert to Ogg Theora (`ffmpeg -an`), place at `res://src/assets/video/smoke_lounge.ogv`, VideoStreamPlayer = **cover** fit + `loop = false` + muted.

---

## Other critical defects (still open)

### 1. Smoke Lounge video — still wrong
- Use the **new** Drive video only.
- One-shot, full-screen cover, muted, lounge ambient continues under and after.

### 2. 2nd boss (Distributor / Stage 2) still not chasing
Founder: “The 2nd boss is still not chasing!!!!”  
Claimed fixed many times. Live it still does not chase.  
**DoD**: real browser capture of the Distributor closing distance on a weaving/hopping player and applying pressure. Headless gates alone are not enough. Kimi owns chase physics.

### 3. E key advances dialogue AND cancels it
Founder: “I press E to go next but it also cancels!!!! What the fuck!!!! Fix this!!!!”  
E must only advance while dialogue is open. Close only on the final line (or a separate action). No double-fire on the same press. Kimi owns input conflict.

### 4. Element still far off-screen
Founder circled an element still too far off-screen. Identify the node and bring it fully on-screen with safe margins.

### 5. Final boss (Claim Jumper / Stage 3) does not move / does not chase
Founder: “The final boss doesnt move!!!!! He doesnt chase!!!!!”  
Live capture required showing him advancing and applying pressure. Kimi owns chase; Grok for pressure feel.

---

## Definition of Done

- [ ] OpenRouter multi-model used this session (Claude + Kimi K3 + Grok 4.5) — evidence in STATUS
- [ ] `Diamondsareforever.mp3` placed and wired as **exclusive** Diamond Vault music (not level02 themes)
- [ ] `Goldmine.mp3` placed and wired as **exclusive** Fort Knox music (not level03 themes)
- [ ] Both tracks start on vault entry, loop while inside, restore stage music on exit
- [ ] Correct Drive video → muted Ogg Theora, one-shot, full-screen cover in Smoke Lounge
- [ ] Lounge ambient continues under and after the video
- [ ] Distributor visibly chases in a real browser capture
- [ ] Claim Jumper visibly moves/chases in a real browser capture
- [ ] E advances dialogue without also cancelling it
- [ ] Off-screen element fully on-screen
- [ ] Gates + Security Sentinel green
- [ ] STATUS.md updated with honest results (note dual-session + which models were called)
- [ ] Commit + push + butler deploy — founder hard-refreshes itch

**Hard rule**: Do not mark FIXED without a real browser capture (or founder confirmation). Headless-only claims have already failed this founder multiple times.

---

## Prompt Claude must fulfill

```
FOUNDER DIRECTIVE ACTIVE — docs/founder-prompts/PROMPT_CRITICAL_LIVE_FAILS_BOSSES_DIALOGUE_VIDEO.md

MANDATORY: OpenRouter multi-model this session — Claude lead + Kimi K3 (chase/input/code) + Grok 4.5 (feel/video/dialogue). Solo is not allowed. Evidence of dispatches in STATUS.

DUAL SUBSCRIPTION: Original Claude sub is back; another session may be active. Fetch master first. Named branch only. No force-push.

TOP PRIORITY — vault music is wrong and was a simple task:

1. Diamond Vault MUST play Diamondsareforever.mp3 exclusively (NOT level02 themes).
2. Fort Knox MUST play Goldmine.mp3 exclusively (NOT level03 themes).
3. Place both files, start on entry, loop while inside, restore stage music on exit.

Also still open:
4. Correct Drive video — one-shot, full-screen cover, muted, lounge music continues.
5. Distributor still does not chase live — fix + browser capture (Kimi).
6. E advances dialogue AND cancels it — fix so advance ≠ close (Kimi).
7. Off-screen element — bring fully on-screen.
8. Claim Jumper does not move/chase — fix + browser capture (Kimi + Grok feel).

Gates + STATUS + deploy. No FIXED claims without captures.
```

End of directive.
