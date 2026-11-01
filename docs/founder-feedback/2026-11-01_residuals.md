# **PROMPT\_EPISODE2\_FOUNDER\_RESIDUALS\_2026-11-01.md**

# **Episode 2 — Founder hard-refresh residuals (facility / quad / armory / VO / bandits / lake / horse)**

**Date:** 2026-11-01  
**Status:** Active — Claude Code / Codex  
**Repo:** youngstunners88/GM-GAME · Godot 4.3  
**Acceptance:** Hard-refresh only. Do not claim FIXED without founder-visible proof.

---

## **0\. Scope (one packet)**

| \# | Area | Residual |
| ----- | ----- | ----- |
| 1 | Smelting facility → elevator | Still jams / glitches |
| 2 | Quad bike | Glitch delay on approach / use |
| 3 | Armory weapons | Showcase spin when highlighted; add shotgun, Bergmann MP18, golden Thompson |
| 4 | Dialogue | Awkward delay; **remove subtitles** |
| 5 | Weed patch | Small plant patch; buy more like armory (Chill Bud / Tabs health) |
| 6 | Trail bandits | Some **run at** Lil Blunt; some **hide behind rocks**; mounted bandits must **ride**, not stand on the horse |
| 7 | Lake approach | Still desert sand; cannot anticipate Logan at distance |
| 8 | Horse at lake | Horse goes to water and **drinks while Lil Blunt talks to Logan**; horse must **remain** so Lil Blunt can remount (currently disappears) |

Related prior locks (do not regress):  
`PROMPT_EPISODE2_TOWN_MUSIC_LAKE_APPROACH_2026-10-31.md`,  
`PROMPT_EPISODE2_MAP_AND_STABLES_RIDE_CODEX_2026-10-28.md`,  
fix pack 2026-10-27 story order.

---

## **1\. Smelting facility → elevator (still broken)**

**Founder:** Transition still jams and glitches.

### **Required**

* No freeze, hitch, or input-dead frame when leaving the smelting facility into the elevator.  
* Stride / walk / held W must continue through the door (prior door-stride fix must still hold).  
* Elevator entry must not rewind, stutter, or re-trigger facility state.  
* Test: walk from furnace area → door → elevator interior without a visible jam.

### **Do not**

* Reintroduce facility-door pause or pre-place Lil Blunt inside the elevator.

---

## **2\. Quad bike — glitch delay**

**Founder:** There is now a glitch delay by the quad bike.

### **Required**

* Approaching / mounting / starting the quad has **no stuck delay**, freeze, or invisible wait.  
* Music / animation / input remain continuous (if a crossfade is running, it must not block control).  
* Hard-refresh: walk to quad → mount → move within one continuous beat.

---

## **3\. Armory — weapon showcase \+ new guns**

**Founder:** When a weapon is highlighted, it should **appear and spin slowly** as a showcase. Need more weapons.

### **Showcase**

* On highlight / hover / select at the armory counter:  
  * Weapon mesh is **visible in a clear showcase pose**  
  * **Slow continuous spin** (gentle Y-axis or slight tilt; readable, not frantic)  
* Showcase stops cleanly when selection changes or player leaves the armory focus.

### **New weapons (add to inventory / purchase list)**

| Weapon | Notes |
| ----- | ----- |
| **Shotgun** | 1800s / Western-appropriate or period-plausible long gun; buy with BTC/ETH/SOL like existing stock |
| **Bergmann MP18** | Submachine gun; distinct mesh \+ fire feel |
| **Golden Thompson** | Thompson SMG with **gold** finish; premium / showcase piece |

*   
  Payment path stays Episode 1 crypto (same as Rich & Utah armory).  
* Do not break existing Peacemaker / Winchester / Gatling / long rifle flows.

---

## **4\. Dialogue — delay \+ no subtitles**

**Founder:** Conversations have an awkward delay. **Remove the subtitles.**

### **Required**

* Strip **on-screen subtitle / caption text** for character VO in Episode 2 town / trail / lake (and any residual caption boards tied to those lines).  
* VO still plays; timing must not wait on a fake typewriter or subtitle duration.  
* Cut awkward pre-roll / post-roll silence before the next interact is allowed (unless a real animation requires it).  
* Keep input lock only while a line is **actually speaking**, not while empty subtitle UI holds the player.

---

## **5\. Weed plant patch (buy like armory)**

**Founder:** Small weed plant patch so Lil Blunt can get more the same way he buys from the armory.

### **Required**

* Place a **small outdoor plant patch** (town edge or ranch-adjacent — not Main Street center clutter).  
* Interact (E / GRAB) opens a simple purchase like armory:  
  * Spend BTC (or existing purse currency)  
  * Receive **Chill Bud** stock into **Tabs** (same health-smoke item Dude already sells)  
* Not a minigame; not farming gameplay — **shop interaction only**.  
* Clear prompt when in range; no free infinite stack without payment.

---

## **6\. Lake trail bandits**

**Founder:** Some bandits should **run toward** Lil Blunt; some **hide behind rocks**. Bandits that are meant to be mounted are **standing on the horse** — they must **ride**.

### **Combat behavior**

* Split ambush roles:  
  * **Rushers:** leave cover and **run toward** the player / horse  
  * **Holdouts:** stay **behind rocks**, shoot from cover  
* Telegraphed shots (rise / draw / glint) stay; do not make them instant-hit from stealth.

### **Mounted bandits**

* Any bandit on a horse must be in a **proper riding pose** (seated in saddle, not standing on the mesh).  
* Horse and rider move as one; no floating feet on the saddle plane.  
* If a chasing rider exists, fix attachment / seat offset so they read as **riding**.

---

## **7\. Lake approach — still desert / no Logan read**

**Founder:** Lake is still not clear; desert sand remains; cannot anticipate that Logan is in the distance.

### **Required (extends 2026-10-31 approach lock)**

* Final approach segment must **shed desert dominance**: water / shoreline / green banks readable **before** chamber handoff.  
* **Logan** (or cabin \+ dock silhouette) visible **from distance** while still on the trail.  
* No instant dump into lake chamber with full desert under the camera.  
* Lengthen shore beyond a blink so the reveal and music blend can land.

---

## **8\. Horse at the lake (drink \+ remount)**

**Founder:** Horse must go to the lake and **drink the whole time** Lil Blunt speaks with Logan. Horse currently **disappears** — Lil Blunt must be able to **mount again**.

### **Required**

* On arrival / shore:  
  * Horse walks or is led to water’s edge  
  * Plays **drink / graze-at-water** for the **duration of the Logan conversation** (and reasonable linger after)  
* Horse **stays in the scene** as a mountable actor — never despawn mid-dialogue.  
* After talking to Logan, Lil Blunt can **E / mount** the same horse and leave (back toward town / onward path per existing geography).  
* If UNHORSE happened on the trail, still provide a usable horse at the lake (Dude’s horse recovery or stable-consistent mount) so the player is not stranded.

### **Do not**

* Free the horse node when entering `logans_lake`  
* Hide the horse for “cinematic cleanliness” during Logan VO

---

## **9\. Definition of Done**

* \[ \] Facility → elevator: no jam / glitch on hard-refresh  
* \[ \] Quad: no glitch delay on approach / mount / go  
* \[ \] Armory: highlighted weapon slow-spins in showcase  
* \[ \] Armory stock includes shotgun, Bergmann MP18, golden Thompson  
* \[ \] Episode 2 character VO: **no subtitles**; no awkward dead delay  
* \[ \] Weed patch: small plants, paid Chill Bud purchase into Tabs  
* \[ \] Bandits: mix of rushers \+ rock holdouts; mounted bandits **ride** correctly  
* \[ \] Lake approach: water \+ Logan readable from distance; less pure desert at arrival  
* \[ \] Horse drinks through Logan talk and remains **remountable**  
* \[ \] STATUS.md lists each residual; no FIXED claim without founder hard-refresh

---

## **10\. Pointers**

* `src/episode2/chamber/lake_trail.gd` — bandits, shore, horse handoff  
* `src/episode2/chamber/logans_lake.gd` — Logan dialogue; horse must persist  
* Armory / Rich & Utah shop scripts — showcase \+ new SKUs  
* Facility / elevator / quad interlude path — stride and delay  
* Tabs ledger — Chill Bud storage already exists from Dude

**Ship when every row in §0 is founder-visible on a hard-refresh, not only in headless gates.**

