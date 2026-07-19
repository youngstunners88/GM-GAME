// Weekly share-card taglines via Kimi K3 (content-engine skill).
// Usage: node backend/content_engine/score_card_taglines.js
// Output: marketing/assets/taglines_week_<ISO-week>.json
// HUMAN-IN-THE-LOOP: outputs are drafts. Merge the keepers into
// GameManager.SHARE_TAGLINES (src/autoload/game_manager.gd) by hand —
// scripts never edit game code (decision: marketing/03-decisions.md).

import { kimi, extractJsonArray } from "./kimi_content.js";
import { writeFileSync, mkdirSync } from "node:fs";

const week = (() => {
  const d = new Date(); const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
  t.setUTCDate(t.getUTCDate() + 4 - (t.getUTCDay() || 7));
  return `${t.getUTCFullYear()}-W${String(Math.ceil(((t - Date.UTC(t.getUTCFullYear(),0,1)) / 86400000 + 1) / 7)).padStart(2, "0")}`;
})();

const raw = await kimi(
  "You write share-card taglines for 'Lil Blunt: The Smoke Realm', a chill stoner-mascot crypto platformer. Output ONLY a JSON array of strings.",
  "Write 10 funny, crypto-themed taglines. Reference: bear markets, HODL, diamond hands, gas fees, rug pulls. Keep each under 60 chars. No profanity, no financial advice, no dollar signs before words.");
const taglines = extractJsonArray(raw).map(String).filter((t) => t.length <= 60).slice(0, 10);
if (taglines.length < 5) throw new Error("too few usable taglines");
mkdirSync("marketing/assets", { recursive: true });
const out = `marketing/assets/taglines_week_${week}.json`;
writeFileSync(out, JSON.stringify({ week, taglines, status: "draft — merge keepers into GameManager.SHARE_TAGLINES" }, null, 2));
console.log(`wrote ${out}:\n` + taglines.map((t) => `  - ${t}`).join("\n"));
