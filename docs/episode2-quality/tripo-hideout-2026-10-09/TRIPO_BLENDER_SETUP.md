# Tripo and Blender setup for Episode 2

Prepared 2026-10-09 from official documentation. Not installed or tested on the user's PC in this session.
The execution host is disconnected. The uploaded ZIP has not yet been opened/audited. No credential value was read, changed or copied.

## Two distinct integration paths

| | Studio DCC Bridge (uploaded filename) | API generation add-on |
| --- | --- | --- |
| Purpose | Send models from signed-in Tripo Studio to Blender | Generate models with the Tripo API from Blender |
| Documented version | 1.0.32 | 0.7.3 |
| Documented minimum Blender | 4.1 | 3.0 |
| Access | Tripo Studio Pro, Max or Team; signed-in browser | Tripo API key and separate API billing |
| Sidebar | Tripo Bridge | Tripo 3D |

Official sources: [Blender DCC integration](https://www.tripo3d.ai/integrations/blender), [API plugins](https://developers.tripo3d.ai/en/docs/plugins).
The documentation describes the current official release; verify the uploaded ZIP's own metadata before treating it as the same version.

The former workspace runtime was Blender 4.0.2. If that runtime is restored unchanged, it is below the documented Studio Bridge minimum. It can satisfy the API add-on minimum. This says nothing about the user's PC version, which remains unverified.

## Studio Bridge on the user's PC

1. Check Blender version; use 4.1 or newer for the documented Bridge.
2. After the uploaded ZIP is inspected, in Blender open Edit -> Preferences -> Add-ons -> Install from Disk. Choose the intact ZIP and enable Tripo Bridge.
3. Open the 3D View sidebar with N. Use Chrome, Edge or Opera signed into the appropriate Tripo Studio account.
4. In Tripo Studio enable DCC Bridge, select Blender and wait for Connected before using Send To Blender.
5. Verify a small existing model arrives with geometry and textures, save the Blender project and inspect material assignments.

This Studio path is not configured merely by entering the Tripo API key. A workspace environment key also does not automatically populate a Blender installation on a different computer. No tool in this session exposes control of the user's PC or signed-in Studio connection.

## API add-on when API generation is actually needed

The official API add-on is a separate ZIP linked by the API plugin documentation. Inspect its code before installation. Enable Tripo 3D and configure its API key through the supported private preference flow on the machine that will make the API call.
When configuring the restored workspace, use the already configured credential directly; never print its value, commit it, pass it in shell history, copy it to a browser game client, or store it in the shared .blend.
For the user's PC, use their existing local credential configuration if present. Do not send workspace secrets through chat or export them in a portable setup file.
Never record a preference panel showing a key. Verify with a bounded existing-task/download or account capability check before creating any paid task.

No new paid generation task is required for the supplied bear until the existing GLB and mine archer have been inspected. Reuse/repair first. Any newly metered generation must follow the configured provider's authorization and budget rules.

## From Tripo to a playable game asset

Preserve the original; inspect scale, min-Y, facing, normals, disconnected islands, UVs and material slots.
Repair duplicate/fused hands and weapon pieces in Blender; protect the bow/string/arrow silhouette while reducing geometry.
Bake exportable PBR materials, pack textures, save editable source, export a separate runtime GLB.
Use measured Godot placement constants, not Tripo's default pivot assumptions.
Check actual Compatibility game-camera pixels and pack cost, not only a Tripo viewer or Blender studio render.
Use the existing game export and deployment pipeline. A successful Bridge connection is setup evidence, not proof the game asset is repaired or shipped.
