// AgentMail API client module (Layer Shift: marketing engine).
// Docs: https://docs.agentmail.to — OpenAPI: https://docs.agentmail.to/openapi.json
// Base: https://api.agentmail.to, Bearer auth with env.AGENTMAIL_API_KEY.
//
// Rules enforced here (AGENTMAIL_SETUP.md):
// - The key NEVER leaves the backend. This module runs only inside the Worker.
// - EVERY send carries an Idempotency-Key header (+ client_id where the API
//   supports it) so retries can never double-send an email.
// - 429 responses queue-and-retry with exponential backoff (3 attempts).
// - All sends go to confirmed opt-in recipients only — callers must check
//   consent BEFORE calling send*(); this module additionally refuses to send
//   when the recipient is on the local suppression set (unsubscribed).

const BASE = "https://api.agentmail.to";

/** Low-level request with auth, idempotency and 429 exponential backoff. */
export async function amRequest(env, method, path, body, idemKey) {
  if (!env.AGENTMAIL_API_KEY) return { ok: false, status: 0, error: "AGENTMAIL_API_KEY not set" };
  const headers = {
    Authorization: `Bearer ${env.AGENTMAIL_API_KEY}`,
    "Content-Type": "application/json",
  };
  if (idemKey) headers["Idempotency-Key"] = idemKey;
  let delay = 1000;
  for (let attempt = 0; attempt < 3; attempt++) {
    let res;
    try {
      res = await fetch(BASE + path, {
        method,
        headers,
        body: body ? JSON.stringify(body) : undefined,
      });
    } catch (e) {
      return { ok: false, status: 0, error: String(e) };
    }
    if (res.status === 429) {
      // Rate limited: honor Retry-After if present, else exponential backoff.
      const ra = parseInt(res.headers.get("Retry-After") || "0");
      await new Promise((r) => setTimeout(r, ra ? ra * 1000 : delay));
      delay *= 2;
      continue;
    }
    let data = null;
    try { data = await res.json(); } catch (e) { /* empty body is fine */ }
    return { ok: res.ok, status: res.status, data };
  }
  return { ok: false, status: 429, error: "rate limited after retries" };
}

/** True if this address has unsubscribed (local suppression, KV-backed). */
export async function isSuppressed(env, email) {
  if (!env.GAME_KV || !email) return false;
  return (await env.GAME_KV.get("suppress:" + email.toLowerCase())) !== null;
}

/** Suppress locally AND block on the AgentMail send list (belt & braces). */
export async function suppress(env, email, reason) {
  const addr = (email || "").toLowerCase();
  if (!addr) return;
  await env.GAME_KV.put("suppress:" + addr, reason || "unsubscribed");
  if (env.SUPPORT_INBOX_ID) {
    // AgentMail Lists API: block this entry for outbound sends.
    await amRequest(env, "POST",
      `/v0/inboxes/${env.SUPPORT_INBOX_ID}/lists/send/block`,
      { entry: addr, reason: reason || "player unsubscribed" });
  }
}

/**
 * Send an email immediately. `key` is the idempotency key — REQUIRED and must
 * be deterministic per logical email (e.g. "digest:<week>:<player>") so cron
 * re-runs can't duplicate. Refuses suppressed recipients.
 */
export async function sendEmail(env, { to, subject, html, text, labels, key }) {
  if (await isSuppressed(env, Array.isArray(to) ? to[0] : to)) {
    return { ok: false, status: 0, error: "recipient suppressed (unsubscribed)" };
  }
  const inbox = env.SENDER_INBOX_ID || env.SUPPORT_INBOX_ID;
  if (!inbox) return { ok: false, status: 0, error: "no sender inbox configured" };
  return amRequest(env, "POST", `/v0/inboxes/${inbox}/messages/send`, {
    to: Array.isArray(to) ? to : [to],
    subject, html, text,
    labels: labels || [],
  }, key);
}

/**
 * Create a draft (human-in-the-loop path). Same shape as sendEmail; the draft
 * sits in the AgentMail inbox until sendDraft() or a human review.
 * client_id doubles as idempotency at the resource level.
 */
export async function createDraft(env, { to, subject, html, text, labels, key, inbox }) {
  const box = inbox || env.SENDER_INBOX_ID || env.SUPPORT_INBOX_ID;
  if (!box) return { ok: false, status: 0, error: "no inbox configured" };
  return amRequest(env, "POST", `/v0/inboxes/${box}/drafts`, {
    to: Array.isArray(to) ? to : [to],
    subject, html, text,
    labels: labels || [],
    client_id: key,
  }, key);
}

/** Send a previously created draft. */
export async function sendDraft(env, inboxId, draftId, key) {
  return amRequest(env, "POST", `/v0/inboxes/${inboxId}/drafts/${draftId}/send`, {}, key);
}

/** Draft-then-send: the weekly digest uses this so a human can pause the cron
 * and review drafts instead — flip DIGEST_DRAFT_ONLY=1 to stop at the draft. */
export async function draftThenSend(env, msg) {
  if (await isSuppressed(env, Array.isArray(msg.to) ? msg.to[0] : msg.to)) {
    return { ok: false, error: "recipient suppressed (unsubscribed)" };
  }
  const box = msg.inbox || env.SENDER_INBOX_ID || env.SUPPORT_INBOX_ID;
  const draft = await createDraft(env, msg);
  if (!draft.ok) return draft;
  if (env.DIGEST_DRAFT_ONLY === "1") return { ok: true, draftOnly: true, data: draft.data };
  const draftId = draft.data && (draft.data.draft_id || draft.data.id);
  if (!draftId) return { ok: false, error: "draft created but no id returned" };
  return sendDraft(env, box, draftId, msg.key ? msg.key + ":send" : undefined);
}

/** Add labels to an existing message (support triage). */
export async function labelMessage(env, inboxId, messageId, addLabels) {
  return amRequest(env, "PATCH", `/v0/inboxes/${inboxId}/messages/${messageId}`, {
    add_labels: addLabels,
  });
}

/** One-time setup helpers (invoked from AGENTMAIL_SETUP.md, not the hot path). */
export async function createDomain(env, domain) {
  return amRequest(env, "POST", "/v0/domains", { domain, feedback_enabled: true });
}
export async function getDomain(env, domainId) {
  return amRequest(env, "GET", `/v0/domains/${domainId}`);
}
export async function verifyDomain(env, domainId) {
  return amRequest(env, "POST", `/v0/domains/${domainId}/verify`);
}
export async function createInbox(env, { username, domain, display_name, client_id }) {
  return amRequest(env, "POST", "/v0/inboxes", { username, domain, display_name, client_id }, client_id);
}
export async function createInboxWebhook(env, inboxId, url) {
  return amRequest(env, "POST", `/v0/inboxes/${inboxId}/webhooks`, {
    url, event_types: ["message.received"], client_id: "smokering-support-hook",
  }, "smokering-support-hook");
}
