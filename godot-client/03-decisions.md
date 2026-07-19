# godot-client — decision log (append-only)

- **2026-07-10 · Procedural-first art pipeline.** Ship with generated/procedural
  visuals (Muapi Flux + code), swap to hand-drawn when the client provides
  frames. Keeps velocity; art lands as data, not refactors.
- **2026-07-12 · Non-threaded web export, forever.** Threaded builds need
  SharedArrayBuffer → silent boot failures on itch/iframes/mobile. Root cause
  of "sometimes doesn't play". Enforced by sentinel DEP-001.
- **2026-07-12 · No fake wallet UX.** Demo wallet removed; reintroduced later
  ONLY as real user-signed integration (TRUST-001 rewritten to enforce).
- **2026-07-18 · One network seam.** All online features route through the
  `Web3Bridge` autoload; every method degrades gracefully. UI never owns state.
- **2026-07-18 · Eval hygiene.** Anything interpolated into
  `JavaScriptBridge.eval` passes `_hex()` (^0x-hex only) or the fixed
  postMessage template. Enforced by sentinel INJ-003.
- **2026-07-19 · State beacon for verification.** StateMachine posts
  `{type:"state"}` via same-origin postMessage; browser-verify requires a real
  `PLAYING` — "no console errors" alone false-passed a missed click.
- **2026-07-19 · Adaptive difficulty is invisible and only ever softens.**
  Per-player, bounded (−15% patrol / warning puff / +1 checkpoint / hint) —
  never announces itself, never hardens, no leaderboard value derivable.
- **2026-07-19 · ICM: no physical move to `godot-client/`.** res:// paths,
  CI triggers, and the export pipeline key off `src/`; relocation = pure risk,
  zero function. This folder is the ICM catalog node routing to `src/`.
- **2026-07-19 · Offline is a mode, not an error.** Backend-configured but
  unreachable → banner + local leaderboard cache + in-persona static-FAQ
  Oracle + queued analytics that flush silently on reconnect. No backend
  configured → quiet (pre-deploy state must not nag players).
- **2026-07-19 · Onboarding privacy copy is architecture-backed.** "We don't
  store your address" is enforced by the stateless /balances read; the one
  opt-in exception (leaderboard submit) is disclosed in the Learn More modal.
