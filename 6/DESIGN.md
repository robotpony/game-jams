# 6 Dug, Dug, Down. — Design

Pre-implementation technical design. See [`../SPEC-FORMAT.md`](../SPEC-FORMAT.md) for what this document covers versus [README.md](README.md) and [CLAUDE.md](CLAUDE.md).

## Screen layout (128×128)

Game screen:

```
y=0
  |  cave view: scrolling camera follows the player, fog beyond
  |  the visibility radius, blocks/monsters/chests within it
y=111
y=112   HUD line (16px: HP | coins | equipped tool/weapon icons)
y=127
```

- Cave view: y=0-111, camera centred on the player, clamped at the world's edges (same clamping behaviour as game 2's shaft camera and game 5's vertical camera).
- HUD: y=112-127, matching the bottom-strip convention games 1, 2, and 5 already use.

Inventory overlay: full-screen, paused. 8 general item-type slots plus the tool-equip and weapon-equip slots, and a crafting sub-area (recipe list, craftable-now highlighted based on current materials). Exact layout not sketched yet, depends on the visual style conversation.

Help overlay: full-screen, paused, matching game 2's help-screen precedent (bezel border, distinct text colour). Content: controls, a tool-tier/block-tier table, a monster-drop/recipe table.

## Palette

Uses Pico-8's native colour names directly (unlike games 1-5's Atari-2600 approximation renaming); the semantic item names already map to intuitive real colours (gold is yellow, water is blue), so no renaming layer is useful here.

Blocks are distinguished by a shared family base colour plus, for anything valuable, a semantic accent colour and a distinguishing pattern, not by giving all 16 blocks unique hues. Pico-8 only has 16 colours total for the whole screen at once, so reuse across blocks/characters is deliberate, not a shortcut:

| Element | Colour | Index |
| ------- | ------ | ----- |
| Loose Dirt, Clay, Rubble (soft-earth family base) | Brown | 4 |
| Packed Stone, Mossy Rock, Flint, Dense Rock (hard-stone family base) | Dark grey | 5 |
| Copper Ore (accent on the stone base) | Orange | 9 |
| Gold Ore, Treasure Vein (accent on the stone base; nugget vs. sparkle-cluster pattern) | Yellow | 10 |
| Crystal Ore, Glowstone (accent on the stone base; faceted-gem vs. radiating-dot pattern) | Blue | 12 |
| Ancient Stone | Dark purple | 2 |
| Iron Ore | Dark grey base, rust fleck (reuses brown, no new index) | 5 + 4 |
| Lava | Red | 8 |
| Deep Water | Blue | 12 (reused from Crystal/Glowstone; different context, full-tile fill vs. small in-block accent) |
| Player | White | 7 |
| Cave Bat | Dark grey | 5 (reused) |
| Rock Crawler | Brown | 4 (reused; camouflaged-with-rock flavour fits an easy enemy that guards ore) |
| Spitting Slug | Green | 11 |
| Tunnel Wraith | Lavender | 13 |
| Bone Archer | Light grey | 6 |
| Cave Warden | Pink | 14 (kept distinct from Lava's red so the boss doesn't blend into a hazard) |
| Chest | Brown | 4 (reused), with a yellow (10) latch/highlight detail |
| HUD text | White | 7 |
| Fog boundary | Black (0) fading via dither to unlit | 0 |

Black (0) and a couple of other indices (e.g. white 7 doubling as an outline colour) stay free for outlines, UI borders, and the fog dither.

## State machine

| `gs` | Name | Entered from | Exits to |
| ---- | ---- | ------------- | -------- |
| 0 | Title | startup | 1 (any button) |
| 1 | Playing | title, or retry from end | 2 (inventory input); 3 (using the book, if found); 4 (HP reaches 0) |
| 2 | Inventory | playing (inventory input) | 1 (inventory input again, or close); 3 (using the book, if found) |
| 3 | Help | playing or inventory (using the book) | back to whichever state it was opened from, on any button |
| 4 | End | playing (HP reaches 0) | 0 (any button) |

## Core system design

**Controls** — Pico-8 gives this game 4 direction buttons plus 2 action buttons (O/Z, X), and it needs more distinct actions than that (mine, attack, parry, interact, inventory-toggle), so most of the mapping is context-sensitive rather than one-button-one-action:

| Input | Effect |
| ----- | ------ |
| Directions | Move (8-way) and set facing (see Mining below) |
| O, held, facing a block | Mine (damage-over-time while resistance is met) |
| O, tapped, facing a monster in melee range | Attack (weapon swing) |
| O, tapped, facing a chest | Interact (open) |
| X, tapped | Parry (timed window, see Combat below) |
| O+X, held together | Toggle Inventory overlay |

No dedicated run button: with both action buttons already spoken for, movement is a single fixed speed rather than adding a walk/run chord (see README's Player section). "Any button" scene transitions (Title/End/Help-dismiss) aren't gameplay-sensitive, so they're unaffected by this mapping. The Help overlay's controls reference (see Chests & help) should show this table.

**World generation** — A single bounded cave, generated once at game start, stored in Pico-8's native map (128×64 cells), in two passes, neither of which uses a continuous noise function:

1. **Floor/wall shape**: classic cellular automata. Randomly fill the map (each cell wall with some seed probability, e.g. ~45%), then run a handful of smoothing iterations (a cell becomes wall/floor based on how many of its 8 neighbours are currently wall, via repeated `lib/map.lua` `neighbour()` scans) until the noisy fill relaxes into organic-looking connected caverns. Spawn lands on open floor by construction (pick a floor cell, or force one open if the seed roll didn't leave one nearby).
2. **Block type per wall cell**: no spatial noise here either. Each wall cell rolls its tier via `lib/rng.lua`'s `weighted()`, with the weight table itself shifted by that cell's distance-from-spawn (closer cells get a table biased toward tier 1, farther cells shift weight toward tier 2/3), then a specific block within that tier picked uniformly. Equivalent in effect to the originally-sketched "compute base tier then re-roll cells the current distance doesn't unlock," but implemented as a single weighted roll against a distance-adjusted table rather than a separate re-roll step.

Mining a wall block converts that cell to floor; player, monsters, and chests are only ever placed on floor cells, never embedded in unmined wall. Chosen over a value-noise lattice or layered sin/cos approximation for token cost: cellular automata's neighbour-count rule is a handful of cheap integer comparisons per cell (and reuses `map.lua`'s `neighbour()`), with no interpolation or trig math anywhere in generation.

**Spawn placement** — Randomized each run rather than fixed, within a margin from the map's edges (enough room on every side for the tier-2/3 gradient to have space to play out; exact margin TBD once world gen is implemented and testable). "Distance from spawn" is Euclidean tile distance from that run's spawn point, recomputed against whichever cell the player is checking.

**Edge wraparound** (Phase 3) — The bounded map's four edges wrap rather than acting as a hard stop: movement that would carry the player past a boundary instead repositions them to the mirrored coordinate on the opposite edge (`x` wraps against `w*8`, `y` against `h*8`, independently per axis, so a corner wraps both at once). If the mirrored cell isn't floor (the world-gen passes don't guarantee the opposite edge happens to be open at that exact row/column), slide along that edge to the nearest floor cell rather than teleporting into solid wall. The scrolling camera needs no dedicated wrap-handling: it's recomputed fresh from `px`/`py` every frame (Phase 1's `mid()` clamp) rather than tweened, so a wrap reads as a hard cut, not a pan across the whole map. Distance-from-spawn (used by both block-tier and, later, monster-difficulty biasing) stays a plain Euclidean measure using the player's un-wrapped cell coordinate; wrapping doesn't change how "far" a cell is from spawn, only where the player's own position resets to.

**Mining** — Targets the tile in the player's current facing (last of the 8 movement directions, persists while stationary; see README's Player section). Two stats per block type: `resistance` (minimum tool tier required to make any progress) and `hp` (damage needed once that threshold is met). First-pass tuning:

| Tier | Resistance | HP |
| ---- | ---------- | -- |
| 1 | 1 | 10 |
| 2 | 2 | 20 |
| 3 | 3 | 35 |

Treasure Vein and Glowstone: resistance 1 (any tool), HP 10, so they're always breakable regardless of what tool the player currently has equipped. Lava and Deep Water aren't mined at all; they're terrain hazards (contact damage / movement penalty respectively), not breakable blocks.

Tool power (damage dealt per mining tick while resistance is met), first-pass:

| Tool tier | Power |
| --------- | ----- |
| 1 (Basic Pick) | 2/tick |
| 2 (Mid Pick) | 4/tick |
| 3 (Advanced Pick) | 7/tick |
| 4 (Runic Pick) | 12/tick |

A higher tool tier both unlocks harder blocks (via resistance) and mines faster (via power), so upgrading is always worth it, not just a gate — except tier 4, which is pure power with no new resistance to unlock (no block needs resistance 4; see README's Blocks, mining & crafting on Ancient Stone). Runic Pick is a reward for reaching the deepest terrain, not a further gate on top of it.

**Combat** — Weapon damage per hit, first-pass:

| Weapon tier | Damage |
| ----------- | ------ |
| 1 (Basic Blade) | 2 |
| 2 (Mid Blade) | 4 |
| 3 (Advanced Blade) | 7 |
| 4 (Runic Blade) | 12 |

Parry is a timed input (a short window, tune once playable, starting guess ~6-10 frames) that fully negates incoming damage from an attack landing during it, distinct from a passive block; whiffing a parry outside its window does nothing (no penalty beyond taking the hit normally). Applies uniformly to melee and ranged damage, including Spitting Slug's spit, Bone Archer's arrows, and Cave Warden's ranged mode, not just melee swings: the check is "did damage land during the window," not attack type.

Player HP: starts at 10 (first-pass, tune once playable).

Monster HP/damage, first-pass, scaling with the difficulty ladder from README's Monsters table:

| Monster | HP | Damage |
| ------- | -- | ------ |
| Cave Bat | 4 | 1 |
| Rock Crawler | 10 | 2 |
| Spitting Slug | 8 | 2 |
| Tunnel Wraith | 12 | 2 |
| Bone Archer | 10 | 3 |
| Cave Warden | 25 | 3 |

**Visibility** — A radius (in tiles, tune once playable, starting guess 3-4 tiles) around the player is fully lit; beyond it, blocks/monsters/chests aren't drawn. The lit/unlit boundary itself dithers rather than cutting sharply (a chosen visual treatment, not just "nothing drawn" — costs more per-frame draw work than a hard cutoff, budget for it in Phase 9's token check). Glowstone blocks and an equipped Lantern each extend the radius while the player is near/holding one; no stacking, `radius = max(base, glowstone_radius, lantern_radius)` when both are in effect at once, simpler than tuning an additive bonus pair and avoids the fog mechanic getting trivialized by parking next to a Glowstone with a Lantern equipped.

**Chests** — Placed during world generation at a modest rate (tune once playable), not a block type, walked up to and opened with an interact input (instant, no timed search). Loot table: weighted toward common materials, a smaller chance of a Health Potion, a small chance of the Book (skipped once already found).

**Crafting** — Recipes are a flat lookup table (output item → list of required input items/counts), matching the flat-array-by-colour-id pattern games 1 and 3 already use for their own lookup tables. Checked from the Inventory overlay; a recipe is shown as craftable once the player's current materials meet every requirement.

**Scoring** — `score = distance_from_spawn_reached + coins*k + materials_collected*j`, a weighted sum shown on the End screen alongside its raw components (coins, distance). Weights `k`/`j` are first-pass/tune-once-playable, not locked; start both at 1 and adjust once real runs show whether distance or collection dominates.

## Difficulty ramp / win condition

No win condition; the run ends when player HP reaches 0 (see README's Game over conditions). The ramp is spatial, not time-based: block tier and monster difficulty both scale with Euclidean distance from that run's (randomized) spawn point, via the re-roll rule in World generation above. There's no separate formula beyond that re-roll rule; this section exists mainly to record that the ramp is deliberately not a survival-timer or wave-count mechanic, so it isn't reintroduced later by habit (games 3 and 5 both use time/wave-based ramps, this game intentionally doesn't).

## Token budget

This is the most system-dense game in the jam so far: procedural cave generation, 16 block types with their own resistance/HP pairs, 6 monsters each with distinct AI (melee vs ranged) and drops, an 8-type inventory plus 2 equip slots, 8 crafting recipes, chests with a loot table, a visibility/fog system, and a full help-overlay reference screen, all inside the same ~8,192-token budget the smaller games in this jam already found tight. Phase 0 builds the `lib/` primitives this game actually needs (state machine, collision, map queries, seeded RNG) before Phase 1 starts, rather than assuming they're already free; their token cost still counts against this game's budget the same as inline code would. Expect this to need real trimming once actual token counts come in during Phase 8 (or possibly earlier); treat every "first-pass" number above as something to simplify, not just retune, if the budget doesn't fit.
