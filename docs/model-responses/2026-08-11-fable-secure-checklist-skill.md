<!-- dispatched: anthropic/claude-fable-5
     prompt: prompts/fable-secure-checklist-skill.md
     files inlined: 2
     tokens: 14387 in / 24000 out
     cost: $1.3439
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
# 1. `assets/checklist.json` — schema + 6 populated rules

**Rule shape.** A `status` is only ever computed by the runner from one of five enum values: `PASS | FAIL | SKIP | MANUAL | ERROR`. A skip can never read as a pass because (a) `SKIP` requires a machine-readable `skipReason.code` or the runner emits `ERROR`, (b) skip/manual are counted in separate summary fields, and (c) `MANUAL` rules have no auto-pass path at all.

```json
{
  "version": 1,
  "project": "lil-blunt-adventure (Godot 4.3 GDScript -> HTML5, itch.io, no backend)",
  "schema": {
    "rule": {
      "id": "string, unique",
      "category": "string",
      "severity": "critical|high|medium|low",
      "title": "string",
      "rationale": "string, optional",
      "refs": ["cross-refs to scripts/security-sentinel.sh checks, optional"],
      "detect": "one of: grep | glob | file-exists | command | manual (discriminated on .type)",
      "applies_if": "optional { anyExists: [paths/globs], skipReason: {code, detail} } — if NONE exist, rule is SKIP with that reason and self-arms when the stack appears",
      "skip": "optional static {code, detail} — unconditional SKIP with reason"
    },
    "detect_variants": {
      "grep":        { "globs": ["..."], "exclude": ["..."], "pattern": "regex", "flags": "", "failIf": "match|noMatch" },
      "glob":        { "globs": ["..."], "failIf": "match|noMatch" },
      "file-exists": { "path": "...", "failIf": "missing|present" },
      "command":     { "run": ["argv0", "..."], "timeoutMs": 60000, "failIf": "nonzero|zero" },
      "manual":      { "question": "...", "owner": "founder|engineer" }
    }
  },
  "rules": [
    {
      "id": "CHK-SEC-101",
      "category": "secrets",
      "severity": "critical",
      "title": "No provider token prefixes OUTSIDE sentinel SEC-001's pattern set (ghp_, github_pat_, xoxb-, sk-proj-, whsec_, glpat-)",
      "rationale": "sentinel SEC-001 covers sk_live/sk_test/AKIA/pk_live/PEM/generic key=value. This rule covers ONLY prefixes SEC-001 does not — a disjoint set, so no duplicate-with-drift. Excludes are rule-definition files (same rationale SEC-001 documents for excluding security-audit.ts: the detector names patterns, gitleaks still scans it for values).",
      "refs": ["sentinel:SEC-001 (disjoint pattern set)"],
      "detect": {
        "type": "grep",
        "globs": ["**/*"],
        "exclude": [
          ".claude/skills/secure-build-checklist/**",
          "scripts/security-sentinel.sh",
          "docs/security/secure-build-checklist-reference.md",
          "**/*.wasm", "**/*.pck", "**/*.png", "**/*.jpg", "**/*.ogg", "**/*.import"
        ],
        "pattern": "ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{22,}|xoxb-[0-9A-Za-z-]{10,}|sk-proj-[A-Za-z0-9_-]{20,}|whsec_[A-Za-z0-9]{24,}|glpat-[A-Za-z0-9_-]{20,}",
        "flags": "",
        "failIf": "match"
      }
    },
    {
      "id": "CHK-INJ-101",
      "category": "injection",
      "severity": "critical",
      "title": "No eval()/new Function()/string-timer in the hand-written web shell (web/*.js, web/*.html)",
      "rationale": "sentinel INJ-001..003 cover the GDScript side (OS.execute, Expression, JavaScriptBridge.eval). This covers the JS we author around the export (launcher.js, web3.js). web/game/** is excluded: it is generated Godot/Emscripten engine output whose integrity is owned by DEP-004 checksum pinning, and minified engine code would false-positive.",
      "refs": ["sentinel:INJ-003 (GDScript side only)"],
      "detect": {
        "type": "grep",
        "globs": ["web/*.js", "web/*.html"],
        "exclude": ["web/game/**"],
        "pattern": "\\beval\\s*\\(|new\\s+Function\\s*\\(|set(Timeout|Interval)\\s*\\(\\s*[\"']",
        "flags": "",
        "failIf": "match"
      }
    },
    {
      "id": "CHK-GD-101",
      "category": "deploy-integrity",
      "severity": "high",
      "title": "Shipped web bundle (web/game/) contains no project-internal artefacts (.gd, .import, .cfg, project.godot, .env, .sh)",
      "rationale": "Godot-specific export hygiene: only engine output belongs in web/game/. NOTE: *.map is deliberately NOT in this list — sentinel DEP-003 owns source maps; listing it here would be duplicate-with-drift.",
      "refs": ["sentinel:DEP-003 (source maps, intentionally excluded here)"],
      "detect": {
        "type": "glob",
        "globs": [
          "web/game/**/*.gd", "web/game/**/*.import", "web/game/**/*.cfg",
          "web/game/**/project.godot", "web/game/**/.env*", "web/game/**/*.sh"
        ],
        "failIf": "match"
      }
    },
    {
      "id": "CHK-SAAS-101",
      "category": "ai-code-risks",
      "severity": "critical",
      "title": "Supabase/Postgres tables have RLS enabled AND at least one policy",
      "rationale": "From the source pack. Self-arms if a Supabase/SQL stack ever appears in the tree; until then it is a machine-readable SKIP, never a PASS.",
      "applies_if": {
        "anyExists": ["supabase/**", "**/*.sql", "**/supabase.toml"],
        "skipReason": {
          "code": "no-supabase-stack",
          "detail": "Client-only Godot HTML5 build: no database, no Supabase project, no SQL in tree. Rule re-arms automatically if supabase/ or *.sql appears."
        }
      },
      "detect": {
        "type": "manual",
        "question": "For every table: is RLS enabled AND at least one policy created (ENABLE-only is still allow-all)?",
        "owner": "engineer"
      }
    },
    {
      "id": "CHK-LEGAL-101",
      "category": "legal",
      "severity": "medium",
      "title": "ToS / Privacy posture confirmed by founder for the itch.io page",
      "rationale": "The web build ships Sentry + PostHog telemetry (see analytics.gd sanitizers referenced by sentinel INJ-003), so 'no data collected' is NOT automatically true. Founder decision; the audit must never invent legal pages.",
      "detect": {
        "type": "manual",
        "question": "Given Sentry + PostHog telemetry in the shipped web build: does the itch.io page need a privacy notice, and does one exist? Record the decision in docs/security/audit-log.md.",
        "owner": "founder"
      }
    },
    {
      "id": "CHK-GATE-001",
      "category": "delegation",
      "severity": "critical",
      "title": "Project sentinel (18 project-specific checks) passes at fail-on=high",
      "rationale": "scripts/security-sentinel.sh is the single source of truth for the project-specific greps (SEC-001..005, INJ-001..004, DEP-001..004, TRUST-001, CI-001..004). The checklist delegates instead of re-implementing them — this is the anti-duplicate-with-drift anchor.",
      "refs": ["sentinel:ALL"],
      "detect": {
        "type": "command",
        "run": ["bash", "scripts/security-sentinel.sh", "--fail-on=high"],
        "timeoutMs": 120000,
        "failIf": "nonzero"
      }
    }
  ]
}
```

# 2. `scripts/audit.ts`

```typescript
#!/usr/bin/env bun
// .claude/skills/secure-build-checklist/scripts/audit.ts
// Secure-build-checklist runner — Godot 4.3 HTML5 adaptation.
//
// Usage:
//   bun scripts/audit.ts <root=.> [--fail-on=critical|high|medium|low] [--verbose|--json]
//
// Design notes:
// - No npm dependencies: Bun built-ins + node:fs/node:path only.
// - .gitignore is respected by delegating file discovery to
//   `git ls-files -co --exclude-standard` (tracked + untracked-non-ignored).
//   If git is unavailable, falls back to a plain walk (warns on stderr).
// - Statuses are a strict enum: PASS | FAIL | SKIP | MANUAL | ERROR.
//   A SKIP without a machine-readable reason code becomes ERROR — a skip can
//   never read as a pass, and ERROR always blocks (fail-safe).
// - Exit code 1 only if a FAIL exists at/above --fail-on, or any ERROR.

import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { join, resolve } from "node:path";

type Severity = "critical" | "high" | "medium" | "low";
type Status = "PASS" | "FAIL" | "SKIP" | "MANUAL" | "ERROR";

interface SkipReason { code: string; detail: string }

interface GrepDetect { type: "grep"; globs: string[]; exclude?: string[]; pattern: string; flags?: string; failIf: "match" | "noMatch" }
interface GlobDetect { type: "glob"; globs: string[]; failIf: "match" | "noMatch" }
interface FileExistsDetect { type: "file-exists"; path: string; failIf: "missing" | "present" }
interface CommandDetect { type: "command"; run: string[]; timeoutMs?: number; failIf: "nonzero" | "zero" }
interface ManualDetect { type: "manual"; question: string; owner?: string }
type Detect = GrepDetect | GlobDetect | FileExistsDetect | CommandDetect | ManualDetect;

interface Rule {
  id: string;
  category: string;
  severity: Severity;
  title: string;
  rationale?: string;
  refs?: string[];
  detect: Detect;
  applies_if?: { anyExists: string[]; skipReason: SkipReason };
  skip?: SkipReason;
}

interface Checklist { version: number; project: string; rules: Rule[] }

interface Result {
  id: string;
  category: string;
  severity: Severity;
  status: Status;
  title: string;
  evidence: string;
  skipReason?: SkipReason;
}

const SEV_RANK: Record<Severity, number> = { critical: 0, high: 1, medium: 2, low: 3 };

// ---------------------------------------------------------------------------
// CLI args
// ---------------------------------------------------------------------------
const argv = process.argv.slice(2);
let root = ".";
let failOn: Severity = "high";
let mode: "summary" | "verbose" | "json" = "summary";

for (const a of argv) {
  if (a === "--verbose") mode = "verbose";
  else if (a === "--json") mode = "json";
  else if (a.startsWith("--fail-on=")) {
    const v = a.slice("--fail-on=".length) as Severity;
    if (!(v in SEV_RANK)) { console.error(`audit: unknown --fail-on value '${v}'`); process.exit(2); }
    failOn = v;
  } else if (!a.startsWith("--")) root = a;
  else { console.error(`audit: unknown flag '${a}'`); process.exit(2); }
}
root = resolve(root);

// ---------------------------------------------------------------------------
// Load checklist (sibling assets/ relative to this script)
// ---------------------------------------------------------------------------
const checklistPath = join(import.meta.dir, "..", "assets", "checklist.json");
if (!existsSync(checklistPath)) {
  console.error(`audit: checklist not found at ${checklistPath}`);
  process.exit(2);
}
let checklist: Checklist;
try {
  checklist = JSON.parse(readFileSync(checklistPath, "utf8"));
} catch (e) {
  console.error(`audit: failed to parse ${checklistPath}: ${e}`);
  process.exit(2);
}

// ---------------------------------------------------------------------------
// File discovery — respects .gitignore via git; plain-walk fallback
// ---------------------------------------------------------------------------
function gitFiles(): string[] | null {
  try {
    const proc = Bun.spawnSync(["git", "ls-files", "-co", "--exclude-standard"], { cwd: root });
    if (proc.exitCode !== 0) return null;
    return [...new Set(proc.stdout.toString().split("\n").filter(Boolean))];
  } catch {
    return null;
  }
}

function walkFiles(dir: string, prefix = ""): string[] {
  const acc: string[] = [];
  let entries;
  try { entries = readdirSync(dir, { withFileTypes: true }); } catch { return acc; }
  for (const e of entries) {
    if (e.name === ".git" || e.name === "node_modules") continue;
    const rel = prefix ? `${prefix}/${e.name}` : e.name;
    if (e.isDirectory()) acc.push(...walkFiles(join(dir, e.name), rel));
    else if (e.isFile()) acc.push(rel);
  }
  return acc;
}

let files = gitFiles();
if (files === null) {
  console.error("audit: WARNING — git unavailable; falling back to plain walk (.gitignore NOT respected)");
  files = walkFiles(root);
}

// ---------------------------------------------------------------------------
// Minimal glob -> RegExp (supports **, *, ?; '/' separators)
// ---------------------------------------------------------------------------
function globToRegex(glob: string): RegExp {
  let re = "";
  for (let i = 0; i < glob.length; i++) {
    const c = glob[i];
    if (c === "*") {
      if (glob[i + 1] === "*") {
        if (glob[i + 2] === "/") { re += "(?:.*/)?"; i += 2; }
        else { re += ".*"; i += 1; }
      } else {
        re += "[^/]*";
      }
    } else if (c === "?") {
      re += "[^/]";
    } else if ("\\^$.|+()[]{}".includes(c)) {
      re += "\\" + c;
    } else {
      re += c;
    }
  }
  return new RegExp("^" + re + "$");
}

function matchAny(path: string, globs: string[]): boolean {
  return globs.some((g) => globToRegex(g).test(path));
}

// ---------------------------------------------------------------------------
// Detect runners
// ---------------------------------------------------------------------------
const MAX_FILE_BYTES = 5_000_000;
const MAX_HITS = 10;

function runGrep(d: GrepDetect): { status: Status; evidence: string } {
  let re: RegExp;
  try { re = new RegExp(d.pattern, d.flags ?? ""); }
  catch (e) { return { status: "ERROR", evidence: `invalid regex: ${e}` }; }

  const hits: string[] = [];
  outer: for (const f of files!) {
    if (!matchAny(f, d.globs)) continue;
    if (d.exclude && matchAny(f, d.exclude)) continue;
    const abs = join(root, f);
    let buf: Buffer;
    try {
      const st = statSync(abs);
      if (!st.isFile() || st.size > MAX_FILE_BYTES) continue;
      buf = readFileSync(abs);
    } catch { continue; }
    if (buf.subarray(0, 8000).includes(0)) continue; // binary heuristic
    const lines = buf.toString("utf8").split("\n");
    for (let i = 0; i < lines.length; i++) {
      re.lastIndex = 0;
      if (re.test(lines[i])) {
        hits.push(`${f}:${i + 1}: ${lines[i].trim().slice(0, 160)}`);
        if (hits.length >= MAX_HITS) break outer;
      }
    }
  }
  const matched = hits.length > 0;
  const fail = d.failIf === "match" ? matched : !matched;
  return {
    status: fail ? "FAIL" : "PASS",
    evidence: matched ? hits.join("\n") : "no matches",
  };
}

function runGlob(d: GlobDetect): { status: Status; evidence: string } {
  const matched = files!.filter((f) => matchAny(f, d.globs)).slice(0, MAX_HITS);
  const any = matched.length > 0;
  const fail = d.failIf === "match" ? any : !any;
  return { status: fail ? "FAIL" : "PASS", evidence: any ? matched.join("\n") : "no matching paths" };
}

function runFileExists(d: FileExistsDetect): { status: Status; evidence: string } {
  const present = existsSync(join(root, d.path));
  const fail = d.failIf === "missing" ? !present : present;
  return { status: fail ? "FAIL" : "PASS", evidence: `${d.path}: ${present ? "present" : "missing"}` };
}

function runCommand(d: CommandDetect): { status: Status; evidence: string } {
  let proc;
  try {
    proc = Bun.spawnSync(d.run, { cwd: root, timeout: d.timeoutMs ?? 60_000 });
  } catch (e) {
    return { status: "ERROR", evidence: `spawn failed: ${e}` };
  }
  const out = (proc.stdout.toString() + proc.stderr.toString()).trim();
  const tail = out.length > 400 ? "…" + out.slice(-400) : out;
  const nonzero = proc.exitCode !== 0;
  const fail = d.failIf === "zero" ? !nonzero : nonzero;
  return {
    status: fail ? "FAIL" : "PASS",
    evidence: `exit=${proc.exitCode} :: ${tail || "(no output)"}`,
  };
}

// ---------------------------------------------------------------------------
// Rule evaluation
// ---------------------------------------------------------------------------
function anyPathExists(patterns: string[]): boolean {
  for (const p of patterns) {
    if (/[*?]/.test(p)) {
      if (files!.some((f) => globToRegex(p).test(f))) return true;
    } else if (existsSync(join(root, p)) || files!.includes(p)) {
      return true;
    }
  }
  return false;
}

function evalRule(rule: Rule): Result {
  const base = { id: rule.id, category: rule.category, severity: rule.severity, title: rule.title };

  // Static skip — must carry a reason code or it is an ERROR, never a pass.
  if (rule.skip) {
    if (!rule.skip.code) return { ...base, status: "ERROR", evidence: "skip declared without machine-readable reason code" };
    return { ...base, status: "SKIP", evidence: `skipped: ${rule.skip.code}`, skipReason: rule.skip };
  }

  // Conditional applicability — self-arms when the stack appears.
  if (rule.applies_if) {
    if (!rule.applies_if.skipReason?.code) {
      return { ...base, status: "ERROR", evidence: "applies_if declared without machine-readable skipReason.code" };
    }
    if (!anyPathExists(rule.applies_if.anyExists)) {
      return {
        ...base,
        status: "SKIP",
        evidence: `skipped: ${rule.applies_if.skipReason.code} (arms if any of: ${rule.applies_if.anyExists.join(", ")})`,
        skipReason: rule.applies_if.skipReason,
      };
    }
  }

  const d = rule.detect;
  switch (d.type) {
    case "grep":        return { ...base, ...runGrep(d) };
    case "glob":        return { ...base, ...runGlob(d) };
    case "file-exists": return { ...base, ...runFileExists(d) };
    case "command":     return { ...base, ...runCommand(d) };
    case "manual":      return { ...base, status: "MANUAL", evidence: `ASK ${d.owner ?? "team"}: ${d.question}` };
    default:            return { ...base, status: "ERROR", evidence: `unknown detect type: ${(d as any).type}` };
  }
}

const results: Result[] = checklist.rules.map(evalRule);

// ---------------------------------------------------------------------------
// Summary + exit policy
// ---------------------------------------------------------------------------
const counts = { pass: 0, fail: 0, skip: 0, manual: 0, error: 0 };
for (const r of results) {
  if (r.status === "PASS") counts.pass++;
  else if (r.status === "FAIL") counts.fail++;
  else if (r.status === "SKIP") counts.skip++;
  else if (r.status === "MANUAL") counts.manual++;
  else counts.error++;
}

const threshold = SEV_RANK[failOn];
const blockers = results.filter(
  (r) => (r.status === "FAIL" && SEV_RANK[r.severity] <= threshold) || r.status === "ERROR"
);

if (mode === "json") {
  console.log(JSON.stringify({
    project: checklist.project,
    root,
    failOn,
    summary: { total: results.length, ...counts, blockers: blockers.length },
    results,
  }, null, 2));
} else {
  console.log(`=== secure-build-checklist — ${checklist.project} ===`);
  console.log(
    `fail-on: ${failOn} | total: ${results.length} | pass: ${counts.pass} | fail: ${counts.fail}` +
    ` | skip: ${counts.skip} | manual: ${counts.manual} | error: ${counts.error} | blockers: ${blockers.length}`
  );
  console.log("");
  for (const r of results) {
    const mark =
      r.status === "PASS" ? "✓" :
      r.status === "FAIL" ? "✗" :
      r.status === "SKIP" ? "→" :
      r.status === "MANUAL" ? "?" : "!";
    const skipTag = r.skipReason ? ` [${r.skipReason.code}]` : "";
    console.log(`[${mark}] ${r.id} (${r.severity}) ${r.status}${skipTag} — ${r.title}`);
    if (mode === "verbose" || r.status === "FAIL" || r.status === "ERROR" || r.status === "MANUAL") {
      for (const line of r.evidence.split("\n")) console.log(`      ${line}`);
      if (r.skipReason) console.log(`      reason: ${r.skipReason.detail}`);
    }
  }
  console.log("");
  console.log(blockers.length > 0
    ? `BLOCKED: ${blockers.length} finding(s) at/above '${failOn}' (ERROR always blocks).`
    : `No blockers at fail-on=${failOn}. (${counts.skip} skipped with reasons, ${counts.manual} awaiting manual answer.)`);
}

process.exit(blockers.length > 0 ? 1 : 0);
```

# 3. Category mapping table

| # | Reference category | Verdict | Reason |
|---|---|---|---|
| 1 | Secrets & Environment | **APPLIES** | Real surface; owned by sentinel SEC-001..005 + gitleaks (CI-001). Checklist adds only disjoint token prefixes (CHK-SEC-101). |
| 2 | Dependencies & Supply Chain | **CONDITIONAL SKIP** | npm/lockfile audits N/A unless `package.json` exists → `applies_if` with reason `no-node-tooling`. CI download pinning already covered by sentinel DEP-004. |
| 3 | Auth, AuthZ & Sessions | **SKIP** (`no-backend`) | No routes, sessions, or server; itch.io serves static files. |
| 4 | Injection & Input Validation | **APPLIES (translated)** | GDScript equivalents already in sentinel: `OS.execute` (INJ-001), `Expression` (INJ-002), `JavaScriptBridge.eval` (INJ-003), `FileAccess` paths (INJ-004). New: hand-written web-shell JS (CHK-INJ-101). |
| 5 | AI-Generated Code Risks | **PARTIAL** | Dynamic-exec parts APPLY (above). Supabase RLS → SKIP `no-supabase-stack` (CHK-SAAS-101, self-arming); `VITE_`/`NEXT_PUBLIC_` client secrets → SKIP `no-bundler-env` (no JS bundler; SEC-001 covers hardcoded keys directly). |
| 6 | API Hardening | **SKIP** (`no-owned-api`) | No owned endpoints; rate limits/CORS/error pages are itch.io's plane. |
| 7 | Logging & Error Tracking | **APPLIES** | Sentry + PostHog are already wired (per the `_js_dsn`/`_js_config` sanitizers in sentinel INJ-003). Rule = validate the existing config; if it fails, fix config — never invent a stack. PII-in-telemetry check applies to the postMessage/analytics payloads. |
| 8 | Data Handling & Legal | **MANUAL** (`founder-decision`) | ToS/PP is a founder call given telemetry (CHK-LEGAL-101); asset licenses also manual. |
| 9 | Infrastructure & Deployment | **PARTIAL** | HTTPS/HSTS/backups → SKIP `platform-managed` / `no-database`. Artifact hygiene APPLIES: sentinel DEP-001/003/004 + CHK-GD-101. |
| 10 | Platform Privilege / Control-plane | **SKIP** (`web-export-no-adb`) | HTML5 in a browser sandbox — no ADB, Accessibility, or device daemons. Skip reason notes: re-arm if an Android export preset ever appears. |

# 4. Overlap map vs the 18 sentinel checks

**Delegated, not duplicated:** `CHK-GATE-001` runs `scripts/security-sentinel.sh --fail-on=high` as a single command rule. That covers all 18 (SEC-001..005, INJ-001..004, DEP-001..004, TRUST-001, CI-001..004) without re-implementing any grep — the anti-drift mechanism.

**Adjacent (deliberately disjoint):**
- `CHK-SEC-101` ↔ **SEC-001**: same category, *disjoint pattern set* (only prefixes SEC-001 doesn't match).
- `CH