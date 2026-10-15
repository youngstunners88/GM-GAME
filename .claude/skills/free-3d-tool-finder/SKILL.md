---
name: free-3d-tool-finder
description: Evaluate and adopt free 3D tools (generators, libraries, HDRI/PBR sources, render finishers) for GM-GAME asset work. TRIGGER on "find a 3D tool", "is there a free alternative", "can we use X for assets", any new image-to-3D / text-to-3D / texture / HDRI service, or before spending money or GPU-hours on a 3D route.
---
# Why (founder 2026-10-16)

Every "free AI 3D" tool hides its real price in one of four places: GPU VRAM,
per-generation credits, license redistribution terms, or gated weights. This skill
is the standing evaluation so each new candidate gets the same five-minute audit
before anyone installs, rents, or pays. (Firecrawl is available — founder offered
the API — for deep doc reads when webfetchConversion fails; ask for the key only
then, never prospectively.)

# The audit (all five, every tool, written down)

1. **Local-run fit:** our floor is a 2 GB GeForce 920MX / 7 GB RAM, no torch.
   Needs Apple Silicon / 16 GB+ NVIDIA / ROCm? → cloud-GPU route with costed
   rental, or founder-PC route. CPU-only estimates in hours, not vibes.
2. **Money:** credits per generation, seat/API cost, free-tier caps. Paid tools
   need founder spend approval with estimate FIRST (see `scenario-blender`).
3. **License for a SHIPPED commercial indie game:** Apache-2.0/MIT/CC0 = clear;
   community/custom licenses (Tencent Hunyuan — not EU/UK/SK; Stability; Lightricks
   LTX) = read fully, record per asset, gate shipping on clearance. Gated weights
   (DINOv3 hand-approval, Stability login, HF contact-consent) are lead time.
4. **Godot fit:** GLB + animations out? PBR maps? Transparent PNGs? Headless/CLI
   usable by agents (our Blender work is headless — GUI-only tools don't qualify
   for agent sessions)?
5. **Provenance:** every adopted tool's outputs land in `src/assets/models/<asset>/`
   with source, seed/settings, and license classification.

# Standing roster (re-verify quarterly — tools move fast)

| Tool | Free? | GPU need | Best for us | License note |
|---|---|---|---|---|
| Poly Haven API (HDRIs/textures) | yes, no key | none | lighting + PBR albedo/normal (already in pipeline) | CC0, commercial OK |
| AssetFurnace (image-to-3dlab) | yes (Apache-2.0) | 16 GB+ NVIDIA / Mac → use cloud GPU | rigged animated characters from pictures | weights vary (Hunyuan NOT EU/UK/SK); record per run |
| Scenario Blender plugin | plugin free, generations PAID (CU) | none (cloud) | PBR sets, HDRIs, hard-surface 3D | per-asset terms; needs approval |
| LTX-2.5 Layout-to-Render | weights free/gated | ~24 GB VRAM → cloud GPU | photoreal finish over our clay motion | ltx-2.x-community-license; read before ship |
| Blender procedural (current) | yes | none (CPU renders) | guaranteed-runnable base + all animation | ours, no clearance needed |

# Gate

- New tool gets a 5-line audit (fit, money, license, Godot, provenance) in the
  commit or session notes before install/rent.
- Roster row added/updated in this file with the verdict.
- First asset from any new tool ships only with side-by-side + license note.
