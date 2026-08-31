<!-- dispatched: moonshotai/kimi-k2-thinking
     prompt: prompts/kimi-false-pass-hunt.md
     files inlined: 2
     tokens: 6466 in / 9697 out
     cost: $0.0281
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
## 1. Checks that **vacuously PASS** (scan nothing yet report "clean")

These are the most dangerous: they give a green light without examining any code.

### **DEP-003: No source maps in shipped bundle**
```bash
maps=$(find web/game -name "*.map" 2>/dev/null || true)
```
- **Why it vacuously passes**: `web/game` is the HTML5 export output directory. It is `.gitignore`d and does not exist in the source repo. `find` silently returns empty, so the check passes without ever seeing the actual shipped artifact.
- **Impact**: Source maps could be deployed to itch.io and expose entire source code; the scanner would still report PASS.
- **Fix**: Change to `SKIPPED-WITH-REASON` if `web/game` is missing, and document that this check must run *after* export, on the artifact itself.

### **SEC-001: No secret-looking strings in shipped paths**
```bash
grep -rEn "$SECRET_PATTERN" web/game src scripts .github 2>/dev/null ...
```
- **Why it vacuously passes**: Scans `web/game` (doesn't exist), `src` (may be empty or non-existent in a fresh clone), `scripts` (may not exist), and `.github` (may not exist). If any path is missing, `grep` skips it silently and returns empty.
- **Impact**: A leaked API key in `src/` would be missed if `src/` were temporarily empty or misnamed.
- **Fix**: Use `git ls-files` (like SEC-005 does) so the check only runs when there are tracked files to scan. If the repo is empty, emit `SKIPPED-WITH-REASON`.

### **SEC-004, INJ-001, INJ-002, INJ-003, INJ-004: All `src/` scanners**
```bash
grep -rEn "0x[a-fA-F0-9]{40}" src/ ...  # SEC-004
grep -rn "OS\.execute" src/ ...          # INJ-001
grep -rn "Expression\.new\|class Expression" src/ ...  # INJ-002
grep -rn "JavaScriptBridge\.eval" src/ ...  # INJ-003
grep -rn "FileAccess\.open(" src/ ...    # INJ-004
```
- **Why they vacuously pass**: If `src/` is empty, missing, or contains no `.gd` files, all return empty and PASS.
- **Impact**: A project restructuring that moves GDScript to `res://scripts/` or `game/` would disable all injection checks.
- **Fix**: Assert `src/` exists and contains at least one `.gd` file; otherwise `SKIPPED-WITH-REASON`.

### **CI-003 & CI-004: Allowlist/ignore-file "narrowness" checks**
```bash
if [ -f .gitleaks.toml ]; then ... else PASS  # CI-003
if [ -f .gitleaksignore ]; then ... else PASS  # CI-004
```
- **Why they vacuously pass**: If the files don't exist, they emit PASS with "no allowlist file" / "no ignore file". Absence of these files is treated as "narrow", but it actually means gitleaks is running with *no* configuration, which is a different risk.
- **Impact**: A misconfigured repo without these files gets a green light even though secret-scanning policy is undefined.
- **Fix**: Report `SKIPPED-WITH-REASON` when the files are absent; only PASS if they exist *and* are narrow.

---

## 2. Checks whose **regex is narrower than the claim**

These PASS while missing patterns the title implies they should catch.

### **SEC-002: .env gitignored**
```bash
grep -qE '^\.env($|\*|\.)' .gitignore
```
- **Claim**: "`.env` gitignored" (implies all env variants)
- **What it misses**: `.env.local`, `.env.production` (the pattern only matches `.env`, `.env*`, or `.env.`; `.env.local` has extra chars after `.env`)
- **Concrete miss**: `.env.local` is not matched; would false-PASS even if committed.
- **Fix**: Use `'^\.env(\.|$|\*)'` to match `.env`, `.env.*`, and `.env*`.

### **SEC-003: .env never committed**
```bash
git log --all ... -- '.env' '.env.local' '.env.production'
```
- **Claim**: "`.env` never committed" (implies any env file)
- **What it misses**: `.env.staging`, `.env.backup`, `.env.secret`
- **Concrete miss**: A committed `.env.backup` is invisible to this check.
- **Fix**: Use glob `.env*` and `.env.*` in the git log query.

### **INJ-002: No Expression (dynamic code exec)**
```bash
grep -rn "Expression\.new\|class Expression" src/
```
- **Claim**: "No Expression ... in game code" (should catch all instantiation)
- **What it misses**: GDScript allows `Expression()` as shorthand for `Expression.new()`. The regex misses `var e = Expression()`.
- **Concrete miss**: `var expr = Expression(); expr.parse("2+2")` would not be flagged.
- **Fix**: Add `Expression\(\)` to the pattern.

### **INJ-004: FileAccess.open never takes a runtime-built path**
```bash
grep -vE 'FileAccess\.open\(([A-Z][A-Z0-9_]*[,)]|"[^"]*"|user://)'
```
- **Claim**: "only targets compile-time consts" (should accept any const)
- **What it misses**: Only accepts **ALL-CAPS** const identifiers like `SAVE_PATH`. A const like `const SavePath = "user://save.dat"` (mixed case) is flagged as "dynamic".
- **Concrete miss**: `FileAccess.open(SavePath, READ)` where `SavePath` is a mixed-case const would false-FAIL.
- **Fix**: Accept any identifier that follows GDScript const naming (e.g., `[A-Za-z_][A-Za-z0-9_]*` and verify it's a const via AST or accept that any identifier is likely a const in Godot style).

### **DEP-001: Web export stays non-threaded**
```bash
grep -q "thread_support=false" .github/workflows/export-game.yml
```
- **Claim**: "Web export stays non-threaded"
- **What it misses**: `thread_support = false` (spaces around `=`) or `thread-support: false` (YAML format).
- **Concrete miss**: `thread_support = false` would false-FAIL even though correct.
- **Fix**: Use `grep -qE 'thread_support\s*=\s*false|thread-support:\s*false'`.

### **DEP-004: Supply-chain downloads checksum-pinned**
```bash
grep -q "SHA512-SUMS\|BUTLER_SHA256" .github/workflows/export-game.yml
```
- **Claim**: "checksum-pinned" (generic)
- **What it misses**: `SHA256-SUMS`, `GODOT_SHA256`, `butler-sha256`, `shasum -c`, etc.
- **Concrete miss**: A workflow that uses `sha256sum --check godot.sha256` would false-FAIL.
- **Fix**: Broaden to match any checksum verification pattern (e.g., `SHA(256|512)`, `shasum`, `checksum`).

### **TRUST-001: Wallet UI is real & user-signed**
```bash
grep -qiE "privateKey|private_key|eth_sign\b|signTransaction"
```
- **Claim**: "no private-key handling" (comprehensive)
- **What it misses**: `secretKey`, `signingKey`, `keyMaterial`, `eth_signTransaction`, `personal_sign`, etc.
- **Concrete miss**: `const secretKey = "0x...";` would not be flagged.
- **Fix**: Expand to `privateKey|private_key|secretKey|signingKey|keyMaterial|eth_sign|personal_sign|signTransaction`.

---

## 3. Reference doc checklist categories

The reference doc (`secure-build-checklist-reference.md`) is a pointer to an external skill pack, not a local implementation. No grep patterns are shown, so we cannot evaluate it for false passes. The sentinel script *is* the local implementation; the reference doc is just a redirect.

---

## 4. Minimal honest-fix per finding

| ID | Fix |
|----|-----|
| **DEP-003** | `if [ ! -d web/game ]; then record "DEP-003" "high" "SKIPPED" "No web/game export dir to scan" ""; else ... fi` |
| **SEC-001** | Replace path list with `git ls-files web/game src scripts .github 2>/dev/null | xargs grep ...` or skip if no files found. |
| **SEC-004, INJ-001/2/3/4** | Add `if [ ! -d src ] || [ -z "$(find src -name '*.gd' -type f)" ]; then record ... "SKIPPED" ...; fi` |
| **CI-003, CI-004** | Change `else` clause to `record ... "SKIPPED" "file absent"`; only PASS if file exists *and* is narrow. |
| **SEC-002** | Regex: `'^\.env(\.|$|\*)'` to match `.env`, `.env.*`, `.env*`. |
| **SEC-003** | Use glob: `git log ... -- '.env*' '.*env*'` |
| **INJ-002** | Pattern: `"Expression\.new\|class Expression\|Expression\(\)"` |
| **INJ-004** | Allow any identifier: `FileAccess\.open\(([A-Za-z_][A-Za-z0-9_]*[,)]\|...)` |
| **DEP-001** | Regex: `grep -qE 'thread_support\s*=\s*false\|thread-support:\s*false'` |
| **DEP-004** | Regex: `grep -qiE 'SHA(256|512)|BUTLER_SHA|shasum|checksum'` |
| **TRUST-001** | Regex: `privateKey|private_key|secretKey|signingKey|keyMaterial|eth_sign|personal_sign|signTransaction` |

---

## 5. Checks that **false-FAIL** on correct Godot code

These would train developers to ignore the scanner.

### **INJ-004: FileAccess.open const check**
- **False-FAIL trigger**: `FileAccess.open("res://data.json", READ)` or `FileAccess.open(SavePath, WRITE)` where `SavePath` is a mixed-case const.
- **Why it's wrong**: `res://` is a safe, read-only resource path. Mixed-case consts are standard GDScript style.
- **Impact**: Forces developers to either rename all consts to ALL_CAPS (non-idiomatic) or silence the check.

### **DEP-001: thread_support spacing**
- **False-FAIL trigger**: `thread_support = false` (with spaces) in YAML.
- **Why it's wrong**: This is valid YAML syntax and correctly disables threads.
- **Impact**: CI fails for correctly formatted workflow.

### **SEC-001: Overly broad secret pattern**
- **False-FAIL trigger**: A legitimate comment like `# api-key: "12345678901234567890"` in a config example.
- **Why it's wrong**: The pattern `[A-Za-z0-9+/_-]{20,}` catches any 20+ char alphanumeric string, including documentation placeholders.
- **Impact**: Low signal-to-noise; developers will add broad exclusions.

### **INJ-003: JavaScriptBridge.eval sanitizer check**
- **False-FAIL trigger**: `JavaScriptBridge.eval('window.parent.postMessage("%s")' % [some_var])` where `some_var` is a hex string but not passed through `_hex()`.
- **Why it's wrong**: The check only looks for `_hex(` token, not whether the data is *actually* hex. A provably safe hex string literal would still FAIL.
- **Impact**: Encourages blindly adding `_hex()` wrappers rather than reasoning about safety.

---

**Summary**: The most dangerous false-PASS is **DEP-003** (source maps) because it scans a non-existent export directory. The most misleading narrow regex is **SEC-002** (env files) because it misses standard variants like `.env.local`. The most annoying false-FAIL is **INJ-004** (FileAccess.open) because it enforces non-idiotic ALL_CAPS const names.