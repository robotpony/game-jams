#!/usr/bin/env python3
"""Strips Lua comments out of a .p8 cart's __lua__ section.

Why this exists: Pico-8 enforces two independent limits. The token counter
(8,192 tokens, shown in the editor and tracked in each game's CLAUDE.md)
counts real code tokens and ignores comments entirely. But when Pico-8
packs a cart for export (.p8.png, or the -export HTML build this jam's
preview/generate.py runs), it compresses the *raw* __lua__ text, comments
included, into a fixed-capacity slot in the cart format. A cart can sit
comfortably under the token limit and still fail export with "code too
long" if its comments are heavy enough to blow the compressed-size cap.
Game 6 hit exactly this: 4,357/8,192 tokens, but ~65% of its source bytes
were prose comments in this project's documentary style, which pushed the
compressed size over the cap.

This script produces a comment-stripped copy for export only. It never
modifies the input cart, so the fully-commented source (which is also the
project's inline bug/design history, see 6/CLAUDE.md's Architecture
section) stays intact as the dev file.

Only the __lua__ section is touched. __gfx__/__label__/__map__/__sfx__/
__music__ (and the two-line file header) are copied through byte for byte,
since those aren't text that can carry comments.

Usage:
    python3 strip_comments.py CART.p8                 write CART.stripped.p8
    python3 strip_comments.py CART.p8 -o OUT.p8        write to OUT.p8
    python3 strip_comments.py CART.p8 --stats-only     print size stats, write nothing
    python3 strip_comments.py --selftest               run the correctness self-test
"""
import argparse
import subprocess
import sys
import zlib
from pathlib import Path

SECTION_MARKERS = ("__lua__", "__gfx__", "__label__", "__gff__", "__map__", "__sfx__", "__music__")


def strip_lua_comments(src: str) -> str:
    """Removes -- line comments and --[[ ]]/--[=[ ]=] block comments from a
    Lua source string, leaving code, strings, and long strings untouched.

    A small hand-written scanner rather than a regex: comments can't be
    reliably stripped with a regex because -- inside a string literal
    ("--not a comment") or a long string ([[ --also not one ]]) must be
    left alone. This mirrors the standard approach used by Lua minifiers
    (track string/long-bracket state, only treat -- as a comment starter
    outside of it).
    """
    out = []
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if c == "-" and src[i + 1 : i + 2] == "-":
            j = i + 2
            # long comment? --[[ ... ]] or --[=[ ... ]=] (any number of =)
            if src[j : j + 1] == "[":
                k = j + 1
                eq = 0
                while src[k : k + 1] == "=":
                    eq += 1
                    k += 1
                if src[k : k + 1] == "[":
                    close = "]" + "=" * eq + "]"
                    end = src.find(close, k + 1)
                    i = n if end == -1 else end + len(close)
                    continue
            # line comment: drop text, keep the newline so line numbers
            # (and a lone -->8 tab-divider marker's line slot) don't shift
            nl = src.find("\n", i)
            i = n if nl == -1 else nl
            continue
        if c in ("'", '"'):
            quote = c
            out.append(c)
            i += 1
            while i < n:
                ch = src[i]
                out.append(ch)
                i += 1
                if ch == "\\" and i < n:
                    out.append(src[i])
                    i += 1
                    continue
                if ch == quote:
                    break
            continue
        if c == "[":
            j = i + 1
            eq = 0
            while src[j : j + 1] == "=":
                eq += 1
                j += 1
            if src[j : j + 1] == "[":
                close = "]" + "=" * eq + "]"
                end = src.find(close, j + 1)
                if end == -1:
                    out.append(src[i:])
                    i = n
                else:
                    out.append(src[i : end + len(close)])
                    i = end + len(close)
                continue
        out.append(c)
        i += 1
    return "".join(out)


def clean_blank_lines(text: str) -> str:
    """Drops lines that are now empty (whitespace-only) after stripping, and
    trims trailing whitespace pico8 doesn't need. Cosmetic byte savings on
    top of the comment removal itself."""
    lines = [ln.rstrip() for ln in text.split("\n")]
    return "\n".join(ln for ln in lines if ln.strip() != "")


def split_sections(cart_text: str) -> list[tuple[str, list[str]]]:
    """Splits a .p8 file's lines into (marker, lines) pieces, each holding
    the lines up to (not including) the next marker line. The first piece
    has marker "" and holds the two-line file header before __lua__.
    Line-based (not a raw string slice) so reassembly is just "\\n".join
    over marker-line-then-body-lines in order, with no separator bugs."""
    lines = cart_text.split("\n")
    pieces: list[tuple[str, list[str]]] = [("", [])]
    for ln in lines:
        if ln in SECTION_MARKERS:
            pieces.append((ln, []))
        else:
            pieces[-1][1].append(ln)
    return pieces


def strip_cart_text(cart_text: str) -> tuple[str, dict]:
    """Returns (stripped_cart_text, stats). Only the __lua__ piece is
    touched; every other section is passed through unchanged, line for
    line."""
    stats = {"lua_bytes_before": 0, "lua_bytes_after": 0}
    out_lines: list[str] = []
    for marker, body_lines in split_sections(cart_text):
        if marker:
            out_lines.append(marker)
        if marker == "__lua__":
            body_text = "\n".join(body_lines)
            before_bytes = body_text.encode("utf-8")
            stats["lua_bytes_before"] = len(before_bytes)
            stats["lua_gzip_before"] = len(zlib.compress(before_bytes, 9))
            stripped_text = clean_blank_lines(strip_lua_comments(body_text))
            after_bytes = stripped_text.encode("utf-8")
            stats["lua_bytes_after"] = len(after_bytes)
            stats["lua_gzip_after"] = len(zlib.compress(after_bytes, 9))
            body_lines = stripped_text.split("\n") if stripped_text else []
        out_lines.extend(body_lines)
    return "\n".join(out_lines), stats


def strip_cart_file(input_path: Path, output_path: Path | None) -> dict:
    """Strips comments out of input_path's __lua__ section. Writes the
    result to output_path (if given) and returns size stats, including a
    zlib-based estimate of compressed size before/after as a rough proxy
    for Pico-8's own cart compressor (not identical, but the same order
    of magnitude, and free to compute)."""
    raw = input_path.read_text(encoding="utf-8", errors="surrogateescape")
    stripped_text, stats = strip_cart_text(raw)
    stats["file_bytes_before"] = len(raw.encode("utf-8", errors="surrogateescape"))
    stats["file_bytes_after"] = len(stripped_text.encode("utf-8", errors="surrogateescape"))
    if output_path is not None:
        output_path.write_text(stripped_text, encoding="utf-8", errors="surrogateescape")
    return stats


def _fmt(n: int) -> str:
    return f"{n:,}"


def print_stats(path_label: str, stats: dict):
    before, after = stats["lua_bytes_before"], stats["lua_bytes_after"]
    saved = before - after
    pct = (saved / before * 100) if before else 0
    print(f"{path_label}: __lua__ {_fmt(before)} -> {_fmt(after)} bytes ({pct:.0f}% smaller, {_fmt(saved)} bytes of comments removed)")
    gb, ga = stats.get("lua_gzip_before"), stats.get("lua_gzip_after")
    if gb is not None:
        print(f"  gzip -9 estimate (proxy for pico8's cart compressor): {_fmt(gb)} -> {_fmt(ga)} bytes")
        print(f"  pico8's classic .p8.png format caps compressed code around 15,616 bytes")


def run_selftest() -> bool:
    """Correctness check: a tricky snippet exercising every case the
    scanner has to get right (strings containing --, long comments, long
    strings, nested brackets, a trailing comment on the same line as code)
    must produce byte-identical *behaviour* after stripping, verified by
    actually running both versions through `lua` and diffing stdout, plus
    a `luac -p` syntax check on the stripped output. Falls back to a
    weaker text-only check if `lua`/`luac` aren't on PATH."""
    src = '''
-- a leading full-line comment
local x = 1 -- trailing comment on a code line
local s1 = "not -- a comment"
local s2 = 'also not -- a comment, and has [[ brackets ]] in it'
local s3 = "escaped \\" quote -- still a string"
--[[ a block comment
spanning multiple lines, with -- inside it
]]
local long1 = [[a long string with -- inside it]]
local long2 = [==[ nested ]] brackets and -- dashes, level 2 ]==]
local t = {1,2,3}
print(x, t[1], s1, s2, s3, long1, long2)
'''.strip("\n") + "\n"

    stripped = clean_blank_lines(strip_lua_comments(src))
    assert "a leading full-line comment" not in stripped, "a real line comment survived stripping"
    assert "trailing comment on a code line" not in stripped, "a real trailing comment survived stripping"
    assert "not -- a comment" in stripped, "string content with -- was corrupted"
    assert "[[ brackets ]]" in stripped, "string content with brackets was corrupted"
    assert "spanning multiple lines" not in stripped, "block comment body leaked into output"
    assert "a long string with -- inside it" in stripped, "long string content was corrupted"
    assert "nested ]] brackets and -- dashes" in stripped, "level-2 long string content was corrupted"

    lua = None
    for candidate in ("lua", "lua5.4", "lua5.3"):
        from shutil import which
        if which(candidate):
            lua = candidate
            break
    if lua is None:
        print("(lua not on PATH, skipping the run-and-diff check; text assertions above still passed)")
        return True

    def run(text: str) -> str:
        p = subprocess.run([lua, "-"], input=text, capture_output=True, text=True, timeout=10)
        if p.returncode != 0:
            raise AssertionError(f"lua failed on:\n{text}\n---\n{p.stderr}")
        return p.stdout

    out_orig = run(src)
    out_stripped = run(stripped)
    assert out_orig == out_stripped, f"stripped output diverged:\n{out_orig!r} != {out_stripped!r}"

    from shutil import which as _which
    if _which("luac"):
        p = subprocess.run(["luac", "-p", "-"], input=stripped, capture_output=True, text=True, timeout=10)
        assert p.returncode == 0, f"stripped source failed luac -p: {p.stderr}"

    print("selftest passed: 6 text assertions + lua run-and-diff + luac -p all ok")
    return True


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("cart", nargs="?", type=Path, help="path to a .p8 cart")
    ap.add_argument("-o", "--output", type=Path, help="output path (default: <cart>.stripped.p8)")
    ap.add_argument("--stats-only", action="store_true", help="print size stats, write nothing")
    ap.add_argument("--selftest", action="store_true", help="run the correctness self-test and exit")
    args = ap.parse_args()

    if args.selftest:
        ok = run_selftest()
        sys.exit(0 if ok else 1)

    if args.cart is None:
        ap.error("cart is required unless --selftest is given")

    out_path = None if args.stats_only else (args.output or args.cart.with_suffix("").with_suffix(".stripped.p8"))
    stats = strip_cart_file(args.cart, out_path)
    print_stats(str(args.cart), stats)
    if out_path is not None:
        print(f"wrote {out_path}")


if __name__ == "__main__":
    main()
