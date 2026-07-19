# Gyri #4 — Design

Technical design derived from the spec in [README.md](README.md), following [`../SPEC-FORMAT.md`](../SPEC-FORMAT.md). Pre-implementation. Once `4.p8` exists, the as-built version of this becomes the Architecture section of [CLAUDE.md](CLAUDE.md).

## Screen layout (128×128)

Title: the shared jam title card, drawn by `draw_title_card("GYRI #4")` from [`../lib/title.lua`](../lib/title.lua). No per-game layout to design here; games 1-3 already use the same card.

Game:

```
y=0
  |  open sky; two entry-point dots sit near here at (32,12) and
  |  (96,12), where enemies enter and split left/right (see
  |  Core system design's Enemy entrance note)
y=12    entry points
  |  background grid: dark-blue line pairs converging on the
  |  shared centre below, sparsest here near the top (see Core
  |  system design's Background grid note)
y=55    ship's arc centre; also the height of its untrimmed
  |     endpoints (x=0 and x=128), where the arc meets the
  |     screen edges (the whole reason this is a valley, see
  |     Core system design's Arc geometry note). Drawn as a
  |     small dot with faint spoke lines fanning out to the
  |     ship's arc edge; enemies spiral out from this point on
  |     spawn (see Enemy arcs' Enemy entrance note) instead of
  |     appearing pre-placed
y=78    ship's position at full ±69° trim (near the screen edges)
  |  ship's arc: 180° half-circle, radius 64, centred (64, 55),
  |  opening upward (a valley, not a dome): the ship sweeps up
  |  toward the screen edges rather than down away from them
  |  enemy arcs: three concentric bands between the centre and
  |  the ship, topmost reach (outer band edge) y≈84, ranging to
  |  y≈108 (inner tier's centred position) — exact per-tier
  |  values in Core system design
y=119   ship's centred/rest position (the valley floor), sitting
  |     just above the HUD
y=120   HUD line (8px): lives left, score centre, wave right
y=127
```

Wave transition: no layout sketch needed, it's a centred "WAVE n" text overlay on the frozen game scene (per SPEC-FORMAT's rule to skip sketches for centred-text-only scenes).

## Palette

Base colour pool reuses game 1's Atari-2600 approximation ([`../1/CLAUDE.md`](../1/CLAUDE.md)): black(0), white(7), red(8), orange(9), yellow(10), green(11), dark green(3), teal(12), sky blue(6), dark blue(5), purple(2), dark red(13).

| Element | Colour | Index |
| ------- | ------ | ----- |
| Ship (fixed, never re-tints) | White | 7 |
| Ship shot | White | 7 |
| Enemy / enemy shot | Wave theme colour, rotates | varies, see below |
| Background grid, radial spoke lines, vanishing-point dot | Dark blue (fixed, never re-tints) | 1 |
| Entry-point dots | Yellow (fixed, never re-tints) | 10 |
| HUD text | White | 7 |

Wave theme rotates on a 4-wave cycle, indexed by `(wave-1) % 4`, and now only covers the enemy/enemy-shot colour:

| `(wave-1) % 4` | Enemy / enemy shot |
| -------------- | ------------------- |
| 0 | Red (8) |
| 1 | Green (11) |
| 2 | Teal (12) |
| 3 | Purple (2) |

An earlier version of this table also rotated the background grid through a "hi"/"mid" tone pair per wave (Orange/Dark red, Dark green/Dark green, Sky blue/Dark blue, Dark red/Dark blue). That was dropped when the background grid itself reverted to the fixed dark-blue radiating version (see Core system design's Background grid note) — a play-test note preferred that grid's original, unchanging look, so wave identity is now carried by the enemy/shot colour alone.

Background fill (`cls()`) is always black (0).

## State machine

| `gs` | Name | Entered from | Exits to |
| ---- | ---- | ------------- | -------- |
| 0 | Title | startup | 1 (any button) |
| 1 | Game | title; wave transition complete | 2 (all enemies on wave destroyed); 3 (lives reach 0) |
| 2 | Wave transition | wave cleared | 1 (36 frames elapsed, next wave loaded) |
| 3 | End | lives reach 0 | 0 (any button) |

## Core system design

**Arc geometry** — All arcs (ship and enemy) are concentric circles around a shared centre point `(cx, cy) = (64, 55)`, which sits near the top of the play area. A point on any arc at angle `a` (in pico-8 turns, `a=0` straight down from the centre) is `x = cx - r*sin(a)`, `y = cy + r*cos(a)` (see `lib/math.lua`'s `arc_xy()`; the sin term is negated to correct for pico-8's inverted `sin()`, and the cos term is *added*, not subtracted, so the shape opens upward — a valley, not a dome). Because `cy` is near the top of the screen, a *smaller* `r` keeps a point closer to the centre and therefore higher up the screen (smaller `y`); a *larger* `r` sits further from the centre and therefore lower, nearer the bottom. The ship's own arc uses the largest radius in the system, 64px, the widest a full 180° half-circle can use without exceeding the 128px screen (for a semicircle, on-screen width is always 2x its apex-to-endpoint height, so capping height at 64px caps width at exactly 128px) — and, at that radius, the arc's untrimmed endpoints land exactly at `x=0` and `x=128`, satisfying the requirement that the arc run edge to edge like a U. Enemy arcs sit *above* the ship (between it and the centre) and therefore need radii *smaller* than 64, so they sit closer to `(cx,cy)` and higher up the screen.

An earlier draft of this design had the centre *below* the play area, which produces the opposite shape: a dome, with the ship's centred position at the top of its sweep and enemies further still above it via *larger* radii. That was backwards. Ships come from the top of the screen, so the player's arc needs to open upward toward them (a valley, low in the middle, rising to the edges), not curve over them (a dome). Every formula below reflects the corrected orientation.

**Ship movement & trim** — The ship's state is an angle `sang`, measured from straight down (0) at `(cx,cy) = (64,55)`, so `sang=0` is the ship's centred, resting position (the valley floor, `y=119`) and increasing `|sang|` sweeps it up toward the screen edges. Screen position is the sprite's centre, `x,y = arc_xy(64,55,64,sang)`, drawn via `spr()` offset by `(-4,-4)`. To keep the ship's 8x8 sprite fully on-screen at full deflection, its centre must stay within `x ∈ [4, 124]`; this constraint only touches the x-formula (unchanged by the geometry fix above), so the trim derivation itself carries over exactly: solving `64 - 64*sin(sang) <= 124`-equivalent gives `sang <= 69.64°`, rounded down to `sang` clamped to `[-69°, 69°]` (a 21° trim off the true ±90° endpoints). At full trim, `y = 55 + 64*cos(69°) ≈ 78`. Left/right input adjusts `sang` at `sturn = 2°/frame` (a default, tune once playable), clamped within that range; the full ±69° sweep takes about 69 frames (2.3s at 30fps) end to end. Horizontal displacement per unit of `sang` is proportional to `cos(sang)`, largest at the resting centre and shrinking toward the endpoints, so the ship's on-screen horizontal speed for a constant angular input decelerates approaching either end of the sweep. This is a consequence of the geometry, not a separate tuning curve, and is worth confirming feels right once playable.

**Radial shots (player)** — Hold-to-fire: while the fire button is held, a shot spawns every 4 frames at the ship's current screen position, direction the *inward* unit vector at `sang` at the moment of firing (`arc_xy(0,0,-1,sang)`, i.e. toward the centre `(64,55)` and therefore up, since the ship sits at the largest radius in the system and the enemies it's shooting at sit at smaller radii, closer to centre), travelling at 4px/frame until off-screen or it hits an enemy. Because `sang` can change between shots, consecutive shots fired while sweeping the ship travel in different, non-parallel directions.

**Enemy arcs** — Three arcs, all above the ship's arc (radii smaller than 64, per Arc geometry above, so they sit closer to the centre and higher up the screen). Each tier's angular band is a stylistic choice, not a hard constraint: at these radii the arc's full ±90° would already stay within `x ∈ [4, 124]` (max horizontal deviation from centre is the radius itself, and the largest of the three, 53px, is well under the 60px margin), so narrower bands are chosen for a formation look rather than to avoid clipping:

| Arc | Radius | y at `ea=0` (centred) | y at band edge (topmost) | Angular band | Starting enemy count |
| --- | ------ | ---------------------- | -------------------------- | ------------- | --------------------- |
| Inner (closest to ship) | 53px | 108 | 89 | ±50° | 7 |
| Middle | 43px | 98 | 88 | ±40° | 6 |
| Outer (topmost) | 33px | 88 | 84 | ±30° | 5 |

18 enemies total on wave 1. Enemies sweep back and forth within their arc's band.

**Enemy entrance** — Enemies don't spawn already on their tier's band. Entry runs in two timed phases, driven by a single global frame counter `ET` since wave start (`ND1`/`ND2` frame durations, both defaults, tune once playable), followed by an untimed third phase that reuses existing formation math:

1. **Split and circle at one of two entry points** (`ET < ND1`, ~`ND1/30` seconds) — two fixed points, `(LX,D1Y)=(32,12)` and `(RX,D1Y)=(96,12)`, sit near the top of the screen flanking the shared centre `(64,55)`, well above it. Each enemy is assigned to one or the other at spawn, alternating by spawn order (`idx%2`) so the wave splits exactly in half; it orbits only its assigned point at a small fixed radius (`D1R=10px`), sharing one angular speed (`CSPD=0.01` turns/frame, roughly 3.6 full revolutions over a 360-frame phase) with every other enemy on the same point but starting at a different phase offset so they don't stack. Alternating a globally-evenly-spaced phase-offset sequence by parity keeps each side's own sub-sequence evenly spaced too (every other value of an evenly-spaced sequence is itself evenly spaced), so no extra bookkeeping is needed to keep either ring from clumping. This replaces an earlier single-entry-point version (both an original single-point design and a first, single-point Phase 7 build) that read as one undifferentiated ring circling one spot; a play-test note asked for the wave to visibly fork into two streams at the top of the screen before continuing down, matching classic two-column enemy entrances, rather than reading as one clump. Both entry points are drawn as small yellow dots.
2. **Spiral to the shared centre** (`ND1 <= ET < ND1+ND2`, ~`ND2/30` seconds) — each enemy's position blends from where its own entry point's orbit formula would put it toward the shared centre `(64,55)`, by linear interpolation on the progress fraction through this phase. Because the orbit formula keeps running throughout (not frozen at phase-1's exit position), the blend reads as a decaying spiral that shrinks to nothing exactly as the enemy arrives at the shared centre, rather than a straight glide. Both streams (left-entry and right-entry) converge on the same shared centre here, so "then continue down" happens naturally: this phase and phase 3 below are unchanged by the phase-1 split.
3. **Grow into formation** (`ET >= ND1+ND2`) — unchanged from the original entrance note below: `r=0` at the shared centre, grows to the tier's target radius at `RGR` px/frame while sweeping its angle, same as formation sweep once settled.

Total entrance time is `(ND1+ND2)/30` seconds plus up to `ER[1]/RGR/30` seconds for the slowest (inner-tier) enemy to finish growing into formation; at the current defaults (`ND1=ND2=360`, `RGR=1`) that's about 24s plus up to 1.8s, roughly 25.8s total (doubled from an initial 10-20s target after a play-test pass asked for a longer, more visibly circling entrance). Once fully arrived (formation sweep, `ET>=ND1+ND2` and `r` at its tier target), `ea` sweeps at half its original speed (`ESPD=0.0007` turns/frame, down from `0.0014`) — a play-test note asked for slower movement specifically "once in the radial area," and since `ea` only affects visible position in this final phase (phases 1-2 derive position from the orbit/spiral formulas instead), halving it only slows the settled formation sweep, not the entrance itself.

Both fixed points are drawn: the entry point as a small dot, the shared centre as a small dot with a few faint spoke lines extending out to the screen edge (drawn via `arc_xy` with a radius far larger than any on-screen distance, 200px, so Pico-8's own line-clipping does the work of stopping exactly at the edge regardless of angle; originally stopped at the ship's own arc radius, 64px, which read as too short) — still giving the shared centre a deliberate vanishing-point read. Phase 3 (below) implements a diving enemy's miss-respawn as a direct snap to its band edge (`ea=±B`, `r` already at its tier target), not routed back through these three entrance phases; sending a respawning enemy through the full entrance again is a possible later polish pass, not required by the current spec.

Enemies also scale in size with their current distance from the shared centre `(64,55)`, computed fresh each frame regardless of which entrance phase they're in (`ds = mid(1, (60-dist)/10, 3) * 3`, an `sspr` destination width/height in px, source always the single enemy sprite): far away (near either entry point, `dist≈43px`) they read small (~5px), and they grow visibly larger through phase 2 as `dist` shrinks toward 0, capping at 9px. In formation this same distance-based size is what makes the outer tier (closest to centre at `r=33`, `ds≈8px`) read largest and the inner tier (farthest at `r=53`, `ds` floored at 3px) read smallest — a single continuous formula produces the "worth more" sizing cue for every tier and through every entrance phase, rather than a fixed per-tier lookup applied only once settled; an earlier Phase 7 pass had reintroduced fixed native-vs-`sspr`-scaled sizing per tier (dropping the continuous version when real sprites replaced `circfill`), but a play-test note asked for the "start smaller, then get larger" entrance read back, so the continuous formula now drives the sprite's `sspr` destination size directly instead of being tier-gated. The 3px collision hitbox used for shot/enemy collision is unaffected by this draw-only size.

**Background grid** — A static, non-animated spatial cue, not tied to `ET`: 7 line pairs straddle the shared centre's y (`55±d` for `d` starting at 4px and multiplying by 1.6 each step, `d≈4,6.4,10.2,16.4,26.2,41.9,67.1`), so lines are dense right around the shared centre and spread out approaching either screen edge, converging toward both the entry points above (near `y=12`) and the ship's own arc below (down to `y≈122`) — the same "closer together near the point of interest" read as the radial spoke lines, just spatial rather than temporal, and together the two line systems form a single-point-perspective "tunnel" converging on the shared centre. Drawn in the same fixed dark blue (1) as the radial spoke lines so the two read as one visual family rather than two competing colours; unlike the enemy/shot colour, this grid does **not** rotate with the wave theme (see Palette note below). An earlier version tied the line spacing to `ET`, animating it wide-to-tight over the entrance duration, but that read as unmotivated movement rather than a distance cue once played; this version fixes the lines' positions in place from frame 1. A later Phase 7 pass replaced this entirely with a flat 8-fixed-row scanline grid (bright near the HUD, fading to black at a fixed horizon `y=30`, colours rotating with the wave theme) as a more literal read of "receding perspective," but a play-test note asked for the original converging grid back specifically ("we lost the gridlines into the distance, they looked good"), so this version is the current and final one; the flat-row version and its wave-rotating grid-hi/grid-mid colours are retired, not merely superseded-pending-reconciliation as an earlier note here suggested.

Each enemy independently, on a wave-scaled interval, either fires or breaks formation to dive:

- **Fire** — a shot spawns at the enemy's current screen position, direction the *outward* unit vector at the enemy's current angle `ea`: `arc_xy(0,0,1,ea)`, i.e. away from the centre `(64,55)` and therefore down, toward the ship. This is the same direction convention as the player's own shots use (both are "away from centre" or "toward centre" depending on which side of the ship they're on) but the opposite sign, since the player sits at the largest radius (64, shooting inward toward smaller-radius enemies) while enemies sit at smaller radii (shooting outward toward the larger-radius ship). The shot travels at `ESSPD=3px/frame` (a default, tune once playable; not given an explicit value elsewhere in this doc, chosen slightly under the player's own 4px/frame so enemy fire stays dodgeable) until it hits the ship or goes off-screen past the bottom. A firing enemy only becomes eligible once its entrance is complete (`r` has reached its tier's target radius, see Enemy entrance above), so newly-arriving enemies don't fire mid-spiral.
- **Dive** — the enemy leaves its arc position and moves in a straight line toward the ship's last-known position at `dive_spd * min(2, 1 + 0.15*ei.dv)` px/frame, where `ei.dv` is that enemy's own miss counter (see below). If it hits the ship, resolve as a player hit. If it goes off-screen without hitting the ship, it does **not** leave the wave: it re-enters at the *top* of its arc, which is the outer edge of its angular band (`ea = ±B` for that tier, whichever the enemy was nearer when it started diving), not `ea=0` — `ea=0` is each tier's centred position, but because the arc opens upward, the band edges are actually the highest (smallest-`y`) points an enemy in that tier can reach, not `ea=0`. It resumes formation-sweep behaviour from there, `ei.dv` incremented by 1. Each miss also tightens that specific enemy's own fire cooldown: `max(20, wave_fire_cooldown - 10*ei.dv)`, floored at the same global 20-frame minimum as the wave-level ramp. The multiplier and cooldown reduction are both capped (`ei.dv` effectively saturates past ~7 misses) so one persistently-dodged enemy can't spiral indefinitely. Because a diving enemy is never actually removed except by being killed, a wave can only clear through kills, not through the player dodging attrition away — this was a deliberate fix over an earlier draft where a missed dive silently decremented the wave's live count. A diving enemy occupies a slot in the 32-entity concurrent cap only while it's actively on-screen (formation, mid-dive, or freshly respawned); the brief off-screen instant between miss and respawn doesn't hold one.

**Wave progression & difficulty ramp** — A wave ends when its enemy count reaches 0. For wave `w` (starting at 1):

- Enemy count: `min(24, 18 + 2*(w-1))`, capped at 24 to leave headroom under the 32-entity concurrent cap (enemies + enemy shots) for enemy fire.
- Formation sweep speed: `base_espd * (1 + 0.08*(w-1))`, `base_espd = 0.5°/frame` (a default, tune once playable) — uncapped, this and aggression below are what keep escalating once the count cap is hit.
- Dive speed: `base_dvspd * (1 + 0.08*(w-1))`, `base_dvspd = 3px/frame` (a default, tune once playable; the per-enemy miss multiplier above stacks on top of this wave-level value).
- Dive chance (per enemy, per-second probability of breaking formation): `min(0.5, 0.05 + 0.015*(w-1))`.
- Enemy fire cooldown: `wave_fire_cooldown = max(20, 90 - 5*(w-1))` frames between an individual enemy's shots (before the per-enemy miss reduction described under Dive above).
- Wave theme colour rotates per the Palette table above, `(w-1) % 4`.

**Entity cap** — Total concurrent enemies + enemy shots is capped at 32. In practice only firing needs the check: a diving enemy doesn't create a new entity (it's already counted as one of the 32 while it's mid-dive, per the paragraph above), so only a fire event that would spawn a new enemy shot can push the total over the cap. That fire event is skipped for that frame and retried next opportunity rather than queued (the enemy's cooldown simply isn't reset, so the same check runs again next frame), keeping the check O(1). Player shots aren't counted against this cap; the 4-frame cooldown and 4px/frame travel speed already bound them to roughly 8 in flight at once over the 128px playfield.

**Scoring** — `50 * arc_tier + (50 if the enemy was diving when destroyed else 0)`, where `arc_tier` is 1 (inner), 2 (middle), or 3 (outer). Rewards both prioritizing harder-to-reach outer-arc enemies and taking the risk of engaging a diving enemy.

**Sprite rendering**

Ship (sprites 0, 5, 6: straight, slight lean, sharp lean), rocket-wedge silhouettes, drawn at native 8×8 via `spr()`, offset `(-4,-4)` from its arc position, always white (7). Each lean sprite keeps the same base row (the bottom two rows, the wedge's "feet") in place and skews the rows above it further right the closer to the nose, so the ship reads as pivoting around a planted base rather than translating sideways:

```
sprite 0: straight    sprite 5: lean (slight)   sprite 6: lean (sharp)
...##...              .....##.                  .......#
...##...              .....##.                  .......#
..####..              ...####.                   ...####
..####..              ...####.                   ...####
.######.              ..######                   ..#####
.######.              ..######                   ..#####
##....##              ##....##                   ##....##
##....##              ##....##                   ##....##
```

Given the ship's current angle `sang` (measured from vertical, same convention as shot angles below), pick the sprite and flip flag with the same two-threshold pattern as the shot lookup, tuned separately for the ship's own ±69° range (roughly dividing it into thirds): `abs(sang) < 23°` → sprite 0, `23° <= abs(sang) < 46°` → sprite 5, `abs(sang) >= 46°` → sprite 6. This gives 5 visibly distinct rotation states (straight, slight-left, slight-right, sharp-left, sharp-right) from 3 drawn sprites, added after a play-test note asked for the ship to visibly rotate as it sweeps rather than staying a fixed silhouette that just translates.

The nose must always point toward the shared centre `(64,55)`, the same "inward" direction the player's own shots already fire along (`arc_xy(0,0,-1,sang)`), not toward the direction of travel: `flip_x = sang > 0`. This follows from the arc's geometry alone, independent of any trig sign convention: `sang>0` puts the ship's screen `x` to the right of the centre's `x=64` (the input mapping already established under Ship movement & trim, "increasing `a` sweeps rightward"), so the centre sits to the ship's *left* and the nose (drawn leaning right by default in sprites 5/6) must be mirrored to point left; symmetrically, `sang<0` leaves the nose unflipped, since the centre is then to the ship's right, matching the base art's default rightward lean. An initial pass used `flip_x = sang < 0`, the inverse of this, which pointed the nose *away* from the centre at both ends of the sweep; a play-test note caught it ("the ship rotates in the wrong direction... the nose should stay pointing to the centre").

Enemy (sprite 1), a distinct wing silhouette (not derived from the ship sprite), recoloured per the wave's theme colour. Vertically symmetric, so it reads the same whether formation-sweeping or mid-dive; no flip needed:

```
##....##
.##..##.
..####..
.######.
.######.
..####..
.##..##.
##....##
```

Always drawn via `sspr(8,0,8,8, x-ds/2,y-ds/2, ds,ds)`, `ds` a continuous size in px driven by distance from the shared centre (see Core system design's Enemy entrance note) rather than a fixed per-tier native/scaled split; the outer tier still reads largest and the inner tier smallest, as a side effect of that formula rather than a separate tier check.

Shots (sprites 2-4: straight, shallow, steep), shared between player and enemy shots, recoloured to match the firer (white for the player, that wave's enemy colour for enemies):

```
sprite 2: straight   sprite 3: shallow      sprite 4: steep
........              ........               ........
...##...              ....##..               ......##
..####..              ...###..               .....##.
.######.              ..####..               ....##..
...##...              ...##...               ...##...
...##...              ...##...               ..##....
........              ........               ........
........              ........               ........
```

Given a shot's fired angle `θ` (`sang` for player shots, `ea` for enemy shots, both measured from vertical), pick the sprite and flip flags:

- `abs(θ) < 12°` → sprite 2 (straight)
- `12° <= abs(θ) < 37°` → sprite 3 (shallow)
- `abs(θ) >= 37°` → sprite 4 (steep)
- `flip_x = θ < 0` (mirrors left-leaning shots)
- `flip_y = ` true for enemy shots (which travel downward, outward from centre), false for player shots (which travel upward, inward toward centre)

This covers every direction that can actually occur (both ship and enemy angular ranges stay well short of ±90°, so no shot ever needs a near-horizontal sprite) from 3 drawn sprites instead of 8, using Pico-8's native `flip_x`/`flip_y` args for the mirrored cases. Shots are drawn at half their native size (`sspr(sp*8,0,8,8, x-2,y-2, 4,4, flip_x,flip_y)`, a 4×4 destination instead of 8×8) — a play-test note found the full-size sprites read as too large once real art replaced the original single-pixel placeholders. The 3px collision hitbox is unaffected by this draw-only size, same precedent as the enemy sizing above.

**Explosion effect** — On enemy death, spawn 4-6 short-lived particles at the enemy's last position: each a flat `{x,y,vx,vy,t}` table, `vx,vy` a small random outward velocity, `t` a countdown (~10-15 frames) decremented each frame and removed at 0. Drawn with `pset` or a 1px `circfill`, coloured to match that wave's enemy colour (no dedicated sprite, no palette entry needed). Same flat-array-by-id pattern as `shots`/`en`, so it costs a `del()`-safe reverse loop, not new architecture.

## Token budget

Angle-based movement (ship, enemies, shots) leans heavily on trig every frame. A shared `arc_xy(cx, cy, r, a)` helper (returning `x, y`) should go in `lib/math.lua` before this game is built, since deriving `cos`/`sin`-based position math separately for the ship, 3 enemy arcs, player shots, and enemy shots would cost tokens fast, and the same helper covers the grid's horizon-band rationale check (enemy apex y-values above) for free. With up to 18 enemies, their shots, and player shots concurrently (capped at 32 hostile entities plus ~8 player shots), keep all per-entity state as flat arrays indexed by id, not named variables. Store the current wave's 4 theme colours as a single table looked up by `(wave-1)%4` rather than branching per-element, the same flat-array-by-id pattern game 3 uses for its colour table.
