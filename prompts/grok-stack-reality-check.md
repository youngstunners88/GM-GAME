# Task: which of these 10 security categories are REAL for this project, and which are theatre?

A general "secure build checklist" written for Next.js/Supabase/npm SaaS is being installed
into a **Godot 4.3 GDScript game exported to HTML5 and hosted on itch.io**.

Architecture facts you must reason from, not around:
- No backend, no database, no server routes, no auth, no user accounts, no payments.
- The entire shipped artefact is static files: `index.html`, `index.pck`, `index.wasm`.
- There IS a wallet-connect UI that calls `window.ethereum` (user signs; no key handling).
- CI is GitHub Actions; it exports the game and pushes to itch.io via `butler`.
- Web export MUST stay non-threaded (`variant/thread_support=false`) or it fails to boot.

@include docs/security/secure-build-checklist-reference.md
@include .github/workflows/export-game.yml

## Deliver
1. For each of the 10 numbered categories, a verdict: **APPLIES**, **SKIP**, or **MANUAL**,
   with one line of reasoning tied to the architecture above. Be honest where a category
   genuinely does not apply — a checklist that "passes" 40 irrelevant checks is worse than
   no checklist, because it manufactures confidence.
2. The inverse, and this is the part I actually want: **what is a REAL risk for this
   specific project that the checklist does NOT cover at all?** Think about what a static
   game bundle on a third-party host with a crypto wallet UI and a CI deploy key actually
   exposes. At least 5 concrete items, each with why it matters here.
3. Of the categories you marked SKIP — for each, name the specific architectural change
   that would make it APPLY again (e.g. "the moment a leaderboard exists"). This is the
   re-audit trigger list.
4. Rank everything you flagged by real-world exploitability for THIS project, most severe
   first. Do not pad the list to look thorough.

Terse. No preamble.
