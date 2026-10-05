---
name: smokerealm-ship
description: Complete GM-GAME changes through verified release to SmokeRealm on itch.io. Use when implementing or finishing work in youngstunners88/GM-GAME, or checking whether its changes reached players.
---

# SmokeRealm release contract

The user explicitly instructed on 2026-10-04: completed game work must be committed, pushed, and shipped to https://youngstunners88.itch.io/smokerealm without repeated reminders. Apply this standing instruction to this repository only. A later user request to pause, review without publishing, or change scope takes precedence.

Repository: https://github.com/youngstunners88/GM-GAME. Production branch is `master`; verify the current workflow target `youngstunners88/smokerealm:html5` before release.

Read repository instructions, current STATUS.md, `.claude/skills/always-ship-live/SKILL.md`, and `scripts/ship-to-master.sh`. Use the existing release pipeline; do not create competing deployment automation.

- Work from current master and preserve concurrent changes. Use a `codex/` branch; never force-push production.
- Complete appropriate runtime, visual, and regression verification. Preserve the title-screen lock, existing access controls, and non-threaded Compatibility web export. The current PCK gate is 190 MiB; re-read the workflow for the actual limit.
- Update STATUS.md with specific changes and checked/unchecked behavior, then commit and push the scoped work.
- Run the repository shipping script, or preserve its merge, verification, and non-forced fast-forward semantics when platform tooling differs. Re-fetch master before updating it. Resolve conflicts by integrating both sessions' intended behavior.
- Verify the release workflow whose source SHA contains the change, its successful export and butler deployment, and the actual upload log. A successful step that merely skips upload for missing credentials is not deployment.
- Open the public game, confirm its BUILD tag corresponds to the released source, and exercise the changed flow. Distinguish native tests, local web tests, and public release checks.
- Report the commit, build, live URL, and actual deployment result. Do not label a local artifact, pushed branch, or pending workflow as shipped. If blocked, state the exact failed step and preserve the work for continuation.

Use existing authenticated connectors or credential helpers. Never request secrets in chat, reveal credential values, or commit credentials. Standing shipping authorization does not authorize unrelated releases, new paid services, or weakened checks.
