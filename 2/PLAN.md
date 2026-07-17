# Plan

Phased implementation checklist for `2.p8`, based on [README.md](README.md) and [DESIGN.md](DESIGN.md). Nothing is built yet; all phases are pending. A few items depend on open questions in README being resolved first.

## Phase 1: Elevator shaft & floor generation

- [ ] Elevator car moves up/down, stops at any floor, clamped to shaft bounds
- [ ] Floors generated from a seed: left corridor, right corridor, both, or neither
- [ ] Elevator hum/buzz sound while moving
- [ ] Verify: same seed produces the same floor layout; elevator stops cleanly at every floor

## Phase 2: Rooms, objects & search

- [ ] Entering a corridor loads the room on the other side; player spawns beside the entry door
- [ ] Room layout: 3 floors, centre lift moving automatically top to bottom
- [ ] Objects placed per floor side (max 2), from the 4 object types
- [ ] Search mechanic: up in front of an object raises the player's hands, shows a comic-bubble progress bar (0–10, ~1s/step), yields contents on completion
- [ ] Object contents: health or a puzzle letter (needs Health pickup value and Puzzle piece distribution from README's Open questions before tuning)
- [ ] Verify: search completes in ~10 seconds, object then stops being searchable, inventory/HP updates correctly

## Phase 3: Robots

- [ ] Stationary pattern: random-interval left/right look, beep on look
- [ ] Patrol pattern: left/right movement, random pause at each end
- [ ] Chase pattern: moves toward player on the same floor; pauses/reverses if jumped over
- [ ] Placement rule: max 1 robot per floor side
- [ ] Player/robot collision costs HP (needs Robot/fall damage value from Open questions)
- [ ] Verify: each pattern behaves distinctly; a chasing robot correctly pauses when jumped

## Phase 4: Puzzle & win condition

- [ ] Secret word assembled from collected letters (1 of 10 possible)
- [ ] Puzzle solvability validated at generation time, not just hoped for
- [ ] Control room reachable from the last puzzle room found
- [ ] Win: puzzle solved in the control room. Loss: timer reaches 0, or HP reaches 0
- [ ] Verify: a generated seed is always solvable; both win and loss paths are reachable

## Phase 5: Screens & flow

- [ ] Title screen: "#2 Mission" / "'26 WARPED GAME JAM", Intellivision-style
- [ ] Room enter/exit fade transitions; game start/end flash
- [ ] Game over screen: win/loss headline, final state (score question pending — see Open questions)
- [ ] HUD: timer, floor level, inventory letters across the bottom 2 lines
- [ ] Verify: full loop is playable start to finish, title → shaft → rooms → control room → game over → title

## Phase 6: Visuals & sound polish

- [ ] Apply palette once chosen (blocked on README's Open questions)
- [ ] Player animations: run (3-frame), stand, search (hands raised)
- [ ] SFX: footstep, robot look-beep, search completion, item pickup, robot hit, jump, win, loss (several blocked on Open questions)
- [ ] Verify: play a full round with sound on; confirm every listed SFX fires at its correct trigger

## Phase 7: Token & performance check

- [ ] Confirm final token count is within the ~8,192 budget
- [ ] Confirm a room with 3 floors, a moving lift, up to 2 robots per side, and HUD renders without frame drops
