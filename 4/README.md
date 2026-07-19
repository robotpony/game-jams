# Gyri #4

This is an arcade shooter built using Claude and Pico-8. Follows the format in [`../SPEC-FORMAT.md`](../SPEC-FORMAT.md).

The game looks like an Atari 2600 game. Colours, sprites, and fonts should approximate the Atari 2600 aesthetic using Pico-8's palette. It's a Space Invaders/Galaga-style shooter with the player's straight firing line replaced by a curved one.

**Status: not yet built.** Several details below aren't decided yet; see [Open questions](#open-questions).

## Game overview

The player's ship holds a fixed angular position on an arc near the bottom of the screen, an inverted-rainbow curve whose implied centre sits off-screen below the play area. Moving left or right sweeps the ship's position along that arc rather than sliding it along a straight line. Firing releases a shot that travels outward along the radius line running from the implied centre through the ship's current position, so a shot's exact direction depends on wherever the ship happens to be on the arc when it fires: a shot from the left end of the arc angles up and to the left, a shot from the middle fires straight up, and so on.

Enemies occupy the space above the ship's arc, arranged on their own concentric arcs at smaller radii from the same implied centre. They sweep back and forth along their arcs, echoing Galaga's formation movement translated onto a curved field. A wave clears once every enemy on it is destroyed.

## Scenes

| Scene | Shows | Enters from | Exits to |
| ----- | ----- | ------------ | -------- |
| Title | Shared jam title card: colour-swatch strip, "'26 WARPED GAME JAM", "GYRI #4", blinking start prompt | Startup | Any button → Game |
| Game | Arc playfield (ship and enemies on concentric arcs), HUD | Title, or Wave transition complete | All enemies on the current wave destroyed → Wave transition; lives reach 0 → End |
| Wave transition | Brief "WAVE n" text overlay over the frozen playfield | All enemies on the current wave destroyed | Transition complete (duration not yet decided) → Game, next wave loaded |
| End | Final score, wave reached | Game, on lives reaching 0 | Any button → Title |

## Arc movement & radial shooting

- The ship's position is an angle along a fixed-radius arc, not an x-coordinate; left/right input changes that angle, clamped to the arc's endpoints.
- The ship's arc is a full 180° half-circle, radius 64px, centred at (64, 103): apex (ship centred) at (64, 39), endpoints at (0, 103) and (128, 103), edge to edge. This caps the arc's height at 64px, 50% of the 128px screen, the widest a true half-circle can be without exceeding the screen: for a semicircle, width is always exactly 2× height, so the height cap and the screen's own width cap saturate at the same point.
- The ship's sprite is 8×8, so the usable angular range is trimmed a few degrees short of the full ±90° to keep the sprite from clipping off-screen at the extremes; the exact trim isn't decided yet (see Open questions).
- Firing releases a shot along the radius line through the ship's current angle, continuing outward (away from the implied off-screen centre) until it leaves the screen or hits an enemy.
- Enemies live on their own concentric arcs, at smaller radii than the ship's arc (visually higher up the screen, closer to the implied centre), and move angularly along those arcs.
- Whether enemies also fire back, and along what trajectory, isn't decided yet; see Open questions.
- Near the apex the ship's horizontal speed (for a given angular input speed) is fastest; near the endpoints it's nearly all vertical. Movement will feel like it decelerates horizontally approaching either end of the sweep, a consequence of the geometry rather than a tuning choice, worth playtesting once built.

## Player

- Moves left/right along the arc; movement is angular, not linear.
- Fires a single shot type along the radial trajectory described above; fire rate and shot speed aren't decided yet.
- Resources: lives (starting count not yet decided) and score.

## Game over conditions

- Player lives reach 0.

No win condition is defined yet: whether the game ends after a fixed number of waves or continues indefinitely with escalating difficulty until the player runs out of lives isn't decided. See Open questions.

## Sound

Not yet decided; no sound event has a chosen character yet. Events that will need one: ship fire, enemy destroyed, player hit, wave clear, game over. See Open questions.

## Tile / sprite visuals

Not yet decided; no palette or per-tile visuals have been chosen. See Open questions for the full list of elements that need one.

## Progression

Difficulty increases wave over wave (more enemies, faster movement, or additional enemy arcs), but the exact ramp formula and wave count aren't decided yet. See Open questions.

## Open questions

- **Ship angular trim**: how many degrees short of the full ±90° the ship's sweep is clamped, to keep its 8×8 sprite fully on-screen at the endpoints.
- **Enemy arcs**: how many concentric enemy arcs exist, their radii (necessarily smaller than the ship's 64px), and how many enemies sit on each.
- **Enemy attack behaviour**: do enemies fire shots at the ship? If so, along what trajectory (radial toward the ship, straight down, or something else)? Do enemies ever break formation and dive, the way Galaga's do?
- **Lives**: starting count.
- **Fire rate / shot speed**: cooldown between shots, and how fast a shot travels.
- **Win condition**: a fixed number of waves to clear, or an endless run that only ends in a loss?
- **Wave-transition duration**: how many frames the "WAVE n" overlay holds before gameplay resumes.
- **Scoring**: points per enemy destroyed, and whether that value varies by enemy type or arc.
- **Palette and tile visuals**: colours and shapes for the ship, enemies, shots, and the arc/playfield boundary itself.
- **Sound events**: ship fire, enemy destroyed, player hit, wave clear, game over.
