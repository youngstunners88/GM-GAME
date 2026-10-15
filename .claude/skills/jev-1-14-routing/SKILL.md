---
name: jev-1-14-routing
description: Route small typed decisions and Jev 1.14 image capability probes through the configured TypeSafe account, with explicit OpenRouter compatibility. Use for Jev/TypeSafe requests, semantic routing, focused visual acceptance questions and upgrading the old Jev 1.13 text-only workflow; not routine coding, image generation or deterministic checks.
---

# Jev 1.14: direct TypeSafe, explicit OpenRouter compatibility

User requested this upgrade on 2026-10-15 and then explicitly selected **Use TypeSafe directly** after configuring its API key. Read `references/compatibility.md` once per session. The old September test describes Jev 1.13 and an incorrect base64-as-text request; it does not establish the newer model's capabilities.

## Route cheaply

1. Exact matches, geometry measurements, tests, arithmetic and known policy checks stay in local code. Do not spend a model call to repeat them.
2. For an ambiguous semantic decision, retrieve only relevant facts and ask one atomic `noul`, named `choice` or ordered `score`. Put related independent questions in one request (usually 2–4; local maximum 8). Use unambiguous criteria, include an uncertain/manual-review outcome where appropriate, and consume only the selected route's arguments. Model output selects an allowlisted handler; it never becomes executable code or an unchecked path.
3. For a visual decision, use real reference/current images, label them distinctly and ask observable questions (grip contact, silhouette, clipping), not "is it good?". Use at most two relevant PNG/JPEG images, reuse aliases, and inspect/crop evidence locally first. Images are not base64 prose or a chat-completions message.
4. Use `scripts/jev.mjs --request request.json --dry-run` first. New requests default to provider `typesafe` and native model pin `jev-1.14`. A digest binds model, facts, criteria and actual image bytes. Reuse an existing receipt only when this digest and evidence/source revision match; never pay twice for unchanged evidence. Keep bulk code/logs out of state. The local budget is 64 KiB text, two images, 3 MiB and 2.1 megapixels per image; these are cost controls, **not advertised model context limits**. The supplied context-length page is currently blocked; refresh the official limit before a long-context job. Do not invent a token count or price.
5. Send explicitly with `--send`. Direct credentials come from configured `TYPESAFE` or `TYPESAFE_API_KEY`, used only at `https://api.typesafe.ai/v1/systemone`. OpenRouter is explicitly selected with provider `openrouter`, its own `OPENROUTER_API_KEY` / `OPENROUTER_API`, endpoint `https://openrouter.ai/api/alpha/decisions` and model `typesafe/jev-1.14`. Node 24.5+ retains proxy/NO_PROXY and platform CA. No automatic provider fallback, retries, credential requests or paid generation. Microsoft Decision stays explicitly on OpenRouter.
6. Save source SHA, request digest, actual returned model, typed answers, usage/cost if returned and HTTP outcome. For `noul`, >=0.8 means yes, <=0.2 no; the middle is uncertain. A model decision is advice and cannot authorize shipping, substitute for tests or prove a live deployment.

## Image boundary — do not skip

Direct TypeSafe uses the documented multipart image bytes and `TypeSafe-Danger-Zone-Images: true` header automatically when assets are attached. It is experimental upstream. A configured key is not proof of network access: all TypeSafe API/docs hosts currently receive CONNECT 403 in this cloud. The attempted network draft save returned INVALID_ARGUMENT and readback retained the old custom hosts. Readiness metadata for the updated key currently says unknown; key values must never be printed.

First verify a response identifies `jev-1.14`, then run a paired image control (same question, unmistakable present/absent gold revolver) with actual attachments. Retain both outputs. Local multipart tests verify the encoder, not provider acceptance or vision accuracy. If blocked, retain the failure and continue local visual inspection. No image judgment is claimed yet.

OpenRouter compatibility is separate: its SDK 1.4.25 only documents JSON Decisions. For an explicitly requested forwarding probe, `--provider openrouter --experimental-images` permits the candidate upstream encoding, pinned `typesafe/jev-1.14`. Do not call that transport verified until it and image controls succeed. Never send a TypeSafe key to OpenRouter or an OpenRouter key to TypeSafe, downgrade a model, or paste base64 prose as image evidence.

```json
{
  "provider": "typesafe",
  "model": "jev-1.14",
  "state": {"source_sha": "ACTUAL_SOURCE_SHA", "evidence": "Inspect <current> against <target>."},
  "questions": {
    "grip_contact": {"type":"noul","instructions":"In <current>, do all visible gripping fingers contact the wooden grip without floating?"},
    "next_work": {"type":"choice","instructions":"Which single correction has the clearest visible evidence?","criteria":{"grip":"Floating or intersecting grip","silhouette":"Wrong barrel/grip shape","manual":"Insufficient visible evidence"}}
  },
  "assets": {"<current>":"path/to/gameplay.png","<target>":"path/to/reference.jpg"}
}
```

```sh
node scripts/jev.mjs --request request.json --dry-run
node scripts/jev.mjs --request request.json --send
node --test tests/jev_request_test.mjs
```

`assets` maps aliases to local files in this wrapper. It reads and validates file bytes, then sends the upstream SDK's `request` JSON part plus named image parts; it never forwards file paths as provider-visible evidence. Text-only requests keep the existing JSON/boolean-to-noul path. A 400/422 is a schema failure, a 403 may be policy/access, and a 404 needs endpoint/model diagnosis. None proves the whole Jev family absent. Stop that request on error and retain evidence.
