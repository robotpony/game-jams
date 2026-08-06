# Making Pico-8 games with Claude

A working guide to how this repo builds Pico-8 carts with Claude Code: the document flow, the utilities that exist so far, the platform's hard limits, and the techniques that came out of building games 1 through 6. It's a field guide, not a spec; for the authoritative format rules see [`SPEC-FORMAT.md`](../SPEC-FORMAT.md), [`tools/CLAUDE.md`](CLAUDE.md), and [`lib/CLAUDE.md`](../lib/CLAUDE.md).

## Starting a new game

Run the `new-game` skill (or ask Claude to scaffold a new entry) to generate the base `README.md`, `DESIGN.md`, `PLAN.md`, and `CLAUDE.md` for a numbered folder, following [`SPEC-FORMAT.md`](../SPEC-FORMAT.md). Design happens in that document order: lock the player-facing spec first (README), then the pixel-level design (DESIGN), then break it into a phased checklist (PLAN), before any Lua gets written. Skipping straight to code produces games where the state machine and the spec disagree by phase 3.

Once `PLAN.md` exists, implementation is phase by phase: finish a phase's checklist items, launch the cart (`pico8 -run <n>/<n>.p8`, backgrounded), play it, then move on. Don't let "Verify" sit as an unchecked manual checkbox until the whole game is done, see [Playtesting](#playtesting-with-claude) below.

## Host-side tools

Scripts in `tools/` generate cart section data on the dev machine; nothing here runs inside Pico-8 itself. Full format details and the `--cart`/manifest flags are in [`tools/CLAUDE.md`](CLAUDE.md).

| Tool | Generates | Status |
| ---- | --------- | ------ |
| `sprites/sprite_tool.py` | `__gfx__` sprite data from plain-text hex-grid defs; `preview`/`sheet` render PNGs, `patch`/`patch-all` write into a cart | Working |
| `sfx/sfx_tool.py` | `__sfx__` slot data from human-readable note defs (`pitch wave vol fx` per line) | Working |
| `export/strip_comments.py` | A comment-stripped export copy of a cart, called automatically by `preview/generate.py` | Working |
| `maps/`, `music/`, `shared/` | `__map__` and `__music__` generation, shared palette/hex helpers | Not built yet, see [`TASKS.md`](TASKS.md) |

Both tools have a `selftest`/round-trip check against real authored data pulled from this repo's own carts, not just the Pico-8 manual's prose description of the format. Trust the selftest over hand-derived hex when the two disagree.

## Shared Lua (`lib/`)

Reusable gameplay code lives in `lib/`, copied into a cart's `__lua__` section by hand (Pico-8 has no `require` or module system). Check here before writing state machines, tweening, collision, HUD, input handling, or RNG from scratch; see [`lib/CLAUDE.md`](../lib/CLAUDE.md) for the current file-by-file status and token estimates. Inline only the functions a given cart actually calls, not the whole file, on a token-limited platform every unused function is a wasted token.

## Two different size limits

Pico-8 enforces a token limit and an export-size limit independently, and only the first one is visible while you're counting tokens as you write:

- **Token limit, 8,192.** Real code tokens only; comments are free. This is what every game's `CLAUDE.md`/`PLAN.md` status line tracks.
- **Export capacity, roughly 15.6 KB compressed.** When Pico-8 packs a `.p8.png` or runs `-export`, it compresses the raw `__lua__` text, comments included. A cart can sit comfortably under the token cap and still fail export with `code block too large` if comments make up a large share of the source.

Game 6 hit this at 4,357/8,192 tokens because 65% of its `__lua__` bytes were comments. `export/strip_comments.py` produces an export-only copy with comments removed, leaving the fully-commented dev cart untouched; run it by hand before a Pico-8 export to check headroom. Full writeup: [`tools/CLAUDE.md`](CLAUDE.md#export-capacity-vs-token-limit).

## Lua dialect notes

Pico-8's Lua omits parts of the standard library. The gaps that actually bite:

- No `string.format`. Use `tostr(n)`, `sub(s,i,j)`, `#s` for length, `add(t,v)` to append to a table.
- Tables are the only data structure; there's no set or queue type, wrap a table if you need one.
- Integer arithmetic is faster than float; prefer `flr()` over `/` in hot loops.
- Globals are the module system: `lib/` functions are pasted in as plain globals, snake_case, action-first (`flash_screen`, `is_held`).

## State machine convention

Every game so far uses a two-global convention rather than a dispatch-table FSM: `gs` (current state) and `gsret` (the state to return to). `goto_state(n)` switches `gs` and remembers the old value in `gsret`; `return_state()` switches back. This is deliberate, not a shortcut: a table-of-functions dispatcher costs more tokens per call than an `if/elseif` chain in `_update()`/`_draw()` for the state counts these games actually have. Reach for `goto_state`/`return_state` only when an overlay (a help screen, a pause menu) is reachable from more than one caller state; a single-caller overlay is cheaper as a plain boolean flag.

## Playtesting with Claude

Two levels of verification, use both, neither substitutes for the other:

**Logic verification** (does this rule actually work): a temporary in-cart `printh()` self-test, output redirected to a log file. Good for exact interactions, damage math, collision edge cases, anything easier to assert than to eyeball.

**Real play verification** (does this reach the player): launch the cart and drive it with actual input.

1. `pico8 -run <n>/<n>.p8`, backgrounded so it doesn't block.
2. Bring the window forward and click inside it (not just `activate`), Pico-8 silently stops receiving input if the window is frontmost-but-not-key; the traffic-light buttons render dim/grey when this happens, a fast visual tell.
3. Send input via macOS Accessibility (System Events): `key down`/`key up` pairs for a true hold, not a single discrete `keystroke`, Pico-8's per-frame `btn()` polling drops presses that are too short. Default keyboard mapping: arrow keys are dpad (key codes 123/124/125/126), Z/C are button O, X/V are button X.
4. Capture with `screencapture -x`, read the PNG back to judge the result.
5. Re-verify focus before every keystroke batch, not once per session, frontmost drifts if anything else on the machine is active concurrently.
6. Quit the test instance (`osascript -e 'tell application "pico8" to quit'`) when done.

Use live input for what it's actually good for: confirming controls reach the game, screens render, and interactions with static or positioned things work end to end. Don't burn turns manually pixel-aligning the player against a moving target through simulated input, use a `printh()` harness for that instead.

## Known pitfalls

Recurring, generalizable issues found across games 1 through 6. Per-game detail and fix history: [`BUGS.md`](../BUGS.md).

- **Cart section order matters on save.** Pico-8's canonical order is `__lua__`, `__gfx__`, `__label__`, `__map__`, `__sfx__`, `__music__`. A section appended out of order loads fine but can silently vanish the next time the cart is opened and saved in the editor. If a section you added disappears, check ordering before assuming a content bug.
- **Full-sprite hitboxes read as too generous.** An 8x8 AABB matched to the sprite's bounding box, not its drawn silhouette, makes near-miss collisions feel wrong. Games have converged on insetting 1-2px on every side as the default starting point, not just the eventual fix.
- **`rnd()` inside `_draw()` flickers.** Any per-frame decorative randomness (speckle, static, dither) needs a deterministic hash of position instead, e.g. `(x*7+y*13)%23`, so it's stable frame to frame rather than reflickering at 30-60fps.
- **State-change effects can jitter near a boundary.** A value converging on a threshold (a chasing enemy nearly matching the player's x) can flip the boundary check every frame from floating-point noise, re-triggering a sound or animation on every one of those frames. Add a cooldown timer on the effect, not just the underlying comparison.
- **A logic-level fix isn't a play-tested fix.** A rule that passes an isolated Lua harness can still fail in the real game if the harness didn't model the actual input path (timing, camera, simultaneous state). Confirm with real play before marking a bug resolved, especially for anything involving player input timing.
- **A difficulty ramp needs a live signal to ramp against.** "Gets harder as you progress" only works if progress is knowable at the point where the ramp applies; procedural content generated entirely upfront (a full level, a full dungeon) has no such signal yet when it's generated. Decide what live variable actually drives the ramp before writing the formula.

## Related

- [`SPEC-FORMAT.md`](../SPEC-FORMAT.md) — the README/DESIGN/PLAN/CLAUDE document set and section structure every game follows.
- [`PLATFORMS.md`](../PLATFORMS.md) — constraints and capabilities per platform (Pico-8, Picotron, Pygame, TIC-80).
- [`tools/CLAUDE.md`](CLAUDE.md) — full asset-generation tool reference and Pico-8 section data formats.
- [`lib/CLAUDE.md`](../lib/CLAUDE.md) — shared Lua snippets, current build status, token budgeting table.
- [`BUGS.md`](../BUGS.md) — full bug history behind the pitfalls above.
- [`tools/TASKS.md`](TASKS.md) — this doc is a first draft toward task 3's planned `/pico8` skill; the skill itself isn't built yet.
