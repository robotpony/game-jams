# Gyri #4 — Design

Technical design derived from the spec in [README.md](README.md), following [`../SPEC-FORMAT.md`](../SPEC-FORMAT.md). Pre-implementation. Once `4.p8` exists, the as-built version of this becomes the Architecture section of [CLAUDE.md](CLAUDE.md).

## Screen layout (128×128)

Title: the shared jam title card, drawn by `draw_title_card("GYRI #4")` from [`../lib/title.lua`](../lib/title.lua). No per-game layout to design here; games 1-3 already use the same card.

Game:

```
y=0
  |  open sky; two entry-point sprites ("planets", see Sprite
  |  rendering's Enemy roster note) sit near here at (32,12) and
  |  (96,12), where enemies enter and split left/right
  |  (see Core system design's Enemy entrance note); shootable for
  |  a bonus all wave (see Core system design's Boss planets note). A third,
  |  undrawn point at (64,12) — directly between the two planets,
  |  the original single entry point before the entrance split —
  |  is the destination of the wave-transition zoom (see Core
  |  system design's Wave transition sequence note)
y=12    entry points / the wave-transition zoom's target point
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
  |  the ship, topmost reach (outer band edge) y≈72, ranging to
  |  y≈95 (inner tier's centred position) — exact per-tier
  |  values in Core system design
y=119   ship's centred/rest position (the valley floor), sitting
  |     just above the HUD
y=120   HUD line (8px): lives left, score centre, wave right
y=127
```

Wave transition: no layout sketch needed (per SPEC-FORMAT's rule to skip sketches for scenes with no fixed spatial layout of their own); it's a timed sequence rather than a static screen — see Core system design's Wave transition sequence note for the full staging.

## Palette

Base colour pool reuses game 1's Atari-2600 approximation ([`../1/CLAUDE.md`](../1/CLAUDE.md)): black(0), white(7), red(8), orange(9), yellow(10), green(11), dark green(3), teal(12), sky blue(6), dark blue(5), purple(2), dark red(13).

| Element | Colour | Index |
| ------- | ------ | ----- |
| Ship (fixed, never re-tints) | White | 7 |
| Ship shot | White | 7 |
| Enemy / enemy shot | Wave theme primary + accent, rotates | varies, see below |
| Crab's trim (fixed, never re-tints) | White | 7 |
| Background grid, radial spoke lines, vanishing-point dot | Dark blue (fixed, never re-tints) | 1 |
| Entry-point sprite ("planet", the Saucer alien) | Yellow + red, fixed (never re-tints) | 10 / 8 |
| HUD text | White | 7 |

Wave theme rotates on a 4-wave cycle, indexed by `(wave-1) % 4`, and carries two colours per wave, a primary (majority of each alien's shape) and an accent (the detail band), rather than the single colour used before the enemy roster grew from one shape to five (see Sprite rendering's Enemy roster note):

| `(wave-1) % 4` | Primary | Accent |
| -------------- | ------- | ------ |
| 0 | Red (8) | Dark red (13) |
| 1 | Green (11) | Dark green (3) |
| 2 | Teal (12) | Sky blue (6) |
| 3 | Purple (2) | Dark blue (5) |

Each pair is a hue and its darker or cooler tonal neighbour from the same locked pool rather than two unrelated hues, so every wave still reads as one colour family the way the single-colour version did. An earlier version of this table rotated the background grid through a similar "hi"/"mid" tone pair per wave (Orange/Dark red, Dark green/Dark green, Sky blue/Dark blue, Dark red/Dark blue); that was dropped when the background grid reverted to the fixed dark-blue radiating version (see Core system design's Background grid note) — a play-test note preferred that grid's original, unchanging look, so wave identity was carried by the enemy/shot colour alone for a while. The accent slot revives the same two-tone idea, now applied to the enemy roster instead, since a single shape only needed one swappable colour but five distinct aliens read better with the same two-tone richness as the reference art they're modelled on.

Background fill (`cls()`) is always black (0).

## State machine

| `gs` | Name | Entered from | Exits to |
| ---- | ---- | ------------- | -------- |
| 0 | Title | startup | 1 (any button) |
| 1 | Game | title; wave transition complete | 2 (all enemies on wave destroyed); 3 (lives reach 0) |
| 2 | Wave transition | wave cleared | 1 (5-stage zoom/fade sequence complete, next wave already loaded underneath) |
| 3 | End | lives reach 0 | 0 (any button) |

## Core system design

**Arc geometry** — All arcs (ship and enemy) are concentric circles around a shared centre point `(cx, cy) = (64, 55)`, which sits near the top of the play area. A point on any arc at angle `a` (in pico-8 turns, `a=0` straight down from the centre) is `x = cx - r*sin(a)`, `y = cy + r*cos(a)` (see `lib/math.lua`'s `arc_xy()`; the sin term is negated to correct for pico-8's inverted `sin()`, and the cos term is *added*, not subtracted, so the shape opens upward — a valley, not a dome). Because `cy` is near the top of the screen, a *smaller* `r` keeps a point closer to the centre and therefore higher up the screen (smaller `y`); a *larger* `r` sits further from the centre and therefore lower, nearer the bottom. The ship's own arc uses the largest radius in the system, 64px, the widest a full 180° half-circle can use without exceeding the 128px screen (for a semicircle, on-screen width is always 2x its apex-to-endpoint height, so capping height at 64px caps width at exactly 128px) — and, at that radius, the arc's untrimmed endpoints land exactly at `x=0` and `x=128`, satisfying the requirement that the arc run edge to edge like a U. Enemy arcs sit *above* the ship (between it and the centre) and therefore need radii *smaller* than 64, so they sit closer to `(cx,cy)` and higher up the screen.

An earlier draft of this design had the centre *below* the play area, which produces the opposite shape: a dome, with the ship's centred position at the top of its sweep and enemies further still above it via *larger* radii. That was backwards. Ships come from the top of the screen, so the player's arc needs to open upward toward them (a valley, low in the middle, rising to the edges), not curve over them (a dome). Every formula below reflects the corrected orientation.

**Ship movement & trim** — The ship's state is an angle `sang`, measured from straight down (0) at `(cx,cy) = (64,55)`, so `sang=0` is the ship's centred, resting position (the valley floor, `y=119`) and increasing `|sang|` sweeps it up toward the screen edges. Screen position is the sprite's centre, `x,y = arc_xy(64,55,64,sang)`, drawn via `spr()` offset by `(-4,-4)`. To keep the ship's 8x8 sprite fully on-screen at full deflection, its centre must stay within `x ∈ [4, 124]`; this constraint only touches the x-formula (unchanged by the geometry fix above), so the trim derivation itself carries over exactly: solving `64 - 64*sin(sang) <= 124`-equivalent gives `sang <= 69.64°`, rounded down to `sang` clamped to `[-69°, 69°]` (a 21° trim off the true ±90° endpoints). At full trim, `y = 55 + 64*cos(69°) ≈ 78`. Left/right input adjusts `sang` at `sturn = 2°/frame` (a default, tune once playable), clamped within that range; the full ±69° sweep takes about 69 frames (2.3s at 30fps) end to end. Horizontal displacement per unit of `sang` is proportional to `cos(sang)`, largest at the resting centre and shrinking toward the endpoints, so the ship's on-screen horizontal speed for a constant angular input decelerates approaching either end of the sweep. This is a consequence of the geometry, not a separate tuning curve, and is worth confirming feels right once playable.

**Radial shots (player)** — Hold-to-fire: while the fire button is held, a shot spawns every 4 frames at the ship's current screen position, direction the *inward* unit vector at `sang` at the moment of firing (`arc_xy(0,0,-1,sang)`, i.e. toward the centre `(64,55)` and therefore up, since the ship sits at the largest radius in the system and the enemies it's shooting at sit at smaller radii, closer to centre), travelling at 4px/frame until off-screen or it hits an enemy. Because `sang` can change between shots, consecutive shots fired while sweeping the ship travel in different, non-parallel directions.

**Enemy arcs** — Three arcs, all above the ship's arc (radii smaller than 64, per Arc geometry above, so they sit closer to the centre and higher up the screen). Each tier's angular band is a stylistic choice, not a hard constraint: at these radii the arc's full ±90° would already stay within `x ∈ [4, 124]` (max horizontal deviation from centre is the radius itself, and the largest of the three, 53px, is well under the 60px margin), so narrower bands are chosen for a formation look rather than to avoid clipping:

| Arc | Radius | y at `ea=0` (centred) | y at band edge (topmost) | Angular band | Starting enemy count |
| --- | ------ | ---------------------- | -------------------------- | ------------- | --------------------- |
| Inner (closest to ship) | 40px | 95 | 81 | ±50° | 7 |
| Middle | 30px | 85 | 78 | ±40° | 6 |
| Outer (topmost) | 20px | 75 | 72 | ±30° | 5 |

Radii shrunk from an original 53/43/33 (kept from README/DESIGN's initial lock) after a play-test note said the settled formation sat "too low" and asked for it to sit closer to the shared centre dot; the 10px gap between tiers and the angular bands are unchanged, so the formation's shape holds, just shifted roughly 13px closer to `(64,55)`. The enemy size formula (`ds`, in Enemy entrance below) was retuned to match.

18 enemies total on wave 1. Enemies sweep back and forth within their arc's band.

**Enemy entrance** — Enemies don't spawn already on their tier's band. Entry runs in two timed phases, driven by a single global frame counter `ET` since wave start (`ND1`/`ND2` frame durations, both defaults, tune once playable), followed by an untimed third phase that reuses existing formation math:

1. **Split and circle at one of two entry points** (`ET < ND1`, ~`ND1/30` seconds) — two fixed points, `(LX,D1Y)=(32,12)` and `(RX,D1Y)=(96,12)`, sit near the top of the screen flanking the shared centre `(64,55)`, well above it. Each enemy is assigned to one or the other at spawn, alternating by spawn order (`idx%2`) so the wave splits exactly in half; it orbits only its assigned point at a small fixed radius (`D1R=10px`), sharing one angular speed (`CSPD=0.01` turns/frame, roughly 3.6 full revolutions over a 360-frame phase) with every other enemy on the same point but starting at a different phase offset so they don't stack. Alternating a globally-evenly-spaced phase-offset sequence by parity keeps each side's own sub-sequence evenly spaced too (every other value of an evenly-spaced sequence is itself evenly spaced), so no extra bookkeeping is needed to keep either ring from clumping. This replaces an earlier single-entry-point version (both an original single-point design and a first, single-point Phase 7 build) that read as one undifferentiated ring circling one spot; a play-test note asked for the wave to visibly fork into two streams at the top of the screen before continuing down, matching classic two-column enemy entrances, rather than reading as one clump. Both entry points are drawn as the Saucer alien (see Sprite rendering's Enemy roster note; "planets" — see Scoring below for the bonus tied to them) and are shootable throughout the wave, not just during this phase.
2. **Spiral to the shared centre** (`ND1 <= ET < ND1+ND2`, ~`ND2/30` seconds) — each enemy's position blends from where its own entry point's orbit formula would put it toward the shared centre `(64,55)`, by linear interpolation on the progress fraction through this phase. Because the orbit formula keeps running throughout (not frozen at phase-1's exit position), the blend reads as a decaying spiral that shrinks to nothing exactly as the enemy arrives at the shared centre, rather than a straight glide. Both streams (left-entry and right-entry) converge on the same shared centre here, so "then continue down" happens naturally: this phase and phase 3 below are unchanged by the phase-1 split.
3. **Grow into formation** (`ET >= ND1+ND2`) — unchanged from the original entrance note below: `r=0` at the shared centre, grows to the tier's target radius at `RGR` px/frame while sweeping its angle, same as formation sweep once settled.

Total entrance time is `(ND1+ND2)/30` seconds plus up to `ER[1]/RGR/30` seconds for the slowest (inner-tier) enemy to finish growing into formation; at the current defaults (`ND1=ND2=360`, `RGR=1`) that's about 24s plus up to 1.8s, roughly 25.8s total (doubled from an initial 10-20s target after a play-test pass asked for a longer, more visibly circling entrance). Once fully arrived (formation sweep, `ET>=ND1+ND2` and `r` at its tier target), `ea` sweeps at half its original speed (`ESPD=0.0007` turns/frame, down from `0.0014`) — a play-test note asked for slower movement specifically "once in the radial area," and since `ea` only affects visible position in this final phase (phases 1-2 derive position from the orbit/spiral formulas instead), halving it only slows the settled formation sweep, not the entrance itself.

Both fixed points are drawn: the entry point as the Saucer sprite, the shared centre as a small dot with a few faint spoke lines extending out to the screen edge (drawn via `arc_xy` with a radius far larger than any on-screen distance, 200px, so Pico-8's own line-clipping does the work of stopping exactly at the edge regardless of angle; originally stopped at the ship's own arc radius, 64px, which read as too short) — still giving the shared centre a deliberate vanishing-point read. Phase 3 (below) implements a diving enemy's miss-respawn as a direct snap to its band edge (`ea=±B`, `r` already at its tier target), not routed back through these three entrance phases; sending a respawning enemy through the full entrance again is a possible later polish pass, not required by the current spec.

Enemies also scale in size with their current distance from the shared centre `(64,55)`, computed fresh each frame regardless of which entrance phase they're in (`ds = mid(1, (50-dist)/10, 3) * 3`, an `sspr` destination width/height in px; the source sprite varies by which of the five aliens the enemy is currently showing, see Sprite rendering's Enemy roster note, but the size formula itself doesn't care which): far away (near either entry point, `dist≈43.6px`) they read small (floored at 3px), and they grow visibly larger through phase 2 as `dist` shrinks toward 0, capping at 9px. In formation this same distance-based size is what makes the outer tier (closest to centre at `r=20`, `ds=9px`, max) read largest and the inner tier (farthest at `r=40`, `ds=3px`, min) read smallest — a single continuous formula produces the "worth more" sizing cue for every tier and through every entrance phase, rather than a fixed per-tier lookup applied only once settled; an earlier Phase 7 pass had reintroduced fixed native-vs-`sspr`-scaled sizing per tier (dropping the continuous version when real sprites replaced `circfill`), but a play-test note asked for the "start smaller, then get larger" entrance read back, so the continuous formula now drives the sprite's `sspr` destination size directly instead of being tier-gated. The formula's constants (`50`, `10`) are tuned to the current tier radii (40/30/20, see Enemy arcs above); when those radii shrank after a later play-test note, the leading `50` shrank with them (from an original `60`, keeping the same `10` divisor and `[1,3]` clamp range) so the size range and per-tier hierarchy still land correctly. The 3px collision hitbox used for shot/enemy collision is unaffected by this draw-only size.

**Background grid** — A static, non-animated spatial cue, not tied to `ET`: 7 line pairs straddle the shared centre's y (`55±d` for `d` starting at 4px and multiplying by 1.6 each step, `d≈4,6.4,10.2,16.4,26.2,41.9,67.1`), so lines are dense right around the shared centre and spread out approaching either screen edge, converging toward both the entry points above (near `y=12`) and the ship's own arc below (down to `y≈122`) — the same "closer together near the point of interest" read as the radial spoke lines, just spatial rather than temporal, and together the two line systems form a single-point-perspective "tunnel" converging on the shared centre. Drawn in the same fixed dark blue (1) as the radial spoke lines so the two read as one visual family rather than two competing colours; unlike the enemy/shot colour, this grid does **not** rotate with the wave theme (see Palette note below). An earlier version tied the line spacing to `ET`, animating it wide-to-tight over the entrance duration, but that read as unmotivated movement rather than a distance cue once played; this version fixes the lines' positions in place from frame 1. A later Phase 7 pass replaced this entirely with a flat 8-fixed-row scanline grid (bright near the HUD, fading to black at a fixed horizon `y=30`, colours rotating with the wave theme) as a more literal read of "receding perspective," but a play-test note asked for the original converging grid back specifically ("we lost the gridlines into the distance, they looked good"), so this version is the current and final one; the flat-row version and its wave-rotating grid-hi/grid-mid colours are retired, not merely superseded-pending-reconciliation as an earlier note here suggested.

The lines below the centre (`CY+d`, toward the ship's own arc) stay solid. The lines above it (`CY-d`, toward the entry points and open sky) fade as they climb, starting immediately at the first line pair past the centre rather than only at the outer few: Pico-8's flat 16-colour palette has no intermediate tone between dark blue (1) and black (0) to produce a true colour gradient, so each upper line is drawn as a repeating dash/dot pattern instead of one solid line, the classic flat-palette way to fake a density gradient with only two tones. Three patterns escalate from denser to sparser as `d` grows, assigned by line index (`i` of `GN=7`, 1 nearest the centre, 7 nearest the top): dash-dash-dot (run lengths `{3,2,3,2,1,2}` px, alternating lit/unlit starting lit, ~54% lit) for `i` 1-3, dash-dot (`{3,2,1,2}`, 50% lit) for `i` 4-5, dot-dot (`{1,2,1,2}`, 33% lit) for `i` 6-7 — a genuine decreasing-density progression, not just three arbitrary patterns. This is a density fade layered on the existing fixed-colour rule above, not an exception to it: the lines are still always dark blue (1), never wave-tinted, only how much of each line is drawn changes.

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

**Boss planets** — The two entry points (see Enemy entrance above) are boss targets, `pl[1]`/`pl[2]` (`{x=LX or RX, hp}`), re-armed every wave in `spawn_wave()` with `hp = 10 + 5*(w-1)` (10 on wave 1, 15 on wave 2, and so on — the same wave-indexed-by-`(w-1)` convention as every other difficulty formula in this doc). Each can be hit by a player shot at any point during the wave using the same 3px hitbox convention as every other collision check here (`abs(dx)<3 and abs(dy)<3` against `(LX,D1Y)` or `(RX,D1Y)`, gated on `hp>0` so a destroyed planet stops registering hits); a hit decrements that planet's `hp`, awards a flat 200-point bonus, and consumes the shot, every time, hit or kill. Below 0 the "explode" hit instead plays the enemy-destroyed chime (reusing `sfx(1)`, not the ordinary hit chime — this is framed as a kill, not another tap) and spawns a much bigger burst than a normal hit (14 particles at up to 3px/frame for 15-30 frames, versus a normal hit's 5 particles at up to 1.5px/frame for 10-15 frames), both centred on the planet's fixed position rather than the shot's exact impact point. Once destroyed, that planet stops drawing and stops registering hits for the rest of the wave; the *next* wave's `spawn_wave()` resets both planets' `hp` unconditionally, so a destroyed planet always comes back next wave, full-health, regardless of whether it survived the previous one.

A planet's `hp`/alive state has no bearing on the enemy entrance geometry: `spawn_wave()` still orbits enemies around the raw `(LX,D1Y)`/`(RX,D1Y)` coordinates regardless of whether the boss sprite standing there is currently drawn, so destroying a planet mid-wave doesn't change how the *next* wave's enemies enter. **Boss planets play no part in the wave-clear condition**: that check is `#en==0` alone (see Wave progression above), and a planet is never a member of `en`, so hitting or destroying one any number of times neither advances nor delays a wave; it's purely extra score layered on top of the kill-everything win condition, never a second objective — confirmed explicitly ("treat them as extra points, but they do not gate the level end"). Landing a hit at all takes a deliberate, precise shot rather than incidental fire, since each entry point sits at roughly the same angular position from the shared centre as the inner-tier enemy band (`~37°`, within the ship's ±69° range but requiring the ship to hold a specific angle). First added as an indestructible, infinitely-repeatable bonus target ("you should be able to hit the yellow planets, too"); given a hit-point pool and an explosion in a follow-up request ("let's turn the planets into bosses... they take 10 hits (increases by 5 per level) to explode, using a particle effect").

**Wave transition sequence** — Replaces the original placeholder (a static 36-frame freeze with a centred "WAVE n" overlay) with a 5-stage animated sequence, entered the same way (`#en==0`) but no longer just a countdown: a sub-state `ws` (1-5) tracks which stage is active, alongside a per-stage frame counter (the same `frz` variable the old freeze used). Two new fixed points bound the sequence, both distinct from the two entry-point planets: the shared centre `(64,55)` (already established, see Arc geometry) and a third point `(TX,TY)=(64,12)`, directly between the two planets — the original single entry point from before the entrance split (see Enemy entrance above), kept around specifically for this. All 5 stage lengths below are defaults, tune once playable, chosen to total roughly 3s (up from the original 1.2s freeze) since there's meaningfully more happening now:

1. **Ship → centre dot** (`WZ1=20` frames, ~0.67s) — the ship flies in a straight line from wherever it was when the wave cleared to `(64,55)`, *not* along its own arc; this is a direct cut across the playfield, the one place in the game the ship's position isn't governed by `sang`/`arc_xy`. A trail accumulates behind it: one point recorded per frame at the ship's current interpolated position, each stamped with a colour based on overall sequence progress (see the colour ramp below), then rendered as connected line segments (`line()` between consecutive trail points) rather than loose points, so it reads as a continuous growing line rather than a dotted one. The ship sprite itself is drawn in its `sprite 0` (straight) pose throughout the whole zoom — it isn't "steering" anymore, so the rotation logic (Sprite rendering's ship note) doesn't apply here.
2. **Centre dot → top point** (`WZ2=15` frames, ~0.5s) — continues from `(64,55)` to `(TX,TY)=(64,12)`, a second straight-line leg in a different direction than stage 1 (a visible bend at the centre dot, not a single unbroken line, since the two destinations aren't generally colinear with the ship's start position). Trail accumulation and the ship's straight-pose sprite continue exactly as in stage 1.
3. **White iris expands from the top point** (`WZ3=10` frames, ~0.33s) — once the ship arrives at `(TX,TY)`, it's no longer drawn separately (it's "become" the point); a circle centred on `(TX,TY)` grows from radius 0 to 140px (comfortably past every screen corner from that point) over this stage, painted with `circfill`, giving a wipe-style "fade to white" — Pico-8 has no alpha blending, so a full cross-fade isn't available; an expanding solid fill from the arrival point is the standard substitute and ties the "fade" directly to where the ship just went. The frozen backdrop (background grid, spokes, centre dot, completed trail) keeps rendering underneath until the circle covers it.
4. **"NEW WAVE n" holds** (`WZ4=30` frames, ~1s) — this is the stage boundary where the actual wave-advance state reset happens, at the moment `ws` becomes 4 (`wv+=1`, `en={}`, `eshots={}`, `pt={}`, `ET=0`, `sang=0`, `spawn_wave()` — which also re-arms both boss planets' `hp`, see Boss planets above — then `trail={}`), so by the time this stage's own draw code runs, `wv` already holds the new wave's number: the screen is fully white, and text reads `"new wave "..wv` centred, coloured in that (now-current) wave's theme colour (`WT[(wv-1)%4+1]`, the same lookup and rotation used everywhere else in this doc — see Palette), a small preview of what's about to load rather than plain white-on-white text.
5. **White iris shrinks back** (`WZ5=15` frames, ~0.5s) — the same circle, now centred on `(TX,TY)` again, shrinks from full coverage back to 0, revealing the ordinary game scene underneath: background grid, ship at its reset rest position (`sang=0`), and the next wave's enemies already spawned at their entry points (static, since the entrance's own `ET`-driven animation only advances once `gs` returns to 1 — they visibly start moving on the very first frame of normal play rather than mid-reveal, a deliberate simplification rather than duplicating the entrance's update logic inside the transition). Once this stage's counter reaches 0, `gs=1` and play resumes normally.

**Trail colour ramp** — Across the combined duration of stages 1-2 (`WZ1+WZ2=35` frames), each trail point's colour is chosen from its progress fraction `p` (0 at the ship's start, 1 at the top point): `p<1/3` → dark blue (1, matching the background grid and spoke lines' fixed colour), `1/3<=p<2/3` → light grey (6), `p>=2/3` → white (7) — "the line turning into white" as it travels, three fixed steps rather than a continuous gradient (Pico-8's 16-colour palette doesn't have the intermediate shades for a smoother ramp, and three steps is enough to read as a directional colour shift at this resolution).

Implemented as spec'd above (`zoompos()`, `draw_backdrop()`/`draw_trail()`/`draw_game()` factored out of the old single `_draw()` body so the same playfield renderer serves both ordinary play and stage 5's reveal, per "Implement this and the end of level transition").

**Ship reset** — `sang` is set to 0 as part of the stage-4 state reset, so the ship is genuinely centred (not just visually parked there) once play resumes; this was a deliberate choice over a purely cosmetic zoom; confirmed directly rather than assumed, since the alternative (visual-only, `sang` unchanged underneath) was a real option that would have left the ship wherever the player had it when the wave cleared.

**Sprite rendering**

Ship (sprites 0, 5, 6: straight, and 2 lean levels), rocket-wedge silhouettes, drawn at native 8×8 via `spr()`, offset `(-4,-4)` from its arc position, always white (7). The angle a rotated sprite should represent is not a stylized guess: it's exactly the angle of the line the ship's own shots travel along, `arc_xy(0,0,-1,sang)`, which by construction of `arc_xy` is `sang` itself — the same angle used for the ship's own arc position. At maximum deflection that angle is exactly `SC` (`0.19167` turns `× 360° = 69.0°`, the same ±69° trim derived under Ship movement & trim above from keeping the sprite on-screen), **not** 90°; an earlier pass used a stylized full 90° at the extreme after a play-test note asked for "completely rotated 90 degrees," but a follow-up note clarified the intent was accuracy to the true fire-line angle, not a round number, so sprite 6 now represents 69°, not 90°.

Sprites 5/6 are generated, not hand-shifted: an initial attempt derived them by shifting rows of sprite 0 rightward, which produced a staircase-like artifact rather than a recognizable rotation (caught in a play-test screenshot); a second attempt used plain nearest-neighbour trig rotation at the target angle, which also produced broken, disconnected pixel art at non-90°-multiple angles (holes, floating fragments) — 8×8 is too coarse for naive per-pixel rotation sampling. The working method supersamples: upscale sprite 0 8×, rotate the upscaled grid by nearest-neighbour, then downsample each 8×8 block back to one pixel by majority vote (filled if ≥50% of the block's samples are filled), which anti-aliases away the single-pixel holes that plain nearest-neighbour left behind, at the cost of a slightly blockier silhouette than the small handful of "clean by construction" 90°-multiple rotations:

```
sprite 0: straight   sprite 5: 35°         sprite 6: 69°
...##...             .....##.              ........
...##...             ...####.              ########
..####..              .######.              ########
..####..              #######.              ########
.######.              #######.              ..#####.
.######.              #######.              ..#####.
##....##             ...###..              ..###...
##....##             ...###..              .###.....
```

Given the ship's current angle `sang`, pick the sprite with 2 thresholds dividing the ship's ±69° range into thirds (`23°`, `46°`): `abs(sang) < 23°` → sprite 0, `23° <= abs(sang) < 46°` → sprite 5 (the 35° rotation, roughly this bucket's midpoint), `abs(sang) >= 46°` → sprite 6 (the 69° rotation, the true maximum). This gives 5 visibly distinct rotation states (straight, slight-left, slight-right, sharp-left, sharp-right) from 3 drawn sprites.

The nose must always point toward the shared centre `(64,55)`, the same "inward" direction the player's own shots already fire along (`arc_xy(0,0,-1,sang)`), not toward the top of the screen: `flip_x = sang > 0`. This follows from the arc's geometry alone, independent of any trig sign convention: `sang>0` puts the ship's screen `x` to the right of the centre's `x=64` (the input mapping already established under Ship movement & trim, "increasing `a` sweeps rightward"), so the centre sits to the ship's *left* and the nose (drawn leaning right by default in sprites 5/6) must be mirrored to point left; symmetrically, `sang<0` leaves the nose unflipped, since the centre is then to the ship's right, matching the base art's default rightward lean. An initial pass used `flip_x = sang < 0`, the inverse of this, which pointed the nose *away* from the centre at both ends of the sweep; a play-test note caught it ("the ship rotates in the wrong direction... the nose should stay pointing to the centre [point], not the top centre [of the screen]").

**Enemy roster (sprites 1, 7-10)** — Five distinct alien silhouettes, one per tier plus a dive-only look and the two entry-point "planets", replace the single generic wing sprite an earlier draft of this design used for every enemy regardless of type. Each is vertically symmetric like the sprite it replaces, so it reads the same whether formation-sweeping or mid-dive and never needs a flip flag:

```
sprite 1: Crab       sprite 7: Moth       sprite 8: Wyrm       sprite 9: Stinger    sprite 10: Saucer
A......A             AA....AA             .A....A.             .A....A.             ..YYYY..
AA....AA             .AA..AA.             AAA..AAA             .AA..AA.             .YYYYYY.
.AA..AA.             ..AAAA..             AAAAAAAA             BAA..AAB             YYRRRRYY
..ABBA..             ..ABBA..             .ABBBBA.             BBAAAABB             YYRRRRYY
..AWWA..             ..ABBA..             .AB..BA.             ..AAAA..             .Y.RR.Y.
...AA...             ...AA...             ..A..A..             ...AA...             ...RR...
..A..A..             ..A..A..             ..AAAA..             ..A..A..             R......R
.A....A.             AA....AA             .A....A.             .A....A.             .R....R.
```

| Alien | Slot | Role |
| ----- | ---- | ---- |
| Crab | 1 (the old generic enemy slot) | Inner tier (`tr==1`, radius 40) |
| Moth | 7 | Middle tier (`tr==2`, radius 30) |
| Wyrm | 8 | Outer tier (`tr==3`, radius 20) |
| Stinger | 9 | Any tier, while diving (`e.dv==1`); reverts to the tier's own sprite once it respawns back into formation |
| Saucer | 10 | The two boss-planet sprites at `(32,12)`/`(96,12)` (see Enemy entrance and Boss planets above) — not a member of `en`, drawn separately, and only while that planet's `hp>0` |

`A` (majority of each shape) and `B` (accent detail) are drawn in the sheet using two fixed source colours, red (8) and teal (12), and remapped at draw time with `pal(8,wtheme.primary) pal(12,wtheme.accent)` immediately before each `sspr()` call, reset with a bare `pal()` right after — the same one-swap-per-draw pattern the original single sprite used, doubled to two source/target pairs (see Palette above for the four-wave primary/accent table). Crab's `W` is the one exception: a literal, never-swapped white (7) trim matching the ship/HUD's existing fixed-white convention, a deliberate callback rather than an inconsistency. Saucer's `Y`/`R` are also literal (yellow 10, red 8, matching the fixed-yellow dot it replaces) and never swapped; because it's drawn outside the `en` loop entirely, no rotating alien's `pal(8,...)` call is ever active while it renders, so its own literal red pixels can't be caught mid-swap.

Always drawn via `sspr(sp*8,0,8,8, x-ds/2,y-ds/2, ds,ds)` for whichever slot `sp` the enemy is currently showing (tier-selected, or 9 while diving), `ds` the same continuous distance-from-centre size formula as before (see Core system design's Enemy entrance note); the outer tier (Wyrm) still reads largest and the inner tier (Crab) smallest, as a side effect of that formula rather than a separate tier check. The 3px collision hitbox is unaffected by which alien is currently drawn.

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
- `flip_x`: mirrors the sprite so it points along its actual direction of travel, not just its fired angle's sign. Sprites 3/4's un-mirrored art leans right (its narrow "nose" sits right of centre — see the diagrams above), so `flip_x` should be true whenever the shot is actually moving *left*. For player shots (travelling inward, `arc_xy(0,0,-1,sang)`) that's `flip_x = sang > 0` (positive `sang` puts the ship right of the centre column, so its inward shot moves left — the same geometry already established for the ship's own nose in Ship movement & trim); for enemy shots (travelling outward, `arc_xy(0,0,1,ea)`) it's the opposite sign, `flip_x = ea < 0`, since outward continues in the same left/right sense the enemy is already offset in, rather than reversing it. An initial version used `flip_x = θ < 0` for both, which happened to be correct for enemy shots (outward travel) but backwards for player shots (inward travel) — the same class of sign inversion the ship's own rotation had, caught by the same kind of play-test note ("the bullets rotate in the inverse direction... it would look better rotated in the direction of movement").
- `flip_y = ` true for enemy shots (which travel downward, outward from centre), false for player shots (which travel upward, inward toward centre)

This covers every direction that can actually occur (both ship and enemy angular ranges stay well short of ±90°, so no shot ever needs a near-horizontal sprite) from 3 drawn sprites instead of 8, using Pico-8's native `flip_x`/`flip_y` args for the mirrored cases. Shots are drawn at half their native size (`sspr(sp*8,0,8,8, x-2,y-2, 4,4, flip_x,flip_y)`, a 4×4 destination instead of 8×8) — a play-test note found the full-size sprites read as too large once real art replaced the original single-pixel placeholders. The 3px collision hitbox is unaffected by this draw-only size, same precedent as the enemy sizing above.

**Explosion effect** — On enemy death, spawn 4-6 short-lived particles at the enemy's last position: each a flat `{x,y,vx,vy,t}` table, `vx,vy` a small random outward velocity, `t` a countdown (~10-15 frames) decremented each frame and removed at 0. Drawn with `pset` or a 1px `circfill`, coloured to match that wave's enemy colour (no dedicated sprite, no palette entry needed). Same flat-array-by-id pattern as `shots`/`en`, so it costs a `del()`-safe reverse loop, not new architecture.

## Token budget

Angle-based movement (ship, enemies, shots) leans heavily on trig every frame. A shared `arc_xy(cx, cy, r, a)` helper (returning `x, y`) should go in `lib/math.lua` before this game is built, since deriving `cos`/`sin`-based position math separately for the ship, 3 enemy arcs, player shots, and enemy shots would cost tokens fast, and the same helper covers the grid's horizon-band rationale check (enemy apex y-values above) for free. With up to 18 enemies, their shots, and player shots concurrently (capped at 32 hostile entities plus ~8 player shots), keep all per-entity state as flat arrays indexed by id, not named variables. Store the current wave's 4 theme colours as a single table looked up by `(wave-1)%4` rather than branching per-element, the same flat-array-by-id pattern game 3 uses for its colour table; the enemy roster's primary/accent pair is just two columns in that same table, not a second lookup structure. Picking an enemy's sprite slot (tier vs. diving) is one more small branch per enemy per frame, not per-frame per-pixel work, so it shouldn't meaningfully move the token count.
