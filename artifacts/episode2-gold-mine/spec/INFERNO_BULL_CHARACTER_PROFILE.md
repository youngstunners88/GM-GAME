# INFERNO BULL — Character Profile & Design Spec
**Episode 2 Companion · Gold Mine Runner**

**GIVE THIS FILE TO CLAUDE CODE** alongside `PROMPT_EPISODE2_GOLD_MINE_RUNNER_COMPLETE_SPEC.md`

---

## 1. Identity

| Field | Detail |
|-------|--------|
| **Full Name / Title** | Inferno Bull (also called “the Bull”, “Inferno”) |
| **Role** | First companion Lil Blunt meets in Episode 2 |
| **Protocol Link** | Official mascot of the Inferno protocol. Docs state he is **“BULLISH ON BLAZE”**. Strong narrative and tokenomic connection to Blaze. |
| **Social** | https://x.com/infernobullwin |
| **Docs** | https://docs.inferno.win/infernox |
| **First Appearance** | Smelting Facility (right after Lil Blunt exits the opening mine-cart runner section) |

---

## 2. Narrative Function

Lil Blunt finishes the first high-speed cart / zip-line runner stretch and stumbles into a working **smelting facility** deep in the Gold Mine.

There he finds Inferno Bull seated among molten gold, whiskey in hand, cigar burning, looking like he owns the place.

They share a drink and a cigar.  
The Bull sizes Lil Blunt up, then **hands him a Winchester 1886** — Lil Blunt’s first long gun.

The Bull becomes a temporary AI companion for the next section (cover fire, guidance, occasional lines).  
Lil Blunt promises that when this is over he will take the Bull to the new **Smoke Lounge** as repayment.

This beat marks the tonal shift from pure runner into the Wild West 3D shooter / protocol-chamber experience.  
The first major destination after this meeting is the path toward **Fort Knox** (or the next white-paper chamber that best fits “using the protocol”).

---

## 3. Visual Design (Locked to Founder Images)

**Primary look (combat / armed):**  
- Massive anthropomorphic black bull, hyper-muscular  
- Copper/bronze miner hard-hat with glowing headlamp  
- Long curved horns  
- Dark aviator sunglasses with reflective/fiery lenses  
- Cigar permanently in mouth, smoke rising  
- Red bandana around neck  
- Heavy weathered leather harness, bandoliers, pouches, chains  
- Gold bull-skull belt buckle and necklace  
- Holds a lever-action long gun (Winchester 1886 style)  
- Dusty, battle-worn, gold-dusted leather and denim  
- Work boots with straps and spurs  

**Secondary look (smelting / relaxed):**  
- Same bull, overalls version, holding whiskey glass and cigar  
- Pickaxe over one shoulder  
- Still wearing the hard-hat and sunglasses  

**Optional cinematic variant:**  
- Green-skinned / more demonic bull with flaming horns (use sparingly for high-drama moments)

**References on disk:**  
`artifacts/episode2-gold-mine/references/`  
- `inferno_bull.png` (logo)  
- `inferno_bull_armed.jpeg`  
- `inferno_bull_whiskey.jpeg`  
- `inferno_bull_smelting.jpeg`  

Aesthetic must stay hyper-realistic and match the same visual language as Lil Blunt and the gold-mine environments.

---

## 4. Personality

- Deeply calm, almost lazy confidence — the kind of calm that only comes from having already survived everything  
- Speaks little; when he does, every word lands  
- Dry Western humor, never tries too hard  
- Loyal once he decides you’re worth the trouble  
- Treats the mine like an old friend he both respects and owns  
- Protective of the protocol and of anyone still grinding in the dark  
- Will call Lil Blunt out if he starts acting soft, but never with malice  

Core energy: **“I’ve been down here longer than you’ve been alive, kid. Keep up.”**

---

## 5. Voice Direction (ElevenLabs)

**Required tone:**  
Deep, distinctive, masculine Western voice.  
Low, gravelly, slow, measured.  
Think old miner + gunslinger + quiet force of nature.  
Not cartoonish, not high-energy hype.  
Heavy chest resonance. Slight Southern/Western drawl is welcome but keep it natural.

**Claude Code instruction:**  
Create or select an ElevenLabs voice that matches the above.  
Store the voice ID in the project so it can be reused for all Inferno Bull lines.  
Priority: deep, calm, authoritative, slightly weary, never nasal or young.

**Sample lines for voice testing:**

> “You made it this far. That’s rarer than you think.”  
> “Take the rifle. You’re gonna need more than a pickaxe from here on.”  
> “I don’t do sidekicks. But I’ll walk with you a stretch.”  
> “When this is over… you owe me a seat in that Smoke Lounge.”  
> “The mine don’t care how long you’ve been down here. It only cares if you’re still standing.”

---

## 6. Gameplay Role

- Appears only after the first runner section (smelting facility).  
- Hands Lil Blunt the Winchester 1886 (permanent unlock for chamber sections).  
- Temporary companion: provides cover fire, points the way, occasional reactive voice lines.  
- Does **not** become a second playable character.  
- Can reappear in later chambers or at key story beats if the narrative calls for it.  
- Architecture must leave room for additional future companions without breaking this one.

---

## 7. Relationship to Protocol & Story

- Living embodiment of the Inferno protocol and its “BULLISH ON BLAZE” stance.  
- His presence makes the Blaze / Inferno connection feel personal instead of abstract.  
- The whiskey + cigar + gun hand-off is the emotional and mechanical gateway into the deeper protocol chambers (Fort Knox and beyond).  
- The Smoke Lounge promise ties Episode 2 back to the broader Lil Blunt / Smoke Realm world.

---

## 8. Asset & Implementation Notes for Claude Code

1. Create full character sheet + turnarounds from the reference images.  
2. Rig for both relaxed (smelting) and armed (companion) states.  
3. Animations needed: idle (cigar smoke), drink, hand-over-gun, walk, cover-fire, simple combat gestures.  
4. Export clean GLB.  
5. Register ElevenLabs voice ID and generate the sample lines above as test clips.  
6. Update the main Episode 2 prompt / STATUS.md so the First Chamber beat explicitly uses this profile.

---

## 9. Hard Rules

- Inferno Bull is companion only — Lil Blunt remains the sole playable protagonist.  
- Never invent new protocol mechanics for him.  
- Visual fidelity to the founder images is law.  
- Voice must stay deep, Western, and restrained.  
- The smelting-facility meeting + Winchester hand-off is a fixed story beat.

**The Bull has been waiting in the fire. Now he walks with us.**

---

# CLAUDE CODE STATUS ANNOTATIONS (2026-09-08)

Appended below the founder's verbatim profile — the profile itself is
unmodified above.

## §3 Visual Design — reference art on disk

**All four listed references are now on disk.** Three arrived with the profile; the logo followed on 2026-09-08:

| Profile lists | On disk | Notes |
|---|---|---|
| `inferno_bull_armed.jpeg` | ✅ | Winchester, bandoliers, red bandana, horned hard-hat — the combat/companion look |
| `inferno_bull_whiskey.jpeg` | ✅ | Overalls, pickaxe over shoulder, whiskey glass — the relaxed/smelting look |
| `inferno_bull_smelting.jpeg` | ✅ | Green/flaming-horn cinematic variant, seated among molten gold — matches the Chamber 0 staging exactly |
| `inferno_bull.png` (logo) | ✅ **received 2026-09-08**, saved as `inferno_bull_logo.jpeg` | The Inferno roundel: black bull, flame-lensed aviators, brass nose ring, flames, "INFERNO" wordmark, red ground. **Filename note:** it arrived as a 400x400 JPEG, not a PNG, so it's stored with its true extension rather than mislabelled `.png`. If a transparent-background PNG is wanted for UI use, that's a separate keying pass — say the word. |

## §8 Asset & Implementation Notes — honest per-item status

| # | Item | Status |
|---|---|---|
| 1 | Character sheet + turnarounds | ❌ Not done. Turnarounds of a hyper-real character are art generation, not something this container can produce at reference fidelity. Needs an artist or an image pipeline pass. |
| 2 | Rig for relaxed + armed states | ❌ Blocked — same organic-character gap as the Lil Blunt hero model. `bpy` scripting builds primitive props, it does not sculpt or rig a character. Needs a human Blender pass or a supplied rigged GLB. |
| 3 | Animations (idle/drink/hand-over-gun/walk/cover-fire) | ❌ Blocked, same reason as #2. |
| 4 | Export clean GLB | ❌ Blocked, same reason as #2. |
| 5 | ElevenLabs voice ID + sample line clips | ✅ **DONE** — see below. |
| 6 | Update Episode 2 prompt/STATUS so the First Chamber beat uses this profile | ✅ **DONE** — `chambers/00_SMELTING_FACILITY.md` (new), `chambers/01_CHAMBER_MINER_SHAFT.md` (Bull beat retired), `spec/STORY_OUTLINE.md` (sequence revised), `STATUS.md`. |

**The pattern to note:** items 1-4 are all the same blocker — organic character
assets. Props (carts, rails, architecture) are solved; characters are not, for
the Bull exactly as for Lil Blunt himself. That gap is unchanged by this
profile and still needs the founder's Option A/B/C decision in
`00_ARCHITECTURE.md` §7.

## §5 Voice — DONE. Original voice, designed and owned by this project.

**Voice ID: `uWE48TmsTuIjyh2ifoNL`** — name **"Inferno Bull"**, ElevenLabs
category `generated`. This is an **original voice created from the character
profile via ElevenLabs Voice Design**, owned by this project — not a stock
voice. Stored as a per-line `voice_id` override in
`assets/audio-manifest.json`, so it is reused automatically for every future
Bull line.

**Correction on the record:** the first pass selected a stock professional
voice ("Elijah Boone – Storytellin' Cowboy"). That was the wrong call — the
founder's instruction was to *create* a voice we own, and ownership is the
point for a brand character. The stock voice has been replaced entirely; no
Bull line references it any more.

### How the voice was chosen — by measurement, not by guessing

Voice Design returned three candidate previews from the character
description. Since tone can't be judged here by ear, all three were decoded
and measured on the same script:

| Preview | Median F0 | Spectral centroid (brightness) | Energy < 300 Hz |
|---|---|---|---|
| 0 | 111.9 Hz | 1405 | 9.5% |
| 1 | 128.9 Hz | 1490 | 11.8% |
| **2 → chosen** | **77.4 Hz** | **1060 (darkest)** | **21.8%** |

Preview 2 wins decisively on exactly the founder's criteria — "deep and thick".
77 Hz is genuine bass (typical adult male speech sits ~100-120 Hz), it has the
darkest timbre, and more than double the chest-register energy of the others.
It was also the fastest of the three, but **pace is tunable via settings and
timbre is not**, so it was selected on timbre and slowed with
`voice_settings.speed = 0.80`.

### Shipped clips, measured

| ID | Duration | Median F0 |
|---|---|---|
| `vo_bull_made_it` | 3.58s | 84.2 Hz |
| `vo_bull_take_rifle` | 5.80s | 82.6 Hz |
| `vo_bull_no_sidekicks` | 3.99s | 88.8 Hz |
| `vo_bull_smoke_lounge` | 5.02s | 78.8 Hz |
| `vo_bull_still_standing` | 7.76s | 84.2 Hz |

All in `src/assets/sounds/voice/`, played via
`AudioManager.play_voice("vo_bull_made_it")`.

Two measurement notes, for honesty about method:
- `vo_bull_no_sidekicks` first measured as 165.8 Hz — that was an **octave
  error in the autocorrelation estimator**, not a real reading. Re-measured
  with a harmonic-product-spectrum method it was 105 Hz: genuinely lighter
  than its siblings, though not double. It was re-generated once and the new
  take (88.8 Hz) kept because it measured deeper.
- Generation is nondeterministic, so line-to-line register varies. Any line
  that reads thin can simply be re-rolled with
  `python3 scripts/generate_audio.py --force <id>`.

**Operational note (important):** a `generated` voice is owned by **one
ElevenLabs workspace** — this one requires the `ELEVENLABS_API` key.
`scripts/generate_audio.py` already prefers that key over the legacy
`ELEVENLABS_API_KEY`, so generation works; but the legacy workspace would
return `voice_not_found`. This is the same property the custom "Lil Blunt"
voice already has, so it is a known, precedented condition rather than a new
fragility.

**Honest limit, unchanged:** these are verified as real audio, genuinely deep
(low-80s Hz), and correctly paced. I still cannot judge *character* by ear —
whether it sounds like the Bull is the founder's call. If it misses, the fix
is another Voice Design pass with an adjusted description, or a re-roll; the
manifest is the only thing that changes.
