# 2 README

This is an action/platform/puzzle game built using Claude and Pico-8. Follows the format in [`../SPEC-FORMAT.md`](../SPEC-FORMAT.md).

The game looks like an Atari 2600 game. Colours, sprites, and fonts should approximate the Atari 2600 aesthetic using Pico-8's palette. It's a vastly simplified remake of Impossible Mission (Epyx, 1984).

**Status: not yet built.** Several details below aren't decided yet; see [Open questions](#open-questions).

## Game overview

The player starts in an elevator, viewed from the side as if the wall is cut away. The elevator moves up or down and stops at any floor it finds, humming softly with a faint buzz while moving.

Each floor has corridors to the left and/or right, each leading to a room just off screen. Entering a corridor puts the player in the room on the other side, standing beside the door they came in through. Most rooms have 3 floors connected by an automatically moving centre lift, with robots and searchable objects (garbage cans, desks with computers, vending machines, shelves) on each floor.

Searching an object can yield health or a puzzle-piece letter, one of a set of 10 that spell a secret word. Finding the control room and solving the puzzle wins the game.

## Scenes

| Scene | Shows | Enters from | Exits to |
| ----- | ----- | ------------ | -------- |
| Title | "#2 Mission" / "'26 WARPED GAME JAM" | Startup | Any button → Elevator shaft |
| Elevator shaft | Vertical shaft, randomized floors scrolling by, top and bottom bounds | Title; exiting a room back through its door | Moving left/right into a floor's corridor → Puzzle room |
| Puzzle room | 3 floors of robots and objects, centre lift, player standing beside the entry door | Elevator shaft, via a floor's corridor | Exiting back through the entry door → Elevator shaft; reaching the control room (far side of the last room found) → Control room |
| Control room | Final room | The last puzzle room found | Puzzle solved → Game over (win); timer or HP hits 0 → Game over (loss), any time |
| Game over | Final score, win or lose state | Timer reaches 0; HP reaches 0; puzzle solved in Control room | Any button → Title |

Transitions: elevator movement implies scrolling by floor as it moves (constant per game, may be randomized between games). Entering or exiting a room fades in/out. Game start and end flash.

## Elevator & rooms

- Layout: title screen (Intellivision-style, per the 2026 jam guide); elevator shaft screen; puzzle room screen.
- Generation: floors are randomized (left, right corridor, or both), seeded. Puzzles are randomized from 4 patterns. Puzzles must be solvable, and robots must be jumpable with skill. The secret word must be solvable.
- Placement rules: no more than 1 robot per floor side (left or right); no more than 2 items per floor side.
- Search: standing in front of an object and pressing up raises the player's hands. A comic-style bubble appears above the player with a progress bar, 0 to 10, about 1 second per step. At 10, the object's contents (health or a puzzle letter) are added to the player's inventory and the bubble disappears.
- Robots, 3 movement patterns:
  - Stationary: looks left and right at random intervals, beeping on each look.
  - Patrol: moves left and right at some speed, pausing a random amount of time at each end.
  - Chase: moves toward the player at a random speed if the player is on the same floor. If the player jumps over it, the robot pauses, "thinks," then reverses direction.

## Player

- Running (3-frame animation) or standing (in the elevator, at rest, or searching); searching raises the player's hands.
- Moves left or right; moves up or down while in an elevator shaft.
- Pressing up outside an elevator triggers a search on a found object, or a jump (in the direction of movement, or straight up if the player isn't moving).
- Jumping clears lift shafts and robots, or is used to move faster.
- Player steps make a percussive sound.
- Resources:
  - HP starts at 5. Lost when hit by a robot, or from falling down a lift shaft (amount per hit not yet decided, see Open questions).
  - Inventory begins with one letter.

## Items

| Item | Effect | Visual feedback |
| ---- | ------ | --------------- |
| Health pickup | Restores HP (amount not yet decided) | Object yields contents once a search completes |
| Puzzle letter | Adds one letter to inventory, toward the secret word (1 of 10 total) | Object yields contents once a search completes |

## Game over conditions

- Timer reaches 0.
- Player HP reaches 0.
- Player finds the control room and solves the puzzle (win).

## Sound

| Event | Description |
| ----- | ------------ |
| Elevator moving | Soft hum with a faint buzz |
| Player footstep | Percussive |
| Robot look | Beep |

Not yet decided: search completion, item pickup (health vs. letter), robot hit, jump, win, and loss sounds. See Open questions.

## Tile / sprite visuals

Not yet decided; no palette or per-tile visuals have been chosen. See Open questions for the full list of elements that need one.

## Open questions

- **Health pickup value**: how much HP does a health object restore?
- **Robot/fall damage**: how much HP does a robot hit cost? Is a lift-shaft fall the same amount?
- **Puzzle piece distribution**: the secret word draws from a set of 10 letters across 8 rooms. Is every piece guaranteed to appear once, or is placement random (allowing duplicates or gaps)?
- **Score**: the original screens list mentions a score shown on the game-over screen, but no scoring system is defined anywhere else. Does this game have a score, or is HP/timer/secret-word the only state that matters?
- **Timer**: starting value, and whether anything resets it mid-run.
- **Control room location**: is it fixed behind a specific room (e.g. the 8th), or determined dynamically by whichever room the player happens to reach last?
- **Palette and tile visuals**: colours and shapes for the elevator car, corridor walls, room floors, the centre lift, robots, each object type (garbage can, desk/computer, vending machine, shelf), health pickups, and letter tiles.
- **Missing sound events**: search completion, item pickup, robot hit, jump, win, loss.
