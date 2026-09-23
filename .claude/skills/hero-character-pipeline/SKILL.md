---
name: hero-character-pipeline
description: Get Lil Blunt from concept to a rigged, Godot-ready GLB. Use when the task is the HERO CHARACTER specifically. Read the honesty section first — this pipeline cannot be completed inside the sandbox, and the skill exists partly to stop anyone reporting that it was.
user-invocable: true
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, WebFetch
---

# Hero Character Pipeline (Lil Blunt 3D)

## The honesty section — read this before anything else

**A primitive-assembly script cannot author this character.** `bpy` in this
sandbox can put boxes, cylinders and icospheres together; Lil Blunt is an
organic, hyper-real, rigged cannabis-bud miner with layered leaf fronds, a
brass helmet, cloth and a face. Those are different problems.

**Nothing in this pipeline is "done" without founder visual sign-off.**
Auto-rigging on non-standard topology — and a leaf-crowned bud head is exactly
that — commonly deforms wrong at the neck and shoulders in ways that look fine
in a T-pose and break the moment the character moves. Headless proof is not
proof here, the same way a green gate was not proof the cameras faced forward.

**What exists today is a PLACEHOLDER, and it must be described that way.**
`src/episode2/assets/lil_blunt_placeholder.glb` is a primitive silhouette —
green bud head, five leaf fronds, brass helmet with a lamp, shoulders clearing
the cart rim. It was built because a fidelity review found the runner had "no
distinct green miner silhouette ... whereas it anchors all three references".
It is a stand-in for the read, not the character. Never call it the hero
character in STATUS.md, a commit message, or a report to the founder.

## What the real path looks like

### Step 1 — generate the mesh (external API, over HTTPS, no GUI)

| Service | Mesh | Auto-rig | Notes |
|---|---|---|---|
| **Meshy** (`api.meshy.ai`) | image/text→3D | **yes**, Mixamo-compatible bone names, returns a rigged GLB | one REST pipeline end to end; the pragmatic first try |
| **Tripo** (`api.tripo3d.ai`) | image/text→3D | **yes** | same shape of workflow |
| **Rodin / Hyper3D** (`hyperhuman.deemos.com`) | highest mesh fidelity | **no** | pair with UniRig |

Feed it the founder references — `artifacts/founder-art/references/ep2_runner_ref_*.jpg`
plus the Episode 1 sprite sheets — never a written description. The written
description is where off-model drift comes from.

**Before any of these will work, the founder must allowlist the host.** This
environment's network policy is Trusted, not Full. Switching it to Custom with a
specific host is an infrastructure setting in the environment dialog at
claude.ai/code that **only the founder can change** — it cannot be fixed from
inside a session. On a DNS or connection error, say plainly which host needs
allowlisting and stop. Do not retry and do not assume Full access.

**The API key goes in the environment's Environment Variables field.** Never
inline in a script, never in a committed file, never echoed to a log. This repo
already lost a full session to pasted keys in the setup script.

### Step 2 — rig, if the generator did not

- **UniRig** (MIT, headless CLI) — handles non-standard topology, which is the
  case that matters here.
- Or a scripted headless Blender **Rigify** pass via `bpy`.

### Step 3 — verify licensing BEFORE shipping

Check commercial-use terms against the actual account tier and write the finding
into `docs/` in the same commit. Known traps from prior research: **Hunyuan3D**
ships under a gated community licence, and **SF3D** carries a $1M-revenue
threshold. Neither is safe to assume.

### Step 4 — import and prove it

```bash
GODOT="$(scripts/bootstrap-godot.sh | tail -1)"
"$GODOT" --headless --import
"$GODOT" --headless res://tests/ep2_glb_pipeline_test.tscn
```

Add the character to `ASSETS` in that gate, and extend it to assert the
**Skeleton3D** and its bone count — a rigged GLB that imports with no skeleton
is the silent failure specific to this path.

Then: real export, real browser capture, `art-direction-fidelity-check`, and
**founder sign-off**. Report the `index.pck` delta in bytes.

## Current status

Probed live on 2026-09-10, not assumed:

| Stage | State |
|---|---|
| Placeholder silhouette in-game | **done** — primitives, browser-verified, explicitly not the hero |
| Network reachability | **NOT a blocker.** All three hosts answer from this sandbox today: `api.meshy.ai` 404 (host up, path empty), `api.tripo3d.ai` 200, `hyperhuman.deemos.com` 301. No allowlisting is needed for these. |
| API credential | **BLOCKED — the only blocker.** `MESHY_API_KEY`, `TRIPO_API_KEY`, `RODIN_API_KEY` and `HYPER3D_API_KEY` are all absent from the session environment (checked by name; values are never read or printed). The founder adds one in the environment's **Environment Variables** field. |
| Generation | not started — needs the credential above |
| Rig | not started |
| Licence check | not started |
| Founder sign-off | not started |

**No AI-generated concept art is needed as an intermediate, and none should be
made.** Meshy and Tripo both accept an input IMAGE, and the founder's own
reference art already shows Lil Blunt from three angles. Generating a
turnaround sheet first would insert an invented interpretation between the
founder's art and the mesh — which is the drift the "never invent art
direction" rule exists to prevent. Feed the references directly.

The one remaining blocker is founder-side and cannot be resolved from a
session. Say so plainly rather than reporting the placeholder as progress
toward a finished character.
