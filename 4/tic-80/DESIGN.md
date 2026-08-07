# 4 (TIC-80 upscale) — Design

Technical design for the TIC-80 build, based on [`../README.md`](../README.md). Follows [`../../SPEC-FORMAT.md`](../../SPEC-FORMAT.md). Written incrementally as [PLAN.md](PLAN.md)'s Phase 0b POC validates each piece, not batched at the end — see that file's Phase 0b intro for why this design pass proceeds by building rather than by pure paper derivation.

**Status**: Stage A (visuals & layout) is done and confirmed against real TIC-80-rendered output, not just the proxy renderer (screenshot coordination landed; see PLAN.md's Stage A). Stage B (movement & waves) is implemented and being tuned live against real play — ship movement, entrance sequence, enemy sweep/fire/dive, and wave spawn/clear all work end to end, but the difficulty-ramp numbers are still placeholder-shaped guesses per PLAN.md's Stage B checklist, not finished. Screen layout, Palette, and Core system design's Enemy tiers and Horizon/trim-rays sections reflect what's actually on screen; the Core system design subsections below cover what Stage B validated so far. Wave scaling and transitions (Stage C) and the Difficulty ramp/Token budget sections aren't written yet.

## Scope agreed so far

This is planned as an expanded upscale of the Pico-8 build ([`../pico-8/DESIGN.md`](../pico-8/DESIGN.md)), not a straight port at a bigger resolution. Four areas are on the table:

- **Bigger playfield/formation** — using the 240×136 canvas (vs. Pico-8's 128×128) for more enemies on-screen, wider arcs, more headroom above the ship. Geometry decided below; ~40 wave-1 enemies (vs. Pico-8's 18) is the target, exact split across tiers still a tuning knob
- **Richer sprite art** — TIC-80's 512 combined tile/sprite slots (vs. Pico-8's 256 shared) for more frames, more roster variety, more rotation states. Not started; Stage A uses primitive shapes (`circ`/`rect`), same as Pico-8's own early phases used before its Phase 7 added real sprites
- **Deeper sound/music** — TIC-80's tracker-style SFX/music editor for a real music track (the Pico-8 build has SFX only, no music) plus more elaborate SFX. Deferred to Stage C, where it's actually needed (the wave-transition sequence)
- **New mechanics** — actual gameplay additions beyond a reskin, not yet chosen. Deferred until after the POC's three stages, evaluated against a real running baseline instead of an imagined one

## Screen layout (240×136)

Title: shared jam title card, same as every other game — see [`../pico-8/DESIGN.md`](../pico-8/DESIGN.md)'s Screen layout note; no per-platform layout to design.

Game:

```
y=0
  |  sky: black, no grid — a subtle orange/maroon glow band sits just
  |  above the horizon (y≈52-55), fading to plain background further
  |  up; entry points and the wave-transition zoom target float here
y=12    entry points (60,12) and (180,12); undrawn zoom target (120,12)
  |     directly between them — 25%/75%/50% of width, the same
  |     proportions as Pico-8's (32,12)/(96,12)/(64,12), just
  |     repositioned for the wider canvas
y≈60    topmost reach of the enemy formation (tier 4's widest points)
  |     enemy tiers: 4 concentric bands (not 3, see Core system
  |     design's Enemy tiers note below), radii 24/36/48/100, ranging
  |     y≈60 to y≈104 depending on tier and sweep position
y=56    shared centre (120,56) = the horizon line — every tier's
  |     radius and the ship's own arc are measured from here; it's
  |     also where the land/sky split happens (below: land, purple
  |     grid; above: sky, see y=0's note) and where the ship's trim
  |     boundary rays originate, continuing to the screen edge (see
  |     Core system design below) rather than stopping at the ship's
  |     own arc radius
y≈104   lowest reach of the settled formation (tier 3's centred point)
y=126   ship's centred/rest position (120,126); ship's arc: 180°
  |     half-circle, radius 70, centred (120,56), trim ±69°
  |     (unchanged from Pico-8's exact trim angle — recheck once real
  |     ship sprite width is decided, since trim exists to keep an
  |     8px-wide sprite from clipping past the screen edge at full
  |     deflection, and that's not guaranteed to still be 8px)
y=126   HUD line begins (10px band, vs. Pico-8's 8px)
y=136
```

Land (below the horizon) and sky (above it) read as distinct zones rather than one uniform void: land keeps the purple grid lines and the void background; sky is plain black with a two-colour glow band (orange idx 9, then maroon idx 13) hugging the horizon before fading to unbroken black higher up. The horizon line itself renders in idx 9, the brightest point in the scene. Confirmed against real TIC-80 output, not just the proxy renderer.

## Palette

TIC-80's palette is remappable (unlike Pico-8's fixed hardware one), and the direction chosen was to use that room rather than carry Pico-8's exact hues forward: a synthwave-themed 16-colour set, confirmed with the user as rendered swatches before landing here, not just hex codes in a table.

| Idx | Role | Hex |
|---|---|---|
| 0 | void/background | `#150726` |
| 1 | grid | `#2c1250` |
| 2 | dark purple | `#4d1a7d` |
| 3 | magenta | `#7b1e6e` |
| 4 | rust | `#c73866` |
| 5 | slate | `#4a4470` |
| 6 | lavender | `#9a93c9` |
| 7 | white / ship body (fixed, never re-tints) | `#f2eaff` |
| 8 | hot pink / ship trim (fixed, never re-tints) | `#ff3864` |
| 9 | orange | `#ff7a3d` |
| 10 | yellow / entry points | `#ffd23f` |
| 11 | spring green | `#3df2a0` |
| 12 | cyan | `#00e5ff` |
| 13 | maroon | `#6b1743` |
| 14 | neon pink / tier-4 enemies | `#ff5ec4` |
| 15 | peach | `#ffb8a8` |

Every index's *role* mirrors Pico-8's original assignment (0 background, 7 ship body, 8 ship trim, 10 bonus/entry-point yellow) even though every hue underneath changed — this keeps README.md's "white 7, red 8 trim, fixed regardless of wave" rule intact without needing to touch that shared-level text.

Set once at boot via `poke()` into VRAM's palette bytes (`0x3fc0`, 3 bytes/colour, byte-addressed — confirmed against `tic_api_poke`'s default `bits=8`, not the nibble-addressed `poke4()` the separate draw-time colour-mapping layer uses, see `../../tools/tic80.md`'s Lua dialect & API notes). No per-wave re-tinting decided yet; Pico-8's `pal(8,ecol)`-style wave-theme rotation is a Stage B/Wrap-up question, not answered here.

## State machine

Not written yet — Stage C work (see [PLAN.md](PLAN.md)).

## Core system design

### Enemy tiers

Four concentric tiers (Pico-8 has three), radii 24/36/48/100. The fourth (radius 100, exceeding the ship's own radius of 70) exists to use the canvas's extra width — 240×136 is 87% wider but only 6% taller than Pico-8's 128×128, so growing the whole formation proportionally isn't possible without blowing the vertical budget; the width has to come from somewhere that isn't "bigger everything."

A tier's radius controls two things at once through the shared `arc_xy(r, deg) = (cx + r·sin(deg), cy + r·cos(deg))` formula: how far sideways it reaches (`sin`) and how far below the shared centre its swept centre-point sits (`cos`, at `deg=0`). A naive radius-100 tier would put that centre-point *below* the ship (`cy + 100 > cy + 70`), which reads as wrong — enemies are supposed to stay between the centre and the ship, not past it. The fix: restrict tier 4's band to 75°-88° each side, deliberately excluding the near-vertical zone. Because `sin(θ)` is nearly flat between 75° and 90° while `cos(θ)` drops fast, this band keeps almost all of radius 100's horizontal reach (x ≈ 20 to 220, nearly the full canvas) while only sweeping vertically between y≈60 and y≈82 — comfortably clear of the ship.

Tiers 1-3's bands were widened from an initial 50°/55°/60° proposal to 65°/70°/75° after a proxy render showed a visible empty gap between the core formation and tier 4's edge columns — the restricted band solved the "below the ship" problem but, unwidened, left the four tiers reading as a tight core plus two isolated satellites rather than one connected formation. Widening tier 4's own band instead (the other fix tried) closed the gap too, but dragged its sweep down to nearly the ship's own height band, undercutting the reason it has a restricted band at all. Widening the core was the cleaner fix: tier 3's new 75° outer edge meets tier 4's 75° inner edge almost exactly, so the bands hand off rather than gap.

| Tier | Radius | Band | Count (wave 1) | Colour |
|---|---|---|---|---|
| 1 (inner) | 24 | ±65° | 12 | 8 (hot pink) |
| 2 (middle) | 36 | ±70° | 10 | 8 (hot pink) |
| 3 (outer) | 48 | ±75° | 9 | 8 (hot pink) |
| 4 (wing) | 100 | 75°-88° each side | 8 | 14 (neon pink) |

Movement (sweep behaviour per tier) and wave-1 counts are implemented (see Core system design's other Stage B subsections below); wave-scaling formulas exist but aren't confirmed by extended play (see Difficulty ramp), and transitions are still Stage C work.

### Horizon and trim rays

The two lines marking the ship's trim boundary used to stop at the ship's own arc radius (70px from centre); they now run from the shared centre out to whichever screen edge they hit first (`ray_to_edge()` in `4.lua`, a generic edge-intersection helper rather than a hardcoded stopping point, so it stays correct if the trim angle changes later). The trim is exactly ±90° now (see Ship movement below), so both rays exit precisely at the horizon height on the left/right edges — `(0,56)` and `(240,56)` — rather than partway down the screen. The shared centre doubles as the horizon line's origin — see Screen layout's y=56 note.

### Ship movement

Two axes, not one: left/right set the ship's angle (pico-8 clamped this to ±69° trim; here it's exactly ±90°, see why below), up/down step between a fixed stack of concentric lanes (`LANES`) rather than pico-8's single fixed-radius arc or this build's own first pass at a continuous radius.

Each lane is an ellipse, not a circle — `lane_xy(a,b,deg) = (cx+a*sin(deg), cy+b*cos(deg))`, independent horizontal (`a`) and vertical (`b`) semi-axes. A circle can't satisfy "every lane touches the horizon, and the outer lane also touches the bottom and both side edges": reaching the bottom of the playfield straight down needs radius 70, reaching the screen's left/right edges needs radius 120, and one shared radius can't be both. With the trim at exactly 90°, `cos(90°)=0` regardless of `b`, so every lane's extreme deflection sits exactly on the horizon for free; the outer lane sets `a=120` (half the screen width) to also reach the literal edges there, and `b=70` (unchanged from the old fixed radius) so straight down still touches y=126. Inner lanes shrink both axes together, nested inside the outer one, matching "each concentric arc gets smaller, towards the horizon".

Ship (and alien) size is *not* tied to which lane/tier something occupies — an early pass did this and a play-test note called it out as the wrong axis. Both instead scale continuously by actual on-screen y, but not with the same curve. The ship's whole movement range sits between the horizon and the HUD line, so `size_by_y()` is one linear ramp across that span. Aliens range further, starting at the entry points well above the horizon (`EX_Y=12`), and a single ramp across their whole range held them at minimum size for the entire above-horizon portion of the entrance (`size_by_y` clamps to 0 above the horizon) before growing suddenly once they crossed it — reading as flat-then-sudden rather than a steady approach. `alien_size_by_y()` splits this into two segments instead, per a play-test note asking for exactly this shape: planets-to-horizon does most of the growing (tiny to a medium midpoint), horizon-to-HUD-line (the land side, where the settled formation actually lives) only grows slightly past that midpoint.

Player shots aim at the literal centre point (`CX-shx, CY-shy`, normalized), not a radial direction from the ship's angle. Those were the same thing back when the ship moved on a circle (a circle's radial direction from centre *is* the direction toward centre), but an ellipse's isn't — a point on an ellipse at parameter angle θ doesn't sit along the direction `(sin θ, cos θ)` from the centre except at θ=0/90°, so the old radial-direction shot trick pointed close to, but not exactly at, the centre dot everywhere else. A play-test note ("shots feel off ... should face roughly towards the top centre dot") caught this; aiming at the real point fixes it exactly.

Switching lanes isn't instant or a slow glide: `cur_a`/`cur_b` ease toward the target lane's shape 40% of the remaining distance per frame, landing in a handful of frames — "slide, but more like a snap," per direct play-test feedback on an earlier instant-snap version. Size doesn't need its own easing variable (see `size_by_y()` above) since it's derived fresh each frame from the already-eased position.

### Entrance sequence

Ported from pico-8's two-phase spiral entry (orbit an entry point, then blend toward the shared centre), initially skipped for this stage and then reinstated: without it, enemies fire from their formation position immediately at wave start, and a live smoke-test emptied all 5 lives before any input could matter (many enemies sit near their formation's centre angle, firing straight down the same column the ship's own rest position occupies). An entering enemy doesn't fire or dive at all, so the entrance is real breathing room, not a bolted-on grace timer.

Each wave randomizes its own entrance shape rather than reusing fixed constants, after a first fixed-parameter pass read as too fast and too repetitive once actually watched: total duration (10-25s), orbit radius (12-24px), lateral sway amplitude (20-50px, a slower sine layered under the tighter orbit for genuine side-to-side drift, not just circling), orbit direction (half the waves spin the other way), and how much of the entrance is spent circling before migrating inward (50-70%). All picked fresh in `spawn_wave`. Still being tuned against live play, these ranges aren't locked.

### Combat and lives

Enemy shots travel outward along the same radial line an enemy sits on (`dir_xy(ea)`), same idea as pico-8. Player shots don't any more — see Ship movement's note on aiming at the literal centre point instead, once the ship stopped moving on a plain circle. Lives are a life *total*, not a hit counter, unlike pico-8's flat "-1 either way": an enemy shot costs a tenth of a life, a diving hit costs a full life. This changed after the same live smoke-test above showed the flat cost draining all 5 lives almost immediately once enemies could fire at all; the HUD shows one decimal (`LIVES 4.7`) to reflect it.

## Difficulty ramp

Not written in final form yet — Stage B's constants (`ESPD_BASE`, `WFC_BASE`, `DIVE_SPD`, dive chance, per-wave enemy-count scaling) exist in `4.lua` in the same shape as pico-8's own formulas, but most are still placeholder guesses per that file's comments, not confirmed by extended play. One is further along than the rest: `ESPD_BASE` (formation sweep speed) was halved from an initial guess (0.4→0.2 deg/frame) after a direct play-test note said the settled formation swept too fast; the existing +8%/wave ramp on top of that base is unchanged and is what "ramping up over time" already meant, not a separate mechanism to add. Don't treat any current value as final; PLAN.md's Stage B checklist tracks this as in progress, not done.

## Token budget

Not written yet — needs real code to measure (Wrap-up).

## Related

- [`../pico-8/DESIGN.md`](../pico-8/DESIGN.md) — the original build's locked design, the baseline this upscale departs from
- [`../../tools/tic80.md`](../../tools/tic80.md) — TIC-80 constraints, RAM/VRAM layout, cart format, CLI workflow, and Known pitfalls (screenshot limitations, palette poke mechanics)
- [`../../tools/tic80/sprite_tool.py`](../../tools/tic80/sprite_tool.py) — asset tooling, not yet used here (Stage A uses primitive shapes; real sprite authoring is later)
