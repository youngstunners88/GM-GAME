// AgentMail marketing engine (Layer Shift).
// Movie Layer: founder digest + branded player comms (domain knowledge baked in).
// Video-Game Layer: campaigns driven by each player's OWN play data (rank,
// deaths, absence), welcome sequences, two-way AI support — self-improving
// from the data the game generates.
//
// Everything here is ADDITIVE to worker.js: the router exposes one function
// (handleMarketingRoute) and one cron entry (runCron). No existing endpoint
// is modified. The AgentMail key lives ONLY in env (see agentmail.js).
//
// KV data model (GAME_KV):
//   pemail:<pid>            {email, consent, wallet, name, created_at,
//                            last_sent_at, welcome_stage, played_at, unsub_token}
//   pemail_index            [pid,...]  (bounded)
//   unsub:<token>           pid
//   suppress:<email>        reason              (see agentmail.js)
//   sentday:<pid>:<yyyymmdd> "1"                (1 email/player/day cap)
//   deaths:<week>:<pid>     {"tax": 3, ...}
//   players_week:<week>     [pid,...]
//   walletconnects:<week>   count
//   digestrank:<pid>        {week, rank, score}  (for delta vs last week)
//   cta:<week>:<name>       count
//   oq:<week>:<b64(question)> count              (Oracle question log)
//   ref:<token>             {referrer, referrer_name, friend_email, sent_at,
//                            clicked_at, converted_at, followup_sent}
//   ref_index               [token,...]
//   milestone:<pid>:<name>  "1"                 (first-time gates)

import { sendEmail, draftThenSend, createDraft, labelMessage, suppress, isSuppressed } from "./agentmail.js";
import * as T from "./email_templates.js";

const GAME_URL = "https://youngstunners88.itch.io/lil-blunt-adventure";
const BOSS_TIPS = {
  tax: "double-jump over his charge, then hit him while he's dizzy.",
  crystal: "his orbs home in — bait them into a wall, then close in.",
  bandit: "the dynamite has a shadow. Watch the ground, not him.",
};
const BOSS_NAMES = { tax: "Tax Collector", crystal: "Crystalline Bureaucrat", bandit: "Bandit" };

const json = (obj, status, cors) =>
  new Response(JSON.stringify(obj), { status: status || 200, headers: { "Content-Type": "application/json", ...cors } });

// ---- small utils ----------------------------------------------------------
const now = () => Date.now();
const isoWeek = (d) => {
  const dt = d ? new Date(d) : new Date();
  const t = new Date(Date.UTC(dt.getUTCFullYear(), dt.getUTCMonth(), dt.getUTCDate()));
  t.setUTCDate(t.getUTCDate() + 4 - (t.getUTCDay() || 7));
  const y = t.getUTCFullYear();
  const w = Math.ceil(((t - Date.UTC(y, 0, 1)) / 86400000 + 1) / 7);
  return `${y}-W${String(w).padStart(2, "0")}`;
};
const dayStamp = () => new Date().toISOString().slice(0, 10).replace(/-/g, "");
const token = () => crypto.randomUUID().replace(/-/g, "");
const kvJson = async (env, key, fallback) => {
  try { return JSON.parse((await env.GAME_KV.get(key)) || "null") ?? fallback; }
  catch (e) { return fallback; }
};

// Email syntax + MX check (no deps: DNS-over-HTTPS against Cloudflare).
const EMAIL_RE = /^[^\s@]{1,64}@[^\s@]{1,255}\.[^\s@]{2,}$/;
async function validEmail(email) {
  if (!EMAIL_RE.test(email || "")) return false;
  try {
    const domain = email.split("@")[1];
    const r = await fetch(`https://cloudflare-dns.com/dns-query?name=${encodeURIComponent(domain)}&type=MX`,
      { headers: { Accept: "application/dns-json" } });
    const d = await r.json();
    return Array.isArray(d.Answer) && d.Answer.length > 0;
  } catch (e) {
    return true; // DNS check is best-effort; never block signup on resolver hiccups
  }
}

// Open-redirect guard for the /go click tracker: only these hosts may be
// redirect targets, everything else falls back to the game.
const REDIRECT_HOSTS = ["itch.io", "twitter.com", "x.com", "basescan.org", "t.me"];
function safeRedirect(env, to) {
  try {
    const u = new URL(to);
    const host = u.hostname.toLowerCase();
    const backendHost = env.PUBLIC_BACKEND_URL ? new URL(env.PUBLIC_BACKEND_URL).hostname : "";
    if (host === backendHost || REDIRECT_HOSTS.some((h) => host === h || host.endsWith("." + h)))
      return u.toString();
  } catch (e) { /* fallthrough */ }
  return GAME_URL;
}

// 1-email-per-player-per-day cap (welcome sequence exempt, per spec).
async function underDailyCap(env, pid) {
  return (await env.GAME_KV.get(`sentday:${pid}:${dayStamp()}`)) === null;
}
async function markSent(env, pid, rec) {
  await env.GAME_KV.put(`sentday:${pid}:${dayStamp()}`, "1", { expirationTtl: 172800 });
  rec.last_sent_at = now();
  await env.GAME_KV.put("pemail:" + pid, JSON.stringify(rec));
}

// ---- player-record helpers ------------------------------------------------
async function getPlayer(env, pid) { return kvJson(env, "pemail:" + pid, null); }

async function addToIndex(env, key, val, cap) {
  const arr = await kvJson(env, key, []);
  if (!arr.includes(val)) {
    arr.push(val);
    await env.GAME_KV.put(key, JSON.stringify(arr.slice(-1 * (cap || 5000))));
  }
}

// ===========================================================================
// ROUTES — returns a Response if the path is ours, else null (worker falls
// through to its existing routes/404).
// ===========================================================================
export async function handleMarketingRoute(path, request, env, cors) {
  // -- TASK 1: email capture ------------------------------------------------
  if (path === "/email/signup" && request.method === "POST") {
    const { player_id, email, consent, wallet_address, name } = await request.json();
    const pid = String(player_id || "").slice(0, 64);
    const addr = String(email || "").trim().toLowerCase().slice(0, 254);
    if (!pid || !addr) return json({ ok: false, error: "player_id and email required" }, 400, cors);
    if (consent !== true) return json({ ok: false, error: "consent required" }, 400, cors);
    if (!(await validEmail(addr))) return json({ ok: false, error: "invalid email" }, 400, cors);
    const existing = await getPlayer(env, pid);
    const rec = existing || {
      created_at: now(), welcome_stage: 0, played_at: 0, last_sent_at: 0,
      unsub_token: token(),
    };
    rec.email = addr;
    rec.consent = true;
    rec.name = String(name || "").slice(0, 40);
    if (wallet_address) rec.wallet = String(wallet_address).slice(0, 42);
    await env.GAME_KV.put("pemail:" + pid, JSON.stringify(rec));
    await env.GAME_KV.put("unsub:" + rec.unsub_token, pid);
    await addToIndex(env, "pemail_index", pid);
    // Referral conversion: the invited friend showed up and signed up.
    const refs = await kvJson(env, "ref_index", []);
    for (const t of refs.slice(-200)) {
      const r = await kvJson(env, "ref:" + t, null);
      if (r && r.friend_email === addr && !r.converted_at) {
        r.converted_at = now();
        await env.GAME_KV.put("ref:" + t, JSON.stringify(r));
      }
    }
    // TASK 2B: welcome email 1, immediately (welcome sequence is exempt from
    // the daily cap by design).
    if (!existing || !rec.welcome_stage) {
      const msg = T.welcome(env, 1, { name: rec.name, unsubToken: rec.unsub_token });
      const sent = await sendEmail(env, { to: addr, ...msg, labels: ["welcome_sent_1"], key: `welcome1:${pid}` });
      if (sent.ok) { rec.welcome_stage = 1; rec.welcome_1_at = now(); await env.GAME_KV.put("pemail:" + pid, JSON.stringify(rec)); }
    }
    return json({ ok: true }, 200, cors);
  }

  // One-click unsubscribe (GET for the mail-client link, POST for API use).
  if (path === "/unsubscribe" && (request.method === "GET" || request.method === "POST")) {
    let tok = "";
    if (request.method === "GET") tok = new URL(request.url).searchParams.get("token") || "";
    else tok = ((await request.json()).token) || "";
    const pid = await env.GAME_KV.get("unsub:" + String(tok).slice(0, 64));
    if (pid) {
      const rec = await getPlayer(env, pid);
      if (rec) {
        rec.consent = false;
        await env.GAME_KV.put("pemail:" + pid, JSON.stringify(rec));
        await suppress(env, rec.email, "one-click unsubscribe");
      }
    }
    if (request.method === "POST") return json({ ok: true }, 200, cors);
    return new Response(
      "<html><body style='background:#0c1410;color:#e7f5ec;font-family:sans-serif;text-align:center;padding:60px'>" +
      "<h2>🌿 You're unsubscribed.</h2><p>No more emails. The Realm door stays open whenever you want back in.</p></body></html>",
      { headers: { "Content-Type": "text/html", ...cors } });
  }

  // -- game events (deaths / plays / boss defeats / wallet connects) --------
  if (path === "/events" && request.method === "POST") {
    const { player_id, event, boss, score, first_time, wallet_address } = await request.json();
    const pid = String(player_id || "anon").slice(0, 64);
    const week = isoWeek();
    if (event === "play_start") {
      await addToIndex(env, "players_week:" + week, pid, 20000);
      const rec = await getPlayer(env, pid);
      if (rec) { rec.played_at = now(); await env.GAME_KV.put("pemail:" + pid, JSON.stringify(rec)); }
    } else if (event === "death" && boss) {
      const k = `deaths:${week}:${pid}`;
      const d = await kvJson(env, k, {});
      d[String(boss).slice(0, 20)] = (d[boss] || 0) + 1;
      await env.GAME_KV.put(k, JSON.stringify(d), { expirationTtl: 1209600 });
    } else if (event === "wallet_connect") {
      const k = "walletconnects:" + week;
      await env.GAME_KV.put(k, String(parseInt((await env.GAME_KV.get(k)) || "0") + 1));
    } else if (event === "boss_defeat" && first_time) {
      // TASK 2C: first-Auditor-kill milestone email (idempotent via KV gate +
      // Idempotency-Key). Not subject to the daily cap gate-check failing the
      // player experience: if capped, we simply skip (the badge screen already
      // celebrated in-game).
      const rec = await getPlayer(env, pid);
      const gate = `milestone:${pid}:boss_${boss || "tax"}`;
      if (rec && rec.consent && (await env.GAME_KV.get(gate)) === null && (await underDailyCap(env, pid))) {
        const board = await kvJson(env, "leaderboard", []);
        const rank = 1 + board.findIndex((b) => rec.wallet && b.addr === rec.wallet);
        const msg = T.milestoneBossDefeat(env, {
          name: rec.name, wallet: rec.wallet, unsubToken: rec.unsub_token,
          score: score || 0, rank: rank > 0 ? rank : null,
        });
        const sent = await sendEmail(env, { to: rec.email, ...msg, labels: ["milestone_boss"], key: gate });
        if (sent.ok) { await env.GAME_KV.put(gate, "1"); await markSent(env, pid, rec); }
        // Top-10 milestone piggybacks on the same event when applicable.
        if (rank > 0 && rank <= 10) {
          const gate10 = `milestone:${pid}:top10`;
          if ((await env.GAME_KV.get(gate10)) === null) {
            const m10 = T.milestoneTop10(env, { name: rec.name, wallet: rec.wallet, unsubToken: rec.unsub_token, rank });
            const s10 = await createDraft(env, { to: rec.email, ...m10, labels: ["milestone_top10"], key: gate10 });
            if (s10.ok) await env.GAME_KV.put(gate10, "1");
          }
        }
      }
    }
    return json({ ok: true }, 200, cors);
  }

  // -- TASK 5: referral engine ---------------------------------------------
  if (path === "/referral" && request.method === "POST") {
    const { player_id, friend_email, player_name } = await request.json();
    const addr = String(friend_email || "").trim().toLowerCase().slice(0, 254);
    if (!(await validEmail(addr))) return json({ ok: false, error: "invalid email" }, 400, cors);
    if (await isSuppressed(env, addr)) return json({ ok: false, error: "recipient opted out" }, 400, cors);
    const t = token();
    const rec = {
      referrer: String(player_id || "anon").slice(0, 64),
      referrer_name: String(player_name || "").slice(0, 40),
      friend_email: addr, sent_at: now(), clicked_at: 0, converted_at: 0, followup_sent: 0,
    };
    const msg = T.referralInvite(env, { referrerName: rec.referrer_name, refToken: t, unsubToken: "ref-" + t });
    await env.GAME_KV.put("unsub:ref-" + t, "ref:" + t); // lets invitees unsubscribe too
    const sent = await sendEmail(env, { to: addr, ...msg, labels: ["referral_invite"], key: "ref:" + t });
    if (!sent.ok) return json({ ok: false, error: "send failed" }, 502, cors);
    await env.GAME_KV.put("ref:" + t, JSON.stringify(rec));
    await addToIndex(env, "ref_index", t, 2000);
    return json({ ok: true }, 200, cors);
  }

  // Referral click-through → mark clicked, off to the game.
  if (path === "/ref" && request.method === "GET") {
    const t = new URL(request.url).searchParams.get("token") || "";
    const r = await kvJson(env, "ref:" + String(t).slice(0, 64), null);
    if (r && !r.clicked_at) { r.clicked_at = now(); await env.GAME_KV.put("ref:" + t, JSON.stringify(r)); }
    return Response.redirect(GAME_URL, 302);
  }
  if (path === "/ref-page" && request.method === "GET") {
    return Response.redirect(GAME_URL, 302); // digest "Brag to a Friend" lands in-game (invite UI lives there)
  }

  // -- CTA click tracker (feeds "most-clicked CTA" in the admin digest) -----
  if (path === "/go" && request.method === "GET") {
    const u = new URL(request.url);
    const cta = (u.searchParams.get("cta") || "unknown").slice(0, 40);
    const k = `cta:${isoWeek()}:${cta}`;
    await env.GAME_KV.put(k, String(parseInt((await env.GAME_KV.get(k)) || "0") + 1), { expirationTtl: 2419200 });
    return Response.redirect(safeRedirect(env, u.searchParams.get("to") || GAME_URL), 302);
  }

  // -- TASK 4: two-way support (AgentMail webhook → LLM triage) -------------
  if (path === "/agentmail/webhook" && request.method === "POST") {
    const secret = new URL(request.url).searchParams.get("secret") || "";
    if (!env.WEBHOOK_SECRET || secret !== env.WEBHOOK_SECRET)
      return json({ ok: false, error: "unauthorized" }, 401, cors);
    const evt = await request.json();
    if (evt && evt.event_type === "message.received" && evt.message)
      return json(await handleSupportEmail(env, evt.message), 200, cors);
    return json({ ok: true, ignored: true }, 200, cors);
  }

  // -- template preview / testing (secret-gated; see AGENTMAIL_SETUP.md) ----
  if (path === "/email/preview" && request.method === "GET") {
    const u = new URL(request.url);
    if (!env.WEBHOOK_SECRET || u.searchParams.get("secret") !== env.WEBHOOK_SECRET)
      return json({ ok: false, error: "unauthorized" }, 401, cors);
    const tpl = u.searchParams.get("tpl") || "digest";
    const sample = {
      digest: () => T.weeklyDigest(env, { name: "BluntFan", rank: 4, score: 12800, delta: 300, played: true, unsubToken: "preview", top3: [{ addr: "0x1234567890abcdef1234", score: 20000 }, { addr: "0xabc4567890abcdef1234", score: 18000 }, { addr: "0xdef4567890abcdef1234", score: 15000 }], deaths: { boss: "Tax Collector", count: 12, tip: BOSS_TIPS.tax } }),
      missed: () => T.weeklyDigest(env, { name: "BluntFan", played: false, unsubToken: "preview" }),
      welcome1: () => T.welcome(env, 1, { name: "BluntFan", unsubToken: "preview" }),
      welcome2: () => T.welcome(env, 2, { name: "BluntFan", unsubToken: "preview" }),
      welcome3: () => T.welcome(env, 3, { name: "BluntFan", unsubToken: "preview" }),
      boss: () => T.milestoneBossDefeat(env, { name: "BluntFan", score: 9000, rank: 7, unsubToken: "preview" }),
      top10: () => T.milestoneTop10(env, { name: "BluntFan", rank: 9, unsubToken: "preview" }),
      referral: () => T.referralInvite(env, { referrerName: "BluntFan", refToken: "preview", unsubToken: "preview" }),
      admin: () => T.adminDigest(env, { week: isoWeek(), uniquePlayers: 42, walletConnects: 7, subscribers: 12, refSent: 5, refClicked: 3, refConverted: 1, top10: [{ addr: "0x1234567890abcdef1234", score: 20000 }], ctaTop: [{ cta: "play_now", count: 9 }], oracleTop: [{ q: "what is blaze mode?", count: 4 }] }),
    };
    const m = (sample[tpl] || sample.digest)();
    return new Response(m.html, { headers: { "Content-Type": "text/html", ...cors } });
  }

  return null; // not ours — worker continues to its existing routes
}

// ===========================================================================
// Oracle question tap — logs question counts for the admin digest WITHOUT
// touching the existing /oracle handler (we clone the request before it).
// ===========================================================================
export async function tapOracleQuestion(request, env) {
  try {
    const body = await request.clone().json();
    const q = String(body.question || "").trim().toLowerCase().slice(0, 120);
    if (q) {
      const k = `oq:${isoWeek()}:${btoa(unescape(encodeURIComponent(q))).slice(0, 100)}`;
      const cur = await kvJson(env, k, { q, count: 0 });
      cur.count += 1;
      await env.GAME_KV.put(k, JSON.stringify(cur), { expirationTtl: 2419200 });
    }
  } catch (e) { /* never break the Oracle over analytics */ }
  return request;
}

// ===========================================================================
// TASK 4 helper: LLM triage of an incoming support email.
// Mistral primary; XAI (Grok) fallback when Mistral is missing/down. The
// response is ALWAYS created as an AgentMail Draft; it is auto-sent only when
// confidence >= 0.7, else it stays a draft labeled human_review.
// ===========================================================================
const SUPPORT_FAQ = `FAQ:
- Controls: arrows/WASD move, Space jump (double-jump in air), J/Enter attack, E interact.
- Blaze Mode: grab a Weed Leaf; faster + higher jumps; stacks with double-jump.
- Wallet: optional! Main menu > CONNECT WALLET. Never required to play.
- Badge NFT: beat The Auditor, then "Claim Your Badge" on the victory screen.
- Lives: 3 per run; pits cost a life; game over returns to menu.
- Leaderboard: main menu > LEADERBOARD; submit from the victory screen.
- The game is free, browser-based, on itch.io. No install.`;

async function llmChat(env, system, user) {
  // Primary: Mistral. Fallback: XAI Grok (key may be set as XAI_API_KEY or XAI_API).
  const tries = [];
  if (env.MISTRAL_API_KEY) tries.push({
    url: "https://api.mistral.ai/v1/chat/completions",
    key: env.MISTRAL_API_KEY, model: env.MISTRAL_MODEL || "mistral-small-latest",
  });
  const xaiKey = env.XAI_API_KEY || env.XAI_API;
  if (xaiKey) tries.push({
    url: "https://api.x.ai/v1/chat/completions",
    key: xaiKey, model: env.XAI_MODEL || "grok-3-mini",
  });
  for (const t of tries) {
    try {
      const r = await fetch(t.url, {
        method: "POST",
        headers: { "Content-Type": "application/json", Authorization: `Bearer ${t.key}` },
        body: JSON.stringify({
          model: t.model, max_tokens: 500,
          messages: [{ role: "system", content: system }, { role: "user", content: user }],
        }),
      });
      if (!r.ok) continue;
      const d = await r.json();
      const c = d?.choices?.[0]?.message?.content;
      if (c) return c;
    } catch (e) { /* try next provider */ }
  }
  return null;
}

async function handleSupportEmail(env, message) {
  const from = (Array.isArray(message.from) ? message.from[0] : message.from) || "";
  const fromAddr = String(typeof from === "object" ? from.address || "" : from).toLowerCase();
  const subject = String(message.subject || "").slice(0, 200);
  const bodyText = String(message.text || message.preview || "").slice(0, 2000);
  const inboxId = message.inbox_id || env.SUPPORT_INBOX_ID;
  const messageId = message.message_id || message.id;

  // Player context, if this address belongs to a subscriber.
  let playerCtx = "Unknown player (no game record for this email).";
  const pids = await kvJson(env, "pemail_index", []);
  for (const pid of pids.slice(-500)) {
    const rec = await getPlayer(env, pid);
    if (rec && rec.email === fromAddr) {
      const board = await kvJson(env, "leaderboard", []);
      const rank = 1 + board.findIndex((b) => rec.wallet && b.addr === rec.wallet);
      playerCtx = `Player record: name=${rec.name || "?"} wallet=${rec.wallet ? "connected" : "none"} rank=${rank > 0 ? rank : "unranked"}.`;
      break;
    }
  }

  const raw = await llmChat(env,
    `You are the Smoke Oracle answering a support email for the game "Lil Blunt: The Smoke Realm". Be warm, concise, chill. Use the FAQ and player context. ${SUPPORT_FAQ}\n${playerCtx}\nRespond ONLY with JSON: {"answer": "<email body, plain text>", "confidence": <0..1>, "category": "question|bug_report|feature_request|other"}`,
    `Subject: ${subject}\n\n${bodyText}`);

  let parsed = null;
  try { parsed = JSON.parse((raw || "").replace(/```json|```/g, "").trim()); } catch (e) { /* not JSON */ }
  if (!parsed || !parsed.answer) {
    if (inboxId && messageId) await labelMessage(env, inboxId, messageId, ["human_review"]);
    return { ok: true, action: "human_review", reason: "llm unavailable or unparseable" };
  }

  const confident = Number(parsed.confidence) >= 0.7;
  const labels = [confident ? "auto_resolved" : "human_review"];
  if (parsed.category === "bug_report") labels.push("bug_report");
  if (parsed.category === "feature_request") labels.push("feature_request");
  if (inboxId && messageId) await labelMessage(env, inboxId, messageId, labels);

  const reply = T.supportReply(env, { subject, body: parsed.answer });
  const key = "support:" + (messageId || token());
  if (confident) {
    const sent = await draftThenSend(env, { to: fromAddr, ...reply, labels, key, inbox: inboxId });
    return { ok: true, action: sent.ok ? "auto_resolved" : "human_review", sent: !!sent.ok };
  }
  await createDraft(env, { to: fromAddr, ...reply, labels, key, inbox: inboxId });
  return { ok: true, action: "human_review", draft: true };
}

// ===========================================================================
// CRON — wrangler.toml triggers:
//   "0 10 * * 1"  weekly: player digests + founder digest  (Mon 10:00 UTC)
//   "0 9 * * *"   daily: welcome sequence steps + referral follow-ups
// ===========================================================================
export async function runCron(cronPattern, env) {
  if (cronPattern === "0 10 * * 1") {
    await weeklyDigests(env);
    await adminDigestSend(env);
  } else {
    await welcomeSequenceTick(env);
    await referralFollowups(env);
  }
}

async function weeklyDigests(env) {
  const week = isoWeek();
  const board = await kvJson(env, "leaderboard", []);
  const cutoff = now() - 7 * 86400000;
  const weekly = board.filter((b) => (b.ts || 0) >= cutoff).sort((a, b) => b.score - a.score);
  const top3 = weekly.slice(0, 3);
  const pids = await kvJson(env, "pemail_index", []);
  for (const pid of pids) {
    const rec = await getPlayer(env, pid);
    if (!rec || !rec.consent || (await isSuppressed(env, rec.email))) continue;
    if (!(await underDailyCap(env, pid))) continue;
    const idx = weekly.findIndex((b) => rec.wallet && b.addr === rec.wallet);
    const played = idx >= 0 || (rec.played_at || 0) >= cutoff;
    const deaths = await kvJson(env, `deaths:${week}:${pid}`, {});
    const worstBoss = Object.entries(deaths).sort((a, b) => b[1] - a[1])[0];
    const prev = await kvJson(env, "digestrank:" + pid, null);
    const msg = T.weeklyDigest(env, {
      name: rec.name, wallet: rec.wallet, unsubToken: rec.unsub_token,
      played, rank: idx + 1, score: idx >= 0 ? weekly[idx].score : 0,
      delta: idx >= 0 && prev && prev.score != null ? weekly[idx].score - prev.score : null,
      top3,
      deaths: worstBoss ? { boss: BOSS_NAMES[worstBoss[0]] || worstBoss[0], count: worstBoss[1], tip: BOSS_TIPS[worstBoss[0]] || "breathe, observe the pattern, then strike." } : null,
    });
    // Drafts API path (human-in-the-loop capable): draft, then send unless
    // DIGEST_DRAFT_ONLY=1 pauses at review stage.
    const sent = await draftThenSend(env, { to: rec.email, ...msg, labels: ["weekly_digest"], key: `digest:${week}:${pid}` });
    if (sent.ok) {
      await markSent(env, pid, rec);
      if (idx >= 0) await env.GAME_KV.put("digestrank:" + pid, JSON.stringify({ week, rank: idx + 1, score: weekly[idx].score }));
    }
  }
}

async function adminDigestSend(env) {
  if (!env.ADMIN_EMAIL) return;
  const week = isoWeek();
  const board = await kvJson(env, "leaderboard", []);
  const pids = await kvJson(env, "pemail_index", []);
  const players = await kvJson(env, "players_week:" + week, []);
  const refs = await kvJson(env, "ref_index", []);
  let refSent = 0, refClicked = 0, refConverted = 0;
  for (const t of refs.slice(-500)) {
    const r = await kvJson(env, "ref:" + t, null);
    if (!r) continue;
    refSent++; if (r.clicked_at) refClicked++; if (r.converted_at) refConverted++;
  }
  const ctaList = await env.GAME_KV.list({ prefix: `cta:${week}:` });
  const ctaTop = [];
  for (const k of ctaList.keys) {
    ctaTop.push({ cta: k.name.split(":").pop(), count: parseInt((await env.GAME_KV.get(k.name)) || "0") });
  }
  ctaTop.sort((a, b) => b.count - a.count);
  const oqList = await env.GAME_KV.list({ prefix: `oq:${week}:`, limit: 200 });
  const oracleTop = [];
  for (const k of oqList.keys) {
    const v = await kvJson(env, k.name, null);
    if (v) oracleTop.push(v);
  }
  oracleTop.sort((a, b) => b.count - a.count);
  const msg = T.adminDigest(env, {
    week, uniquePlayers: players.length,
    walletConnects: parseInt((await env.GAME_KV.get("walletconnects:" + week)) || "0"),
    subscribers: pids.length, refSent, refClicked, refConverted,
    top10: board.slice(0, 10), ctaTop: ctaTop.slice(0, 5), oracleTop: oracleTop.slice(0, 10),
  });
  await sendEmail(env, { to: env.ADMIN_EMAIL, ...msg, labels: ["admin_digest"], key: `admin:${week}` });
}

async function welcomeSequenceTick(env) {
  const pids = await kvJson(env, "pemail_index", []);
  for (const pid of pids) {
    const rec = await getPlayer(env, pid);
    if (!rec || !rec.consent || (await isSuppressed(env, rec.email))) continue;
    const age = now() - (rec.created_at || 0);
    // Email 2: 3 days in, ONLY if they haven't played yet.
    if (rec.welcome_stage === 1 && age >= 3 * 86400000) {
      if (!rec.played_at) {
        const msg = T.welcome(env, 2, { name: rec.name, unsubToken: rec.unsub_token });
        const s = await sendEmail(env, { to: rec.email, ...msg, labels: ["welcome_sent_2"], key: `welcome2:${pid}` });
        if (!s.ok) continue;
      }
      rec.welcome_stage = 2; // played players skip the nag but advance stages
      await env.GAME_KV.put("pemail:" + pid, JSON.stringify(rec));
    }
    // Email 3: 7 days in.
    else if (rec.welcome_stage === 2 && age >= 7 * 86400000) {
      const msg = T.welcome(env, 3, { name: rec.name, unsubToken: rec.unsub_token });
      const s = await sendEmail(env, { to: rec.email, ...msg, labels: ["welcome_sent_3"], key: `welcome3:${pid}` });
      if (s.ok) { rec.welcome_stage = 3; await env.GAME_KV.put("pemail:" + pid, JSON.stringify(rec)); }
    }
  }
}

async function referralFollowups(env) {
  const refs = await kvJson(env, "ref_index", []);
  for (const t of refs.slice(-500)) {
    const r = await kvJson(env, "ref:" + t, null);
    if (!r || r.followup_sent || r.converted_at) continue;
    // Spec: clicked but didn't play within 48h → one follow-up.
    if (r.clicked_at && now() - r.clicked_at >= 48 * 3600000) {
      if (await isSuppressed(env, r.friend_email)) continue;
      const msg = T.referralFollowup(env, { referrerName: r.referrer_name, refToken: t, unsubToken: "ref-" + t });
      const s = await sendEmail(env, { to: r.friend_email, ...msg, labels: ["referral_followup"], key: `reffu:${t}` });
      if (s.ok) { r.followup_sent = now(); await env.GAME_KV.put("ref:" + t, JSON.stringify(r)); }
    }
  }
}
