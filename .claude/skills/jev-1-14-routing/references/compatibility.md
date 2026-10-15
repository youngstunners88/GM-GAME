# Verified sources and pending transport (2026-10-15)

User sources: https://typesafe.ai/blog/jev-1-14 ; https://docs.typesafe.ai/models#context-length ; https://docs.typesafe.ai/images . All three returned proxy CONNECT 403; no release-specific context size or price has been verified.

Read independently accessible official source, without changing network policy:

- TypeSafe SDK `@typesafe-ai/sdk` 0.7.0, npm registry tarball; official repository https://github.com/typesafe-ai/typesafe-sdk-js/tree/b844cd1aca12855a5d24a2df52a1401c86e7d37a . README Images; `src/assets.ts` lines 292–402. PNG/JPEG, file-byte MIME detection, literal aliases, multipart `request` JSON with `assets:{alias:{type:"image",part:"asset-N"}}`, and image file parts. Experimental opt-in header `TypeSafe-Danger-Zone-Images: true`. SDK `box` examples use `jev-preview`; **do not infer box support on OpenRouter**. No new SDK dependency was added to the game.
- OpenRouter official `@openrouter/sdk` 1.4.25, https://github.com/OpenRouterTeam/typescript-sdk . `models/decisionsrequest` contains model/state/questions; `funcs/alphaDecisionsCreate` sends JSON to `/api/alpha/decisions`. It has no documented image assets or multipart fields. Upstream TypeSafe image syntax is evidence for the candidate encoding, not proof OpenRouter forwards it.
- TypeSafe official skill https://github.com/typesafe-ai/skills/tree/65a39f393687675ce170e6094757de20370365b9 : small semantic primitives, named facts/criteria, code retains deterministic work. Adapted routing guidance; no upstream code copied into the game.

`scripts/jev-request.mjs` implements the bounded candidate image encoding and exact-response checks. Actual acceptance, model ID availability, image control, context length and cost remain pending live provider evidence. No vision result is claimed on a failed request. Text path and offline multipart validation are tested separately.

## User-selected direct route

The user explicitly chose “Use TypeSafe directly” after adding TYPESAFE. The helper now defaults to `https://api.typesafe.ai/v1/systemone` (SDK `client.ts`) and native pin `jev-1.14`. TypeSafe credentials never go to OpenRouter; OpenRouter remains an explicit compatibility provider. The live direct request also fails before provider acceptance with proxy CONNECT 403. Native model availability, paired image control and release-specific limits remain pending. The SDK's default `jev-latest` is not used to silently bypass the requested 1.14 pin.

The final encoder matches the SDK byte protocol: the `request` JSON part has Content-Type application/json **without a filename**; image parts have their own MIME/filename. Offline tests inspect boundaries, descriptors and unchanged binary PNG bytes. Native FormData + Blob was corrected because it adds filename="blob" to the JSON part, which some servers parse as a file. The blocked network attempt cannot establish either candidate was accepted.

## Verified against official docs 2026-10-15

Read from the official TypeSafe docs (supersedes the "unreachable" note above for these facts):

- Images: endpoint `https://api.typesafe.ai/v1/systemone`, required header `TypeSafe-Danger-Zone-Images: true`; multipart with JSON part `request` (application/json) plus image parts named by each asset's `part` field; alternative is base64 `data_base64` in the JSON (not used here). PNG or JPEG stills only; animated PNG rejected.
- Limits: image <= 16 MiB; each side 256..1568 px; total pixels 78,400..2,458,624; request body, all images combined and expanded request each <= 32 MiB. Local `BUDGET` stays stricter (3 MiB, 2.1M px, 2 images).
- References are the asset key in backticks (`photo`) in `state`/`instructions`/`criteria`; reusing a reference duplicates the image (token cost). `usage.input_tokens` includes image tokens. The helper accepts both docs-style `photo` and SDK-style `<photo>` keys.
- Question types: noul, choice, score, plus experimental `box` (bounding boxes). Images and Box are documented as not production-ready; format and accuracy may change. `validateResponse` checks only the answer type for `box`.
- Long context: header `TypeSafe-Danger-Zone-Long-Context: true` raises 64k per-request / 32k per-question to 262k. Exposed as `longContext` / `--long-context`; local text budget rises to 1 MiB only when set.
- Models: `jev-1.14.0`, `jev-1.13.0`; `jev-preview` -> 1.14.0; **`jev-latest` -> 1.13.0, not 1.14**. Image requests therefore accept only `jev-1.14`, `jev-1.14.0`, `jev-preview`. Price $42 per billion input tokens, output free.
- Docs disagree: the models page lists input as text-only; the images page describes images behind the experimental header. Treat images as experimental.
- **Live acceptance is still unverified**: no API key is available in this environment, so no request was sent. Offline tests cover encoding and validation only.
