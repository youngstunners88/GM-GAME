<!-- dispatched: x-ai/grok-4.5
     prompt: prompts/crit-grok.md
     files inlined: 1
     tokens: 3386 in / 1668 out
     cost: $0.0168
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
**1. Stage 3 — what’s actually shit**

It reads random because **everything is a gold accent with equal weight**. No quiet ground, no landmark hierarchy, no negative space. Props, pickups, particles, lips, carts, forges, gate, secrets, and enemies all scream at the same volume on a brown slab.

**Top 3 (removal first):**
1. **Kill pickup confetti.** Gold tokens **16 → 6**. wBTC **8 → 3**. BTC coins **3 → 1**. ETH rings stay at 2 only if they’re sparse landmarks; otherwise 1. One pickup every ~400–500px max, clustered at reads (above a gap, after a forge, cart end) — not sprinkled on every ledge.
2. **Kill the 6 gold-dust emitters entirely** (0). They turn the whole stage into sparkle noise and fight the gold lips/tokens. If you must keep dust, **1** tiny emitter at the vault/alcove only.
3. **Cut parallel toy systems.** Mine carts **5 → 2** (one fast, one slow). Drop the **4 gold one-ways + coins** or strip their coins. Powerups **7 → 4** (keep big_axe, pickaxe, one heal-ish, one movement; cut the weed/bong/mushroom pile). Secrets **3 → 1**. You already thinned forges — good; don’t add anything back.

Secondary (only after the cuts): stop gold-lipping every platform edge at full scream — body stays dark, **one** bright lip language for interactables only (forge / vault / assay), duller lip on generic ground.

**2. Assay panel**

Founder said **remove the background** → **(a) fully opaque panel**. Not blur. Not 0.92 alpha. Alpha is why the machinery still shreds the type.

- **Single highest-leverage change:** opaque charcoal/near-black plate (alpha **1.0**), full occlusion, simple hard gold edge or none. No textured fill, no showing the room through it.
- **Dominant element:** the **scale + the two live numbers**. Numbers should be the largest, brightest thing (near-white or hot gold). Scale can stay ~230px but **kill or ghost the halo ring** — it muddies the needle.
- **Shrink hard:** title “ASSAY SCALE” (34 → ~22–24, or kill it), STAKED/RETURN labels (dim, smaller than values), `[E] WEIGH GOLD` (one quiet line, bottom, lower contrast). Outline-on-gold-on-busy is why words are still fucked — outline is a band-aid; contrast + opacity fix it.

Typography hierarchy: **Values >> scale >> labels >> prompt >> title**. Right now 34/30/26/26 is flat competition.

**3. Still shitty after that**

- **Stage 3:** Parallax is two flat brown ColorRect bands — still a dead cardboard tunnel once sparkle is gone. Ground is one y=650 ribbon with generic gaps; sparse platforms (6) + leftover carts/forges can feel like props dropped on an empty shelf. Enemy pack (14) with no telegraph spacing will still feel like a pile, not encounters. Theme bilge (weed/bong next to Fort Knox/assay) will still tone-clash.
- **Assay:** Opaque panel + same gold-on-gold type + fat halo + equal-weight labels will still look like a noisy sticker. If the scale art is weak/low-contrast, a clean panel only exposes that. Panel at 380×680 may still dominate half the boss beat like a UI billboard if it doesn’t sit in a deliberate frame.

**Do in order:** opaque assay + number dominance → cut tokens/wBTC/dust → cut carts/one-ways/powerup pile. Do not add art, emitters, or pickups.