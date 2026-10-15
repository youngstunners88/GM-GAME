# Source-only files (not shipped)

Files here are build inputs for Blender (HDRIs, reference stills, Poly Haven textures). This folder has a `.gdignore`,
so Godot never imports them and they never reach `index.pck` (CI gate: 190 MB). Put new source-only art here, never next
to the runtime GLBs. The 2K studio HDRI alone cost 8 MB of pack when it sat in `goldmine_train/`.
