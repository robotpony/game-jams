# 7 Perfect War

A two-player hex-based WWII combined-arms wargame, approximated through Pico-8's native palette with a distinct semantic colour mapping rather than the jam's usual Atari-2600 look (see [DESIGN.md](DESIGN.md)'s Palette table).

## Core Concept

A two-player hex-based wargame (human vs. human or human vs. AI) set in WWII-era combined arms combat. You win by accumulating **Victory Points** through controlling towns, not by destroying enemy units.

---

## Setup

**Buy Points:** Each scenario grants a fixed pool of buy points. You spend them to purchase your starting forces from the unit roster. The attacker always has more points than the defender.

**Unit Placement:** After buying units, you place them within your designated setup zone before the game begins.

---

## Turn Sequence

Each turn proceeds in this order, with attacker and defender alternating within each phase:

1. **Unit Purchase & Placement** — spend any available reinforcement points
2. **Mobile Artillery Plot** — mobile artillery plots its indirect fire targets (fires next phase)
3. **Indirect Fire** — mobile artillery and previously-plotted stationary artillery fire; shots may drift 0–3 hexes
4. **Artillery Plot** — stationary artillery (Light/Heavy) plots shots *for the next turn*
5. **First Direct Fire** — any unit with a spotted enemy in LOS and range may fire; targeted units may fire **Return Fire** before the incoming shot resolves
6. **Movement** — units move; enemy unfired units may take **Passing Fire** at units moving past them
7. **Second Direct Fire** — units that haven't fired yet may fire; return fire applies again
8. **Scoring** — towns occupied *exclusively* by one side award Victory Points; game advances to next turn

---

## Victory

Towns have point values. You must have a unit **in** the town at **end of turn** with no enemy also present — otherwise no points are awarded. Destruction of enemy units gives no direct VP. Final VP total determines the winner.

**Match Game:** The "true test" — play the scenario twice, switching attacker/defender roles. Your combined score across both games is compared.

---

## Unit Types

| Unit | Move | Notes |
|------|------|-------|
| Armored Car | 9 | Fastest; weakest armor; good for transport runs and flanking |
| Light Tank | 6 | Cheap, flexible, weak vs. heavy armor |
| Medium Tank | 5 | Best all-around unit |
| Heavy Tank | 4 | Slowest, most powerful armored unit; expensive |
| Mobile Artillery | 4 | Fires indirect next phase (not next turn); can also direct-fire like a heavy tank; cannot transport other units |
| Infantry | 1 | Cheap; can only damage armor at range 1; useful for scouting and holding towns |
| Engineer | 1 | Same as infantry + can build/destroy bridges and mines |
| Bazooka | 1 | Infantry movement/defense but Light Tank offensive firepower; good cheap anti-armor |
| Light Artillery | 0 | Must be transported; plots indirect fire one turn ahead; can also direct fire |
| Heavy Artillery | 0 | Same as Light but longer range and much heavier barrage area (strike hex + all 6 adjacent) |
| Mine | — | Destroys any unit that enters its hex; survives two detonations; Engineer or direct artillery hit removes it |

---

## Combat

### Direct Fire

- Target must be *spotted* and within LOS and effective range
- Each unit fires at most **once per turn**, across all fire phases
- The targeted unit may take **Return Fire** (if it hasn't fired yet) — fires *before* the incoming shot resolves
- Units cannot fire at night

### Indirect (Artillery) Fire

- Target location must be in LOS of *any* friendly unit (not necessarily the artillery itself)
- Shots can drift; adjacent units take splash damage
- **Barrage** option blocks movement through the strike area for the rest of the turn; Heavy artillery barrage also affects all 6 adjacent hexes
- Mobile artillery fires the *same* turn it plots; stationary artillery fires the *next* turn

### Close Assault

- An *unfired* armored unit (not mobile artillery) can move onto an enemy-occupied hex
- One unit dies; the other survives (possibly damaged under Partial Kill rules)
- Victory odds depend on attacker/defender unit types, with these modifiers:
  - +20% if defender has already fired this turn
  - −10% if defender is in cover (city, forest, or higher ground)
  - −20% if attacker is >50% damaged (Partial Kill rules only)
  - Odds are clamped to 5%–95%

---

## Spotting & Ambush

- Units start **unspotted** and cannot be targeted by direct fire even if their location is visible
- A unit becomes spotted when it moves or fires within enemy LOS, or occupies open terrain an enemy can see
- Units revert to unspotted at the end of any phase if outside all enemy LOS
- Forest, towns, and fortifications block LOS; hills give range and accuracy bonuses to higher-positioned units
- Maximum visibility: 25 hexes (clear day), 10 (fog), 5 (night)

---

## Transport

- Armored Cars, Light/Medium/Heavy Tanks can carry Infantry, Engineers, Bazookas, and Artillery
- Loading and unloading each costs 1 movement point; the carrier must move off the drop hex after unloading
- Cargo cannot fire or move independently until the next turn
- If the carrier is destroyed, its cargo is also destroyed

---

## Terrain

| Terrain | Movement Cost | Notes |
|---------|--------------|-------|
| Clear / Field | 1 MP | Baseline |
| Road | ½ MP | Only while traveling *along* it |
| Track / Railroad | 1 MP | Same as clear |
| Forest | ½ movement rate on entry | Blocks LOS; grants defensive bonus; becomes rubble if shelled |
| Hill | 2× cost uphill | Higher altitude: +1 firing range, combat advantage |
| Town | ½ MP | Blocks LOS; grants defensive bonus; rubble if shelled (2 MP to enter) |
| Rough / Desert / Cratered | 2× | No combat bonus |
| River | Infantry/Engineer: 1 MP; Armor: impassable | Engineers can build bridges |
| Bridge | ½ MP (road speed) | Engineers can destroy them |
| Fortification | — | Blocks LOS; defensive bonus |
| Beach | 2× (rough) | Armor can land here; otherwise acts as desert |
| Sea / Lake | Impassable | — |

---

## Rules Options

| Option | Choices | Effect |
|--------|---------|--------|
| Kill mode | Full Kill / Partial Kill | Instant death on any hit vs. accumulated damage points |
| Hit mode | Always Hit / Random Hit | Deterministic vs. probability-based combat |
| Visibility | Full View / Limit to LOS | All units visible vs. unspotted units hidden (two-human-on-one-PC forces Full View) |
| Game length | Standard / Long | Most scenarios offer two lengths; Long game adds more buy points |
| Handicap | Slider | Reduces one player's buy points for balance adjustment |