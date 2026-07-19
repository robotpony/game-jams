# Plan

Extraction backlog for shared Lua snippets, drawn from patterns duplicated in `1/1.p8` and `3/3.p8` (see each file's Architecture section in its own `CLAUDE.md`) and anticipated by `2/DESIGN.md`. `lib/` now holds `screen.lua` and `title.lua`; the rest of the backlog below is still unbuilt.

## Built

- [x] `screen.lua`: `blink(hz)` prompt-text helper, stateless (`(time()*hz)%2<1`). Replaces `1.p8`'s `(time()*2)%2<1` and `3.p8`'s `blink_t` counter, both used identically now. Verified: both carts reimplemented flash separately, so blink was the only piece extracted here; flash itself is still open below.
- [x] `title.lua`: `draw_title_card(name)`, shared jam title card (colour-swatch strip, "'26 WARPED GAME JAM", "PRESENTS", centred per-game name, blinking prompt). Retrofitted into `1.p8` (`"#1"`) and `3.p8` (`"3 FALLING"`); `2/PLAN.md` and `2/DESIGN.md` now call for it in `2.p8` once built. Not part of the original backlog below, it came out of a follow-up discussion about matching the jam's Intellivision reference style (`lib/styles/intellivision-title.png`).
- [x] `math.lua`: `arc_xy(cx,cy,r,a)` polar-to-cartesian helper. Built ahead of `4.p8` as planned below, since `4/DESIGN.md`'s ship, enemy arcs, and shots all need it. Corrects for pico-8's inverted `sin()` (negates the sin term) so increasing angle sweeps rightward; this wasn't obvious from `4/DESIGN.md`'s abstract formula and only surfaced while implementing `4/PLAN.md` Phase 1. Also adds (not subtracts) the cos term, since `4`'s arc is a valley opening upward (implied centre above the screen) rather than a dome (centre below) — an orientation bug in the original spec, corrected after Phase 1 was already built, so `4.p8` needed a follow-up fix too. In use in `4.p8` for ship position and shot direction.
- Verify: both `1.p8` and `3.p8` still run and their title screens display correctly (manual play test — not yet done, see Open questions). `4.p8` Phase 1 (ship movement + shooting via `arc_xy`) is implemented but not yet manually play-tested in Pico-8 (see `4/PLAN.md`).

## Confirmed — matches the planned module list

- [ ] `screen.lua`: flash_t/flash_c screen flash (fill screen, decrement each draw). Already `lib/CLAUDE.md`'s own worked example. Source: `1.p8` (`flash_t`/`flash_c` on trap/treasure), `3.p8` (`flash_t`/`flash_c`, combo-only).
- [ ] `rng.lua`: weighted choice (cumulative-threshold roll). Source: `3.p8` `rnd_col()`.
- [ ] `hud.lua`: right-aligned number printing (`tostr(x)` then `pos - #str*width`). Source: `1.p8` score/level/timer, `3.p8` score.
- Verify: each extracted function is dropped into `1.p8` or `3.p8` in place of the original inline code and the cart still runs identically (manual play test).

## Gaps — real duplication, not currently named in the module list

- [ ] `rng.lua`: Fisher-Yates array shuffle. Source: `1.p8` `shuf(t)`. `2/DESIGN.md`'s randomized floor layout will need this again.
- [ ] `input.lua`: `any_btnp()` (was any button just pressed, checks 0-5). Source: `3.p8`.
- Verify: same as above, plus confirm `2.p8` (once built) uses these instead of reimplementing.

## Open question

- [ ] `math.lua`: clamped increment/decrement (`min(hi, x+1)` / `max(lo, x-1)`). Used repeatedly for bounded counters: `1.p8` score floor, `3.p8` `lives`/`pseg`. `min`/`max` calls are already cheap (2-3 tokens); a wrapper function may cost more tokens than it saves. Decide before implementing, not after.

## Deliberately excluded

- Combo/streak detection (`3.p8` `last3` three-in-a-row check) — specific to that catch mechanic, no second use case yet.
- Difficulty ramp formula (`3.p8` `spd = base_spd + base_spd*(t/2700)`) — one line, not worth a function.
- Win/loss flag + branching end screen — architectural convention, not code. Already documented via `2/DESIGN.md`'s cross-reference to `3/DESIGN.md`.

## Note on adoption

General policy: `1.p8` and `3.p8` shipped before this backlog existed, so as a rule they don't get retrofitted when a new module is extracted; game 2 onward is where the backlog is expected to get used first.

The title card is a deliberate, explicit exception to that rule (2026-07-17): both shipped carts now call `draw_title_card()`, because the point was a jam-wide title format, not a token-saving extraction, and leaving 1 and 3 on bespoke title screens would have defeated it. Screen flash and HUD printing are still bespoke in both carts and aren't getting retrofitted under the general policy above.
