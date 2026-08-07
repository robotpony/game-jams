# TIC-80

Reference for TIC-80's constraints, cart format, and CLI workflow, verified against the actual local build rather than general familiarity. Link here from a TIC-80 game's `CLAUDE.md` instead of restating this, the same way a Pico-8 game's `CLAUDE.md` links to root [`CLAUDE.md`](../CLAUDE.md)'s Pico-8 section instead of repeating it.

`tic80` is aliased to a local build at `~/tools/TIC-80/build/bin/tic80`, version 1.2.3083-dev, confirmed in-repo via `tic80 --version`. Everything below was pulled from that binary's own `help` output (`help spec`, `help ram`, `help vram`), not from TIC-80's website docs, so it reflects what this build actually enforces.

## Spec

| | TIC-80 |
| --- | --- |
| Display | 240×136 pixels, 16-colour palette (remappable, unlike Pico-8's fixed hardware palette) |
| Input | 4 gamepads, 8 buttons each; mouse; keyboard |
| Sprites | 256 8×8 tiles + 256 8×8 sprites — two separate banks, 512 slots total, vs. Pico-8's one 256-slot shared sheet |
| Map | 240×136 cells, 1920×1088 px |
| Sound | 4 channels, configurable waveforms |
| Code | 64KB cart size cap, not a token count; language choice affects how much of that a given feature costs |
| Languages | Lua, Ruby, JS, Moonscript, Fennel, Squirrel, Wren, WASM, Janet, Scheme, Python, Yue — this project uses Lua (see [Language choice](#language-choice)) |
| Project shape | Single `.tic` cart file, binary format (not plain text like Pico-8's `.p8` — see [Cart format](#cart-format)) |
| Web export | Native, but bundles a shared JS/WASM runtime per export rather than one self-contained HTML file (see [Web export](#web-export)) |

## RAM layout (96KB total)

| Addr | Info | Bytes |
| --- | --- | --- |
| 00000 | VRAM | 16384 |
| 04000 | Tiles | 8192 |
| 06000 | Sprites | 8192 |
| 08000 | Map | 32640 |
| 0FF80 | Gamepads | 4 |
| 0FF84 | Mouse | 4 |
| 0FF88 | Keyboard | 4 |
| 0FF8C | SFX state | 16 |
| 0FF9C | Sound registers | 72 |
| 0FFE4 | Waveforms | 256 |
| 100E4 | SFX | 4224 |
| 11164 | Music patterns | 11520 |
| 13E64 | Music tracks | 408 |
| 13FFC | Music state | 4 |
| 14000 | Stereo volume | 4 |
| 14004 | Persistent memory | 1024 |
| 14404 | Sprite flags | 512 |
| 14604 | Font | 1016 |
| 149FC | Font params | 8 |
| 14A04 | Alt font | 1016 |
| 14DFC | Alt font params | 8 |
| 14E04 | Buttons mapping | 32 |
| 14E24 | PCM samples | 128 |
| 14EA4 | Reserved | 12636 |

## VRAM layout (16KB)

| Addr | Info | Bytes |
| --- | --- | --- |
| 00000 | Screen | 16320 |
| 03FC0 | Palette | 48 |
| 03FF0 | Palette map | 8 |
| 03FF8 | Border colour | 1 |
| 03FF9 | Screen offset | 2 |
| 03FFB | Mouse cursor | 1 |
| 03FFC | Blit segment | 1 |

Useful when hand-authoring sprite/map/sfx data later, the way `tools/CLAUDE.md`'s `__gfx__` reference is for Pico-8 — nothing in `tools/` generates TIC-80 asset data yet (see [Tooling gap](#tooling-gap)).

## Language choice

This project uses **Lua** for every TIC-80 build. It's the closest match to Pico-8 Lua (the language every other game in this jam already uses), so game logic and structure carry over with the least translation, and `lib/`'s existing snippets (state machine, tweening, collision, HUD, input, seeded RNG) are a straightforward adaptation rather than a rewrite into a different language.

## Lua dialect & API notes

Verified against this build's own source (`~/tools/TIC-80/src/api/luaapi.c`'s `luaapi_open()` and `~/tools/TIC-80/src/api.h`'s function table), not the website docs or general familiarity — the same standard this file holds itself to elsewhere.

**Standard library**: `luaapi_open()` loads `base`, `package`, `coroutine`, `table`, `string`, `math`, and `debug`. No `os` or `io` (sandboxed, no filesystem access from Lua directly). This means `string.format` **is available**, unlike Pico-8 Lua, along with the full `table`/`math`/`coroutine` libraries — a materially richer stdlib than Pico-8's, so several of `pico8.md`'s [Lua dialect notes](pico8.md#lua-dialect-notes) workarounds (`tostr()` in place of `string.format`, hand-rolled table helpers) don't apply when porting code over.

**API shape differs from Pico-8's in ways that will silently misport code**, not just rename it:

| Pico-8 | TIC-80 | What changes |
| ------ | ------ | ------------- |
| `circ()` outline, `circfill()` filled | `circ()` **filled**, `circb()` outline | Names are inverted, not just renamed — the easiest of these three to port wrong without noticing. |
| `spr()` + `sspr()`; `flip_x`/`flip_y` booleans | One `spr(id,x,y,colorkey,scale,flip,rotate,w,h)`; `flip` is a 0-3 bitmask (0 none, 1 horizontal, 2 vertical, 3 both); `rotate` is a native parameter | Fewer functions, different call shape. TIC-80 can rotate sprites natively in a way Pico-8 flatly can't (which is why Gyri's pico-8 build hand-authored rotation sprites in the first place) — but only in 90° steps as far as this is verified, and Gyri's fire-line angles (~35°/69°) don't land on those steps, so hand-authored sprites are probably still needed for the fine angles even here. |
| `pal(c0,c1)` two-argument runtime swap | No equivalent function. `tic_vram`'s `mapping` field (the VRAM "palette map," 8 bytes, one nibble per colour index — see [RAM layout](#ram-layout-96kb-total)) is what a `pal()` swap would poke on Pico-8; on TIC-80 it has to be written directly via `poke4()` at that VRAM offset: **`poke4(32736 + c0, c1)`** remaps colour index `c0` to display as `c1`, confirmed against this build's own source rather than a live screenshot (see below). | Gyri's wave-recolor mechanic (`pal(8,ecol)`/`pal(7,ecol)`, reset every frame) has no drop-in translation; it needs new code built around this poke, not a line-for-line port — `poke4(32736+8, ecol) poke4(32736+7, ecol)` each frame is the equivalent. |

**`poke4`/`pal()`-equivalent derivation**, cross-checked against `~/tools/TIC-80/src/tic.h`'s `tic_vram` union and `core.c`'s `tic_api_poke4`, not just this file's own RAM-layout table:

- `tic_vram.mapping` sits at byte offset `sizeof(tic_screen) + sizeof(tic_palette)` = `16320 + 48` = `16368` (`0x3FF0`) within the struct, matching the [VRAM layout](#vram-layout-16kb) table's Palette map row exactly — confirmed by reading the struct field order directly, not assumed from the table.
- `draw.c`'s `getPalette()` reads that array per-pixel at draw time (`mapping[i] = tic_tool_peek4(vram.mapping, i)`, then `mapping[raw_pixel_value]` picks the displayed colour) — this **is** the live pal()-equivalent path, not a display-adjacent setting that happens to share the name.
- `poke4(address, value)` is nibble-addressed over the whole RAM (`tic_api_poke4` → `tic_tool_poke4(ram, address, value)`, `ram` = the full `tic_ram`, VRAM at its byte offset 0), so nibble address = `byte_offset * 2` = `16368 * 2` = `32736`. `poke4(32736 + c0, c1)` therefore writes nibble `c0` of the mapping array to `c1`, exactly mirroring Pico-8's `pal(c0, c1)`.
- **Not yet confirmed with a live screenshot.** TIC-80's `run` console command blocks the CLI's own event loop and never returns control to a chained `--cmd` (`run & eval ... & export screen ...` sends `eval`/`export` only after `run` exits, which doesn't happen without manual quit) — tried directly in this session, confirmed by observation, not assumption. A real visual check needs an interactive GUI session: launch `tic80 <cart>.tic`, drop to the console with ESC, then `eval poke4(32736,8) trace(peek4(32736))` and eyeball a rect drawn in colour 0 turning red. Do that once before shipping the wave-recolor code, even though the source-level derivation above is solid on its own.

Full function reference (names, signatures, descriptions) is in this build's own `~/tools/TIC-80/src/api.h`, but that's a local machine path, not something a fresh clone of this repo can follow. For a reference anyone can open, use the official API wiki: https://github.com/nesbox/TIC-80/wiki/API.

## Cart format

A `.tic` cart is a **binary** file, not a plain-text format like Pico-8's `.p8` (which stores every section, including `__lua__`, as readable text with hex-encoded sprite/map/sound data). Editing a `.tic` file directly with a text tool isn't viable, and it doesn't diff cleanly in git.

The workaround this project uses: author game code as a plain external `.lua` file (git-committed, diffable, edited with normal tools), and use TIC-80's console `import code` command to bring it into a working `.tic` cart for local testing and export. The `.lua` file is the source of truth; the `.tic` cart is a build artifact, regenerated from it — the same relationship `tools/export/strip_comments.py` has to a Pico-8 cart's export copy, just one step earlier in the pipeline.

Sprites, map, and sound data still have to be authored or edited inside TIC-80 itself (or scripted against the RAM layout above) and live only in the `.tic` cart; there's no external-file equivalent for those sections yet.

## CLI workflow

No GUI needed for the code-only loop. All commands below assume `--fs=<folder>` points at the directory holding the game's `.lua` source and `.tic` cart (TIC-80 sandboxes file access to that folder).

Bring external code into a cart:

```sh
tic80 --fs=<dir> --cli --cmd "load <name>.tic & import code <name>.lua & save <name>.tic & exit"
```

On a brand-new cart (no `.tic` yet):

```sh
tic80 --fs=<dir> --cli --cmd "new lua & import code <name>.lua & save <name>.tic & exit"
```

Play/test interactively (opens the GUI, not headless):

```sh
tic80 --fs=<dir> <name>.tic
```

Or from the console: `load <name>.tic` then `run`.

There's no headless `-run`-and-exit equivalent to Pico-8's; verification is manual play-testing, same as every other platform in this repo (see root [CLAUDE.md](../CLAUDE.md)'s Commands section).

## Known pitfalls

Confirmed directly against this build (1.2.3083-dev) while writing `tools/tic80/sprite_tool.py` — see [`TASKS.md`](TASKS.md)'s task 5 for the debugging trail. Thin so far since this is the first real TIC-80 CLI-scripting work in the project; add to this list rather than rediscovering the same thing next time, mirroring [`pico8.md`](pico8.md#known-pitfalls)'s.

- **Any confirm dialog in a `--cmd` chain hangs forever, with no way to answer it non-interactively.** `load` (unsaved changes), `new` (unsaved changes), `save` (target already exists), and `del` all have a confirm path (`confirmCommand` in `console.c`), and none of them can be satisfied by anything short of a real keypress in a real GUI session. The practical rule: never let a scripted command chain hit one. For `save`, that means the target filename must not already exist — not even as an empty placeholder file `tempfile.NamedTemporaryFile` itself creates just to reserve a unique name, which trips the exact same "already exists" check as a real file. Generate temp names without touching disk first (e.g. `uuid.uuid4()`), then rename over the final path once TIC-80's own process has exited.
- **`run` never returns control to a `--cmd` chain.** It starts the game loop and blocks there indefinitely waiting for the GUI; any commands chained after it (`& eval ...`, `& export screen ...`) never execute. There's no headless run-a-few-frames-then-continue equivalent — confirmed by testing directly, not assumed from the docs. `eval`, `import`, `export`, `load`, and `save` all return immediately and are safe to chain; `run` is the one exception, and a screenshot-based visual check needs an actual interactive GUI session, not a scripted one.
- **Don't trust a single-trial fix for a hang.** A command that hung once and then succeeded after one unrelated change looks fixed but might not be — the actual cause here was a `save`-target collision, not the stdin-inheritance theory that a single retest first seemed to confirm. Isolate the variable properly (does it stay fixed with the fix removed? does the original bug still reproduce with the fix in place but the real cause reintroduced?) before writing a hang's cause down as confirmed.
- **TIC-80's own PNG export marks palette-index-0 pixels as `alpha=0`**, a sheet-preview convention (colour type 6, RGBA), not a rendering bug — a def file with a black/index-0 background can look almost entirely blank against a light viewer background as a result. Diff raw pixel bytes against a known-good export before concluding a patch didn't land; a visual skim at thumbnail size isn't enough to tell "transparent" from "unchanged."

## Web export

```sh
tic80 --fs=<dir> --cli --cmd "load <name>.tic & export html <name>_export & exit"
```

This produces a **zip** (`<name>_export.zip`), not a single self-contained HTML file the way Pico-8's `-export` does. Inside: `index.html`, `tic80.js` (~228KB), `tic80.wasm` (~5.3MB — the whole TIC-80 runtime, identical across every cart), and `cart.tic` (the actual game, tiny by comparison). `preview/generate.py`'s `ensure_export_tic80()` unzips it as-is into each game's own export folder rather than sharing one runtime copy across games; that means every TIC-80 build's export carries its own ~5.5MB, a deliberate simplicity-over-disk-space choice (see [`preview/CLAUDE.md`](../preview/CLAUDE.md)'s Export handling section for the reasoning, and revisit only if that stops being cheap enough).

## Tooling gap

`tools/tic80/sprite_tool.py` now exists (sprite/tile authoring, both 256-slot banks, delegating actual cart writes to this binary's own `import`/`export` rather than the raw `.tic` binary format) — see [`TASKS.md`](TASKS.md)'s task 5. Still open: sound/music, a different data format again (this file's RAM layout's SFX/music-pattern/music-track byte ranges are the starting reference), and palette handling (remappable vs. Pico-8's fixed hardware palette, still undecided per [`../4/tic-80/PLAN.md`](../4/tic-80/PLAN.md)'s Phase 0b).

## Related

- [`../PLATFORMS.md`](../PLATFORMS.md) — comparison table across all four jam platforms
- [`../SPEC-FORMAT.md`](../SPEC-FORMAT.md#platforms-and-folder-layout) — how a game folder is organized once it has more than one platform's build
- [`../4/tic-80/CLAUDE.md`](../4/tic-80/CLAUDE.md) — first game built against this reference
- [`pico8.md`](pico8.md) — this file's Pico-8 equivalent; the two are worth reading side by side when porting a game between the platforms, since most of the traps are in where their APIs and dialects quietly diverge, not where they're obviously different
