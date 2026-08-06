# Platforms

A reference for what each platform in this project implies: resolution, colour, budget, sound, project shape. A game's CLAUDE.md should link here for its target platform's constraints rather than restating them; that file keeps only what's specific to the one game (an actual measured token count, a platform choice, a deviation).

Pico-8, Picotron, Pygame, and TIC-80 are all valid jam platforms, author's choice per entry (see root [README.md](README.md)'s Rules). Every game jammed so far happens to target Pico-8; that's a choice each entry made, not a constraint this file imposes.

## Comparison

| | Pico-8 | Picotron | Pygame | TIC-80 |
| --- | --- | --- | --- | --- |
| Resolution | 128×128 | ~480×270 | Author's choice | ~240×136 |
| Colour | 16-colour fixed hardware palette | Wider default palette; truecolor drawing available | Arbitrary RGBA | 16-colour palette, remappable |
| Code budget | ~8,192 tokens, hard cap | No token cap; still a 60fps perf budget | No cap | Cart-size limit (varies by language), not a token count |
| Sprites | 8×8, 256 slots on one shared sheet | Larger, more flexible sheets | Arbitrary PNG assets | 8×8, 256 slots across banks |
| Map | 128×64 cells, shares memory with the sprite sheet | Own map format, not memory-shared | Roll your own, or use Tiled | Own map format, bank-based |
| Sound | 64 SFX slots, 4 channels, `__sfx__` hex format | Own tracker-style format, distinct from Pico-8's | `pygame.mixer`: wav/ogg/mp3 | 4 channels, own SFX/music editor |
| Language | Pico-8 Lua (stdlib gaps — no `string.format`, etc.) | Lua 5.4 | Python 3 | Lua, JS, Wren, Python, and others |
| Project shape | Single `.p8` cart file | Multi-file project in its own virtual filesystem | Plain `.py` + asset files | Single `.tic` cart file |
| Web export | Native; what `preview/generate.py` currently relies on | Native, different embed mechanism than Pico-8's | None built-in (would need something like pygbag) | Native |

The TIC-80 row is verified against a real local build (see [`tools/tic80.md`](tools/tic80.md)); the Picotron row is still from general familiarity with the tool, not verified against a real build in this project. Confirm Picotron specifics against the current manual before locking a DESIGN.md's Screen layout or Budget section to any of its numbers.

## Per-platform notes

### Pico-8

The jam's default and the only platform actually shipped in this project so far. Constraints are documented in full in root [CLAUDE.md](CLAUDE.md)'s Pico-8 constraints section and echoed in every Pico-8 game's own CLAUDE.md; don't duplicate that text a third time here.

### Picotron

No token budget in the Pico-8 sense; the practical ceiling is frame time, not code size, so a Budget section for a Picotron game should talk in terms of draw calls, entity counts, or measured frame time instead of a token number. Its multi-file project shape means `lib/`'s copy-paste-into-`__lua__` convention doesn't apply as-is; a Picotron port would want its own equivalent of `lib/`, or a real `require`-style split, once one exists.

### Pygame

No budget ceiling at all, and no proprietary asset format: sprites are plain PNGs and audio is plain wav/ogg. This makes it the cheapest platform to upscale into from what's already here, since `tools/sprites/sprite_tool.py` already renders sprite defs to PNG for preview purposes; that output is close to being Pygame-ready as-is, where it needs a full new encoder for Pico-8's `__gfx__` hex format. The trade-off is no built-in web embed, so `preview/generate.py` would need a fallback (screenshot, or a packaged wasm build via something like pygbag) rather than the live-cart iframe it uses for Pico-8 entries today.

### TIC-80

Closest in spirit to Pico-8 (same fantasy-console category, similar resolution class, still a hard cart-size ceiling), so it's a smaller conceptual jump than Picotron or Pygame if the goal is "same constraints, slightly more room" rather than "no constraints." Its budget is cart-size in bytes, not a token count, and that limit varies by which supported language the cart uses. Full constraints, RAM/VRAM layout, cart format, and CLI workflow are documented in [`tools/tic80.md`](tools/tic80.md) rather than repeated here; game 4's `tic-80/` build ([`4/tic-80/CLAUDE.md`](4/tic-80/CLAUDE.md)) is the first to use it.

## Related

- [`SPEC-FORMAT.md`](SPEC-FORMAT.md#platforms-and-folder-layout) — how a game folder is organized once it has more than one platform's build
- [`CLAUDE.md`](CLAUDE.md) — Pico-8 constraints as they apply project-wide, since every game built so far targets Pico-8
- [`tools/tic80.md`](tools/tic80.md) — TIC-80 constraints, RAM/VRAM layout, cart format, and CLI workflow, verified against the local build
