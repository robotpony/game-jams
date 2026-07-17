# 2 — Design

Technical design derived from the spec in [README.md](README.md), following [`../SPEC-FORMAT.md`](../SPEC-FORMAT.md). Pre-implementation: several values below are marked TBD and tracked in README's Open questions. Once `2.p8` exists, the as-built version of this becomes the Architecture section of [CLAUDE.md](CLAUDE.md).

## Screen layout (128×128)

Elevator shaft:

```
y=0
  |  elevator shaft: vertical column, player's car centred
  |  floors scroll past as the car moves; each floor may show
  |  a corridor opening to the left, right, both, or neither
  |
y=111
y=112   HUD line 1 (8px): TBD split — timer, floor level
y=119
y=120   HUD line 2 (8px): TBD split — inventory letters
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
y=112   HUD line 1 (8px): TBD split — timer, floor level
y=119
y=120   HUD line 2 (8px): TBD split — inventory letters
y=127
```

Floor boundaries within a 3-floor room aren't decided yet (even thirds of the 112px play area is the obvious default: ~37px per floor). HUD line layout follows this project's established bottom-strip convention (see [`1/CLAUDE.md`](../1/CLAUDE.md) and [`3/DESIGN.md`](../3/DESIGN.md)); which of the two 2 lines a given piece of information sits on is TBD.

## Palette

Not yet decided. Every row below is a placeholder pending the palette question in README's Open questions.

| Element | Colour | Index |
| ------- | ------ | ----- |
| Elevator car | TBD | TBD |
| Corridor / room floor | TBD | TBD |
| Centre lift | TBD | TBD |
| Robot | TBD | TBD |
| Object (can, desk, vending machine, shelf) | TBD | TBD |
| Health pickup | TBD | TBD |
| Letter tile | TBD | TBD |
| Player | TBD | TBD |
| HUD text | TBD | TBD |

## State machine

| `gs` | Name | Entered from | Exits to |
| ---- | ---- | ------------- | -------- |
| 0 | Title | startup | 1 (any button) |
| 1 | Elevator shaft | title; exiting a room | 2 (entering a corridor) |
| 2 | Puzzle room | elevator shaft, via corridor | 1 (exit through entry door); 3 (reaching the control room) |
| 3 | Control room | last puzzle room found | 4 (puzzle solved, or timer/HP hits 0) |
| 4 | Game over | any state, on loss/win condition | 0 (any button) |

`won` (bool) set when state 3 is exited via a solved puzzle rather than timer/HP hitting 0; the game-over screen branches on this flag, matching the pattern in [`3/DESIGN.md`](../3/DESIGN.md).

## Core system design

**Floor/room generation** — Floors along the elevator shaft are randomized (left corridor, right corridor, both, or neither) from a seed, so a given seed reproduces the same building. Puzzle rooms draw from 4 layout patterns (patterns themselves not yet designed); placement rules cap each floor side at 1 robot and 2 objects. The secret word and the solvability of every puzzle must hold for any seed the generator produces, which likely means generate-then-validate rather than generate-and-hope.

**Search mechanic** — Pressing up in front of an object starts a 10-step progress bar, roughly 1 second per step (about 30 frames per step at 30fps, 300 frames total). On completion, the object's contents (health or a letter) are added to the player's inventory.

**Robot behaviour** — 3 patterns per robot, chosen at placement time: stationary-look (random-interval left/right look with a beep), patrol (left/right at a set speed, random pause at each end), and chase (moves toward the player at a random speed when on the same floor; pauses and reverses if the player jumps over it).

**Collision** — Player vs. robot: HP loss (amount TBD). Player vs. lift shaft edge while not in the lift: HP loss (amount TBD, see README's Open questions).

## Token budget

This design carries more concurrent state than games 1 or 3: per-room robot AI (3 behaviour variants), a search progress-bar timer, a 3-floor room layout, and a seeded floor/puzzle generator that must validate solvability. Lean on [`../lib/CLAUDE.md`](../lib/CLAUDE.md) for input handling, the state machine, and seeded RNG rather than rederiving them; the robot behaviour table is a good candidate for a flat array indexed by pattern id rather than per-pattern branching code.
