// Weekly newsletter draft: live analytics -> Kimi K3 -> AgentMail Draft ->
// human approval -> send (content-engine skill; NEVER auto-sends).
// Usage: node backend/content_engine/weekly_digest_generator.js [--sample]
//   --sample: use placeholder stats (pre-deploy dry-run; no backend needed)
// Env: OPENROUTER_API_KEY (required), AGENT_MAIL_API_KEY (optional — without
// it the draft prints to marketing/assets/ instead of AgentMail),
// BACKEND_URL (optional — live stats source once the Worker is deployed).

import { kimi } from "./kimi_content.js";
import { writeFileSync, mkdirSync } from "node:fs";

const SAMPLE = process.argv.includes("--sample");
const BACKEND = process.env.BACKEND_URL || "";
const INBOX = "smokering-notifications@agentmail.to";

async function liveStats() {
  const board = await (await fetch(`${BACKEND}/leaderboard`)).json();
  const top = Array.isArray(board) && board[0] ? board[0] : null;
  return {
    top_player: top ? top.addr : "nobody yet",
    top_score: top ? top.score : 0,
    top_death_cause: "the Tax Collector", // aggregate death leader; refine when /admin stats endpoint lands
    community_event: "a secret wall spilled fresh community lore",
  };
}
const stats = SAMPLE || !BACKEND
  ? { top_player: "0x1234...5678", top_score: 12800, top_death_cause: "the Tax Collector", community_event: "someone reflected a Diamond Surge shard on the first try" }
  : await liveStats();

const draft = await kimi(
  "You write the weekly Smoke Realm newsletter in Lil Blunt's voice: chill, crypto-savvy, warm, funny, zero financial advice. Plain text, ~150 words, with a subject line on the first line prefixed 'SUBJECT: '.",
  `Write this week's newsletter. Top player: ${stats.top_player}, score: ${stats.top_score}. Most deaths: ${stats.top_death_cause}. Funniest moment: ${stats.community_event}. Include a CTA to play (https://youngstunners88.itch.io/lil-blunt-adventure) and to join Telegram (t.me/LilBluntdotWin).`);

const subject = (draft.match(/^SUBJECT:\s*(.+)$/m) || [, "Smoke Realm weekly"])[1].trim();
const body = draft.replace(/^SUBJECT:.*$/m, "").trim();

const key = process.env.AGENT_MAIL_API_KEY || process.env.AGENTMAIL_API_KEY;
if (key) {
  const r = await fetch(`https://api.agentmail.to/v0/inboxes/${encodeURIComponent(INBOX)}/drafts`, {
    method: "POST",
    headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
    body: JSON.stringify({ subject, text: body, labels: ["weekly_newsletter", "needs_approval"] }),
  });
  console.log(r.ok ? `AgentMail DRAFT created in ${INBOX} — approve there to send.` : `AgentMail draft failed (${r.status}) — falling back to file.`);
  if (r.ok) process.exit(0);
}
mkdirSync("marketing/assets", { recursive: true });
writeFileSync("marketing/assets/newsletter_draft_latest.md", `SUBJECT: ${subject}\n\n${body}\n`);
console.log("wrote marketing/assets/newsletter_draft_latest.md (human review before send)");
