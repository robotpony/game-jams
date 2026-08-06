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

## Web export

```sh
tic80 --fs=<dir> --cli --cmd "load <name>.tic & export html <name>_export & exit"
```

This produces a **zip** (`<name>_export.zip`), not a single self-contained HTML file the way Pico-8's `-export` does. Inside: `index.html`, `tic80.js` (~228KB), `tic80.wasm` (~5.3MB — the whole TIC-80 runtime, identical across every cart), and `cart.tic` (the actual game, tiny by comparison). Unzip before deploying; the file count and the runtime's fixed size are why `preview/generate.py` extracts the runtime once and shares it across every TIC-80 game's export rather than duplicating ~5.3MB per game (see [`preview/CLAUDE.md`](../preview/CLAUDE.md)).

## Tooling gap

`tools/` has working Pico-8 asset scripts (`sprites/sprite_tool.py`, `sfx/sfx_tool.py`) but nothing TIC-80-specific yet — different sprite-sheet layout (two 256-slot banks vs. one shared 256-slot sheet), different palette handling (remappable vs. fixed), different sound-data format. Building against this file's RAM layout is the starting point whenever that work begins; see [`tools/TASKS.md`](TASKS.md) for the backlog.

## Related

- [`../PLATFORMS.md`](../PLATFORMS.md) — comparison table across all four jam platforms
- [`../SPEC-FORMAT.md`](../SPEC-FORMAT.md#platforms-and-folder-layout) — how a game folder is organized once it has more than one platform's build
- [`../4/tic-80/CLAUDE.md`](../4/tic-80/CLAUDE.md) — first game built against this reference
