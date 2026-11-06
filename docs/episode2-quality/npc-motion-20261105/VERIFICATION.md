# Character motion and protected response — work in progress

Source baseline: `0acdb2a55c2ffed1aa3dc9cee2ee854b89822f81`.
User decisions: Minister and Mike Dean both mean existing MinisterMikeDean; Rich uses the supplied `extras/armory/showcase/sharps.glb`.

Implemented locally: bounded rest-aware arm poses for Utah and Rich; grounded locomotion on both rigs; supplied Sharps with hand-relative attachment, support-arm solve and held dialogue/walk variants; texture-only black lens treatment preserving Dude geometry/skin/animations; horse +X/human +Z heading correction and staged mount/reversed dismount; hit-only protected response for Dude and Rich through existing chamber-failed signal, recorded section arrival and retained story instance.

Native Godot 4.3 checks: ranch, protected response (42 checks, 0 failures), armory guns, two-storey armory, town law, founder fix document, world routes, save compatibility and script compilation pass. Repeated protected encounters, misses and bursts are covered. Captures here are isolated Compatibility renderer diagnostics, not proof of all player-camera acceptance criteria. Rich side view predates held dialogue variants. The actual armory introduction capture completed (2 plates, 23 demo shots) with no script errors; rich-player-camera.png shows the supplied rifle in the real room. Retaliation muzzle direction and full motion contact sampling remain required.

User clarified that Minister Mike Dean, bartender, sheriff and Utah all use the existing golden Remington. These four are now enabled and the regression test covers all six entities twice; that expanded run is queued and not yet validated. The shared Dude in the woods copy has no new retaliation hook yet. Dark-light lens review and repeated full mount/dismount pose review remain open. Full release suite, export, pack bounds and deployment verification remain open. No new generation or paid-provider job was used.
