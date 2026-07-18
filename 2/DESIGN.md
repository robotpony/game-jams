# 2 — Design

Technical design derived from the spec in [README.md](README.md), following [`../SPEC-FORMAT.md`](../SPEC-FORMAT.md). Pre-implementation; design is finalized. Once `2.p8` exists, the as-built version of this becomes the Architecture section of [CLAUDE.md](CLAUDE.md).

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

Floor boundaries within a 3-floor room: even thirds of the 112px play area, ~37px per floor. HUD line layout follows this project's established bottom-strip convention (see [`1/CLAUDE.md`](../1/CLAUDE.md) and [`3/DESIGN.md`](../3/DESIGN.md)).

Control room: a single screen showing one blank letter slot per letter of the secret word (10 slots, centred), the player's collected letters below for selection, and a "confirm" prompt. No 3-floor layout here, since it's a distinct puzzle-arrangement UI rather than a physical room.

## Palette

Reuses game 1's Atari-2600-approximation colour indices (see [`../1/CLAUDE.md`](../1/CLAUDE.md)).

| Element | Colour | Index |
| ------- | ------ | ----- |
| Background | Black | 0 |
| Elevator car | Sky blue | 6 |
| Corridor / room floor | Dark blue | 5 |
| Centre lift | Teal | 12 |
| Robot | Red | 8 |
| Object (can, desk, vending machine, shelf) | Dark green | 3 |
| Health pickup | Green | 11 |
| Letter tile | Yellow | 10 |
| Player | White | 7 |
| HUD text | White | 7 |

## State machine

| `gs` | Name | Entered from | Exits to |
| ---- | ---- | ------------- | -------- |
| 0 | Title | startup | 1 (any button) |
| 1 | Elevator shaft (corridors included) | title; walking back out of a room | 2 (walking through an edge door on a corridor floor) |
| 2 | Puzzle room | the elevator shaft, through a floor's edge door | 1 (walking back out the entry door); 3 (reaching the control room) |
| 3 | Control room | last valid puzzle room in the shaft | 4 (correct letter arrangement submitted, or timer/HP hits 0); stays in 3 on a wrong submission |
| 4 | Game over | any state, on loss/win condition | 0 (any button) |

`won` (bool) set when state 3 is exited via a correct letter arrangement rather than timer/HP hitting 0; the game-over screen branches on this flag, matching the pattern in [`3/DESIGN.md`](../3/DESIGN.md).

A short (~9 frame / 300ms) input-frozen pause plays out on both sides of the shaft↔room crossing (`trans_t`, ticked down before any other `_update` logic runs, screen keeps rendering normally throughout). Elevator floor stops don't get this pause — only the shaft/room boundary does.

## Core system design

**Floor/room generation** — 16 floors along the elevator shaft, each randomized (left corridor, right corridor, both, or neither) from a seed; a "both" floor produces two independent rooms, one per side. Re-roll the seed (generate-then-validate) until at least 10 floors resolve to a valid room. Puzzle rooms draw from 4 density patterns (light/medium/heavy robot and object placement per floor side, same 3-floor structure throughout); placement rules cap each floor side at 1 robot and 2 objects. Valid floors are spaced apart afterward: any two valid floors that land back-to-back get a blank floor inserted between them, as long as doing so doesn't drop the room count below the 10-room minimum the puzzle needs; usually there's 1 blank floor between valid ones, sometimes more (existing longer blank runs from the random roll aren't shortened), occasionally none where there isn't enough slack to spare.

**Secret word & letter placement** — `words = {"impossible","infiltrate","demolition","electrical","mechanical"}`; pick one per seed (10 letters each, no length variance to handle). Assign one letter, in word order, to each of the first 10 valid rooms in shaft order. Any valid room beyond the 10th gets no letter; every object it generates holds a health pickup instead. If a letter-room's rolled object count is 0, one object is force-placed so the letter always has somewhere to live. The control room is placed behind the last valid room regardless of whether that room carries a letter.

**Room persistence** — Each generated room's object/robot state is stored once (e.g. a table keyed by room id) and mutated in place; re-entering a room reads that same state rather than regenerating it, so searched objects stay empty and robots keep their position.

**Shaft walking & corridors** — The shaft's car interior is narrow (16px), and the player walks left/right within it using the same movement input as everywhere else. A corridor is not a separate screen: on a floor with an open corridor, the walkable range on that side extends from the shaft column all the way to the screen's edge (x=0 or x=127), where the door is; a floor with no corridor on that side keeps the solid wall in place instead, blocking movement there. Direction stays consistent the whole way: walking left through a left-side door arrives in the room beside its right-hand wall (continuing left goes deeper); walking right through a right-side door arrives beside the room's left-hand wall (continuing right goes deeper). Leaving a room retraces the same path in reverse, back through the same door, ending at the shaft's edge.

**Elevator stops** — The car only auto-stops at floors where `floors[i]~=0`; from the current floor, the next stop in a given direction is found by scanning forward until a non-"neither" floor turns up, skipping over "neither" floors without pausing there (they're still scrolled past visually at the normal travel speed). If no more valid floors remain before the shaft's physical top or bottom, the car just can't go further in that direction — it never parks on a "neither" floor, even at the very ends of the shaft. Up/down input only moves the car while the player is standing inside the narrow shaft column (not out in an open corridor stretch); arriving at a new floor re-clamps the player's shaft-relative x to that floor's actual wall/corridor layout, in case it differs from the floor just left.

**Search mechanic** — Holding up in front of an object advances a 10-step progress bar, roughly 1 second per step (about 30 frames per step at 30fps, 300 frames total). On completion, the object's contents (health or a letter) are added to the player's inventory. Releasing up, walking away, or getting hit all pause the bar rather than resetting it (progress lives on the object itself), resuming from the same step next time the player holds up in front of it.

**Robot behaviour** — 3 patterns per robot, chosen at placement time: stationary-look (random-interval left/right look with a beep), patrol (left/right at a set speed, random pause at each end), and chase (moves toward the player at a random speed when on the same floor; pauses for about 30 frames ("thinks"), then reverses if the player jumps over it). Every pattern is confined to the side of the floor the robot spawned on; none of them ever cross the centre lift gap, so a robot on one side is never a threat on the other unless the player crosses to it.

**Jump trigger** — Up always jumps, with three exceptions where up already has a job: moving the car while standing in its narrow column (a corridor is part of the same screen but not this column, so jumping works normally there), riding the centre lift, and searching a found object. Search wins whenever a found object is in front of the player and up is held; jump is what up does everywhere else. Direction follows whichever way the player is currently moving (left/right), or straight up if they're standing still.

**Jump arc** — Fixed parabolic arc, not an instant hop: higher and slower than a minimal hop, so it reads as a deliberate, floaty leap rather than a twitch dodge. Horizontal reach must clear either hazard (a robot's 8px body, or the lift shaft's gap — which is exactly as wide as the lift platform itself, not narrower than it) with margin, not exactly match it — landing right on the edge of what you jumped over isn't "cleared." Once player animation exists (Phase 6), the sprite flips during the arc as its jump pose.

**Lift shaft width** — The gap in the room floor where the centre lift travels is exactly as wide as the lift platform, so there's no visual mismatch between where the platform sits and where the floor actually opens up; walking into that gap while the lift isn't there falls through (see Collision below), consistently across the platform's whole footprint.

**Collision** — Player vs. robot: 1 HP loss plus a small knockback (a few px away from the robot) and a brief invulnerability window (~45 frames) before it can hit again. Player vs. lift shaft edge while not in the lift, on any floor (walking in, or a jump landing in it): 3 HP loss and a respawn at the room's entry door, same invulnerability window as a robot hit. Wrong letter-arrangement submission in the control room: 1 HP loss, no retry limit.

**Puzzle-solving UI** — Control room renders one blank slot per letter of the secret word plus the player's collected letters below; directional input cycles the highlighted slot and selects which collected letter fills it, a confirm button checks the full arrangement against the target word.

## Difficulty ramp

Robot speed and density scale with rooms found, similar in spirit to game 3's `spd` formula: `robot_spd = base_spd + base_spd * (rooms_found / 10)`, capped at `rooms_found = 10` so the ramp maxes out once the secret word is complete rather than continuing to scale in bonus rooms.

## Score

`score = 100 * letters_collected + 2 * seconds_remaining` on a win; `0` on a loss. Shown on the game-over screen.

## Timer

Starts at 300 seconds (5 minutes, `timer = 9000` frames at 30fps), counts down continuously across the elevator shaft and all rooms, never resets. Game over on reaching 0.

## Token budget

This design carries more concurrent state than games 1 or 3: per-room robot AI (3 behaviour variants), a search progress-bar timer, a 3-floor room layout, a seeded floor/puzzle generator that must validate solvability, persisted per-room state across revisits, and an ambient music loop for the elevator shaft. Lean on [`../lib/CLAUDE.md`](../lib/CLAUDE.md) for input handling, the state machine, the title screen (`draw_title_card`), and seeded RNG rather than rederiving them; the robot behaviour table is a good candidate for a flat array indexed by pattern id rather than per-pattern branching code. The 5-word list and per-room state table are the two new memory costs this game has that 1 and 3 didn't.
