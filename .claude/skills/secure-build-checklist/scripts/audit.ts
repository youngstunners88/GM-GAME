#!/usr/bin/env bun
/**
 * secure-build-checklist audit script
 *
 * Scans a project directory against the 9-category, 25+ rule security
 * checklist and returns a pass/fail report. Designed to be run by
 * agents (or humans) before deploying any app.
 *
 * Usage:
 *   bun audit.ts [project-path] [--json] [--fail-on=critical|high|medium] [--verbose]
 *
 * Default project path: current working directory
 */

import { readFileSync, readdirSync, statSync, existsSync } from "node:fs";
import { join, relative, resolve } from "node:path";
import { execSync } from "node:child_process";

type Severity = "critical" | "high" | "medium" | "low";

interface Check {
  id: string;
  title: string;
  pattern?: string;
  patterns?: string[];
  files?: string[];
  file_pattern?: string;
  exclude?: string[];
  must_contain_any?: string[];
  must_have_nearby?: string[];
  must_have_in_project?: string[];
  must_not_match?: string;
  file_must_exist?: string[];
  command?: string;
  command_check?: string;
  expect_empty?: boolean;
  expect_https?: boolean;
  expect_pattern?: string;
  trigger_pattern?: string;
  expect_in_migration?: string[];
  policy?: string;
  exclude_files_when_prod?: boolean;
  context?: string;
  severity: Severity;
  fix: string;
  mode?: string;
}

interface Category {
  label: string;
  weight: number;
  checks: Check[];
}

interface Checklist {
  version: string;
  categories: Record<string, Category>;
}

interface Finding {
  id: string;
  title: string;
  category: string;
  severity: Severity;
  status: "fail" | "pass" | "warn" | "skip" | "manual";
  matches?: Array<{ file: string; line: number; excerpt: string }>;
  fix: string;
  // WHY this check did not run, for skip/manual. A first-class field because
  // it was previously absent: skip sites copied `check.fix` (the remediation
  // text) into `fix` and emitted nothing else, so every skip in the JSON read
  // as a bare "skip" with no justification attached. The founder's rule for
  // this gate is explicit — "mark skip with reason" — and a reason that lives
  // only in someone's head is how a skipped check quietly becomes a claimed
  // one. Also carries the condition that would make the check APPLY again.
  reason?: string;
  rearm_when?: string;
}

const args = process.argv.slice(2);
if (args.includes("--help") || args.includes("-h")) {
  console.log(
    [
      "Secure Build Checklist — pre-deploy security scanner",
      "",
      "USAGE:",
      "  bun audit.ts [path]              Scan the given project (default: cwd)",
      "  bun audit.ts /path/to/project    Scan a specific project",
      "  bun audit.ts --json              Machine-readable JSON output",
      "  bun audit.ts --verbose           Show passing checks too",
      "  bun audit.ts --fail-on=level     Block threshold: low|medium|high|critical (default: high)",
      "  bun audit.ts --help              Show this help",
      "",
      "Exits 0 on pass, 1 on blockers, 2 on internal error.",
    ].join("\n")
  );
  process.exit(0);
}

const projectPath = args.find((a) => !a.startsWith("--")) ?? ".";
const jsonOutput = args.includes("--json");
const verbose = args.includes("--verbose") || jsonOutput;
const failOnArg = args.find((a) => a.startsWith("--fail-on="));
const failOn = (failOnArg?.split("=")[1] ?? "high") as Severity;

// The rules live at the SKILL ROOT (`../assets/checklist.json`), which is the
// upstream pack's own layout and the one the founder specified. An earlier
// integration had flattened it to `scripts/assets/security-checklist.json`;
// moving back means this file is byte-comparable to upstream again, so a
// future version bump is a diff rather than an archaeology exercise.
//
// The legacy path is still probed, and ONLY the legacy path — an unknown
// location must be a hard error, never a silent "no rules loaded", because a
// checklist that loads zero rules reports a clean pass. Stack adaptations are
// made in the JSON, not here — see SECURITY_CHECKLIST_INTEGRATION.md.
const CHECKLIST_CANDIDATES = [
  join(import.meta.dir, "..", "assets", "checklist.json"),
  join(import.meta.dir, "assets", "security-checklist.json"),
];
const CHECKLIST_PATH = CHECKLIST_CANDIDATES.find((p) => existsSync(p));
if (!CHECKLIST_PATH) {
  console.error(
    "FATAL: no checklist.json found. Looked in:\n  " + CHECKLIST_CANDIDATES.join("\n  ")
  );
  process.exit(2);
}
const checklist: Checklist = JSON.parse(readFileSync(CHECKLIST_PATH, "utf-8"));
// `categories` is an OBJECT keyed by category id, not an array — counting it
// with `.length` silently yields undefined and would have turned this guard
// into the exact failure it exists to prevent.
const _ruleCount = Object.values(checklist.categories ?? {}).reduce(
  (n, c: any) => n + (c?.checks?.length ?? 0),
  0
);
if (_ruleCount === 0) {
  console.error(`FATAL: ${CHECKLIST_PATH} defines no checks — refusing to report a pass on an empty rule set.`);
  process.exit(2);
}

const findings: Finding[] = [];

// ---------- helpers ----------

function walk(dir: string, out: string[] = [], depth = 0): string[] {
  if (depth > 8) return out;
  let entries: string[];
  try {
    entries = readdirSync(dir);
  } catch {
    return out;
  }
  for (const entry of entries) {
    if (entry === "node_modules" || entry === ".next" || entry === "dist" || entry === "build" || entry === ".git" || entry === "Trash" || entry === ".z" || entry === "__pycache__") continue;
    const full = join(dir, entry);
    let stat;
    try {
      stat = statSync(full);
    } catch {
      continue;
    }
    if (stat.isDirectory()) walk(full, out, depth + 1);
    else out.push(full);
  }
  return out;
}

function globMatch(file: string, patterns: string[] | undefined): boolean {
  if (!patterns || patterns.length === 0) return true;
  return patterns.some((p) => {
    const re = new RegExp(
      "^" +
        p
          .replace(/[.+^${}()|[\]\\]/g, "\\$&")
          .replace(/\*\*/g, ".*")
          .replace(/\*/g, "[^/]*") +
        "$",
    );
    return re.test(file);
  });
}

function isExcluded(file: string, patterns: string[] | undefined): boolean {
  if (!patterns) return false;
  return patterns.some((p) => {
    const re = new RegExp(
      "^" +
        p
          .replace(/[.+^${}()|[\]\\]/g, "\\$&")
          .replace(/\*\*/g, ".*")
          .replace(/\*/g, "[^/]*") +
        "$",
    );
    return re.test(file);
  });
}

function readFileSafe(path: string): string | null {
  try {
    const stat = statSync(path);
    if (stat.size > 5 * 1024 * 1024) return null; // skip files > 5MB
    return readFileSync(path, "utf-8");
  } catch {
    return null;
  }
}

function searchPattern(files: string[], regex: RegExp, excludes: string[] | undefined): Array<{ file: string; line: number; excerpt: string }> {
  const results: Array<{ file: string; line: number; excerpt: string }> = [];
  for (const file of files) {
    const rel = relative(projectPath, file);
    if (isExcluded(rel, excludes)) continue;
    // GM-GAME adaptation: .md added — DATA002 targets ["*.md"] but the
    // upstream allowlist silently dropped markdown, so the check could never
    // pass anywhere. Policy/legal text legitimately lives in markdown.
    if (!/\.(ts|tsx|js|jsx|py|go|rs|sql|vue|html|env|json|ya?ml|java|kt|xml|gradle|gd|cs|cpp|h|md)$/i.test(file)) continue;
    const content = readFileSafe(file);
    if (!content) continue;
    const lines = content.split("\n");
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      if (regex.test(line)) {
        results.push({ file: rel, line: i + 1, excerpt: line.trim().slice(0, 200) });
        if (results.length > 20) return results;
      }
    }
  }
  return results;
}

function fileContentHasAny(file: string, needles: string[]): boolean {
  const content = readFileSafe(file);
  if (!content) return false;
  return needles.some((n) => content.includes(n));
}

function projectHasAny(needles: string[]): { found: boolean; matched: string[] } {
  const matched: string[] = [];
  const all = walk(projectPath);
  for (const file of all) {
    if (!/\.(ts|tsx|js|jsx|json|lock|yaml|yml|toml)$/i.test(file)) continue;
    const rel = relative(projectPath, file);
    if (rel.includes("node_modules") || rel.includes(".git/")) continue;
    const content = readFileSafe(file);
    if (!content) continue;
    for (const needle of needles) {
      if (content.includes(needle) && !matched.includes(needle)) matched.push(needle);
    }
  }
  return { found: matched.length > 0, matched };
}

function packageManager(): "npm" | "pnpm" | "yarn" | "bun" | null {
  if (existsSync(join(projectPath, "bun.lockb")) || existsSync(join(projectPath, "bun.lock"))) return "bun";
  if (existsSync(join(projectPath, "pnpm-lock.yaml"))) return "pnpm";
  if (existsSync(join(projectPath, "yarn.lock"))) return "yarn";
  if (existsSync(join(projectPath, "package-lock.json"))) return "npm";
  return null;
}

function runAudit(): { ok: boolean; output: string } {
  const pm = packageManager();
  if (!pm) return { ok: true, output: "no package manager detected" };
  try {
    const out = execSync(`${pm} audit --json 2>/dev/null || ${pm} audit 2>&1 || true`, {
      cwd: projectPath,
      encoding: "utf-8",
      stdio: ["ignore", "pipe", "pipe"],
      timeout: 30000,
    });
    if (pm === "npm" && out.trim().startsWith("{")) {
      try {
        const data = JSON.parse(out);
        const vulns = data.metadata?.vulnerabilities || {};
        const critical = vulns.critical || 0;
        const high = vulns.high || 0;
        if (critical > 0 || high > 0) {
          return { ok: false, output: `${critical} critical, ${high} high vulnerabilities` };
        }
        return { ok: true, output: "no critical or high vulnerabilities" };
      } catch {
        return { ok: true, output: out.slice(0, 500) };
      }
    }
    return { ok: !/vulnerabilit/i.test(out) || /0 vulnerabilit/.test(out), output: out.slice(0, 500) };
  } catch (e: any) {
    return { ok: false, output: e.message?.slice(0, 500) || "audit failed" };
  }
}

function gitLogForEnv(): { committed: boolean; files: string[] } {
  try {
    const out = execSync(
      `git log --all --full-history --diff-filter=A --name-only --pretty=format: -- '.env' '.env.local' '.env.production' '.env.development' 2>/dev/null || true`,
      { cwd: projectPath, encoding: "utf-8" },
    );
    const files = out.split("\n").map((s) => s.trim()).filter(Boolean);
    return { committed: files.length > 0, files };
  } catch {
    return { committed: false, files: [] };
  }
}

function checkGitRemote(): { allHttps: boolean; remotes: string[] } {
  try {
    const out = execSync("git remote -v 2>/dev/null || true", { cwd: projectPath, encoding: "utf-8" });
    const remotes = out.split("\n").filter(Boolean).map((l) => l.split(/\s+/)[1]).filter(Boolean);
    // GM-GAME adaptation: the remote-execution sandbox proxies git through a
    // loopback URL (http://…@127.0.0.1:…). Loopback can't be MITM'd off-host;
    // real remotes (GitHub in CI) must still be HTTPS.
    const isLoopback = (r: string) => /^http:\/\/[^/]*@?(127\.0\.0\.1|localhost)[:/]/.test(r);
    const allHttps = remotes.length === 0 || remotes.every((r) => r.startsWith("https://") || isLoopback(r));
    return { allHttps, remotes };
  } catch {
    return { allHttps: true, remotes: [] };
  }
}

function runCheck(check: Check, categoryKey: string, allFiles: string[]): void {
  // NOT-APPLICABLE, declared in the rules rather than inferred.
  //
  // For a rule whose whole premise is a stack this project does not have. It
  // is a SKIP, never a pass, and the JSON must supply BOTH a reason and the
  // condition that re-arms it — if either is missing the check is reported as
  // a failure, because an undocumented skip is indistinguishable from nobody
  // having looked.
  if ((check as any).policy === "not_applicable") {
    const reason = (check as any).reason;
    const rearm = (check as any).rearm_when;
    findings.push({
      id: check.id, title: check.title, category: categoryKey,
      severity: check.severity,
      status: reason && rearm ? "skip" : "fail",
      fix: reason && rearm
        ? check.fix
        : `Marked not_applicable without both a 'reason' and a 'rearm_when'. An undocumented skip is not a pass — fill both in. Original guidance: ${check.fix}`,
      reason: reason ?? "declared not_applicable but gave NO reason",
      rearm_when: rearm,
    });
    return;
  }

  // must_be_gitignored: the named files must be ignored AND absent from the
  // tracked tree. Implemented because it previously had no handler at all —
  // SEC002 (critical, ".env files gitignored") fell through to the unhandled
  // branch and was silently reported as a skip on every run.
  if ((check as any).mode === "must_be_gitignored") {
    const candidates = [".env", ".env.local", ".env.production", ".env.development"];
    const gi = readFileSafe(join(projectPath, ".gitignore")) ?? "";
    const ignoresEnv = /^\s*\.env(\*|\.\*)?\s*$/m.test(gi) || /^\s*\.env\b/m.test(gi);
    const committed = candidates.filter((c) => existsSync(join(projectPath, c)));
    const ok = ignoresEnv && committed.length === 0;
    findings.push({
      id: check.id, title: check.title, category: categoryKey,
      severity: check.severity,
      status: ok ? "pass" : "fail",
      fix: check.fix,
      matches: committed.map((c) => ({ file: c, line: 0, excerpt: "present in working tree" })),
      reason: ok
        ? undefined
        : (!ignoresEnv ? ".gitignore does not ignore .env" : "a .env file exists in the working tree"),
    });
    return;
  }

  // policy/manual checks
  if (check.policy) {
    findings.push({
      id: check.id,
      title: check.title,
      category: categoryKey,
      severity: check.severity,
      status: "manual",
      fix: check.fix,
    });
    return;
  }

  // file_must_exist — ANY-OF semantics (GM-GAME adaptation): the lists are
  // alternatives (terms.md OR terms.html OR legal/**), and upstream ALL-OF
  // could never pass (existsSync can't glob "legal/**"). One present = pass.
  if (check.file_must_exist) {
    // requires_file (GM-GAME extension): skip the check entirely when its
    // precondition file is absent — e.g. lockfile checks only apply when a
    // package.json exists (this repo has no Node manifest; deps are vendored
    // or installed ad hoc in CI).
    if ((check as any).requires_file && !existsSync(join(projectPath, (check as any).requires_file))) {
      findings.push({
        id: check.id, title: check.title, category: categoryKey,
        severity: check.severity, status: "skip",
        fix: check.fix,
        reason: `precondition file '${(check as any).requires_file}' is not present in this project`,
        rearm_when: `a '${(check as any).requires_file}' is added`,
      });
      return;
    }
    const present = check.file_must_exist.some((f) => existsSync(join(projectPath, f)));
    if (!present) {
      findings.push({
        id: check.id,
        title: check.title,
        category: categoryKey,
        severity: check.severity,
        status: "fail",
        fix: `Missing (need at least one of): ${check.file_must_exist.join(", ")}. ${check.fix}`,
      });
    } else {
      findings.push({
        id: check.id,
        title: check.title,
        category: categoryKey,
        severity: check.severity,
        status: "pass",
        fix: check.fix,
      });
    }
    return;
  }

  // must_have_in_project
  if (check.must_have_in_project) {
    const { found, matched } = projectHasAny(check.must_have_in_project);
    if (!found) {
      findings.push({
        id: check.id,
        title: check.title,
        category: categoryKey,
        severity: check.severity,
        status: "fail",
        fix: `None of [${check.must_have_in_project.join(", ")}] found in project. ${check.fix}`,
      });
    } else {
      findings.push({
        id: check.id,
        title: check.title,
        category: categoryKey,
        severity: check.severity,
        status: "pass",
        fix: `Found: ${matched.join(", ")}.`,
      });
    }
    return;
  }

  // Conditional presence checks: skip when the capability is absent, fail when it is present without its required control.
  if (check.expect_pattern && check.files) {
    const targetFiles = allFiles.filter((f) => globMatch(relative(projectPath, f), check.files));
    let triggerMatches: Array<{ file: string; line: number; excerpt: string }> = [];
    if (check.trigger_pattern) {
      try {
        triggerMatches = searchPattern(targetFiles, new RegExp(check.trigger_pattern, "i"), check.exclude);
      } catch (e: any) {
        if (verbose) console.error(`bad trigger pattern in ${check.id}: ${e.message}`);
      }
      if (triggerMatches.length === 0) {
        findings.push({
          id: check.id,
          title: check.title,
          category: categoryKey,
          severity: check.severity,
          status: "skip",
          fix: check.fix,
          reason:
            (check as any).skip_reason ??
            "the capability this check guards was not found anywhere in the project",
          rearm_when:
            (check as any).rearm_when ?? "that capability is introduced",
        });
        return;
      }
    }

    let expectedMatches: Array<{ file: string; line: number; excerpt: string }> = [];
    try {
      expectedMatches = searchPattern(targetFiles, new RegExp(check.expect_pattern, "i"), check.exclude);
    } catch (e: any) {
      if (verbose) console.error(`bad expected pattern in ${check.id}: ${e.message}`);
    }
    findings.push({
      id: check.id,
      title: check.title,
      category: categoryKey,
      severity: check.severity,
      status: expectedMatches.length > 0 ? "pass" : "fail",
      matches: expectedMatches.length > 0 ? expectedMatches : triggerMatches,
      fix: check.fix,
    });
    return;
  }

  // command checks
  if (check.command) {
    if (check.command === "package_manager_audit") {
      const r = runAudit();
      findings.push({
        id: check.id,
        title: check.title,
        category: categoryKey,
        severity: check.severity,
        status: r.ok ? "pass" : "fail",
        fix: r.ok ? r.output : `${r.output}. ${check.fix}`,
      });
      return;
    }
    if (check.command.includes("git log")) {
      const r = gitLogForEnv();
      findings.push({
        id: check.id,
        title: check.title,
        category: categoryKey,
        severity: check.severity,
        status: r.committed ? "fail" : "pass",
        matches: r.files.map((f) => ({ file: f, line: 0, excerpt: "committed in git history" })),
        fix: check.fix,
      });
      return;
    }
  }

  if (check.command_check === "git remote -v") {
    const r = checkGitRemote();
    findings.push({
      id: check.id,
      title: check.title,
      category: categoryKey,
      severity: check.severity,
      status: r.allHttps ? "pass" : "fail",
      matches: r.remotes.filter((x) => !x.startsWith("https://")).map((x) => ({ file: x, line: 0, excerpt: "non-HTTPS remote" })),
      fix: check.fix,
    });
    return;
  }

  // pattern-based search
  const patterns: string[] = [];
  if (check.pattern) patterns.push(check.pattern);
  if (check.patterns) patterns.push(...check.patterns);

  if (patterns.length > 0 && check.files) {
    const targetFiles = allFiles.filter((f) => {
      const rel = relative(projectPath, f);
      if (isExcluded(rel, check.exclude)) return false;
      return globMatch(rel, check.files);
    });
    let allMatches: Array<{ file: string; line: number; excerpt: string }> = [];
    for (const p of patterns) {
      try {
        const re = new RegExp(p, "i");
        allMatches.push(...searchPattern(targetFiles, re, check.exclude));
      } catch (e: any) {
        if (verbose) console.error(`bad pattern in ${check.id}: ${e.message}`);
      }
    }
    // de-dup
    const seen = new Set<string>();
    allMatches = allMatches.filter((m) => {
      const k = `${m.file}:${m.line}`;
      if (seen.has(k)) return false;
      seen.add(k);
      return true;
    });

    if (allMatches.length === 0) {
      findings.push({
        id: check.id,
        title: check.title,
        category: categoryKey,
        severity: check.severity,
        status: "pass",
        fix: check.fix,
      });
    } else {
      // check must_contain_any / must_have_nearby / must_not_match
      let stillFails = true;
      if (check.must_contain_any) {
        const anyFileHas = allMatches.some((m) => {
          const content = readFileSafe(join(projectPath, m.file));
          return content ? check.must_contain_any!.some((n) => content.includes(n)) : false;
        });
        if (anyFileHas) stillFails = false;
      }
      if (check.must_have_nearby && stillFails) {
        const nearbyFileHas = allMatches.some((m) => {
          const content = readFileSafe(join(projectPath, m.file));
          return content ? check.must_have_nearby!.some((n) => content.includes(n)) : false;
        });
        if (nearbyFileHas) stillFails = false;
      }
      if (check.must_not_match && stillFails) {
        const anyFileMatches = allMatches.some((m) => {
          const content = readFileSafe(join(projectPath, m.file));
          return content ? new RegExp(check.must_not_match!, "i").test(content) : false;
        });
        if (anyFileMatches) stillFails = false;
      }
      findings.push({
        id: check.id,
        title: check.title,
        category: categoryKey,
        severity: check.severity,
        status: stillFails ? "fail" : "pass",
        matches: allMatches.slice(0, 10),
        fix: check.fix,
      });
    }
    return;
  }

  // UNRECOGNISED CHECK TYPE — reported as a FAILURE, never as a skip.
  //
  // This branch used to emit `status: "skip"`. That meant any rule this
  // scanner does not know how to execute — a typo in the JSON, a rule shape
  // from a newer upstream version, a hand-edit that dropped a field — vanished
  // into the "not applicable" column and the run still exited 0. A rule that
  // could not be run is not a rule that does not apply; conflating the two is
  // precisely how a checklist ends up green while covering less than it says.
  findings.push({
    id: check.id,
    title: check.title,
    category: categoryKey,
    severity: check.severity,
    status: "fail",
    fix:
      `This checklist entry has no executable form the scanner recognises, so it was NEVER CHECKED. ` +
      `Give it one of: pattern / file_must_exist / expected_pattern / policy:"manual". Original guidance: ${check.fix}`,
    reason: "unrecognised check shape — the scanner could not execute this rule",
  });
}

// ---------- main ----------

const allFiles = walk(projectPath);
for (const [key, cat] of Object.entries(checklist.categories)) {
  for (const check of cat.checks) {
    runCheck(check, key, allFiles);
  }
}

const sevOrder: Record<Severity, number> = { critical: 0, high: 1, medium: 2, low: 3 };
const severityFail = (s: Severity) => ({ critical: 0, high: 1, medium: 2, low: 3 }[s] <= ({ critical: 0, high: 1, medium: 2, low: 3 }[failOn] as number));

const summary = {
  total: findings.length,
  pass: findings.filter((f) => f.status === "pass").length,
  fail: findings.filter((f) => f.status === "fail").length,
  warn: findings.filter((f) => f.status === "warn").length,
  manual: findings.filter((f) => f.status === "manual").length,
  skip: findings.filter((f) => f.status === "skip").length,
  bySeverity: {
    critical: findings.filter((f) => f.status === "fail" && f.severity === "critical").length,
    high: findings.filter((f) => f.status === "fail" && f.severity === "high").length,
    medium: findings.filter((f) => f.status === "fail" && f.severity === "medium").length,
  },
};

const blockers = findings
  .filter((f) => f.status === "fail" && severityFail(f.severity))
  .sort((a, b) => sevOrder[a.severity] - sevOrder[b.severity]);

if (jsonOutput) {
  console.log(JSON.stringify({ project: projectPath, summary, findings, blockers }, null, 2));
} else {
  const pad = (s: string, n: number) => s + " ".repeat(Math.max(0, n - s.length));
  const c = (s: string, code: string) => `\x1b[${code}m${s}\x1b[0m`;
  const red = (s: string) => c(s, "31");
  const yellow = (s: string) => c(s, "33");
  const green = (s: string) => c(s, "32");
  const dim = (s: string) => c(s, "90");
  const bold = (s: string) => c(s, "1");

  console.log("");
  console.log(bold(`Secure Build Checklist — ${projectPath}`));
  console.log(dim(`checklist v${checklist.version} • fail-on: ${failOn}`));
  console.log("");
  console.log(
    `${pad("total", 8)}${pad("pass", 8)}${pad("fail", 8)}${pad("manual", 9)}${pad("skip", 8)}`,
  );
  console.log(
    `${pad(String(summary.total), 8)}${green(pad(String(summary.pass), 8))}${red(pad(String(summary.fail), 8))}${pad(String(summary.manual), 9)}${pad(String(summary.skip), 8)}`,
  );
  console.log("");
  console.log(
    `critical: ${red(String(summary.bySeverity.critical))}  high: ${red(String(summary.bySeverity.high))}  medium: ${yellow(String(summary.bySeverity.medium))}`,
  );
  console.log("");

  if (blockers.length > 0) {
    console.log(bold(red("BLOCKERS — ship blocked")));
    console.log("");
    for (const b of blockers) {
      const sevColor = b.severity === "critical" ? red : yellow;
      console.log(`  ${sevColor("[" + b.severity.toUpperCase() + "]")} ${bold(b.id)} ${b.title} ${dim("(in " + b.category + ")")}`);
      if (b.matches && b.matches.length > 0) {
        for (const m of b.matches.slice(0, 5)) {
          console.log(`    ${dim(m.file + ":" + m.line)}  ${m.excerpt}`);
        }
        if (b.matches.length > 5) console.log(dim(`    …and ${b.matches.length - 5} more`));
      }
      console.log(`    ${dim("fix: " + b.fix)}`);
      console.log("");
    }
  } else {
    console.log(green(bold("No blockers at fail-on=" + failOn)));
    console.log("");
  }

  // EVERY SKIP, WITH ITS REASON AND ITS RE-ARM CONDITION.
  //
  // Printed unconditionally, not behind --verbose. This project has no
  // backend, database, auth or payments, so a large slice of a general
  // checklist cannot fail here — not because the project is safe, but because
  // the surface does not exist. A bare "5 skip" in the summary invites the
  // reader to round that up to "fine". Naming each one, and naming what would
  // make it matter again, is the difference between a gate and a green light.
  const skipped = findings.filter((f) => f.status === "skip");
  if (skipped.length > 0) {
    console.log(bold(`Skipped — NOT checked, NOT a pass (${skipped.length}):`));
    for (const sk of skipped) {
      console.log(`  ${dim("[SKIP]")} ${bold(sk.id)} ${sk.title}`);
      console.log(`    ${dim("why:      " + (sk.reason ?? "NO REASON RECORDED — treat as unchecked"))}`);
      if (sk.rearm_when) console.log(`    ${dim("re-check: when " + sk.rearm_when)}`);
    }
    console.log("");
  }

  const manuals = findings.filter((f) => f.status === "manual");
  if (manuals.length > 0) {
    console.log(bold(`Manual — a human must answer these (${manuals.length}):`));
    for (const mn of manuals) {
      console.log(`  ${dim("[MANUAL]")} ${bold(mn.id)} ${mn.title} ${dim("(" + mn.severity + ")")}`);
    }
    console.log("");
  }

  // pass/skip summary by category
  console.log(bold("By category:"));
  for (const [key, cat] of Object.entries(checklist.categories)) {
    const inCat = findings.filter((f) => f.category === key);
    const p = inCat.filter((f) => f.status === "pass").length;
    const f = inCat.filter((f) => f.status === "fail").length;
    const m = inCat.filter((f) => f.status === "manual").length;
    const s = inCat.filter((f) => f.status === "skip").length;
    console.log(`  ${pad(cat.label, 30)} ${green(p + " pass")}  ${f > 0 ? red(f + " fail") : dim("0 fail")}  ${dim(m + " manual " + s + " skip")}`);
  }
  console.log("");
  console.log(dim(`Run with --json for machine output, --verbose for debug, --fail-on=medium for stricter gate.`));
}

const shouldExit = blockers.length > 0;
process.exit(shouldExit ? 1 : 0);
