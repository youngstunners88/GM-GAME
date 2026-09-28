# Shot list — Drop 001 (Bong-Party Teaser) — v2

State: **RENDERED, awaiting founder review**
Format: format-hype-30s (adapted) · 9:16 · anime/comic-book style ·
still (nano-banana-pro-edit) → animate (Seedance 2 image-to-video) ·
**no on-screen text anywhere** (founder: "I don't want text!!!!")
Hero window: 9.0–19.0s

> v2 is a full rebuild after founder rejection of v1. v1 ignored the real
> Lil Blunt reference art (generated a generic character from imagination),
> dropped the "moving to Solana" premise, had no people at the party, and
> tried to render on-screen text inside the video model (looked cheap/garbled).
> v2 fixes all four: generated on-model anime-style stills conditioned on the
> real founder-supplied reference art, animated those stills (character
> fidelity locked from frame one), a packed party with human partygoers
> including a woman excited to be there, and **zero text anywhere in the
> video** — the message lives in the post caption, not burned into the footage.

## Pipeline (2 stages, not 1)
1. **Still generation** — `nano-banana-pro-edit` (MuAPI), reference images from
   `../assets/` (real founder art) via `images_list` + `@image1`/`@image2`
   tags. See `v2_still-01-rocket.json`, `v2_still-02-party.json`,
   `v2_still-03-payoff.json`.
2. **Animation** — `seedance-2-image-to-video-fast` (MuAPI, Seedance 2 family),
   each still as the start frame. See `v2_clip-A/B/C_seedance2-i2v.json`.

## Clips

| Clip | Time | Still source | Scene | In hero window? |
|---|---|---|---|---|
| A | 0.0–8.0s | rocket still | Lil Blunt rides his branded rocket through space toward the glowing Solana mark — the "moving to Solana" journey | No |
| B | 8.0–20.0s | party still | Arrival at a packed neon bong-party lounge on Solana; a lavender-haired anime woman excitedly at his side; a crowd of human partygoers dancing behind them; purple double-chamber bong in hand | **Yes — fully** (9.0–19.0s) |
| C | 20.0–30.3s | payoff still (+3s padded hold) | Surrounded by the cheering crowd, presents a glowing wrapped-leaf NFT card (iconographic, no text on the card itself) | No |

## On-model lock (from `ref-03-smoke-solana.png` + `ref-01-fomo-rocket.jpg`)
Muscular green cannabis-leaf character, spiky leaf mohawk, round googly
freckled eyes, wide grin, cigar with visible smoke (never a joint/bong
mouthpiece), mirrored sunglasses, red bandana, open black leather jacket with
gold leaf embroidery, thick gold chains with a Solana "S" pendant, gold rings,
purple double-chamber bong loaded with visible bud. Rockstar/gangster swagger,
not a soft mascot.

## Must-not
- No text, captions, words, or logos other than Lil Blunt's own branding and
  the Solana mark, rendered anywhere in any frame.
- No APY/MC/TVL/price/"guaranteed SOL" — the payoff card is purely
  iconographic (a wrapped leaf), no reward numbers implied.
- No real, identifiable people; the party crowd and the woman character are
  original stylized anime figures.
