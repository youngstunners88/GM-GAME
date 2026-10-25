# FOUNDER PROMPT — Episode 2: CAD quality, seamless transitions, audio, draw rewrite

**GIVE THIS ENTIRE FILE TO CLAUDE CODE.** Path: `PROMPT_EPISODE2_CAD_TRANSITIONS_DRAW_REWRITE_2026-10-25.md`

Repo: `youngstunners88/GM-GAME`. Godot 4.3. Hard refresh is the only acceptance. **Runpod is topped up — activate Runpod for this build.** Prefer Runpod for heavy mesh / bake work. Use free CAD / **U3CAD** for hyperreal facility, weapons, town exterior/interior, Gatling, and armory interior. Do not ship grey boxes or low-poly placeholders where CAD can replace them.

---

## 0\. Priority order

1. **P0 — Transitions** (smelter door pause; elevator pre-load; forest delay \+ rewind)  
2. **P0 — Audio** (VO under music; silent train)  
3. **P1 — CAD quality** (smelting facility \+ weapons hyperreal; Gatling; Rich/Utah armory interior; town exterior \+ furnished interiors)  
4. **P1 — Post-draw narrative rewrite** (below; supersedes Bull-arrives-at-draw close in the surface-to-town lock)

Do not claim FIXED on quality while transitions still pause or rewind.

---

## 1\. Transitions — no pause, no rewind

### 1.1 Smelting facility → doorway

- There must be **no arbitrary pause / interval** between the facility and the doorway that leads out.  
- Player walks through continuously. No black hold, no frozen wait, no “loading beat” that feels like a cut.

### 1.2 Elevator

- Looking ahead into the elevator must **not** show Lil Blunt already inside before he enters.  
- Body and camera enter together. No pre-spawn of the player mesh in the car.

### 1.3 Elevator → forest

- Current: long painful delay where nothing happens; scene **rewinds**.  
- Required: **seamless** — they walk out of the elevator **straight into the forest** with **zero delay** and **zero rewind**.  
- No reverse playback of the lift, no hold on black, no re-trigger of the ascent animation after exit.

**Done for transitions:** founder hard-refresh path facility → door → elevator → forest with no pause and no rewind; elevator empty until entry.

---

## 2\. CAD / U3CAD quality pass

Activate **Runpod**. Use **U3CAD / free CAD** for:

| Target | Standard |
| :---- | :---- |
| Inferno hideout **smelting facility** | Hyperreal props, furnace, kegs, tools, surfaces — not grey primitives |
| **Weapons** in facility / personal armory view | Hyperreal; match founder Winchester / revolver quality bar |
| **Colt Gatling** | Full quality pass — readable, period, not a trash prop |
| **Rich & Utah armory interior** | More furniture, cases, racks, subtle detail; denser but readable |
| **Town exterior** | Better façades/openings (align with windows-doors skill; no new Bldg\_\* count required) |
| **Town interiors** | More furnished furniture and subtle details (Certificate, Saloon, Armory, Jail as touched) |

Pack gate remains hard (\~190 MiB class). Prefer replacing worst offenders; exclude dead loose textures; do not ship unused Meshy/Tripo sidecars.

Related: `PROMPT_EPISODE2_TOWN_WINDOWS_DOORS_EXISTING.md`, `PROMPT_EPISODE2_ARMORY_FURTHER_OFF_MAIN.md`.

---

## 3\. Audio

| Problem | Fix |
| :---- | :---- |
| People VO overshadowed by music | Raise dialogue / character VO relative to BGM (duck music under VO or \+gain on VO bus). Music must not bury speech. |
| Train inaudible when it passes | Raise train pass-by / rail SFX so it is clearly heard on approach and pass. |

Use Episode 2 audio skills / VARCO buses if present (`gm-game-episode2-audio-state-router`, `gm-game-episode2-varco-sound`). Do not mute BGM entirely.

**Done for audio:** hard-refresh — speech intelligible over music; train clearly audible on pass.

---

## 4\. Post-draw narrative rewrite (locks)

This **replaces** the old close where Inferno Bull arrives during/right after the draw. Bull does **not** arrive at the draw.

### 4.1 Immediately after the draw (Lil Blunt wins)

1. **Minister Mike Dean** leaves his office, runs out in **panic**, and **inquires what happened**.  
2. **Townspeople celebrate** Lil Blunt’s win, then **dance together**.  
3. **Inferno Bull does not arrive yet.**

### 4.2 Sheriff → job → Rich & Utah

4. **Sheriff** is impressed with Lil Blunt’s shooting.  
5. Sheriff **offers him the job**: find out **who let the bears hold Fort Knox** — this leads toward the **prisoner** (jailhouse investigation lock).  
6. Sheriff **advises** Lil Blunt to see **Rich and Utah** (armory).

### 4.3 Gatling → Inferno returns → bar

7. Lil Blunt goes to **Rich & Utah**; can **test the Colt Gatling**.  
8. **After** testing the Gatling, **Inferno returns on his bike** and **parks outside Rich’s**.  
9. Inferno takes Lil Blunt **to the bar for whiskey**.

### 4.4 Body in the street \+ joke

10. On the way / at the scene: they find the **man Lil Blunt shot**, with **Minister Mike Dean praying** by him.  
11. Inferno **greets the Minister**.  
12. Inferno asks Lil Blunt **what happened / who put a hole in his head**.  
13. Lil Blunt: **"Must've been a bird that had to get rid of the heavy load."**

### 4.5 Bar \+ Flux delay

14. They go into the **bar and drink**.  
15. Inferno says his cousin **Flux** needs help with his **new kettle** — they need to **delay a little while and reconvene later**.

Jailhouse / bears / Fort Knox climax remain downstream (`PROMPT_EPISODE2_JAILHOUSE_BEARS_INVESTIGATION.md`). Do not open Fort Knox in this pass.

---

## 5\. Definition of Done

- [ ] Facility → door: no arbitrary pause  
- [ ] Elevator: Lil Blunt not pre-visible inside before entry  
- [ ] Elevator → forest: seamless walk-out, no delay, no rewind  
- [ ] Smelter \+ weapons \+ Gatling \+ armory interior \+ town CAD pass visibly improved (Runpod/U3CAD used where needed)  
- [ ] VO clear over music; train audible on pass  
- [ ] Post-draw sequence matches §4 (Mike Dean panic, celebrate/dance, no Bull at draw, Sheriff job \+ Rich/Utah tip, Gatling then Bull on bike, body \+ bird line, bar \+ Flux kettle delay)  
- [ ] Pack under gate; STATUS build tag; founder hard-refresh only

---

## 6\. Out of scope this pass

- Full day-88 river set-piece implementation beyond armory gear already sold  
- AwesomeX / Bull sacrifice Fort Knox climax  
- Episode 1 residuals

---

## 7\. Related locks (read; do not contradict except where §4 supersedes Bull-at-draw)

- `PROMPT_EPISODE2_SURFACE_TO_TOWN_DRAW_SPEC.md` — surface → town → certificate → draw (Bull-at-draw **overridden** by §4)  
- `PROMPT_EPISODE2_RICH_ARMORY_UTAH_RIVER.md` / armory further-off-main  
- `PROMPT_EPISODE2_JAILHOUSE_BEARS_INVESTIGATION.md` — prisoner / bears source  
- `PROMPT_EPISODE2_TOWN_WINDOWS_DOORS_EXISTING.md` — openings quality  
- Episode 2 audio skills as above

**Ship when transitions are seamless, audio is readable, CAD reads hyperreal on the named sets, and the draw aftermath matches the founder script above.**

&nbsp;

&nbsp;