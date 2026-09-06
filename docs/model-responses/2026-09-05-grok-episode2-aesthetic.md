<!-- dispatched: x-ai/grok-4.5
     prompt: prompts/grok-episode2-aesthetic.md
     files inlined: 0
     tokens: 856 in / 1398 out
     cost: $0.0101
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
## 1. Reality check on the aesthetic bar

**No.** A Godot 4.3 web build on mobile will not hit Midjourney/Unreal cinematic stills in real time. Those refs assume offline path tracing, dense geo, volumetric god-rays, and film post. Your ceiling is closer to a stylized third-person mobile/Uncharted-lite read: readable silhouette, strong local contrast, and a few hero emissives—not per-frame cinematic lighting.

**Honest ceiling (web/mobile real-time):**
- Forward-friendly PBR, 1 dir light + few omni/spot, heavy reliance on **baked lightmaps / light probes**
- **Emissive** gold veins + lanterns (cheap “glow”) rather than true volumetrics
- **Fake volumetrics:** height fog, particle dust motes, screen-space god-ray approximation, not raymarched fog
- **Trim sheets + tiling rock/wood** over unique high-poly sculpt detail
- **Sparks/embers** as GPU particles (budgeted counts), not mesh debris sims
- Post: cheap bloom, mild color grade, optional SSAO/SSR only on desktop; off or ultra-low on mobile
- Resolution scale + aggressive LODs; no real-time GI, no dense Nanite-style geo

**What closes most of the gap:** baked lighting + emissive materials + strong albedo/roughness contrast on wood/metal/gold + fog card/particle atmosphere + motion (camera shake, speed lines, spark trails). Static screenshot parity with the refs is not the target; **in-motion readability** is.

**Recommendation:** Lock “Uncharted mobile” as the bar—baked light, emissive gold, fog fakes, bloom—and reject any ref that needs path tracing or dense volumetrics.

## 2. Art direction that survives downscaling

At minecart speed the eye holds: **silhouette, value grouping, 2–3 accent colors, and motion cues**. It drops: micro-pore texture, dense leaf venation, multi-bounce GI, thin geometric filigree.

**What reads at distance / 60fps runner:**
- Character: clear hat + headlamp cone + leaf-clump body mass + pickaxe profile (not individual leaflets)
- Cart: wood plank value break, metal rim catchlights, **large gold leaf emblem** (flat readable decal, not engraved micro-detail)
- Tunnel: dark rock mass vs **bright gold vein ribbons** (emissive strips), repeating beam cadence, lantern pools as simple warm discs
- Motion: lamp bob, spark bursts on rails, fog density increase in depth, slight FOV/camera lean

**Wasted detail:** 4K unique sculpts, subsurface skin on leaves, animated individual leaf cards, animated lightmap-quality GI, complex parallax rock.

**Art direction pivot that still “feels like the refs”:** grounded PBR materials, cinematic **color grade** (teal shadows / warm key), heroic emissive gold, and graphic read of veins/beams—not photoreal surface complexity. Think “stylized realism” (Fortnite/Uncharted mobile), not “screenshot of Octane.”

**Recommendation:** Design for silhouette + emissive accents + value contrast at cart speed; kill micro-detail that dies under motion blur and mobile resolution.

## 3. Character fidelity

Episode 1 is 2D—there is **no** reusable 3D hero. Identity must be locked as a **model sheet** before rigging: proportions, hat copper + lamp lens, leaf body topology rules, pickaxe shape, color IDs.

**Keep him on-model across runner/shooter:**
- One hero mesh, mid-poly, **one skeleton**; share anim set (run, cart-idle, shoot, hit)
- Lamp as separate child mesh with emissive + simple spot/projected cookie (or fake cone mesh)
- Leaf body: clumped cards or solid stylized mass with normal maps—not hundreds of animated leaflets
- **Trim/atlas** for leaf/copper/wood so mips stay readable
- Strict turnaround + “100px thumbnail” test: if hat/lamp/leaf/pickaxe fail at thumbnail size, the 3D read fails in-game
- Godot: LOD1 without leaf cards; shadow proxy mesh

**Risk:** image-to-3D and generic rigs drift off-model (wrong hat brassiness, blob leaves, broken pickaxe weight). Human art direction pass is mandatory even if base mesh is generated.

**Recommendation:** Freeze a 2D model sheet + orthographic turnaround first; build one mid-poly hero rig around hat/lamp/leaf/pickaxe silhouette, not a full botanical sculpt.

## 4. Pipeline pragmatics

**No Blender in-container** means local/human Blender (or equivalent DCC) is still the quality gate for the hero. TRELLIS-class image-to-3D is usable for **blockout and some props** (cart base, beams, rocks, lantern body), not for a shippable on-model hero with clean topology, animation-ready weights, and atlas UVs.

| Asset | image-to-3D | Hand-authored DCC |
|--------|-------------|-------------------|
| Hero character | Draft only; retopo/UVs/rig still required | **Required** for final |
| Minecart, beams, props | Often good enough after cleanup | Optional upgrade |
| Gold vein tiles, trim | Bad fit (use trim sheets / substance-style) | Material authoring |
| LODs, collision, Godot import | Manual | Manual |

GLB → Godot is fine; the bottleneck is **authoring clean assets**, not the format. Web budget still demands manual poly/LOD/material discipline after any gen step.

**Recommendation:** Use image-to-3D for prop blockouts only; **hand-model/retopo the hero in Blender (human, out-of-band)**—generated hero meshes will not stay on-model through runner/shooter rigs.