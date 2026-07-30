#!/usr/bin/env python3
"""Generates preview/index.html from the game jam repo's game folders.

Scans numbered game folders (1/, 2/, 3/, ...) and templates a single
self-contained preview/index.html: a grid of Techie-style flip tiles, one
per game. A tile's front face is informational (title, tagline, status)
plus a live embed of the built cart; its back face links out to that
game's README/DESIGN on GitHub and its downloadable .p8, rather than
rendering any of those documents inline.

The page uses Warped's "Techie" dev-tool visual system, vendored into
preview/theme/ from ~/projects/warped/visual-style-next/techie/ (styles.css
+ Fira Code). This is a deliberately different, all-dark register from the
warpedvisions.org blog theme, not an approximation of it.

Also runs `pico8 -x <cart>.p8 -export "<num>.html"` for any game whose cart
has a captured label but no export yet, writing into preview/exports/<num>/.
Carts without a label are skipped with a note (Pico-8 refuses to export
until a label has been captured in-editor).

Usage:
    python3 generate.py           regenerate preview/index.html (default)
    python3 generate.py publish   upload the already-generated preview/
                                   folder over SFTP (see SFTP_* below);
                                   run the default command first
"""
import argparse
import json
import os
import re
import shutil
import subprocess
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
ROOT = SCRIPT_DIR.parent
EXPORTS_DIR = SCRIPT_DIR / "exports"
DOWNLOADS_DIR = SCRIPT_DIR / "downloads"
GAMES_DIR = SCRIPT_DIR / "games"
GITHUB_REF = "main"  # branch used for github.com/.../blob/<ref>/... links

# Publish the generated preview/ folder with `python3 generate.py publish`.
# Shells out to the system `sftp` binary in batch mode (same approach as
# ~/projects/warped/utilities/project-list): no new dependency, key-based
# auth only (a passwordless key + a Host alias in ~/.ssh/config is the
# expected setup, so no credentials live here). Same host project-list
# already publishes to, a different remote_path dedicated to this jam
# preview. Unlike project-list's single distributable file, this uploads
# a whole directory tree (index.html + theme/ + downloads/ + exports/ +
# games/), so publish() below issues one recursive `put -r` per top-level
# item rather than a single `put`.
SFTP_ENABLED = True
SFTP_HOST = "w28@warpedvisions.org"
SFTP_USER = None  # only needed if SFTP_HOST doesn't already embed a user
SFTP_PORT = 22
SFTP_REMOTE_PATH = "jams.warpedvisions.org/"


def read(path: Path):
    return path.read_text(encoding="utf-8") if path.exists() else None


def extract_tagline(readme_text: str) -> str:
    if not readme_text:
        return ""
    m = re.search(r"This is (?:an?|a) (.+?) built using", readme_text)
    if m:
        return m.group(1).strip()
    for line in readme_text.splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            return line
    return ""


def extract_root_intro(readme_text: str) -> str:
    """Returns the root README's top section: the text between the title
    and the first `##` subheading. Split on blank lines into paragraphs;
    callers join those into separate <p> tags."""
    if not readme_text:
        return ""
    lines = readme_text.splitlines()
    start = 0
    for i, line in enumerate(lines):
        if line.strip().startswith("# "):
            start = i + 1
            break
    body_lines = []
    for line in lines[start:]:
        if line.strip().startswith("#"):
            break
        body_lines.append(line)
    return "\n".join(body_lines).strip()


def extract_title(readme_text: str) -> str:
    if not readme_text:
        return ""
    for line in readme_text.splitlines():
        line = line.strip()
        if line.startswith("# "):
            return line[2:].strip()
    return ""


def has_label(cart_path: Path) -> bool:
    if not cart_path.exists():
        return False
    return "__label__" in cart_path.read_text(encoding="utf-8", errors="ignore")


def find_pico8() -> str | None:
    """Locates the pico8 binary. `pico8` is commonly just a shell alias (not
    on PATH), which subprocess can't resolve, so check common install
    locations too. Override with the PICO8_PATH env var if needed."""
    if env_path := os.environ.get("PICO8_PATH"):
        return env_path
    if which := shutil.which("pico8"):
        return which
    for candidate in (
        Path.home() / "Downloads/bin/PICO-8.app/Contents/MacOS/pico8",
        Path("/Applications/PICO-8.app/Contents/MacOS/pico8"),
    ):
        if candidate.exists():
            return str(candidate)
    return None


def github_repo_url() -> str | None:
    """Resolves this repo's GitHub URL from its origin remote (one remote
    for the whole repo, so every game folder's doc links share this same
    base, just a different path — no per-folder ambiguity to resolve).
    Returns None if there's no remote (e.g. a local-only clone); callers
    fall back to showing a plain local path instead of a link."""
    try:
        result = subprocess.run(
            ["git", "-C", str(ROOT), "remote", "get-url", "origin"],
            capture_output=True, text=True, timeout=10,
        )
    except (subprocess.SubprocessError, OSError):
        return None
    if result.returncode != 0:
        return None
    url = result.stdout.strip()
    m = re.match(r"git@github\.com:(.+?)(\.git)?$", url)
    if m:
        return f"https://github.com/{m.group(1)}"
    m = re.match(r"(https://github\.com/.+?)(\.git)?$", url)
    if m:
        return m.group(1)
    return None


def ensure_export(num: str, cart_path: Path) -> tuple[str | None, str]:
    """Runs pico8's headless HTML export if a label exists and no export yet.
    Returns (embed_path, status) where embed_path is the relative path (from
    preview/) if an export is or becomes available, else None, and status
    explains why when it isn't.
    """
    out_dir = EXPORTS_DIR / num
    out_html = out_dir / f"{num}.html"
    if out_html.exists():
        return f"exports/{num}/{num}.html", "ok"
    if not cart_path.exists():
        return None, "no cart"
    if not has_label(cart_path):
        return None, "no label captured yet"
    pico8 = find_pico8()
    if not pico8:
        return None, "pico8 binary not found (set PICO8_PATH)"
    out_dir.mkdir(parents=True, exist_ok=True)
    try:
        result = subprocess.run(
            [pico8, "-x", cart_path.name, "-export", str(out_html.resolve())],
            cwd=cart_path.parent,
            capture_output=True,
            text=True,
            timeout=60,
        )
    except (subprocess.SubprocessError, OSError) as e:
        return None, f"export failed to run ({e})"
    if out_html.exists():
        return f"exports/{num}/{num}.html", "ok"
    detail = (result.stderr or result.stdout or "").strip().splitlines()
    return None, f"export ran but produced no file ({detail[-1] if detail else 'no output'})"


def stage_download(num: str, cart_path: Path) -> str | None:
    """Copies the cart into preview/downloads/ so the page works when
    preview/ is deployed on its own, without its sibling game folders."""
    if not cart_path.exists():
        return None
    DOWNLOADS_DIR.mkdir(parents=True, exist_ok=True)
    dest = DOWNLOADS_DIR / cart_path.name
    shutil.copy2(cart_path, dest)
    return f"downloads/{cart_path.name}"


def collect_game(dir_: Path, github_base: str | None) -> dict:
    num = dir_.name
    cart_path = dir_ / f"{num}.p8"
    readme = read(dir_ / "README.md")
    embed_path, embed_status = ensure_export(num, cart_path)
    has_design = (dir_ / "DESIGN.md").exists()
    return {
        "num": num,
        "title": extract_title(readme or ""),
        "tagline": extract_tagline(readme or ""),
        "hasCart": cart_path.exists(),
        "cartRelPath": stage_download(num, cart_path),
        "embedPath": embed_path,
        "embedStatus": embed_status,
        "readmeUrl": f"{github_base}/blob/{GITHUB_REF}/{num}/README.md" if github_base else None,
        "designUrl": f"{github_base}/blob/{GITHUB_REF}/{num}/DESIGN.md" if (github_base and has_design) else None,
        "hasDesign": has_design,
    }


def write_game_page(game: dict):
    """Writes preview/games/<n>.html: a standalone page with just this
    game's live embed and its doc links, for a direct link to a single
    entry (independent of the index.html tile grid)."""
    data = {"game": game}
    json_blob = json.dumps(data)
    json_blob = re.sub(r"</script", "<\\/script", json_blob, flags=re.IGNORECASE)
    title = game["title"] or f"Game {game['num']}"
    html = GAME_TEMPLATE.replace("__TITLE__", title).replace("__DATA__", json_blob)
    GAMES_DIR.mkdir(parents=True, exist_ok=True)
    (GAMES_DIR / f"{game['num']}.html").write_text(html, encoding="utf-8")


def publish() -> None:
    """Uploads the already-generated preview/ folder over SFTP via the
    system `sftp` binary in batch mode: no new dependency, and auth is
    whatever the system's SSH agent/keys/~/.ssh/config already provide, so
    no credentials are ever handled or stored by this script."""
    if not SFTP_ENABLED:
        print("sftp publishing is disabled (set SFTP_ENABLED = True in generate.py)")
        return
    if not SFTP_HOST or not SFTP_REMOTE_PATH:
        print("SFTP_HOST and SFTP_REMOTE_PATH must be set in generate.py")
        return

    index_path = SCRIPT_DIR / "index.html"
    if not index_path.is_file():
        print(f"nothing to publish, {index_path} does not exist yet (run 'python3 generate.py' first)")
        return

    target = f"{SFTP_USER}@{SFTP_HOST}" if SFTP_USER else SFTP_HOST

    # index.html is a single file; theme/, downloads/, exports/, games/ are
    # directories. One recursive put per top-level item, all landing
    # directly in remote_path, rather than a single `put -r` on preview/
    # itself (which would nest everything one level deeper, under an extra
    # preview/ subdirectory on the remote). Only existing items are queued —
    # downloads/exports/games won't exist yet on a repo with no built carts.
    batch_lines = [f"put {index_path} {SFTP_REMOTE_PATH}"]
    for item in ("theme", "downloads", "exports", "games"):
        local_dir = SCRIPT_DIR / item
        if local_dir.is_dir():
            batch_lines.append(f"put -r {local_dir} {SFTP_REMOTE_PATH}")
    batch = "\n".join(batch_lines) + "\n"

    try:
        out = subprocess.run(
            ["sftp", "-P", str(SFTP_PORT), "-b", "-", target],
            input=batch, capture_output=True, text=True, timeout=120,
        )
    except (OSError, subprocess.SubprocessError) as e:
        print(f"sftp publish failed: {e}")
        return

    if out.returncode != 0:
        print(f"sftp publish failed: {out.stderr.strip() or out.stdout.strip()}")
    else:
        print(f"published preview/ -> {target}:{SFTP_REMOTE_PATH}")


def generate():
    game_dirs = sorted(
        (d for d in ROOT.iterdir() if d.is_dir() and d.name.isdigit()),
        key=lambda d: int(d.name),
    )
    github_base = github_repo_url()
    games = [collect_game(d, github_base) for d in game_dirs]

    root_readme = read(ROOT / "README.md")
    data = {
        "games": games,
        "readmeIntro": extract_root_intro(root_readme or ""),
        "readmeUrl": f"{github_base}/blob/{GITHUB_REF}/README.md" if github_base else None,
    }
    json_blob = json.dumps(data)
    # Defensively break up a literal "</script" so it can't terminate the
    # data island early; extremely unlikely to occur in these docs, but cheap
    # to guard against.
    json_blob = re.sub(r"</script", "<\\/script", json_blob, flags=re.IGNORECASE)

    repo_nav = f'<a href="{github_base}">repo</a>' if github_base else ""
    html = TEMPLATE.replace("__DATA__", json_blob).replace("__REPO_NAV__", repo_nav)
    (SCRIPT_DIR / "index.html").write_text(html, encoding="utf-8")

    for g in games:
        write_game_page(g)

    built = sum(1 for g in games if g["hasCart"])
    embedded = sum(1 for g in games if g["embedPath"])
    print(f"Wrote preview/index.html — {len(games)} games ({built} built, {embedded} with a live embed)")
    print(f"Wrote preview/games/<n>.html for {len(games)} games")
    if not github_base:
        print("  note: no GitHub origin remote resolved — readme/design back-rows show local paths, not links")
    for g in games:
        if g["hasCart"] and not g["embedPath"]:
            print(f"  game {g['num']}: cart exists but no live embed — {g['embedStatus']}")


TEMPLATE = r"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Warped 2026 Summer Game Jam — preview</title>
<link rel="stylesheet" href="theme/styles.css">
<style>
.tile-embed {
  width: 100%;
  aspect-ratio: 1 / 1;
  min-height: 320px;
  align-self: stretch;
  background: var(--brown-950);
  border-bottom: 1px solid var(--border);
  overflow: hidden;
}
.tile-embed iframe { width: 100%; height: 100%; border: 0; display: block; }
.tile-embed .placeholder {
  color: var(--tan); text-align: center; padding: var(--space-5); font-size: 0.8rem;
  display: flex; flex-direction: column; justify-content: center; height: 100%; box-sizing: border-box;
}
.tile-embed .placeholder strong {
  display: block; color: var(--mustard); text-transform: uppercase; letter-spacing: 0.06em;
  margin-bottom: var(--space-2); font-size: 0.75rem;
}
/* Techie's own .grid-2/.grid-3 use repeat(N, 1fr), whose columns default to
   a min-content floor. This page's embed (aspect-ratio + min-height) gives
   each tile a natural minimum width wider than a 2-up column has room for
   below a certain window width, so the grid grows a column to fit instead
   of shrinking the embed — a classic CSS grid "blowout": one tile ends up
   full-width and the other is pushed off-screen behind a horizontal
   scrollbar. minmax(0, 1fr) removes that floor so columns can actually
   shrink; local override here rather than editing the shared styles.css,
   since other Techie consumers may not have this kind of size-floor content
   and shouldn't need to think about it. Worth reporting upstream too. */
.grid-2 { grid-template-columns: repeat(2, minmax(0, 1fr)); }

/* minmax(0, 1fr) alone fixes the track's own floor, but a grid ITEM has
   the same auto-min-width-from-content default independently — .tile-flip
   still won't shrink below its content's min-content width (the iframe's
   default intrinsic size) unless told it's allowed to. Same family of bug,
   one level down; both fixes are needed together. */
.grid-2 > .tile-flip { min-width: 0; }

@media (max-width: 420px) {
  .grid-2 { grid-template-columns: 1fr; }
}
</style>
</head>
<body>

<header class="wrap" style="border-bottom: 1px solid var(--border); padding: var(--space-5) 0; display: flex; align-items: baseline; justify-content: space-between; gap: var(--space-5); flex-wrap: wrap;">
  <div>
    <div class="eyebrow" style="color: var(--tan); margin-bottom: var(--space-2);">warpedvisions.org / game-jams</div>
    <div class="title" style="font-size: 1.25rem;">'26 SUMMER GAME JAM</div>
  </div>
  <nav class="tabs">
    <a href="#" class="active">games</a>
    __REPO_NAV__
  </nav>
</header>

<main class="wrap">
  <div id="readme-intro-wrap" style="padding-top: var(--space-6);"></div>
  <section style="padding: var(--space-7) 0 var(--space-8);">
    <div style="display: flex; align-items: baseline; justify-content: space-between; gap: var(--space-4); margin-bottom: var(--space-6); flex-wrap: wrap;">
      <div class="eyebrow" style="color: var(--avocado);">entries<span class="cursor" aria-hidden="true"></span></div>
      <div class="meta-text" style="max-width: 42ch; text-align: right;">click a tile for links: readme, design, download.</div>
    </div>
    <div class="grid-2" id="tiles"></div>
  </section>
</main>

<footer class="wrap" style="border-top: 1px solid var(--border); padding: var(--space-6) 0 var(--space-8); font-size: 0.76rem; color: var(--tan);">
  warped@techie:~$ game jam preview<span class="cursor" aria-hidden="true"></span>
</footer>

<script id="site-data" type="application/json">__DATA__</script>
<script>
const DATA = JSON.parse(document.getElementById('site-data').textContent);
const GAMES = DATA.games;

function escapeHtml(s){
  return s.replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
}

function readmeIntroHtml(){
  if(!DATA.readmeIntro) return '';
  const paras = DATA.readmeIntro.split(/\n{2,}/).map(p => p.trim()).filter(Boolean);
  const body = paras.map(p => `<p>${escapeHtml(p).replace(/\n/g, ' ')}</p>`).join('');
  const link = DATA.readmeUrl ? `<p style="margin-top: var(--space-3);"><a href="${DATA.readmeUrl}">full README &#8594;</a></p>` : '';
  return `<div class="callout"><span class="eyebrow">readme</span>${body}${link}</div>`;
}

function embedHtml(game){
  if(game.embedPath){
    return `<iframe src="${game.embedPath}" loading="lazy" allow="autoplay" scrolling="no"></iframe>`;
  }
  const hint = game.hasCart
    ? 'cart exists, no playable web export yet'
    : 'design in progress';
  return `<div class="placeholder"><strong>not ready</strong>${hint}</div>`;
}

function backRows(game){
  const rows = [];
  rows.push(`<div class="back-row"><span class="k">readme</span><span class="v">${
    game.readmeUrl ? `<a href="${game.readmeUrl}">${game.num}/README.md</a>` : `${game.num}/README.md`
  }</span></div>`);
  if(game.designUrl){
    rows.push(`<div class="back-row"><span class="k">design</span><span class="v"><a href="${game.designUrl}">${game.num}/DESIGN.md</a></span></div>`);
  }
  rows.push(`<div class="back-row"><span class="k">download</span><span class="v">${
    game.cartRelPath ? `<a href="${game.cartRelPath}">${game.num}.p8</a>` : 'not built yet'
  }</span></div>`);
  return rows.join('');
}

function tileHtml(game){
  const status = game.embedPath ? 'built' : (game.hasCart ? 'not ready' : 'not built');
  const liveClass = game.embedPath ? ' is-live' : '';
  const title = game.title || `Game ${game.num}`;
  return `
    <div class="tile-flip" role="button" tabindex="0" aria-pressed="false" aria-label="${title}, flip for details">
      <div class="tile-flip-inner">
        <div class="tile-face tile-front">
          <div class="tile-bar"><span class="tile-path">${game.num}/</span><span class="tile-status${liveClass}">${status}</span></div>
          <div class="tile-embed">${embedHtml(game)}</div>
          <div class="tile-body">
            <h3 class="title title-card">${title}</h3>
            ${game.tagline ? `<p class="tile-desc">${game.tagline}</p>` : ''}
            <span class="flip-hint">click for details &#8635;</span>
          </div>
        </div>
        <div class="tile-face tile-back">
          <div class="tile-bar"><span class="tile-path">${game.num}/</span><span class="tile-status">details</span></div>
          <div class="tile-back-body">${backRows(game)}</div>
        </div>
      </div>
    </div>`;
}

document.addEventListener('DOMContentLoaded', () => {
  document.getElementById('readme-intro-wrap').innerHTML = readmeIntroHtml();
  const container = document.getElementById('tiles');
  if(GAMES.length === 0){
    container.innerHTML = '<p class="meta-text">No games in this repo yet.</p>';
    return;
  }
  container.innerHTML = GAMES.map(tileHtml).join('');
  document.querySelectorAll('.tile-flip').forEach(function (el) {
    function toggle(){
      const pressed = el.getAttribute('aria-pressed') === 'true';
      el.setAttribute('aria-pressed', String(!pressed));
    }
    el.addEventListener('click', toggle);
    el.addEventListener('keydown', function (e) {
      if (e.key === 'Enter' || e.key === ' ' || e.key === 'Spacebar') {
        e.preventDefault();
        toggle();
      }
    });
  });
});
</script>
</body>
</html>
"""

GAME_TEMPLATE = r"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>__TITLE__ — Warped 2026 Summer Game Jam</title>
<link rel="stylesheet" href="../theme/styles.css">
<style>
.game-embed {
  width: 100%; max-width: 480px; aspect-ratio: 1 / 1; margin: 0 auto;
  background: var(--brown-950); border: 1px solid var(--border); border-radius: var(--radius); overflow: hidden;
}
.game-embed iframe { width: 100%; height: 100%; border: 0; display: block; }
.game-embed .placeholder {
  color: var(--tan); text-align: center; padding: var(--space-5); font-size: 0.85rem;
  display: flex; flex-direction: column; justify-content: center; height: 100%; box-sizing: border-box;
}
.game-embed .placeholder strong {
  display: block; color: var(--mustard); text-transform: uppercase; letter-spacing: 0.06em;
  margin-bottom: var(--space-2); font-size: 0.8rem;
}
</style>
</head>
<body>

<header class="wrap" style="border-bottom: 1px solid var(--border); padding: var(--space-5) 0;">
  <a href="../index.html" style="font-size: 0.78rem;">&larr; all games</a>
</header>

<main class="wrap" style="padding: var(--space-7) 0 var(--space-8); max-width: 640px;">
  <h1 class="title title-page" id="game-title" style="font-size: 1.6rem;"></h1>
  <p class="meta-text" id="game-tagline" style="margin-top: var(--space-2);"></p>
  <div class="game-embed" id="game-embed" style="margin-top: var(--space-6);"></div>
  <div id="game-links" style="margin-top: var(--space-5); display: flex; flex-direction: column; gap: var(--space-2);"></div>
</main>

<script id="site-data" type="application/json">__DATA__</script>
<script>
const GAME = JSON.parse(document.getElementById('site-data').textContent).game;

document.getElementById('game-title').textContent = GAME.title || `Game ${GAME.num}`;
const tagline = document.getElementById('game-tagline');
if(GAME.tagline){ tagline.textContent = GAME.tagline; } else { tagline.remove(); }

const embed = document.getElementById('game-embed');
if(GAME.embedPath){
  embed.innerHTML = `<iframe src="../${GAME.embedPath}" loading="lazy" allow="autoplay" scrolling="no"></iframe>`;
} else {
  const hint = GAME.hasCart ? 'cart exists, no playable web export yet' : 'design in progress';
  embed.innerHTML = `<div class="placeholder"><strong>not ready</strong>${hint}</div>`;
}

const rows = [];
rows.push(`<div class="back-row"><span class="k">readme</span><span class="v">${
  GAME.readmeUrl ? `<a href="${GAME.readmeUrl}">${GAME.num}/README.md</a>` : `${GAME.num}/README.md`
}</span></div>`);
if(GAME.designUrl){
  rows.push(`<div class="back-row"><span class="k">design</span><span class="v"><a href="${GAME.designUrl}">${GAME.num}/DESIGN.md</a></span></div>`);
}
rows.push(`<div class="back-row"><span class="k">download</span><span class="v">${
  GAME.cartRelPath ? `<a href="../${GAME.cartRelPath}">${GAME.num}.p8</a>` : 'not built yet'
}</span></div>`);
document.getElementById('game-links').innerHTML = rows.join('');
</script>
</body>
</html>
"""

def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument(
        "command", nargs="?", default="generate", choices=["generate", "publish"],
        help="'generate' (default): scan + render + export. 'publish': upload the already-generated preview/ over SFTP.",
    )
    args = parser.parse_args()
    if args.command == "publish":
        publish()
    else:
        generate()


if __name__ == "__main__":
    main()
