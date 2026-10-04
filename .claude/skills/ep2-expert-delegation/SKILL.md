---
name: ep2-expert-delegation
description: How to hand Episode 2 work to a stronger model ("get Fable 5.1 to do the work you are unable to do") - file-ownership contract, the brief template, what to do when Fable 5.1 is blocked by usage credits (fall back to Opus, say so), and how to review what comes back. TRIGGER on "get Fable / Opus to do it", "use the stronger model", a task whose art or architecture quality you cannot reach yourself, or an Agent call that fails with "requires usage credits".
---
# What happened 2026-10-04
The founder asked for Fable 5.1 to do the art work the session could not. The Agent tool accepts `model: "fable"` but the account answered HTTP 429 "Fable 5.1 requires usage credits". That is an account setting (claude.ai/settings/usage), not something a session can fix. Do not retry it, do not hide it: tell the founder in one line, then run the SAME brief on `model: "opus"` and say that is what ran.
# Contract (it worked: no edit collisions with a concurrent session)
- Split by FILE, not by feature: the delegate owns named files + named functions; the lead owns everything else. Extract the delegate's surface into its own file first (`range_dressing.gd` with a documented contract) so there is no shared function to fight over.
- In a shared file the delegate may only use small anchored Edit-tool replacements, re-reading the region before each edit; never rewrite or reformat it.
- The delegate never commits, pushes, merges or ships; the lead does, after reviewing the diff.
- Give measurable acceptance (px size + contrast thresholds, test names, capture commands), the rules from CLAUDE.md that bind it (front-page lock, no wallet addresses, non-threaded export, pck budget: net growth < 1.5 MB), and the reporting format (files, before/after numbers, hooks the lead must call, what did NOT work).
# Review
Read the diff, run the gates yourself, LOOK at the captures. A delegate's "done" is a lead, not a fact. Re-integrate any hook it exposes (e.g. `set_bull_rifle_mode`) and add a test.
