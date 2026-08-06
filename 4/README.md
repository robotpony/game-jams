# Gyri #4

In the spirit of Gyrus and Galaga, Gyri is a small space shooter.

## Details

This is an arcade shooter built using Claude, following the format in [`../SPEC-FORMAT.md`](../SPEC-FORMAT.md).

The game looks like an Atari 2600 game. Colours, sprites, and fonts approximate the Atari 2600 aesthetic. It's a Space Invaders/Galaga-style shooter with the player's straight firing line replaced by a curved one.

| Folder | Status | Note |
| ------ | ------ | ---- |
| [`pico-8/`](pico-8/) | Phase 7 of 8 implemented, plus several play-test follow-up passes | Real sprites, sound, and screens are in; only Phase 8's final token/performance check remains — see [`pico-8/CLAUDE.md`](pico-8/CLAUDE.md) |
| [`tic-80/`](tic-80/) | Design not started | Planned as an expanded upscale (bigger playfield, richer sprites, deeper sound/music, new mechanics), not a straight port — see [`tic-80/CLAUDE.md`](tic-80/CLAUDE.md) |

This README describes the game at the level that's shared across both: overview, scenes, core mechanic, player state, game-over conditions. Exact numbers, palettes, and sprite/sound detail live in each platform's own `DESIGN.md`, since those differ by build.

## Game overview

The player's ship holds a fixed angular position on an arc near the bottom of the screen, rather than an x-coordinate. The arc's implied centre sits off-screen above the play area, so it opens upward like a U: the ship rests low in the middle and sweeps up toward the screen edges as it moves left or right.

Firing is hold-to-fire: holding the button repeats shots at a fast, steady rate. Each shot travels inward along the radius line running from the ship's current position toward the implied centre, so a shot's direction depends on where the ship is on the arc when it fires. A shot from the left end angles up and to the left; from the middle, it fires straight up.

Enemies occupy three concentric arcs above the ship, in a full Galaga-scale formation (18 enemies on wave 1). They sweep back and forth along their arcs, periodically fire radial shots back at the ship along the same kind of trajectory the player uses, and occasionally break formation to dive at the ship. On later waves, a few enemies peel off and dive before the formation has even finished forming, so the pressure ramps up from the very start of the entrance. A wave clears once every enemy on it is destroyed. Two fixed boss planets flank the top of the screen throughout every wave, each taking 10 hits on wave 1 (+5 per wave after) to destroy in a burst of particles; shooting one is worth bonus points per hit but is entirely optional and has no bearing on clearing the wave, and a destroyed planet returns at full health next wave. The run is endless: there's no final wave, only an escalating one, and it ends when the player runs out of lives.

## Scenes

| Scene | Shows | Enters from | Exits to |
| ----- | ----- | ------------ | -------- |
| Title | Shared jam title card: colour-swatch strip, "'26 WARPED GAME JAM", "GYRI #4", blinking start prompt | Startup | Any button → Game |
| Game | Arc playfield (ship and enemies on concentric arcs), scanline grid, HUD | Title, or wave transition complete | All enemies on the current wave destroyed → Wave transition; lives reach 0 → End |
| Wave transition | Ship zooms to the shared centre, where a yellow glow pulses behind it, then to a fixed top point, trailing a line that turns white; each step pauses briefly with a rising tone. Screen irises to white, "NEW WAVE n" holds in the new wave's colour, then irises back to reveal the next wave already loaded | All enemies on the current wave destroyed | 5-stage sequence complete → Game, next wave loaded |
| End | Final score, wave reached | Game, on lives reaching 0 | Any button → Title |

## Core mechanic: arc movement & radial shooting

- The ship's position is an angle along a fixed-radius arc, not an x-coordinate; left/right input changes that angle, clamped to ±69° from the arc's centre point (a ~21° trim off the true ±90° endpoints, so the ship's 8×8 sprite stays fully on-screen; derivation in DESIGN.md).
- The ship's arc is a 180° half-circle, radius 64px, centred at (64, 55): the ship's centred resting position is at (64, 119), just above the HUD, the lowest point of the valley, and the untrimmed endpoints reach exactly (0, 55) and (128, 55), the screen's left and right edges.
- Holding fire releases shots at a fixed cooldown, each travelling along the radius line through the ship's angle at the moment it was fired, continuing inward (toward the centre, i.e. up) until off-screen or it hits an enemy.
- Enemies live on three concentric arcs at smaller radii than the ship's own (40px, 30px, 20px); a smaller radius sits closer to the shared centre and therefore higher on screen, since that centre sits above the ship (full derivation in DESIGN.md). Each arc's angular sweep is a band, not the full semicircle, for a formation look.
- Enemies sweep back and forth along their arc, periodically fire radial shots toward the ship, and occasionally break formation to dive; frequency of both increases with wave number (see Progression).
- On later waves, a few enemies dive during the entrance itself, before settling into formation: 1 on wave 1, ramping to 5 by wave 5, staggered a few seconds apart. Same dive mechanic as a formation dive, just triggered early.
- A diving enemy that misses doesn't die or leave the wave: it reappears at the top of its arc and attacks again, faster and more often each time it misses. A wave only ever clears by killing every enemy on it.

## Player

- Moves left/right along the arc; movement is angular, not linear, clamped to ±69°.
- Hold-to-fire: shots repeat automatically while held, 4 frames apart, travelling at 4px/frame along the radial trajectory.
- Resources: 5 starting lives, score.
- Fixed colours (white 7, red 8 trim) mark the ship regardless of wave; every other on-screen colour re-tints per wave (see DESIGN.md Palette), so the ship stays the one constant visual anchor.

## Game over conditions

- Player lives reach 0.

There's no win condition. The run is endless; difficulty escalates wave over wave until the player dies (see Progression).

## Sound

| Trigger | Character |
| ------- | --------- |
| Ship fire | Short, punchy blip, the one sound that breaks from the game's atmospheric palette |
| Enemy destroyed | Atmospheric, sustained tone |
| Player hit | Atmospheric, sustained tone, lower/harsher than enemy destroyed |
| Enemy dive start | Atmospheric, sustained rising tone |
| Wave clear | Atmospheric, sustained ascending chord |
| Game over | Atmospheric, sustained descending tone |
| Planet bonus | Bright, quick ascending chime, a bonus rather than a kill |
| Wave-transition pause | Three short ascending tones, one per pause in the transition sequence, building to a rising phrase |

## Tile / sprite visuals

| Element | Colour | Description |
| ------- | ------ | ------------ |
| Ship | White (7) with red (8) trim, fixed, never re-tints | Rocket-wedge silhouette, native 8×8, one of 3 sprites (straight + 2 lean levels) picked by angle so the ship visibly rotates, nose always pointing toward the shared centre |
| Enemy | Wave theme colour, primary and accent, both rotate (see DESIGN.md Palette) | Five-shape roster, one per tier: Crab (inner), Moth (middle), Wyrm (outer), and Stinger for any enemy that's currently diving, regardless of tier. Drawn via `sspr` at a continuous size driven by distance from the shared centre (small far away, growing as it approaches — outer tier ends up largest, a "worth more" cue) |
| Ship shot | White (7) | One of 3 shared shot sprites (straight/shallow/steep), picked and mirrored by travel angle, pointing inward/up, drawn at half size (4×4) |
| Enemy shot | Matches that wave's enemy colour | Same 3 shared shot sprites, `flip_y`'d to point outward/down, also drawn at half size |
| Background grid | Dark blue (1), fixed, never re-tints | Line pairs converging on the shared centre, denser near the middle, sparser toward either screen edge (see DESIGN.md) |
| Boss planets | Yellow/red, fixed, never re-tint (the Saucer alien, see DESIGN.md's Sprite rendering) | Two fixed targets flanking the top of the screen; take 10 hits on wave 1 (+5/wave) to destroy in a particle burst, worth a score bonus per hit, optional and non-gating (see DESIGN.md's Boss planets note) |

## Progression

Wave-to-wave escalation (exact formulas in DESIGN.md's Core system design): enemy count, enemy speed, and enemy aggression (dive frequency and fire rate) all increase with wave number. Enemy count is capped at 24 (leaving headroom under the 32-entity concurrent cap for enemy shots); once the count cap is hit, speed and aggression carry the rest of the difficulty curve.
