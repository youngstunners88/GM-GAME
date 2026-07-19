# docs — next task

**Single next action:** keep `../02-status.md` blockers synchronized as the
client burns them down (backend deploy → AgentMail DNS → contracts → Publish).
Each unblock flips a track's `02-next-task.md` — update the pair together.

## Acceptance criteria
- [ ] Every client unblock reflected in root `02-status.md` + the owning
      track's `01-current-state.md` within the same working session
- [ ] `STATUS.md` (client report) updated per the ALWAYS-SHIP rule
- [ ] Security checklist F2/F3 flipped to LIVE status when the backend deploys

**After that:** promote the top 5 track-log decisions (one seam, non-threaded
export, LLM cost ladder, off-chain scores, adaptive-difficulty bounds) into
formal ADRs under `architecture/` using the template.
