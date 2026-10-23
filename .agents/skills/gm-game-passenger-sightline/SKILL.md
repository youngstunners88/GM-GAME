---
name: gm-game-passenger-sightline
description: Repair the first-person passenger shooting view when Inferno or his pack occludes the road and bears; inspect real normal/ADS captures and preserve supported mounting and finite combat.
---

# Passenger shooting clearance

The founder's Transition 2 document (2026-10-23) asks to raise Lil Blunt on Inferno's back so his bag no longer blocks shooting. In the actual woods code Inferno drives the quad and Lil Blunt rides the rear rack. Preserve that arrangement and the founder's character/pack; solve the passenger stance and eye height.

1. Read gm-game-transition-repair, ep2-living-woods and ep2-mountain-quad-escape. Inspect current BACK_EYE, BACK_F/BACK_SIDE, seat and driver anchors, _seat_riders and _glide_to. The live camera is reseated each tick, so moving Camera3D once cannot fix it.
2. Capture the actual seated driver and passenger view looking forward, sideways and behind, in normal view and ADS. Include visible roadway/bears, rifle and crosshair. Use the same road coordinates and angles before/after.
3. Raise the supported passenger eye/stance enough to see above the pack. Keep the camera on the quad, first person, with continuous mount/dismount, earned equipped weapon, finite ammo and unchanged bear awareness/attack rules. Do not hide Inferno or his bag globally, move the driver off the grips, or bypass encounters to manufacture clearance.
4. Project the pack/head silhouette into the actual camera; measure the clear central aiming corridor and verify a visible road bear can be aimed at and shot. Repeat during straight/bent road headings, normal/ADS, mount and dropoff. Avoid a floating third-person camera.
5. Freeze the sightline, ammo expenditure/hit and mount continuity in a runtime regression. Inspect Compatibility-rendered pixels yourself; constants or a headless pass alone do not prove the view. Record limits and exact source; ship with smokerealm-ship.
