# Gyri #4

This is an arcade shooter built using Claude and Pico-8. Follows the format in [`../SPEC-FORMAT.md`](../SPEC-FORMAT.md).

The game looks like an Atari 2600 game. Colours, sprites, and fonts approximate the Atari 2600 aesthetic using Pico-8's palette. It's a Space Invaders/Galaga-style shooter with the player's straight firing line replaced by a curved one.

**Status: Phase 1 of 8 implemented** (ship arc movement and hold-to-fire shooting, placeholder visuals only — see [CLAUDE.md](CLAUDE.md)). Design for all phases is locked; see [DESIGN.md](DESIGN.md) for exact numbers and [PLAN.md](PLAN.md) for the build order.

## Game overview

The player's ship holds a fixed angular position on an arc near the bottom of the screen, an inverted-rainbow curve whose implied centre sits off-screen above the play area, so the arc opens upward like a U rather than curving over the ship like a dome — the ship rests low in the middle and sweeps up toward the screen edges. Moving left or right sweeps the ship's position along that arc rather than sliding it along a straight line. Firing is hold-to-fire: holding the button repeats shots at a fast, steady rate, each travelling inward along the radius line running from the ship's current position toward the implied centre (and therefore up, toward the enemies). A shot's exact direction depends on wherever the ship happens to be on the arc when it fires: a shot from the left end angles up and to the left, a shot from the middle fires straight up, and so on.

Enemies occupy three concentric arcs above the ship, in a full Galaga-scale formation (18 enemies on wave 1). They sweep back and forth along their arcs, periodically fire radial shots back at the ship along the same kind of trajectory the player uses, and occasionally break formation to dive at the ship. A wave clears once every enemy on it is destroyed. The run is endless: there's no final wave, only an escalating one, and it ends when the player runs out of lives.

## Scenes

| Scene | Shows | Enters from | Exits to |
| ----- | ----- | ------------ | -------- |
| Title | Shared jam title card: colour-swatch strip, "'26 WARPED GAME JAM", "GYRI #4", blinking start prompt | Startup | Any button → Game |
| Game | Arc playfield (ship and enemies on concentric arcs), scanline grid, HUD | Title, or wave transition complete | All enemies on the current wave destroyed → Wave transition; lives reach 0 → End |
| Wave transition | Brief "WAVE n" text overlay over the frozen playfield | All enemies on the current wave destroyed | 36 frames (1.2s) elapsed → Game, next wave loaded |
| End | Final score, wave reached | Game, on lives reaching 0 | Any button → Title |

## Core mechanic: arc movement & radial shooting

- The ship's position is an angle along a fixed-radius arc, not an x-coordinate; left/right input changes that angle, clamped to ±69° from the arc's centre point (a ~21° trim off the true ±90° endpoints, so the ship's 8×8 sprite stays fully on-screen; derivation in DESIGN.md).
- The ship's arc is a 180° half-circle, radius 64px, centred at (64, 25): the ship's centred resting position is at (64, 89), the lowest point of the valley, and the untrimmed endpoints reach exactly (0, 25) and (128, 25), the screen's left and right edges.
- Holding fire releases shots at a fixed cooldown, each travelling along the radius line through the ship's angle at the moment it was fired, continuing inward (toward the centre, i.e. up) until off-screen or it hits an enemy.
- Enemies live on three concentric arcs at smaller radii than the ship's own arc (53px, 43px, 33px; smaller radius puts them closer to the centre and therefore higher on screen, since the shared centre sits above the ship — see DESIGN.md for the full derivation). Each arc's angular sweep is a band, not the full semicircle, chosen for a formation look rather than out of necessity (these radii stay on-screen even at the full ±90°).
- Enemies sweep back and forth along their arc, periodically fire radial shots toward the ship, and occasionally break formation to dive; frequency of both increases with wave number (see Progression).
- A diving enemy that misses doesn't die or leave the wave: it reappears at the top of its arc and attacks again, faster and more often each time it misses. A wave only ever clears by killing every enemy on it.

## Player

- Moves left/right along the arc; movement is angular, not linear, clamped to ±69°.
- Hold-to-fire: shots repeat automatically while held, 4 frames apart, travelling at 4px/frame along the radial trajectory.
- Resources: 5 starting lives, score.
- A fixed outline/highlight colour (white, index 7) marks the ship regardless of wave; every other on-screen colour re-tints per wave (see DESIGN.md Palette), so the ship stays the one constant visual anchor.

## Game over conditions

- Player lives reach 0.

There's no win condition. The run is endless; difficulty escalates wave over wave until the player dies (see Progression).

## Sound

| Trigger | Character |
| ------- | --------- |
| Ship fire | Short, punchy blip — deliberately breaks from the game's otherwise atmospheric palette, since a sustained tone retriggered on every hold-to-fire shot would choke Pico-8's 4 sound channels |
| Enemy destroyed | Atmospheric, sustained tone |
| Player hit | Atmospheric, sustained tone, lower/harsher than enemy destroyed |
| Enemy dive start | Atmospheric, sustained rising tone |
| Wave clear | Atmospheric, sustained ascending chord |
| Game over | Atmospheric, sustained descending tone |

## Tile / sprite visuals

| Element | Colour | Description |
| ------- | ------ | ------------ |
| Ship | White (7), fixed, never re-tints | Rocket-wedge silhouette, native 8×8 |
| Enemy (inner/middle tier) | Wave theme colour, rotates (see DESIGN.md Palette) | Distinct wing silhouette, native 8×8 |
| Enemy (outer tier) | Wave theme colour, rotates | Same wing silhouette, drawn at 10×10 via `sspr` scaling, a "worth more" visual cue for the highest-scoring arc |
| Ship shot | White (7) | One of 3 shared shot sprites (straight/shallow/steep), picked and mirrored by travel angle, pointing inward/up |
| Enemy shot | Matches that wave's enemy colour | Same 3 shared shot sprites, `flip_y`'d to point outward/down |
| Background grid | Wave theme colours, brightest near the bottom fading to black near the horizon | Horizontal scanlines, foreground to horizon (see DESIGN.md) |

## Progression

Wave-to-wave escalation (exact formulas in DESIGN.md's Core system design): enemy count, enemy speed, and enemy aggression (dive frequency and fire rate) all increase with wave number. Enemy count is capped at 24 (leaving headroom under the 32-entity concurrent cap for enemy shots); once the count cap is hit, speed and aggression carry the rest of the difficulty curve.
