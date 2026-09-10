---
name: ep2-security-and-trust-audit
description: Episode-2-specific security surface — the client/server trust boundary for value-bearing outcomes, Proof-of-Play spoofability, config and setup-script hygiene, and the web-export pack budget. Complements scripts/security-sentinel.sh (which stays the single implementation of the 18 baseline checks); this adds the value-authority analysis the sentinel does not cover. Use before any on-chain wiring, before adding a chamber that grants rewards, and before any release that changes save/load, config, or CI.
user-invocable: true
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Episode 2 Security & Trust Audit

This does **not** duplicate `scripts/security-sentinel.sh`. That script is and
remains the single implementation of the 18 baseline checks (secrets, injection,
deploy config, CI). Run it too — but it answers "are there secrets or dangerous
calls in the tree?", not "**who decides how much GOLD the player earned?**"

That second question is the whole point of this skill.

## Standing context: free-to-play today

The game emits no real funds. The Gold Mine economy is a simulation in
`goldmine_system.gd`. **This does not make the findings theoretical.** Every
client-authoritative decision documented here becomes a live mint the day the
economy is wired to chain actions or Proof-of-Play. Record them now, while
they're cheap to fix, and treat this file as the checklist that on-chain wiring
must clear before it ships.

## 1. Trust-boundary map (the core deliverable)

The shipped artifact is a **web/mobile export**. Everything in the pack runs on
hardware the player controls. GDScript in `index.pck` is not obfuscated in any
meaningful sense, `localStorage`/IndexedDB is editable, and a determined player
can patch the wasm or simply write the save file directly.

Produce a table with one row per value-bearing outcome:

| Outcome | Computed where | Authoritative? | What a tampered client could forge |
|---|---|---|---|

Rules for filling it in:
- **"Authoritative" means: could a server or chain independently verify this?**
  If the only evidence is the client's assertion, the answer is No — regardless
  of how carefully the client computes it.
- Every **No** row is a finding to resolve before on-chain wiring. Do not
  silently assume client honesty, and do not downgrade a row because the value
  is currently simulated.
- Include the **save/load path** explicitly. `load_save_data()` assigns every
  balance straight from a `Dictionary` with no validation, bounds, or signature
  — it is the single widest hole, because it bypasses every function-level guard
  the economy has.

### Known client-authority holes (keep this list current)

| Hole | Mechanism |
|---|---|
| Save/load | `load_save_data()` sets every balance directly from an untrusted dict; no clamping, no negative rejection, no integrity check |
| Unvalidated stake input | `melt_gold(amount, staked_amount)` mints shares proportional to a caller-supplied `staked_amount` never checked against real holdings |
| Unbounded auction multiplier | `settle_auction(user_contribution, total_pool)` computes `contribution / pool` with no clamp to `[0, 1]` |
| Treasury mint | `distribute_treasury_revenue(total_revenue)` credits from a caller-supplied number with nothing debited |
| Reward computation | the chamber computes `gold_awarded`/`gold_forfeited` client-side; the root commits what the chamber says |

## 2. Proof-of-Play spoofability

Ask directly: **can "play happened" be asserted without playing?**

Today the answer is yes — the loop is entirely client-side, and any reward is
whatever the client reports. Document the concrete forgeries:
- Call the commit path directly without running a chamber.
- Replay a legitimate outcome N times.
- Edit the save to a post-reward state and skip the play entirely.

The mitigation direction (for the on-chain design, not this audit's scope) is
server-verifiable play evidence: a seeded run whose inputs replay to the claimed
outcome, verified off-client. Note it as a design requirement; do not
half-implement it here.

## 3. Config & setup-script hygiene

This repo has real history here: the setup script was once corrupted with live
API keys, an MCP registration, and stray tool-onboarding prose, which broke
session startup with **exit 127**. Verify the residue is gone and cannot return.

The rule: **the setup script contains only provisioning bash.** No secrets, no
bare URLs, no natural-language instructions, no MCP registrations, no
tool-onboarding text.

```bash
# Setup script / config hygiene sweep
for f in $(ls .devcontainer/*.sh scripts/setup*.sh 2>/dev/null) .mcp.json .claude/settings.json; do
  [ -f "$f" ] || continue
  echo "--- $f"
  grep -nE 'https?://[^ )"]+' "$f" | grep -vE '^\s*#' && echo "  ^ bare URL"
  grep -nE '(api[_-]?key|secret|token|Bearer)[[:space:]]*[=:]' "$f" && echo "  ^ possible secret"
  grep -nE 'mcp (add|install)|mcpServers' "$f" && echo "  ^ MCP registration"
done
```

Also verify:
- `.claude/settings.json` `enabledMcpjsonServers` contains no entry that is
  undefined in `.mcp.json` — an enabled-but-undefined server is a dead
  reference (this repo carried `xdevplatform-xmcp` as exactly that).
- **gitleaks allowlist stays narrow**: `.gitleaksignore` entries must be
  per-path/per-fingerprint, never a widened rule that disables a detector
  repo-wide. A broadened rule is a finding even when nothing leaks today.

## 4. Web-export pack budget

`index.pck` must stay under the CI gate of **190 MiB = 199,229,440 bytes**
(itch.io rejects the whole HTML5 embed if any single file exceeds 200 MB — that
outage has already happened once here).

```bash
P=web/game/index.pck; B=$(stat -c%s "$P"); GATE=$((190*1024*1024))
python3 -c "print(f'pck {$B} B ({$B/1048576:.2f} MiB), headroom {($GATE-$B)/1048576:.2f} MiB')"
[ "$B" -gt "$GATE" ] && echo "OVER GATE" || echo "under gate"
head -c4 "$P" | od -An -tx1 | tr -d ' '   # expect 47445043 = 'GDPC'
```

Report **exact bytes and headroom**, never "about". Confirm test/audit assets
are excluded (`exclude_filter` drops `docs/`, `tests/`, `prompts/`, `scripts/`)
and that no fixture was added under `src/`.

Music is the usual pressure: the project standard is **128 kbps** for MP3
(`tools/reencode_media.sh`). A client-supplied track at 200+ kbps is roughly
double-size for no audible gain in a browser game — re-encode before committing.

## Relationship to the other gates

| Concern | Owner |
|---|---|
| Secrets, injection, deploy config, CI wiring | `scripts/security-sentinel.sh` (18 checks) — unchanged, run it |
| Broad pre-ship sweep across 11 categories | `secure-build-checklist` skill |
| Value conservation, name-vs-behavior | `goldmine-economy-invariants` |
| Commit-exactly-once, transition guards | `ep2-state-transition-audit` |
| **Who is authoritative over value; spoofability; pack budget** | **this skill** |

When the architecture gains a real surface — a backend, accounts, a
leaderboard, real payments, multiplayer, or on-chain calls — the N/A rows in
`docs/security/GAME_SECURITY_CHECKLIST.md` stop being N/A. Re-audit them
immediately and unprompted; they are N/A *because* the surface doesn't exist
yet, not permanently.
