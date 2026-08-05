# How to play: 6 Dug, Dug, Down.

A top-down cave-mining RPG. Dig, fight, craft, and see how far you can get before you die.

## Controls

Each action button belongs to one equipped item: O to your tool, X to your weapon.

| Input | Effect |
| ----- | ------ |
| Arrow keys | Move (8 directions) and set facing |
| O, held, facing a block | Mine it |
| O, tapped, facing a chest | Open it |
| X, tapped | Attack (weapon swing) |
| X, held | Guard — blocks damage for as long as you hold it |
| O + X, held together | Open/close Inventory |

On a keyboard rather than a gamepad, "O" and "X" are Pico-8's button names, not literal keys: **Z (or C) is O**, **X (or V) is X**. The letter "O" key isn't bound to anything.

Holding O+X takes about a third of a second to register (it's a deliberate hold, not a tap, so it doesn't false-trigger while mining and attacking at the same time). Let go of at least one button once Inventory opens — if you keep both held down, it'll count the hold again and close right back on you.

There's no run button — movement is a single fixed speed.

## The basics

You start with a Basic Pick and a Basic Blade equipped, dropped into a large cave that's generated fresh every run. There's no win condition: you explore, mine, fight, and craft for as long as you can, and the run ends when your HP hits 0.

**Mining**: face a block and hold O. Every block has a resistance tier — if your equipped tool is too weak, you'll hear a dull thud and make no progress at all; upgrade your tool to get through it. Blocks near your spawn point are easy (tier 1); the farther you wander, the tougher the blocks and the monsters get. That distance is the actual difficulty curve — there's no timer pushing you.

**Visibility**: you can only see a small radius around yourself; everything beyond it is dark. A Glowstone block or an equipped Lantern extends how far you can see.

**Combat**: tap X to swing your weapon at whatever's directly in front of you. Hold X to guard — it fully blocks incoming damage for as long as you keep holding it, so lean on it when something's about to hit you. There are 6 monster types, from easy (Cave Bat) to a genuine mini-boss (Cave Warden); each drops its own material on a kill, separate from what you get from mining.

**Hazards**: Lava damages you on contact for as long as you stand in it. Deep Water doesn't hurt you, just slows you down.

**Chests**: walk up to one and tap O to open it instantly — no searching required. Mostly you'll get materials, sometimes a Health Potion, and rarely the Book. The Book is a one-time find that unlocks a permanent Help screen in-game (controls plus a tool/block-tier and recipe cheat sheet) — reopen it from the Inventory any time.

**The HUD** (bottom strip): top row is HP, coins, and the O+X hint. Bottom row is your equipped tool and weapon, followed by the last few materials you've picked up — a quick way to confirm a mine or kill actually gave you something, without opening Inventory to check.

## Crafting

Open Inventory (O+X held) to craft. It's one list, one cursor: your 8 general items first, then the 10 recipes below them. Move the cursor with up/down, press O on a recipe to craft it if you can afford it.

Every ingredient — a raw material or a lower-tier item you already own — draws from the same pool, so "3 Iron Ore" and "1 Basic Pick" work exactly the same way as recipe inputs.

| Item | Recipe |
| ---- | ------ |
| Basic Pick | 3× Copper Ore |
| Mid Pick | 3× Iron Ore + 1 Basic Pick |
| Advanced Pick | 3× Gold Ore + 1 Mid Pick |
| Basic Blade | 2× Copper Ore + 1 Bat Wing |
| Mid Blade | 2× Iron Ore + 1 Wraith Essence |
| Advanced Blade | 2× Gold Ore + 1 Crystal Ore + 1 Warden Core |
| Runic Pick | 3× Ancient Stone + 1 Advanced Pick |
| Runic Blade | 2× Ancient Stone + 1 Warden Core + 1 Advanced Blade |
| Lantern | 2× Glowstone |
| Health Potion | 2× Mossy Rock |

Notice tools only ever need mining materials, but every weapon needs a monster drop too — so upgrading your blade always means you've had to fight something, not just dig. Runic Pick and Runic Blade are the end-game tier: craft one and it auto-equips immediately, no manual equip step needed.

## Scoring & death

There's no health bar management trick beyond guarding well and carrying a potion. When HP reaches 0, the run ends and your score is built from how far you got from spawn plus your coins and materials collected. Then it's back to the title screen to try again on a freshly generated cave.
