# Evidence — B. Readable menu  &  C. Rabby wallet

## B — root cause & fix
Layer-shift menu column was 240×36 buttons at font 14 over the forest art —
too small/low-contrast to read without browser zoom. Fixed in
`src/ui/main_menu.gd`: 300×46 buttons, font 20, a solid dark StyleBoxFlat
plate (82% alpha) behind each label for contrast, hover/focus plate variants
(keyboard focus visible), and the column repositioned to fit the taller stack
without clipping off-screen.

## B — verification
menu-after-corrections.png (from the REAL local web export) shows all 8
layer-shift buttons rendered large, on dark plates, fully legible over the
artwork. PASS.

## C — root cause & fix
`src/ui/crypto_onboarding.tscn/.gd` had a "GET METAMASK" button + MetaMask
setup copy + metamask.io link — the only player-facing wallet-brand reference.
`web/web3.js` already uses plain `window.ethereum` (Rabby injects the same
EIP-1193 interface), so the BRIDGE was already Rabby-compatible; only branding
was MetaMask. Rebranded: button "GET RABBY" → rabby.io, copy references Rabby's
setup, main-menu wallet button "CONNECT RABBY" / "CONNECT WALLET" statuses →
"CONNECT RABBY". `grep -c metamask` on both onboarding files = 0.

## C — verification
menu-after-corrections.png shows "CONNECT RABBY" as the top menu button. The
existing `web3_bridge.connect_wallet()` (30s poll loop + connectError channel,
from the Kimi pass) handles unavailable/locked/rejected/timeout — provider
access stays in the ONE bridge, not scattered. Wallet never blocks play
(degrades: no wallet → button explains, game continues). PASS (player-facing
brand is Rabby; historical note kept in this evidence + investigation.md).
