# Golden revolver textures: lossless -> lossy (pack-size fix, 2026-10-18)

The four extracted revolver textures in `src/episode2/assets/weapons/armory/` (`golden_revolver_{founder,gun}_rev_{albedo,normal}.jpg`)
had no tracked `.import` files, so a FRESH CLONE (CI, `scripts/pack-gate-fresh.sh`) imported them with Godot's default
`compress/mode=0` (lossless): a 1024x1024 albedo packed at 1.82 MB. That put the combined build 3,944,944 B over the 199,229,440 B gate
once the 20 stripped textures were restored. Now tracked with `compress/mode=1` (lossy), `compress/lossy_quality=0.85`, the same as the
rifle's textures.

| texture | before (pck) | after (pck) |
|---|---|---|
| founder albedo / gun albedo | 1.82 / 1.81 MB | 0.24 / 0.24 MB |
| founder normal / gun normal | 0.91 / 0.90 MB | 0.06 / 0.06 MB |

Proof it is invisible (`tools/ep2_shots/armory_shot.tscn`, same room, same camera, real Compatibility renders, before vs after):
- Winchester shot (no revolver): identical, 0 pixels differ.
- Revolver shots: mean abs difference 0.20 / 255, PSNR 48.8-50.2 dB, 0.075-0.142 % of pixels differ by more than 8 levels,
  at most 0.005 % by more than 24 (edge pixels). Inventory shot PSNR 67 dB.
- `before_lossless_3_remington_ads.png` and `after_lossy_3_remington_ads.png` side by side: no visible difference.
Rule applied: `.claude/skills/ship-visual-proof/SKILL.md`.
