# Gyri #4 — Design

Technical design derived from the spec in [README.md](README.md), following [`../SPEC-FORMAT.md`](../SPEC-FORMAT.md). Pre-implementation: several values below are marked TBD and tracked in README's Open questions. Once `4.p8` exists, the as-built version of this becomes the Architecture section of [CLAUDE.md](CLAUDE.md).

## Screen layout (128×128)

Title: the shared jam title card, drawn by `draw_title_card("GYRI #4")` from [`../lib/title.lua`](../lib/title.lua). No per-game layout to design here; games 1-3 already use the same card.

Game:

```
y=0
  |
  |  enemy arcs: concentric curves above the ship's arc,
  |  smaller radii than 64px, exact radii and counts TBD
  |
y=39    apex of ship's arc (x=64), ship's highest reachable point
  |  ship's arc: 180° half-circle, radius 64, centred (64, 103)
  |  ship sweeps angularly along it, endpoints trimmed a few
  |  degrees short of true ±90° to keep its 8x8 sprite on-screen
y=103   ship's arc endpoints (x≈0 and x≈128, before trim)
y=111
y=112   HUD line (8px): TBD split — lives, score, wave number
y=127
```

Wave transition: no layout sketch needed, it's a centred "WAVE n" text overlay on the frozen game scene (per SPEC-FORMAT's rule to skip sketches for centred-text-only scenes).

Ship-arc centre, radius, and angular range are locked (see Core system design below); HUD field split and the exact endpoint trim aren't decided, see README's Open questions.

## Palette

Not yet decided. Every row below is a placeholder pending the palette question in README's Open questions.

| Element | Colour | Index |
| ------- | ------ | ----- |
| Ship | TBD | TBD |
| Enemy | TBD | TBD |
| Shot | TBD | TBD |
| Arc / playfield boundary | TBD | TBD |
| HUD text | TBD | TBD |

## State machine

| `gs` | Name | Entered from | Exits to |
| ---- | ---- | ------------- | -------- |
| 0 | Title | startup | 1 (any button) |
| 1 | Game | title; wave transition complete | 2 (all enemies on wave destroyed); 3 (lives reach 0) |
| 2 | Wave transition | wave cleared | 1 (transition complete, next wave loaded) |
| 3 | End | lives reach 0 | 0 (any button) |

## Core system design

**Arc geometry** — Both the ship's arc and each enemy arc are concentric circles around a shared centre point `(cx, cy) = (64, 103)`. The ship's arc has radius 64, the largest in the system (it's the outer boundary the player patrols); enemy arcs have smaller radii, stacked toward the centre, exact values TBD (see README's Open questions). 64 is the widest radius a full 180° half-circle can use without exceeding the 128px screen: for a semicircle, on-screen width is always 2× its height (apex-to-endpoint), so capping height at 64px (50% of the 128px screen) caps width at exactly 128px, the screen's own limit. Both bounds saturate together, there's no wider arc that still fits.

**Ship movement** — The ship's state is an angle `sang` rather than an x-coordinate, measured from straight up (0) at the centre `(cx,cy)`. Left/right input adjusts `sang` within a clamped range, trimmed a few degrees short of the arc's true ±90° endpoints so the ship's 8×8 sprite doesn't clip off-screen at full deflection (exact trim TBD, see README's Open questions). Screen position is derived each frame from `sang` and the ship-arc radius via Pico-8's `cos()`/`sin()`: `x = cx + 64*sin(sang)`, `y = cy - 64*cos(sang)`. Because horizontal displacement per unit of `sang` is `64*cos(sang)`, largest at the apex (`sang=0`) and shrinking toward the endpoints, the ship's on-screen horizontal speed for a constant angular input speed decreases as it approaches either end of its sweep, an intentional consequence of the geometry rather than a separate speed curve to tune.

**Radial shots** — On fire, a shot spawns at the ship's current screen position with a direction equal to the radius vector at `sang` (the direction from `(cx, cy)` through the ship), and travels in a straight line along that vector until off-screen or it hits an enemy. Because `sang` can change between shots, two shots fired from different ship positions travel in different, non-parallel directions, unlike a fixed vertical Galaga shot.

**Enemy arcs** — Enemies are placed at angular positions along their arc, similar to the ship's `sang` representation, and sweep back and forth (or in some other pattern, TBD) along it. Collision between a shot and an enemy is a straightforward check once both are expressed as angle+radius or converted to x/y for a distance check; which approach is cheaper token-wise is worth testing once the shot count is known.

**Wave progression** — A wave ends when its enemy count reaches 0. The next wave's enemy count, arc count, and speed aren't decided yet; see README's Open questions and Progression section.

## Token budget

Angle-based movement (ship, enemies, shots) leans heavily on trig every frame; check whether [`../lib/CLAUDE.md`](../lib/CLAUDE.md) gains a `math.lua` with angle/lerp helpers before this game is built, since re-deriving `cos`/`sin`-based position math per system (ship, enemies, shots) three times over would cost tokens fast. This design also carries more concurrent moving entities than games 1 or 3 (an enemy formation plus their shots, if enemies fire back), so keep enemy and shot state as flat arrays indexed by id rather than named variables per entity.
