# Protocol logos — drop-in slots (no code change needed)

`secret_realm.gd::_setup_protocol_signs()` calls `_swap_placeholder_texture()`
for each sign. The moment a file exists at the exact path below, the drawn
placeholder is hidden and the real logo renders in its place. Nothing else to
edit, no rebuild step beyond the normal export.

| Drop the file here | Which sign it replaces | Founder-supplied art |
|---|---|---|
| `src/assets/logos/smokering.png` | SMOKERING | the Lil Blunt / FOMO rocket roundel |
| `src/assets/logos/diamonds.png`  | DIAMONDS  | the DIAMONDS roundel |
| `src/assets/logos/goldmine.png`  | GOLDMINE  | the GOLD MINE pickaxe crest |

Filenames are `sign_names[i].to_lower() + ".png"` — they must be exactly
lowercase, no spaces, `.png`.

## Founder mural

| Drop the file here | Where it appears |
|---|---|
| `src/assets/art/founder_portrait.png` | the Founder Mural Ledge in the Smoke Lounge (`_setup_founder_mural()`) |

## Format notes

- PNG with transparency is fine; the signs are ~90x70 and the mural is a wide
  mat, and both use `STRETCH_SCALE` + `EXPAND_IGNORE_SIZE`, so source art is
  scaled to fit rather than cropped. Square roundels will letterbox slightly
  on the wide mural — a landscape crop reads better there.
- A soft smoke-haze overlay is drawn on top by `_swap_placeholder_texture()`,
  so very dark art loses contrast. The supplied roundels (bright logo on dark
  disc) sit well against it.
