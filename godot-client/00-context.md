# godot-client — the game itself

**One job:** everything the player sees and plays. Godot 4.3, GDScript,
non-threaded HTML5 export.

**Layers served:** 📖 Book (the complete platformer — must always run with
zero backend/wallet) + the in-game seams of 🎬 Movie and 🎮 Video Game
(wallet perks, adaptive difficulty, secret walls, snapshot shares).

**Physical location (catalog holds no books):**
- `src/` — all scenes + scripts (`autoload/`, `player/`, `level/`, `boss/`,
  `enemies/`, `ui/`, `npc/`, `combat/`, `collectibles/`, `dashmode/`)
- `project.godot` — autoloads + input map · `web/web3.js` — browser wallet half
- `config.json` — runtime wiring (contracts, backend URL; NEVER hardcode)

**Depends on:** `backend/` for every online feature via ONE seam —
`src/autoload/web3_bridge.gd`. Nothing else may call the network.
**Depended on by:** `marketing/` (in-game share/referral/email-capture surfaces).

**House rules:** every online call degrades gracefully; `gdparse` before
commit; `scripts/kimi-review.sh` for cheap pre-merge review; web-export
compiler rejects `:=` Variant inference from array-index/`.get()` — type it.
