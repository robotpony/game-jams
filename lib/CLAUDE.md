# CLAUDE.md — lib

Shared Lua code for Pico-8 games. These are reusable functions and abstractions that get copy-pasted (or included via a build step) into `.p8` cartridge files.

Each game's own Core system design (in its DESIGN.md, per [`../SPEC-FORMAT.md`](../SPEC-FORMAT.md)) should check here before describing new gameplay utility code from scratch.

## Purpose

Common patterns show up across every Pico-8 game: tweening, screen flash, state machines, input handling, collision, HUD drawing. This project captures them as well-tested, token-efficient Lua snippets so each game doesn't reinvent them under budget pressure.

## Constraints

Everything here runs under Pico-8's Lua variant. That means:

- **Token budget is shared with the game** — every function added to a cart costs tokens; keep implementations tight
- No standard library reliance beyond what Pico-8 provides (`rnd`, `flr`, `abs`, `min`, `max`, `mid`, `btn`, `btnp`, `spr`, `sspr`, `map`, `mget`, `mset`, `print`, `pset`, `pget`, `line`, `rect`, `rectfill`, `circ`, `circfill`, `cls`, `camera`, `pal`, `palt`, `srand`, `stat`, `peek`, `poke`)
- No `string.format`; use `tostr()`, `tonum()`, `sub()`, `#str`
- Tables are the only data structure; no sets, maps, or queues beyond table wrappers
- Integer arithmetic is faster than float; prefer `flr()` over `/`

## Folder layout

```
lib/
  input.lua       button helpers, input buffering, held-button detection
  screen.lua      flash, fade, palette cycling, screen shake, blink() prompt timer
  state.lua       simple finite state machine (init/update/draw dispatch)
  title.lua       shared jam title card (colour swatches, jam name, per-game name, blink prompt)
  tween.lua       linear and eased interpolation
  collision.lua   AABB helpers for pixel and tile collision
  hud.lua         score display, timer bar, message flash
  map.lua         map query helpers (tile flags, neighbour checks)
  math.lua        lerp, clamp, sign, dist, angle helpers
  rng.lua         seeded RNG wrappers, weighted choice
```

`screen.lua` and `title.lua` are built and in use (games 1, 3, and 5, see [`PLAN.md`](PLAN.md)). The rest of this list is still a backlog; the files don't exist yet.

## File format

Each file is a self-contained Lua snippet with no external dependencies. Files begin with a comment block:

```lua
-- lib/<name>.lua
-- <one-line description>
-- tokens: ~<estimated count>
-- depends: <none | other lib files>
```

Token estimates are rough; recount after significant changes using Pico-8's token counter.

## Usage

Copy the relevant snippet(s) into the `__lua__` section of a `.p8` file before the game code. Functions are global by convention (Pico-8 has no module system).

For games with tight token budgets, inline only what you need — don't paste the whole lib.

## Style rules

- Function names: `snake_case`, short, action-first (`flash_screen`, `is_held`, `lerp`)
- No closures or metatables unless the token saving is significant and documented
- Prefer early-return guard clauses over nested conditionals
- One function per logical operation; no Swiss Army functions
- Each function must have a usage comment showing a realistic call site

## Example: screen flash (planned, not yet in `screen.lua`)

Games 1 and 3 still inline `flash_t`/`flash_c` by hand rather than calling shared functions; extracting them into `screen.lua` is a pending [`PLAN.md`](PLAN.md) item. The target shape:

```lua
-- screen.lua
-- screen flash and shake utilities
-- tokens: ~45
-- depends: none

flash_t = 0
flash_c = 0

function flash_screen(col, frames)
  flash_c = col
  flash_t = frames or 6
end

function update_flash()
  if flash_t > 0 then flash_t -= 1 end
end

-- call at top of _draw() before any other drawing
-- returns true if flash is active (skip normal draw)
function draw_flash()
  if flash_t > 0 then
    cls(flash_c)
    return true
  end
  return false
end
```

## Example: blink prompt (built, in `screen.lua`)

```lua
-- lib/screen.lua
-- blinking prompt-text helper
-- tokens: ~15
-- depends: none

-- call: if blink(2) then print("press x to start",...) end
-- hz=2 gives a 0.5s on/off cycle at any framerate; stateless, no update() call needed
function blink(hz)
  return (time()*hz)%2<1
end
```

## Token budgeting

Pico-8 counts tokens, not bytes. Rough costs:

| Construct | Tokens |
|-----------|--------|
| `function f() end` | 4 |
| each identifier | 1 |
| each literal | 1 |
| each operator | 1 |
| `if/then/end` | 3 |
| `for/do/end` | 3 |

When a lib file risks pushing a cart over budget, document the cheaper inline alternative in a comment.
