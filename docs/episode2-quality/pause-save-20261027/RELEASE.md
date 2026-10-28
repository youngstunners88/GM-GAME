# Pause and Save release — 2026-10-27

Runtime source `eaebdacf85ae0b963f1b916fb9ff2270d6916f9b`, cursor/context-exit followup `729b38db`, production release `4044823647c3e107c128477eceaa8fda50b8b823`. The repository shipping script refreshed master and preserved the branch's generated export commit without force-pushing. CI export commit `f59caef6` is on master.

[Production CI40513406899](https://github.com/youngstunners88/GM-GAME/actions/runs/40513406899), job122220792382, succeeded. The exact release passed the full hosted gameplay suite, including manual checkpoint30 and save compatibility, title/access/security and town/stable camera gates. Butler confirms85.25% reused and48.86MiB fresh data, followed by “Pushed to https://youngstunners88.itch.io/smokerealm”. This is an actual upload, not a skipped credential step.

Local proof: full native regression baseline plus final affected30-check pause/save and full Episode2 touch tests; exact final export desktop14 and touch-browser14 checks, each with two real engine/page reloads and the actual menu Continue route. Touch saves use a second finger; blocked browser storage preserves the previous checkpoint. Desktop pause/resume/Talk/restart/quit playtest passes. Eight Compatibility captures reviewed. The native pause suite retains only its three documented machine-specific tap-target/HUD differences; production CI passed cleanly. No real-phone hardware pass is claimed.

Fresh-import main198846944B (limit199229440B; margin382496B). Final local main198879632B and extras112818464B; zero script errors.69 models scanned, zero excluded-but-used textures. All five title-screen files remain unchanged. No paid services used.

Saves are one latest named checkpoint: Episode1's last stage checkpoint/start, Episode2's current section start, with coherent inventory/economy/reward guards. They use the same browser/device. The explicit web checkpoint is a small atomic localStorage record, separate from rolling filesystem/IndexedDB autosaves; old saves remain compatible. No exact-frame snapshot, cloud service or access bypass was added. Scripted/film contexts retain their existing Escape exit; normal gameplay opens/resumes pause with a usable pointer.

**Public verification PASS:** browser reports BUILD `2026-10-27-4044823`, extras HTTP200/ready and the unchanged Episode2 access-code prompt. Downloaded public main198846976B and extras112817856B both pass the190MiB cap. Across three native engine processes, the actual public packs pass10 save/Continue checks. The downloaded public HTML/JS/WASM/audio worklet and packs pass14 desktop and14 phone-emulation WebGL checks, each with two real page/engine reloads, both actual menu Continue routes, preserved ammo/reward guards, multi-finger Save and blocked-storage protection. No script/shader/page/test errors remain.

`PUBLIC_PROOF.json` records the actual public URL/BUILD, sizes, SHA512 hashes and raw browser results; `CI_RECEIPT.json` records deployment. Public scenes are replayed through excluded external local fixtures against the exact served resources. This is distinct from an authenticated public-origin Episode2 walkthrough or a hardware phone pass; no production access bypass was added.

Live page: https://youngstunners88.itch.io/smokerealm — hard refresh and check BUILD2026-10-27-4044823.
