# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Static showcase page for the game jam. `preview/generate.py` scans the sibling game folders and templates a single self-contained `preview/index.html`; nothing here is hand-edited.

## Commands

Regenerate the page after adding a game, changing a spec, or capturing a cart's Pico-8 label:

```sh
python3 generate.py
```

Serve it locally (required — Pico-8's web export needs HTTP, not `file://`):

```sh
python3 -m http.server 8000
```

Then open `http://localhost:8000/`. There is no build system, linter, or test suite; `generate.py` has no CLI flags. Verification is manual: regenerate, serve, and check the page in a browser.

## Architecture

`generate.py` has two halves living in one file:

1. **Data collection** (top of the file): walks `ROOT.iterdir()` for numbered game folders (`1/`, `2/`, ...) only — `lib/` and `tools/` are not collected or shown on this page. For each game it reads `README.md`/`DESIGN.md`/`PLAN.md`/`CLAUDE.md` as raw text and checks for a `.p8` cart. This is assembled into a `{"games": [...]}` dict and serialized to JSON.
2. **`TEMPLATE`** (bottom of the file): a Python triple-quoted string containing the entire page — HTML, a small amount of page-specific CSS, and a vanilla-JS renderer. The JSON blob from step 1 is substituted into a `__DATA__` placeholder inside a `<script type="application/json">` data island. Markdown docs are rendered in the browser via `marked.js` (CDN), not by Python.

There's no separate `.html`/`.css`/`.js` template file to edit; all markup and client logic live inside the `TEMPLATE` string in `generate.py`. The bulk of the visual styling, though, comes from `theme/` (see below), not from CSS written in `generate.py`.

### Vendored theme (`theme/`)

`theme/theme-vars.css`, `header.css`, `warped.css`, `warped.js`, and `reset.css` are copied from the real warpedvisions.org Hugo theme (source at `~/projects/sites/w42/themes/w42` on this machine; `warped.css`/`warped.js` specifically from the live `cdn.warpedvisions.org` build, which is newer than what's checked into that theme repo — verify against the live site before re-vendoring, don't assume the local theme repo is current). `generate.py`'s `TEMPLATE` links these directly rather than re-approximating the site's styles inline, and reuses the real markup for the header (logo, tagline, sun/moon theme-toggle button) and footer (verbatim, including "Powered by Hugo," which is inaccurate here but intentional — see README.md's "Theme fidelity" section for why). The theme toggle uses the real site's `.dark` body-class convention, not a custom attribute, because the vendored CSS is written against that class.

`warped.js`'s `warpBranding()` injects the top/bottom coloured "flourish" bars at runtime by prepending/appending elements to `<body>`; that's why they don't appear in `generate.py`'s own markup.

### Pico-8 export handling

For each game with a cart, `ensure_export()` shells out to `pico8 -x <cart>.p8 -export ...` to produce a playable web build, but only if the cart has a captured label (`__label__` present in the `.p8` file — Pico-8 refuses to export otherwise). `find_pico8()` locates the binary via `PICO8_PATH`, `PATH`, or a couple of hardcoded macOS install paths, since `pico8` is often just a shell alias rather than an executable subprocess can resolve.

### Generated output

`downloads/` (cart copies) and `exports/<n>/` (playable web builds) are written by `generate.py`, gitignored, and read by the page at runtime via relative paths. `theme/` is committed (not generated). Together this is what makes `preview/` deployable as a standalone folder, independent of its sibling game directories — rsync `preview/` (including `theme/`, `downloads/`, and `exports/`) to any static host.

### The console carousel

The main view is a single 3D "console," not a grid of tiles. It's split into two DOM layers, and that split matters:

- **`.console-frame`** — a static CSS grid (`.frame-btn.top`/`.bottom`/`.left`/`.right` around a centre `.console-window` cell). These buttons never move or rotate; they're the always-visible, full-width/height "control chrome." This exists because a literal 90°-rotated cube face is edge-on to the camera at rest — invisible *and* unclickable (confirmed the hard way: Playwright couldn't even click a button mounted directly on a rotating face, because at rest it has no on-screen hit area). Don't try to put the nav buttons back onto the rotating cube; keep them on the static frame.
- **`#console`** — the inner cube, absolutely positioned inside `.console-window`, `transform-style: preserve-3d`, with six `.cube-face` children (`front`/`back`/`top`/`bottom`/`left`/`right`). Only `front` ever holds real content (`#console-screen`); the other five are plain `var(--tertiary)`-coloured panels that exist purely to give the box genuine depth during rotation — without them, mid-turn would show a gap instead of a believable edge.

Client-side state is just two indices: `gameIndex` (which game) and `faceIndex` (which of `FACES = ['play', 'download', 'about']`). `defaultFaceIndex(game)` picks `'about'` instead of `'play'` for any game with no live embed, so landing on an unbuilt game shows its spec instead of an empty screen.

Navigation is a content-swap rotation, implemented in `flip(axis, dir, updateFn)`: `#console` (not the buttons) rotates out via a CSS `transition` on `transform` (`rotateY` for left/right game paging, `rotateX` for up/down face paging), a `transitionend` listener swaps `gameIndex`/`faceIndex` and re-renders `#console-screen`'s content once the rotation completes, then the cube snaps instantly to the opposite angle (transition disabled, forced reflow) and animates back to `rotate(0)`. This is pure CSS 3D; JS only toggles `#console`'s inline transform and swaps DOM content between the two phases — no animation loop, no drag physics. A `busy` flag blocks new navigation until a flip's exit-plus-re-entry finishes (~1s) — don't remove it without accounting for `render()` being called mid-transition. `render()` also rewrites the frame buttons' text every call (`▲ {label of the face one step up}`, `▼ {label of the face one step down}`), since which face is "up" vs. "down" depends on the current `faceIndex`.

`flip()` also sets `cube.style.transformOrigin` before rotating, to the edge in the direction of travel (`right`/`left` for game paging, `bottom`/`top` for face paging) rather than leaving it at the element's default center. A center-pivoted rotation on a shallow box (`--console-depth` vs. `--embed-size`) shrinks symmetrically toward the middle and reads as a fade, not a turn — this was a real bug caught by eye, not just theory. Hinging on the leading edge makes the motion asymmetric (one edge anchored, the other visibly sweeps like a door or a page turning), which is what actually sells "rotation" to a viewer. Don't reset `transformOrigin` back to center; there's no need to since it only affects visuals at a non-zero rotation, and idle state is always `rotate(0)`.

The nameplate below the console (`.console-indicator`) shares the frame's `background: var(--tertiary)` and butts directly against it (`margin-top: -1px`, matching `border-radius` on the bottom corners only) so it reads as one attached object rather than floating page text. It renders just `.title` and `.tagline`; there is deliberately no `Game N · i/total · Face` line — it was cut for clarity, so don't re-add a position/state readout here without checking that's still wanted. Title comes from `extract_title()` (the game's README `# ` heading, verbatim) — games whose README predates the SPEC-FORMAT.md convention (1 and 2, as of this writing) don't have a real name yet and will show something like "1 README" until that's fixed in the source README, not something to special-case here.

### Touch-swipe vs. scroll conflict

The touch-swipe handler (bottom of the inline `<script>`) listens on `.console-stage`, which contains `#console-screen`. A vertical drag is normally read as a face-nav swipe (`nextFace()`/`prevFace()`) — but the about face is a scrollable, often-tall document, so a vertical drag that *starts* on `#console-screen` needs to scroll it natively instead of flipping faces out from under the reader. `touchOnScreen` (set in the `touchstart` handler via `e.target.closest('#console-screen')`) gates this: face-nav swipes only fire for drags starting on the frame/bezel. Horizontal drags (game paging) aren't gated, since they don't conflict with vertical scrolling. If you touch this logic, re-test by dragging vertically *inside* the about face specifically — the desktop mouse-wheel path won't catch a regression here, since wheel events never go through the touch handler at all.

The about face (`aboutFaceHtml()`) concatenates README, DESIGN, PLAN, and CLAUDE guidance into one scrollable terminal-styled pane, skipping whichever don't exist for that game. Both the download and about faces use a dark-background, monospace, terminal-green look (`#console-screen.face-about`/`.face-download`); only the play face resembles a live screen. Heading colours inside `.face-about` are overridden explicitly (`h1`–`h5`, `strong`) because the vendored `reset.css` sets `color: var(--primary)` directly on heading elements, which otherwise wins over the inherited terminal-green and renders headings nearly invisible against the dark background — a real bug hit once already, worth remembering if more markdown-rendered chrome is added.
