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

Then open `http://localhost:8000/`. There is no build system, linter, or test suite. Verification is manual: regenerate, serve, and check the page in a browser.

`generate.py` takes one optional positional argument: `generate` (default, the above) or `publish` (see Publishing below).

## Architecture

`generate.py` has two halves living in one file:

1. **Data collection** (top of the file): walks `ROOT.iterdir()` for numbered game folders (`1/`, `2/`, ...) only — `lib/` and `tools/` are not collected or shown on this page. For each game it reads `README.md` (for title/tagline), checks for a `.p8` cart and a captured label, and checks whether `DESIGN.md` exists (a boolean, not its text — see Doc links below). This is assembled into a `{"games": [...]}` dict and serialized to JSON.
2. **`TEMPLATE`** (bottom of the file): a Python triple-quoted string containing the entire page — HTML, a small amount of page-specific CSS, and a vanilla-JS renderer. The JSON blob from step 1 is substituted into a `__DATA__` placeholder inside a `<script type="application/json">` data island. JS builds each tile's markup client-side from that data (`tileHtml()`); there's no server-side/Python string-formatting of individual tiles.

There's no separate `.html`/`.css`/`.js` template file to edit; all page-specific markup and client logic live inside the `TEMPLATE` string in `generate.py`. The bulk of the visual styling comes from `theme/styles.css` (see below), not from CSS written in `generate.py`.

### Theme (`theme/`)

`theme/styles.css` and `theme/fonts/` (Fira Code, three weights, woff2) are copied verbatim from Warped's "Techie" design system (source at `~/projects/warped/visual-style-next/techie/` on this machine — see that folder's own `DESIGN.md` for the palette/type/spacing rationale and its component contracts). This page does **not** vendor the warpedvisions.org blog theme; Techie is a deliberately separate, all-dark, dev-tool register, not an approximation of the blog's light theme. `generate.py` adds only a small amount of page-specific CSS on top (`.tile-embed`/`.game-embed`, sizing the embed area), everything else — tokens, `.tile-flip`, `.title`, `.eyebrow`, `nav.tabs`, etc. — comes straight from `styles.css` unmodified. When touching visual details, check whether the change belongs in Techie itself (reusable by other Techie consumers) before adding one-off CSS here.

### Doc links, not rendered docs

Earlier versions of this page rendered README/DESIGN/PLAN/CLAUDE text inline (via `marked.js`) inside an "About" face. That's gone: a tile's back face links to the real files on GitHub instead (`readmeUrl`, and `designUrl` if `DESIGN.md` exists), resolved once per run via `github_repo_url()` (`git remote get-url origin`, normalized from SSH to `https://github.com/owner/repo`, `.git` suffix stripped). Every game folder shares the one repo remote, so this resolves without the per-folder ambiguity a multi-repo tool would have. If there's no remote configured, `readmeUrl`/`designUrl` are `None` and the JS falls back to showing the plain local path (`<n>/README.md`) as text instead of a link, rather than emitting a broken one. `PLAN.md` and `CLAUDE.md` aren't linked from a tile; only README/DESIGN, matching what's actually useful to a visitor browsing the jam.

### Pico-8 export handling

Unchanged from before: for each game with a cart, `ensure_export()` shells out to `pico8 -x <cart>.p8 -export ...` to produce a playable web build, but only if the cart has a captured label (`__label__` present in the `.p8` file — Pico-8 refuses to export otherwise). `find_pico8()` locates the binary via `PICO8_PATH`, `PATH`, or a couple of hardcoded macOS install paths, since `pico8` is often just a shell alias rather than an executable subprocess can resolve.

### Generated output

`downloads/` (cart copies), `exports/<n>/` (playable web builds), and `games/<n>.html` (standalone per-game pages) are written by `generate.py` and gitignored; `index.html` reads `downloads/`/`exports/` at runtime via relative paths. `theme/` is committed (not generated). Together this is what makes `preview/` deployable as a standalone folder, independent of its sibling game directories — rsync `preview/` (including `theme/`, `downloads/`, `exports/`, and `games/`) to any static host.

### The tile grid

The main view is a `grid-2` of Techie `.tile-flip` cards (`styles.css`'s stock component, unmodified), not a carousel. Client-side rendering is a single pass: `document.addEventListener('DOMContentLoaded', ...)` builds every tile's HTML from `GAMES` via `tileHtml()` and writes it into `#tiles` once, then attaches the stock flip-toggle listener (click, or Enter/Space) to each `.tile-flip`. There's no per-navigation re-render and no rotation/paging state to manage — every game is on the page at once, which is what makes this simpler than the console it replaced (see History below).

**Front face** (`tileHtml()`): `.tile-bar` shows the folder number and a status word — `built` (with `is-live`) if there's a live embed, `not ready` if the cart exists but has no captured label yet, `not built` if there's no cart at all. `.tile-embed` holds either a live `<iframe src="${embedPath}">` or a placeholder div explaining why not (`cart exists, no playable web export yet` vs. `design in progress`). Below that, the title (README's `# ` heading verbatim) and tagline, then the stock `.flip-hint`.

Embedding the live cart in an `<iframe>` (not an inline canvas sharing the tile's own document) turns out to be what avoids any conflict with the tile's own click-to-flip trigger: clicks inside an iframe's content never bubble up into the parent document's event handlers, since it's a separate browsing context. That means the whole tile can keep the stock flip-anywhere-on-the-card behavior with no dedicated flip button carved out for it, and no changes to Techie's own tile-flip JS were needed at all.

**Back face** (`backRows()`): `readme` (always present, links to GitHub if a remote resolved, else plain text), `design` (only if `DESIGN.md` exists), `download` (links to the local `.p8` copy, or `not built yet`). No `play` row — playing happens directly on the front face's embed, so a back-row link to the same thing would be redundant.

### Per-game standalone pages

`write_game_page()`/`GAME_TEMPLATE` produce `games/<n>.html`: title, tagline, the same live-embed-or-placeholder area (styled with local `.game-embed` CSS rather than the tile's `.tile-embed`, since it's not inside a `.tile-flip` card here), and the same `readme`/`design`/`download` back-rows, laid out as plain stacked `.back-row`s rather than tucked behind a flip. A direct link to one game, independent of the tile grid.

### Publishing

`publish()` uploads the already-generated `preview/` folder over SFTP, the same approach `~/projects/warped/utilities/project-list`'s own `publish` command uses: shell out to the system `sftp` binary in batch mode (`sftp -P <port> -b - <target>`, batch commands piped via stdin), so there's no new dependency and no credentials handled or stored by this script — auth is whatever the system's SSH agent/keys/`~/.ssh/config` already provide. `SFTP_ENABLED`/`SFTP_HOST`/`SFTP_USER`/`SFTP_PORT`/`SFTP_REMOTE_PATH` are plain module-level constants near the top of `generate.py`, not a YAML config file: this repo has no config-file/dependency precedent anywhere else (see the root `CLAUDE.md`'s "no build system, package manager" note), so a `config.yaml` + PyYAML dependency purely for five deploy-target values would be a heavier footprint than the feature warrants. Currently set to the same host project-list deploys to (`w28@warpedvisions.org`), a different `remote_path` (`jams.warpedvisions.org/`) dedicated to this jam preview.

project-list's own `publish` does a single `put` since its output is one distributable HTML file (fonts inlined as data URIs — see its `inline_styles()`). This preview is a whole directory tree instead (`index.html` plus `theme/`, `downloads/`, `exports/`, `games/`, none of which get inlined, since the folder itself, not a single file, is the deployable unit — see Generated output above), so `publish()` issues one recursive `put -r` per top-level item, all targeting the same `SFTP_REMOTE_PATH`, rather than a single `put -r` on `preview/` itself (which would nest everything one level deeper, under an extra `preview/` subdirectory on the remote, since sftp's `put -r localdir remotedir` creates `remotedir/localdir/...`, not `remotedir/...`). Only items that exist locally are queued — `downloads/`/`exports/`/`games/` won't exist yet on a fresh checkout with no built carts, and `sftp` errors on a nonexistent local path. `publish()` does not regenerate anything itself; it only checks that `index.html` exists (printing a "run generate first" message if not) and uploads whatever is currently on disk, mirroring project-list's own scan/render/publish separation of concerns.

### History

This page used to be a single 3D "console" carousel (`rotateX`/`rotateY` on a cube, static frame buttons, Play/Download/About faces, the warpedvisions.org blog theme vendored for fidelity to the live site) that paged through one game at a time. It was replaced with this tile grid because: the console's About face concatenated README/DESIGN/PLAN/CLAUDE into one long scrollable pane, which duplicated content already readable on GitHub and needed its own scroll-vs-swipe conflict handling on touch; and the whole page read as trying to look like the blog rather than being its own dev-tool artifact. If you find old references to `#console`, `.cube-face`, `rotateY`/`rotateX` navigation, or `marked.js` elsewhere (docs, notes, screenshots), they describe that earlier design, not the current one.
