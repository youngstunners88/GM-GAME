#!/usr/bin/env bash
# One-command backend deploy (deploy-skill). Everything that CAN be prepared
# is prepared — this script is the single remaining step, runnable the moment
# Cloudflare credentials with account access exist.
#
# WHY THIS ISN'T ALREADY DONE (2026-07-19): the CLOUDFLARE_API_KEY in the
# environment is a valid, active API TOKEN (tokens/verify = 200) but has NO
# account permissions — /accounts lists nothing, /memberships is denied, and
# no CLOUDFLARE_ACCOUNT_ID is set. Wrangler cannot target an account.
#
# FIX (client, ~1 min): EITHER set CLOUDFLARE_ACCOUNT_ID (dash.cloudflare.com
# → right sidebar) alongside a token that has [Workers Scripts:Edit, Workers
# KV Storage:Edit], OR mint a token with those perms + Account Settings:Read.
# Then: ./scripts/deploy-backend.sh
set -euo pipefail
cd "$(dirname "$0")/../backend"

export CLOUDFLARE_API_TOKEN="${CLOUDFLARE_API_TOKEN:-${CLOUDFLARE_API_KEY:-}}"
# NB: `[ cond ] && action` is a set -e landmine (false cond = script death);
# every guard here uses if/then.
if [ -z "$CLOUDFLARE_API_TOKEN" ]; then echo "FATAL: no CLOUDFLARE_API_TOKEN/CLOUDFLARE_API_KEY"; exit 1; fi
if [ -z "${CLOUDFLARE_ACCOUNT_ID:-}" ]; then
  CLOUDFLARE_ACCOUNT_ID=$(curl -s https://api.cloudflare.com/client/v4/accounts \
    -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" | python3 -c "import json,sys;r=json.load(sys.stdin).get('result') or [];print(r[0]['id'] if r else '')")
  if [ -z "$CLOUDFLARE_ACCOUNT_ID" ]; then echo "FATAL: token has no account access and CLOUDFLARE_ACCOUNT_ID unset (see header)"; exit 1; fi
fi
export CLOUDFLARE_ACCOUNT_ID

# 1/6 KV namespace via REST (wrangler refuses ALL commands while the toml id
# is empty — chicken-and-egg discovered on first live deploy). Idempotent:
# reuse an existing *GAME_KV namespace, else create.
KV_API="https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/storage/kv/namespaces"
KV_ID=$( { curl -s "$KV_API?per_page=100" -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" || true; } | python3 -c "import json,sys
try:
  for n in json.load(sys.stdin).get('result') or []:
    if n.get('title','').endswith('GAME_KV'): print(n['id']); break
except: pass")
if [ -z "$KV_ID" ]; then
  KV_ID=$( { curl -s -X POST "$KV_API" -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" -H "Content-Type: application/json" -d '{"title":"lil-blunt-backend-GAME_KV"}' || true; } | python3 -c "import json,sys
try: print(json.load(sys.stdin)['result']['id'])
except: pass")
fi
if [ -z "$KV_ID" ]; then echo "FATAL: could not create/find GAME_KV namespace"; exit 1; fi
sed -i "s/^id = \"\"/id = \"$KV_ID\"/" wrangler.toml
echo "KV: $KV_ID"

# 2/6 Secrets from the environment (names mapped; never echoed).
put_secret() {
  if [ -n "${2:-}" ]; then
    if printf '%s' "$2" | wrangler secret put "$1" >/dev/null 2>&1; then echo "secret set: $1"; else echo "secret FAILED: $1"; fi
  else
    echo "secret SKIPPED (env empty): $1"
  fi
}
put_secret MISTRAL_API_KEY      "${MINSTRAL_API_KEY:-${MISTRAL_API_KEY:-}}"
put_secret MISTRAL_API_KEY2     "${MINSTRAL_API_KEY2:-}"
put_secret OPENROUTER_API_KEY   "${OPENROUTER_API_KEY:-}"
put_secret AGENTMAIL_API_KEY    "${AGENT_MAIL_API_KEY:-${AGENTMAIL_API_KEY:-}}"
put_secret XAI_API_KEY          "${XAI_API_KEY:-${XAI_API:-}}"
WEBHOOK_SECRET_VAL="${WEBHOOK_SECRET:-$(head -c 32 /dev/urandom | od -A n -t x1 | tr -d " \\n")}"
put_secret WEBHOOK_SECRET "$WEBHOOK_SECRET_VAL"
echo "NOTE: WEBHOOK_SECRET generated — register the AgentMail webhook with ?secret=<it> (AGENTMAIL_SETUP.md step 4)."

# 3/6 First deploy → learn the public URL.
URL=$(wrangler deploy 2>&1 | tee /tmp/wrangler-deploy.log | grep -oE 'https://[a-z0-9.-]+\.workers\.dev' | head -1)
if [ -z "$URL" ]; then echo "FATAL: deploy failed"; tail -20 /tmp/wrangler-deploy.log; exit 1; fi
echo "Deployed: $URL"

# 4/6 Bake vars that need the URL, then redeploy once.
python3 - "$URL" <<'EOF'
import re, sys
url = sys.argv[1]
s = open('wrangler.toml').read()
block = f'''[vars]
PUBLIC_BACKEND_URL = "{url}"
ALLOWED_ORIGIN = "*"
SENDER_INBOX_ID = "smokering-notifications@agentmail.to"
SUPPORT_INBOX_ID = "smokering-notifications@agentmail.to"
ADMIN_EMAIL = "teacherchris37@gmail.com"
POSTAL_ADDRESS = "SmokeRing - The Smoke Realm (update with mailing address)"
DIGEST_DRAFT_ONLY = "1"
'''
# Replace the commented [vars] stub with a real one (idempotent).
if '\nPUBLIC_BACKEND_URL' in s:
    s = re.sub(r'PUBLIC_BACKEND_URL = "[^"]*"', f'PUBLIC_BACKEND_URL = "{url}"', s)
else:
    s = s.replace('[vars]\n', block, 1) if '[vars]\n' in s else s + '\n' + block
open('wrangler.toml','w').write(s)
EOF
wrangler deploy >/dev/null 2>&1
echo "vars baked + redeployed (ALLOWED_ORIGIN=* for first smoke test — tighten per checklist F3; DIGEST_DRAFT_ONLY=1 so the first Monday run stops at drafts)"

# 5/6 E2E verification.
echo "--- /health ---";      curl -sf "$URL/health" && echo ""
echo "--- /leaderboard ---"; curl -sf "$URL/leaderboard" && echo ""
echo "--- /oracle (live Mistral) ---"
curl -sf -X POST "$URL/oracle" -H "Content-Type: application/json" -d '{"question":"what is blaze mode?"}' && echo ""
echo "--- /balances (multi-chain read, vitalik.eth as neutral test addr) ---"
curl -sf "$URL/balances?owner=0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045" && echo ""

# 6/6 Wire the game.
python3 - "$URL" <<'EOF'
import json, sys
p = '../config.json'
d = json.load(open(p))
d['backend_base_url'] = sys.argv[1]
json.dump(d, open(p, 'w'), indent=2)
EOF
echo ""
echo "DONE. config.json updated → commit + push (CI rebuilds the game with the live backend)."
echo "Post-deploy: run scripts/security-audit.ts, flip checklist F2/F3 to LIVE, update backend/01-current-state.md."
