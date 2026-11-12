# Episode 1 vault floor protocol branding

World-space decoration in `src/level/vault_realm.gd`, built once after Mira/Gideon setup. The strip is centred near each attendant, at `FLOOR_Y + 60`, above the deck and behind the characters. Both original logo textures flank an outlined 48px exact domain; both logos are 88px high with their original aspect ratio. The diamond fallback path is retained. Label metrics resolve after entering the scene tree, avoiding overlap.

Mira's existing holdings hint was moved from canvas y596 to y672 so it cannot mask the floor URL while her panel is open. Its copy and behavior are unchanged.

No collision/input nodes were added. No Episode 2, pit geometry, music, dialogue, staking math, Smoke Lounge signs or title assets were changed. No panel footer was needed.

Validation pending final route captures, full headless gates, fresh pack-size gate and public release verification. Local pinned Godot 4.3 non-threaded export: zero script/parse errors. Four selected vault suites passed before the font-metrics correction; final wider gate includes the actual touch dialogue suite again. Background art, harness and front-page locks pass; security sentinel reports no high-severity blockers.

The existing Game Development Studio CLI and a packaged preflight script were unavailable; the repository's Godot/Playwright release workflow was used.

The fresh pack initially exceeded the 190 MiB gate by 2,400 bytes. The export filter now excludes `src/assets/logos/founder/ref_fud_reject.png`, a review screenshot mentioned only in a code comment, with no runtime resource reference. The source image is preserved. This is the only release-configuration change.
