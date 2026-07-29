# Asset Handoff — what the game is still waiting on

**Last updated:** 2026-07-29

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
| Blaze Rush art (9 images) | *unassigned* | ⛔ not received |
| Smoke Lounge video loop | *not built* — see below | ⛔ not received, **format blocker** |

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

---

## The video — there is a real format blocker

You asked for a video looping in the background of a Smoke Lounge (maybe
stage 2) while the song loops. Before building anything I checked what the
engine actually accepts, by querying the running engine rather than going
from memory:

```
ResourceLoader.get_recognized_extensions_for_type("VideoStream")
  -> ["ogv", "tres", "res"]
```

**Godot 4.3 plays exactly one video format: Ogg Theora (`.ogv`).** Not MP4,
not MOV, not WebM, not GIF. Whatever is in the Drive folder is almost
certainly MP4 or MOV, and it will not load as-is.

Two further things you should know before committing to this:

1. **I can't convert it here.** This sandbox has no `ffmpeg`, `sox`, `oggenc`
   or equivalent (checked). So the conversion has to happen on your side, or
   in a session on a machine that has ffmpeg.
2. **Theora on HTML5 is heavy.** The web build is already ~94MB. Video
   decode in the browser export is CPU-bound and is the single most likely
   thing to push the Smoke Lounge below the 45 FPS target on a phone. The
   Smoke Lounge is deliberately the *chill, slow* room, so a dropped frame
   rate there is more forgivable than in Blaze Rush — but it's a real cost.

**If you want to proceed**, the conversion command is:

```bash
ffmpeg -i your_video.mp4 -c:v libtheora -q:v 6 -an -vf "scale=640:-2" smoke_lounge_loop.ogv
```

- `-an` strips the video's audio — important, since SL.mp3 is the soundtrack
  and you don't want two audio sources fighting.
- `scale=640` keeps the file small; the background is behind a hazy overlay
  and doesn't need full resolution.
- Aim for **under 8MB**. Send me the `.ogv` and I'll wire the looping
  background.

**A cheaper alternative worth considering:** the Smoke Lounge already has a
painted parallax backdrop plus drifting smoke particles. Much of the "living
background" feel a video would provide is achievable with an animated
shader or a slow pan on the existing art, at near-zero file size and no
frame-rate risk. If the video is mainly there for atmosphere rather than
specific content, that's likely the better trade. Happy to build either —
tell me which.

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
tracks. (I also can't do it here — no ffmpeg.)

For itch.io HTML5 this size loads fine on desktop broadband; the cost is
first-load time on mobile data.
