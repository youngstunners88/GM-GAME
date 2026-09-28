# Drops

One folder per drop: `NNN_slug/` (zero-padded, e.g. `001_bong-party-teaser/`).

Scaffold a new one with the `drop-runner` skill — do not hand-create folders,
so every drop gets the same lifecycle files and a matching board row in
`../calendar.md`.

A scaffolded drop folder contains:

```
NNN_slug/
  drop.md            # the drop's control file: format, hook, state, links
  brief.md           # Astra creative brief (filled by astra-lead)
  script_final.md    # locked script
  script_shots.md    # beat-by-beat shot list, 10s hero window marked
  prompts/           # shot-NN_seedance2.md + hero_seedance25.md
  builds/            # render takes (failed + WIP)
  output/            # masters only
  posts/             # platform captions + schedule
```

Shipped + analyzed drops move to `../../archive/NNN_slug/` to keep this lean.
