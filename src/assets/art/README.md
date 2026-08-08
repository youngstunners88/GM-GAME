# Founder mural art — drop-in slot

Drop the founder portrait at:

    src/assets/art/founder_portrait.png

`secret_realm.gd::_setup_founder_mural()` already calls
`_swap_placeholder_texture()` against that exact path — the moment the file
exists, the drawn placeholder mat is replaced by the real art. No code change.

A landscape crop reads best (the mural mat is wide); a square image will
letterbox. A soft smoke-haze overlay is drawn over the top, so avoid very
dark, low-contrast source art.
