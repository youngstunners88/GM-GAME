# Logan's Lake: woodland and working skiff

Founder request2026-10-27: improve the cheap-looking lake and trees, and give Logan a little boat he actually uses. The active lake narrative lock remains in force.

The lake now has a continuous recessed basin and wandering outflow, textured forest-floor banks, fir groves with rooted crooked trunks/woody boughs/needle sprays, ferns, rushes, granite and fallen timber. Lake-only calm-water and wind materials work in Godot4.3 Compatibility. Trees share geometry through MultiMesh. No other world's art is changed.

Meshy's open cedar hull is normalized to3.4×1.25×0.60m and reduced from1.306million to23,983 hull triangles. Local authored seat, footrest, independent oars/oarlocks and rigid contacts make it usable. An18-section waterline profile cuts the moving water surface only inside the actual hull. Local sources are in `sources/`; builders are in `tools/ep2_lake/`. To regenerate the derivative, retrieve the source from the task IDs in `PROVENANCE.json` and pass sourceGLB/outputGLB/blend paths to `prepare_skiff.py`; no provider rerun is required.

Actual Meshy spend: **30 credits** (preview20 + textured refine10), balance572→542. No paid retries, rigging charge or animation charge. Logan's supplied GLB,65-bone skin and Idle/Greet/Point/Approve clips remain unchanged. His rest-aware local skeleton solve walks to the dock, boards, then rows a sheltered circuit after the existing cargo handoff has finished. Independent palm, pelvis, boot and oar-blade checks run across two whole strokes; limbs retain their authored lengths. Mooring, wake, pause and retry follow the routine state.

Existing arrival, investigation, one touch staging action, high overlook, inventory/ammunition and access/title contracts remain. This adds no fishing, rewards or later river combat.

## Verification

- Pinned Blender4.3.2: both normalized hull and forest semantic mesh QA pass, no errors. Reports in `verification/`. Remaining warnings are intentional stacked foliage atlas UVs/seams; six hidden opposite hull face pairs; buoyant hull beloworigin. Zero wire/non-manifold hull geometry after local cleanup. Documented Blender5.2.2 and Game Development Studio `game-dev` are unavailable here; actual local tooling is recorded in provenance.
- Pinned Godot4.3: lake story route and new23-check art/contact test pass. Whole-cycle independent palm error≤0.000006m, pelvis≤0.000002m, boots≤0.000003m and limb-length drift≤0.000003m; blades enter water on power and clear it on recovery. These numerical contact results accompany real Compatibility pose captures, not a substitute for them.
- Player-camera arrival, Logan, investigation, staging, handoff and overlook plus boarding and eight stroke phases inspected. Original founder reference: `../references/Logan.JPG`.
- Front-page lock5 files and Security Sentinel pass; no production harness bypass added.
- Full regression, exact web export/isolated resources and public release evidence are recorded in `RELEASE.md` once complete. Public browser boot/access-gate checks and native replay of downloaded public packs are distinct evidence.
