# Lil Blunt: The Smoke Realm — Web Deployment

Mobile-first PWA launcher for the Godot game.

## What's Included

- **`index.html`** — Beautiful launcher with title screen, daily challenges, achievements
- **`styles.css`** — Mobile-first responsive design with safe-area support
- **`launcher.js`** — Game state, combo system, achievements, leaderboard
- **`manifest.json`** — PWA manifest (Add to Home Screen on iOS/Android)
- **`service-worker.js`** — Offline caching
- **`icon.svg`** — Game icon

## Features Built In

### Mobile-First
- Auto-fullscreen on play
- Safe area insets for notched devices
- Portrait + landscape support
- Haptic feedback on combos and achievements
- Prevents double-tap zoom and pinch zoom
- Touch-optimized buttons with active states

### Addictive Hooks
- **Combo system** — Chain collectibles for up to 5x score multiplier
- **Daily challenges** — Rotating goals reset at midnight with timer
- **Daily streak tracker** — Rewards consecutive play days
- **12 achievements** — From first step to flawless clears
- **Leaderboard** — Compare against fictional rivals (real online when enabled)
- **High score persistence** — Saved locally between sessions
- **Loading tips** — 10 gameplay hints rotate during load

### PWA Capabilities
- **Add to Home Screen** — Install on iOS/Android like a native app
- **Offline play** — Service worker caches all assets
- **No app store needed** — Just share a URL

## How to Deploy

### Step 1: Export the Godot Game

1. Open the project in Godot 4.3
2. **Project → Export → Add Preset → Web**
3. Set **Export Path** to `web/game/index.html`
4. Click **Export Project** (uncheck "Export With Debug")

This creates `web/game/index.html`, `index.js`, `index.pck`, `index.wasm`, and audio worklet files.

### Step 2: Test Locally

```bash
cd web
python3 -m http.server 8000
# Open http://localhost:8000 in a browser
```

### Step 3: Deploy

**Option A — Netlify (easiest):**
1. Drag the entire `web/` folder to https://app.netlify.com/drop
2. Get an instant live URL

**Option B — GitHub Pages:**
1. Push to a `gh-pages` branch with `web/` contents at root
2. Enable Pages in repo settings

**Option C — Any host:**
1. Upload `web/` folder contents to your web server
2. Make sure server sends `Cross-Origin-Embedder-Policy: require-corp` and `Cross-Origin-Opener-Policy: same-origin` headers (required for Godot 4 web exports with SharedArrayBuffer)

For Netlify add a `_headers` file:
```
/*
  Cross-Origin-Embedder-Policy: require-corp
  Cross-Origin-Opener-Policy: same-origin
```

## Launcher → Game Communication

The launcher listens for `postMessage` events from the Godot game:

```gdscript
# In Godot, post to the launcher (combo_system.gd already does this):
JavaScriptBridge.eval("window.postMessage({type: 'combo', value: 5}, '*')")
```

Supported event types:
- `combo` — Update combo display, trigger achievements
- `score` — Update high score
- `coins` — Track lifetime coins (50/500 achievements)
- `diamond` — Track lifetime diamonds
- `achievement` — Unlock a specific achievement by id

## Client Experience

When your client opens the URL:
1. Beautiful animated launcher with Lil Blunt logo
2. Their progress shows (high score, streak, diamonds)
3. Today's daily challenge with countdown timer
4. Big PLAY button — taps to launch the game
5. Game runs fullscreen with touch controls
6. Achievements pop up as toasts
7. Can install to home screen for native feel
