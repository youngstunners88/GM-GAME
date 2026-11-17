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

**Status 2026-11-17: all seven built with the Tripo API (505 -> 40 credits).** The game-ready files are in `built/` (a `.gdignore`
keeps Godot out of it). They are not in the game: the streamed pack has no room (see STATUS). To install one, copy `<name>.glb` to
`src/episode2/extras/people/`, import, then copy the settings from `<name>.glb.import.txt` (no LODs / shadow meshes, animation
compression) and `texture.import.txt` (lossy 0.72) over the generated `.import` files, re-import and `git add -f` the `.import` files.
Task ids: `manifest.json`. Rebuild steps: `tools/tripo/auction_cast_batch.py`, then prep_folk / export_folk / gltfpack_safe /
shrink_glb (`--max 1024`), then `tools/tripo/install_person.py`.
