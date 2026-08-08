---
name: env-secrets-and-apis
description: Discover which API keys/secrets are present in THIS session's environment, by name only — never print or log values. Resolves the itch/butler key-name ambiguity and the "session env vs GitHub Actions secret" confusion that previously caused a founder to be asked for keys that were already available. Run at the start of any session that touches ElevenLabs, OpenRouter, Muapi, itch/butler, or before claiming a key is "missing."
user-invocable: true
allowed-tools: Bash, Read, Grep
---

# Env Secrets & APIs — presence-only discovery

**This skill only checks NAMES. It never prints, logs, or commits a key
VALUE.** A previous session burned a whole cycle diagnosing a "missing
voice" that was actually a wrong-key problem — the fix was found by
checking *which* key a workspace resolves to, not by re-asking the founder.

## Why this exists

1. **The itch/butler key family.** The founder's itch.io API key **is** the
   butler deploy credential. It may be present in the session as
   `ITCH_API_KEY` and/or `BUTLER_API_KEY` — check both names before saying
   "butler isn't configured." If either is present in the session, butler
   deploy is possible from this session (see `itch-butler-deploy`).
2. **Session env ≠ GitHub Actions secret.** A key being present in *this*
   interactive session (`printenv`) does **not** mean CI can see it. CI only
   sees repo secrets configured at Settings → Secrets → Actions, under the
   **exact name** the workflow YAML references (e.g. `.github/workflows/
   export-game.yml` reads `secrets.BUTLER_API_KEY` — a session-only
   `ITCH_API_KEY` does not satisfy that, even though it's the same
   credential family). Conflating these two caused a stale itch.io build to
   go unnoticed for multiple sessions.
3. **ElevenLabs has TWO keys in this project's history**
   (`ELEVENLABS_API` and the legacy `ELEVENLABS_API_KEY`), and they do
   **not** see the same voice library — one workspace owns custom voices,
   the other doesn't. A `voice_not_found` error is a wrong-key symptom, not
   proof the voice doesn't exist. Always check which key resolves the
   target voice ID via `GET /v1/voices` before concluding a voice is
   missing (see `scripts/generate_audio.py`'s `KEY_ENV_NAMES` order — do
   not silently reorder it back).
4. **OpenRouter / Muapi** are single-key services in this project
   (`OPENROUTER_API_KEY`, `MUAPI_API_KEY`) — no known ambiguity, but still
   check presence-only before assuming a dispatch or image-gen call will
   work.

## How to run the scan

Names only — this exact pattern never echoes a value:

```bash
for k in ITCH_API_KEY BUTLER_API_KEY ELEVENLABS_API ELEVENLABS_API_KEY \
         OPENROUTER_API_KEY MUAPI_API_KEY; do
  v=$(printenv "$k" 2>/dev/null)
  if [ -n "$v" ]; then echo "$k: present (len ${#v})"; else echo "$k: absent"; fi
done
```

Report results as a table of `name: present/absent` (length is fine to
show; the value never is). This is the standing "session-start checklist"
step — do it once per session before claiming a key is unavailable.

## Resolving which key actually works for a multi-key service

Don't guess — call the service's own discovery endpoint with each candidate
key and compare. Example pattern (ElevenLabs voices, adapt per service):

```python
import os, json, urllib.request
for name in ("ELEVENLABS_API", "ELEVENLABS_API_KEY"):
    key = os.environ.get(name, "")
    if not key:
        continue
    req = urllib.request.Request("https://api.elevenlabs.io/v1/voices",
                                  headers={"xi-api-key": key})
    data = json.load(urllib.request.urlopen(req, timeout=30))
    print(name, "sees", len(data.get("voices", [])), "voices")
```

Whichever key resolves the resource you need is the one to use — record
that decision in code (a comment on the constant/order), not just in chat,
so it survives to the next session.

## What NOT to do

- Do not ask the founder "is your itch key set?" before running the scan
  above — if `ITCH_API_KEY` or `BUTLER_API_KEY` is present in session, you
  already know.
- Do not claim "BUTLER_API_KEY not set" from a CI log alone without also
  checking whether the *session* has a usable itch/butler key — those are
  two different facts and both matter (session key can deploy manually now;
  repo secret is needed for CI to auto-deploy on every push).
- Do not print a key value into a commit, a STATUS.md note, a test file, or
  a chat message under any circumstance, including "just to confirm it's
  right" — length and presence are always sufficient.
