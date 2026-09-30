# 013 — Jev + vision assessment of the current look (2026-09-30)

Founder: "get Jev to help us assess what we need to improve the aesthetics and the skills we can build for this."
Method (per CLAUDE.md role split): DeepSeek V4.1 Flash LOOKED at a real capture next to the founder's target
(`scripts/ref_compare.py --grade`, $0.002); Jev (text-only) PRIORITISED from those findings ($0.00002). Both are leads;
Claude verified against the capture and changed code.

## DeepSeek's grade (unverified lead)
Hero partial (small, back-on) - gold revolver not discernible from behind - pickaxe PASS - rails dark/flat, no shine or bolts -
crystals flat floating shards, lanterns look unlit - overall muddy brown. (It also failed coins and bears because neither was in that frame.)

## Jev probabilities ("is X a major aesthetic gap?")
| Item | p | Verdict | Action taken |
|---|---|---|---|
| Lanterns look unlit | 0.91 | yes | lantern props self-lit warm (`_self_light` 1.1) |
| Gold revolver reads poorly from behind | 0.88 | yes | metallic map dropped (black in web GL), albedo lifted, hero turned 3/4 toward the gun side |
| Rails dull | 0.81 | yes | bright steel line on each rail head + brass bolts on every second sleeper |
| Hero too small in frame | 0.78 | uncertain | open |
| Fog hurting depth | 0.78 | uncertain | open |
| Flat crystal shards | 0.74 | uncertain | open (crystal embedding = Opus task) |
| Soft blurry rock | 0.67 | uncertain | open (Meshy retexture) |
| Muddy lighting overall | 0.45 | uncertain | hero key light + brighter hero; global left alone |

## Skills this produced
`ep2-bear-design` (new), `ep2-voice-barks` (vocabulary now 160+, bear death/attack sounds), `ep2-runner-camera-light`
(light inventory and VFX table stay the reference). Still worth building: a crystal-embedding skill (emitters seated in rock),
a rock-retexture skill (Meshy retexture within the pack budget).
