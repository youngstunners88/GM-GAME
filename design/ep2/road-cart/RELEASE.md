# Animated desert-road cart: verified release

Source commit: `0e3383daf2af6d106f9fb9b70387ae82ebc18bd2`.
Production CI: [40212082180](https://github.com/youngstunners88/GM-GAME/actions/runs/40212082180), export job121225261426, completed/success. The full repository gates passed, including twelve motion/contact checks and36 isolated exported-cart resource checks. Export stayed nonthreaded and under the unchanged190MiB per-file gate. Title-screen lock and access controls remain intact.

The actual butler upload reused79.93% and added63.80MiB fresh data. Its terminal log at2026-10-25T16:58:35.6051282Z says `Pushed to https://youngstunners88.itch.io/smokerealm`. This was an upload, not a skipped deployment step.

Public verification on2026-10-26: the real Chromium browser printed BUILD `2026-10-25-0e3383d`; the extras request returnedHTTP200 and the game logged `[EP2] extras ready (ready)`. The public access-code screen remains in place. No public unlock/debug route was added or used.

The exact public files were downloaded from the page's served itch frame: main198599104B, extras98983008B. Their SHA512 digests, frame URL and checks are in `verification/public-release.json`. From an empty project, the mounted public packs pass all36 imported-resource checks with no source-GLB fallback: skins, clips, textures and both axle pivots are actually in the deployed payload.

The actual compiled WoodsQuad encounter was then replayed locally with those PUBLIC packs and an external test fixture (never shipped). It passes the full pass sequence:5.1m/s near the farmer, real wave, cart state3 after passing, and `vo_bull_cart1 → vo_bull_cart2 → vo_cart_man → vo_lb_cart`. The downloaded build's passenger-camera greeting was rendered in Godot4.3 Compatibility and visually reviewed: `verification/public-passenger-greeting.png`. This proves the deployed encounter bytes were exercised; it does not claim a full public-browser/phone playthrough beyond the preserved access gate. Source motion/contact and full repository regression checks also passed in production CI.

Actual Meshy spend:65 of the authorized150 credits, with no paid reruns. Game Development Studio's CLI and the documented Blender5.2 executable were unavailable; the verified Blender4.3.2/Godot4.3 fallback completed authoring, integration and rendering. See the adjacent README, provenance and editable sources for rig conventions and reproduction.

The release receipt was added after refreshing master and preserving concurrent NFT release documentation and CI's generated export commit. No runtime changes are part of this receipt update.
