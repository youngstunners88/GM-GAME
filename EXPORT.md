# Exporting Lil Blunt: The Smoke Realm to Web

This guide covers exporting the Godot game for web deployment to Vercel/Netlify.

## Quick Start (Using Script)

If you have Godot 4.3 installed and in your PATH:

```bash
chmod +x scripts/export-web.sh
./scripts/export-web.sh
```

The script will:
1. Locate your Godot installation
2. Create the export preset (`export_presets.cfg`)
3. Export to `web/game/`
4. Verify the output files

Then push:
```bash
git add web/game/
git commit -m "build: export Godot game to web"
git push
```

---

## Manual Export (Godot UI)

If the script doesn't work or you prefer the GUI:

### Step 1 — Open Godot 4.3

```
File → Open Project → [Select this repo]
```

### Step 2 — Add Web Export Preset

```
Project → Project Settings → Export...
  → Click "Add Preset" → Select "Web"
  → Export Path: web/game/index.html
```

### Step 3 — Export

```
→ Select the "Web" preset
→ Click "Export Project"
```

### Step 4 — Verify Output

Check that these files exist in `web/game/`:

- `index.js` — JavaScript engine loader
- `index.wasm` — Game binary (WebAssembly)
- `index.pck` — Game assets pack
- `index.html` — Fallback loader page

### Step 5 — Commit & Push

```bash
git add web/game/
git commit -m "build: export Godot game to web"
git push
```

---

## Troubleshooting

**Script not executable?**
```bash
chmod +x scripts/export-web.sh
```

**Godot not found?**
Set the `GODOT` environment variable:
```bash
GODOT=/path/to/godot ./scripts/export-web.sh
```

**Export fails?**
- Ensure you're using **Godot 4.3** (not 4.2 or earlier)
- Check that `project.godot` exists in the repo root
- Try exporting from the Godot UI to see error details

**Files are huge?**
- Check that compression is enabled in the export preset
- WASM + assets typically ~50–100MB

---

## After Export

Once exported, the game is ready to deploy:

### Option 1 — Vercel (Recommended)

```bash
npx vercel deploy --prod
```

### Option 2 — Netlify

```bash
npx netlify deploy --prod --dir=web
```

### Option 3 — GitHub Pages

```bash
git push origin claude/setup-game-dev-environment-itWJv
# Then enable GitHub Pages from master/main in settings
```

---

## File Structure

After export, your `web/` folder looks like:

```
web/
  index.html          # Launcher UI
  launcher.js         # Launcher logic
  styles.css          # Launcher styles
  manifest.json       # PWA config
  service-worker.js   # Offline caching
  icon.svg            # PWA icon
  game/
    index.js          # ← Exported by Godot
    index.wasm        # ← Exported by Godot
    index.pck         # ← Exported by Godot
    index.html        # ← Can be deleted (we use root index.html)
    ...
```

The launcher (`index.html`) automatically loads the game from `game/index.js`.

---

## What the Launcher Does

- **Beautiful mobile UI** — Shows Lil Blunt, daily challenge, achievements
- **Detects exported game** — Checks for `game/index.js` before trying to boot
- **Combo system** — Tracks collectible streaks with score multipliers
- **Achievements** — Unlocks on gameplay events (levels, combos, etc.)
- **PWA support** — Install to home screen on iOS/Android
- **Offline play** — Service worker caches assets
- **Haptic feedback** — Vibration on combo milestones

---

## Next Steps

1. **Export the game** using one of the methods above
2. **Test locally** — Open `web/index.html` in a browser (or run `npx serve web`)
3. **Deploy** — Push to Vercel/Netlify (auto-deploys from git)
4. **Share with client** — Send the live URL to Rich
