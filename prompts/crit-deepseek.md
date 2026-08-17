You are DeepSeek with the skill `model-deepseek-compliance`. Build a compliance
matrix for this in-progress work against the founder's Definition of Done.
Mark each PASS / FAIL / BLOCKED with the evidence standard required.

DoD:
| ID | Requirement | Pass condition |
| B1 | Distributor chases in real Stage 2 arena | Closes on a MOVING player; not pinned/frozen in VULNERABLE |
| B2 | Claim Jumper chases in real Stage 3 arena | Closes + can kill; separation floor doesn't make him trivial |
| S1 | Stage 3 functionless blocks/props removed or purposeful | STATUS lists removals with approx x |
| S2 | Hammer/big_axe substantial + distinct from pickaxe | Pickup and throw both read clearly |
| A1 | Assay panel text readable, no overlaps | Real Label rects measured; hierarchy clear |
| A2 | Assay panel background cleaned | Busy art muted or removed behind the panel |
| G1 | Main path still jump-legal and walkable | No new forced-jump blockers |
| G2 | Set-pieces intact | Timed gate, Fort Knox door, Reserve, boss arena bounds |
| M1 | Multi-model logs present | Kimi + Grok + Qwen + DeepSeek + B.AI (or honest 403) |
| D1 | Gates + Security Sentinel green | No secret leak; non-threaded export intact |

WORK DONE SO FAR (previous sessions + this one):
- S1: melt forges thinned 5->3 and grounded (they floated 105-155px above the
  ground, unreachable); script-built bare brown ColorRect bridge box replaced
  with a real data-driven ground segment. Gated by stage3_clutter_test 7/7.
- S2: big_axe thrown scale 1.55->1.95 (~78px vs base throw ~9px), pickup
  1.15->1.45, own distinct art. Gated.
- A1: Assay labels rebuilt with ~100px vertical bands; gate asserts NO two
  Label rects intersect (measured via real get_minimum_size after outline).
  BUT founder says words are STILL fucked in his latest screenshot.
- A2: NOT DONE — the busy backdrop behind the panel has not been touched.
- B1/B2: a 1.2s boss spawn-grace was added after a real browser capture caught
  the player dying to boss body contact within ~2s of the fight starting (each
  death fully restarts the level, so a chase is never visible). Pursuit code
  itself was NOT retuned. Chase still NOT proven live to the founder.
- D1: Security Sentinel 18/18; script compile 163 scripts/122 scenes PASS.

CRITICAL: the founder rejects "FIXED" claims backed by headless gates or by
prior sessions' claims. Only live, hard-refreshable behaviour counts.

For EACH DoD row: state PASS / FAIL / BLOCKED, the evidence that currently
exists, and the SPECIFIC additional evidence required before the row may be
claimed. Then: name the single biggest risk that this session repeats the
previous sessions' failure (claiming fixed, founder rejects again).
