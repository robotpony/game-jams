# 7 Perfect War — Design

Pre-implementation technical design for `7.p8`, based on [README.md](README.md) and the scope decisions from the design conversation. Follows [`../SPEC-FORMAT.md`](../SPEC-FORMAT.md).

All specific numbers below (costs, HP, ranges, map layout) are first-pass balance values, not verified by play. Expect to retune them once the cart is playable, the same way game 5's tile geometry and game 4's arc placement went through several play-test-driven revisions before landing.

## Scope locked by the design conversation

- 5-unit roster (down from README's 11): Light Tank, Medium Tank, Infantry, Mobile Artillery, and a merged stationary Artillery (combining Light/Heavy, keeping the plot-this-turn/fire-next-turn mechanic). No Armored Car, Heavy Tank, Bazooka, Engineer, Mine, or Transport rule.
- 6-terrain roster (down from README's 11): Clear, Road, Forest, Town, Hill, Water. No rubble transitions, rivers/bridges, fortifications, beach, rough, or track.
- Rules fixed, no options menu: Random Hit, Partial Kill, Limit to LOS, Standard length, no handicap.
- Simplified LOS: spotted = within visibility range, blocked by terrain on the viewer's hex, the target's hex, or the single hex directly between them (not a full raycast). Visibility range (25 hexes clear-day per README) exceeds the whole map at this scale, so day/fog/night aren't modelled; spotting is governed entirely by terrain-blocking and the moved-or-fired-in-enemy-LOS rule.
- Both modes exposed at the title screen: 1P vs AI and 2P Hotseat.
- Build order: rules engine first (playable and verifiable via 2P Hotseat), AI added later as a phase that reuses the same movement/fire/spotting functions to drive whichever role the 1P human didn't pick.
- One fixed scenario, Standard length = 10 turns.
- AI: greedy heuristics only (fire at any spotted target in range, step toward objective with adjacent-hex retry if blocked, plot artillery at last-known enemy position, close-assault only at favourable odds, spend reinforcement points off a fixed priority list). No lookahead or scoring.
- Match Game (double match, swapped roles, combined score) deferred to a stretch goal.

## Screen layout (128×128)

**Title (`gs=0`)** — shared jam title card via [`lib/title.lua`](../lib/CLAUDE.md)'s `draw_title_card()` and `blink()`, same as games 1, 3, and 5. No custom layout needed.

**Mode select (`gs=1`)**

```
y=20   "PERFECT WAR"

y=56   > 1 PLAYER VS AI
y=68     2 PLAYER HOTSEAT

y=110  up/down to choose, o to confirm
```

**Role select (`gs=2`, 1P mode only — 2P mode skips straight to Buy, P1=Attacker/P2=Defender)**

```
y=20   "CHOOSE YOUR SIDE"

y=56   > ATTACKER  (30 pts, moves first)
y=68     DEFENDER  (20 pts, holds the towns)

y=110  up/down to choose, o to confirm
```

**Buy / Setup (`gs=3`)**

```
BUYING: ATTACKER                        PTS LEFT: 12

  > LIGHT TANK   cost 4   x2            [+][-]
    MEDIUM TANK  cost 6   x1
    INFANTRY     cost 2   x3
    MOBILE ARTY  cost 5   x0
    ARTILLERY    cost 5   x0

y=104  cursor on hex map: place purchased units in your zone
y=118  o: confirm placement    x: done buying
```

The same screen and shop logic run twice per match (Attacker buys/places, then Defender), and are reused every turn during Phase 1 for reinforcement spending, minus the placement step (reinforcements enter at a fixed hex in the owner's zone rather than being freely placed).

**Playing (`gs=4`)** — the hex battlefield, scrolled, camera following the active/selected unit

```
y=0                                     playfield: 128×112 viewport
  |  scrolling hex battlefield (15x11 hexes, world ~164x150px)
  |  hex tiles: terrain colour + outline
  |  units: 8x8 sprite, faction colour (red=attacker, teal=defender)
  |  selected/active unit: yellow outline
  |  unspotted enemy units: not drawn at all
y=111
y=112  HUD (16px): TURN n/10 | PHASE NAME | ATK vp : DEF vp
y=127
```

**End (`gs=5`)**

```
y=30   "ATTACKER WINS" / "DEFENDER WINS" / "DRAW"

y=60   ATK VP: n     DEF VP: n
y=72   TURNS PLAYED: n

y=110  any button: title
```

## Palette

Distinct semantic palette (real colour names matched to meaning), following game 6's precedent rather than the Atari-2600 approximation games 1-5 use:

| Element | Colour | Index |
| ------- | ------ | ----- |
| Clear (field) | green | 11 |
| Road | light_grey | 6 |
| Forest | dark_green | 3 |
| Town | brown | 4 |
| Hill | dark_grey | 5 |
| Water (impassable) | dark_blue | 1 |
| Attacker units | red | 8 |
| Defender units | teal | 12 |
| Selected/active unit outline | yellow | 10 |
| HUD text | white | 7 |
| VP / score highlight | yellow | 10 |

## State machine

| `gs` | Name | Entered from | Exits to |
| ---- | ---- | ------------- | -------- |
| 0 | Title | startup | 1 (any button) |
| 1 | Mode select | title | 2 (1P chosen) or 3 (2P chosen, roles auto-assigned) |
| 2 | Role select | mode select (1P only) | 3 |
| 3 | Buy / Setup | role select, or 2P auto-assign | 4 (both sides done buying+placing) |
| 4 | Playing | buy/setup | 5 (turn counter exceeds 10, or a side's VP makes the outcome decided early — see Victory below) |
| 5 | End | playing | 0 (any button) |

`gs==4` runs its own 8-phase turn sequence via a sub-counter `ph` (1-8, matching the README's Turn Sequence numbering), looping back to `ph=1` at the start of each new turn until the turn limit is reached.

## Core system design

### Hex grid & coordinates

15 columns × 11 rows, odd-q offset coordinates (flat-top hexes, columns offset vertically — the classic wargame hex orientation). Stored as a plain Lua table (`hex[col][row] = {terrain=t, unit=u_or_nil}`), not Pico-8's native `__map__` section: `__map__` is a square grid, and forcing hex offset addressing onto it would cost more than just drawing hexes procedurally from a flat table.

Pixel conversion: hex width 14px, height 12px, column step 10px, row step 12px, odd columns shifted down 6px.

```
screen_x = col * 10 - camera_x
screen_y = row * 12 + (col % 2 == 1 and 6 or 0) - camera_y
```

World size ≈ 164×150px against a 128×112px playfield viewport (bottom 16px reserved for HUD), so both axes need to scroll. Camera follows whichever unit is currently active (selected by the human, or acting under AI control), clamped to world bounds — no free-pan mode.

Six neighbour directions for odd-q offset columns (even/odd columns have different neighbour deltas — the standard hex-offset asymmetry): precompute both tables once at `_init()` rather than branching on parity at every lookup.

### Unit stats

| Unit | Move | Cost | HP | Direct atk | Direct rng | Def | Indirect atk | Indirect rng | Splash |
| ---- | ---- | ---- | -- | ---------- | ---------- | --- | ------------- | ------------- | ------ |
| Light Tank | 6 | 4 | 3 | 3 | 3 | 2 | — | — | — |
| Medium Tank | 5 | 6 | 4 | 4 | 3 | 3 | — | — | — |
| Infantry | 1 | 2 | 2 | 1 | 1 | 1 | — | — | — |
| Mobile Artillery | 4 | 5 | 2 | 3 | 3 | 1 | 3 | 6 | target hex only |
| Artillery (stationary) | 0 | 5 | 3 | — | — | 1 | 4 | 8 | target + 6 adjacent |

Infantry's README restriction ("can only damage armor at range 1") is simplified to a flat range-1 direct-fire rule against any spotted target, not type-restricted targeting — a second targeting rule for marginal realism isn't worth the tokens here.

Mobile Artillery keeps single-hex splash (the README's "Light"-style behaviour); the merged stationary Artillery keeps the wider "Heavy"-style splash (target hex plus all 6 neighbours), since that's the more distinctive of the two and worth keeping when only one stationary tier survives the trim.

Stationary Artillery's 0 move plus the deferred Transport rule means it's placed once during Buy/Setup and never repositioned for the rest of the match — consistent with "stationary" as a name, not a gap to fix.

### Terrain stats

| Terrain | Move cost | Blocks LOS | Defensive bonus | Passable |
| ------- | --------- | ---------- | ---------------- | -------- |
| Clear | 1 | No | None | Yes |
| Road | 0.5 (only along it) | No | None | Yes |
| Forest | 2 | Yes | Yes | Yes |
| Town | 0.5 | Yes | Yes | Yes (victory objective) |
| Hill | 2 (uphill) | No | +1 range/accuracy to occupant | Yes |
| Water | — | No | — | No |

### Spotting

Units start unspotted. A unit becomes spotted when it moves or fires within enemy LOS, or occupies non-blocking terrain within enemy LOS. It reverts to unspotted at the end of any phase if outside all enemy LOS. Only spotted units can be targeted by direct fire; artillery can target any hex regardless of spotting (per README, indirect fire only needs LOS from *some* friendly unit to the target hex, not the target itself being spotted).

LOS check (simplified, see Scope section above): blocked if the viewer's hex, the target's hex, or the single hex directly between them has `blocks_los=true` terrain.

### Turn sequence (`ph` within `gs==4`)

1. **Purchase & Placement** — both sides spend any reinforcement points earned this turn (Attacker +6/turn, Defender +4/turn), via the same shop screen as initial Buy/Setup, minus free placement: new units enter at a fixed reinforcement hex in the owner's zone.
2. **Mobile Artillery Plot** — owning player picks a target hex for each Mobile Artillery that wants to fire this phase-cycle.
3. **Indirect Fire** — Mobile Artillery fires now (drift 0-3 hexes, random direction); stationary Artillery that plotted last turn fires now too.
4. **Artillery Plot** — stationary Artillery plots a target hex for next turn's Indirect Fire.
5. **First Direct Fire** — any unit with a spotted enemy in LOS and range may fire; the target may fire Return Fire first if it hasn't fired yet this turn.
6. **Movement** — units move, spending MP by terrain cost. No Passing Fire (dropped from the README's version to control scope — see Token budget below).
7. **Second Direct Fire** — units that haven't fired yet this turn may fire, with Return Fire as in phase 5.
8. **Scoring** — any town occupied exclusively by one side awards its VP to that side; turn counter increments; if `turn > 10`, go to `gs=5`.

### Combat resolution

**Direct fire (Random Hit, Partial Kill):** hit chance = `50% + (attacker_atk - defender_def) * 10%`, clamped 10-90%. A hit deals 1 HP damage. Return Fire uses the same formula with attacker/defender swapped, resolved before the original shot if the target hasn't fired yet this turn.

**Indirect fire:** the drifted impact hex (and, for stationary Artillery, its 6 neighbours) always deals damage — no separate to-hit roll, since drift already represents the inaccuracy. Damage = `max(1, blast_atk - target_def)`.

**Drift:** roll `d = flr(rnd(4))` (0-3 hexes), then walk `d` steps in a randomly chosen one of the 6 neighbour directions from the plotted target hex.

**Close assault:** an unfired armored unit (Light or Medium Tank; Mobile Artillery direct-fires instead per README) can move onto an enemy-occupied hex. Odds = `50% + (attacker_atk - defender_def) * 10%`, then `+20%` if the defender has already fired this turn, `-10%` if the defender is on blocking/defensive terrain, `-20%` if the attacker's current HP is below half its max (Partial Kill only), clamped 5-95%. A single roll resolves it: the loser is removed outright (this is the one place combat isn't HP-based, matching the README's "one unit dies, the other survives").

### AI (built after the rules engine is proven via 2P Hotseat — see PLAN.md)

Greedy heuristics only, no lookahead:

- **Movement**: step toward the nearest uncontested objective town (or, if any enemy is spotted, toward the nearest spotted enemy instead); on a blocked hex, retry an adjacent hex once before giving up movement for that unit this turn.
- **Targeting**: fire at any spotted enemy in range; if multiple are in range, prefer the lowest-HP target (likely to die this turn).
- **Artillery plotting**: target the last hex a spotted enemy was seen at; if nothing has ever been spotted, hold fire that phase.
- **Close assault**: only initiate if computed odds ≥ 60%.
- **Reinforcement buy**: spend affordable points on the next unit off a fixed priority list — Medium Tank, Light Tank, Infantry, Mobile Artillery, Artillery — placing it at the fixed reinforcement hex.

The AI needs to be able to play either role (Attacker or Defender), since in 1P mode the human picks which side to take.

## Victory & match length

Standard length = 10 turns. At `turn > 10`, or immediately if one side reaches an outright VP majority no longer contestable (optional early-exit, skip if it adds meaningful complexity), go to End. Whoever has more total VP wins; equal VP is a draw. No sudden-death tie-break — Match Game (replay swapped, combined score) is the README's own answer to "which side is really better," and that's deferred.

## Token budget

This is the most rules-dense cart in the jam by rule count — a two-role AI on top of a full wargame ruleset — but token count hasn't tracked rule count so far: game 5 (the previous "most system-dense" entry) landed at ~2,898/8,192, and game 6 at 4,357/8,192, both with real headroom left. No cuts are planned in advance; PLAN.md's Phase 10 measures the real number once the cart exists, and that's the point to decide anything, not before.

Lean on [`lib/`](../lib/CLAUDE.md) for input handling, the state machine, HUD, and seeded RNG (needed for drift rolls and AI decisions) rather than rederiving them; the hex grid, unit/terrain tables, and combat/AI logic are novel to this game and aren't in `lib/` yet.
