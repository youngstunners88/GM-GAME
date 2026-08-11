# Lead task: design a runnable secure-build-checklist audit for a Godot 4.3 HTML5 game

The founder approved installing a general "secure build checklist" pack as a Claude Code
skill at `.claude/skills/secure-build-checklist/` with:
`SKILL.md`, `assets/checklist.json`, `references/checklist.md`, `scripts/audit.ts`
(run with `bun scripts/audit.ts . --fail-on=high --verbose|--json`).

The pack was written for a Next.js/Supabase/npm SaaS. **This project is not that.**
It is a Godot 4.3 GDScript game exported to HTML5 and hosted on itch.io: no backend,
no database, no auth, no payments, no user accounts, no server routes. There IS a
wallet-connect UI that uses `window.ethereum` (user-signed, no key handling).

The founder's explicit adaptation rules:
- Critical/High from REAL greps (secrets in tree, eval/RCE, unsafe shell) -> BLOCK deploy.
- Supabase RLS / `VITE_`-style client-bundled secrets -> SKIP with a reason if no such stack.
- npm audit / lockfile -> run if Node tooling exists, else mark N/A.
- Sentry/PostHog error tracking -> should PASS if already wired; if it fails, fix the
  config, do NOT invent a stack.
- ToS / Privacy Policy -> MANUAL, ask the founder; do NOT invent legal pages.
- DeFi / Solidity -> SKIP unless contract artefacts appear.
- Android Wireless ADB / control-plane -> SKIP for the web build; note for a future APK.
- **Do not fake a pass.** A skipped check must carry a machine-readable reason.

There is ALREADY a project-specific scanner, `scripts/security-sentinel.sh` (18 checks).
The new checklist is ADDITIVE and must not replace or duplicate-with-drift.

## Files
@include docs/security/secure-build-checklist-reference.md
@include scripts/security-sentinel.sh

## Deliver
1. **`assets/checklist.json` schema.** Propose the exact JSON shape for a rule: id,
   category, severity, what it detects, how (glob + regex, file-exists, command), and
   how a SKIP is expressed so a skip can never read as a pass. Show 6 representative
   rules fully populated for THIS project, spanning: a real secret grep, a dynamic-exec
   grep, a Godot-specific deploy rule, a legitimately-skipped SaaS rule, a MANUAL rule,
   and a rule that shells out.
2. **`scripts/audit.ts`** — complete TypeScript for Bun. Must: load the JSON, walk the
   repo respecting .gitignore, run each rule, print a human table under `--verbose` and
   a machine object under `--json`, exit non-zero only at or above `--fail-on`, and
   report skip/manual counts separately from passes. No external npm dependencies —
   Bun built-ins only.
3. **Category mapping table** — for each of the 10 categories in the reference doc, say
   whether it APPLIES / SKIPS / IS MANUAL for this project, with a one-line reason.
4. **Overlap map** vs the 18 sentinel checks: which new rules duplicate a sentinel check
   (name it), and which are genuinely new coverage.
5. Anything in the pack that would produce a **false PASS** on a Godot project — i.e. a
   check that trivially passes because the pattern it looks for cannot exist here, and
   would therefore create false confidence.

Code, not essays. TypeScript must be complete and runnable.
