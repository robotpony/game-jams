# Plan

Extraction backlog for shared Lua snippets, drawn from patterns duplicated in `1/1.p8` and `3/3.p8` (see each file's Architecture section in its own `CLAUDE.md`) and anticipated by `2/DESIGN.md`. `lib/` now holds `screen.lua`, `title.lua`, `math.lua`, `rng.lua`, `input.lua`, `hud.lua`, `collision.lua`, `map.lua`, and `state.lua`; `screen.lua`'s flash/fade/shake is the only item left in the original backlog below.

## Built

- [x] `screen.lua`: `blink(hz)` prompt-text helper, stateless (`(time()*hz)%2<1`). Replaces `1.p8`'s `(time()*2)%2<1` and `3.p8`'s `blink_t` counter, both used identically now. Verified: both carts reimplemented flash separately, so blink was the only piece extracted here; flash itself is still open below.
- [x] `title.lua`: `draw_title_card(name)`, shared jam title card (colour-swatch strip, "'26 WARPED GAME JAM", "PRESENTS", centred per-game name, blinking prompt). Retrofitted into `1.p8` (`"#1"`) and `3.p8` (`"3 FALLING"`); `2/PLAN.md` and `2/DESIGN.md` now call for it in `2.p8` once built. Not part of the original backlog below, it came out of a follow-up discussion about matching the jam's Intellivision reference style (`lib/styles/intellivision-title.png`).
- [x] `math.lua`: `arc_xy(cx,cy,r,a)` polar-to-cartesian helper. Built ahead of `4.p8` as planned below, since `4/DESIGN.md`'s ship, enemy arcs, and shots all need it. Corrects for pico-8's inverted `sin()` (negates the sin term) so increasing angle sweeps rightward; this wasn't obvious from `4/DESIGN.md`'s abstract formula and only surfaced while implementing `4/PLAN.md` Phase 1. Also adds (not subtracts) the cos term, since `4`'s arc is a valley opening upward (implied centre above the screen) rather than a dome (centre below) — an orientation bug in the original spec, corrected after Phase 1 was already built, so `4.p8` needed a follow-up fix too. In use in `4.p8` for ship position and shot direction.
- [x] `rng.lua`: `weighted(vals,cum,total)` cumulative-threshold roll, and `shuf(t)` Fisher-Yates shuffle. Both extracted verbatim in behaviour from their source: `weighted` reproduces `3.p8`'s `rnd_col()` generically (was hardcoded to 5 fixed colours/thresholds); `shuf` is `1.p8`'s `shuf(t)` unchanged. Built for `6/PLAN.md`'s Phase 0 (`6.p8` needs both: `weighted` for distance-biased block/monster/loot selection, `shuf` was already anticipated below for `2.p8`'s floor layout).
- [x] `input.lua`: `any_btnp()`, verbatim from `3.p8`. Built for `6/PLAN.md`'s Phase 0 (scene-transition "press any button" prompts).
- [x] `hud.lua`: `rprint(s,rightx,y,col)` right-aligned print. Generalizes `1.p8`'s score/level/timer and `3.p8`'s score right-align math (`pos - #str*4`) into one function instead of three inline copies. Built for `6/PLAN.md`'s Phase 0.
- [x] `collision.lua`: `rect_hit(x1,y1,w1,h1,x2,y2,w2,h2)` AABB overlap check. Not an extraction of existing shared code, no cart before game 6 used a generic version: `3.p8` and `5.p8` each hand-roll an inline overlap check with hardcoded sizes. Built for `6/PLAN.md`'s Phase 0 (player-block, player-monster, player-hazard checks).
- [x] `map.lua`: `cell_xy(px,py)` pixel-to-cell conversion and `neighbour(cx,cy,i)` 8-directional (Moore neighbourhood) cell offset. Also novel, no prior cart uses Pico-8's native `mget`/`mset`/`fget` map at all (checked: zero hits across `1`-`5`). Deliberately doesn't wrap `mget`/`mset` themselves, calling them directly is the same token cost as a wrapper with no savings. Built for `6/PLAN.md`'s Phase 0 (world-gen neighbour scans, mining target lookup); bumped from an initial 4-directional version to 8 once Phase 1 needed a real Moore-neighbourhood wall-count for cellular-automata cave smoothing (a 4-neighbour count gives blockier caves).
- [x] `state.lua`: `goto_state(ns)`/`return_state()`, a `gs`/`gsret` pair for overlays reachable from more than one caller state. Deliberately not a full dispatch-table FSM (see the file's own header comment for why); games 1/2/3/5's plain `if gs==n then` chains stay the pattern for the main dispatch, this only covers the "remember where an overlay was opened from" piece game 6's Help screen needs and `2.p8`'s single-caller `help_on` didn't. Built for `6/PLAN.md`'s Phase 0.
- Verify: both `1.p8` and `3.p8` still run and their title screens display correctly (manual play test — not yet done, see Open questions). `4.p8` Phase 1 (ship movement + shooting via `arc_xy`) is implemented but not yet manually play-tested in Pico-8 (see `4/PLAN.md`). The six files built for `6/PLAN.md` Phase 0 haven't been play-tested in a real cart yet either, since `6.p8` doesn't exist yet; Phase 0's own Verify step covers that.

## Confirmed — matches the planned module list

- [ ] `screen.lua`: flash_t/flash_c screen flash (fill screen, decrement each draw). Already `lib/CLAUDE.md`'s own worked example. Source: `1.p8` (`flash_t`/`flash_c` on trap/treasure), `3.p8` (`flash_t`/`flash_c`, combo-only).
- Verify: dropped into `1.p8` or `3.p8` in place of the original inline code and the cart still runs identically (manual play test).

## Open question

- [ ] `math.lua`: clamped increment/decrement (`min(hi, x+1)` / `max(lo, x-1)`). Used repeatedly for bounded counters: `1.p8` score floor, `3.p8` `lives`/`pseg`. `min`/`max` calls are already cheap (2-3 tokens); a wrapper function may cost more tokens than it saves. Decide before implementing, not after.

## Deliberately excluded

- Combo/streak detection (`3.p8` `last3` three-in-a-row check) — specific to that catch mechanic, no second use case yet.
- Difficulty ramp formula (`3.p8` `spd = base_spd + base_spd*(t/2700)`) — one line, not worth a function.
- Win/loss flag + branching end screen — architectural convention, not code. Already documented via `2/DESIGN.md`'s cross-reference to `3/DESIGN.md`.

## Note on adoption

General policy: `1.p8` and `3.p8` shipped before this backlog existed, so as a rule they don't get retrofitted when a new module is extracted; game 2 onward is where the backlog is expected to get used first.

The title card is a deliberate, explicit exception to that rule (2026-07-17): both shipped carts now call `draw_title_card()`, because the point was a jam-wide title format, not a token-saving extraction, and leaving 1 and 3 on bespoke title screens would have defeated it. Screen flash and HUD printing are still bespoke in both carts and aren't getting retrofitted under the general policy above.
