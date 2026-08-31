<!-- dispatched: moonshotai/kimi-k3
     prompt: prompts/boss-vo-vocab.md
     files inlined: 1
     tokens: 1564 in / 12131 out
     cost: $0.1867
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
66 new lines below, ranked strongest first per category. All ≤8 words, none duplicate the existing pool.

## TAX (nasal, bureaucratic, condescending)

**taunt**
1. Capital gains? More like capital PAINS!
2. 1099 problems, and you're every one!
3. Nothing is certain but death and ME!
4. I've got a lien on your future!
5. I don't spread FUD. I AM FUD!
6. Your refund status: permanently delayed!
7. I've itemized your failures, nugget!
8. I'll repossess your high score!

**mock**
1. That hit? Non-deductible!
2. I'll bill you for the bruises!
3. That one's going on your permanent record!
4. Your face just accrued interest!
5. Damage assessment: considerable!

**hurt**
1. That's coming out of YOUR refund!
2. That was NOT in my projections!
3. Ow! I'm expensing this pain!

**phase50**
1. That's it! Out come the RED forms!
2. Now I'm auditing ANGRY!

**phase25**
1. Final notice! FINAL! NOTICE!
2. I'm garnishing EVERYTHING! Even your coins!

**death**
1. This isn't over... I have... an extension...
2. Tell my calculator... I loved it...

## CRYSTAL (cold, robotic, corporate)

**taunt**
1. Impermanent loss? Yours looks permanent.
2. Your health bar is... undercollateralized.
3. Rug pull initiated. You are the rug.
4. You are a rounding error.
5. Cold storage? I am the cold.
6. Your smart contract has a bug: you.
7. I farm you for yield.
8. I am the correction you feared.

**mock**
1. Error 404: your dodge not found.
2. Your pain has been... monetized.
3. You have been... deprecated.
4. Damage logged. Performance review: poor.
5. Impact absorbed. By you.

**hurt**
1. That input was... unscheduled.
2. Anomaly detected. It is you.
3. That will be reflected in your review.

**phase50**
1. Efficiency at fifty percent. Escalating to maximum.
2. Half depleted. Fully motivated.

**phase25**
1. Critical mass achieved. Dumping everything.
2. Final quarter. Final offer: surrender.

**death**
1. Tell the shareholders... I was... efficient...
2. This outcome... was not... in the forecast...

## BANDIT (gravelly, wild-west, unhinged)

**taunt**
1. I staked this claim fair and square!
2. Fool's gold? Nah, yer just a fool!
3. Yer about to be a one-man ghost town!
4. Boom goes the dynamite, bye goes the nugget!
5. The motherlode's MINE! All MINE!
6. Claim jumper? I prefer claim ENTHUSIAST!
7. I struck gold! Then I struck heroes!
8. Gold rush? More like gold CRUSH!

**mock**
1. That one's free! Next one costs ya!
2. Down ya go, like a bad investment!
3. Shoulda dodged, greenhorn!
4. Yer leakin' ETH, kid!
5. Ha! Yer slower than cold molasses!

**hurt**
1. Ow! That was MY favorite rib!
2. Yer gonna pay for that! In GOLD!
3. Lucky shot! Won't happen twice!

**phase50**
1. That's it! Breakin' out the GOOD dynamite!
2. Half dead? Bah! I'm just WARMED UP!

**phase25**
1. If I go down, the mine comes too!
2. Cornered varmint is the meanest varmint!

**death**
1. The gold... was fool's gold... all along...
2. Tell the motherlode... I said... howdy...

## Flags on your existing lines

- **crystal "I hoard. You bleed. Efficient." + phase50 "Q3 earnings are... your blood."** — two blood jokes, and both are the edgiest lines in the file against the PG/no-gore bar. Keep at most one; the phase50 version is the stronger line.
- **tax phase25 "This is highway robbery! MY robbery!"** — funny, but "robbery" is bandit's lane. Mild theme bleed; a seizure/garnishment joke would be more on-brand.
- **tax mock "Ha! Filed under: losers!"** — weakest tax mock; no tax or crypto hook, could belong to any villain.
- **crystal hurt pair** ("Unacceptable variance." / "Recalculating threat level.") — individually fine, tonally identical as a pair. The three new ones add range.
- **bandit's pool is the thinnest** (3 taunts, 2 mocks) — he's the boss who'll feel most repetitive until these land.
- **tax "Tax Form 420..."** — confirming this one's fine: playful, on-brand for a weed mascot, not negative drug framing.

Two craft notes: bandit's death #1 is an intentional callback to taunt #2 — works standalone, lands harder if the taunt played. And per the JSON's `note`, shipping these means generating new `<boss>_<category>_<i>.mp3` files and bumping the per-category counts in `boss_voice_data.gd` — I don't have that file, so I can't tell you the current count format.