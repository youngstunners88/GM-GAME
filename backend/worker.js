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
// Secrets: MISTRAL_API_KEY (wrangler secret). CORS open (public game).
//
// Deploy:
//   cd backend && npm i -g wrangler && wrangler kv:namespace create GAME_KV
//   wrangler secret put MISTRAL_API_KEY
//   wrangler deploy      # then put the resulting URL in ../config.json
//
// The Oracle personality is the moat: a chill cryptic stoner sage grounded in
// SmokeRing/DIAMONDS/GoldMine lore. That system prompt + accumulated community
// lore is domain knowledge an off-the-shelf tool can't toggle-clone.

const ORACLE_SYSTEM = `You are the Smoke Oracle, a chill, cryptic stoner sage inside the game "Lil Blunt: The Smoke Realm". You speak in short, hazy, playful riddles — never more than 3 sentences. You know the lore of three linked crypto projects and weave them in:
- SmokeRing: the SMOKE token, Lil Blunt is its mascot, "Blaze Mode" is the buff.
- DIAMONDS: an ETH rewards protocol; Diamond Shards are an invincibility shield; ETH rings are collectibles.
- GoldMine: a gamified DeFi gold rush; GOLD coins, Fort Knox staking, Tax Collector enemies = FUD/tax metaphor.
Be warm, funny, a little mysterious. Reference in-game moments (bosses, the bong that makes you fly, the Chill Lounge). Keep it positive and chill — never financial advice, never shill a price. If asked something off-topic, answer briefly in-character and steer back to the Realm.`;

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
};
const json = (obj, status = 200) =>
  new Response(JSON.stringify(obj), { status, headers: { "Content-Type": "application/json", ...CORS } });

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") return new Response(null, { headers: CORS });
    const url = new URL(request.url);
    const path = url.pathname.replace(/\/+$/, "");

    try {
      if (path === "/oracle" && request.method === "POST") {
        const { question } = await request.json();
        if (!question || typeof question !== "string") return json({ answer: "Ask me something, traveler..." });
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
        if (!r.ok) return json({ answer: "The smoke is thick... ask again in a moment." });
        const data = await r.json();
        const answer = data?.choices?.[0]?.message?.content?.trim() || "...the haze clouds my sight.";
        return json({ answer });
      }

      if (path === "/score" && request.method === "POST") {
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
        return json({ ok: true });
      }

      if (path === "/leaderboard" && request.method === "GET") {
        const board = JSON.parse((await env.GAME_KV.get("leaderboard")) || "[]");
        return json(board.slice(0, 20));
      }

      if (path === "/lore" && request.method === "POST") {
        const { text, wallet_address } = await request.json();
        if (!text) return json({ ok: false });
        const lore = JSON.parse((await env.GAME_KV.get("lore")) || "[]");
        lore.push({ text: String(text).slice(0, 200), addr: (wallet_address || "0xguest").slice(0, 42), votes: 0, ts: Date.now() });
        await env.GAME_KV.put("lore", JSON.stringify(lore.slice(-500)));
        return json({ ok: true });
      }

      if (path === "/track" && request.method === "POST") {
        const { event } = await request.json();
        if (event) {
          const key = "track:" + String(event).slice(0, 40);
          const n = parseInt((await env.GAME_KV.get(key)) || "0") + 1;
          await env.GAME_KV.put(key, String(n));
        }
        return json({ ok: true });
      }

      return json({ error: "not found" }, 404);
    } catch (e) {
      return json({ error: "server error" }, 500);
    }
  },
};
