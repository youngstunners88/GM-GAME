// Kimi K3 client via OpenRouter (Level Depth / enhancement layer).
// Slug verified against the live OpenRouter model list: "moonshotai/kimi-k3".
// Used as an LLM tier in the fallback chain (support triage, newsletter copy
// drafting) — Mistral stays primary where configured; Kimi is the enhancement
// when Mistral is missing/rate-limited; XAI Grok remains the last resort.
// Key: env.OPENROUTER_API_KEY (Worker secret — never client-side).

const OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions";

/** One chat completion against Kimi K3. Returns content string or null. */
export async function kimiChat(env, system, user, maxTokens) {
  if (!env.OPENROUTER_API_KEY) return null;
  try {
    const r = await fetch(OPENROUTER_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${env.OPENROUTER_API_KEY}`,
        // OpenRouter attribution headers (optional, aids their moderation).
        "HTTP-Referer": "https://youngstunners88.itch.io/lil-blunt-adventure",
        "X-Title": "Lil Blunt: The Smoke Realm",
      },
      body: JSON.stringify({
        model: env.KIMI_MODEL || "moonshotai/kimi-k3",
        // Kimi K3 is a REASONING model: with a small max_tokens it can spend
        // the whole budget thinking and return content:null. Keep reasoning
        // effort low (cost control) and budget enough for the answer.
        max_tokens: Math.max(1200, maxTokens || 0),
        reasoning: { effort: "low" },
        messages: [
          { role: "system", content: system },
          { role: "user", content: user },
        ],
      }),
    });
    if (!r.ok) return null;
    const d = await r.json();
    const msg = d?.choices?.[0]?.message;
    // content preferred; if the provider still returns reasoning-only, use it.
    return msg?.content || msg?.reasoning || null;
  } catch (e) {
    return null;
  }
}
