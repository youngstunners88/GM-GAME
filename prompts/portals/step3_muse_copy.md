You write in-game copy for a chill, friendly 2D platformer classroom (hero: Lil Blunt, a cute relaxed weed-nugget mascot; tone positive, never aggressive, no drug stereotypes). Each of three stages has a short underground study room where the player reads the official whitepaper OR watches the official video, then sits an 11-question quiz with an examiner. You write VOICE and PLATE DESIGN only. You must NOT state any protocol fact, number, APY, address, chain, or date — the quiz facts are locked elsewhere. Keep every line <= 70 characters so it fits a dialogue box at 1280x720.

Rooms / examiners:
- smoke: "The Reading Ring", examiner "Ember the Archivist" — archivist, green lamp, dry patience ("read it before you claim you know it").
- diamonds: "The Pressure Study", examiner "The Assay Trio" — a three-voice crystal jury; lines come in cut / weigh / stamp triplets (prefix speaker as "CUT:", "WEIGH:", "STAMP:").
- gold: "The Claim Office", examiner "The Claim Recorder" — a clerk with a stamp ledger and a vest-clock; plain, procedural, no poetry about yields.

Pass bar is 7 of 11. Fail = retry OR proceed with the score. Any completion earns a scorecard.

Two images are attached: 1 = the founder's DIAMONDS whitepaper art, 2 = the founder's GOLD MINE whitepaper art. Describe how to present each as an in-room plate (composition, stamp hierarchy, frame, lighting), copying composition energy, not pixel detail. For SMOKE there is no art: design the plate — circular ash-ring certificate, neon-green rim, a Lounge-basket mark as a sink hole in the centre, the word SMOKE and the phrase "culture + sink", burn arrows pointing inward. Not a cigarette, not a DEX UI, not a QR code.

Reply with ONLY valid JSON (no fences, no prose) in exactly this shape:
{"smoke":{"room_title":"","examiner_name":"","examiner_intro":["","",""],"study_choice_prompt":"","paper_label":"","video_label":"","video_wait_line":"","quiz_intro":"","pass_line":"","fail_line":"","retry_label":"","proceed_label":"","ascent_line":"","plate":{"title":"","subtitle":"","design_notes":"","draw_spec":{"background":"#rrggbb","rim":"#rrggbb","accent":"#rrggbb","shapes":["short procedural drawing instructions, one per item, for a 512x512 canvas"]}}},
 "diamonds":{same keys; plate.draw_spec may be null because the founder art is used as the plate texture; design_notes = how to frame/light it},
 "gold":{same keys; plate.draw_spec null likewise}}
