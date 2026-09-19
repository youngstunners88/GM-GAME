<!-- dispatched: openai/gpt-6-astra
     prompt: prompts/templates/astra-fidelity-check.md
     files inlined: 0
     images attached: 4 (artifacts/ep2-shots/ep2_runner_mid.png, artifacts/founder-art/references/ep2_runner_ref_3_minecart_ride.jpg, artifacts/founder-art/references/ep2_runner_ref_1_boulder_bandits.jpg, artifacts/founder-art/references/ep2_runner_ref_2_zipline.jpg)
     tokens: 8812 in / 1013 out
     cost: $0.1388
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
### 1. Verdict
**OFF MODEL** — The mine vocabulary survives, but near-black values, uniform brown lighting and a tightly boxed corridor lose the references’ warm-gold/cool-slate contrast, readable silhouettes and cavernous depth.

### 2. What matches
- **Brown timber supports framing the route:** retain these as the structural motif; their repeated silhouettes establish a mine.
- **Amber wall lights and gold wall accents:** retain those colour assignments; they align with the references’ lanterns and exposed ore.
- **Rails converging past a foreground cart-like silhouette:** retain the forward route emphasis; it supports the references’ minecart staging.

### 3. What drifts — ranked
1. **Darkness erases the playable scene.** The foreground cart, floor and inner rails merge into almost one black mass. The references retain readable wood, stone and metal surfaces even in shadow. **Smallest change:** raise ambient/fill illumination and the darkest material base colours until cart edges, rails and floor separate; preserve black for recesses rather than entire surfaces.

2. **The lighting is almost entirely brown.** The references contrast amber lantern pools with cool slate-blue illumination through the cavern. **Smallest change:** introduce restrained cool fill over the route and distance, and increase the warm lights’ illumination of nearby timber and rock—not merely their visible source brightness. This does not require volumetric effects.

3. **Track boundaries dominate while the actual railway disappears.** The outer pale lines are clearer than the inner rails or sleeper rhythm. In the references, rail pairs and cross-ties explain the route immediately. **Smallest change:** brighten existing rail tops and sleepers, separating grey metal from brown wood; keep metallic low if there is no reflection capture. If sleepers are absent, add only repeated flat crosswise boxes.

4. **The composition reads as a rectangular shaft, not a cavern.** The references use uneven rock openings, substantial overhead space and layered depth. **Smallest change:** vary the spacing of existing supports and move selected wall/ceiling sections outward to create occasional wider, taller pockets while preserving the straight gameplay route. Lighting alone cannot supply that silhouette. If the enclosure cannot be repositioned, a simple widened chamber section with an uneven polygonal opening is needed—not detailed rock meshes.

5. **Gold reads as isolated ochre tiles.** The references show concentrated, irregular seams and clusters with bright yellow-gold highlights. **Smallest change:** regroup existing patches into broken clusters, vary their scale, and raise selected patches toward pale gold. Avoid making every patch equally bright or equally spaced.

6. **The foreground subject has little reference identity.** Neither a clearly edged wood-and-metal cart nor the references’ green miner silhouette is legible. **Smallest change:** first light the existing subject and separate brown panels from lighter trim. If a rider is present, expose its green/helmet colour blocks. This frame cannot establish whether missing silhouette parts need geometry or are simply hidden in darkness.

### 4. Readability at speed
- **Brown box ahead on the right:** its face barely separates from the track bed, while its top blends into shadow. Its occupied lane and blocking silhouette are too weak for a quick decision.
- **Dark transverse shape immediately beyond the foreground subject:** it is difficult to distinguish an obstacle from a shadow or part of the subject. It needs a readable top edge and separation from the floor.
- **Distant pale shape and thin coloured bars:** they are visible marks, but their height, extent and required response cannot be identified. Their gameplay colour coding is **not covered by the references — founder question**.
- **Yellow upright object beside the foreground subject:** it attracts attention, but its narrow silhouette does not explain its function. If it is a pickup, its visual language is **not covered by the references — founder question**.
- **Inner lane rails:** insufficient contrast makes assigning an obstacle to a lane harder than merely spotting it.

At 12 m/s, each metre provides only about **83 ms**; these silhouettes need to resolve before reaching the near foreground.

### 5. What you cannot judge from this frame
- Actual obstacle distances, warning times, collision bounds or intended jump/duck/switch responses.
- Motion readability, pickup rotation, animation, lighting changes or later tunnel sections.
- Whether dark features are absent, unlit or occluded.
- Actual material parameters, light settings or reflection-probe presence; no scene or material files were provided.
- Whether the wider cavern compositions occur elsewhere in the episode.