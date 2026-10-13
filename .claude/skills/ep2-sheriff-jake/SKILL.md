---
name: ep2-sheriff-jake
description: Sheriff Jake - the founder's identity lock for the GoldMine town's lawman, a tribute to JakeX (TitanX ecosystem founder meme) elevated into a Western sheriff. Who he is, how he must look, how to build/rig him and what he does in the certificate office and the draw. TRIGGER on "sheriff", "Jake", "JakeX", "TitanX", "lawman", "the witness".
---

# Identity (spec section 3, verbatim intent)

Jake (JakeX / TitanX ecosystem tribute). **Cigarette in mouth.** Recognisable as the TitanX founder-meme figure elevated into a Western
lawman. Not a random NPC: he is the on-screen identification of the TitanX ecosystem inside the Gold Mine town.
Reference: `artifacts/episode2-gold-mine/references/founder_2026-10-13_town/sheriff_jake_jakex_identity.jpg`.

Carry over from the reference: the big curly dark-brown hair, round face with big brown eyes and full lips, the cigarette with a curl of
smoke, and the neon-green "jakeX" ransom-letter band (as his hatband). Make him an **adult** lawman (the meme art is a child's face -
never show a child smoking): sheriff's star, wide-brim hat over the curls, waistcoat, gun belt, duster, boots.

# Role in this slice

- Certificate office: present and involved; he DIRECTS Lil Blunt (the certificate path / next step). Certificate rules stay faithful to
  the GoldMine whitepaper (non-transferable claims, share requirements); do not resolve or invent numbers here.
- Bar: he decides to be Lil Blunt's WITNESS - the only reason the draw is formal rather than an ambush.
- Deeper TitanX ties: later. Do not invent lore.

# Build

Concept stills (Muapi GPT Image 2, `ep2-hyperreal-scene-pipeline`) -> image-to-3D (Tripo H3.1 / Meshy via `tools/ep2_forge/muapi_3d.py`)
-> auto-rig to the same 24-bone skeleton family (`ep2-motion-emotion`, `ep2-rest-aware-retargeting`) -> Ep2Actor. The cigarette is a
rigid prop on a head holder (`Ep2Actor.holder("Head")`) with a small smoke particle; never skinned. Voice: his own ElevenLabs voice id
recorded in the manifest note; calm, dry, laconic. Prove with real first-person captures beside the reference (`ep2-reference-match-loop`).
