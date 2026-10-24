---
name: browser-keep-the-tab
description: "Browser etiquette for the founder's built-in browser pane: never navigate a tab away from the page it is working on (Flow with attached references and queued generations, Tripo, a half-filled form, a Drive folder). To visit another site, OPEN A NEW TAB with tabs_create and navigate THAT, then switch back with tabs_select. TRIGGER whenever a task needs a second website while a first one holds state: Google Flow + Drive, Flow + the game on itch, Tripo + anything, any 'let me just check this link'. Founder rule 2026-10-19."
---

# The rule (founder, 2026-10-19, after Flow lost its attached references because the tab was navigated away)
"When you're switching websites, don't use the one you're on. Open a new one so you can simply return."

# Do
1. The tab that holds work (Flow prompt with references, Tripo scene, an unsaved form) is **home**. Never call `navigate` on it for anything unrelated.
2. Need another site (Drive viewer, a doc, itch, GitHub)? `mcp__Claude_Browser__tabs_create` (foreground only if the founder should watch), `navigate` with that `tabId`, do the work there.
3. To return: `tabs_select` the home tab. Its state (attached images, typed prompt, scroll position, running generations) is untouched.
4. Keep one extra "scratch" tab for lookups and reuse it for several look-ups (navigating the scratch tab is fine). Close it with `tabs_close` when the task is finished.
5. Always pass `tabId` on `computer`, `find`, `read_page`, `javascript_tool` and `navigate` once there is more than one tab, so an action never lands on the wrong page.

# Don't
- Don't `navigate` the work tab "just for a second", not even to reload it; a reload drops attached references and unsent prompts.
- Don't leave stray tabs behind at the end of a task.

# Verifying a Drive image without leaving Flow
Use a scratch tab: `https://drive.google.com/thumbnail?id=<fileId>&sz=w1000` renders the image (the pane is signed in); screenshot it there.

# Related
`gm-game-nft-flow-generation` (the Flow workflow that depends on this rule), `see-it-yourself`.
