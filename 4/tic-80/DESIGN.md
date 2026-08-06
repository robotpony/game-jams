# 4 (TIC-80 upscale) — Design

Pre-implementation technical design for the TIC-80 build, based on [`../README.md`](../README.md). Follows [`../../SPEC-FORMAT.md`](../../SPEC-FORMAT.md).

**Not written yet.** This is a stub, not a draft: the design conversation that fills in this file hasn't happened. What's decided so far is direction, not numbers — see [`../CLAUDE.md`](../CLAUDE.md) and [PLAN.md](PLAN.md)'s Phase 0.

## Scope agreed so far

This is planned as an expanded upscale of the Pico-8 build ([`../pico-8/DESIGN.md`](../pico-8/DESIGN.md)), not a straight port at a bigger resolution. Four areas are on the table, none detailed yet:

- **Bigger playfield/formation** — using the 240×136 canvas (vs. Pico-8's 128×128) for more enemies on-screen, wider arcs, more headroom above the ship
- **Richer sprite art** — TIC-80's 512 combined tile/sprite slots (vs. Pico-8's 256 shared) for more frames, more roster variety, more rotation states
- **Deeper sound/music** — TIC-80's tracker-style SFX/music editor for a real music track (the Pico-8 build has SFX only, no music) plus more elaborate SFX
- **New mechanics** — actual gameplay additions beyond a reskin (new enemy behaviours, a second weapon, power-ups, etc.), not yet chosen

## What this file will need, once the design pass happens

Per [`../../SPEC-FORMAT.md`](../../SPEC-FORMAT.md#designmd)'s required DESIGN.md sections:

- Screen layout (240×136, not 128×128 — every pixel coordinate in the Pico-8 DESIGN.md needs rederiving, not scaling by eye)
- Palette (TIC-80's remappable 16-colour palette vs. Pico-8's fixed hardware one — decide whether to keep Pico-8's exact hues or use the remap room for something new)
- State machine
- Core system design (arc geometry, formation, wave scaling — how much of the Pico-8 build's math carries over vs. needs rework for the new playfield size and any new mechanics)
- Difficulty ramp
- Budget (TIC-80's is "Token budget" per SPEC-FORMAT.md's naming convention, since 64KB is still a countable ceiling, not an uncapped one)

## Related

- [`../pico-8/DESIGN.md`](../pico-8/DESIGN.md) — the original build's locked design, the baseline this upscale departs from
- [`../../tools/tic80.md`](../../tools/tic80.md) — TIC-80 constraints, RAM/VRAM layout, cart format, CLI workflow
