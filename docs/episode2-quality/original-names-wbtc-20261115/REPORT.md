# Original weapon names and Episode 1 WBTC

Restored Winchester 1886, Golden Remington 1875, Recovered Bear Bow, Bergmann MP18, Borchardt C-93 and Sharps 1874 in the shared handling/inventory names and counter catalogue. The actual lever shotgun remains a Winchester 1887 (its old coach-gun model has been replaced). Save IDs, weapons, ammunition, prices and acquisition locks are preserved.

Rich already accepted WBTC through GameManager.purse_balance/spend and GoldMineSystem.wbtc_balance. The counter hid this behind cycling a default BTC balance. It now lists all accepted currencies and opens on the largest funded balance when the selected balance is empty. A funded selection stays selected. No conversion or extra WBTC is awarded. Tap the payment strip or use left/right to change tender.

Names fit the existing card/row widths; long counter tab labels use shorter model labels. Native gameplay-camera captures cover desktop, portrait and landscape counter layouts, equipped firearms, and Tabs.

## Verification

- Pinned Godot 4.3 checksum verified; native ORIGINAL_NAMES_WBTC: 20 checks passed. Real Episode 1 pickup (100 gross -> 60 WBTC under the existing short-pool rule), protocol save/load, WBTC-only counter selection, Shipment, Sharps, all seven other weapons, ammunition, locked stock refusal, duplicate refund, insufficient funds, independent balances, selection retention and switching.
- New transaction gate is in the existing CI test block.
- Actual Compatibility-rendered town camera and UI inspected at 1280x720, 390x844 and 844x390. These are simulated viewports, not a physical phone test.
- Local suite: 116 retained logs aggregated with corrected armory tests rerun, plus full script compile and texture-reference probes. The documented pause-menu geometry exception matches repository policy. Complete master CI subsequently passed every gameplay/render/export/security gate.
- Fresh web base pack and published base pack: 199,192,576 bytes, under the 199,229,440-byte cap. Export stays nonthreaded.
- Source `901784b7e4d0c3769edb6e56197f533574f4f9cf`, [release run](https://github.com/youngstunners88/GM-GAME/actions/runs/43715825769): actual butler upload succeeded. Public BUILD `2026-11-15-901784b`, core/extras loading and keyboard input at the preserved access gate verified.
- The exact downloaded published base pack passed all 20 transaction checks. The prior public pack failed the two intended acceptance differences (restored names and funded WBTC default), confirming this test uses the exported implementation.
- Public browser verification used trusted Node TLS and a verified curl-backed streaming relay for the packs because Chromium uses a separate trust store and CDP messages cap at 100 MiB. Scoped loopback permissions were granted to the isolated test context. No TLS bypass. A cloud-browser audio worklet network error remains a test limitation; no audio code changed and audio is not claimed verified there. Weapon transactions were tested natively against the published pack, not manually purchased through the public access gate.
- Receipt: `release-receipt.json`; concise native/public results: `validation.txt`; real upload notice: `upload-proof.txt`.

Reproduce visual captures with `tools/ep2_shots/original_names_wbtc_shot.tscn`; output is `.farm/original-names-wbtc/`. Capture scenario uses a test-only local WBTC balance and production purchase functions, not a production URL hook.
