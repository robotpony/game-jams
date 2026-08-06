# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Static showcase page for the game jam. `preview/generate.py` scans the sibling game folders and templates a single self-contained `preview/index.html`; nothing here is hand-edited.

## Commands

Regenerate the page after adding a game, changing a spec, or capturing a cart's Pico-8 label:

```sh
python3 generate.py
```

Serve it locally (required — both Pico-8's and TIC-80's web exports need HTTP, not `file://`):

```sh
python3 -m http.server 8000
```

Then open `http://localhost:8000/`. There is no build system, linter, or test suite. Verification is manual: regenerate, serve, and check the page in a browser.

`generate.py` takes one optional positional argument: `generate` (default, the above) or `publish` (see Publishing below).

## Architecture

`generate.py` has two halves living in one file:

1. **Data collection** (top of the file): walks `ROOT.iterdir()` for numbered game folders (`1/`, `2/`, ...) only — `lib/` and `tools/` are not collected or shown on this page. For each game it reads `README.md` (for title/tagline) and collects one or more platform builds (see [Multi-platform games](#multi-platform-games) below), each with its own cart, export, and DESIGN.md check. This is assembled into a `{"games": [...]}` dict and serialized to JSON.
2. **`TEMPLATE`** (bottom of the file): a Python triple-quoted string containing the entire page — HTML, a small amount of page-specific CSS, and a vanilla-JS renderer. The JSON blob from step 1 is substituted into a `__DATA__` placeholder inside a `<script type="application/json">` data island. JS builds each tile's markup client-side from that data (`tileHtml()`); there's no server-side/Python string-formatting of individual tiles.

There's no separate `.html`/`.css`/`.js` template file to edit; all page-specific markup and client logic live inside the `TEMPLATE` string in `generate.py`. The bulk of the visual styling comes from `theme/styles.css` (see below), not from CSS written in `generate.py`.

### Multi-platform games

A game folder is either flat single-platform (`<n>/<n>.p8` or `<n>/<n>.tic` directly in the folder, matching SPEC-FORMAT.md's default layout) or a multi-platform folder with a `pico-8/` and/or `tic-80/` subfolder (SPEC-FORMAT.md's "second platform" layout — see `4/`, the jam's first upscale). `find_build_specs()` detects which shape a game folder is in and returns a list of `(platform, build_dir)` pairs; `collect_build()` runs the platform-appropriate export function (`ensure_export_pico8()` or `ensure_export_tic80()`) and DESIGN.md lookup once per pair. A game's collected data is therefore `{"num", "title", "tagline", "readmeUrl", "builds": [...]}`, where `builds` has one entry for a single-platform game and two (so far) for game 4. Adding a third platform means adding an entry to `PLATFORM_INFO` plus its own `ensure_export_<platform>()`; nothing else in the collection path is platform-specific.

A game with more than one build gets a small tab strip (`.platform-tabs`) above its embed instead of a single iframe, both on its tile (`embedHtml()`) and its standalone page (`GAME_TEMPLATE`'s inline script) — see [The tile grid](#the-tile-grid) below. `backRows()`/`GAME_TEMPLATE`'s row-builder prefix each design/download row with the platform's lowercase label (`pico-8 design`, `tic-80 download`, ...) whenever a game has more than one build, and leave the plain `design`/`download` labels alone for a single-build game so existing single-platform games' back faces don't change.

### Theme (`theme/`)

`theme/styles.css` and `theme/fonts/` (Fira Code, three weights, woff2) are copied verbatim from Warped's "Techie" design system (source at `~/projects/warped/visual-style-next/techie/` on this machine — see that folder's own `DESIGN.md` for the palette/type/spacing rationale and its component contracts). This page does **not** vendor the warpedvisions.org blog theme; Techie is a deliberately separate, all-dark, dev-tool register, not an approximation of the blog's light theme. `generate.py` adds only a small amount of page-specific CSS on top (`.tile-embed`/`.game-embed`, sizing the embed area), everything else — tokens, `.tile-flip`, `.title`, `.eyebrow`, `nav.tabs`, etc. — comes straight from `styles.css` unmodified. When touching visual details, check whether the change belongs in Techie itself (reusable by other Techie consumers) before adding one-off CSS here.

### Doc links, not rendered docs

Earlier versions of this page rendered README/DESIGN/PLAN/CLAUDE text inline (via `marked.js`) inside an "About" face. That's gone: a tile's back face links to the real files on GitHub instead (`readmeUrl` at the game level, since README.md is shared across every build; `designUrl` per build, since DESIGN.md is platform-specific — see [Multi-platform games](#multi-platform-games)), resolved once per run via `github_repo_url()` (`git remote get-url origin`, normalized from SSH to `https://github.com/owner/repo`, `.git` suffix stripped). Every game folder shares the one repo remote, so this resolves without the per-folder ambiguity a multi-repo tool would have. If there's no remote configured, `readmeUrl`/`designUrl` are `None` and the JS falls back to showing the plain local path as text instead of a link, rather than emitting a broken one. `PLAN.md` and `CLAUDE.md` aren't linked from a tile; only README/DESIGN, matching what's actually useful to a visitor browsing the jam.

### Export handling

Each build gets exported by its own platform-specific function, both returning the same `(embed_path, status)` shape so the rest of the pipeline (`collect_build()`, the JS templates) doesn't need to know which platform it's looking at.

**Pico-8** (`ensure_export_pico8()`): shells out to `pico8 -x <cart>.p8 -export ...` to produce a playable web build, but only if the cart has a captured label (`__label__` present in the `.p8` file — Pico-8 refuses to export otherwise). `find_pico8()` locates the binary via `PICO8_PATH`, `PATH`, or a couple of hardcoded macOS install paths, since `pico8` is often just a shell alias rather than an executable subprocess can resolve. Before shelling out, it runs `tools/export/strip_comments.py`'s `strip_cart_file()` against the real cart and exports the comment-stripped result instead (written to `exports/<n>/pico-8/<n>.stripped.p8`, a build artifact, not a change to the real cart). Pico-8's export path compresses the raw `__lua__` text, comments included, into a fixed-capacity slot separate from the 8,192 token limit; game 6's cart sat at 4,357 tokens but had comments dense enough (65% of its source bytes) to blow that byte cap, failing with `failed: code block too large` even though the token counter looked fine. If the strip step itself fails (read/write error), it falls back to exporting the real cart directly rather than blocking the whole run. Output: `exports/<n>/pico-8/<n>.html` (plus the `.js` runtime `pico8 -x` writes alongside it).

**TIC-80** (`ensure_export_tic80()`): shells out to `tic80 --fs=<staging> --cli --cmd "load <cart> & export html out & exit"`. TIC-80 has no label concept, so export isn't gated on one, only on the cart existing. `find_tic80()` mirrors `find_pico8()`'s alias problem — `tic80` is aliased in this project's dev shell too — falling back to `~/tools/TIC-80/build/bin/tic80` (override with `TIC80_PATH`). Unlike Pico-8's single self-contained HTML file, `export html` produces a **zip** (`index.html` + `tic80.js` + `tic80.wasm`, ~5.3MB, + `cart.tic`); `ensure_export_tic80()` unzips it directly into `exports/<n>/tic-80/`. The cart is staged into a scratch `tempfile.TemporaryDirectory()` first rather than exporting from the cart's real folder directly, since `--fs` sandboxes tic80 to one folder for both the cart it reads and the zip it writes, and that folder shouldn't be the dev cart's own directory. No shared-runtime optimization: each TIC-80 build's export carries its own ~5.5MB copy of the runtime rather than a single copy shared across games, matching Pico-8's per-game duplication instead of adding path-rewriting logic to save disk space `exports/` (gitignored) doesn't need saved. Revisit only if the jam's TIC-80 build count grows enough for `publish()`'s upload size to actually matter. See [`tools/tic80.md`](../tools/tic80.md) for the underlying CLI this wraps.

### Generated output

`downloads/` (cart copies, one per build — `stage_download()` suffixes the filename with `-<platform>` for a game with more than one build, e.g. `4-pico-8.p8` and `4-tic-80.tic`, and leaves a single-build game's plain `<n>.<ext>` name alone), `exports/<n>/<platform>/` (playable web builds, one subfolder per build, always platform-qualified even for a single-platform game), and `games/<n>.html` (standalone per-game pages) are written by `generate.py` and gitignored; `index.html` reads `downloads/`/`exports/` at runtime via relative paths. `theme/` is committed (not generated). Together this is what makes `preview/` deployable as a standalone folder, independent of its sibling game directories — rsync `preview/` (including `theme/`, `downloads/`, `exports/`, and `games/`) to any static host.

### The tile grid

The main view is a `grid-2` of Techie `.tile-flip` cards (`styles.css`'s stock component, unmodified), not a carousel. Client-side rendering is a single pass: `document.addEventListener('DOMContentLoaded', ...)` builds every tile's HTML from `GAMES` via `tileHtml()` and writes it into `#tiles` once, then attaches the stock flip-toggle listener (click, or Enter/Space) to each `.tile-flip`. There's no per-navigation re-render and no rotation/paging state to manage — every game is on the page at once, which is what makes this simpler than the console it replaced (see History below).

**Front face** (`tileHtml()`): `.tile-bar` shows the folder number and a status word from `overallStatus()` — `built` (with `is-live`) if any build has a live embed, `not ready` if some build's cart exists but none has exported yet (e.g. a Pico-8 cart with no captured label), `not built` if no build has a cart at all. `.tile-embed` holds `embedHtml(game)`: for a single-build game, a live `<iframe src="${embedPath}">` or a placeholder div explaining why not (`cart exists, no playable web export yet` vs. `design in progress`); for a multi-build game, a `.platform-tabs` strip above stacked `.platform-panel`s (one per build, first active), each panel holding that build's iframe-or-placeholder. Below the embed, the title (README's `# ` heading verbatim) and tagline, then the stock `.flip-hint`.

Embedding the live cart in an `<iframe>` (not an inline canvas sharing the tile's own document) turns out to be what avoids any conflict with the tile's own click-to-flip trigger: clicks inside an iframe's content never bubble up into the parent document's event handlers, since it's a separate browsing context. That means the whole tile can keep the stock flip-anywhere-on-the-card behavior with no dedicated flip button carved out for it, and no changes to Techie's own tile-flip JS were needed at all. A platform tab is a real button inside `.tile-front` though, so its click listener (`handlePlatformTabClick()`, delegated on `#tiles` rather than attached per-tile) calls `stopPropagation()` before swapping the active tab/panel pair, or the same click would also toggle the card's flip.

**Back face** (`backRows()`): `readme` (always present, links to GitHub if a remote resolved, else plain text), then per build, `design` (only if that build's `DESIGN.md` exists) and `download` (links to that build's downloaded cart, or `not built yet`) — prefixed with the platform's lowercase label when a game has more than one build (see [Multi-platform games](#multi-platform-games)). No `play` row — playing happens directly on the front face's embed, so a back-row link to the same thing would be redundant.

### Per-game standalone pages

`write_game_page()`/`GAME_TEMPLATE` produce `games/<n>.html`: title, tagline, the same live-embed-or-placeholder area (styled with local `.game-embed` CSS rather than the tile's `.tile-embed`, since it's not inside a `.tile-flip` card here), and the same `readme`/`design`/`download` back-rows, laid out as plain stacked `.back-row`s rather than tucked behind a flip. A direct link to one game, independent of the tile grid.

### Publishing

`publish()` uploads the already-generated `preview/` folder over SFTP, the same approach `~/projects/warped/utilities/project-list`'s own `publish` command uses: shell out to the system `sftp` binary in batch mode (`sftp -P <port> -b - <target>`, batch commands piped via stdin), so there's no new dependency and no credentials handled or stored by this script — auth is whatever the system's SSH agent/keys/`~/.ssh/config` already provide. `SFTP_ENABLED`/`SFTP_HOST`/`SFTP_USER`/`SFTP_PORT`/`SFTP_REMOTE_PATH` are plain module-level constants near the top of `generate.py`, not a YAML config file: this repo has no config-file/dependency precedent anywhere else (see the root `CLAUDE.md`'s "no build system, package manager" note), so a `config.yaml` + PyYAML dependency purely for five deploy-target values would be a heavier footprint than the feature warrants. Currently set to the same host project-list deploys to (`w28@warpedvisions.org`), a different `remote_path` (`jams.warpedvisions.org/`) dedicated to this jam preview.

project-list's own `publish` does a single `put` since its output is one distributable HTML file (fonts inlined as data URIs — see its `inline_styles()`). This preview is a whole directory tree instead (`index.html` plus `theme/`, `downloads/`, `exports/`, `games/`, none of which get inlined, since the folder itself, not a single file, is the deployable unit — see Generated output above), so `publish()` issues one recursive `put -r` per top-level item, all targeting the same `SFTP_REMOTE_PATH`, rather than a single `put -r` on `preview/` itself (which would nest everything one level deeper, under an extra `preview/` subdirectory on the remote, since sftp's `put -r localdir remotedir` creates `remotedir/localdir/...`, not `remotedir/...`). Only items that exist locally are queued — `downloads/`/`exports/`/`games/` won't exist yet on a fresh checkout with no built carts, and `sftp` errors on a nonexistent local path. `publish()` does not regenerate anything itself; it only checks that `index.html` exists (printing a "run generate first" message if not) and uploads whatever is currently on disk, mirroring project-list's own scan/render/publish separation of concerns.

### History

This page used to be a single 3D "console" carousel (`rotateX`/`rotateY` on a cube, static frame buttons, Play/Download/About faces, the warpedvisions.org blog theme vendored for fidelity to the live site) that paged through one game at a time. It was replaced with this tile grid because: the console's About face concatenated README/DESIGN/PLAN/CLAUDE into one long scrollable pane, which duplicated content already readable on GitHub and needed its own scroll-vs-swipe conflict handling on touch; and the whole page read as trying to look like the blog rather than being its own dev-tool artifact. If you find old references to `#console`, `.cube-face`, `rotateY`/`rotateX` navigation, or `marked.js` elsewhere (docs, notes, screenshots), they describe that earlier design, not the current one.
