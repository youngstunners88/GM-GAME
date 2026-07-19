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
import { kimiChat } from "./kimi_client.js";

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

// Per-IP fixed-window rate limiter for the marketing routes (same pattern as
// worker.js's overRateLimit; duplicated here so worker.js stays untouched).
// PR #6 review #1: public routes must not be able to drain the AgentMail
// quota or flood arbitrary recipients.
async function overLimit(env, request, bucket, limit, windowSec) {
  try {
    if (!env.GAME_KV) return false;
    const ip = request.headers.get("cf-connecting-ip") || "anon";
    const win = Math.floor(Date.now() / 1000 / windowSec);
    const key = `rl:mkt:${bucket}:${ip}:${win}`;
    const n = parseInt((await env.GAME_KV.get(key)) || "0") + 1;
    await env.GAME_KV.put(key, String(n), { expirationTtl: windowSec * 2 });
    return n > limit;
  } catch (e) { return false; }
}

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

// Open-redirect guard for the /go click tracker (PR #6 review: exact hosts,
// not whole-registrable-domain wildcards — a trusted-domain redirector is a
// phishing primitive). Only *.itch.io keeps a suffix match because the game
// itself is served from itch's CDN subdomains; everything else is exact.
const REDIRECT_HOSTS_EXACT = ["itch.io", "youngstunners88.itch.io", "twitter.com", "x.com", "basescan.org", "t.me"];
function safeRedirect(env, to) {
  try {
    const u = new URL(to);
    if (u.protocol !== "https:") return GAME_URL;
    const host = u.hostname.toLowerCase();
    const backendHost = env.PUBLIC_BACKEND_URL ? new URL(env.PUBLIC_BACKEND_URL).hostname : "";
    if (host === backendHost || REDIRECT_HOSTS_EXACT.includes(host) || host.endsWith(".itch.io"))
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
    // Abuse controls (PR #6 review #1): per-IP quota + one signup email per
    // address per day. The single immediate email doubles as DOUBLE-OPT-IN:
    // Welcome 1 carries a "confirm subscription" link, and NO campaign mail
    // (digest/welcome-2/3/milestones) goes out until /confirm is clicked.
    if (await overLimit(env, request, "signup", 5, 3600))
      return json({ ok: false, error: "rate_limited" }, 429, cors);
    const { player_id, email, consent, wallet_address, name } = await request.json();
    const pid = String(player_id || "").slice(0, 64);
    const addr = String(email || "").trim().toLowerCase().slice(0, 254);
    if (!pid || !addr) return json({ ok: false, error: "player_id and email required" }, 400, cors);
    if (consent !== true) return json({ ok: false, error: "consent required" }, 400, cors);
    if (!(await validEmail(addr))) return json({ ok: false, error: "invalid email" }, 400, cors);
    if (await isSuppressed(env, addr)) return json({ ok: false, error: "address opted out" }, 400, cors);
    const perAddrKey = "signupaddr:" + addr + ":" + dayStamp();
    if ((await env.GAME_KV.get(perAddrKey)) !== null)
      return json({ ok: false, error: "already signed up today" }, 429, cors);
    await env.GAME_KV.put(perAddrKey, "1", { expirationTtl: 172800 });
    const existing = await getPlayer(env, pid);
    const rec = existing || {
      created_at: now(), welcome_stage: 0, played_at: 0, last_sent_at: 0,
      unsub_token: token(), confirmed: false,
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
    // the daily cap by design). Carries the double-opt-in confirm link.
    if (!existing || !rec.welcome_stage) {
      const confirmUrl = `${env.PUBLIC_BACKEND_URL || ""}/confirm?token=${encodeURIComponent(rec.unsub_token)}`;
      const msg = T.welcome(env, 1, { name: rec.name, unsubToken: rec.unsub_token, confirmUrl });
      const sent = await sendEmail(env, { to: addr, ...msg, labels: ["welcome_sent_1"], key: `welcome1:${pid}` });
      if (sent.ok) { rec.welcome_stage = 1; rec.welcome_1_at = now(); await env.GAME_KV.put("pemail:" + pid, JSON.stringify(rec)); }
    }
    return json({ ok: true }, 200, cors);
  }

  // GDPR-style data rights (privacy.md; audit DATA002). Authenticated by the
  // per-player unsubscribe token — only reachable from the owner's own email.
  if (path === "/data-export" && request.method === "GET") {
    if (await overLimit(env, request, "dexport", 10, 3600))
      return json({ ok: false, error: "rate_limited" }, 429, cors);
    const tok = String(new URL(request.url).searchParams.get("token") || "").slice(0, 64);
    const pid = await env.GAME_KV.get("unsub:" + tok);
    if (!pid || pid.startsWith("ref:")) return json({ ok: false, error: "unknown token" }, 404, cors);
    const rec = await getPlayer(env, pid);
    const stats = await kvJson(env, "pstats:" + pid, {});
    return json({ exported_at: now(), email_record: rec || {}, gameplay_stats: stats }, 200, cors);
  }
  if (path === "/data-delete" && request.method === "GET") {
    if (await overLimit(env, request, "ddelete", 10, 3600))
      return json({ ok: false, error: "rate_limited" }, 429, cors);
    const tok = String(new URL(request.url).searchParams.get("token") || "").slice(0, 64);
    const pid = await env.GAME_KV.get("unsub:" + tok);
    if (!pid || pid.startsWith("ref:")) return json({ ok: false, error: "unknown token" }, 404, cors);
    const rec = await getPlayer(env, pid);
    if (rec && rec.email) await suppress(env, rec.email, "account deleted (right to be forgotten)");
    await env.GAME_KV.delete("pemail:" + pid);
    await env.GAME_KV.delete("pstats:" + pid);
    await env.GAME_KV.delete("unsub:" + tok);
    return new Response(
      "<html><body style='background:#0c1410;color:#e7f5ec;font-family:sans-serif;text-align:center;padding:60px'>" +
      "<h2>Deleted.</h2><p>Your email record and gameplay stats are gone. The Realm forgets, as requested.</p></body></html>",
      { headers: { "Content-Type": "text/html", ...cors } });
  }

  // Double-opt-in confirmation (clicked from Welcome 1). Campaign sends check
  // rec.confirmed — only this route sets it, so a spoofed /email/signup POST
  // alone can never subscribe an address to ongoing mail.
  if (path === "/confirm" && request.method === "GET") {
    const tok = new URL(request.url).searchParams.get("token") || "";
    const pid = await env.GAME_KV.get("unsub:" + String(tok).slice(0, 64));
    if (pid && !pid.startsWith("ref:")) {
      const rec = await getPlayer(env, pid);
      if (rec) { rec.confirmed = true; await env.GAME_KV.put("pemail:" + pid, JSON.stringify(rec)); }
    }
    return new Response(
      "<html><body style='background:#0c1410;color:#e7f5ec;font-family:sans-serif;text-align:center;padding:60px'>" +
      "<h2>🌿 Subscription confirmed.</h2><p>Weekly Smoke Realm reports incoming. See you Monday.</p></body></html>",
      { headers: { "Content-Type": "text/html", ...cors } });
  }

  // One-click unsubscribe (GET for the mail-client link, POST for API use).
  if (path === "/unsubscribe" && (request.method === "GET" || request.method === "POST")) {
    let tok = "";
    if (request.method === "GET") tok = new URL(request.url).searchParams.get("token") || "";
    else tok = ((await request.json()).token) || "";
    const pid = await env.GAME_KV.get("unsub:" + String(tok).slice(0, 64));
    if (pid && pid.startsWith("ref:")) {
      // Referral-invitee unsubscribe (PR #6 review #3: this used to be a false
      // success — the value is a ref record key, NOT a player id). Suppress the
      // invitee's address directly and mark the referral record.
      const r = await kvJson(env, pid, null);
      if (r && r.friend_email) {
        await suppress(env, r.friend_email, "referral invitee unsubscribed");
        r.unsubscribed_at = now();
        await env.GAME_KV.put(pid, JSON.stringify(r));
      }
    } else if (pid) {
      const rec = await getPlayer(env, pid);
      if (rec) {
        rec.consent = false;
        rec.confirmed = false;
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
    if (await overLimit(env, request, "events", 120, 60))
      return json({ ok: false, error: "rate_limited" }, 429, cors);
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
      if (rec && rec.consent && rec.confirmed && (await env.GAME_KV.get(gate)) === null && (await underDailyCap(env, pid))) {
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
    // Abuse controls (PR #6 review #1): per-IP quota, per-referrer daily cap,
    // and ONE invite per friend address ever — this endpoint sends mail to a
    // third party, so it gets the tightest limits in the file.
    if (await overLimit(env, request, "referral", 3, 3600))
      return json({ ok: false, error: "rate_limited" }, 429, cors);
    const { player_id, friend_email, player_name } = await request.json();
    const addr = String(friend_email || "").trim().toLowerCase().slice(0, 254);
    if (!(await validEmail(addr))) return json({ ok: false, error: "invalid email" }, 400, cors);
    if (await isSuppressed(env, addr)) return json({ ok: false, error: "recipient opted out" }, 400, cors);
    if ((await env.GAME_KV.get("refonce:" + addr)) !== null)
      return json({ ok: false, error: "already invited" }, 429, cors);
    const refDayKey = `refday:${String(player_id || "anon").slice(0, 64)}:${dayStamp()}`;
    const refDayCount = parseInt((await env.GAME_KV.get(refDayKey)) || "0");
    if (refDayCount >= 3) return json({ ok: false, error: "daily invite limit" }, 429, cors);
    await env.GAME_KV.put(refDayKey, String(refDayCount + 1), { expirationTtl: 172800 });
    await env.GAME_KV.put("refonce:" + addr, "1");
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
    // Provider signature verification (PR #6 review #2). svix-style HMAC over
    // "<id>.<timestamp>.<rawBody>" with a stale-timestamp window; enforced
    // when AGENTMAIL_WEBHOOK_SIGNING_KEY is set (set it — see
    // AGENTMAIL_SETUP.md), on top of the URL secret.
    const rawBody = await request.text();
    if (env.AGENTMAIL_WEBHOOK_SIGNING_KEY) {
      const ok = await verifyWebhookSignature(env, request, rawBody);
      if (!ok) return json({ ok: false, error: "bad signature" }, 401, cors);
    }
    let evt = null;
    try { evt = JSON.parse(rawBody); } catch (e) { return json({ ok: false, error: "bad json" }, 400, cors); }
    if (evt && evt.event_type === "message.received" && evt.message) {
      // Replay/duplicate gate: one triage per event/message id, 24h TTL.
      const evtId = String(evt.event_id || evt.message.message_id || evt.message.id || "");
      if (evtId) {
        const seenKey = "evt:" + evtId.slice(0, 120);
        if ((await env.GAME_KV.get(seenKey)) !== null)
          return json({ ok: true, deduped: true }, 200, cors);
        await env.GAME_KV.put(seenKey, "1", { expirationTtl: 86400 });
      }
      return json(await handleSupportEmail(env, evt.message), 200, cors);
    }
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

  // ==== LEVEL DEPTH (task #23) — analytics pipeline + adaptive difficulty ==

  // Granular event ingestion (Video-Game Layer). Distinct from the digest's
  // /events: this feeds per-player stats (pstats:<pid>) that power dynamic
  // difficulty, the founder digest, and future Oracle context.
  if (path === "/event" && request.method === "POST") {
    if (await overLimit(env, request, "gevent", 120, 60))
      return json({ ok: false, error: "rate_limited" }, 429, cors);
    const { player_id, event_type, event_data } = await request.json();
    const pid = String(player_id || "anon").slice(0, 64);
    const type = String(event_type || "").slice(0, 40);
    const data = (event_data && typeof event_data === "object") ? event_data : {};
    const ALLOWED_EVENTS = ["death", "powerup_used", "secret_found", "boss_phase_reached",
      "lore_read", "share_clicked", "referral_code_used", "level_complete", "retry"];
    if (!ALLOWED_EVENTS.includes(type)) return json({ ok: false, error: "unknown event_type" }, 400, cors);
    const st = await kvJson(env, "pstats:" + pid, {
      deaths_by_enemy: {}, deaths_by_obstacle: {}, session_times: [], retry_count: 0, counters: {},
    });
    if (type === "death") {
      const enemy = String(data.enemy || "").slice(0, 24);
      const obstacle = String(data.obstacle || "").slice(0, 24);
      if (enemy) st.deaths_by_enemy[enemy] = (st.deaths_by_enemy[enemy] || 0) + 1;
      if (obstacle) st.deaths_by_obstacle[obstacle] = (st.deaths_by_obstacle[obstacle] || 0) + 1;
    } else if (type === "level_complete") {
      const secs = Math.max(0, Math.min(7200, Number(data.seconds) || 0));
      if (secs) st.session_times = [...st.session_times, secs].slice(-20);
    } else if (type === "retry") {
      st.retry_count = (st.retry_count || 0) + 1;
    } else {
      st.counters[type] = (st.counters[type] || 0) + 1;
    }
    st.updated_at = now();
    await env.GAME_KV.put("pstats:" + pid, JSON.stringify(st), { expirationTtl: 7776000 });
    // Weekly aggregate for the founder digest.
    const ak = `evtagg:${isoWeek()}:${type}`;
    await env.GAME_KV.put(ak, String(parseInt((await env.GAME_KV.get(ak)) || "0") + 1), { expirationTtl: 2419200 });
    return json({ ok: true }, 200, cors);
  }

  // Death heatmap + pacing stats for the dynamic difficulty system. Read-only,
  // pseudonymous (client-generated player id), rate-limited.
  if (path === "/player-analytics" && request.method === "GET") {
    if (await overLimit(env, request, "panalytics", 30, 60))
      return json({ ok: false, error: "rate_limited" }, 429, cors);
    const pid = String(new URL(request.url).searchParams.get("player_id") || "").slice(0, 64);
    if (!pid) return json({ ok: false, error: "player_id required" }, 400, cors);
    const st = await kvJson(env, "pstats:" + pid, null);
    if (!st) return json({ deaths_by_enemy: {}, deaths_by_obstacle: {}, avg_completion_time: 0, retry_count: 0 }, 200, cors);
    const times = st.session_times || [];
    const avg = times.length ? times.reduce((a, b) => a + b, 0) / times.length : 0;
    return json({
      deaths_by_enemy: st.deaths_by_enemy || {},
      deaths_by_obstacle: st.deaths_by_obstacle || {},
      avg_completion_time: Math.round(avg),
      retry_count: st.retry_count || 0,
    }, 200, cors);
  }

  // Community lore for secret walls: serve the least-recently-used approved
  // snippet and mark it served (so explorers keep finding fresh lore).
  if (path === "/community-lore" && request.method === "GET") {
    if (await overLimit(env, request, "clore", 30, 60))
      return json({ ok: false, error: "rate_limited" }, 429, cors);
    const lore = await kvJson(env, "lore", []);
    if (!lore.length) return json({ text: "", empty: true }, 200, cors);
    // Pick the entry served the fewest times (stable rotation, no Math.random
    // dependence); votes break ties so top-voted lore surfaces first.
    let best = 0;
    for (let i = 1; i < lore.length; i++) {
      const a = lore[i], b = lore[best];
      if ((a.served || 0) < (b.served || 0) ||
          ((a.served || 0) === (b.served || 0) && (a.votes || 0) > (b.votes || 0))) best = i;
    }
    lore[best].served = (lore[best].served || 0) + 1;
    await env.GAME_KV.put("lore", JSON.stringify(lore));
    return json({ text: lore[best].text, addr: lore[best].addr || "" }, 200, cors);
  }

  // Hall of Blaze: weekly top-10 silhouettes for the token-gated easter room.
  if (path === "/hall-of-blaze" && request.method === "GET") {
    if (await overLimit(env, request, "hall", 30, 60))
      return json({ ok: false, error: "rate_limited" }, 429, cors);
    const board = await kvJson(env, "leaderboard", []);
    return json(board.slice(0, 10).map((b) => ({
      addr: (b.addr || "").slice(0, 6) + "..." + (b.addr || "").slice(-4), score: b.score,
    })), 200, cors);
  }

  return null; // not ours — worker continues to its existing routes
}

// svix-style webhook signature check: headers svix-id / svix-timestamp /
// svix-signature (or webhook-* equivalents), HMAC-SHA256 over
// "<id>.<timestamp>.<rawBody>" with the base64 signing key, constant-ish
// compare, ±5 min timestamp window.
async function verifyWebhookSignature(env, request, rawBody) {
  try {
    const h = request.headers;
    const id = h.get("svix-id") || h.get("webhook-id") || "";
    const ts = h.get("svix-timestamp") || h.get("webhook-timestamp") || "";
    const sigHeader = h.get("svix-signature") || h.get("webhook-signature") || "";
    if (!id || !ts || !sigHeader) return false;
    if (Math.abs(Date.now() / 1000 - parseInt(ts)) > 300) return false; // stale
    let keyB64 = env.AGENTMAIL_WEBHOOK_SIGNING_KEY;
    if (keyB64.startsWith("whsec_")) keyB64 = keyB64.slice(6);
    const keyBytes = Uint8Array.from(atob(keyB64), (c) => c.charCodeAt(0));
    const cryptoKey = await crypto.subtle.importKey("raw", keyBytes,
      { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
    const signed = await crypto.subtle.sign("HMAC", cryptoKey,
      new TextEncoder().encode(`${id}.${ts}.${rawBody}`));
    const expected = btoa(String.fromCharCode(...new Uint8Array(signed)));
    // Header format: "v1,<base64sig>" (possibly several space-separated).
    return sigHeader.split(" ").some((part) => {
      const sig = part.includes(",") ? part.split(",")[1] : part;
      return sig === expected;
    });
  } catch (e) { return false; }
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
  // Chain: Mistral (primary) → Kimi K3 via OpenRouter (enhancement layer,
  // Level Depth) → XAI Grok (last resort). Each tier is skipped when its key
  // is absent and on any failure the next tier is tried.
  const tries = [];
  if (env.MISTRAL_API_KEY) tries.push({
    url: "https://api.mistral.ai/v1/chat/completions",
    key: env.MISTRAL_API_KEY, model: env.MISTRAL_MODEL || "mistral-small-latest",
  });
  // Second Mistral key = rate-limit/quota failover (both keys validated
  // 2026-07-19). Same provider, same quality, different quota bucket.
  if (env.MISTRAL_API_KEY2) tries.push({
    url: "https://api.mistral.ai/v1/chat/completions",
    key: env.MISTRAL_API_KEY2, model: env.MISTRAL_MODEL || "mistral-small-latest",
  });
  if (env.OPENROUTER_API_KEY) tries.push({ kimi: true });
  const xaiKey = env.XAI_API_KEY || env.XAI_API;
  if (xaiKey) tries.push({
    url: "https://api.x.ai/v1/chat/completions",
    key: xaiKey, model: env.XAI_MODEL || "grok-3-mini",
  });
  for (const t of tries) {
    if (t.kimi) {
      const c = await kimiChat(env, system, user, 500);
      if (c) return c;
      continue;
    }
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

  // Auto-send gate (PR #6 review #4): the email body is attacker-controlled
  // prompt input, so model confidence alone must not authorize a send. The
  // reply may auto-send ONLY when ALL hold — otherwise it stays a draft for
  // human review (reply still only ever goes to the original sender):
  //   - category is a plain FAQ "question" (bug reports/feature requests and
  //     anything else always get human eyes),
  //   - model confidence >= 0.7,
  //   - the answer passes content checks: bounded length, no links other than
  //     the game's own URL, no email addresses (blocks exfil/phish payloads).
  const answer = String(parsed.answer).slice(0, 2000);
  const strayLinks = (answer.match(/https?:\/\/\S+/gi) || []).filter((u) => !u.startsWith(GAME_URL));
  const containsEmail = /[^\s@]+@[^\s@]+\.[^\s@]{2,}/.test(answer);
  const contentSafe = answer.length <= 1200 && strayLinks.length === 0 && !containsEmail;
  const confident = Number(parsed.confidence) >= 0.7 && parsed.category === "question" && contentSafe;
  const labels = [confident ? "auto_resolved" : "human_review"];
  if (parsed.category === "bug_report") labels.push("bug_report");
  if (parsed.category === "feature_request") labels.push("feature_request");
  if (inboxId && messageId) await labelMessage(env, inboxId, messageId, labels);

  const reply = T.supportReply(env, { subject, body: answer });
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
  // Credit-efficiency: ONE Kimi call per week drafts the "realm news" blurb
  // from aggregate stats, cached in KV and reused in EVERY subscriber's
  // digest (never per-player LLM calls). Skipped silently without a key.
  let realmNews = await env.GAME_KV.get("realmnews:" + week);
  if (realmNews === null) {
    const evtList = await env.GAME_KV.list({ prefix: `evtagg:${week}:` });
    const agg = [];
    for (const k of evtList.keys.slice(0, 12))
      agg.push(`${k.name.split(":").pop()}=${await env.GAME_KV.get(k.name)}`);
    const drafted = await kimiChat(env,
      "You write ONE 2-sentence, chill, playful 'realm news' blurb for a weekly game email (Lil Blunt: The Smoke Realm — a stoner-chill crypto platformer). No hashtags, no links, no financial advice, max 220 chars total. Plain text only.",
      `This week's aggregate events: ${agg.join(", ") || "quiet week"}. Top score: ${weekly[0]?.score || 0}.`, 300);
    realmNews = (drafted || "").slice(0, 240).replace(/[<>]/g, "");
    await env.GAME_KV.put("realmnews:" + week, realmNews, { expirationTtl: 1209600 });
  }
  const pids = await kvJson(env, "pemail_index", []);
  for (const pid of pids) {
    const rec = await getPlayer(env, pid);
    // confirmed = double-opt-in via /confirm (PR #6 review #1) — campaign
    // mail never goes to an address that only ever appeared in a POST body.
    if (!rec || !rec.consent || !rec.confirmed || (await isSuppressed(env, rec.email))) continue;
    if (!(await underDailyCap(env, pid))) continue;
    const idx = weekly.findIndex((b) => rec.wallet && b.addr === rec.wallet);
    const played = idx >= 0 || (rec.played_at || 0) >= cutoff;
    const deaths = await kvJson(env, `deaths:${week}:${pid}`, {});
    const worstBoss = Object.entries(deaths).sort((a, b) => b[1] - a[1])[0];
    const prev = await kvJson(env, "digestrank:" + pid, null);
    const msg = T.weeklyDigest(env, {
      name: rec.name, wallet: rec.wallet, unsubToken: rec.unsub_token,
      realmNews,
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
    // Welcome 2/3 are campaign mail → double-opt-in required (see /confirm).
    if (!rec || !rec.consent || !rec.confirmed || (await isSuppressed(env, rec.email))) continue;
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
