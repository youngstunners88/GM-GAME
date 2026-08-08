# Kimi K3 audit — title/UI font sizes + theme overrides (findings-first)

Godot 4.3 project (Lil Blunt Adventure), HTML5 web export, base resolution
1280x720 with `stretch/mode=canvas_items`, `aspect=expand` (so UI scales to
the physical screen — on a phone everything shrinks). The founder reports
titles and early UI text are **too small to read on a phone at arm's
length**. Audit the font sizes and theme overrides across the boot / main
menu / first-run flow.

**Findings first**, each as: file:line — the element — current size — is it
too small for phone/arm's-length (yes/no + why) — recommended size. No
preamble. Be exhaustive: list EVERY user-facing text size you can find in the
dumped files, including ones set in code (`add_theme_font_size_override`,
`custom_minimum_size`) not just in the .tscn.

## Specifically
1. Main menu: title, subtitle, primary buttons (PLAY/CONTINUE/QUIT),
   secondary button column (font 20, 300x46). Note the title text is set
   BOTH in the .tscn (48) and overwritten in `_ready()` to a two-line
   string — flag any redundancy/conflict between TitleLabel and SubtitleLabel.
2. First-run email signup panel and crypto onboarding panel — text sizes,
   and whether button/tap targets are big enough for a thumb (min ~44px).
3. Any place a fixed pixel `position`/`size` (not anchors) would push text or
   buttons off-screen or into a corner on a narrow phone viewport.
4. Contrast: any near-white text placed directly over busy art with no
   shadow/outline/plate.

Do NOT propose a full redesign — just enumerate the sizes and the specific
minimal bumps. I will implement.

## Files

@include src/ui/main_menu.tscn
@include src/ui/main_menu.gd
@include src/ui/hud.tscn
@include src/ui/hud.gd
@include src/ui/email_signup_panel.tscn
@include src/ui/crypto_onboarding.gd
