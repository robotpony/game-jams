#!/usr/bin/env python3
"""Generates preview/index.html from the game jam repo's game folders.

Scans numbered game folders (1/, 2/, 3/, ...) and templates a single
self-contained preview/index.html: one 3D "console" carousel that pages
between games (left/right) and, per game, through Play / Download /
Docs faces (up/down). Markdown is embedded as raw text and rendered
client-side (marked.js via CDN); no Python dependencies beyond the
standard library.

The page reuses the real warpedvisions.org header/footer/branding,
vendored into preview/theme/ from the site's Hugo theme (see
preview/README.md's "Theme fidelity" section) rather than approximating
them here.

Also runs `pico8 -x <cart>.p8 -export "<num>.html"` for any game whose cart
has a captured label but no export yet, writing into preview/exports/<num>/.
Carts without a label are skipped with a note (Pico-8 refuses to export
until a label has been captured in-editor).

Usage: python3 generate.py
"""
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


def collect_game(dir_: Path) -> dict:
    num = dir_.name
    cart_path = dir_ / f"{num}.p8"
    readme = read(dir_ / "README.md")
    embed_path, embed_status = ensure_export(num, cart_path)
    return {
        "num": num,
        "title": extract_title(readme or ""),
        "tagline": extract_tagline(readme or ""),
        "hasCart": cart_path.exists(),
        "cartRelPath": stage_download(num, cart_path),
        "embedPath": embed_path,
        "embedStatus": embed_status,
        "docs": {
            "readme": readme,
            "design": read(dir_ / "DESIGN.md"),
            "plan": read(dir_ / "PLAN.md"),
            "claude": read(dir_ / "CLAUDE.md"),
        },
    }


def write_game_page(game: dict):
    """Writes preview/games/<n>.html: a standalone dark page with just this
    game's live embed and its README + DESIGN below, for a direct link to a
    single entry (independent of the index.html console)."""
    data = {"game": game}
    json_blob = json.dumps(data)
    json_blob = re.sub(r"</script", "<\\/script", json_blob, flags=re.IGNORECASE)
    title = game["title"] or f"Game {game['num']}"
    html = GAME_TEMPLATE.replace("__TITLE__", title).replace("__DATA__", json_blob)
    GAMES_DIR.mkdir(parents=True, exist_ok=True)
    (GAMES_DIR / f"{game['num']}.html").write_text(html, encoding="utf-8")


def main():
    game_dirs = sorted(
        (d for d in ROOT.iterdir() if d.is_dir() and d.name.isdigit()),
        key=lambda d: int(d.name),
    )
    games = [collect_game(d) for d in game_dirs]

    data = {"games": games}

    json_blob = json.dumps(data)
    # Defensively break up a literal "</script" so it can't terminate the
    # data island early; extremely unlikely to occur in these docs, but cheap
    # to guard against.
    json_blob = re.sub(r"</script", "<\\/script", json_blob, flags=re.IGNORECASE)

    html = TEMPLATE.replace("__DATA__", json_blob)
    (SCRIPT_DIR / "index.html").write_text(html, encoding="utf-8")

    for g in games:
        write_game_page(g)

    built = sum(1 for g in games if g["hasCart"])
    embedded = sum(1 for g in games if g["embedPath"])
    print(f"Wrote preview/index.html — {len(games)} games ({built} built, {embedded} with a live embed)")
    print(f"Wrote preview/games/<n>.html for {len(games)} games")
    for g in games:
        if g["hasCart"] and not g["embedPath"]:
            print(f"  game {g['num']}: cart exists but no live embed — {g['embedStatus']}")


TEMPLATE = r"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Warped 2026 Summer Game Jam — preview</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Alumni+Sans+Pinstripe&family=Montserrat:wght@400;600;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="theme/reset.css">
<link rel="stylesheet" href="theme/theme-vars.css">
<link rel="stylesheet" href="theme/header.css">
<link rel="stylesheet" href="theme/warped.css">
<script defer src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
<style>
:root{--embed-size:440px; --console-depth:70px; --edge-size:42px}
.main{position:relative; max-width:calc(var(--main-width) + var(--gap) * 2); margin:auto; padding:var(--gap)}
.jam-title{text-align:center; font-family:"Montserrat",sans-serif; font-weight:700; letter-spacing:3px; text-transform:uppercase; font-size:.8em; color:var(--secondary); margin-bottom:var(--gap)}

/* The console is a static outer frame (always-visible, full-width/height
   labelled buttons — the TV's physical control chrome) wrapped around an
   inner cube that does the actual 3D rotation. A literal 90deg-rotated
   cube face is edge-on to the camera at rest — invisible and unclickable —
   so the buttons can't themselves be rotating faces; the frame stays put
   and the content cube spins inside its window. */
.console-stage{perspective:1400px; display:flex; justify-content:center; margin:8px auto}
.console-frame{
  display:grid;
  grid-template-columns: var(--edge-size) var(--embed-size) var(--edge-size);
  grid-template-rows: var(--edge-size) var(--embed-size) var(--edge-size);
  background:var(--tertiary); border-radius:16px; overflow:hidden;
}
.frame-btn{
  background:var(--tertiary); border:0; cursor:pointer; color:var(--primary);
  font-family:"Montserrat",sans-serif; font-weight:600; letter-spacing:1px; text-transform:uppercase;
  font-size:.75em; display:flex; align-items:center; justify-content:center;
}
.frame-btn:hover{background:var(--border)}
.frame-btn.top{grid-column:1 / 4; grid-row:1}
.frame-btn.bottom{grid-column:1 / 4; grid-row:3}
.frame-btn.left{grid-column:1; grid-row:2}
.frame-btn.right{grid-column:3; grid-row:2}
.frame-btn.left,.frame-btn.right{font-size:16px}

.console-window{
  grid-column:2; grid-row:2; position:relative; perspective:1400px;
  background:#000; border-radius:4px; overflow:hidden;
}
.console{
  position:absolute; inset:0; transform-style:preserve-3d; transition:transform .5s ease;
}
.cube-face{position:absolute; inset:0; backface-visibility:hidden}
.cube-face.front{transform:translateZ(calc(var(--console-depth) / 2)); background:#000}
.cube-face.back{transform:rotateY(180deg) translateZ(calc(var(--console-depth) / 2)); background:var(--tertiary)}
.cube-face.top{transform:rotateX(90deg) translateZ(calc(var(--console-depth) / 2)); background:var(--tertiary)}
.cube-face.bottom{transform:rotateX(-90deg) translateZ(calc(var(--console-depth) / 2)); background:var(--tertiary)}
.cube-face.left{transform:rotateY(-90deg) translateZ(calc(var(--console-depth) / 2)); background:var(--tertiary)}
.cube-face.right{transform:rotateY(90deg) translateZ(calc(var(--console-depth) / 2)); background:var(--tertiary)}

#console-screen{width:100%; height:100%; overflow:hidden}
#console-screen iframe{width:100%; height:100%; border:0; display:block}
#console-screen.face-about{
  background:#0b0f0c; color:#39ff6a; font-family:Menlo,Consolas,monospace; font-size:.68em;
  padding:16px; overflow-y:auto; text-align:left; display:block; height:100%; box-sizing:border-box;
  scrollbar-width:thin; scrollbar-color:#2e8a52 #0b0f0c;
}
#console-screen.face-about::-webkit-scrollbar{width:8px}
#console-screen.face-about::-webkit-scrollbar-track{background:#0b0f0c}
#console-screen.face-about::-webkit-scrollbar-thumb{background:#2e8a52; border-radius:4px}
#console-screen.face-about a{color:#7dffb0}
#console-screen.face-about h1,#console-screen.face-about h2,#console-screen.face-about h3,
#console-screen.face-about h4,#console-screen.face-about h5,#console-screen.face-about strong{
  color:#7dffb0; font-family:inherit;
}
#console-screen.face-about h1,#console-screen.face-about h2,#console-screen.face-about h3{
  font-size:1em; text-transform:uppercase; letter-spacing:1px; margin:1em 0 .3em;
}
#console-screen.face-about h1:first-child,#console-screen.face-about h2:first-child,
#console-screen.face-about h3:first-child{margin-top:0}
#console-screen.face-about table{width:100%; border-collapse:collapse; font-size:.85em; margin:.6em 0}
#console-screen.face-about th,#console-screen.face-about td{border-bottom:1px solid #1e5c34; padding:3px 5px; text-align:left}
#console-screen.face-about .doc-label{
  color:#39ff6a; text-transform:uppercase; letter-spacing:2px; font-size:.85em; margin:1em 0 .3em; opacity:.8;
}
#console-screen.face-about .doc-label:first-child{margin-top:0}
#console-screen.face-about hr{border:0; border-top:1px dashed #1e5c34; margin:1em 0}
#console-screen.face-about pre{background:#06110a; padding:8px; border-radius:4px; overflow-x:auto}
#console-screen.face-about code{background:#06110a; padding:1px 4px; border-radius:3px}
#console-screen .placeholder{color:var(--secondary); text-align:center; padding:20px; font-size:.85em; font-family:-apple-system,sans-serif}
#console-screen .placeholder strong{display:block; font-size:1.3em; letter-spacing:1px; color:var(--primary); margin-bottom:6px; font-family:Menlo,Consolas,monospace}
#console-screen.face-about .placeholder{color:#2e8a52; font-family:inherit}
#console-screen.face-download{background:var(--theme); color:var(--primary); text-align:center; padding:20px; box-sizing:border-box}
#console-screen.face-download a{font-weight:600; border-bottom:1px solid currentColor}
#console-screen.face-download p{margin-top:10px; color:var(--secondary); font-size:.85em; font-family:Menlo,Consolas,monospace}

.console-indicator{
  text-align:center; background:var(--tertiary); border-radius:0 0 16px 16px;
  margin:-1px auto 0; padding:10px var(--gap) 14px; max-width:calc(var(--edge-size) * 2 + var(--embed-size));
}
.console-indicator .title{display:block; font-family:"Montserrat",sans-serif; font-weight:700; font-size:1.15em; color:var(--primary)}
.console-indicator .tagline{display:block; font-size:.85em; color:var(--secondary); font-style:italic; margin-top:2px}

@media (max-width:560px){
  :root{--embed-size:min(64vw,300px); --console-depth:50px; --edge-size:34px}
  .frame-btn{font-size:.65em}
  .frame-btn.left,.frame-btn.right{font-size:14px}
}

footer.footer{text-align:center; padding:var(--gap) 0}
</style>
</head>
<body class="list" id="top">
<script>
if (localStorage.getItem("pref-theme") === "dark") {
    document.body.classList.add('dark');
} else if (localStorage.getItem("pref-theme") === "light") {
    document.body.classList.remove('dark');
} else if (window.matchMedia('(prefers-color-scheme: dark)').matches) {
    document.body.classList.add('dark');
}
</script>
<header class="header">
    <nav class="nav">
        <div class="logo">
            <a href="https://warpedvisions.org/" accesskey="h" title="warpedvisions.org (Alt + H)">warpedvisions.org</a>
            <div class="logo-switches">
                <button id="theme-toggle" accesskey="t" title="(Alt + T)">
                    <svg id="moon" xmlns="http://www.w3.org/2000/svg" width="24" height="18" viewBox="0 0 24 24"
                        fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"
                        stroke-linejoin="round">
                        <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"></path>
                    </svg>
                    <svg id="sun" xmlns="http://www.w3.org/2000/svg" width="24" height="18" viewBox="0 0 24 24"
                        fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"
                        stroke-linejoin="round">
                        <circle cx="12" cy="12" r="5"></circle>
                        <line x1="12" y1="1" x2="12" y2="3"></line>
                        <line x1="12" y1="21" x2="12" y2="23"></line>
                        <line x1="4.22" y1="4.22" x2="5.64" y2="5.64"></line>
                        <line x1="18.36" y1="18.36" x2="19.78" y2="19.78"></line>
                        <line x1="1" y1="12" x2="3" y2="12"></line>
                        <line x1="21" y1="12" x2="23" y2="12"></line>
                        <line x1="4.22" y1="19.78" x2="5.64" y2="18.36"></line>
                        <line x1="18.36" y1="5.64" x2="19.78" y2="4.22"></line>
                    </svg>
                </button>
            </div>
            <p class="tagline"><a href="https://warpedvisions.org/">ESSAYS</a>, <a href="https://warpedvisions.org/food">RECIPES</a>, AND <a href="https://warpedvisions.org/projects">GENERAL MAKERY</a> BY <a href="https://warpedvisions.org/pages/about-bruce-alderson">BRUCE ALDERSON</a>.</p>
        </div>
        <ul id="menu"></ul>
    </nav>
</header>

<main class="main">
  <p class="jam-title">Warped 2026 Summer Game Jam</p>

  <div class="console-stage">
    <div class="console-frame">
      <button class="frame-btn top" id="prev-face" aria-label="Previous view"></button>
      <button class="frame-btn left" id="prev-game" aria-label="Previous game">&larr;</button>
      <div class="console-window">
        <div class="console" id="console">
          <div class="cube-face front"><div id="console-screen"></div></div>
          <div class="cube-face back"></div>
          <div class="cube-face top"></div>
          <div class="cube-face bottom"></div>
          <div class="cube-face left"></div>
          <div class="cube-face right"></div>
        </div>
      </div>
      <button class="frame-btn right" id="next-game" aria-label="Next game">&rarr;</button>
      <button class="frame-btn bottom" id="next-face" aria-label="Next view"></button>
    </div>
  </div>
  <p class="console-indicator" id="console-indicator"></p>
</main>

<footer class="footer">
    <span>&copy; 2026 <a href="https://warpedvisions.org/pages/about-warpedvisions-dot-org/">warpedvisions.org</a></span> ·
    <span><a href="https://mas.to/@robotpony">@robotpony mas.to</a></span> ·
    <span class="kudos">Powered by <a href="https://gohugo.io/" rel="noopener noreferrer" target="_blank">Hugo</a></span>
</footer>
<a href="#top" aria-label="go to top" title="Go to Top (Alt + G)" class="top-link" id="top-link" accesskey="g">
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 12 6" fill="currentColor">
        <path d="M12 6H0l6-6z" />
    </svg>
</a>

<script id="site-data" type="application/json">__DATA__</script>
<script src="theme/warped.js" defer></script>
<script>
const DATA = JSON.parse(document.getElementById('site-data').textContent);
const GAMES = DATA.games;
const FACES = ['play', 'download', 'about'];
const FACE_LABELS = {play: 'Play', download: 'Download', about: 'About'};

let gameIndex = 0;
let faceIndex = 0;
let busy = false;

function md(text){
  if(!text) return '';
  return window.marked ? window.marked.parse(text) : '<pre>' + text.replace(/</g,'&lt;') + '</pre>';
}

function defaultFaceIndex(game){
  return game.embedPath ? FACES.indexOf('play') : FACES.indexOf('about');
}

function playFaceHtml(game){
  if(game.embedPath){
    return `<iframe src="${game.embedPath}" loading="lazy" allow="autoplay"></iframe>`;
  }
  const hint = game.hasCart
    ? 'Cart exists, but no playable web export yet. Capture a label for this cart in Pico-8, then rerun generate.py.'
    : "Design is in progress — see the About tab.";
  return `<div class="placeholder"><strong>(GAME NOT READY)</strong>${hint}</div>`;
}

function downloadFaceHtml(game){
  if(!game.hasCart){
    return `<div class="placeholder">No cart yet.</div>`;
  }
  return `<div><a href="${game.cartRelPath}" download>Download ${game.num}.p8</a>
    <p>Load locally: <code>pico8 -run ${game.num}/${game.num}.p8</code></p></div>`;
}

function aboutFaceHtml(game){
  const sections = [
    ['SPEC', game.docs.readme],
    ['DESIGN', game.docs.design],
    ['PLAN', game.docs.plan],
    ['GUIDANCE', game.docs.claude],
  ].filter(([, text]) => text);
  if(!sections.length) return '<div class="placeholder">No docs yet.</div>';
  return sections.map(([label, text]) =>
    `<p class="doc-label">${label}</p>${md(text)}`).join('<hr>');
}

function faceHtml(game, face){
  if(face === 'play') return playFaceHtml(game);
  if(face === 'download') return downloadFaceHtml(game);
  return aboutFaceHtml(game);
}

function faceClass(face){
  return face === 'play' ? 'face-play' : (face === 'download' ? 'face-download' : 'face-about');
}

function render(){
  const game = GAMES[gameIndex];
  const face = FACES[faceIndex];
  const screen = document.getElementById('console-screen');
  screen.className = faceClass(face);
  screen.innerHTML = faceHtml(game, face);

  const upLabel = FACE_LABELS[FACES[(faceIndex - 1 + FACES.length) % FACES.length]];
  const downLabel = FACE_LABELS[FACES[(faceIndex + 1) % FACES.length]];
  document.getElementById('prev-face').textContent = '▲ ' + upLabel;
  document.getElementById('next-face').textContent = '▼ ' + downLabel;

  const indicator = document.getElementById('console-indicator');
  const title = game.title || `Game ${game.num}`;
  indicator.innerHTML = `<span class="title">${title}</span>` +
    (game.tagline ? `<span class="tagline">${game.tagline}</span>` : '');
}

function flip(axis, dir, updateFn){
  if(busy || GAMES.length === 0) return;
  busy = true;
  const cube = document.getElementById('console');
  const exitDeg = dir > 0 ? -90 : 90;
  const enterDeg = dir > 0 ? 90 : -90;
  const prop = axis === 'y' ? 'rotateY' : 'rotateX';

  // Pivot from the leading edge, not the box's own center: a center pivot on
  // a shallow box shrinks symmetrically toward the middle and reads as a
  // fade, not a turn. Hinging on the edge you're heading toward gives an
  // asymmetric swing (one edge anchored, the other sweeps) that reads
  // unambiguously as rotation.
  const origin = axis === 'y'
    ? (dir > 0 ? 'right center' : 'left center')
    : (dir > 0 ? 'center bottom' : 'center top');
  cube.style.transformOrigin = origin;

  cube.style.transition = 'transform .5s ease';
  cube.style.transform = `${prop}(${exitDeg}deg)`;

  const onExit = (e) => {
    if(e.propertyName !== 'transform') return;
    cube.removeEventListener('transitionend', onExit);
    updateFn();
    render();
    cube.style.transition = 'none';
    cube.style.transform = `${prop}(${enterDeg}deg)`;
    void cube.offsetWidth;
    cube.style.transition = 'transform .5s ease';
    cube.style.transform = 'none';
    setTimeout(() => { busy = false; }, 520);
  };
  cube.addEventListener('transitionend', onExit);
}

function nextGame(){
  flip('y', 1, () => { gameIndex = (gameIndex + 1) % GAMES.length; faceIndex = defaultFaceIndex(GAMES[gameIndex]); });
}
function prevGame(){
  flip('y', -1, () => { gameIndex = (gameIndex - 1 + GAMES.length) % GAMES.length; faceIndex = defaultFaceIndex(GAMES[gameIndex]); });
}
function nextFace(){ flip('x', 1, () => { faceIndex = (faceIndex + 1) % FACES.length; }); }
function prevFace(){ flip('x', -1, () => { faceIndex = (faceIndex - 1 + FACES.length) % FACES.length; }); }

document.addEventListener('DOMContentLoaded', () => {
  if(GAMES.length === 0){
    document.getElementById('console-indicator').textContent = 'No games in this repo yet.';
    return;
  }
  faceIndex = defaultFaceIndex(GAMES[gameIndex]);
  render();
  document.getElementById('next-game').addEventListener('click', nextGame);
  document.getElementById('prev-game').addEventListener('click', prevGame);
  document.getElementById('next-face').addEventListener('click', nextFace);
  document.getElementById('prev-face').addEventListener('click', prevFace);

  document.addEventListener('keydown', (e) => {
    if(e.key === 'ArrowRight') nextGame();
    else if(e.key === 'ArrowLeft') prevGame();
    else if(e.key === 'ArrowDown') nextFace();
    else if(e.key === 'ArrowUp') prevFace();
  });

  let touchStartX = null, touchStartY = null, touchOnScreen = false;
  const stage = document.querySelector('.console-stage');
  stage.addEventListener('touchstart', (e) => {
    touchStartX = e.touches[0].clientX;
    touchStartY = e.touches[0].clientY;
    touchOnScreen = !!e.target.closest('#console-screen');
  }, {passive: true});
  stage.addEventListener('touchend', (e) => {
    if(touchStartX === null) return;
    const dx = e.changedTouches[0].clientX - touchStartX;
    const dy = e.changedTouches[0].clientY - touchStartY;
    if(Math.abs(dx) > Math.abs(dy) && Math.abs(dx) > 40){
      dx < 0 ? nextGame() : prevGame();
    } else if(Math.abs(dy) > 40 && !touchOnScreen){
      // A vertical drag that started on the screen content (the About/
      // Download face) is a scroll attempt, not a face-nav swipe — only
      // treat drags starting on the frame/bezel as face navigation.
      dy < 0 ? nextFace() : prevFace();
    }
    touchStartX = null; touchStartY = null;
  }, {passive: true});

  const toggle = document.getElementById('theme-toggle');
  toggle.addEventListener('click', () => {
    if(document.body.classList.contains('dark')){
      document.body.classList.remove('dark');
      localStorage.setItem('pref-theme', 'light');
    } else {
      document.body.classList.add('dark');
      localStorage.setItem('pref-theme', 'dark');
    }
  });

  const topLink = document.getElementById('top-link');
  window.addEventListener('scroll', () => {
    const show = document.body.scrollTop > 400 || document.documentElement.scrollTop > 400;
    topLink.style.visibility = show ? 'visible' : 'hidden';
    topLink.style.opacity = show ? '1' : '0';
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
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@400;600;700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="../theme/reset.css">
<link rel="stylesheet" href="../theme/theme-vars.css">
<link rel="stylesheet" href="../theme/header.css">
<link rel="stylesheet" href="../theme/warped.css">
<script defer src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
<style>
.main{position:relative; max-width:calc(var(--main-width) + var(--gap) * 2); margin:auto; padding:var(--gap)}
.back-link{display:inline-block; margin-bottom:var(--gap); font-family:"Montserrat",sans-serif; font-weight:600; font-size:.8em; letter-spacing:.5px; color:var(--secondary)}
.game-title{font-family:"Montserrat",sans-serif; font-weight:700; font-size:1.4em; color:var(--primary); margin-bottom:2px}
.game-tagline{display:block; font-size:.9em; color:var(--secondary); font-style:italic; margin-bottom:var(--gap)}

.game-embed{
  width:100%; aspect-ratio:1 / 1; max-width:480px; margin:0 auto var(--gap);
  background:#000; border-radius:8px; overflow:hidden;
}
.game-embed iframe{width:100%; height:100%; border:0; display:block}
.game-embed .placeholder{
  color:#999; text-align:center; padding:20px; font-size:.85em;
  font-family:-apple-system,sans-serif; display:flex; flex-direction:column;
  justify-content:center; height:100%; box-sizing:border-box;
}
.game-embed .placeholder strong{display:block; font-size:1.2em; letter-spacing:1px; color:#eee; margin-bottom:6px; font-family:Menlo,Consolas,monospace}

.game-docs{
  background:#0b0f0c; color:#39ff6a; font-family:Menlo,Consolas,monospace; font-size:.8em;
  padding:16px; border-radius:8px; overflow-x:auto;
}
.game-docs a{color:#7dffb0}
.game-docs h1,.game-docs h2,.game-docs h3,.game-docs h4,.game-docs h5,.game-docs strong{
  color:#7dffb0; font-family:inherit;
}
.game-docs h1,.game-docs h2,.game-docs h3{
  font-size:1em; text-transform:uppercase; letter-spacing:1px; margin:1em 0 .3em;
}
.game-docs h1:first-child,.game-docs h2:first-child,.game-docs h3:first-child{margin-top:0}
.game-docs table{width:100%; border-collapse:collapse; font-size:.9em; margin:.6em 0}
.game-docs th,.game-docs td{border-bottom:1px solid #1e5c34; padding:3px 5px; text-align:left}
.game-docs .doc-label{
  color:#39ff6a; text-transform:uppercase; letter-spacing:2px; font-size:.9em; margin:1em 0 .3em; opacity:.8;
}
.game-docs .doc-label:first-child{margin-top:0}
.game-docs hr{border:0; border-top:1px dashed #1e5c34; margin:1em 0}
.game-docs pre{background:#06110a; padding:8px; border-radius:4px; overflow-x:auto}
.game-docs code{background:#06110a; padding:1px 4px; border-radius:3px}
.game-docs .placeholder{color:#2e8a52}

footer.footer{text-align:center; padding:var(--gap) 0}
</style>
</head>
<body class="list dark" id="top">
<script>
if (localStorage.getItem("pref-theme") === "light") {
    document.body.classList.remove('dark');
} else {
    document.body.classList.add('dark');
}
</script>
<header class="header">
    <nav class="nav">
        <div class="logo">
            <a href="https://warpedvisions.org/" accesskey="h" title="warpedvisions.org (Alt + H)">warpedvisions.org</a>
            <div class="logo-switches">
                <button id="theme-toggle" accesskey="t" title="(Alt + T)">
                    <svg id="moon" xmlns="http://www.w3.org/2000/svg" width="24" height="18" viewBox="0 0 24 24"
                        fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"
                        stroke-linejoin="round">
                        <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"></path>
                    </svg>
                    <svg id="sun" xmlns="http://www.w3.org/2000/svg" width="24" height="18" viewBox="0 0 24 24"
                        fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"
                        stroke-linejoin="round">
                        <circle cx="12" cy="12" r="5"></circle>
                        <line x1="12" y1="1" x2="12" y2="3"></line>
                        <line x1="12" y1="21" x2="12" y2="23"></line>
                        <line x1="4.22" y1="4.22" x2="5.64" y2="5.64"></line>
                        <line x1="18.36" y1="18.36" x2="19.78" y2="19.78"></line>
                        <line x1="1" y1="12" x2="3" y2="12"></line>
                        <line x1="21" y1="12" x2="23" y2="12"></line>
                        <line x1="4.22" y1="19.78" x2="5.64" y2="18.36"></line>
                        <line x1="18.36" y1="5.64" x2="19.78" y2="4.22"></line>
                    </svg>
                </button>
            </div>
            <p class="tagline"><a href="https://warpedvisions.org/">ESSAYS</a>, <a href="https://warpedvisions.org/food">RECIPES</a>, AND <a href="https://warpedvisions.org/projects">GENERAL MAKERY</a> BY <a href="https://warpedvisions.org/pages/about-bruce-alderson">BRUCE ALDERSON</a>.</p>
        </div>
        <ul id="menu"></ul>
    </nav>
</header>

<main class="main">
  <a class="back-link" href="../index.html">&larr; All games</a>
  <h1 class="game-title" id="game-title"></h1>
  <span class="game-tagline" id="game-tagline"></span>

  <div class="game-embed" id="game-embed"></div>
  <div class="game-docs" id="game-docs"></div>
</main>

<footer class="footer">
    <span>&copy; 2026 <a href="https://warpedvisions.org/pages/about-warpedvisions-dot-org/">warpedvisions.org</a></span> ·
    <span><a href="https://mas.to/@robotpony">@robotpony mas.to</a></span> ·
    <span class="kudos">Powered by <a href="https://gohugo.io/" rel="noopener noreferrer" target="_blank">Hugo</a></span>
</footer>
<a href="#top" aria-label="go to top" title="Go to Top (Alt + G)" class="top-link" id="top-link" accesskey="g">
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 12 6" fill="currentColor">
        <path d="M12 6H0l6-6z" />
    </svg>
</a>

<script id="site-data" type="application/json">__DATA__</script>
<script src="../theme/warped.js" defer></script>
<script>
const GAME = JSON.parse(document.getElementById('site-data').textContent).game;

function md(text){
  if(!text) return '';
  return window.marked ? window.marked.parse(text) : '<pre>' + text.replace(/</g,'&lt;') + '</pre>';
}

document.addEventListener('DOMContentLoaded', () => {
  document.getElementById('game-title').textContent = GAME.title || `Game ${GAME.num}`;
  const tagline = document.getElementById('game-tagline');
  if(GAME.tagline){ tagline.textContent = GAME.tagline; } else { tagline.remove(); }

  const embed = document.getElementById('game-embed');
  if(GAME.embedPath){
    embed.innerHTML = `<iframe src="../${GAME.embedPath}" loading="lazy" allow="autoplay"></iframe>`;
  } else {
    const hint = GAME.hasCart
      ? 'Cart exists, but no playable web export yet.'
      : 'Design is in progress.';
    embed.innerHTML = `<div class="placeholder"><strong>(GAME NOT READY)</strong>${hint}</div>`;
  }

  const sections = [
    ['SPEC', GAME.docs.readme],
    ['DESIGN', GAME.docs.design],
  ].filter(([, text]) => text);
  const docs = document.getElementById('game-docs');
  docs.innerHTML = sections.length
    ? sections.map(([label, text]) => `<p class="doc-label">${label}</p>${md(text)}`).join('<hr>')
    : '<div class="placeholder">No docs yet.</div>';

  const toggle = document.getElementById('theme-toggle');
  toggle.addEventListener('click', () => {
    if(document.body.classList.contains('dark')){
      document.body.classList.remove('dark');
      localStorage.setItem('pref-theme', 'light');
    } else {
      document.body.classList.add('dark');
      localStorage.setItem('pref-theme', 'dark');
    }
  });

  const topLink = document.getElementById('top-link');
  window.addEventListener('scroll', () => {
    const show = document.body.scrollTop > 400 || document.documentElement.scrollTop > 400;
    topLink.style.visibility = show ? 'visible' : 'hidden';
    topLink.style.opacity = show ? '1' : '0';
  });
});
</script>
</body>
</html>
"""

if __name__ == "__main__":
    main()
