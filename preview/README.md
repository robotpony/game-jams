# Game jam preview

A single generated page that showcases the game jam. `index.html` is built by `generate.py` from the numbered game folders; nothing on the page is hand-edited.

## The page

- Uses Warped's "Techie" dev-tool visual system (dark, Fira Code, terminal chrome), vendored into [`theme/`](theme/) from `~/projects/warped/visual-style-next/techie/` on this machine (see [Theme](#theme)). This is a deliberately different, all-dark register from the warpedvisions.org blog theme, not an approximation of it.
- Only game folders appear. `lib/` and `tools/` are not shown on this page.
- One tile per game, in a two-column grid.

## Tiles

Each game is a flip tile (click, or focus and press Enter/Space, to flip):

- **Front**: a chrome bar (folder number and status: `built` / `not ready` / `not built`), a live embed of the built cart, the game's title (its README's `# ` heading, verbatim — some games don't have a real name yet and will show something like "1 README" until their README is updated), and its tagline.
- **Back**: links, not rendered documents — `readme` (and `design`, if a `DESIGN.md` exists) point at that folder's file on GitHub; `download` points at the local `.p8` copy. There's no in-page rendering of README/DESIGN/PLAN/CLAUDE text; the page links out to the real files instead of reproducing them.

A game with no captured cart label shows a placeholder in the embed area instead of an iframe (`cart exists, no playable web export yet` if the cart exists but has no label, `design in progress` if there's no cart at all) and its status reads `not ready` or `not built` accordingly.

Every game also gets its own standalone page at `games/<n>.html`, a direct link to a single entry (embed plus the same doc links) independent of the tile grid.

## Theme

`theme/styles.css` and `theme/fonts/` are Techie's stylesheet and subsetted Fira Code files, copied as-is from the Techie design system (see that system's own `DESIGN.md` for its palette, spacing, and component rules — the tile markup here matches its `.tile-flip` component exactly, unmodified). This page adds only a small amount of local CSS for the embed area (`.tile-embed`/`.game-embed`) on top of that.

## Building

`index.html` is generated, not hand-edited. Regenerate it after adding a game, changing a spec, or capturing a cart's Pico-8 label:

```sh
python3 generate.py
```

This scans the numbered game folders, embeds their docs' links (resolved against the repo's GitHub origin remote — if there's no remote, `readme`/`design` show a plain local path instead of a link), copies each existing cart into `downloads/`, and, for any cart with a captured label, exports a playable build into `exports/<n>/`. Both `downloads/` and `exports/` are generated output (gitignored); the page reads them at runtime via relative paths, so the whole `preview/` folder (including the committed `theme/` assets) is self-contained and can be deployed on its own.

A cart without a captured label (Esc menu in Pico-8, or the `label` console command) shows a placeholder instead of a live embed — Pico-8 refuses to export until one exists. Capture it once in the editor and rerun the generator.

## Viewing

Pico-8's web export needs to be served over HTTP; opening `index.html` directly (`file://`) will fail to load the embed due to browser fetch restrictions. Serve it locally instead:

```sh
python3 -m http.server 8000
```

Then open `http://localhost:8000/`.

## Publishing

```sh
python3 generate.py publish
```

Uploads the already-generated `preview/` folder (`index.html`, `theme/`, `downloads/`, `exports/`, `games/`) over SFTP to `jams.warpedvisions.org/`, using the system `sftp` binary in batch mode — no new dependency, no credentials stored here, key-based auth via whatever `~/.ssh/config` already provides. Run the default `python3 generate.py` first; `publish` only uploads what's already on disk, it doesn't regenerate anything. Same mechanism as `~/projects/warped/utilities/project-list`'s `publish` command, adapted for a whole directory tree instead of one distributable file (see `preview/CLAUDE.md` for the exact upload shape).

For a manual/one-off deploy instead, rsync the `preview/` folder (including its generated `downloads/` and `exports/` subfolders) to a folder on a live webserver; no server-side logic is required, it's static files.
