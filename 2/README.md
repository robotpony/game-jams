# #2 Somewhat possible mission

This is an action/platform/puzzle game built using Claude and Pico-8. Follows the format in [`../SPEC-FORMAT.md`](../SPEC-FORMAT.md).

The game looks like an Atari 2600 game. Colours, sprites, and fonts should approximate the Atari 2600 aesthetic using Pico-8's palette. It's a vastly simplified remake of Impossible Mission (Epyx, 1984).

## Game overview

The player starts in an elevator, viewed from the side as if the wall is cut away. It moves up or down, auto-stopping at floors with a corridor and humming with a faint buzz while it moves. Floors with no corridor just scroll past.

Each floor may have a corridor on the left, the right, both, or neither. A corridor isn't a separate screen: it's just the elevator screen's walkable area extending out to a door at the screen edge. Walking through a door leads into a room. Most rooms have 3 floors linked by an automatic centre lift, with robots and searchable objects (garbage cans, desks, vending machines, shelves, and the occasional terminal) on each floor. A room's state persists: searched objects and robot positions carry over if the player leaves and comes back. See [Elevator & rooms](#elevator--rooms) for the exact entry/exit rules.

Searching an object can yield health, extra time, or a puzzle-piece letter; a terminal instead opens a reusable help screen. Ten letters, found across the first 10 valid rooms, spell a secret word. The control room, behind the last valid room in the shaft, shows the word as blank slots; the player arranges their letters into the blanks and submits. A correct arrangement wins; a wrong one costs 1 HP and can be retried without limit.

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
- Centre lift: a platform moving automatically between a room's 3 floors, pausing briefly at each. While riding it, the player can move and jump freely, the same as on any floor or corridor. Walking off either edge lands on whichever floor the lift is nearest to. Jumping off it can catch the lift again mid-air (whether it's paused or moving) or miss it entirely.
- The bottom floor is solid ground, walkable straight across; only the gap on the top and middle floors is a hazard. Walking or jumping into an open gap while the lift isn't there starts a real fall, not an instant penalty: drifting sideways under momentum lands safely on whichever floor below is reached, and catching the lift mid-transit also lands safely. Falling all the way down costs HP scaled to the distance fallen (1 HP from the middle floor, 2 HP from the top), landing the player in place rather than resetting them to the room's entry door.
- Secret word: 10 letters, picked per seed from a short hardcoded word list (`IMPOSSIBLE`, `INFILTRATE`, `DEMOLITION`, `ELECTRICAL`, `MECHANICAL`). One letter is placed in each of the first 10 valid rooms (in shaft order); every object in rooms beyond the 10th holds a health pickup instead. The control room sits behind the last valid room in the shaft, whatever that room's letter status.
- Room persistence: once a room is generated, its state sticks. Objects already searched stay empty and robots keep their current position and pattern state if the player leaves and returns.
- Placement rules: no more than 1 robot per floor side (left or right); no more than 2 items per floor side. A robot never crosses the centre lift gap; it's confined to the side of the floor it spawned on, for every movement pattern, including chase.
- Search: standing in front of an object and holding up raises the player's hands. A comic-style bubble appears above the player with a progress bar, 0 to 10, about half a second per step. An object's contents stay hidden until the search actually starts; checking every object is the only way to know what it holds. At 10, the contents are added to the player's inventory (or, for a clock, the timer) and the bubble disappears; finding a letter also shows a brief "found: X" popup. Releasing up, or getting hit, pauses the bar at its current step rather than resetting it; holding up again resumes from there.
- Terminal search works the same way but at double speed (~2.5s total) and opens a full-screen help overlay instead of adding to inventory. The overlay pauses the game and ignores input for the first 3 seconds, so it can't be closed before it's readable, then dismisses on any button. A terminal isn't consumed, so it can be searched again later; releasing up early cancels its progress back to 0 instead of pausing it.
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
  - Inventory begins empty.

## Items

| Item | Effect | Visual feedback |
| ---- | ------ | --------------- |
| Health pickup | Restores 2 HP | Green cross/plus icon, revealed in the search bubble once searching starts |
| Puzzle letter | Adds one letter to inventory (1 of 10 total) | Yellow letter tile, revealed in the search bubble; also triggers the "found: X" popup |
| Clock | Adds 60 seconds to the timer | Clock icon, revealed in the search bubble. Roughly 1 in 4 non-letter objects is a clock instead of health |
| Terminal | Opens a reusable help screen (controls, letter/win goal, object legend); see Search above for its timing | Terminal icon; only placed on the bottom floor next to the entry door, never elsewhere |

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
| Robot look/turn | Two-note "bleep-bloop", on every look-flip, patrol turn, chase direction change, and the chase "thinks" pause |
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
