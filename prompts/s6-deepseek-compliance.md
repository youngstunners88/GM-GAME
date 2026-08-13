@include prompts/_s6_facts.md

# YOUR ROLE: DeepSeek — compliance / regression cross-check

Against the project's global rules, flag any risk in the planned Session-6 work:
- Never hardcode wallet/contract addresses (the vault/crush economy is in-game
  counters only — confirm no real-address temptation).
- All weed/diamond content positive & chill; enemies not weed-themed.
- Web export must stay non-threaded.
- Save/load compatibility: adding a `blaze_diamonds` counter to
  goldmine_system.gd get_save_data/load_save_data must not break old saves
  (missing key must default, not crash).
- Godot 4.3 `var x := <Variant>` parse-error trap.
Give a short checklist verdict (PASS/RISK per item) + the one regression test
most likely to catch a mistake here.
