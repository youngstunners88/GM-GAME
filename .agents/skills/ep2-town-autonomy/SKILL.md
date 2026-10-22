---
name: ep2-town-autonomy
description: Implement and verify SmokeRealm town NPC individuality, autonomous activities, safe navigation, social memory and danger responses.
---

Use this for the ambient town controller, not quest rewrites. Read `design/ep2/town/autonomy-20261022/CONTRACT.md`, `src/episode2/actors/ep2_town_people.gd`, and its navigation helper. Follow the repository resume and ship skills.

Each person owns a seeded random stream, personality, activity history, destinations and cooldowns. Score useful activities from that person's profile, recent history and current context. Random wandering alone does not establish individuality. Keep all decisions on the chamber step clock; no wall-clock timers or network AI.

Build navigation from actual town walls and props. Exclude raised porches/building interiors until height-aware navigation exists. Sweep edges and movement, yield to people/player, recover blocked paths, reserve activity spots, and preserve office/saloon access. Threats interrupt activities; dialogue and duel control ambient movement without teleporting. Civilians, particularly children, are never combat targets or loot.

Test long simulations, crossed paths, obstructed routes, recovery, distinct activity distributions, greetings and social cooldowns, danger recovery, pause and rebuild/save round trips. Observe the actual player camera over time. Tests of declarations or asset counts do not prove behavior. Record limits and release evidence in the task verification document.
