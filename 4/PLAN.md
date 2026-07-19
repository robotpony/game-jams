# Plan

Phased implementation checklist for `4.p8`, based on [README.md](README.md) and [DESIGN.md](DESIGN.md). Nothing is built yet; all phases are pending. Several items depend on open questions in README being resolved first.

## Phase 1: Ship arc movement & radial shooting

- [ ] Ship position represented as an angle along a fixed-radius arc, not an x-coordinate
- [ ] Left/right input adjusts the ship's angle, clamped to the arc's endpoints (needs Arc geometry from README's Open questions)
- [ ] Fire input spawns a shot travelling along the radius vector through the ship's current angle
- [ ] Verify: ship visibly sweeps along a curve rather than a straight line; a shot fired from each end of the arc travels in a visibly different direction

## Phase 2: Enemy arcs & formation

- [ ] Enemy arcs defined as concentric circles at smaller radii than the ship's arc (needs radii/count from Open questions)
- [ ] Enemies placed at angular positions along their arc and sweep back and forth
- [ ] Shot/enemy collision detection
- [ ] Verify: enemies visibly move along a curved path distinct from the ship's arc; a shot that crosses an enemy's position destroys it

## Phase 3: Waves & progression

- [ ] Wave clears when its enemy count reaches 0
- [ ] Next-wave enemy count/speed scaling (needs Progression details from Open questions)
- [ ] Lives, score tracking (needs starting lives count and scoring value from Open questions)
- [ ] Verify: clearing every enemy on a wave triggers the next wave; losing all lives ends the round

## Phase 4: Screens & flow

- [ ] Title screen: call the shared `draw_title_card("GYRI #4")` from [`../lib/title.lua`](../lib/title.lua); paste `blink()` (`lib/screen.lua`) and `draw_title_card()` into `4.p8`'s `__lua__` section rather than hand-rolling
- [ ] Wave-transition overlay: "WAVE n" text over the frozen playfield (needs duration from Open questions)
- [ ] End screen: final score and wave reached
- [ ] HUD: lives, score, wave number across the bottom strip (exact split TBD)
- [ ] Verify: full loop is playable start to finish, title → game → wave transition → ... → end → title

## Phase 5: Visuals & sound polish

- [ ] Apply palette once chosen (blocked on README's Open questions)
- [ ] Ship, enemy, and shot sprites
- [ ] SFX: ship fire, enemy destroyed, player hit, wave clear, game over (blocked on Open questions)
- [ ] Verify: play a full round with sound on; confirm every listed SFX fires at its correct trigger

## Phase 6: Token & performance check

- [ ] Confirm final token count is within the ~8,192 budget
- [ ] Confirm a full wave (ship, all enemies, all shots, HUD) renders without frame drops, given the extra per-frame trig from angle-based movement
