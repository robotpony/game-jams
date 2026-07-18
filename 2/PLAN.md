# Plan

Phased implementation checklist for `2.p8`, based on [README.md](README.md) and [DESIGN.md](DESIGN.md). Phases 1–5 are built, including the corridor rework (corridors merged into the elevator screen, replacing an earlier separate-screen misreading of the spec). Phases 6–7 are pending. Design is finalized, no open questions remain blocking any phase.

## Phase 1: Elevator shaft & floor generation

- [x] Elevator car moves up/down, clamped to shaft bounds
- [x] 16 floors generated from a seed: left corridor, right corridor, both (two independent rooms), or neither; re-roll until at least 10 floors resolve to a valid room
- [x] Elevator hum/buzz sound while moving (ambient music loop deferred to Phase 6; `__music__` patterns need Pico-8's built-in tracker, not hand-typed hex)
- [x] Shaft is narrow (16px); player walks left/right within it
- [x] Elevator only auto-stops at floors with a corridor (`next_stop` scans past "neither" floors; can't park on one even at the shaft's physical top/bottom); up/down input only responds while standing inside the narrow shaft column; arriving at a new floor re-clamps the player's position (`shaft_bounds`) to that floor's actual layout
- [x] Corridors are not a separate screen — a corridor floor's walkable area (`shaft_bounds`) extends from the shaft column straight out to that screen edge (x=0 or x=120), where the door is drawn (x=0-3 or x=124-127); a "neither" side there keeps the solid wall + concrete. (An earlier build made the corridor its own screen; that was a misreading of the spec, not the intended design — the "blank room with nothing in it" report was this screen, not a broken room.)
- [ ] Verify (manual play-test): same seed produces the same floor layout; elevator skips "neither" floors without stopping; player is visible standing in the car; walking off the shaft column on a corridor floor reaches the room's door at the screen edge

## Phase 2: Rooms, objects & search

- [x] Walking through a corridor floor's edge door loads the room on the other side, player spawning beside the entry door on the room's bottom floor. Direction stays consistent throughout: entering left keeps going left, arriving beside the room's right wall; entering right keeps going right, arriving beside its left wall. Leaving retraces the same door in reverse, back to the shaft
- [x] ~300ms input-frozen pause (`trans_t`, 9 frames) on both sides of the shaft↔room crossing, screen still rendering throughout; door SFX plays at that same crossing, both directions
- [x] Room layout: 3 floors (even thirds, ~37px each), centre lift moving automatically top to bottom (rideable: board when it's aligned with your floor, ride it, disembark when aligned with another; crossing when misaligned now falls to the floor below for 3 HP, jump clears it safely — see Phase 3)
- [x] Objects placed per floor side (max 2), from the 4 object types, per one of 4 density patterns
- [x] Room state persists across revisits: searched objects stay empty; robots keep their position and pattern state too (Phase 3)
- [x] Search mechanic: holding up in front of an object raises the player's hands, shows a progress readout (0–10, ~1s/step), yields contents on completion; releasing up pauses rather than resets; a robot hit (Phase 3) also just pauses it, same mechanism
- [x] Object contents: health pickup (+2 HP) or a puzzle letter, one per first-10 valid rooms in shaft order
- [ ] Verify (manual play-test): search completes in ~10 seconds, object then stops being searchable, inventory/HP updates correctly; leaving and re-entering a room preserves its state; rooms reached via a corridor floor actually have their objects (confirming the earlier "empty room" report was the stray corridor screen, not this)

## Phase 3: Robots

- [x] Jump: fixed parabolic arc (`jumping`/`jt`/`jT`/`jh`/`jdir`/`jy0`), triggered by `btnp(2)` (up) except while standing in the elevator car's narrow column, riding the centre lift, or searching a found object — those three are up's other jobs and take priority; a corridor is part of the elevator-shaft screen but not that column, so jumping works there too (a follow-up fix — the first pass had left corridors with no jump handling at all, silently falling through to a no-op). 24 frames, ~18px peak height, ~19px horizontal: deliberately higher/slower/wider than a minimal hop, clearing an 8px robot or the lift shaft's gap with margin rather than exactly (spec gap resolved after Phase 3's first pass, which under-scoped this to a bare 8px/16-frame hop). Also replaces Phase 2's "wait for the lift" blocking behaviour at the gap: walking into a misaligned lift shaft now falls to the floor below and costs 3 HP (`hp-=3`, `rfl+=1`), while jumping clears it safely (the jump branch returns early, bypassing the fall check entirely). The room's lift shaft gap (`liftx0`/`liftx1`, 58-69) is now exactly as wide as the lift platform itself — a follow-up fix; the first pass had widened the platform to 12px without widening the underlying blank-floor gap or the fall-through/board collision column to match, leaving an 8px functional gap under a 12px visual platform
- [x] Stationary pattern (`pat==1`): random-interval left/right look (`r.dir` flips every 30-90 frames). Beep-on-look SFX deferred to Phase 6 alongside the rest of this game's SFX identity — not wired up yet, only the visual look-flip
- [x] Patrol pattern (`pat==2`): left/right movement between `r.x0`/`r.x1` (its side's floor span), random pause (15-45 frames) at each end
- [x] Chase pattern (`pat==3`): moves toward the player when `r.fl==rfl`; on overlap while the player is jumping, pauses 30 frames then flees the player's position for 20 frames before resuming the chase
- [x] All 3 patterns are confined to their spawn side of the room, never crossing the centre lift gap (fixed after the initial Phase 3 pass, which only confined patrol; chase/flee could walk straight across since their movement wasn't clamped to a side)
- [x] Placement rule: max 1 robot per floor side, rolled per side at generation time (`robp` probability table, indexed by the room's existing density pattern so heavier rooms get both more objects and more robots)
- [x] Player/robot collision (`hit_check()`): 1 HP loss, small knockback (6px away from the robot), 45-frame invulnerability (`invt`, also gates the lift-fall hazard so a fall can't immediately cascade through multiple floors); player sprite flickers while invulnerable
- [x] Difficulty ramp: `rmul()` returns `1 + min(nvisited,10)/10`, applied to `r.spd` every frame a robot moves (patrol and chase); `nvisited` increments the first time each room is entered, capped at 10. Density itself is NOT re-scaled live by rooms found — rooms are still all generated upfront in `gen_floors()`, before any room has been visited, so each room's density pattern (1-4, chosen at generation) is the only density lever; this is a deliberate scope call against DESIGN.md's prose (which reads as speed+density), following the DESIGN.md formula (speed only) as the more precise source
- [ ] Verify (manual play-test): each pattern behaves distinctly; a chasing robot correctly pauses then flees when jumped; robots visibly speed up as more rooms are visited; jumping clears the lift gap safely; walking into a misaligned gap without jumping costs 3 HP and drops a floor

## Phase 4: Puzzle & win condition

- [x] Secret word picked per seed from the 5-word list (`impossible`, `infiltrate`, `demolition`, `electrical`, `mechanical`); one letter assigned per first-10 valid rooms in shaft order
- [x] Puzzle solvability validated at generation time (word length and room count always line up), not just hoped for — `wlen` (derived from `words[1]`'s length, not a hardcoded `10`) drives both the `nrooms>=wlen` generation-retry threshold and the `idx<=wlen` letter-assignment cutoff, so the two can't drift apart even if the word list changes later
- [x] Control room reachable from the last valid room in the shaft — `enter_control()`, triggered by reaching the deep wall (opposite the entry door) of the room whose index equals `nrooms`
- [x] Control room UI: blank slot per letter, player arranges collected letters, submits
- [x] Win: correct arrangement submitted. Wrong arrangement: 1 HP loss, stays in control room, unlimited retries. Loss: timer (starts 300s/9000 frames, never resets) reaches 0, or lift fall (3 HP) / robot hits (1 HP) bring HP to 0
- [ ] Verify (manual play-test): a generated seed is always solvable; both win and loss paths are reachable; a wrong submission costs HP but doesn't end the run; the control room's deep wall is only reachable behind the true last room, not any letter room

## Phase 5: Screens & flow

- [x] Title screen: call the shared `draw_title_card("#2 MISSION")` from [`../lib/title.lua`](../lib/title.lua) (colour-swatch strip, "'26 WARPED GAME JAM", "#2 MISSION", blinking start prompt) — already built since Phase 1 (this checkbox was stale, not a Phase 5 gap)
- [x] Room enter/exit fade transitions; game start/end flash — `draw_overlay()` renders a shrinking black iris (top/bottom bars) over `trans_t`'s existing 9-frame window for shaft↔room/control-room crossings, and a brief white `flash_t` pop for game start (`new_game()`) and end (win in `update_control()`, loss in `_update()`). A deliberate scope call: single-phase reveal-only, not a true fade-out-then-fade-in crossfade (the state already switches the instant a transition starts, and a real palette-based crossfade would cost meaningfully more tokens for a jam-scope visual) — see CLAUDE.md
- [x] Game over screen: win/loss headline, final score (`100 * letters_collected + 2 * seconds_remaining`, 0 on loss) — `draw_gameover()` now has a colour band (green/red) behind the headline instead of Phase 4's plain text stub; win/loss/score logic is unchanged from Phase 4
- [x] HUD: line 1 timer + floor level, line 2 letters collected (e.g. "LETTERS 4/10") — `draw_hud()`, shared by the shaft and room screens, replacing the temporary debug HUD (seed/floor/room-count). HP has no dedicated slot in DESIGN.md's 2-line layout, so it's folded onto the letters line rather than dropped; the control room keeps its own separate hp/time display (DESIGN.md treats it as a distinct UI, not the standard room HUD)
- [ ] Verify (manual play-test): full loop is playable start to finish, title → shaft → rooms → control room → game over → title; fades/flashes read correctly at each transition; HUD values (timer, floor, letters, hp) are all readable and correct in both the shaft and room screens

## Phase 6: Visuals & sound polish

- [ ] Apply palette (reused from game 1's colour indices; see DESIGN.md's table)
- [ ] Player animations: run (3-frame), stand, search (hands raised), jump (sprite flips for the arc's pose — the jump mechanic itself is built, Phase 3; this is only the visual)
- [ ] SFX: footstep, robot look-beep, search completion, item pickup (health vs. letter, distinct tones), robot hit, jump, win, loss — distinct identity from games 1/3
- [ ] Ambient music loop for the elevator shaft, authored in Pico-8's built-in tracker (`__music__` pattern referencing 2-3 pad-note sfx slots), silent elsewhere
- [ ] Verify: play a full round with sound on; confirm every listed SFX fires at its correct trigger

## Phase 7: Token & performance check

- [ ] Confirm final token count is within the ~8,192 budget
- [ ] Confirm a room with 3 floors, a moving lift, up to 2 robots per side, and HUD renders without frame drops
