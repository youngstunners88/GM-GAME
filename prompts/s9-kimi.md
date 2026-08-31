@include prompts/_s9_facts.md
@include src/boss/distributor.gd
# Kimi K3 — design LOCK HYSTERESIS for the climb-lock. Terse; exact code/consts.
Give a concrete hysteresis so the lock (climbing -> to.x=0) cannot re-arm on
every player hop, WITHOUT reintroducing the sideways sweep-kill:
- Propose the exact new state var(s) + timer(s) + the modified condition in
  _hover_pursue. E.g. once climbing releases, suppress re-arm for a cooldown
  UNLESS the boss is genuinely about to collide (very small |dx| AND very small
  vertical gap). Give the numbers (cooldown seconds, the "genuine collision"
  thresholds) and why they don't sweep-kill.
- Give a headless gate metric that DISCRIMINATES pre/post using a weaving+HOPPING
  player: what to measure (lock duty AND net horizontal pursuit under hops) and
  the threshold. Note the pre-fix expected value.
- Confirm the fix can't pin him at a wall or freeze him.
Output numbers + line-level changes only.
