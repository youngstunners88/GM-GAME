# Founder vault logo sources

- GOLD MINE: https://drive.google.com/file/d/1j0LkQuoVdZBEti6rq8ItWdnjfmcjaYhi/view — Gold Logo.png, 1024 × 1024 RGBA. Runtime resource: src/assets/logos/vault/goldmine.png.
- DIAMONDS: https://drive.google.com/file/d/1ffcc1IqTbCooqVODU4k2pUfvkS6LiGG8/view — supplied background-removed PNG, 640 × 640 RGBA, 283,617 fully transparent pixels. Runtime resource: src/assets/logos/vault/diamonds.png.

The two source PNGs are exact copies of the supplied Drive files. Godot imports them at a 256 px limit with quality 0.9 texture compression; the native alpha channel is retained. Sprite regions ignore empty transparent padding when sizing the 96 px-high signs. No logo was redrawn or generated.

Each vault has three complete groups: logo, exact protocol URL, matching logo. All sit on the existing floor band with 24 px room-edge clearance and the existing 48 px outlined URL font. The final group fits entirely before the room boundary. Old lounge assets, staking, dialogue, controls and music are preserved.
