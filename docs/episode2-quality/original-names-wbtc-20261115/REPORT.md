# Original weapon names and Episode 1 WBTC

Restored Winchester 1886, Golden Remington 1875, Recovered Bear Bow, Bergmann MP18, Borchardt C-93 and Sharps 1874 in the shared handling/inventory names and counter catalogue. The actual lever shotgun remains a Winchester 1887 (its old coach-gun model has been replaced). Save IDs, weapons, ammunition, prices and acquisition locks are preserved.

Rich already accepted WBTC through GameManager.purse_balance/spend and GoldMineSystem.wbtc_balance. The counter hid this behind cycling a default BTC balance. It now lists all accepted currencies and opens on the largest funded balance when the selected balance is empty. A funded selection stays selected. No conversion or extra WBTC is awarded. Tap the payment strip or use left/right to change tender.

Names fit the existing card/row widths; long counter tab labels use shorter model labels. Native gameplay-camera captures cover desktop, portrait and landscape counter layouts, equipped firearms, and Tabs.

## Verification

- Pinned Godot 4.3 checksum verified; native ORIGINAL_NAMES_WBTC: 20 checks passed. Real Episode 1 pickup (100 gross -> 60 WBTC under the existing short-pool rule), protocol save/load, WBTC-only counter selection, Shipment, Sharps, all seven other weapons, ammunition, locked stock refusal, duplicate refund, insufficient funds, independent balances, selection retention and switching.
- New transaction gate is in the existing CI test block.
- Actual Compatibility-rendered town camera and UI inspected at 1280x720, 390x844 and 844x390. These are simulated viewports, not a physical phone test.
- Full CI-equivalent regression suite, fresh export, security/front-page checks and publication: pending at this commit. Do not infer live release from this report; consult the final receipt.

Reproduce visual captures with `tools/ep2_shots/original_names_wbtc_shot.tscn`; output is `.farm/original-names-wbtc/`. Capture scenario uses a test-only local WBTC balance and production purchase functions, not a production URL hook.
