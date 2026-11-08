# ADR: the Auction House lives inside the auction road room (2026-11-08)

**Context.** Founder brief PROMPT_AUCTION_HOUSE_RENEGADE_JACK_HAMMER_2026-11-08 bans teleports, blackouts, geometry glitches and "a separate
auction-only world" between Logan's Lake and the auction hall, and wants one atmosphere.

**Decision.** `Ep2AuctionHouse` (src/episode2/chamber/ep2_auction_house.gd) is a component of `AuctionRoadChamber`, placed at road s = 395 in
the road's own frame. The road's gate no longer resolves; the visit ends when the player walks back out of the hall's front doors after
Jack Hammer's flee (`end_session`). The lake requests `prebuild_requested("auction_road")` on its ROAD beat, so the road (and the hall when
the streamed pack is mounted) is built off screen before the sign, and the hand-over keeps the gaze (`_apply_handoff_gaze`, up to 90°).
Collision is a list of 2D rectangles in hall-local (x, z) pushed out after the road's corridor clamp. Renegade's clips and Jack's run are
lent at runtime between Tripo/Mixamo rigs (rotation tracks only, into a per-player "lent" library).

**Consequences.** No session-root change and no second world system; the road room carries ~25 extra people + lights at its far end
(web Compatibility ignores LODs, so the crowd is kept to readable groups). A later auction room (bidding economy, train hand-off) should
extend this component rather than add a chained chamber at the door.
