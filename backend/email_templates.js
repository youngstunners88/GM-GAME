// Email template system (Layer Shift marketing engine).
// Every template returns { subject, html, text } — HTML with a plain-text
// fallback, and EVERY email ends with the compliance footer: who we are, why
// you got this, and a working one-click Unsubscribe link (CAN-SPAM basics).
// Templates never receive raw user HTML — all interpolations are escaped.

const GAME_URL = "https://youngstunners88.itch.io/lil-blunt-adventure";

const esc = (s) => String(s == null ? "" : s)
  .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
  .replace(/"/g, "&quot;").replace(/'/g, "&#39;");

const short = (addr) => {
  const a = String(addr || "");
  return a.startsWith("0x") && a.length >= 12 ? a.slice(0, 6) + "..." + a.slice(-4) : a;
};

/** CTA that routes through the backend click-tracker (/go) so the admin digest
 * can report the most-clicked CTA. utm params ride along for the destination. */
const cta = (base, name, dest, label, color) =>
  `<a href="${esc(base)}/go?cta=${encodeURIComponent(name)}&to=${encodeURIComponent(dest)}"
     style="display:inline-block;background:${color || "#3fae6a"};color:#fff;padding:12px 22px;
     border-radius:8px;text-decoration:none;font-weight:bold;margin:4px 6px;">${esc(label)}</a>`;

const xIntent = (textStr) =>
  "https://twitter.com/intent/tweet?text=" + encodeURIComponent(textStr);

/** Base layout: dark chill theme, mobile-safe single column. */
function layout(env, { title, bodyHtml, unsubToken }) {
  const base = env.PUBLIC_BACKEND_URL || "";
  const unsub = `${base}/unsubscribe?token=${encodeURIComponent(unsubToken || "")}`;
  const addr = env.POSTAL_ADDRESS || "SmokeRing — The Smoke Realm (address on file with AgentMail)";
  return `<!DOCTYPE html><html><body style="margin:0;background:#0c1410;color:#e7f5ec;
  font-family:Arial,Helvetica,sans-serif;">
  <div style="max-width:560px;margin:0 auto;padding:24px;">
    <div style="text-align:center;padding:10px 0 18px;">
      <div style="font-size:26px;font-weight:bold;color:#7ee2a8;">🌿 LIL BLUNT</div>
      <div style="font-size:12px;letter-spacing:3px;color:#5b8a6f;">THE SMOKE REALM</div>
    </div>
    <div style="background:#132019;border:1px solid #23402f;border-radius:12px;padding:22px;">
      <h1 style="font-size:20px;margin:0 0 14px;color:#aef0c8;">${esc(title)}</h1>
      ${bodyHtml}
    </div>
    <div style="font-size:11px;color:#57735f;padding:18px 6px;text-align:center;line-height:1.6;">
      Join us: <a href="https://t.me/LilBluntdotWin" style="color:#7ee2a8;">t.me/LilBluntdotWin</a> ·
      X: <a href="https://x.com/smokering25" style="color:#7ee2a8;">@smokering25</a><br>
      You're getting this because you opted in to Smoke Realm updates in-game.<br>
      ${esc(addr)}<br>
      <a href="${unsub}" style="color:#7ee2a8;">Unsubscribe</a> — one click, no questions, gone forever.<br>
      <a href="${base}/data-export?token=${encodeURIComponent(unsubToken || "")}" style="color:#57735f;">Export my data</a> ·
      <a href="${base}/data-delete?token=${encodeURIComponent(unsubToken || "")}" style="color:#57735f;">Delete my data</a>
    </div>
  </div></body></html>`;
}

const textFooter = (env, unsubToken) => {
  const base = env.PUBLIC_BACKEND_URL || "";
  return `\n\n--\nJoin us: t.me/LilBluntdotWin | X: @smokering25\nYou opted in to Smoke Realm updates in-game.\nUnsubscribe (one click): ${base}/unsubscribe?token=${unsubToken || ""}\nExport my data: ${base}/data-export?token=${unsubToken || ""} | Delete: ${base}/data-delete?token=${unsubToken || ""}\n`;
};

// ---------------------------------------------------------------------------
// A. Weekly leaderboard digest
// ---------------------------------------------------------------------------
export function weeklyDigest(env, p) {
  // p: {name, unsubToken, rank, score, delta, top3:[{addr,score}], deaths:{boss,count,tip}, played}
  const base = env.PUBLIC_BACKEND_URL || "";
  const name = esc(p.name || short(p.wallet) || "traveler");
  if (!p.played) {
    return {
      subject: "🌿 We missed you in the Smoke Realm this week",
      html: layout(env, {
        title: "We missed you!",
        unsubToken: p.unsubToken,
        bodyHtml: `<p>Yo ${name},</p>
          <p>The Realm was quiet without you. <b>The Auditor is getting cocky</b> —
          somebody needs to humble him.</p>
          <div style="text-align:center;margin:18px 0;">
            ${cta(base, "play_now", GAME_URL, "▶ Play Now")}
          </div>`,
      }),
      text: `Yo ${p.name || short(p.wallet) || "traveler"},\n\nThe Realm was quiet without you. The Auditor is getting cocky - somebody needs to humble him.\n\nPlay now: ${GAME_URL}${textFooter(env, p.unsubToken)}`,
    };
  }
  const deltaLine = p.delta == null ? "" :
    p.delta >= 0 ? `up <b>+${esc(p.delta)}</b> vs last week 📈` : `down ${esc(p.delta)} vs last week — comeback time`;
  const top3Html = (p.top3 || []).map((t, i) =>
    `<tr><td style="padding:6px 10px;">${["🥇", "🥈", "🥉"][i] || i + 1}</td>
     <td style="padding:6px 10px;font-family:monospace;">${esc(t.name || short(t.addr))}</td>
     <td style="padding:6px 10px;text-align:right;">${esc(t.score)}</td></tr>`).join("");
  const deathHtml = p.deaths && p.deaths.count
    ? `<p style="background:#1b2a20;border-radius:8px;padding:12px;">💀 You died to the
       <b>${esc(p.deaths.boss)}</b> ${esc(p.deaths.count)} time${p.deaths.count === 1 ? "" : "s"}.
       <i>Pro tip: ${esc(p.deaths.tip)}</i></p>` : "";
  const shareText = `I ranked #${p.rank} in Lil Blunt: The Smoke Realm this week 🌿🏆 Come take my spot: ${GAME_URL}`;
  const newsHtml = p.realmNews
    ? `<p style="font-style:italic;color:#9fd4b4;">${esc(p.realmNews)}</p>` : "";
  return {
    subject: `🏆 Your Smoke Realm Weekly Report — You ranked #${p.rank}`,
    html: layout(env, {
      title: `You ranked #${esc(p.rank)} this week`,
      unsubToken: p.unsubToken,
      bodyHtml: `<p>Yo ${name},</p>
        ${newsHtml}
        <p>Your score: <b>${esc(p.score)}</b> ${deltaLine ? "— " + deltaLine : ""}</p>
        ${deathHtml}
        <p style="margin-bottom:6px;"><b>This week's top 3:</b></p>
        <table style="width:100%;border-collapse:collapse;background:#0f1a14;border-radius:8px;">${top3Html}</table>
        <div style="text-align:center;margin:20px 0 4px;">
          ${cta(base, "play_now", GAME_URL, "▶ Play Now")}
          ${cta(base, "share_rank", xIntent(shareText), "𝕏 Share Your Rank", "#365ac2")}
          ${cta(base, "refer_friend", `${base}/ref-page?src=digest`, "🤝 Brag to a Friend", "#a2843a")}
        </div>`,
    }),
    text: `Yo ${p.name || short(p.wallet)},\n\nYou ranked #${p.rank} this week with ${p.score} points.\n` +
      ((p.top3 || []).map((t, i) => `  ${i + 1}. ${t.name || short(t.addr)} - ${t.score}`).join("\n")) +
      (p.deaths && p.deaths.count ? `\n\nYou died to the ${p.deaths.boss} ${p.deaths.count} times. Pro tip: ${p.deaths.tip}` : "") +
      `\n\nPlay: ${GAME_URL}\nShare: ${xIntent(shareText)}${textFooter(env, p.unsubToken)}`,
  };
}

// ---------------------------------------------------------------------------
// B. Welcome sequence (3 stages)
// ---------------------------------------------------------------------------
export function welcome(env, stage, p) {
  const base = env.PUBLIC_BACKEND_URL || "";
  const name = esc(p.name || "friend");
  const bodies = {
    1: {
      subject: "🌿 Welcome to the Smoke Realm — confirm your spot",
      title: "Welcome in. Stay chill.",
      html: `<p>Yo ${name}, glad you're here.</p>
        <p><b>Your first tip:</b> Blaze Mode stacks with double-jump — grab a
        Weed Leaf, then double-jump to clear gaps that look impossible.</p>
        ${p.confirmUrl ? `<p><b>One tap to finish:</b> confirm below and the weekly
        rank report + tips start landing. No confirm, no more emails — simple.</p>
        <div style="text-align:center;margin:14px 0;">
          <a href="${esc(p.confirmUrl)}" style="display:inline-block;background:#7ee2a8;color:#0c1410;padding:12px 22px;border-radius:8px;text-decoration:none;font-weight:bold;">✅ Confirm Subscription</a>
        </div>` : ""}
        <div style="text-align:center;margin:18px 0;">${cta(base, "play_now", GAME_URL, "▶ Play Now")}</div>`,
      text: `Yo ${p.name || "friend"}, glad you're here.\n\nFirst tip: Blaze Mode stacks with double-jump - grab a Weed Leaf, then double-jump to clear gaps that look impossible.\n` +
        (p.confirmUrl ? `\nConfirm your subscription (required for weekly reports): ${p.confirmUrl}\n` : "") +
        `\nPlay: ${GAME_URL}`,
    },
    2: {
      subject: "The Tax Collector wants a word 🌿",
      title: "He's counting your coins already.",
      html: `<p>Yo ${name},</p>
        <p>You signed up but haven't dropped into the Realm yet. <b>The Tax
        Collector is waiting</b> — and he does NOT do refunds.</p>
        <div style="text-align:center;margin:18px 0;">${cta(base, "play_now", GAME_URL, "▶ Play Now")}</div>`,
      text: `Yo ${p.name || "friend"},\n\nYou signed up but haven't dropped into the Realm yet. The Tax Collector is waiting - and he does NOT do refunds.\n\nPlay: ${GAME_URL}`,
    },
    3: {
      subject: "📊 Leaderboard drops Monday — get on it",
      title: "Verified bragging rights.",
      html: `<p>Yo ${name},</p>
        <p>The weekly leaderboard drops <b>every Monday</b>. Connect your wallet
        in the main menu for verified, on-chain bragging rights — your rank,
        tied to your address, forever.</p>
        <div style="text-align:center;margin:18px 0;">${cta(base, "play_now", GAME_URL, "▶ Play & Connect")}</div>`,
      text: `Yo ${p.name || "friend"},\n\nThe weekly leaderboard drops every Monday. Connect your wallet in the main menu for verified bragging rights.\n\nPlay: ${GAME_URL}`,
    },
  };
  const b = bodies[stage];
  return {
    subject: b.subject,
    html: layout(env, { title: b.title, unsubToken: p.unsubToken, bodyHtml: b.html }),
    text: b.text + textFooter(env, p.unsubToken),
  };
}

// ---------------------------------------------------------------------------
// C. Milestone emails
// ---------------------------------------------------------------------------
export function milestoneBossDefeat(env, p) {
  const base = env.PUBLIC_BACKEND_URL || "";
  const shareText = `I just SMOKED The Auditor in Lil Blunt: The Smoke Realm 🌿💨 Rank #${p.rank || "?"}. ${GAME_URL}`;
  return {
    subject: "💨 You smoked the Auditor",
    html: layout(env, {
      title: "You SMOKED the Auditor.",
      unsubToken: p.unsubToken,
      bodyHtml: `<p>Yo ${esc(p.name || short(p.wallet) || "champion")},</p>
        <p>First Auditor kill on record. Score: <b>${esc(p.score)}</b>${p.rank ? ` — that puts you at rank <b>#${esc(p.rank)}</b>` : ""}.</p>
        ${p.badgeUrl ? `<p style="text-align:center;"><img src="${esc(p.badgeUrl)}" alt="Victory badge" style="max-width:100%;border-radius:10px;"></p>` : ""}
        <p>Claim your <b>SmokeRing Survivor badge</b> from the victory screen next run — it mints to your wallet.</p>
        <div style="text-align:center;margin:18px 0;">
          ${cta(base, "play_now", GAME_URL, "▶ Run It Back")}
          ${cta(base, "share_boss", xIntent(shareText), "𝕏 Share the Kill", "#365ac2")}
        </div>`,
    }),
    text: `You SMOKED the Auditor. Score: ${p.score}${p.rank ? `, rank #${p.rank}` : ""}.\n\nClaim your SmokeRing Survivor badge from the victory screen next run.\n\nPlay: ${GAME_URL}${textFooter(env, p.unsubToken)}`,
  };
}

export function milestoneTop10(env, p) {
  const base = env.PUBLIC_BACKEND_URL || "";
  const shareText = `Top 10 in Lil Blunt: The Smoke Realm 🌿🏆 #${p.rank}. The SmokeRing sees me. ${GAME_URL}`;
  return {
    subject: `🔥 You're in the top 10 — rank #${p.rank}`,
    html: layout(env, {
      title: "You're in the top 10!",
      unsubToken: p.unsubToken,
      bodyHtml: `<p>Yo ${esc(p.name || short(p.wallet))},</p>
        <p>Rank <b>#${esc(p.rank)}</b>. The SmokeRing community sees you.</p>
        <div style="text-align:center;margin:18px 0;">
          ${cta(base, "share_top10", xIntent(shareText), "𝕏 Share on X", "#365ac2")}
          ${cta(base, "play_now", GAME_URL, "▶ Defend It")}
        </div>`,
    }),
    text: `Rank #${p.rank} - top 10! The SmokeRing community sees you.\n\nShare: ${xIntent(shareText)}\nPlay: ${GAME_URL}${textFooter(env, p.unsubToken)}`,
  };
}

// ---------------------------------------------------------------------------
// Referral invites
// ---------------------------------------------------------------------------
export function referralInvite(env, p) {
  const base = env.PUBLIC_BACKEND_URL || "";
  const joinUrl = `${base}/ref?token=${encodeURIComponent(p.refToken)}`;
  return {
    subject: `${p.referrerName || "A friend"} wants you in their Smoke Realm crew 🌿`,
    html: layout(env, {
      title: `${esc(p.referrerName || "Your friend")} sent for you.`,
      unsubToken: p.unsubToken,
      bodyHtml: `<p>Your friend <b>${esc(p.referrerName || "a Smoke Realm player")}</b> wants you
        to join their crew in <b>Lil Blunt: The Smoke Realm</b> — a chill retro
        platformer with bosses, secret realms, and on-chain bragging rights.</p>
        <div style="text-align:center;margin:18px 0;">
          ${cta(base, "ref_play", joinUrl, "▶ Play Now")}
          ${cta(base, "ref_join", joinUrl, "🤝 Join Crew", "#a2843a")}
        </div>
        <p style="font-size:12px;color:#57735f;">One free browser game. No install, no signup required.</p>`,
    }),
    text: `${p.referrerName || "A friend"} wants you to join their crew in Lil Blunt: The Smoke Realm.\n\nPlay: ${joinUrl}${textFooter(env, p.unsubToken)}`,
  };
}

export function referralFollowup(env, p) {
  const base = env.PUBLIC_BACKEND_URL || "";
  const joinUrl = `${base}/ref?token=${encodeURIComponent(p.refToken)}`;
  return {
    subject: "Your crew spot is still open 🌿",
    html: layout(env, {
      title: "Still saving your spot.",
      unsubToken: p.unsubToken,
      bodyHtml: `<p>You peeked at the Smoke Realm but haven't dropped in yet.
        ${esc(p.referrerName || "Your friend")}'s crew spot is still open.</p>
        <div style="text-align:center;margin:18px 0;">${cta(base, "ref_followup", joinUrl, "▶ Claim Your Spot")}</div>`,
    }),
    text: `You peeked at the Smoke Realm but haven't dropped in. The crew spot is still open.\n\nPlay: ${joinUrl}${textFooter(env, p.unsubToken)}`,
  };
}

// ---------------------------------------------------------------------------
// Admin digest (founder-only, no unsubscribe needed but keep it anyway)
// ---------------------------------------------------------------------------
export function adminDigest(env, d) {
  const rows = (d.top10 || []).map((t, i) =>
    `<tr><td style="padding:4px 8px;">${i + 1}</td>
     <td style="padding:4px 8px;font-family:monospace;">${esc(t.name || short(t.addr))}</td>
     <td style="padding:4px 8px;text-align:right;">${esc(t.score)}</td></tr>`).join("");
  const oracleRows = (d.oracleTop || []).map((q) =>
    `<li><b>${esc(q.count)}×</b> ${esc(q.q)}</li>`).join("");
  const ctas = (d.ctaTop || []).map((c) => `<li><b>${esc(c.count)}×</b> ${esc(c.cta)}</li>`).join("");
  return {
    subject: `📊 Smoke Realm founder digest — week of ${d.week}`,
    html: layout(env, {
      title: `Founder digest — ${esc(d.week)}`,
      unsubToken: d.unsubToken || "admin",
      bodyHtml: `
        <table style="width:100%;background:#0f1a14;border-radius:8px;margin-bottom:14px;">
          <tr><td style="padding:8px 10px;">Unique players this week</td><td style="text-align:right;padding:8px 10px;"><b>${esc(d.uniquePlayers)}</b></td></tr>
          <tr><td style="padding:8px 10px;">Wallet connections</td><td style="text-align:right;padding:8px 10px;"><b>${esc(d.walletConnects)}</b></td></tr>
          <tr><td style="padding:8px 10px;">Email subscribers</td><td style="text-align:right;padding:8px 10px;"><b>${esc(d.subscribers)}</b></td></tr>
          <tr><td style="padding:8px 10px;">Referrals sent / clicked / converted</td>
              <td style="text-align:right;padding:8px 10px;"><b>${esc(d.refSent)} / ${esc(d.refClicked)} / ${esc(d.refConverted)}</b>
              ${d.refSent ? ` (${Math.round((d.refConverted / d.refSent) * 100)}%)` : ""}</td></tr>
        </table>
        <p><b>Top 10 leaderboard:</b></p>
        <table style="width:100%;border-collapse:collapse;background:#0f1a14;border-radius:8px;">${rows || "<tr><td style='padding:8px'>no runs yet</td></tr>"}</table>
        <p><b>Most-clicked email CTAs:</b></p><ul>${ctas || "<li>no clicks tracked yet</li>"}</ul>
        <p><b>Oracle: most-asked questions:</b></p><ul>${oracleRows || "<li>no questions logged yet</li>"}</ul>`,
    }),
    text: `Founder digest ${d.week}\nPlayers: ${d.uniquePlayers} | Wallets: ${d.walletConnects} | Subs: ${d.subscribers}\nReferrals: ${d.refSent}/${d.refClicked}/${d.refConverted}\nTop10: ${(d.top10 || []).map((t, i) => `${i + 1}.${t.name || short(t.addr)}:${t.score}`).join(" ")}\nCTAs: ${(d.ctaTop || []).map((c) => `${c.cta}:${c.count}`).join(" ")}\nOracle: ${(d.oracleTop || []).map((q) => `${q.count}x ${q.q}`).join(" | ")}`,
  };
}

// ---------------------------------------------------------------------------
// Support auto-reply wrapper (body comes from the LLM; we add the frame)
// ---------------------------------------------------------------------------
export function supportReply(env, p) {
  return {
    subject: p.subject && p.subject.startsWith("Re:") ? p.subject : `Re: ${p.subject || "your Smoke Realm question"}`,
    html: layout(env, {
      title: "Smoke Realm support",
      unsubToken: p.unsubToken || "support",
      bodyHtml: `<p style="white-space:pre-wrap;">${esc(p.body)}</p>
        <p style="font-size:12px;color:#57735f;">— The Smoke Oracle (an AI helper).
        A human reviews flagged threads; just reply if this didn't solve it.</p>`,
    }),
    text: `${p.body}\n\n- The Smoke Oracle (an AI helper). Reply if this didn't solve it.${textFooter(env, p.unsubToken || "support")}`,
  };
}
