# Auction cast references (founder sheets, 2026-11-16)

Copied from `~/Documents/SmokeRealm-stable-characters-20261024/auction folk/`. Each is one person, T-pose, plain white background.

| Role | Game file (`src/episode2/extras/people/`) | Sheet here | Founder's file name |
|---|---|---|---|
| Checker A, claim wagon clerk | `auction_checker_a.glb` | `checker_a.jpg` | `Certificate man.jpg` |
| Checker B, hall doorman | `auction_checker_b.glb` | `checker_b.jpg` | `Certificate man2.jpg` |
| Band lead, the woman who sings | `auction_band_lead.glb` | `band_lead.jpg` | `Woman_in_period_dress_T-pose_0375a564_2K.jpg` |
| Fiddle | `auction_band_fiddle.glb` | `band_fiddle.jpg` | `Character_sheet_for_1800s_fiddler_b0080eef_2K.jpg` |
| Banjo | `auction_band_guitar.glb` | `band_guitar.jpg` | `Male_musician_T-pose_reference_a54d37c9_2K.jpg` |
| Upright bass | `auction_band_bass.glb` | `band_bass.jpg` | `Man_in_Western_attire_T-pose_15d81a44_2K.jpg` |
| Harmonica | `auction_band_harmonica.glb` | `band_harmonica.jpg` | `Man_in_period_western_attire_8efe7a73_2K.jpg` |

**Status 2026-11-16: no model generated yet, 0 credits spent.** Both credentials are valid. Meshy has 86 credits; the Meshy 401 was
a placeholder in `~/.bashrc` shadowing the real key, now fixed. **Tripo is the primary path: 505 API credits**, and the founder's
Tripo web app is open in Brave with a separate balance. Use the sheets below directly; do not invent or restyle faces.

Tripo API: `python3 tools/ep2_forge/tripo_gen.py balance` then generate, rig (`/animations/rig`), and retarget
(`/animations/retarget`). Meshy remains the fallback for its Talk/Greet clip library. Pack room must be measured before the full
batch: the streamed extras pack has only 67 KB free. The game already looks for the seven files above; checkers swap in on their
own, and the band appears only when all five are present.
