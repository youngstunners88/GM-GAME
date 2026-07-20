#!/usr/bin/env node
// Kimi K3 full-architecture audit (mandatory pre-itch gate, task 4B).
// Reads the load-bearing files across backend + game seams, sends ONE big
// review request to Kimi K3 via OpenRouter, saves the verbatim findings for
// KIMI_AUDIT_FEEDBACK.md. Falls back to Mistral with the same prompt if
// OpenRouter is down. Node 18+; keys from env only.
// Usage: node scripts/kimi-architecture-audit.js > audit-out.md

import { readFileSync, existsSync } from "node:fs";

// Key files (repo reality: backend is .js not .ts; game code lives in src/).
const FILES = [
  "backend/worker.js", "backend/marketing.js", "backend/agentmail.js",
  "backend/kimi_client.js", "backend/email_templates.js",
  "src/autoload/web3_bridge.gd", "src/autoload/game_manager.gd",
  "src/autoload/difficulty_manager.gd", "src/autoload/state_machine.gd",
  "src/player/player.gd",
  "src/ui/main_menu.gd", "src/ui/victory_screen.gd", "src/ui/oracle_panel.gd",
  "src/ui/email_signup_panel.gd", "src/ui/crypto_onboarding.gd",
  "web/web3.js", "config.json",
];

const SYSTEM = "You are a senior game security architect and Godot 4.3 specialist. Review the attached codebase for: 1) Critical security vulnerabilities 2) Godot 4.3 anti-patterns and performance traps 3) Web3/crypto safety issues 4) Missing error handling and edge cases 5) Race conditions in async flows. Be extremely critical. Rate each finding [CRITICAL], [HIGH], [MEDIUM], or [LOW]. Suggest specific fixes with code examples.";

let corpus = "";
for (const f of FILES) {
  if (!existsSync(f)) { corpus += `\n===== ${f} (MISSING) =====\n`; continue; }
  const body = readFileSync(f, "utf-8");
  corpus += `\n===== ${f} (${body.split("\n").length} lines) =====\n${body.slice(0, 30000)}\n`;
}

async function chat(url, key, model, extra = {}) {
  const r = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${key}` },
    body: JSON.stringify({
      model, max_tokens: 8000,
      messages: [{ role: "system", content: SYSTEM }, { role: "user", content: corpus }],
      ...extra,
    }),
  });
  if (!r.ok) throw new Error(`${url} -> ${r.status}`);
  const d = await r.json();
  const m = d?.choices?.[0]?.message;
  const out = m?.content || m?.reasoning || "";
  if (!out) throw new Error("empty completion");
  return out;
}

let review, engine;
try {
  review = await chat("https://openrouter.ai/api/v1/chat/completions",
    process.env.OPENROUTER_API_KEY,
    process.env.KIMI_MODEL || "moonshotai/kimi-k3",
    { reasoning: { effort: "medium" } });
  engine = "Kimi K3 (OpenRouter)";
} catch (e) {
  // Fallback: Mistral, same prompt (task 4B requirement).
  const mk = process.env.MINSTRAL_API_KEY || process.env.MISTRAL_API_KEY;
  review = await chat("https://api.mistral.ai/v1/chat/completions", mk,
    process.env.MISTRAL_MODEL || "mistral-large-latest");
  engine = "Mistral (fallback: " + String(e).slice(0, 80) + ")";
}

console.log(`<!-- engine: ${engine} · files: ${FILES.length} · ${new Date().toISOString()} -->\n`);
console.log(review);
