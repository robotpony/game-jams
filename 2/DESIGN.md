# 2 — Design

Technical design derived from the spec in [README.md](README.md), following [`../SPEC-FORMAT.md`](../SPEC-FORMAT.md). Updated through Phase 6 (sprites, visual polish, and the fixes in [`../BUGS.md`](../BUGS.md)'s #2 section) to track the shipped cart rather than the original pre-implementation draft; [`CLAUDE.md`](CLAUDE.md)'s Architecture section still has the exhaustive as-built detail (line-level code behaviour, state variable table) where this document only needs the design decision.

## Screen layout (128×128)

Title: the shared jam title card, drawn by `draw_title_card("#2 MISSION")` from [`../lib/title.lua`](../lib/title.lua). No per-game layout to design here, games 1 and 3 already use the same card; see that file for the exact pixel layout.

Elevator shaft:

```
y=0
  |  elevator shaft: narrow vertical column (x=56-71, 16px wide),
  |  player walks left/right within it and up/down between floors,
  |  but up/down only responds while standing inside that column
  |  floors scroll past as the car moves, 24px per floor (16 floors,
  |  384px total shaft height), auto-stopping only at floors with
  |  a corridor (others are scrolled straight past)
  |  a corridor is part of this same screen, not a separate one: on
  |  a floor with one open, that side has no wall or concrete, just
  |  blank background from the shaft column out to the screen edge
  |  (x=0 or x=127), where a door frame sits. A floor with no
  |  corridor on a side keeps the solid 4px wall + concrete backdrop
  |  there instead. Walking through an edge door pauses ~300ms then
  |  enters the room; leaving the room pauses the same on return
  |
y=111
y=112   HUD line 1 (8px): timer (left), floor level (right)
y=119
y=120   HUD line 2 (8px): letters collected so far, e.g. "LETTERS 4/10"
y=127
```

Puzzle room:

```
y=0
  |  floor 1 (top): robots/objects along left and/or right side
y=?
  |  floor 2 (middle), centre lift shaft running top to bottom
y=?
  |  floor 3 (bottom), entry door where the player stands on arrival
y=111
y=112   HUD line 1 (8px): timer (left), floor level (right)
y=119
y=120   HUD line 2 (8px): letters collected so far, e.g. "LETTERS 4/10"
y=127
```

Floor boundaries within a 3-floor room: even thirds of the 112px play area, ~37px per floor. HUD line layout follows this project's established bottom-strip convention (see [`1/CLAUDE.md`](../1/CLAUDE.md) and [`3/DESIGN.md`](../3/DESIGN.md)). The two HUD lines sit on their own dark-blue panel with a light-grey top border (rather than floating directly over the scene), with dim labels and brighter values so it reads as a UI layer distinct from the shaft/room behind it.

Control room: a single screen showing one blank letter slot per letter of the secret word (10 slots, centred), the player's collected letters below for selection, and a "confirm" prompt. No 3-floor layout here, since it's a distinct puzzle-arrangement UI rather than a physical room.

## Palette

Reuses game 1's Atari-2600-approximation colour indices (see [`../1/CLAUDE.md`](../1/CLAUDE.md)).

| Element | Colour | Index |
| ------- | ------ | ----- |
| Background | Black | 0 |
| Elevator car | Sky blue | 6 |
| Corridor / room floor | Dark blue | 5 |
| Centre lift | Teal | 12 |
| Robot (skin 1) | Red body, dark red legs, white lights | 8, 13, 7 |
| Robot (skin 2) | Red body, yellow lights | 8, 10 |
| Robot (skin 3) | Purple body, white lights | 2, 7 |
| Object (can, desk, vending machine, shelf) | Dark green, brown, or dark grey (1 of 3 picked at random per instance) | 3, 4, 5 |
| Health pickup | Green | 11 |
| Letter tile | Yellow badge, black letter | 10, 0 |
| Player | White | 7 |
| Concrete backdrop speckle | Light grey and dark blue flecks, on a dark grey fill | 6, 1, 5 |
| Corridor floor/ceiling line | Light grey | 6 |
| Shaft exit light bar | Yellow | 10 |
| HUD panel | Dark blue fill, light grey border, white/red text | 1, 6, 7, 8 |
| "Found: X" letter popup | Black fill, white border/text, yellow tile | 0, 7, 10 |

## State machine

| `gs` | Name | Entered from | Exits to |
| ---- | ---- | ------------- | -------- |
| 0 | Title | startup | 5 (any button) |
| 5 | Intro | title, any button | 1 (~90 frames elapsed, or any button) |
| 1 | Elevator shaft (corridors included) | the intro screen; walking back out of a room | 2 (walking through an edge door on a corridor floor) |
| 2 | Puzzle room | the elevator shaft, through a floor's edge door | 1 (walking back out the entry door); 3 (reaching the control room) |
| 3 | Control room | last valid puzzle room in the shaft | 4 (correct letter arrangement submitted, or timer/HP hits 0); stays in 3 on a wrong submission |
| 4 | Game over | any state, on loss/win condition | 0 (any button) |

`won` (bool) set when state 3 is exited via a correct letter arrangement rather than timer/HP hitting 0; the game-over screen branches on this flag, matching the pattern in [`3/DESIGN.md`](../3/DESIGN.md).

A short (~9 frame / 300ms) input-frozen pause plays out on both sides of the shaft↔room crossing (`trans_t`, ticked down before any other `_update` logic runs, screen keeps rendering normally throughout). Elevator floor stops don't get this pause — only the shaft/room boundary does.

State 5 (Intro) is a placeholder transition screen: plain black background, centred white text reading "stay a while, solve a puzzle!". It auto-advances to state 1 after ~90 frames (~3s) or on any button press, whichever comes first, calling `new_game()` at that point — the same call state 0's button press used to make directly before this state existed.

## Core system design

**Floor/room generation** — 16 floors along the elevator shaft, each randomized (left corridor, right corridor, both, or neither) from a seed; a "both" floor produces two independent rooms, one per side. Re-roll the seed (generate-then-validate) until at least 10 floors resolve to a valid room. Puzzle rooms draw from 4 density patterns (light/medium/heavy robot and object placement per floor side, same 3-floor structure throughout); placement rules cap each floor side at 1 robot and 2 objects. Valid floors are spaced apart afterward: any two valid floors that land back-to-back get a blank floor inserted between them, as long as doing so doesn't drop the room count below the 10-room minimum the puzzle needs; usually there's 1 blank floor between valid ones, sometimes more (existing longer blank runs from the random roll aren't shortened), occasionally none where there isn't enough slack to spare.

**Secret word & letter placement** — `words = {"impossible","infiltrate","demolition","electrical","mechanical"}`; pick one per seed (10 letters each, no length variance to handle). Assign one letter, in word order, to each of the first 10 valid rooms in shaft order. Any valid room beyond the 10th gets no letter; every object it generates holds a health pickup instead. If a letter-room's rolled object count is 0, one object is force-placed so the letter always has somewhere to live. The control room is placed behind the last valid room regardless of whether that room carries a letter.

**Room persistence** — Each generated room's object/robot state is stored once (e.g. a table keyed by room id) and mutated in place; re-entering a room reads that same state rather than regenerating it, so searched objects stay empty and robots keep their position.

**Shaft walking & corridors** — The shaft's car interior is narrow (16px), and the player walks left/right within it using the same movement input as everywhere else. A corridor is not a separate screen: on a floor with an open corridor, the walkable range on that side extends from the shaft column all the way to the screen's edge (x=0 or x=127), where the door is; a floor with no corridor on that side keeps the solid wall in place instead, blocking movement there. Direction stays consistent the whole way: walking left through a left-side door arrives in the room beside its right-hand wall (continuing left goes deeper); walking right through a right-side door arrives beside the room's left-hand wall (continuing right goes deeper). Leaving a room retraces the same path in reverse, back through the same door, ending at the shaft's edge.

**Corridor & shaft rendering** — An open corridor's floor/ceiling lines are light grey (not the original navy, which was too close to the corridor's black fill to read); each floor's band gets a line at both its top and bottom edge, not just the top. The shaft column also gets a 2px yellow light bar on whichever side has an open corridor at that floor, positioned right at the column edge so it's visible from inside the narrow column, not only at the door frame out at the screen edge. The concrete backdrop on closed sides has a sparse light-grey/dark-blue speckle texture on top of its base fill and mortar lines, using a deterministic position hash rather than `rnd()` since it's redrawn every frame.

**Elevator stops** — The car only auto-stops at floors where `floors[i]~=0`; from the current floor, the next stop in a given direction is found by scanning forward until a non-"neither" floor turns up, skipping over "neither" floors without pausing there (they're still scrolled past visually at the normal travel speed). If no more valid floors remain before the shaft's physical top or bottom, the car just can't go further in that direction — it never parks on a "neither" floor, even at the very ends of the shaft. Up/down input only moves the car while the player is standing inside the narrow shaft column (not out in an open corridor stretch); arriving at a new floor re-clamps the player's shaft-relative x to that floor's actual wall/corridor layout, in case it differs from the floor just left.

**Search mechanic** — Holding up in front of an object advances a 10-step progress bar, roughly half a second per step (2 progress/frame, 300-unit threshold, so 150 frames total at 30fps; doubled from an initial 1 progress/frame pass that felt slow). A tick plays once per step; on completion, the object's contents (health or a letter) are added to the player's inventory and a celebratory major-chord arpeggio plays, distinct from the per-step tick. Finding a letter also shows a brief "found: X" popup (60 frames, ~2s) with the yellow letter tile and the actual letter, since silently adding it to inventory gave no feedback. Releasing up, walking away, or getting hit all pause the bar rather than resetting it (progress lives on the object itself), resuming from the same step next time the player holds up in front of it. By decision, the object's contents are shown at all times (a green cross for health, a yellow letter tile for a letter), not hidden until completion — searching is a timed action on a known target, not a discovery mechanic.

**Object sprites** — Each object rolls both a kind (1 of 4: can, desk, vending machine, shelf; a distinct 8x8 silhouette per kind) and a colour variant (1 of 3: dark green, brown, dark grey) independently at generation time, so instances of the same furniture type aren't all identically coloured.

**Robot behaviour** — 3 patterns per robot, chosen at placement time: stationary-look (random-interval left/right look), patrol (left/right at a set speed, random pause at each end), and chase (moves toward the player at a random speed when on the same floor; pauses for about 30 frames ("thinks"), then reverses if the player jumps over it; also pauses briefly whenever its required direction actually changes, e.g. the player crossing from one side to the other, instead of reversing on the same frame — matches patrol's existing pause-at-turn behaviour, which chase originally lacked). Every pattern is confined to the side of the floor the robot spawned on; none of them ever cross the centre lift gap, so a robot on one side is never a threat on the other unless the player crosses to it — this still applies on the bottom floor even though it's no longer a fall hazard for the player, a placement rule independent of that hazard. The per-side clamp accounts for the robot's 8px sprite width on both edges (not just the room's outer edge), so a robot can't visually hang off the screen or overlap into the gap by its sprite width; base movement speed is also tuned to about half its original value.

Sound cycle: every look/turn event (stationary's flip, patrol's turn, chase's direction change or "thinks" pause) plays a two-note "bleep-bloop"; actively moving (patrol, chase, or fleeing) plays a periodic buzz blip roughly every 8px of travel. Both share a single channel across every robot in the room (a jam-scope simplification — not true per-robot polyphony, so only the most recently triggered robot is audible if two overlap).

Sprite: an inverted-U arch on two legs, in 1 of 3 random colour skins (red body/dark red legs/white lights; solid red body/yellow lights; or purple body/white lights — the third added after a play-test question revealed the first two, while nominally "two skins," were both red-based and read as one colour at a glance); a pair of lights blinks and shifts to whichever side matches the robot's current facing/travel direction (the same `dir` value already driving the 3 patterns above), so the look/turn sound cue has a matching visual. Both the robot's and the player's collision boxes are inset 2px on every side (was: robot only, inset 1px — still triggered 2-4px before the sprites visually touched, since the player's own box was still the full 8x8 too), matching each entity's actual drawn silhouette more closely so standing next to a robot to search a nearby object doesn't trigger a hit from bounding-box padding alone.

**Jump trigger** — Up always jumps, with three exceptions where up already has a job: moving the car while standing in its narrow column (a corridor is part of the same screen but not this column, so jumping works normally there), riding the centre lift, and searching a found object. Search wins whenever a found object is in front of the player and up is held; jump is what up does everywhere else. Direction follows whichever way the player is currently moving (left/right), or straight up if they're standing still.

**Jump arc** — Fixed parabolic arc, not an instant hop: higher and slower than a minimal hop, so it reads as a deliberate, floaty leap rather than a twitch dodge. Horizontal reach must clear either hazard (a robot's 8px body, or the lift shaft's gap — which is exactly as wide as the lift platform itself, not narrower than it) with margin, not exactly match it — landing right on the edge of what you jumped over isn't "cleared." The sprite steps through a 4-frame launch/tuck/extend/land sequence keyed to arc progress, drawn as separate left/right-facing art (not mirrored) and picked by the jump's horizontal direction.

**Player sprite & animation** — Beyond the jump sequence above: a stand pose, a 4-frame run cycle (separate left/right-facing art, picked by a facing flag set wherever left/right input drives movement), and a 2-frame search reach loop (direction-neutral, driven by search progress rather than a separate timer). Authored via a small host-side tool (`tools/sprites/sprite_tool.py`) that renders 8x8 hex-grid sprite definitions as terminal glyph art or PNGs for review, then patches them into the cart's `__gfx__` section directly — `tools/sprites/` had no scripts before this game.

**Lift shaft width** — The gap in the room floor where the centre lift travels is exactly as wide as the lift platform, so there's no visual mismatch between where the platform sits and where the floor actually opens up. On the top and middle floors, walking into that gap while the lift isn't there starts a fall (see Falling below). The bottom floor's gap is solid ground instead, drawn as a continuous line with no visual gap: there's nothing below it to fall to, so by decision it reads and behaves as ordinary walkable floor, not a hazard.

**Lift dwell time** — The lift pauses briefly (~1s) each time it reaches one of the 3 floor-aligned positions before continuing, giving the player a real window to board it by walking in. Catching it with a jump works by height proximity to the lift's current position, not by checking whether it's paused at a floor stop, so a jump can also catch it while it's actively moving between floors.

**Riding the lift** — Once aboard, the player moves and jumps exactly as they would on any floor or corridor: horizontal input isn't gated on the lift being aligned with a floor, walking off either edge lands on whichever floor the lift is currently nearest to, and jumping off it launches a normal jump arc from the lift's current height (which can then catch the lift again mid-air, or miss it and fall/land normally). (Superseded an earlier design where movement while riding only worked when the lift happened to be paused at a floor stop, making it unresponsive for most of its travel, and where jumping off it wasn't possible at all.)

**Falling** — Walking or jumping into the lift shaft's gap while the lift isn't there, on the top or middle floor only, starts a real descent, not an instant penalty: normal left/right input still applies while falling, so momentum can carry the player sideways out of the gap column entirely, landing safely on whichever floor's band the fall has reached by then. Catching the lift at its current position mid-descent also lands safely, whether or not it's paused at a floor. Only reaching the bottom floor's ground while still falling costs HP, landing the player there in place rather than respawning them at the room's entry door — scaled to how far they fell (1 HP from the middle floor, 2 HP from the top), not a flat amount, since a 1-floor slip and a full 2-floor plunge shouldn't cost the same. Either way, the same ~45-frame invulnerability window a robot hit gives applies. (Superseded two earlier designs in turn: first an instant-fail where a single pixel crossing the gap boundary immediately failed with no chance to recover, then a flat-3-HP/reset-to-entry-door fall that didn't distinguish 1-floor slips from 2-floor plunges and treated the bottom floor as another fall hazard rather than solid ground.)

**Collision** — Player vs. robot: 1 HP loss plus a small knockback (a few px away from the robot) and a brief invulnerability window (~45 frames) before it can hit again; the robot's own hit box is inset 1px per side (see Robot behaviour above). Player vs. lift shaft void: see Falling above. Wrong letter-arrangement submission in the control room: 1 HP loss, no retry limit.

**Puzzle-solving UI** — Control room renders one blank slot per letter of the secret word plus the player's collected letters below; directional input cycles the highlighted slot and selects which collected letter fills it, a confirm button checks the full arrangement against the target word.

## Difficulty ramp

Robot speed and density scale with rooms found, similar in spirit to game 3's `spd` formula: `robot_spd = base_spd + base_spd * (rooms_found / 10)`, capped at `rooms_found = 10` so the ramp maxes out once the secret word is complete rather than continuing to scale in bonus rooms.

## Score

`score = 100 * letters_collected + 2 * seconds_remaining` on a win; `0` on a loss. Shown on the game-over screen.

## Timer

Starts at 300 seconds (5 minutes, `timer = 9000` frames at 30fps), counts down continuously across the elevator shaft and all rooms, never resets. Game over on reaching 0.

## Token budget

This design carries more concurrent state than games 1 or 3: per-room robot AI (3 behaviour variants), a search progress-bar timer, a 3-floor room layout, a seeded floor/puzzle generator that must validate solvability, persisted per-room state across revisits, and an ambient music loop for the elevator shaft. Lean on [`../lib/CLAUDE.md`](../lib/CLAUDE.md) for input handling, the state machine, the title screen (`draw_title_card`), and seeded RNG rather than rederiving them; the robot behaviour table is a good candidate for a flat array indexed by pattern id rather than per-pattern branching code. The 5-word list and per-room state table are the two new memory costs this game has that 1 and 3 didn't.
