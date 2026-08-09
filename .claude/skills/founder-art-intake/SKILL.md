---
name: founder-art-intake
description: Recover reference images the founder pastes inline into chat when they do not appear as files anywhere on the container filesystem. Extracts the base64 image data straight from this session's own JSONL transcript instead of declaring the art "never arrived." Run the moment a prompt references image1/image2/etc. or attached art and a normal disk search comes up empty — BEFORE telling the founder anything is blocked on missing files.
user-invocable: true
allowed-tools: Bash, Read, Write, Edit
---

# Founder Art Intake — pasted images live in the transcript, not the filesystem

**Three separate sessions told the founder his reference images "never
reached the container," asked him to resend them, and shipped nothing when he
resent the exact same way.** All three times the images were sitting in this
session's own JSONL transcript file, in plain base64, the entire time. This
skill is that fix, made permanent.

## Why the old diagnosis was wrong

A pasted/attached image renders into the conversation as a vision input block
— the model genuinely sees it — but this container's harness does **not**
also materialize it as a file under `/root/.claude/uploads/` or anywhere else
on disk unless the client's attach-as-file flow was used (that path DOES
land, e.g. `.md` prompt docs, `.mp3` audio). Searching the filesystem and
finding nothing is real, but "the file search came up empty" was
misdiagnosed as "the image never arrived," when the correct read is "the
image only exists in the conversation, and there is a second, size-effectively
-unlimited place conversation content lives: this session's own transcript."

## The fix: extract straight from the transcript

Every message this session has sent or received — including full base64
image payloads — is durably logged in
`/root/.claude/projects/<escaped-cwd>/<session-id>.jsonl`. The escaped-cwd
segment replaces `/` with `-` (e.g. `/home/user/GM-GAME` →
`-home-user-GM-GAME`). The session id matches the uploads directory name
under `/root/.claude/uploads/` if any `.md`/file attachments arrived this
session — reuse that id, or list `/root/.claude/projects/*/` and pick the
most recently modified `.jsonl`.

### Step 1 — confirm the images are actually only-in-transcript

Do the disk search first, but budget 2 minutes for it, not 20 — this skill
exists so the failure mode is recognized fast, not re-investigated fully:

```bash
find /root/.claude/uploads -newermt "-30 minutes" -type f 2>/dev/null
find / -newermt "-30 minutes" -type f \( -iname "*.png" -o -iname "*.jpg" \
  -o -iname "*.jpeg" -o -iname "*.webp" \) 2>/dev/null \
  | grep -viE "scratchpad|godot-cache|/web/|\.import|node_modules|src/assets"
```

If both come back empty and the prompt clearly references image content,
stop searching disk and move to Step 2 immediately.

### Step 2 — locate the transcript and enumerate image blocks

```bash
find /root/.claude/projects -iname "*<session-id-fragment>*"
```

Then, without ever printing raw base64 to the terminal (it is enormous and
useless as text — always go straight to decoding), enumerate what is there:

```python
import json
path = "/root/.claude/projects/<escaped-cwd>/<session-id>.jsonl"
hits = []
with open(path) as f:
    for lineno, line in enumerate(f):
        if '"media_type":"image' not in line and '"media_type": "image' not in line:
            continue
        hits.append((lineno, json.loads(line)))
for lineno, obj in hits[-8:]:
    content = obj.get("message", {}).get("content")
    kinds = []
    if isinstance(content, list):
        for c in content:
            if isinstance(c, dict) and c.get("type") == "image":
                src = c.get("source", {})
                kinds.append(("image", src.get("media_type"), len(src.get("data", ""))))
    print(lineno, obj.get("message", {}).get("role"), obj.get("timestamp"), kinds)
```

Match the line to the message you need by timestamp and image count/order —
the founder's message describing "4 images" should show 4 `image` entries on
one line at the right time.

### Step 3 — decode to real files

```python
import json, base64
with open(path) as f:
    for lineno, line in enumerate(f):
        if lineno != TARGET_LINE:
            continue
        content = json.loads(line)["message"]["content"]
        i = 0
        for c in content:
            if isinstance(c, dict) and c.get("type") == "image":
                data = base64.b64decode(c["source"]["data"])
                ext = c["source"]["media_type"].split("/")[-1]
                open(f"{outdir}/raw_{i}.{ext}", "wb").write(data)
                i += 1
```

### Step 4 — verify before it goes anywhere near the repo

Read every extracted file back with the `Read` tool and visually confirm it
is a pixel match for what the founder described/showed inline — do not
assume decode success means content correctness. Check dimensions with PIL
against what the inline render looked like (aspect ratio is a fast sanity
check).

### Step 5 — process for engine use, same as any other founder asset

- **Full-bleed banner/backdrop art** (has its own painted background): save
  straight through as PNG, no keying needed.
- **Logo lockups on a plain white studio background**: key the white to
  alpha with a **corner-flood-fill**, not a global white color-key. A global
  key eats into legitimate white highlights *inside* the artwork (a bright
  facet, a metallic letter edge); flood-filling outward from the four image
  corners across connected near-white pixels only removes the background
  because the artwork's outline encloses and disconnects any internal
  whites from the corner region. `scripts/keyout-founder-art.py` in this
  repo implements this — reuse it rather than re-deriving the algorithm.
- Run `python3 scripts/check-sprite-alpha.py` after keying any cut-out art.

### Step 6 — prove it renders, not just that the file exists

`ResourceLoader.exists()` passing is not the same claim as the art being
visible in the game — a founder has explicitly called this distinction out
before ("wired but not visible" is not "fixed"). Instantiate the real scene
in a Godot headless test, read back the **actual assigned
`Texture2D.resource_path`** on the live node, and assert it matches the new
asset's filename — not merely that some non-null texture is set (the old
fallback art would also satisfy that). See
`tests/founder_critical_probe_test.gd`'s
`_test_founder_art_drop_ins_actually_render()` for the pattern: instantiate,
read back `sprite.texture.resource_path`, assert on the exact filename.

If a full real-browser proof is warranted (a founder has rejected a
scene-tree-only claim before), export locally with the exact preset CI uses
(`.github/workflows/export-game.yml`'s "Create export preset" step — copy it
verbatim into a throwaway `export_presets.cfg`, which is already
`.gitignore`d), serve it, and drive it with Playwright
(`/opt/pw-browsers/chromium`, needs `node_modules/playwright` symlinked from
`/opt/node22/lib/node_modules/playwright` since ESM `import` resolution
requires an ancestor `node_modules` directory — `NODE_PATH` alone does not
satisfy it). Clean up the scratch export directory and the symlink
afterward; `rm -rf` is blocked by this environment's permission policy, so
either use non-recursive removal the policy allows or simply leave untracked
scratch files in place and stage commits explicitly by path rather than
`git add -A`.

## When to reach for this

- A prompt names `image1`/`image2`/... or otherwise clearly describes
  attached reference art, and a disk search for recent image files comes up
  empty.
- A founder has *just* pasted images in the same turn you are reading —
  check the transcript's last few lines immediately, before writing any
  message claiming the art "didn't arrive."
- A previous session in this same project already claimed art was missing
  for a task that is still open — re-check the transcript before repeating
  that claim a second time.

## What this does NOT fix

This does not help with images referenced only by a path that was never
actually attached to any message (e.g. `artifacts/founder-art/references/`
in a prompt where no such directory or upload exists anywhere, including in
transcript image blocks). If the transcript enumeration in Step 2 finds zero
image blocks for the relevant message, the art genuinely was not sent this
turn, and asking the founder to resend — ideally via a real client
attachment, since that lands on disk directly and needs none of this — is
the correct next step, not a failure of this skill.
