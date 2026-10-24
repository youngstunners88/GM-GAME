---
name: gm-game-nft-drive-delivery
description: "Deliver the finished Lil Blunt NFT set to Google Drive and prepare the Captain presentation board: what works and what does not for getting local images into Drive from this machine. TRIGGER on: put the NFTs in a Google Drive folder, upload to Drive, presentation board for the Captain, share the collection."
---

# Deliverables
1. `board/captain_board.png` (+ a webp): grid of the framed medallions on a dark background with a short caption each, plus `board/captions.md`. Built locally with ImageMagick (`montage`).
2. A Drive folder "Lil Blunt NFT Collection - Captain review" holding `game/`, `community/`, the board and the generation log (`03_GENERATION_LOG.md`).

# What works / does not (verified 2026-10-19)
- Drive MCP `create_folder` = `create_file` with mime `application/vnd.google-apps.folder` (works) and text files via `textContent` (works: log, captions).
- Drive MCP `create_file` with `base64Content` for a 1-2 MB PNG is NOT workable (base64 must be emitted through the model context: ~1M tokens per image).
- Built-in browser pane cannot upload local files: no native file dialog, and web pages (flow/drive) cannot reach `http://127.0.0.1` (blocked at the pane), so the local receiver `tools/nft/flow_receiver.py` only works for non-browser tools.
- Claude-in-Chrome `file_upload` can set a local file on Drive's file input IF the extension is connected (`list_connected_browsers` was empty 2026-10-19): ask the founder to connect it, then use Drive web "New > File upload" input ref.
- `rclone` / Drive-for-desktop are not installed; installing and the OAuth consent are the founder's call.
- Never upload unreleased art to a third-party host (paste/file hosts, public GitHub): it publishes it.
- Fallback = tell the founder the local folder path `design/nft/lil-blunt-collection/outputs` and that one drag of the folder into Drive finishes it; say so plainly instead of claiming it is in Drive.

# Report honestly
Say what is IN CODE / on disk / in Drive. "Placed in Drive" only after the Drive MCP `search_files` (or a Drive screenshot) shows the files.
