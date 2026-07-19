# Android Export Security — manual checklist (RedHook-inspired)

**Current state: the game has NO Android export preset** (web-only:
itch.io + mirrors). This checklist is the mandatory gate for the day an
Android build is added — checked into the repo now so the requirement can't
be forgotten then. Source: secure-build-checklist PLAT001–007 (platform
privilege & control-plane abuse) + the skill's RedHook addendum.

## Before the FIRST Android release build (all boxes required)

### Debug surfaces
- [ ] Export preset uses **release** keystore; `debug=false`; no
      `android:debuggable` in the manifest.
- [ ] No Wireless ADB enablement, no self-pairing, no code that toggles
      Developer Options (the skill treats these as control-plane abuse).
- [ ] Godot remote debug / live-reload flags OFF in the export preset.
- [ ] No `JavaScriptBridge`-equivalent debug consoles reachable in release.

### Permissions (least privilege)
- [ ] Manifest requests ONLY: `INTERNET`. Everything else is justified in
      writing here or removed. Expected NOT present: storage, contacts,
      camera, mic, location, accessibility services, overlay
      (`SYSTEM_ALERT_WINDOW`), device admin, `QUERY_ALL_PACKAGES`,
      boot receivers, foreground services.
- [ ] No runtime permission is requested before the feature needing it runs.

### Control-plane review (enumerate and justify — skill mandate)
- [ ] Accessibility/automation services: none.
- [ ] Overlays / screen capture: none.
- [ ] Package install / update mechanisms: none beyond the store's.
- [ ] Remote command channels: none — the Worker API is request/response
      only; the game never polls for executable instructions.
- [ ] Uninstall leaves nothing behind (no device-admin lock, no residual
      services).

### Release artifact hygiene
- [ ] APK/AAB built in CI from a tagged commit; keystore held by the client,
      never committed (gitleaks + sentinel SEC checks already cover this).
- [ ] `bun scripts/security-audit.ts --fail-on=high` green on the release
      commit (PLAT checks flip from manual to enforced where patterns allow).
- [ ] Wallet flows re-tested on mobile: system browser/wallet-app handoff
      only — never an embedded webview asking for keys (TRUST-001 spirit).

**Owner:** whoever adds the Android preset. **Enforcement:** the export
preset lands in `export_presets.cfg` via PR — that PR must check every box
above in its description.
