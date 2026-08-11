<!-- dispatched: qwen/qwen3.7-max
     prompt: prompts/qwen-scanner-integrity.md
     files inlined: 2
     tokens: 17401 in / 11121 out
     cost: $0.0749
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
### 1. Silent-skip paths (False Passes)
No checks **vanish** from the totals. Every branch in `runCheck` pushes exactly one object to `findings`. However, several paths silently report `"pass"` when they should `"skip"` or `"fail"`:

*   **Bad Regex in `pattern`**: If `new RegExp(p, "i")` throws, the `catch` block swallows it. `allMatches` remains empty, and the check reports `"pass"`.
*   **Empty `targetFiles`**: If `check.files` matches zero files in the project, `allMatches` is empty → `"pass"`. (Unlike `expect_pattern`, which correctly skips).
*   **Unreadable / >5MB Files**: `readFileSafe` returns `null`, `searchPattern` skips the file. If *all* target files are skipped, `allMatches` is empty → `"pass"`.
*   **Missing Extensions in `searchPattern`**: The hardcoded allowlist (`/\.(ts|tsx|...|md)$/i`) drops extensions like `.sh`, `.c`, `.rb`, `.toml`. If a rule targets them, they are silently skipped → `"pass"`.
*   **Git Command Failures**: `gitLogForEnv` and `checkGitRemote` catch `execSync` exceptions (e.g., not a git repo, git not installed) and return "clean" defaults (`committed: false`, `allHttps: true`). SEC003 and DEP004 report `"pass"` when history/remotes are actually unverifiable.

### 2. Walker blind spots
`walk()` hardcodes skips for: `node_modules`, `.next`, `dist`, `build`, `.git`, `Trash`, `.z`, `__pycache__`. It also caps depth at 8.
*   **Never scanned but claimed**: `dist/`, `build/`, `.next/`. Rules like `INJ001`, `AI001`, and `PLAT002` target `*.ts`/`*.js` but **lack `exclude` fields** for these directories. They claim coverage, but the walker blind spot prevents scanning them.
*   **Scanned correctly**: `.github/workflows/*` (depth 2), `src/**/*.gd` (depth < 8), and `.claude/` (depth 1) are **not** in the skip list and are fully scanned.

### 3. Exit-code correctness
*   **`--fail-on=high`**: `severityFail` maps `critical` to `0` and `high` to `1`. `0 <= 1` is true. A `critical` finding **will** exit 1.
*   **Uncounted failures**: A rule can be `"fail"` and not block only if its severity is `medium`/`low` (intended).
*   **Mid-scan exceptions**: `globMatch` and `isExcluded` compile regexes without `try/catch`. If a malformed glob throws, the exception propagates to the main loop, crashes the Bun process, and **exits 1**. It does not produce a partial report that exits 0.

### 4. JSON vs human divergence
**None.** Both outputs are derived from the exact same `summary` object and `findings` array. `--verbose` only toggles `console.error` for bad patterns; it does not mutate findings or counts.

### 5. Self-audit gap
**No gap.** `.claude/` is not in the walker skip list. SEC001 targets `*.ts` and `*.json`, both of which are in the `searchPattern` extension allowlist and not excluded. A secret committed to `.claude/skills/.../audit.ts` or `checklist.json` would be caught.

### 6. Smallest patches for real findings

**Fix 1: Pattern-based false passes (Bad regex, empty targets, unreadable files)**
Replace the unconditional `pass` on empty matches with state tracking.
```typescript
// audit.ts, inside `if (patterns.length > 0 && check.files) {`
    const targetFiles = allFiles.filter(/* ... */);
    if (targetFiles.length === 0) {
      findings.push({ id: check.id, title: check.title, category: categoryKey, severity: check.severity, status: "skip", fix: check.fix, reason: "no files matched target glob", rearm_when: "matching file added" });
      return;
    }

    let allMatches: Array<{ file: string; line: number; excerpt: string }> = [];
    let regexErrors = 0;
    for (const p of patterns) {
      try {
        const re = new RegExp(p, "i");
        allMatches.push(...searchPattern(targetFiles, re, check.exclude));
      } catch (e: any) {
        regexErrors++;
        if (verbose) console.error(`bad pattern in ${check.id}: ${e.message}`);
      }
    }
    // ... de-dup ...

    if (allMatches.length === 0) {
      const status = regexErrors > 0 ? "fail" : "pass";
      findings.push({
        id: check.id, title: check.title, category: categoryKey, severity: check.severity,
        status, fix: status === "fail" ? `Regex compilation failed. ${check.fix}` : check.fix,
        reason: status === "fail" ? "invalid regex pattern in checklist" : undefined
      });
    } else { ... }
```
*(Note: To fix the >5MB/unreadable false pass, `searchPattern` must return a `skippedFiles` count, and the `status` logic above should check `skippedFiles > 0`.)*

**Fix 2: Git command false passes**
Return an error flag instead of assuming a clean state on exception.
```typescript
// audit.ts, gitLogForEnv
function gitLogForEnv(): { committed: boolean; files: string[]; error: boolean } {
  try {
    // ... execSync ...
    return { committed: files.length > 0, files, error: false };
  } catch {
    return { committed: false, files: [], error: true };
  }
}

// audit.ts, runCheck (git log branch)
    if (check.command.includes("git log")) {
      const r = gitLogForEnv();
      findings.push({
        id: check.id, title: check.title, category: categoryKey, severity: check.severity,
        status: r.error ? "skip" : (r.committed ? "fail" : "pass"),
        reason: r.error ? "git history unavailable or not a git repo" : undefined,
        rearm_when: r.error ? "git repository is initialized" : undefined,
        // ...
```
*(Apply identical `error: boolean` pattern to `checkGitRemote` for DEP004).*

**Fix 3: Walker blind spots claiming coverage**
Remove the hardcoded build-dir skips from `walk()` and rely strictly on rule-level `exclude` arrays (which SEC001 already uses correctly).
```typescript
// audit.ts, walk()
  for (const entry of entries) {
    // REMOVE: || entry === ".next" || entry === "dist" || entry === "build"
    if (entry === "node_modules" || entry === ".git" || entry === "Trash" || entry === ".z" || entry === "__pycache__") continue;
```
*(Then add `"dist/**", "build/**", ".next/**"` to the `exclude` arrays of `INJ001`, `AI001`, `PLAT002`, etc., in `checklist.json`).*