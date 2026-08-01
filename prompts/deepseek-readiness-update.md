# DeepSeek — update PR #12 Episode 1 readiness (playtest status honesty)

Rewrite the status of `docs/pr12-episode1-readiness.md` given what changed
since it was written. Output ONLY the replacement content for the three
status sections (Green / Soft / Deferred) plus the merge-recommendation
line. Keep it terse and factual. Do not invent test results.

## What changed since that doc was written

**Resolved this session:**
- Lil Blunt's real custom voice is now LIVE on all 5 action barks. The
  earlier `voice_not_found` 404 was a WRONG-KEY problem, not a missing
  voice: the environment has two ElevenLabs keys, and only `ELEVENLABS_API`
  (not the legacy `ELEVENLABS_API_KEY`) belongs to the workspace that owns
  the custom "Lil Blunt" voice HMGfKwZCRujgXyRDUW0b. The generator now
  prefers `ELEVENLABS_API`. The stand-in voice is gone.
- Verified at engine level: all 5 barks load from exported paths, create a
  live player on the SFX bus, cooldowns suppress repeats, and a missing
  file is a silent no-op. Clip lengths 0.84-1.53s, every cooldown exceeds
  its clip length so no bark can cut itself off.
- Companion offline lines for the two most-repeated states (last life,
  died-to-Auditor) now rotate through 3 extra variants each instead of
  replaying one sentence.

**Still true / unchanged:**
- Full gate battery + security sentinel 18/18 were green as of the prior
  session; re-run this session after the changes.
- The Auditor chase tune (0.7s ramp + 0.35s contact grace) is still
  CODE-ONLY. No human has played it. Checklist step 24 is the open verdict.
- **The founder has still NOT run `docs/playtest/episode1-human-checklist.md`.**
  That is the single biggest open risk and the gate for calling Episode 1
  complete.
- Companion pause-menu entry is structurally verified but was never driven
  open in an automated browser harness (synthetic Escape doesn't reach
  Godot's _unhandled_input); a main-menu entry point exists and IS
  browser-verified, so the feature is reachable either way.

**Deferred / untouched:** Episode 2, meme guests, NFT mint, Audio8,
Polygres, Freebuff, Agent-Reach, StreamCore redesign, and the optional
Blaze Rush art slice.

Merge recommendation must state plainly that merging PR #12 remains a
founder decision AFTER they complete the playtest checklist — not a
recommendation to merge now.
