# Plan

Phased implementation checklist for the TIC-80 build of game 4, based on [`../README.md`](../README.md) and [DESIGN.md](DESIGN.md).

Phases past 0 aren't written yet: this build's scope (bigger playfield, richer sprites, deeper sound/music, and new mechanics, per [`../CLAUDE.md`](../CLAUDE.md)) isn't decided in enough detail to phase out until the Phase 0 design pass happens. Filling in Phase 1 onward before that would mean guessing at numbers DESIGN.md is supposed to lock first.

## Phase 0: Design pass

- [ ] Design conversation covering the four scope areas from DESIGN.md's "Scope agreed so far": how much bigger the playfield/formation gets, what new sprite roster/rotation states are worth authoring, what music/SFX TIC-80's tracker adds, and which new mechanic(s) (if any) actually ship
- [ ] Rederive Screen layout for 240×136 (not a scaled-up copy of the Pico-8 build's 128×128 coordinates)
- [ ] Decide the TIC-80 palette mapping: keep the Pico-8 build's exact hues, or use the remap room for something new
- [ ] Write DESIGN.md's Core system design, Difficulty ramp, and Token budget sections from those decisions
- [ ] Rewrite this PLAN.md's Phase 1 onward from the finished DESIGN.md, following the Pico-8 build's phase shape ([`../pico-8/PLAN.md`](../pico-8/PLAN.md)) as a structural reference, not a numbers reference
- [ ] Verify: DESIGN.md has no bracket placeholders and no section deferred to "TBD"; every number a later phase needs is either in DESIGN.md or explicitly punted to this PLAN.md's Open questions
