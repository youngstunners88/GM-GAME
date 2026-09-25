<!-- dispatched: anthropic/claude-opus-5.5
     prompt: prompts/portals/tour_art_notes_opus.md
     files inlined: 0
     images attached: 5 (src/assets/portals/leaders/leader_stage1.png, src/assets/portals/leaders/leader_stage2.png, src/assets/portals/leaders/leader_stage3.png, docs/founder_briefs/2026-09-25/ref/images/image1.png, docs/founder_briefs/2026-09-25/ref/images/image2.png)
     tokens: 4613 in / 3359 out
     cost: $0.0856
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
```json
{
  "leaders": [
    {
      "stage": 1,
      "figures_count": 1,
      "background": "solid colour #ffffff",
      "needs_cutout": true,
      "figure_bbox_pct": [0.17, 0.01, 0.96, 0.99],
      "suggested_display_height_px": 100,
      "facing": "front",
      "description": "Ember: slicked-hair man in black tux with neon blue/purple outline, sunglasses, cigar with smoke, holding $SMOKE bong. The background reads as white, but I can't tell from the preview whether it has real alpha, so check it in the editor. The thin neon rim will alias at about a 5x downscale, so pre-downscale with a filtered resample."
    },
    {
      "stage": 2,
      "figures_count": 1,
      "background": "solid colour #ffffff",
      "needs_cutout": true,
      "figure_bbox_pct": [0.03, 0.01, 0.96, 0.99],
      "suggested_display_height_px": 100,
      "facing": "front",
      "description": "Single miner in dark leather harness with sunglasses, cigar, glowing diamond in hand, diamond chest emblem, pickaxe over shoulder, lamp at hip. The checkerboard looks baked-in (fake transparency), so it needs a real cutout. MISMATCH: this is labelled 'The Assay Trio' but shows ONE figure, while reference image 4 shows the Trio as three crystal characters. Confirm which art is canonical."
    },
    {
      "stage": 3,
      "figures_count": 1,
      "background": "solid colour #ffffff",
      "needs_cutout": true,
      "figure_bbox_pct": [0.04, 0.01, 1.0, 0.99],
      "suggested_display_height_px": 100,
      "facing": "front",
      "description": "Claim Recorder: prospector with headlamp hat, sunglasses, cigarette, red bandana, GM medallion, gold nugget raised, pickaxe lowered at right. The checkerboard looks baked-in, so it needs a cutout. The pickaxe tip touches the right edge, so check whether it is cropped."
    }
  ],
  "reference_takeaways": [
    "Neither reference is Warcraft-style (isometric/3rd-person). Both are flat 2D side-view with a horizontal-follow camera and one ground line.",
    "Image 5 (entry): a glowing green 'STUDY' hatch sits on a main-level platform with a down-arrow label. The founder's red lines mark a ladder shaft going down into the study area.",
    "Image 4 (tour room): dark navy background, cyan-outlined props, sparse floating square particles, a flat cyan ground line.",
    "Arrival ladder sits mid-screen from the ceiling, with a 'CLIMB BACK [E]' prompt beside its top as the exit.",
    "Left stop: a framed image (DIAMONDS whitepaper art) on a dark trapezoid pedestal, labelled 'Read the whitepaper'.",
    "Right stop: a video panel with a cyan play triangle on a dark pedestal, labelled 'Watch the video'.",
    "Companion(s) stand on the ground just right of the ladder, between the player and the stops, with a name label above ('The Assay Trio').",
    "Labels use one style: dark rounded-rect background with cyan sans-serif text, floating above each object.",
    "The player is small (about 64 px) relative to the stops, and the companion group is taller than the player.",
    "UI is minimal inside the tour: only menu and fullscreen icons. The main-level HUD (score/tokens/lives) is absent in image 4."
  ],
  "tour_layout_advice": "Build each protocol room as a 2560–3840 px strip with a single flat ground line, and a Camera2D that follows horizontally with its limits clamped to the strip. Place the arrival ladder ('CLIMB BACK [E]') at the far left, with the companion spawning beside it and a name label overhead. Line up named pedestal stops left to right, spaced about 600–900 px apart so roughly one stop is on screen at a time. For example: 'Arrival/[Leader] Intro' → 'Read the whitepaper' → 'Watch the video' → a protocol-specific stop such as 'Assay Table' or 'Claim Office' → an 'End/Return' marker. Keep every stop in the cyan-outline pedestal and dark-label style from image 4, with an [E] interact prompt when the player is in range. Have the companion walk ahead to the next unvisited stop and idle there, facing the player, to give the guided walking-tour feel."
}
```