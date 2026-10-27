# Logan's Lake — founder aesthetic rebuild, 2026-10-27

Request: improve the cheap-looking overall environment and trees; give Logan a small boat he uses. Meshy boat generation is authorized. Preserve the active2026-10-18 narrative lock and supplied character. No fish/financial gameplay or other-world changes.

Reference: `../references/Logan.JPG` (founder wooded bank, weathered dock and small rowing skiff); original player-camera baseline captured under `/workspace/work/lake-rebuild/before/`. Baseline defects: flat exposed ground, coarse geometric basin, oversized striping in water, very regular sparse conifers, bare dock and no boat.

Design: warm cedar and brass against cool shaded green water; irregular rooted shore, leaf litter, rushes/ferns and granite; mature crooked firs, woody boughs and small crossed needle sprays with height/rotation variation; layered forest groves and a winding outflow. Keep arrival→Logan→one staging action→overlook walkable and signs readable. Frame the dock/boat from arrival and close views, keep outflow visible from high ground.

Performance/pack: lake-only materials and shaders; new art streams through existing extras. Share forest meshes/materials via MultiMesh; existing founder texture atlas, bark/normal and fern images reused. Bounded actual-tree silhouettes in Compatibility water; no SSR/Forward+ dependency. Unchanged190MiB per-file gate, nonthreaded Godot4.3 web export.

Boat: one Meshy preview20+texture10, no paid reruns planned. Separate UV-preserving runtime derivative at3.4m length/1.25m beam, a truly open hull, fitted row seat and footrest, independent rigid oars/oarlocks, hand-grip and blade markers. Boat is moored during existing dialogue. After cargo handoff dialogue, Logan walks down the dock, boards and rows a short sheltered circuit. Original65-bone Logan GLB and four gestures remain unchanged; rest-aware runtime skeletal solves drive walking, supported seating, fingers and two independent palm/oar contacts. Mooring and wake follow actual routine state. Pause/retry must freeze/reset the routine.

Verification before release: compare the same six player views; close-ups and whole rowing stroke, palms vs independent oar sockets, seat/feet, blade power/recovery contact, boarding and reset; meaningful native tests plus current town-chain regression; real web export and isolated packed resources; front-page/security gates; preserve concurrent master and verify production CI/butler/public BUILD and exact public encounter.
