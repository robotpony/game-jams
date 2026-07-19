# Plan

Phased implementation checklist for `4.p8`, based on [README.md](README.md) and [DESIGN.md](DESIGN.md). Nothing is built yet; all phases are pending. Design is locked, no phase below is blocked on an open question.

## Phase 1: Ship arc movement & radial shooting

- [x] Ship position represented as an angle `sang`, clamped to ±69° (a 21° trim off the true ±90° endpoints, keeping the 8×8 sprite fully on-screen; derivation in DESIGN.md)
- [x] Left/right input adjusts `sang` at `sturn = 2°/frame` (default, tune once playable) within that clamp
- [x] Shared `arc_xy(cx, cy, r, a)` helper added to `lib/math.lua` before wiring ship position; 3 enemy arcs and both shot types reuse the same math, so deriving it once here pays off immediately. Implementing it surfaced a gotcha not visible from the DESIGN.md formula alone: Pico-8's built-in `sin()` is inverted from standard math convention (`sin(x) == -sin(2*pi*x)`, a consequence of its y-down screen coordinates), so the helper negates the sin term to keep "increasing angle" sweep rightward, matching the left/right button mapping.
- [x] Hold-to-fire: spawns a shot every 4 frames while held, travelling 4px/frame along the radius vector through `sang` at the moment of firing
- [ ] Verify (manual play test, not yet done): ship visibly sweeps along a curve rather than a straight line, clamps cleanly at both ends without the sprite clipping off-screen; a shot fired from each end of the arc travels in a visibly different direction; holding fire produces a steady stream of shots

Implemented in `4.p8` with placeholder visuals only (filled circle for the ship, single pixels for shots); real sprites land in Phase 7.

**Follow-up fix**: the arc's orientation in the original spec was backwards (a dome opening downward, centre below the screen) instead of a valley opening upward toward the screen edges (centre above the screen), per a corrected spec — see DESIGN.md's Arc geometry note. `CX,CY` moved from `(64,103)` to `(64,25)`, `arc_xy()` in `lib/math.lua` now adds the cos term instead of subtracting it, and the player's shot direction flipped from outward to inward (`arc_xy(0,0,-1,sang)`). The four checked items above are still correct in shape, but `4.p8`'s constants and shot-direction call were updated to match; re-verify after this fix, not just the original implementation.

## Phase 2: Enemy arcs & formation

- [ ] Three enemy arcs at radii 53/43/33 (centred position y=78/68/58, band-edge/topmost y≈59/58/54), angular bands ±50°/±40°/±30°
- [ ] Wave 1 starting counts: 7/6/5 (18 total), evenly spaced within each arc's band
- [ ] Enemies sweep back and forth within their arc's band
- [ ] Shot/enemy collision detection (player shot vs enemy)
- [ ] Verify: enemies visibly occupy three distinct curved bands above the ship; a player shot that crosses an enemy's position destroys it

## Phase 3: Enemy attack behaviour

- [ ] Each enemy independently fires a shot outward along its radius vector (`arc_xy(0,0,1,ea)`, away from the centre and therefore down toward the ship — enemies sit at smaller radii than the ship, so "outward" is toward the ship here, the opposite of the player's own inward shots) on a wave-scaled cooldown (`max(20, 90-5*(w-1))` frames)
- [ ] Each enemy independently has a wave-scaled per-second chance to break formation and dive toward the ship's last-known position (`min(0.5, 0.05+0.015*(w-1))`), at `base_dvspd = 3px/frame` scaled the same way as formation speed (default, tune once playable)
- [ ] Dive miss handling: an enemy that goes off-screen without hitting the ship does **not** leave the wave; it respawns at the *outer edge of its angular band* (`ea=±B` for its tier, the highest point it can reach, not `ea=0` which is its centred/lowest position) and resumes formation sweep, with a per-enemy miss counter (`ei.dv`) that makes its next dive faster and its own fire cooldown shorter each time (both capped after ~7 misses). A wave must always clear via kills, never via unshot enemies dodging their way out of the roster.
- [ ] Player-hit collision (enemy shot or diving enemy vs ship) reduces lives
- [ ] Entity cap enforced: total enemies + enemy shots never exceeds 32 (a respawning diver doesn't hold a slot during its brief off-screen instant); a fire/dive event that would exceed it is skipped for that frame rather than queued
- [ ] Verify: enemies visibly fire back and occasionally dive; a missed dive re-enters at the top and is visibly more aggressive on its next attempt; getting hit reduces lives; entity count never visibly exceeds the cap even with fire and dive both active

## Phase 4: Waves & progression

- [ ] Wave clears when its enemy count reaches 0
- [ ] Next-wave enemy count `min(24, 18+2*(w-1))`, formation speed `base_espd*(1+0.08*(w-1))` (`base_espd = 0.5°/frame` default), feeding Phase 2/3's placement and behaviour formulas
- [ ] Lives (5 start), score tracking: `50*arc_tier + (50 if diving when destroyed)` per kill
- [ ] Verify: clearing every enemy on a wave triggers the next wave with a visibly larger/faster formation; losing all 5 lives ends the round; score increases correctly by arc tier and dive bonus

## Phase 5: Token checkpoint (core systems)

- [ ] Count tokens with Phases 1-4 implemented: ship movement, enemy arcs/formation, attack behaviour (fire, dive, miss-respawn), waves/progression, entity cap
- [ ] Compare against a soft ceiling of ~4,000 tokens for core systems (roughly half the ~8,192 total), leaving room for Phase 6's screens/HUD and Phase 7's sprites/SFX
- [ ] If over the soft ceiling, simplify before continuing (e.g. cut the miss-intensity stacking, simplify dive-vs-formation state, or move more shared math into `lib/`) rather than discovering the problem after art and sound are already built
- [ ] Verify: token count recorded; explicit decision made (proceed, or simplify first) before starting Phase 6

## Phase 6: Screens & flow

- [ ] Title screen: call the shared `draw_title_card("GYRI #4")` from [`../lib/title.lua`](../lib/title.lua); paste `blink()` (`lib/screen.lua`) and `draw_title_card()` into `4.p8`'s `__lua__` section rather than hand-rolling
- [ ] Wave-transition overlay: "WAVE n" text over the frozen playfield, holds 36 frames (1.2s)
- [ ] End screen: final score and wave reached
- [ ] HUD (y=120-127): lives left, score centre, wave right
- [ ] Verify: full loop is playable start to finish, title → game → wave transition → ... → end → title

## Phase 7: Visuals & sound polish

- [ ] Apply palette: ship fixed white (7), enemy/enemy-shot/grid colours rotate per the 4-wave theme table in DESIGN.md
- [ ] Draw sprite 0 (ship, rocket wedge) and sprite 1 (enemy, wing silhouette), per the pixel data in DESIGN.md's Sprite rendering section
- [ ] Draw sprites 2-4 (shot straight/shallow/steep); wire the angle-to-sprite-and-flip lookup (`abs(θ)` thresholds at 12°/37°, `flip_x` on sign, `flip_y` for enemy shots) so both shot types share all 3 sprites
- [ ] Outer-tier enemies (33px arc) drawn via `sspr` at 10×10 instead of native 8×8; inner/middle tiers stay native
- [ ] Background scanline grid: 8 fixed rows at the y-values in DESIGN.md, foreground/mid/horizon colour banding
- [ ] SFX: ship fire (short/punchy, deliberately breaks from the atmospheric palette so hold-to-fire doesn't choke the 4 sound channels), enemy destroyed, player hit, enemy dive start, wave clear, game over (all atmospheric/sustained)
- [ ] Verify: play a full round with sound on; confirm every listed SFX fires at its correct trigger, shots visibly point along their travel direction, outer-tier enemies read as visibly bigger, and the ship stays visually identifiable against a re-tinting field

## Phase 8: Final token & performance check

- [ ] Confirm final token count is within the ~8,192 budget (second checkpoint, now including Phase 6/7's screens, sprites, and SFX on top of Phase 5's core-systems count)
- [ ] Confirm a full wave at the entity cap (32 hostile entities plus ~8 player shots) renders without frame drops, given the extra per-frame trig from angle-based movement and the per-frame grid redraw
