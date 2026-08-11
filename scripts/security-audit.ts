#!/usr/bin/env bun
// Shim. The scanner now lives with its rules and its reference doc in the
// skill, at the upstream pack's own layout:
//
//   .claude/skills/secure-build-checklist/
//     SKILL.md  assets/checklist.json  references/checklist.md  scripts/audit.ts
//
// This file is kept so `bun scripts/security-audit.ts` — the path CI, the
// release script and a year of habit all use — keeps working. It re-execs the
// real scanner rather than duplicating it: one implementation, no drift, which
// is the same rule CLAUDE.md already applies to the sentinel.
import { spawnSync } from "node:child_process";
import { join } from "node:path";

const real = join(
  import.meta.dir, "..", ".claude", "skills", "secure-build-checklist", "scripts", "audit.ts"
);
const r = spawnSync("bun", [real, ...process.argv.slice(2)], { stdio: "inherit" });
process.exit(r.status ?? 2);
