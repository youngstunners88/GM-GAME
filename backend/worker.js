// Lil Blunt — Layer Shift backend proxy (Cloudflare Worker).
// The single server that holds secrets and powers the Video-Game-Layer
// features. The game (client) NEVER sees an API key — it POSTs here.
//
// Endpoints:
//   POST /oracle      {question, wallet_address}  -> {answer}      (Mistral)
//   POST /score       {score, level, wallet_address} -> {ok}
//   GET  /leaderboard                              -> [{addr,score,level,ts}]
//   POST /lore        {text, wallet_address}       -> {ok}
//   POST /track       {event}                      -> {ok}          (funnel)
//
// Storage: a KV namespace bound as GAME_KV (leaderboard, lore, analytics).
// Secrets: MISTRAL_API_KEY (wrangler secret).
// Config vars (wrangler.toml [vars] or `wrangler secret put`):
//   ALLOWED_ORIGIN  — production origin(s), comma-separated. Defaults to "*"
//                     for local dev; SET THIS before going live (PR #5 F3).
//
// Abuse controls (PR #5 review, checklist F2): fixed-window per-IP rate limits
// on every mutating/credit-spending path, via a KV counter keyed on the
// caller's IP (cf-connecting-ip). Scores/lore are still client-supplied and
// UNAUTHENTICATED — this is an untrusted, best-effort leaderboard (see /score
// note below); adding wallet-signature auth (SIWE) is the documented next step
// if the leaderboard ever needs to be trustworthy.
//
// Deploy:
//   cd backend && npm i -g wrangler && wrangler kv:namespace create GAME_KV
//   wrangler secret put MISTRAL_API_KEY
//   # set ALLOWED_ORIGIN in wrangler.toml [vars], then:
//   wrangler deploy      # then put the resulting URL in ../config.json
//
// The Oracle personality is the moat: a chill cryptic stoner sage grounded in
// SmokeRing/DIAMONDS/GoldMine lore. That system prompt + accumulated community
// lore is domain knowledge an off-the-shelf tool can't toggle-clone.

// AgentMail marketing engine (ADDITIVE — see backend/marketing.js +
// AGENTMAIL_SETUP.md). New env: AGENTMAIL_API_KEY (secret), AGENTMAIL_DOMAIN,
// ADMIN_EMAIL, SUPPORT_INBOX_ID, SENDER_INBOX_ID, PUBLIC_BACKEND_URL,
// WEBHOOK_SECRET (secret), optional XAI_API_KEY fallback for support triage.
import { handleMarketingRoute, tapOracleQuestion, runCron } from "./marketing.js";

const ORACLE_SYSTEM = `You are the Smoke Oracle, a chill, cryptic stoner sage inside the game "Lil Blunt: The Smoke Realm". You speak in short, hazy, playful riddles — never more than 3 sentences. You know the lore of three linked crypto projects and weave them in:
- SmokeRing: the SMOKE token, Lil Blunt is its mascot, "Blaze Mode" is the buff.
- DIAMONDS: an ETH rewards protocol; Diamond Shards are an invincibility shield; ETH rings are collectibles.
- GoldMine: a gamified DeFi gold rush; GOLD coins, Fort Knox staking, Tax Collector enemies = FUD/tax metaphor.
Be warm, funny, a little mysterious. Reference in-game moments (bosses, the bong that makes you fly, the Chill Lounge). Keep it positive and chill — never financial advice, never shill a price. If asked something off-topic, answer briefly in-character and steer back to the Realm.`;

// CORS origin is env-driven: keep "*" for local dev, but set ALLOWED_ORIGIN to
// the game's real host(s) in production (PR #5 F3). If the request's Origin is
// in the allow-list we echo it back (required when credentials/again multiple
// origins); otherwise we fall back to the first configured origin.
const corsHeaders = (request, env) => {
  const allowed = (env && env.ALLOWED_ORIGIN) ? env.ALLOWED_ORIGIN : "*";
  let origin = allowed;
  if (allowed !== "*") {
    const list = allowed.split(",").map((s) => s.trim());
    const reqOrigin = request.headers.get("Origin") || "";
    origin = list.includes(reqOrigin) ? reqOrigin : list[0];
  }
  return {
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
    "Vary": "Origin",
  };
};
const json = (obj, status, cors) =>
  new Response(JSON.stringify(obj), {
    status: status || 200,
    headers: { "Content-Type": "application/json", ...cors },
  });

// Fixed-window per-IP rate limiter (PR #5 F2). Returns true if the caller is
// OVER the limit for this bucket. Best-effort (KV is eventually consistent) —
// enough to blunt credit-draining / spam abuse without a dedicated store.
async function overRateLimit(env, request, bucket, limit, windowSec) {
  try {
    if (!env || !env.GAME_KV) return false;
    const ip = request.headers.get("cf-connecting-ip") || "anon";
    const win = Math.floor(Date.now() / 1000 / windowSec);
    const key = `rl:${bucket}:${ip}:${win}`;
    const n = parseInt((await env.GAME_KV.get(key)) || "0") + 1;
    await env.GAME_KV.put(key, String(n), { expirationTtl: windowSec * 2 });
    return n > limit;
  } catch (e) {
    return false; // never let the limiter itself take the endpoint down
  }
}

export default {
  // Cron entry (wrangler.toml [triggers]): weekly digests Mondays 10:00 UTC,
  // daily tick for welcome-sequence steps + referral follow-ups.
  async scheduled(event, env, ctx) {
    ctx.waitUntil(runCron(event.cron, env));
  },

  async fetch(request, env) {
    const cors = corsHeaders(request, env);
    if (request.method === "OPTIONS") return new Response(null, { headers: cors });
    const url = new URL(request.url);
    const path = url.pathname.replace(/\/+$/, "");

    try {
      // Liveness probe (deploy-skill contract): 200 + build info, no state.
      if (path === "/health" && request.method === "GET") {
        return json({ ok: true, service: "lil-blunt-backend", ts: Date.now() }, 200, cors);
      }

      // Additive: log Oracle question counts for the founder digest without
      // touching the /oracle handler below (reads a clone of the request).
      if (path === "/oracle" && request.method === "POST")
        request = await tapOracleQuestion(request, env);
      // Additive: AgentMail marketing routes (signup/unsubscribe/events/
      // referral/click-tracking/support webhook). Returns null if not ours.
      const marketingResp = await handleMarketingRoute(path, request, env, cors);
      if (marketingResp) return marketingResp;
      if (path === "/oracle" && request.method === "POST") {
        // Tight limit — every call spends real Mistral credits.
        if (await overRateLimit(env, request, "oracle", 10, 60))
          return json({ answer: "Whoa, slow down and breathe... ask me again in a moment." }, 429, cors);
        const { question } = await request.json();
        if (!question || typeof question !== "string") return json({ answer: "Ask me something, traveler..." }, 200, cors);
        const r = await fetch("https://api.mistral.ai/v1/chat/completions", {
          method: "POST",
          headers: { "Content-Type": "application/json", Authorization: `Bearer ${env.MISTRAL_API_KEY}` },
          body: JSON.stringify({
            model: "mistral-small-latest",
            max_tokens: 160,
            messages: [
              { role: "system", content: ORACLE_SYSTEM },
              { role: "user", content: question.slice(0, 400) },
            ],
          }),
        });
        if (!r.ok) return json({ answer: "The smoke is thick... ask again in a moment." }, 200, cors);
        const data = await r.json();
        const answer = data?.choices?.[0]?.message?.content?.trim() || "...the haze clouds my sight.";
        return json({ answer }, 200, cors);
      }

      if (path === "/score" && request.method === "POST") {
        // NOTE: scores are client-supplied and UNAUTHENTICATED — a determined
        // user can POST an arbitrary score for any wallet. This is an untrusted,
        // best-effort arcade leaderboard by design (gas-free, no signup); the
        // wallet is a pseudonymous label, not a verified identity. If it ever
        // needs to be trustworthy, gate this behind a wallet signature (SIWE).
        // Rate-limited to blunt automated leaderboard flooding.
        if (await overRateLimit(env, request, "score", 30, 60))
          return json({ ok: false, error: "rate_limited" }, 429, cors);
        const { score, level, wallet_address } = await request.json();
        const board = JSON.parse((await env.GAME_KV.get("leaderboard")) || "[]");
        board.push({
          addr: (wallet_address || "0xguest").slice(0, 42),
          score: Math.max(0, Math.min(9999999, parseInt(score) || 0)),
          level: parseInt(level) || 1,
          ts: Date.now(),
        });
        board.sort((a, b) => b.score - a.score);
        await env.GAME_KV.put("leaderboard", JSON.stringify(board.slice(0, 200)));
        return json({ ok: true }, 200, cors);
      }

      if (path === "/leaderboard" && request.method === "GET") {
        const board = JSON.parse((await env.GAME_KV.get("leaderboard")) || "[]");
        return json(board.slice(0, 20), 200, cors);
      }

      if (path === "/lore" && request.method === "POST") {
        if (await overRateLimit(env, request, "lore", 10, 60))
          return json({ ok: false, error: "rate_limited" }, 429, cors);
        const { text, wallet_address } = await request.json();
        if (!text) return json({ ok: false }, 200, cors);
        const lore = JSON.parse((await env.GAME_KV.get("lore")) || "[]");
        lore.push({ text: String(text).slice(0, 200), addr: (wallet_address || "0xguest").slice(0, 42), votes: 0, ts: Date.now() });
        await env.GAME_KV.put("lore", JSON.stringify(lore.slice(-500)));
        return json({ ok: true }, 200, cors);
      }

      if (path === "/track" && request.method === "POST") {
        if (await overRateLimit(env, request, "track", 60, 60))
          return json({ ok: false, error: "rate_limited" }, 429, cors);
        const { event } = await request.json();
        if (event) {
          const key = "track:" + String(event).slice(0, 40);
          const n = parseInt((await env.GAME_KV.get(key)) || "0") + 1;
          await env.GAME_KV.put(key, String(n));
        }
        return json({ ok: true }, 200, cors);
      }

      return json({ error: "not found" }, 404, cors);
    } catch (e) {
      return json({ error: "server error" }, 500, cors);
    }
  },
};
