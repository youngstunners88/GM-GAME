# Asset Handoff — what the game is still waiting on

**Last updated:** 2026-07-29 (later same day)

This is the single list of art/media the game has integration points built
for but no actual file. Every path below is already wired: drop a real file
at the exact path and it appears on the next boot with **zero code changes**.

---

## Status at a glance

| Asset | Path the game reads | Status |
|---|---|---|
| Smoke Lounge music | `src/assets/music/smoke_lounge.mp3` | ✅ **DELIVERED** (SL.mp3, 2026-07-29) |
| Founder portrait | `src/assets/art/founder_portrait.png` | ⛔ not received as a file |
| SmokeRing logo | `src/assets/logos/smokering.png` | ⛔ not received |
| DIAMONDS logo | `src/assets/logos/diamonds.png` | ⛔ not received |
| GoldMine logo | `src/assets/logos/goldmine.png` | ⛔ not received |
| Blaze Rush art (9 images) | *unassigned* | ⛔ not received (PDF attachment rendered blank — see below) |
| Smoke Lounge video loop | `src/assets/shaders/smoke_lounge_ambient.gdshader` | 🔀 **shader alternative built instead** — the supplied footage was rejected, see below |

---

## Why the Google Drive folder didn't work

I can't open Drive links — no browser session, no Google auth, and the
sandbox has no route to fetch a private Drive folder. This isn't a
permissions problem you can fix by sharing the link more widely; I have no
mechanism to read Drive at all.

**What works instead:** attach the files directly to a chat message, the
same way SL.mp3 arrived. That upload landed at a real path I could read and
copy into the repo — which is exactly why the music shipped this session
and the images didn't.

Zip is fine for a batch. 13 images in one zip is one upload.

## Why the founder portrait didn't work either

The profile picture came through as an **image pasted into the
conversation**, not as an uploaded file. I can look at an image in chat, but
I can't write it to disk — there's no path on the filesystem for it, so
there's nothing to copy into `src/assets/art/`.

Attach it as a file (`.png`/`.jpg`) and it drops straight into the mural
slot.

**One judgement call worth your input:** the picture shown is a personal
beach photo. The slot it would fill is a large, glowing "holographic mural"
on the back wall of the Smoke Lounge, rendered at roughly 190×95px in-game.
A tightly-cropped headshot or a branded/logo treatment will read far better
at that size than a full-body shot, which will be mostly unrecognisable.
You also said you weren't sure the founder mural is necessary at all —
that's a fair instinct, and leaving it as a styled placeholder (or swapping
it for a fourth protocol logo) is a perfectly good outcome. Your call.

## Why the Blaze Rush art PDF didn't work

The file arrived and opened fine — it's just a genuinely blank page. No
images, no text, nothing to extract. Same underlying pattern as the Drive
link and the pasted portrait: whatever attached it didn't actually carry the
image content into the file. A zip of the 9 images works the same way SL.mp3
did — direct attachment, not a PDF wrapper.

---

## The video — format is solved now; the supplied footage was rejected on content

Update, same day: the format blocker below is **no longer real** — I found a
working ffmpeg build (`ffmpeg-static` via npm, no system install needed) and
converted the supplied video end-to-end, then actually looked at the output
frames before wiring anything in.

**I didn't ship it.** The footage shows sexualized women in skimpy outfits
smoking/serving alongside a muscular, aggressive-looking mascot mid-hit on a
giant blunt with bongs in frame. That conflicts directly with two things
already written down for this project: no aggressive or stereotypical drug
imagery, and Lil Blunt stays chill/cute/**not aggressive**. It also isn't
Lil Blunt's actual design at all. I deleted the converted `.ogv` rather than
leave it in the repo. If different footage comes in that's actually
consistent with the brand, converting it is now a solved problem (see the
original format note below, still accurate on the technical side) — the
open question was never the format.

**What shipped instead**: `src/assets/shaders/smoke_lounge_ambient.gdshader`,
a procedural drifting-smoke + slow-color-breathe background wired into
`secret_realm.gd` behind the existing painted parallax. Zero file size,
zero video-decode cost, no content risk — same "living backdrop" job a video
was meant to do.

### Original format note (technical detail still accurate)

Godot 4.3 plays exactly one video format, confirmed by querying the running
engine rather than going from memory:

```
ResourceLoader.get_recognized_extensions_for_type("VideoStream")
  -> ["ogv", "tres", "res"]
```

Not MP4, not MOV, not WebM, not GIF. The conversion command, now proven to
work in this sandbox via `ffmpeg-static`:

```bash
ffmpeg -i your_video.mp4 -c:v libtheora -q:v 6 -an -vf "scale=640:-2" output.ogv
```

`-an` strips the source audio (SL.mp3 is the soundtrack; two audio sources
would fight). Theora decode on HTML5 is still a real CPU cost worth weighing
against the shader alternative above, which has none.

---

## Exact specs for the remaining images

Drop them at these paths (create the directories; they don't exist yet):

| File | Path | Recommended size | Notes |
|---|---|---|---|
| Founder portrait | `src/assets/art/founder_portrait.png` | ~380×190 (2:1) | Renders ~190×95. Transparent PNG ideal. |
| SmokeRing logo | `src/assets/logos/smokering.png` | ~180×140 | Renders ~90×70 on a neon sign. |
| DIAMONDS logo | `src/assets/logos/diamonds.png` | ~180×140 | Same slot size as above. |
| GoldMine logo | `src/assets/logos/goldmine.png` | ~180×140 | Same slot size as above. |

The three logos share one slot size, so give them **consistent proportions**
or one will look oversized next to the others.

For the 9 Blaze Rush images I need to see them before assigning slots — I
don't know yet whether they're backgrounds, obstacle art, or decorative
elements, and guessing would produce exactly the stretched/wrong-layer
result the brief warns against.

---

## Size budget reality check

The `art_integration.md` brief set a "<20MB HTML5 export" rule. The current
export is **~94MB** (60MB `index.pck` + 34MB `index.wasm`) and has been well
over 20MB for many sessions. Breakdown:

- **34MB** — the Godot engine wasm itself. Irreducible without a custom
  engine build.
- **~35MB** — music and voice assets (`level01_theme.ogg` alone is 3.2MB;
  `lil_blunt_theme.mp3` is 4.2MB).
- Remainder — backgrounds and sprites.

So "<20MB" is not reachable by compressing incoming art; it would take
re-encoding the existing music library at a lower bitrate, which is a real
decision with an audio-quality cost and is **your call, not mine to make
unilaterally** — especially now that some of that music is yours. Flagging
it rather than silently failing the check or quietly re-encoding your
tracks. (Re-encoding itself is technically possible now — a working ffmpeg
was found this session — but the quality trade-off decision is still yours.)

For itch.io HTML5 this size loads fine on desktop broadband; the cost is
first-load time on mobile data.
