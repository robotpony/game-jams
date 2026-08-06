#!/usr/bin/env python3
"""Generates preview/index.html from the game jam repo's game folders.

Scans numbered game folders (1/, 2/, 3/, ...) and templates a single
self-contained preview/index.html: a grid of Techie-style flip tiles, one
per game. A tile's front face is informational (title, tagline, status)
plus a live embed of the built cart; its back face links out to that
game's README/DESIGN on GitHub and its downloadable cart, rather than
rendering any of those documents inline.

A game folder is either single-platform (flat: <n>/<n>.p8 or <n>/<n>.tic
directly in the game folder) or multi-platform (a <n>/pico-8/ and/or
<n>/tic-80/ subfolder, each with its own cart/DESIGN.md/PLAN.md/CLAUDE.md
per SPEC-FORMAT.md's platform layout). Either way, collect_game() produces
one or more "builds" per game; a tile with more than one build gets a
small platform tab switcher on its embed instead of a single iframe.

The page uses Warped's "Techie" dev-tool visual system, vendored into
preview/theme/ from ~/projects/warped/visual-style-next/techie/ (styles.css
+ Fira Code). This is a deliberately different, all-dark register from the
warpedvisions.org blog theme, not an approximation of it.

For a Pico-8 build, runs `pico8 -x <cart>.p8 -export "<num>.html"` if the
cart has a captured label but no export yet, writing into
preview/exports/<num>/pico-8/. Carts without a label are skipped with a
note (Pico-8 refuses to export until a label has been captured in-editor).
Before handing the cart to pico8, a comment-stripped copy is generated via
tools/export/strip_comments.py and exported instead of the real cart file:
Pico-8's export path compresses the raw __lua__ text (comments included)
into a fixed-capacity slot separate from the 8,192 token limit, and this
project's carts carry heavy inline documentation comments dense enough to
blow that cap even when well under the token limit (see 6/CLAUDE.md's
Status line for the game that first hit this). The stripped copy is a
build artifact written into preview/exports/<num>/pico-8/, not a change
to the real cart.

For a TIC-80 build, runs `tic80 --cli --cmd "load ... & export html ..."`
for any cart with no export yet, writing into preview/exports/<num>/tic-80/.
TIC-80 has no label concept, so export isn't gated on one. Its export is a
zip (index.html + tic80.js + tic80.wasm + cart.tic, not one self-contained
HTML file like Pico-8's); ensure_export_tic80() unzips it into place. See
tools/tic80.md for the underlying CLI workflow this wraps.

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
import sys
import tempfile
import zipfile
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
ROOT = SCRIPT_DIR.parent
EXPORTS_DIR = SCRIPT_DIR / "exports"

# Platforms this page knows how to find a cart and export a web build for,
# in the fixed order tabs/rows should show them. Adding a platform means
# adding an entry here plus its own ensure_export_<platform>() function;
# an unrecognized subfolder name under a game dir is silently ignored
# rather than crashing the whole scan.
PLATFORM_INFO = {
    "pico-8": {"label": "Pico-8", "ext": "p8"},
    "tic-80": {"label": "TIC-80", "ext": "tic"},
}
PLATFORM_ORDER = list(PLATFORM_INFO.keys())

sys.path.insert(0, str(ROOT / "tools" / "export"))
import strip_comments  # noqa: E402 (needs sys.path set up first)
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


def step(msg: str, indent: int = 1):
    """Prints a small, cute progress note for a sub-step within a bigger
    milestone (see the bare `print()` calls for milestones themselves)."""
    print(f"{'   ' * indent}↳ {msg}")


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


def find_tic80() -> str | None:
    """Locates the tic80 binary. Same alias problem as pico8 (see
    find_pico8) — `tic80` is aliased in this project's dev shell, not on
    PATH as a resolvable executable. Override with the TIC80_PATH env var
    if needed."""
    if env_path := os.environ.get("TIC80_PATH"):
        return env_path
    if which := shutil.which("tic80"):
        return which
    candidate = Path.home() / "tools/TIC-80/build/bin/tic80"
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


def ensure_export_pico8(num: str, cart_path: Path) -> tuple[str | None, str]:
    """Runs pico8's headless HTML export if a label exists and no export yet.
    Returns (embed_path, status) where embed_path is the relative path (from
    preview/) if an export is or becomes available, else None, and status
    explains why when it isn't. Always writes under exports/<num>/pico-8/,
    even for a single-platform game, so every build's output lives at a
    predictable, platform-qualified path.
    """
    out_dir = EXPORTS_DIR / num / "pico-8"
    out_html = out_dir / f"{num}.html"
    if out_html.exists():
        step(f"already has a web export, reusing it")
        return f"exports/{num}/pico-8/{num}.html", "ok"
    if not cart_path.exists():
        step(f"no cart yet, still cooking in the design oven")
        return None, "no cart"
    if not has_label(cart_path):
        step(f"cart found but unlabeled, pico8 won't export it yet")
        return None, "no label captured yet"
    pico8 = find_pico8()
    if not pico8:
        step(f"cart is ready but no pico8 binary found, set PICO8_PATH")
        return None, "pico8 binary not found (set PICO8_PATH)"
    out_dir.mkdir(parents=True, exist_ok=True)

    # Export a comment-stripped copy, not cart_path directly: Pico-8's
    # export path fails "code too large" once compressed __lua__ text
    # (comments included) exceeds its fixed capacity, independent of the
    # token count. See strip_comments.py's module docstring.
    export_source = cart_path
    stripped_path = out_dir / f"{num}.stripped.p8"
    try:
        stats = strip_comments.strip_cart_file(cart_path, stripped_path)
        saved = stats["lua_bytes_before"] - stats["lua_bytes_after"]
        if saved > 0:
            step(f"stripped {saved:,} bytes of comments for export (dev cart untouched)")
            export_source = stripped_path
    except OSError as e:
        step(f"comment-strip step failed, exporting the real cart as-is: {e}")

    step(f"popping cart {num} into pico8 for a web export...")
    try:
        result = subprocess.run(
            [pico8, "-x", export_source.name, "-export", str(out_html.resolve())],
            cwd=export_source.parent,
            capture_output=True,
            text=True,
            timeout=60,
        )
    except (subprocess.SubprocessError, OSError) as e:
        step(f"export blew a fuse: {e}")
        return None, f"export failed to run ({e})"
    if out_html.exists():
        step(f"export complete, {num} is now playable in-browser")
        return f"exports/{num}/pico-8/{num}.html", "ok"
    detail = (result.stderr or result.stdout or "").strip().splitlines()
    step(f"export ran but no file showed up, that's odd")
    return None, f"export ran but produced no file ({detail[-1] if detail else 'no output'})"


def ensure_export_tic80(num: str, cart_path: Path) -> tuple[str | None, str]:
    """Runs tic80's headless HTML export if no export exists yet. Returns
    (embed_path, status) the same shape as ensure_export_pico8(). TIC-80 has
    no label concept, so unlike Pico-8 there's nothing to gate export on
    besides the cart existing.

    tic80's `export html` writes a zip (index.html + tic80.js + tic80.wasm
    + cart.tic), not one self-contained file — see tools/tic80.md's Web
    export section. `--fs` sandboxes tic80 to one folder for both the cart
    it loads and the zip it writes, so the cart is staged into a scratch
    temp dir first rather than pointed at cart_path's real folder directly
    (avoids tic80 writing its export artifact next to the dev cart).
    """
    out_dir = EXPORTS_DIR / num / "tic-80"
    out_html = out_dir / "index.html"
    if out_html.exists():
        step(f"already has a web export, reusing it")
        return f"exports/{num}/tic-80/index.html", "ok"
    if not cart_path.exists():
        step(f"no cart yet, still cooking in the design oven")
        return None, "no cart"
    tic80 = find_tic80()
    if not tic80:
        step(f"cart is ready but no tic80 binary found, set TIC80_PATH")
        return None, "tic80 binary not found (set TIC80_PATH)"

    step(f"popping cart {num} into tic80 for a web export...")
    try:
        with tempfile.TemporaryDirectory(prefix="tic80-export-") as staging:
            staging_path = Path(staging)
            staged_cart = staging_path / cart_path.name
            shutil.copy2(cart_path, staged_cart)
            result = subprocess.run(
                [
                    tic80, f"--fs={staging_path}", "--cli",
                    "--cmd", f"load {cart_path.name} & export html out & exit",
                ],
                capture_output=True,
                text=True,
                timeout=60,
            )
            zip_path = staging_path / "out.zip"
            if not zip_path.exists():
                detail = (result.stderr or result.stdout or "").strip().splitlines()
                step(f"export ran but no zip showed up, that's odd")
                return None, f"export ran but produced no file ({detail[-1] if detail else 'no output'})"
            out_dir.mkdir(parents=True, exist_ok=True)
            with zipfile.ZipFile(zip_path) as zf:
                zf.extractall(out_dir)
    except (subprocess.SubprocessError, OSError, zipfile.BadZipFile) as e:
        step(f"export blew a fuse: {e}")
        return None, f"export failed to run ({e})"

    if out_html.exists():
        step(f"export complete, {num} is now playable in-browser")
        return f"exports/{num}/tic-80/index.html", "ok"
    step(f"zip extracted but no index.html inside, that's odd")
    return None, "export produced a zip with no index.html"


def stage_download(num: str, cart_path: Path, suffix: str = "") -> str | None:
    """Copies the cart into preview/downloads/ so the page works when
    preview/ is deployed on its own, without its sibling game folders.
    `suffix` (e.g. "-pico-8") disambiguates a game with more than one
    platform build; a single-build game keeps its plain <num>.<ext> name
    to avoid renaming every existing download link for no reason."""
    if not cart_path.exists():
        return None
    DOWNLOADS_DIR.mkdir(parents=True, exist_ok=True)
    dest_name = f"{num}{suffix}{cart_path.suffix}"
    dest = DOWNLOADS_DIR / dest_name
    shutil.copy2(cart_path, dest)
    step(f"tucked a download copy into downloads/{dest_name}")
    return f"downloads/{dest_name}"


def collect_build(num: str, platform: str, build_dir: Path, is_multi: bool, github_base: str | None) -> dict:
    """Collects one platform build's data: cart, export, and DESIGN.md link.
    build_dir is the folder that actually holds this build's files — the
    game folder itself for a flat single-platform game, or a pico-8/tic-80
    subfolder for a multi-platform one. `is_multi` controls filename
    suffixing (stage_download) and label prefixing (the JS templates use
    platformLabel directly, so this only affects downloads/ naming here)."""
    info = PLATFORM_INFO[platform]
    cart_path = build_dir / f"{num}.{info['ext']}"
    step(f"[{info['label']}] cart: {'found' if cart_path.exists() else 'not built yet'}")
    if platform == "pico-8":
        embed_path, embed_status = ensure_export_pico8(num, cart_path)
    elif platform == "tic-80":
        embed_path, embed_status = ensure_export_tic80(num, cart_path)
    else:  # pragma: no cover — PLATFORM_INFO only lists platforms with a
        # matching ensure_export_* above; new entries need one added here.
        embed_path, embed_status = None, "no exporter wired up for this platform"
    has_design = (build_dir / "DESIGN.md").exists()
    dir_rel = build_dir.relative_to(ROOT).as_posix()
    suffix = f"-{platform}" if is_multi else ""
    return {
        "platform": platform,
        "platformLabel": info["label"],
        "dirRel": dir_rel,
        "hasCart": cart_path.exists(),
        "cartFileName": cart_path.name,
        "cartRelPath": stage_download(num, cart_path, suffix),
        "embedPath": embed_path,
        "embedStatus": embed_status,
        "designUrl": f"{github_base}/blob/{GITHUB_REF}/{dir_rel}/DESIGN.md" if (github_base and has_design) else None,
        "hasDesign": has_design,
    }


def find_build_specs(dir_: Path, num: str) -> list[tuple[str, Path]]:
    """Returns [(platform, build_dir), ...] for a game folder: one entry per
    pico-8/tic-80 subfolder that exists (the multi-platform layout
    SPEC-FORMAT.md defines once a game gets a second platform), or, if
    neither subfolder exists, a single flat-layout entry inferred from
    whichever cart extension (.p8 or .tic) is sitting directly in dir_. A
    game with no cart at all yet (spec-only, not built) still gets one
    entry — assumed pico-8, the jam's default — so it shows up as "not
    built" rather than vanishing from the page."""
    subdirs = [p for p in PLATFORM_ORDER if (dir_ / p).is_dir()]
    if subdirs:
        return [(p, dir_ / p) for p in subdirs]
    for platform, info in PLATFORM_INFO.items():
        if (dir_ / f"{num}.{info['ext']}").exists():
            return [(platform, dir_)]
    return [("pico-8", dir_)]


def collect_game(dir_: Path, github_base: str | None) -> dict:
    num = dir_.name
    print(f"🔍 peeking into {num}/ ...")
    readme = read(dir_ / "README.md")
    title = extract_title(readme or "")
    if readme:
        step(f'found README.md — "{title or "(untitled)"}"')
    else:
        step("no README.md yet, shrug emoji")

    build_specs = find_build_specs(dir_, num)
    is_multi = len(build_specs) > 1
    if is_multi:
        step(f"multi-platform: {', '.join(p for p, _ in build_specs)}")
    builds = [collect_build(num, platform, build_dir, is_multi, github_base) for platform, build_dir in build_specs]

    return {
        "num": num,
        "title": title,
        "tagline": extract_tagline(readme or ""),
        "builds": builds,
        "readmeUrl": f"{github_base}/blob/{GITHUB_REF}/{num}/README.md" if github_base else None,
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
    print("🚀 prepping the preview for launch...")
    if not SFTP_ENABLED:
        print("😴 sftp publishing is disabled (set SFTP_ENABLED = True in generate.py)")
        return
    if not SFTP_HOST or not SFTP_REMOTE_PATH:
        print("🤔 SFTP_HOST and SFTP_REMOTE_PATH must be set in generate.py")
        return

    index_path = SCRIPT_DIR / "index.html"
    if not index_path.is_file():
        print(f"📭 nothing to publish, {index_path} does not exist yet (run 'python3 generate.py' first)")
        return

    target = f"{SFTP_USER}@{SFTP_HOST}" if SFTP_USER else SFTP_HOST

    # index.html is a single file; theme/, downloads/, exports/, games/ are
    # directories. One recursive put per top-level item, all landing
    # directly in remote_path, rather than a single `put -r` on preview/
    # itself (which would nest everything one level deeper, under an extra
    # preview/ subdirectory on the remote). Only existing items are queued —
    # downloads/exports/games won't exist yet on a repo with no built carts.
    print("📦 packing the crate...")
    step("index.html")
    batch_lines = [f"put {index_path} {SFTP_REMOTE_PATH}"]
    for item in ("theme", "downloads", "exports", "games"):
        local_dir = SCRIPT_DIR / item
        if local_dir.is_dir():
            step(f"{item}/")
            batch_lines.append(f"put -r {local_dir} {SFTP_REMOTE_PATH}")
    batch = "\n".join(batch_lines) + "\n"

    print(f"🛰️  beaming everything up to {target}:{SFTP_REMOTE_PATH} ...")
    try:
        out = subprocess.run(
            ["sftp", "-P", str(SFTP_PORT), "-b", "-", target],
            input=batch, capture_output=True, text=True, timeout=120,
        )
    except (OSError, subprocess.SubprocessError) as e:
        print(f"💥 sftp publish failed: {e}")
        return

    if out.returncode != 0:
        print(f"💔 sftp publish failed: {out.stderr.strip() or out.stdout.strip()}")
    else:
        print(f"🎉 published! preview/ is now live at {target}:{SFTP_REMOTE_PATH}")


def generate():
    print("🎲 waking up the game jam preview generator...")
    print("🗂️  scanning the repo for numbered game folders...")
    game_dirs = sorted(
        (d for d in ROOT.iterdir() if d.is_dir() and d.name.isdigit()),
        key=lambda d: int(d.name),
    )
    if game_dirs:
        found = ", ".join(f"{d.name}/" for d in game_dirs)
        step(f"found {len(game_dirs)} folder(s): {found}", indent=1)
    else:
        step("found none, awfully quiet in here", indent=1)

    print("🔗 sniffing out the GitHub remote for doc links...")
    github_base = github_repo_url()
    step(f"resolved: {github_base}" if github_base else "no remote configured, falling back to plain paths")

    print("🎮 touring each game folder...")
    games = [collect_game(d, github_base) for d in game_dirs]

    print("📖 reading the root README for the page intro...")
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

    print("🧵 weaving the tile grid into index.html...")
    repo_nav = f'<a href="{github_base}">repo</a>' if github_base else ""
    html = TEMPLATE.replace("__DATA__", json_blob).replace("__REPO_NAV__", repo_nav)
    (SCRIPT_DIR / "index.html").write_text(html, encoding="utf-8")
    step("saved preview/index.html")

    print("📄 stamping out a standalone page per game...")
    for g in games:
        write_game_page(g)
        step(f"games/{g['num']}.html ready")

    all_builds = [b for g in games for b in g["builds"]]
    built = sum(1 for b in all_builds if b["hasCart"])
    embedded = sum(1 for b in all_builds if b["embedPath"])
    print(f"\n🏁 all done! {len(games)} game(s), {len(all_builds)} build(s) total, {built} built, {embedded} with a live embed to play.")
    if not github_base:
        print("   ⚠️  no GitHub origin remote resolved — readme/design back-rows show local paths, not links")
    for g in games:
        for b in g["builds"]:
            if b["hasCart"] and not b["embedPath"]:
                print(f"   ⚠️  game {g['num']} [{b['platformLabel']}]: cart exists but no live embed — {b['embedStatus']}")


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
  display: flex;
  flex-direction: column;
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

/* Platform switcher for a tile/page with more than one build. Sits above
   the embed; clicking a tab must not also trigger the tile's own
   click-anywhere-to-flip handler (see the JS delegate's stopPropagation). */
.platform-tabs {
  display: flex; gap: 1px; background: var(--border);
  border-bottom: 1px solid var(--border);
}
.platform-tab {
  flex: 1; font: inherit; font-size: 0.72rem; letter-spacing: 0.04em; text-transform: uppercase;
  background: var(--brown-950); color: var(--tan); border: 0; padding: var(--space-2);
  cursor: pointer;
}
.platform-tab.active { background: var(--brown-900, var(--brown-950)); color: var(--mustard); }
.platform-panels { position: relative; flex: 1; }
.platform-panel { display: none; height: 100%; }
.platform-panel.active { display: block; }
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

function buildEmbedInner(build){
  if(build.embedPath){
    return `<iframe src="${build.embedPath}" loading="lazy" allow="autoplay" scrolling="no"></iframe>`;
  }
  const hint = build.hasCart
    ? 'cart exists, no playable web export yet'
    : 'design in progress';
  return `<div class="placeholder"><strong>not ready</strong>${hint}</div>`;
}

// One build: just its embed, no switcher needed. More than one: a small
// tab strip above stacked panels, one per platform, first tab active.
// Tab clicks are handled by a delegated listener (see DOMContentLoaded
// below) since tiles are rendered from a template string, not built as
// DOM nodes with individual listeners attached.
function embedHtml(game){
  if(game.builds.length === 1){
    return buildEmbedInner(game.builds[0]);
  }
  const tabs = game.builds.map((b, i) =>
    `<button type="button" class="platform-tab${i === 0 ? ' active' : ''}" data-idx="${i}">${b.platformLabel}</button>`
  ).join('');
  const panels = game.builds.map((b, i) =>
    `<div class="platform-panel${i === 0 ? ' active' : ''}" data-idx="${i}">${buildEmbedInner(b)}</div>`
  ).join('');
  return `<div class="platform-tabs" role="tablist">${tabs}</div><div class="platform-panels">${panels}</div>`;
}

function backRows(game){
  const rows = [];
  rows.push(`<div class="back-row"><span class="k">readme</span><span class="v">${
    game.readmeUrl ? `<a href="${game.readmeUrl}">${game.num}/README.md</a>` : `${game.num}/README.md`
  }</span></div>`);
  const multi = game.builds.length > 1;
  game.builds.forEach(build => {
    const prefix = multi ? `${build.platformLabel.toLowerCase()} ` : '';
    if(build.designUrl){
      rows.push(`<div class="back-row"><span class="k">${prefix}design</span><span class="v"><a href="${build.designUrl}">${build.dirRel}/DESIGN.md</a></span></div>`);
    }
    rows.push(`<div class="back-row"><span class="k">${prefix}download</span><span class="v">${
      build.cartRelPath ? `<a href="${build.cartRelPath}">${build.cartFileName}</a>` : 'not built yet'
    }</span></div>`);
  });
  return rows.join('');
}

function overallStatus(game){
  if(game.builds.some(b => b.embedPath)) return { status: 'built', live: true };
  if(game.builds.some(b => b.hasCart)) return { status: 'not ready', live: false };
  return { status: 'not built', live: false };
}

function tileHtml(game){
  const { status, live } = overallStatus(game);
  const liveClass = live ? ' is-live' : '';
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

// Switches the active tab/panel pair within whichever .tile-embed the
// click happened in. stopPropagation is required: a platform-tab lives
// inside .tile-front, and .tile-flip's own click listener (attached below)
// toggles the flip on any click within the card, tab or not.
function handlePlatformTabClick(e){
  const tab = e.target.closest('.platform-tab');
  if(!tab) return;
  e.stopPropagation();
  const embed = tab.closest('.tile-embed, .game-embed');
  if(!embed) return;
  const idx = tab.dataset.idx;
  embed.querySelectorAll('.platform-tab').forEach(t => t.classList.toggle('active', t.dataset.idx === idx));
  embed.querySelectorAll('.platform-panel').forEach(p => p.classList.toggle('active', p.dataset.idx === idx));
}

document.addEventListener('DOMContentLoaded', () => {
  document.getElementById('readme-intro-wrap').innerHTML = readmeIntroHtml();
  const container = document.getElementById('tiles');
  if(GAMES.length === 0){
    container.innerHTML = '<p class="meta-text">No games in this repo yet.</p>';
    return;
  }
  container.innerHTML = GAMES.map(tileHtml).join('');
  container.addEventListener('click', handlePlatformTabClick);
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
  display: flex; flex-direction: column;
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
/* Platform switcher, same pattern as index.html's tile grid (see that
   TEMPLATE's own copy of these rules for the full rationale) — duplicated
   here rather than shared since this page has its own <style> block. */
.platform-tabs {
  display: flex; gap: 1px; background: var(--border);
  border-bottom: 1px solid var(--border);
}
.platform-tab {
  flex: 1; font: inherit; font-size: 0.72rem; letter-spacing: 0.04em; text-transform: uppercase;
  background: var(--brown-950); color: var(--tan); border: 0; padding: var(--space-2);
  cursor: pointer;
}
.platform-tab.active { background: var(--brown-900, var(--brown-950)); color: var(--mustard); }
.platform-panels { position: relative; flex: 1; }
.platform-panel { display: none; height: 100%; }
.platform-panel.active { display: block; }
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

function buildEmbedInner(build){
  if(build.embedPath){
    return `<iframe src="../${build.embedPath}" loading="lazy" allow="autoplay" scrolling="no"></iframe>`;
  }
  const hint = build.hasCart ? 'cart exists, no playable web export yet' : 'design in progress';
  return `<div class="placeholder"><strong>not ready</strong>${hint}</div>`;
}

const embed = document.getElementById('game-embed');
if(GAME.builds.length === 1){
  embed.innerHTML = buildEmbedInner(GAME.builds[0]);
} else {
  const tabs = GAME.builds.map((b, i) =>
    `<button type="button" class="platform-tab${i === 0 ? ' active' : ''}" data-idx="${i}">${b.platformLabel}</button>`
  ).join('');
  const panels = GAME.builds.map((b, i) =>
    `<div class="platform-panel${i === 0 ? ' active' : ''}" data-idx="${i}">${buildEmbedInner(b)}</div>`
  ).join('');
  embed.innerHTML = `<div class="platform-tabs" role="tablist">${tabs}</div><div class="platform-panels">${panels}</div>`;
  embed.addEventListener('click', function(e){
    const tab = e.target.closest('.platform-tab');
    if(!tab) return;
    const idx = tab.dataset.idx;
    embed.querySelectorAll('.platform-tab').forEach(t => t.classList.toggle('active', t.dataset.idx === idx));
    embed.querySelectorAll('.platform-panel').forEach(p => p.classList.toggle('active', p.dataset.idx === idx));
  });
}

const rows = [];
rows.push(`<div class="back-row"><span class="k">readme</span><span class="v">${
  GAME.readmeUrl ? `<a href="${GAME.readmeUrl}">${GAME.num}/README.md</a>` : `${GAME.num}/README.md`
}</span></div>`);
const multi = GAME.builds.length > 1;
GAME.builds.forEach(build => {
  const prefix = multi ? `${build.platformLabel.toLowerCase()} ` : '';
  if(build.designUrl){
    rows.push(`<div class="back-row"><span class="k">${prefix}design</span><span class="v"><a href="${build.designUrl}">${build.dirRel}/DESIGN.md</a></span></div>`);
  }
  rows.push(`<div class="back-row"><span class="k">${prefix}download</span><span class="v">${
    build.cartRelPath ? `<a href="../${build.cartRelPath}">${build.cartFileName}</a>` : 'not built yet'
  }</span></div>`);
});
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
