# 2 README

This is an action/platform/puzzle game built using Claude and Pico-8. Follows the format in [`../SPEC-FORMAT.md`](../SPEC-FORMAT.md).

The game looks like an Atari 2600 game. Colours, sprites, and fonts should approximate the Atari 2600 aesthetic using Pico-8's palette. It's a vastly simplified remake of Impossible Mission (Epyx, 1984).

**Status: not yet built.** Design is finalized; no `.p8` cartridge exists in this folder yet.

## Game overview

The player starts in an elevator, viewed from the side as if the wall is cut away. The elevator moves up or down and automatically stops, but only at floors that have a corridor; floors with neither are simply scrolled past. It hums softly with a faint buzz while moving.

The shaft has 16 floors. Each floor is randomized as having a left corridor, a right corridor, both, or neither; a floor with both leads to two independent rooms, one off each side. The shaft itself is narrow, and a corridor isn't a separate place: on a floor with an open corridor, the walkable area of that same elevator screen simply extends from the shaft out to the screen's edge, where the door is. The player walks out of the narrow shaft column, across the blank corridor stretch, and through that edge door into the room, arriving on its bottom floor. Entering from the left, the player arrives beside the room's right-hand wall walking further left; entering from the right, beside its left-hand wall walking further right; movement stays continuous in the same direction the whole trip, and crossing either door pauses briefly (about 300ms) before control returns, in both directions. Most rooms have 3 floors connected by an automatically moving centre lift, with robots and searchable objects (garbage cans, desks with computers, vending machines, shelves, and the occasional terminal) on each floor. A room's state persists once generated: searched objects stay empty and robots keep their position if the player leaves and comes back.

Searching an object can yield health, extra time, or a puzzle-piece letter, one of a set of 10 that spell a secret word (picked per seed from a short word list); a terminal instead opens a reusable help screen. The generator guarantees at least 10 valid rooms among the 16 floors and places one letter in each of the first 10; every other non-terminal object holds health or a clock instead. The control room sits behind the last (deepest) valid room in the shaft. Reaching it shows the secret word as blank letter slots; the player arranges their collected letters into the blanks and submits. A correct arrangement wins; a wrong one costs 1 HP and can be retried without limit.

## Scenes

| Scene | Shows | Enters from | Exits to |
| ----- | ----- | ------------ | -------- |
| Title | "#2 Mission" / "'26 WARPED GAME JAM" | Startup | Any button → Intro |
| Intro | Placeholder transition text, "stay a while, solve a puzzle!" | Title, any button | ~3 seconds elapsed, or any button → Elevator shaft |
| Elevator shaft | Vertical shaft, 16 randomized floors scrolling by (auto-stopping only at corridor floors), top and bottom bounds; a floor's corridor is part of this same screen, extending from the shaft to a door at the screen edge | The Intro screen; walking back out of a puzzle room | Walking through an edge door on a corridor floor → Puzzle room |
| Puzzle room | 3 floors of robots and objects, centre lift, player standing beside the entry door on the bottom floor | The elevator shaft, through a floor's edge door (a "both" floor's two doors lead to two independent rooms) | Walking back out the entry door → Elevator shaft; reaching the control room (far side of the last valid room in the shaft) → Control room; completing a terminal search → Help |
| Help | Full-screen overlay: controls, the letter/win goal, and an object legend; gameplay is paused (timer, robots) while shown | Completing a search on a terminal object, from any puzzle room | Any button → back to the puzzle room, unpaused |
| Control room | Blank letter slots for the secret word; player arranges collected letters and submits | The last valid puzzle room in the shaft | Correct arrangement → Game over (win); timer or HP hits 0 → Game over (loss), any time; wrong arrangement costs 1 HP, stays in Control room |
| Game over | Final score, win or lose state | Timer reaches 0; HP reaches 0; puzzle solved in Control room | Any button → Title |

Transitions: elevator movement implies scrolling by floor as it moves (constant per game, may be randomized between games). Entering or exiting a room fades in/out. Game start and end flash.

## Elevator & rooms

- Layout: title screen (Intellivision-style, per the 2026 jam guide); elevator shaft screen (corridors are part of this screen, not separate); puzzle room screen; control room screen.
- Generation: 16 floors, each randomized as left corridor, right corridor, both (two independent rooms), or neither, seeded. The generator re-rolls the seed until at least 10 floors resolve to a valid room. Puzzle rooms are randomized from 4 patterns that vary robot and object density per floor side (light/medium/heavy), not room structure. Puzzles must be solvable, and robots must be jumpable with skill.
- The elevator only stops at floors with a corridor; a "neither" floor is scrolled past without stopping. If the shaft's very top or bottom floor happens to be "neither", the car simply can't reach it — it stops at the nearest corridor floor instead.
- Corridor: not a separate place, just the part of the elevator screen between the narrow shaft column and the screen's edge, on any floor with an open corridor on that side. Same blank background as the rest of the shaft. No objects or robots in it, just floor space to walk across; jumping there is just a faster way to cross it, since there's nothing to clear.
- Centre lift: a platform moving automatically between a room's 3 floors, pausing briefly at each. While riding it, the player can move and jump freely, the same as standing on any floor or corridor; walking off either edge lands on whichever floor the lift is nearest to, and jumping off it can catch the lift again mid-air (whether it's paused or moving) or miss it entirely. The bottom floor is solid ground, walkable straight across; only the gap on the top and middle floors is a hazard. Walking or jumping into an open gap while the lift isn't there starts a real fall, not an instant penalty: drifting sideways under momentum lands safely on whichever floor below is reached, and catching the lift mid-transit also lands safely. Falling all the way to the bottom floor costs HP scaled to how far the player fell (1 HP from the middle floor, 2 HP from the top), landing them there in place rather than resetting to the room's entry door.
- Secret word: 10 letters, picked per seed from a short hardcoded word list (`IMPOSSIBLE`, `INFILTRATE`, `DEMOLITION`, `ELECTRICAL`, `MECHANICAL`). One letter is placed in each of the first 10 valid rooms (in shaft order); every object in rooms beyond the 10th holds a health pickup instead. The control room sits behind the last valid room in the shaft, whatever that room's letter status.
- Room persistence: once a room is generated, its state sticks. Objects already searched stay empty and robots keep their current position and pattern state if the player leaves and returns.
- Placement rules: no more than 1 robot per floor side (left or right); no more than 2 items per floor side. A robot never crosses the centre lift gap; it's confined to the side of the floor it spawned on, for every movement pattern, including chase.
- Search: standing in front of an object and holding up raises the player's hands. A comic-style bubble appears above the player with a progress bar, 0 to 10, about half a second per step. An object's contents stay hidden until the search actually starts, at which point its icon (health cross, letter tile, clock, or terminal) shows inside the bubble alongside the progress count — checking every object is the only way to know what it holds. At 10, the object's contents are added to the player's inventory (or, for a clock, added to the timer) and the bubble disappears; finding a letter also shows a brief "found: X" popup with the letter tile. Searching a terminal instead opens a full-screen help overlay (controls, the letter/win goal, and an object legend), still 10 steps but each one twice as fast (~2.5s total); the screen pauses the game and ignores input for the first 3 seconds, so it can't be closed before it's readable, then dismisses on any button. A terminal isn't consumed by this, so it can be searched again later. Releasing up (or getting hit) pauses the bar at its current step rather than resetting it, and holding up again in front of the same object resumes from there — except for a terminal, where releasing early cancels the attempt back to 0 instead of pausing it.
- Robots, 3 movement patterns:
  - Stationary: looks left and right at random intervals, beeping on each look.
  - Patrol: moves left and right at some speed, pausing a random amount of time at each end.
  - Chase: moves toward the player at a random speed if the player is on the same floor, confined to its own side of the centre lift gap (it won't follow the player across). If the player jumps over it, the robot pauses, "thinks" for about 1 second, then reverses direction. Also pauses briefly whenever the direction it needs to move actually changes (e.g. the player crosses from one side of it to the other), rather than reversing instantly.
- Difficulty ramps with rooms found: robot speed and density scale up as the player collects more letters, similar in spirit to game 3's fall-speed ramp.
- Puzzle solving: the control room shows one blank slot per letter of the secret word. The player arranges their collected letters into the blanks (directional input to cycle/place) and submits. A correct arrangement wins immediately; a wrong one costs 1 HP and can be retried without limit.

## Player

- Standing (idle pose, same for both facings). Running: a 4-frame leg/arm cycle, drawn as separate left-facing and right-facing sequences (not mirrored). Searching: a 2-frame animated loop, hands raised and reaching, direction-neutral (shown facing whichever way the player last moved). Jumping: a 4-frame flip sequence (launch, tuck, extend, land) stepped through by the jump arc's progress, drawn as separate left-facing and right-facing sequences matching the jump's horizontal direction; a straight-up jump (no horizontal direction) uses the right-facing sequence by default.
- Moves left or right; moves up or down while in an elevator shaft.
- Up always jumps, except: while standing in the elevator car's narrow column (up/down there moves the car instead — this doesn't apply out in a corridor, where jumping works normally), while riding the centre lift, or while searching a found object (up there advances the search instead). Jump direction follows whichever way the player is currently moving, or straight up if they aren't.
- Jumping is a fixed parabolic arc (Mario-style), not an instant hop: higher and slower than a quick hop would be, deliberately floaty, with enough horizontal reach to clear a robot or the lift shaft's gap with margin to spare, not just barely. Used to clear either hazard, or just to move faster.
- Player steps make a percussive sound.
- Resources:
  - HP starts at 5. A robot hit costs 1 HP plus a brief knockback; falling all the way to the bottom floor during a lift-shaft fall costs 1-2 HP depending on how far the player fell (a fall can also be recovered from safely, see Elevator & rooms); a wrong puzzle submission in the control room costs 1 HP.
  - Inventory begins with one letter.

## Items

| Item | Effect | Visual feedback |
| ---- | ------ | --------------- |
| Health pickup | Restores 2 HP | Object contents are hidden until a search actually starts (design reversal — see Elevator & rooms); a green cross/plus icon then shows in the search progress bubble, added to inventory once the search completes |
| Puzzle letter | Adds one letter to inventory, toward the secret word (1 of 10 total) | Hidden until search starts; a yellow letter tile with the letter shows in the search progress bubble, added to inventory once the search completes |
| Clock | Adds 60 seconds to the timer | Hidden until search starts; a clock icon shows in the search progress bubble. Roughly 1 in 4 non-letter objects are a clock instead of health |
| Terminal | Opens a help screen (controls, letter/win goal, object legend); pauses the game while shown, and ignores input for the first 3 seconds so it can't be dismissed before it's even readable | Its own furniture kind, only placed on the bottom floor next to the entry door (not a random fill of the other 4 anywhere in the room), always shows a terminal icon in the search bubble. Still a full 10-step search, but each step is twice as fast as normal (~2.5s total); releasing up before completion cancels the attempt entirely, unlike every other object, which only pauses. Reusable — searching it again re-opens the help screen, it's never consumed |

## Game over conditions

- Timer reaches 0. Starts at 300 seconds (5 minutes), never resets mid-run.
- Player HP reaches 0.
- Player reaches the control room and submits the correct letter arrangement (win). Score is `100 × letters collected + 2 × seconds remaining` on a win, 0 on a loss.

## Sound

| Event | Description |
| ----- | ------------ |
| Elevator moving | Soft hum with a faint buzz |
| Elevator ambient loop | Low, tense ambient pad, loops only while in the elevator shaft; silent in puzzle rooms and elsewhere |
| Room door (enter/exit) | Short percussive thunk, decaying noise hit |
| Player footstep | Percussive |
| Player jump | Quick rising whoosh |
| Player landing | Short percussive thump, on completing a jump's arc |
| Robot look/turn | Two-note "bleep-bloop", on every look-flip, patrol turn, chase direction change, and the chase "thinks" pause; capped at once per 3 seconds per robot, so a robot rapidly re-triggering (e.g. jittering right at the player's position while chasing) doesn't spam it |
| Robot move | Short buzzy blip, repeated periodically while actively moving (patrol, chase, or fleeing) |
| Robot hit (player) | Harsh, low percussive/noise hit |
| Search progress tick | Short blip, once per progress step |
| Search completion | Celebratory major chord (ascending arpeggio: root, third, fifth, octave) |
| Item pickup: health | Warm ascending tone |
| Item pickup: letter | Twinkling chime, distinct from the health tone |
| Win | Triumphant ascending run |
| Loss | Descending buzz |

This game's SFX set is a distinct identity from games 1 and 3, not a reuse of their runs.

## Tile / sprite visuals

Palette reuses game 1's Atari-2600-approximation colour index list; see [DESIGN.md](DESIGN.md) for the per-element colour table.

| Tile / sprite | Colour | Visual description |
| ------------- | ------ | ------------------- |
| Elevator car | Sky blue | Boxy car frame around the player, open on the side facing the shaft |
| Corridor / room floor | Dark blue | Flat institutional floor and back wall |
| Centre lift | Teal | Vertical platform strip, animates moving top to bottom |
| Robot | 1 of 3 random skins: red/dark red legs/white lights, solid red/yellow lights, or purple/white lights | Inverted-U arch on two legs; direction lights blink and shift to whichever side matches its current travel/look direction |
| Object (can, desk, vending machine, shelf) | Dark green, brown, or dark grey | Distinct 8×8 silhouette per object type; each instance randomly picks 1 of 3 colour variants (same silhouette) |
| Terminal | Light grey | Monitor-and-base silhouette, single fixed look (no colour variants, unlike the other 4 object kinds) |
| Health pickup | Green | Cross/plus glyph, shown in the search progress bubble once searching starts |
| Letter tile | Yellow | Yellow tile badge with the letter printed in black, shown in the search progress bubble once searching starts |
| Clock | White | Circular clock-face glyph with hands, shown in the search progress bubble once searching starts |
| Player | White | Stand, or animated sequences: run (4-frame, separate left/right), search (2-frame, direction-neutral), jump (4-frame flip, separate left/right) |
| HUD text | White | Bottom two lines, over a black strip |
| Help screen | Neon green text, light grey border | Full-screen black background with a bezel-style border frame, evoking a terminal display |
