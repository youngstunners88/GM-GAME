// Content-engine Kimi K3 client (content-engine skill). Node 18+ (built-in
// fetch) — these tools run LOCALLY/CI on demand, not inside the Worker.
// Reasoning-model safe: effort low, >=1500 token budget, content||reasoning.
// Slug verified live on OpenRouter: moonshotai/kimi-k3 (the skill doc's
// kimi-k2 note predates the K3 release; K3 confirmed available 2026-07-19).
// Key: OPENROUTER_API_KEY env — never committed, never client-side.

export async function kimi(system, user, maxTokens = 1500) {
  const key = process.env.OPENROUTER_API_KEY;
  if (!key) throw new Error("OPENROUTER_API_KEY not set");
  const r = await fetch("https://openrouter.ai/api/v1/chat/completions", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${key}`,
      "HTTP-Referer": "https://youngstunners88.itch.io/lil-blunt-adventure",
      "X-Title": "Lil Blunt Content Engine",
    },
    body: JSON.stringify({
      model: process.env.KIMI_MODEL || "moonshotai/kimi-k3",
      max_tokens: Math.max(1500, maxTokens),
      reasoning: { effort: "low" },
      messages: [
        { role: "system", content: system },
        { role: "user", content: user },
      ],
    }),
  });
  if (!r.ok) throw new Error(`OpenRouter ${r.status}: ${(await r.text()).slice(0, 200)}`);
  const d = await r.json();
  const m = d?.choices?.[0]?.message;
  const out = m?.content || m?.reasoning || "";
  if (!out) throw new Error("empty completion");
  return out.trim();
}

/** Pull a JSON array out of a completion that may carry prose/fences. */
export function extractJsonArray(text) {
  const match = text.match(/\[[\s\S]*\]/);
  if (!match) throw new Error("no JSON array in output");
  return JSON.parse(match[0]);
}
