<!-- dispatched: openai/gpt-6-astra
     prompt: prompts/templates/astra-fidelity-check.md
     files inlined: 0
     images attached: 4 (artifacts/ep2-shots/ep2_runner_start.png, artifacts/founder-art/references/ep2_runner_ref_3_minecart_ride.jpg, artifacts/founder-art/references/ep2_runner_ref_1_boulder_bandits.jpg, artifacts/founder-art/references/ep2_runner_ref_2_zipline.jpg)
     tokens: 8812 in / 943 out
     cost: $0.1353
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
### 1. Verdict
**OFF MODEL** — The minecart-and-lantern vocabulary matches, but near-black brown values, absent gold-rich walls and a uniformly enclosed corridor lose the references’ warm-gold/cool-stone contrast and cavernous depth.

### 2. What matches
- **Lantern colour and placement:** Warm practical lights beside timber supports are reference-aligned; retain these as local amber accents.
- **Cart colour blocking:** Brown body panels with darker wheels establish the right material families; preserve that division when improving their value separation.
- **Track-led composition:** Rails pull attention toward the route ahead, as in the references; preserve this guidance rather than adding competing foreground decoration.

### 3. What drifts — ranked
1. **The playable scene collapses into shadow.** Cart edges, sleepers and obstacles occupy similar dark values; the references retain readable midtones beneath bright highlights. **Smallest change:** Raise restrained ambient/fill illumination, with a cool bias, and lighten rail tops and cart trim. Keep lanterns warm; do not merely increase their already-bright cores.

2. **The palette reads as brown timber rather than gold-bearing rock.** References separate cool charcoal stone, warm wood and concentrated yellow-gold deposits. **Smallest change:** Recolour wall materials toward charcoal-grey and add irregular ochre/gold material patches with a few pale highlights. Use low metallic values so these remain visible without reflections; keep gold patches off the immediate driving line.

3. **Uniform tunnel framing removes the reference’s spatial identity.** Equally spaced, tightly enclosing rectangular frames produce a corridor rather than layered mine workings. **Smallest change:** Move selected existing wall sections outward/upward and vary support spacing to create occasional wider pockets and longer sightlines. Reposition existing supports into those recesses for a second depth layer. More detailed props are not the fix.

4. **The cart’s value hierarchy is reversed.** Its flat pale circular badge dominates while the body and rim disappear; reference carts have readable warm panels, lighter metal edging and a gold leaf emblem on a dark round field. **Smallest change:** Darken the badge background, add the reference leaf as a texture, and raise rim/panel values selectively. No additional geometry is needed for the emblem.

5. **The reference’s green character accent is not readable.** No distinct green miner silhouette is visible above the live cart, whereas it anchors all three references. **Smallest change:** If the character is present, adjust its height, visibility and lighting so its green head and helmet clear the rim. If absent, material changes alone cannot restore that silhouette: a simple green head with pointed leaf shapes and a helmet cap is needed.

### 4. Readability at speed
- **Brown box left of the cart:** Its top and side blend with sleepers and surrounding wood. If it is a hazard, recognition is likely late. Lighten its upper/front faces and ensure its silhouette separates from the cart.
- **Small pale cluster beside the right rail:** It registers as a bright fleck, not an identifiable object. Its gameplay role is not covered by the references — founder question.
- **Faint transverse shapes near the vanishing point:** Their height and clearance are indistinguishable from ordinary track/support structure. If actionable, they need stronger face-to-background contrast before reaching the foreground.
- **Rail boundaries:** Dark rails against an almost-black bed weaken lateral positioning cues. Brighter rail-top values would improve route tracking without introducing a new colour language.

### 5. What you cannot judge from this frame
- Actual reaction windows: object distances, collision bounds and first-visible moments are unavailable.
- Whether the box, pale cluster or distant bars are hazards, rewards or scenery.
- Lane-change, jump and duck readability in motion, including cart occlusion during those actions.
- Whether wider caverns, gold deposits or the green character appear elsewhere.
- Material/light settings or reflection-probe presence: no scene or material files were provided.
- Whether these changes remain readable and performant in the moving Compatibility web build; that requires an in-motion capture and testing.