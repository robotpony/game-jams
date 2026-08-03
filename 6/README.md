# 6 Dug, Dug, Down.

A procedurally generated top-down cave-mining RPG with crafting and combat. Follows the format in [`../SPEC-FORMAT.md`](../SPEC-FORMAT.md).

**Status: not yet built.**

Unlike games 1-5, this one doesn't use the Atari-2600-via-Pico-8 look. The palette leans on Pico-8's real colour names directly and matches them semantically to what each thing is (gold is yellow, water is blue); see Tile / sprite visuals below.

## Game overview

The player explores a single large cave, generated once at the start of a run by carving connected caverns with cellular automata (Pico-8 has no native Simplex/Perlin noise, and cellular automata turned out cheaper in tokens than approximating one; see DESIGN.md's World generation). The remaining walls are filled with 16 kinds of destructible blocks: common filler like dirt and clay, ore that feeds crafting, hazards like lava and water, and a couple of special blocks. Harder, rarer blocks cluster farther from the player's starting point, so distance from spawn is the game's difficulty curve.

The player mines blocks with an equipped tool, fights the cave's 6 monster types with an equipped weapon, and crafts better tools and weapons from the ore and monster drops they collect. Visibility is limited to a radius around the player, fog beyond it, so a light source matters. There's no win condition: the run ends when the player's HP reaches 0, and the score is built from how far they got and what they collected.

Random chests scattered through the cave hold loot, mostly materials and potions, occasionally a book that unlocks a permanent, re-readable in-game reference screen (controls plus a full tool-tier/block-tier/recipe cheat sheet).

## Scenes

| Scene | Shows | Enters from | Exits to |
| ----- | ----- | ------------ | -------- |
| Title | Shared jam title card: colour-swatch strip, "'26 WARPED GAME JAM", "6 DUG, DUG, DOWN.", blinking start prompt | Startup | Any button → Game |
| Game | Cave view (camera follows player, scrolling), player, monsters, HUD (HP, coins, equipped tool/weapon) | Title | HP reaches 0 → End; inventory input → Inventory |
| Inventory | Paused overlay: 8 general item-type slots, tool-equip slot, weapon-equip slot, crafting | Inventory input, from Game | Inventory input again, or a close button → Game (unpaused) |
| Help | Paused full-screen overlay: controls, tool-tier/block-tier reference, monster-drop/recipe reference | Reading the book, from Inventory or Game once the book has been found | Any button → back to where it was opened from |
| End | Death screen: coins collected, distance reached, score | HP reaches 0, from Game | Any button → Title |

## Blocks, mining & crafting

- **World**: one large cave, generated once at game start by carving floor/wall shape with cellular automata, then assigning each wall cell one of the 16 block types via a distance-biased weighted roll (no continuous noise function; see DESIGN.md's World generation), stored in Pico-8's native map (128×64 cells) — a single bounded world with a scrolling camera, the same pattern games 2 and 5 already use, not an infinite/streaming world. Player, monsters, and chests all occupy open floor from the start; mining a wall block converts it to floor rather than being how the player creates all traversable space. The map's four edges wrap: walking into one teleports the player to the corresponding position on the opposite edge (see DESIGN.md's World generation and PLAN.md's Phase 3) rather than stopping at a hard boundary.
- **Breaking a block**: hold the mine input while facing/adjacent to a block. Each block has two stats: a **resistance** threshold (the minimum equipped-tool tier that can make any progress at all — a weaker tool literally can't scratch it) and an **HP** pool (chipped away over time once the resistance threshold is met, at a rate set by the tool's power). Breaking a block adds its drop to inventory.
- **16 block types**, by tier:

| Tier | Blocks |
| ---- | ------ |
| 1 (basic tool) | Loose Dirt, Clay, Copper Ore, Rubble |
| 2 (mid tool) | Packed Stone, Iron Ore, Mossy Rock, Flint |
| 3 (advanced tool) | Dense Rock, Gold Ore, Crystal Ore, Ancient Stone |
| Hazard | Lava (damages on contact, not mined), Deep Water (slows movement, not mined) |
| Special | Treasure Vein (any tier, guaranteed bonus drop), Glowstone (any tier, passively lights nearby tiles) |

- **Distance-based difficulty**: tier-2 and tier-3 blocks, and tougher monsters, become more common the farther a tile is from the player's spawn point (Euclidean tile distance). Near spawn, the cave is mostly tier-1 material and easy monsters. Spawn location is randomized each run, within a margin from the map edges so the tier gradient has room to play out in every direction; see DESIGN.md's Spawn placement note.
- **Crafting**: done from the Inventory overlay, anywhere, no crafting station needed. Recipes:

| Item | Recipe |
| ---- | ------ |
| Basic Pick (tool 1) | 3× Copper Ore |
| Mid Pick (tool 2) | 3× Iron Ore + 1 Basic Pick |
| Advanced Pick (tool 3) | 3× Gold Ore + 1 Mid Pick |
| Basic Blade (weapon 1) | 2× Copper Ore + 1 Bat Wing |
| Mid Blade (weapon 2) | 2× Iron Ore + 1 Wraith Essence |
| Advanced Blade (weapon 3) | 2× Gold Ore + 1 Crystal Ore + 1 Warden Core |
| Runic Pick (tool 4) | 3× Ancient Stone + 1 Advanced Pick |
| Runic Blade (weapon 4) | 2× Ancient Stone + 1 Warden Core + 1 Advanced Blade |
| Lantern | 2× Glowstone |
| Health Potion | 2× Mossy Rock |

Tools only need mining materials; weapons need mining material *and* a monster drop, so weapon progression requires both mining and fighting. This is deliberately uneven pacing, not an oversight: weapon tiers are meant to be harder-won than tool tiers, gated on defeating a monster at roughly the target difficulty rather than just gathering material, even if that means facing a "medium-hard" Tunnel Wraith with a tier-1 Basic Blade for Mid Blade. Confirm this reads as intended, not punishing, once Phase 4/5 are playtestable.

Ancient Stone gates a true end-game tier: Runic Pick and Runic Blade, tool/weapon tier 4. There's no block that needs a tier-4 tool to mine (Ancient Stone itself is still resistance 3, so an Advanced Pick can already reach it), so the tier-4 upgrade is pure payoff, faster mining and more damage, for players who push far enough to find Ancient Stone at all, not a new gate on top of an already-brutal distance requirement. Runic Blade reuses Warden Core (Cave Warden's drop) rather than introducing a 7th monster, a steeper cost on the existing hardest fight instead of a new one. Neither counts against the 8 general item-type slots below: crafting one auto-equips it immediately into the tool/weapon equip slot, the same "outside the 8 types" treatment the Book already gets, since a player who's earned one is always going to want it equipped anyway.

## Player

- Moves in 8 directions (4 cardinal + 4 diagonal) at a single fixed speed; no separate walk/run modes. Pico-8 only gives this game 2 action buttons (O and X) once mine/attack/interact/parry/inventory are mapped (see Controls below), so there's no button left for a run modifier, and a fixed speed is simpler than a chord for it. Facing persists as whichever of the 8 directions the player last moved in, including while standing still; it determines which adjacent tile mining targets and which direction a melee swing covers.
- Combat: swing the equipped weapon to attack, parry to defend (a timed deflect, not a passive block). No shield item.
- Visibility is limited to a radius around the player; a Glowstone block or an equipped Lantern extends it.
- Resources:
  - HP (starting value and damage amounts are first-pass, see DESIGN.md, subject to playtesting).
  - Coins, accumulate up to 255 (tracked separately from the 8 inventory item types).
- Equipment: 2 dedicated equip slots (1 tool, 1 weapon), separate from the 8 general inventory item-type slots. Only the currently equipped tool determines what can be mined; only the equipped weapon determines melee damage. Crafting Runic Pick or Runic Blade (tool/weapon tier 4, see Items) auto-equips it into the matching slot immediately rather than requiring a manual equip step, since both are one-off end-game items rather than one of several stacked general-inventory options.

## Items

8 general item types (materials/consumables, each stacking up to 99 per slot, a ceiling high enough to never realistically bind during a run, just enough to keep the counter display sane):

| Item | Role |
| ---- | ---- |
| Basic / Mid / Advanced Pick | Tool tiers 1-3; equip to mine correspondingly harder blocks |
| Basic / Mid / Advanced Blade | Weapon tiers 1-3; equip to deal correspondingly more combat damage |
| Lantern | Light source; equip or hold to extend the visibility radius |
| Health Potion | Consumable; restores HP |

Four more things track separately from the 8 types, similar to how the original sketch already separated coins from general items:

- **Coins**: a plain counter, up to 255, no inventory slot.
- **Book**: a special, non-stacking, persistent item found in a chest. Doesn't count against the 8 item types. Opens the Help overlay from the Inventory screen, any time, as many times as wanted, once found.
- **Runic Pick** and **Runic Blade**: tool/weapon tier 4, crafted from Ancient Stone (see Blocks, mining & crafting above). Don't count against the 8 item types either; crafting one auto-equips it straight into the tool/weapon equip slot instead of landing in general inventory.

## Monsters

| Monster | Difficulty | Attack | Drop |
| ------- | ---------- | ------ | ---- |
| Cave Bat | Easy | Melee, fast/erratic movement | Bat Wing |
| Rock Crawler | Easy-medium | Melee, slow but tanky | Crawler Shell |
| Spitting Slug | Medium | Ranged (short-range spit), slow-moving | Slug Gland |
| Tunnel Wraith | Medium-hard | Melee, fast pursuit | Wraith Essence |
| Bone Archer | Hard | Ranged (long-range, kites away) | Old Bone |
| Cave Warden | Hardest | Melee + occasional ranged, mini-boss | Warden Core |

Each monster drops its own material on death, not generic block material, so combat has its own crafting inputs distinct from mining. Monster difficulty (which types spawn) scales with distance from spawn, same as block tiers.

## Chests & help

- Chests are a world object (not a block, not mined), placed at a modest rate through the cave, more common than a Treasure Vein but not on every screen.
- Opening one is instant: walk up, press interact, loot reveals immediately. No timed search.
- Loot table is weighted mostly toward materials, occasionally a Health Potion, rarely a Book.
- Only one Book is meaningful; a chest that would roll a second one rolls something else instead.
- The Help overlay (opened by using the Book from Inventory) shows controls plus a compact reference: which tool tier breaks which block tier, and which monster drop feeds which recipe. It's meant as a genuinely useful cheat sheet, not just onboarding text.

## Game over conditions

- Player HP reaches 0. There's no win condition; this is a survive-as-long-as-you-can run, scored by a weighted sum of distance reached and coins/materials collected (see DESIGN.md's Scoring note).

## Progression

- No time-based ramp. Difficulty is spatial: block tier and monster difficulty both scale with distance from the player's spawn point, so exploring farther is the actual difficulty curve, not survival time.

## Sound

| Event | Description |
| ----- | ------------ |
| Mining tick | Short percussive knock, repeats each tick while the mine input is held |
| Block break | A bigger crunch/crumble, one-shot layered on top of the last tick |
| Block resists (tool too weak) | Dull, unpitched thud, distinct from a mining tick so "this tool can't scratch it" reads immediately, no visual needed |
| Sword swing | Quick whoosh |
| Parry success | Bright metallic ring |
| Player hit taken | Descending buzz |
| Monster hit taken | Short percussive impact, lower-pitched than parry's ring so the two don't read as the same event |
| Melee monster attack | Low growl/thump on windup |
| Ranged monster attack (spit/arrow launch) | Sharp hiss/twang, clearly distinct from melee's thump |
| Coin pickup | Bright ascending chime |
| Material pickup | Soft, short tick |
| Chest open | Creak plus a short rising flourish |
| Book find | Celebratory major-chord arpeggio, deliberately echoing game 2's terminal-found sting since both mark "found the reference screen" |
| Crafting success | Ascending 3-note run |
| Health Potion use | Warm rising tone |
| Player death | Descending 3-note run, mirroring game 3's loss stinger |

Character only, not exact notes or SFX slot numbers; that level of detail gets tuned by ear once there's a real cart to hear it in, per SPEC-FORMAT.md's Sound section guidance.

## Tile / sprite visuals

Blocks share a family base colour and, where the material actually matters, get a semantic accent colour and a distinguishing pattern rather than a unique hue each; see [DESIGN.md](DESIGN.md)'s Palette table for the full colour-reuse rationale. Player and monster sprites are fully hand-detailed rather than flat silhouettes, unlike games 1-5.

| Tile / sprite | Colour | Visual |
| -------------- | ------ | ------ |
| Loose Dirt | Brown | Solid fill, minimal texture — the softest, plainest block |
| Clay | Brown | Solid fill with a faint horizontal streak texture |
| Rubble | Brown | Speckled, scattered-pebble texture |
| Packed Stone | Dark grey | Solid fill, coarse cross-hatch texture |
| Mossy Rock | Dark grey | Solid fill with speckled green moss patches |
| Flint | Dark grey | Solid fill, sharp angular crack lines |
| Dense Rock | Dark grey | Solid fill, dense fine speckle — the heaviest texture of the stone family |
| Copper Ore | Dark grey base, orange accent | Stone base with orange ore nuggets embedded |
| Iron Ore | Dark grey base, brown fleck | Stone base with small rust-toned flecks |
| Gold Ore | Dark grey base, yellow accent | Stone base with yellow ore nuggets embedded |
| Crystal Ore | Dark grey base, blue accent | Stone base with faceted blue gem shapes |
| Ancient Stone | Dark purple | Solid fill, subtle etched rune-like pattern |
| Lava | Red | Solid fill with a bright wavy highlight |
| Deep Water | Blue | Solid fill, horizontal wave-line texture |
| Treasure Vein | Dark grey base, yellow accent | Stone base with a sparkle-cluster pattern, distinct from Gold Ore's solid nugget |
| Glowstone | Dark grey base, blue accent | Stone base with a radiating-dot pattern around a bright core, distinct from Crystal Ore's faceted gem |
| Player | White | Fully detailed humanoid, directional facing |
| Cave Bat | Dark grey | Small winged silhouette, erratic flutter animation |
| Rock Crawler | Brown | Squat, rock-textured body, stubby legs |
| Spitting Slug | Green | Elongated slug body, visible spit animation |
| Tunnel Wraith | Lavender | Ghostly, semi-transparent-reading wisp form |
| Bone Archer | Light grey | Skeletal humanoid holding a bow |
| Cave Warden | Pink | Large, boss-scale silhouette, visually distinct from every other monster |
| Chest | Brown, yellow latch highlight | Simple chest silhouette |
| HUD text | White | Bottom strip, over the HP/coins/equipment icons |
| Fog boundary | Dithers to black | Soft-edged transition at the lit-radius boundary, not a hard cutoff |

## Open Questions

- **Tuning numbers**: DESIGN.md proposes first-pass values for block resistance/HP, tool power, weapon damage, and player/monster HP. Treat these as a starting point for playtesting, not locked.
- **Fog dither cost**: the soft-edged dither at the visibility boundary costs more per-frame draw work than a hard cutoff; confirm it fits Phase 9's token/performance budget once measured, simplify to a hard cutoff if it doesn't.
- **Visibility/fog radius isn't built yet**: found while implementing Phase 7 (screens & flow) that no phase from 0 through 7 actually built the lit-radius/fog mechanic this section and DESIGN.md's Visibility section both describe as core — only the dither-cost question above got tracked, not the base mechanic it's a cost question *about*. Now on Phase 8's checklist (`PLAN.md`).
