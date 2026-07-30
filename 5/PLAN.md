# Plan

Phased implementation checklist for `5.p8`, based on [README.md](README.md) and [DESIGN.md](DESIGN.md).

## Phase 1: Level generation & player movement

- [x] Row/tile data: 4 rows × 16 columns, tile types (platform/gap), generated per DESIGN.md's Level generation algorithm (chute lane, gap density roll, guaranteed connector per row pair). Rope anchor placement is deferred to Phase 3, since nothing consumes it yet — no point generating dead data early.
- [x] Render the 4 platform rows plus fixed ground row from tile data
- [x] Player: left/right walk, jump (❎), gravity, collision against platform tiles and the ground row
- [x] Ladders: climb up/down when overlapping a ladder connector column
- [x] Stairs/box: walk/jump up a stairs/box connector without a climb input
- [x] Automated check: a 2,000-trial Lua-harness simulation of `gen_level()` (chute/connector logic only, no jump-range check) found zero cases of a missing connector or a connector landing on the chute column
- [ ] Verify: a freshly generated level is always completable ground-to-finish via ladders/stairs alone, including horizontal walkability along gap-dense rows between connector columns, which the generator doesn't explicitly guarantee (manual — needs a play test in Pico-8; see DESIGN.md's Level generation note on this known gap)

## Phase 2: Hazards & lives

- [ ] Hazard spawn: timer-driven, random column/type/roll-direction per DESIGN.md
- [ ] Hazard fall/roll behaviour: falls through gap columns, rolls across platform columns until reaching a gap, chute lane free-falls straight through
- [ ] Player/hazard collision: -1 life, brief invincibility window after a hit
- [ ] Lives: start at 3, no cap, game over at 0
- [ ] Verify: hazards visibly roll along platforms and drop through gaps and the chute lane; a hit costs exactly 1 life even on prolonged contact (manual — needs a play test in Pico-8)

## Phase 3: Rope swing

- [ ] Rope anchor placement (from level gen) and grab detection (player adjacent + up/jump toward it)
- [ ] Pendulum physics: `theta`/`theta_v` update per DESIGN.md's Rope swing formula, left/right pumps the swing
- [ ] Release (fire/jump button): launches player with velocity proportional to `theta_v` at release, falls through to normal jump/fall physics after
- [ ] Verify: a well-timed release crosses the gap and lands on the far platform; a mistimed release drops the player through the gap with no extra penalty beyond lost position (manual — needs a play test in Pico-8)

## Phase 4: Prize items — gun & bottle

- [ ] Prize spawn: periodic, random walkable platform tile, gun vs bottle (and bottle's green/red roll)
- [ ] Gun: 300-frame timer on pickup, rate-limited firing (no ammo count), shot destroys first hazard hit (+10 score), unequips at timer 0
- [ ] Bottle: green +1 life (no cap), red -1 life (can trigger game over at 1 life)
- [ ] Verify: gun stops firing exactly at the 10s mark; green/red bottles apply the correct life delta and visual/sound feedback (manual — needs a play test in Pico-8)

## Phase 5: Screens, flow & progression

- [ ] Title screen: shared jam title card, "5 TO THE TOP", blinking start prompt
- [ ] Level transition: flicker over the playfield, next level number shown, regenerates the level per Phase 1's generator with the new level's difficulty inputs
- [ ] End screen: "GAME OVER", final score, levels cleared, any button → Title
- [ ] State machine: title → playing → level transition → playing (next level) / end → title
- [ ] Progression: gap density, hazard spawn interval, and hazard fall/roll speed scale per level using DESIGN.md's formulas
- [ ] HUD: lives (numeric) left, level centred, score right
- [ ] Verify: full loop is playable across several level transitions; HUD values update correctly; difficulty is visibly higher by level 3-4 (manual — needs a play test in Pico-8)

## Phase 6: Visuals & sound polish

- [ ] Apply final palette (DESIGN.md) to platforms, ladders, stairs/box, chute marker, rope, finish button, player, all hazard and prize sprites
- [ ] SFX: jump, ladder step, rope grab/release, hazard hit, green/red bottle, gun pickup/shot/expiring-warning, hazard-destroyed pop, level clear, game over
- [ ] Verify: play a full round with sound on; confirm every listed SFX fires at its correct trigger (manual — needs a play test in Pico-8; sound content authored by ear-judgment, flag anything that sounds off)

## Phase 7: Token & performance check

- [ ] Confirm final token count is within the ~8,192 budget (see DESIGN.md's Token budget note on expected complexity relative to games 3 and 4) — authoritative number only available from Pico-8's own status bar; manual confirmation needed
- [ ] Confirm concurrent hazards (multiple rows/columns), rope physics, and tile rendering run without frame drops (manual — needs a play-test to confirm actual FPS)
