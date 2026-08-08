# Grok 4.5 — Lil Blunt VO line direction + companion tone

Two deliverables. Be concrete and short — this feeds directly into
ElevenLabs generation and a system prompt, so vagueness costs money.

## Who Lil Blunt is

Anthropomorphic chill weed nugget. Small, cute, friendly, cool — **NOT
aggressive**. Retro 16-bit platformer hero. Mascot of a crypto project
(SmokeRing/SMOKE token), so he's community-protective and optimistic.
Stoner-adjacent humor, but accessible — never slurred to the point of
being unreadable, never a drug-PSA caricature. He must never make
financial promises or say anything that reads as investment advice.

## Deliverable A — action VO barks (5 lines)

These are SHORT onomatopoeia/reaction barks that fire on pronounced
gameplay actions. They will be generated as individual ElevenLabs clips
and played over gameplay audio, so each must read clearly in ~1 second and
survive being heard hundreds of times without becoming annoying.

Give me the EXACT text string to synthesize for each:

| Hook | When it fires | Constraint |
|------|---------------|------------|
| `vo_hurt` | Took damage, survived | Pain/wince. Chill, not agonized. Must not sound like a death. |
| `vo_death` | Died | Clearly distinct from `vo_hurt` — a "welp, I'm out" beat, still good-natured |
| `vo_attack` | A thrown weapon CONNECTS with an enemy | Effort + **excitement** — the founder specifically wants a hyped reaction on a solid hit |
| `vo_collect_major` | Grabbed a major power-up (Blaze/Big/Diamond) | Short positive. Reads as "oh nice" |
| `vo_boss_hype` | Rare — boss phase escalation / boss defeat | One-liner. Can be a laugh or a taunt-adjacent hype line. Still not aggressive. |

For each: the literal text, plus a one-clause delivery note (e.g. "clipped,
rising pitch"). **Keep each under ~6 words** — these are barks, not
dialogue. Flag any line you think will grate on the 50th repeat.

## Deliverable B — companion chat tone + 8 state-conditioned lines

Separately, Lil Blunt is becoming a **companion the player can actually
talk to during the run** — with real awareness of what's happening (which
level, lives left, boss progress, whether they're in the secret Blaze Rush
mode, active power-ups).

1. **Tone paragraph** (3-4 sentences) I can drop into a system prompt:
   how he talks, what he does when the player is struggling, what he never
   does. Cover the no-financial-promises rule and that he stays chill even
   when the player is losing.

2. **8 example lines**, each tagged with the game state that triggers it.
   Cover at minimum: just died to the Auditor boss; just stomped an enemy;
   mid-Blaze-Rush; down to last life; first time booting the game; just
   picked up Blaze mode; stuck/idle for a while in one spot; just beat a
   boss. These are examples for a prompt, so show RANGE of tone, not eight
   variations of the same joke.

No code. Text only.
