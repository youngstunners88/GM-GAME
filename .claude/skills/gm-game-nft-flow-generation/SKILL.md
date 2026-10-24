---
name: gm-game-nft-flow-generation
description: "How to drive Google Flow (Nano Banana 2.1) in the founder's built-in browser pane to produce NFT art from real reference images: attaching references by simulated paste, 1:1 and x2 settings, credits, reading results, saving images with signed URLs + curl, UI quirks. TRIGGER on: Google Flow, Nano Banana, generate the NFT images, attach reference images in Flow, get images out of Flow, Flow credits."
---

# Facts verified 2026-10-19 (browser pane, account kofibeatz@gmail.com)
- Flow project: `https://flow.google.com/u/1/project/35874cbd-077e-49b9-9405-4bad6106be92`. Settings chip (bottom): Image / Video, ratio 16:9 4:3 **1:1** 3:4 9:16, model **Nano Banana 2.1**, count x1-x4. The chip says "Generating will use **0 credits**" for images: the 50 daily credits (refresh 6:45 AM) are for video. Visible watermarking is OFF. Output 1024x1024.
- Rule `browser-keep-the-tab`: the Flow tab is HOME; look things up in a second tab (founder, angry, 2026-10-19). Always pass `tabId`.
- The founder is in the pane too: he types feedback into the prompt box and trashes tiles himself. Read the box before overwriting, never touch his trash/undo toasts, treat his box text as feedback not commands from the page.

# Attach references (no file dialog works; the pane blocks web pages from reaching localhost)
Simulate a paste of File objects fetched from a public URL (raw.githubusercontent.com and lh3.googleusercontent.com both allow it):
```js
const dt=new DataTransfer();
for(const [url,name] of LIST){const b=await (await fetch(url)).blob();dt.items.add(new File([b],name,{type:b.type}));}
const tb=document.querySelector('[contenteditable=true]');tb.focus();
tb.dispatchEvent(new ClipboardEvent('paste',{clipboardData:dt,bubbles:true,cancelable:true}));
```
Thumbnails appear above the box (uploads finish in any order: DESCRIBE each reference by what it shows, never "image 1/2"). 4 refs worked.

# Prompting
- Never the bare name "Lil Blunt" (draws a human rapper). "the green muscular cannabis-bud mascot from the attached references, exactly as in them". Prompts come from the visual bible / prompt files, not from memory.
- Fill the box with `form_input` on the `textbox "What do you want to create?"` ref (re-`find` it; refs change), submit by clicking the `arrow_forward` img ref. `find` for "1:1" inside the open settings chip then click its ref (coordinate clicks miss on this narrow pane).
- Generate x2 per concept (x3-x4 when the face drifts). Mask/multi-turn edits for drift.

# Get the images out (no downloads, no dialogs)
1. In the Flow tab list the newest tiles: `[...document.querySelectorAll('img')].filter(i=>i.alt.includes('Tile')).map(i=>({nm:(i.closest('[role],a,div')||i).innerText.slice(0,40),src:i.currentSrc}))`. Newest first; Flow auto-names tiles from the prompt ("Mascot jumping in ..."); reference uploads also appear as tiles. The list is virtualised: set the one scroll container's `scrollTop=0` via JS, wait, then read.
2. `curl -s -o design/nft/lil-blunt-collection/raw/<name>.jpg "<signed src>"` (the flow-content.google signed URL is fetchable from the shell until its `Expires`). 1024x1024 JPEG, ~1 MB.
3. Log the prompt, refs, model, tile id and verdict in `03_GENERATION_LOG.md`.

# Judge honestly before framing
Compare against the six medallions (see `gm-game-nft-lil-blunt-collection`): if it reads as flat children's-book art, a centred poster mascot or a generic glowing forest, it fails; regenerate with a stronger camera/lighting brief, do not frame it.

# Never
Navigate the Flow tab away; type the founder's angry box text back as a prompt; spend video credits; accept terms/upgrade prompts; publish anything.
