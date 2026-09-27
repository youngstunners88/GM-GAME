# 004 — Gemini as the listener for audio takes (VERIFIED)

Sessions cannot hear. `scripts/varco-grade.mjs` sends all takes of a stem (inline WAV) plus its
catalog brief to Gemini and gets `{best, scores, notes}`; picks are written to
`takes/<id>/grade.json` so a human can overrule them. Model availability moves: on 2026-09-27
`gemini-2.5-*` returned 404 ("no longer available to new users"), `gemini-3.8-flash` and
`gemini-omni-*` hit 429 quota, `gemini-3.5-flash` worked. The grader backs off on 429.
