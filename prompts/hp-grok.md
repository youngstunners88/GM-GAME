You are Grok 4.5 (`model-grok-stage3-aesthetics`). Founder screenshots (this
session) show:
1. Stage 3's background art (bg_l3_goldrush.jpg) has a Bitcoin coin rendered as
   the SUN — roughly 250px diameter in a 1280x720 painting, dominating the sky
   and reading as an oversized "figure". Founder: "make these figures smaller".
2. The main gameplay HUD (top-left stat list: SCORE 30px, then COINS/RINGS/
   GOLD/DIAMONDS/TITANX/wBTC/XAUT/SMOKE/POWERUP all at 26px with 4-5px black
   outline, ~10 lines stacked) now consumes roughly half the 720px viewport
   height. Same founder circle, same "make these figures smaller" caption —
   he's circling the STAT TEXT BLOCK, not a sprite.
3. A solid opaque black ColorRect (400x120) sits behind ONLY the top SCORE+
   lives row on every level, while the rest of the stat list below it has NO
   backing at all and reads fine over the painted stage. Founder: "clear it so
   the background stage is complete".

I'm shrinking the background sun in-place (crop+resize+recomposite, not a full
regen, to avoid style drift) to ~55% of current size, shrinking HUD stat font
sizes (Score 30->22, stat rows 26->18, header 18->13), and removing the black
mask entirely (matching the rest of the list, which already proves outlined
text reads fine with no backing).

1. Is 55% the right target for the sun, or should it go smaller/be de-emphasized
   further (e.g. lower opacity) to read as "sky element" rather than "logo"?
2. Any risk that shrinking the HUD text that far (26->18) hurts readability on
   mobile, given this project's established 24px "hard mobile-web minimum" was
   for the VAULT interior panels specifically, not the main HUD?
3. One-line verdict on removing the black mask entirely (not just lowering its
   alpha) given the rest of the list has zero backing already.
No code, concise.
