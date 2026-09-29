---
name: gm-game-portal-ledge-fall
description: Historical ledge-fall implementation, withdrawn by the founder. Consult when modifying education-room edges so falls and life loss are not reintroduced.
---

# Education rooms have safe edges

The founder explicitly withdrew the bridge falling/life-loss request after playing it. Do not restore FALL_MARGIN, overhang timers, falling tweens, respawns or GameManager.lose_life in education rooms. Campaign hazards are separate.

PortalExplorer and Companion both use StudyRoom.constrain_to_ground. Make the painted walking surface and polygon union spacious and continuous; move machinery off the bridge. Verify real input traversal and advisor following with tests/portal_traversal_test.gd, including holding movement against the bridge edge without losing a life.
