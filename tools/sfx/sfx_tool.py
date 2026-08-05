#!/usr/bin/env python3
"""Author and patch Pico-8 SFX without the in-editor tracker.

An SFX def is a plain-text file: an optional `speed:`/`loop:` header line,
then one note per line as `pitch wave vol fx` (numbers or names, see
WAVES/EFFECTS below). See sfx_tool.py --help for subcommands.

Format verified against real authored data in this repo's own carts
(1/1.p8, 3/3.p8, 4/4.p8, 5/5.p8), not just the Pico-8 manual's prose
description -- `selftest` re-derives that verification on demand rather
than relying on a one-time manual check. No third-party dependencies.
"""
import argparse
import sys
from pathlib import Path

# Standard Pico-8 SFX waveforms/effects (one hex digit each in the note
# encoding). Names are accepted in def files as a readability aid; numbers
# always work too.
WAVES = {
    "triangle": 0, "tiltedsaw": 1, "saw": 2, "square": 3,
    "pulse": 4, "organ": 5, "noise": 6, "phaser": 7,
}
EFFECTS = {
    "none": 0, "slide": 1, "vibrato": 2, "drop": 3,
    "fadein": 4, "fadeout": 5, "arpfast": 6, "arpslow": 7,
}
NOTE_NAMES = "c c# d d# e f f# g g# a a# b".split()


def note_name_to_pitch(s):
    """'c2' -> 24 etc, per pico-8's pitch 0-63 spanning ~5 octaves from c0."""
    s = s.lower().strip()
    for i in range(len(s), 0, -1):
        name, octstr = s[:i], s[i:]
        if octstr.isdigit() and name in NOTE_NAMES:
            return NOTE_NAMES.index(name) + int(octstr) * 12
    raise ValueError(f"not a note name: {s!r}")


def parse_field(tok, table):
    tok = tok.strip().lower()
    if tok in table:
        return table[tok]
    return int(tok)


def parse_pitch(tok):
    tok = tok.strip()
    if tok[0].isdigit() or (tok[0] == "-" and tok[1:].isdigit()):
        return int(tok)
    return note_name_to_pitch(tok)


def load_def(path):
    """Returns (speed, loop_start, loop_end, notes) -- notes is a list of
    (pitch, wave, vol, fx) tuples, length 0-32 (caller pads to 32)."""
    speed, loop = 8, (0, 0)
    notes = []
    for raw in Path(path).read_text().splitlines():
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        if line.lower().startswith("speed:"):
            speed = int(line.split(":", 1)[1].strip())
            continue
        if line.lower().startswith("loop:"):
            a, b = line.split(":", 1)[1].split()
            loop = (int(a), int(b))
            continue
        parts = line.split()
        if len(parts) != 4:
            raise ValueError(f"{path}: expected 'pitch wave vol fx', got {raw!r}")
        pitch = parse_pitch(parts[0])
        wave = parse_field(parts[1], WAVES)
        vol = int(parts[2])  # no names for volume, just 0-7
        fx = parse_field(parts[3], EFFECTS)
        if not (0 <= pitch <= 63):
            raise ValueError(f"{path}: pitch {pitch} out of range 0-63")
        if not (0 <= wave <= 7):
            raise ValueError(f"{path}: wave {wave} out of range 0-7")
        if not (0 <= vol <= 7):
            raise ValueError(f"{path}: vol {vol} out of range 0-7")
        if not (0 <= fx <= 7):
            raise ValueError(f"{path}: fx {fx} out of range 0-7")
        notes.append((pitch, wave, vol, fx))
    if len(notes) > 32:
        raise ValueError(f"{path}: {len(notes)} notes, max 32")
    return speed, loop[0], loop[1], notes


def encode_note(pitch, wave, vol, fx):
    return f"{pitch:02x}{wave:01x}{vol:01x}{fx:01x}"


def encode_header(speed, loop_start=0, loop_end=0, mode=0):
    return f"{mode:02x}{speed:02x}{loop_start:02x}{loop_end:02x}"


def encode_sfx(speed, notes, loop_start=0, loop_end=0):
    """notes: list of up to 32 (pitch,wave,vol,fx) tuples. Returns the
    168-char __sfx__ line (8-char header + 32x5-char notes, silence-padded)."""
    padded = list(notes) + [(0, 0, 0, 0)] * (32 - len(notes))
    line = encode_header(speed, loop_start, loop_end) + "".join(encode_note(*n) for n in padded)
    assert len(line) == 168, f"internal error: got {len(line)} chars, want 168"
    return line


def decode_sfx(line):
    """Inverse of encode_sfx, for inspection and the selftest round-trip."""
    line = line.strip()
    if len(line) != 168:
        raise ValueError(f"expected a 168-char __sfx__ line, got {len(line)} chars")
    mode = int(line[0:2], 16)
    speed = int(line[2:4], 16)
    loop_start = int(line[4:6], 16)
    loop_end = int(line[6:8], 16)
    notes = []
    for i in range(32):
        chunk = line[8 + i * 5: 13 + i * 5]
        notes.append((int(chunk[0:2], 16), int(chunk[2], 16), int(chunk[3], 16), int(chunk[4], 16)))
    return {"mode": mode, "speed": speed, "loop_start": loop_start, "loop_end": loop_end, "notes": notes}


def cmd_encode(args):
    speed, loop_start, loop_end, notes = load_def(args.sfxdef)
    print(encode_sfx(speed, notes, loop_start, loop_end))


def cmd_decode(args):
    cart = Path(args.cart)
    lines = cart.read_text().split("\n")
    sfx_start = lines.index("__sfx__") + 1
    line = lines[sfx_start + args.slot]
    d = decode_sfx(line)
    print(f"speed={d['speed']} loop={d['loop_start']}-{d['loop_end']}")
    for i, (p, w, v, f) in enumerate(d["notes"]):
        if (p, w, v, f) == (0, 0, 0, 0) and all(n == (0, 0, 0, 0) for n in d["notes"][i:]):
            break
        print(f"  {i:2d}: pitch={p:2d} wave={w} vol={v} fx={f}")


def sfx_start_line(lines):
    """Return the line index of __sfx__'s first data row, inserting a blank
    section (in canonical position) first if the cart doesn't have one yet.
    Canonical order (tools/CLAUDE.md): __lua__ __gfx__ __label__ __map__
    __sfx__ __music__ -- must go after __map__ (or __gfx__/__label__ if
    __map__ is absent) and before __music__, or Pico-8 silently drops it
    on next save."""
    try:
        return lines.index("__sfx__") + 1
    except ValueError:
        insert_at = len(lines)
        for marker in ("__music__",):
            if marker in lines:
                insert_at = lines.index(marker)
                break
        blank_row = "0" * 168
        sfx_block = ["__sfx__"] + [blank_row] * 64
        lines[insert_at:insert_at] = sfx_block
        return insert_at + 1


def apply_patch(lines, sfxdef_path, slot):
    speed, loop_start, loop_end, notes = load_def(sfxdef_path)
    line = encode_sfx(speed, notes, loop_start, loop_end)
    sfx_start = sfx_start_line(lines)
    lines[sfx_start + slot] = line


def cmd_patch(args):
    cart = Path(args.cart)
    lines = cart.read_text().split("\n")
    apply_patch(lines, args.sfxdef, args.slot)
    cart.write_text("\n".join(lines))
    print(f"patched sfx slot {args.slot} into {args.cart}")


def cmd_patch_all(args):
    """Batch-patch many SFX into a cart from a manifest file.

    Manifest format: one `slot path` pair per line (whitespace-separated),
    `#` starts a comment, blank lines ignored. Loads and saves the cart once
    regardless of manifest size, same convention as sprite_tool.py's
    patch-all."""
    cart = Path(args.cart)
    lines = cart.read_text().split("\n")
    count = 0
    for lineno, raw in enumerate(Path(args.manifest).read_text().splitlines(), 1):
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        parts = line.split(None, 1)
        if len(parts) != 2:
            raise ValueError(f"{args.manifest}:{lineno}: expected 'slot path', got {raw!r}")
        slot_str, sfxdef_path = parts
        apply_patch(lines, sfxdef_path.strip(), int(slot_str))
        count += 1
    cart.write_text("\n".join(lines))
    print(f"patched {count} sfx into {args.cart} from {args.manifest}")


# (cart, line-index-within-sfx-section, expected notes) fixtures hand-decoded
# from this repo's own real, already-composed carts -- not invented data.
# Proves the encoder/decoder pair matches what real Pico-8-authored SFX
# actually look like, which is the strongest check available without
# being able to listen to the output (see 6/PLAN.md's SFX addendum for why
# that mattered here).
SELFTEST_FIXTURES = [
    ("1/1.p8", 0, "000a0000" + "24350" + "21340" + "1f330" + "1c310" + "0" * 140),
    ("3/3.p8", 4, "00060000" + "14675" + "0" * 155),
    ("4/4.p8", 0, "00040000" + "30253" + "0" * 155),
]


def cmd_selftest(args):
    repo_root = Path(__file__).resolve().parents[2]
    failures = 0
    for cart_rel, slot, expected_line in SELFTEST_FIXTURES:
        cart = repo_root / cart_rel
        if not cart.exists():
            print(f"SKIP {cart_rel}: not found")
            continue
        lines = cart.read_text().split("\n")
        sfx_start = lines.index("__sfx__") + 1
        actual_line = lines[sfx_start + slot]
        ok_raw = actual_line == expected_line
        d = decode_sfx(actual_line)
        reencoded = encode_sfx(d["speed"], d["notes"], d["loop_start"], d["loop_end"])
        ok_roundtrip = reencoded == actual_line
        status = "PASS" if (ok_raw and ok_roundtrip) else "FAIL"
        if status == "FAIL":
            failures += 1
        print(f"{status} {cart_rel} slot {slot}: fixture-match={ok_raw} round-trip={ok_roundtrip}")
    if failures:
        print(f"{failures} failure(s)")
        sys.exit(1)
    print("all selftests passed")


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)

    en = sub.add_parser("encode", help="print a def file's 168-char __sfx__ line")
    en.add_argument("sfxdef", help="path to an sfx def text file")
    en.set_defaults(func=cmd_encode)

    de = sub.add_parser("decode", help="print a cart's sfx slot in human-readable form")
    de.add_argument("cart", help="path to the .p8 cartridge file")
    de.add_argument("slot", type=int, help="sfx slot, 0-63")
    de.set_defaults(func=cmd_decode)

    pa = sub.add_parser("patch", help="write an sfx def into a cart's __sfx__ section")
    pa.add_argument("cart", help="path to the .p8 cartridge file")
    pa.add_argument("sfxdef", help="path to an sfx def text file")
    pa.add_argument("slot", type=int, help="sfx slot, 0-63")
    pa.set_defaults(func=cmd_patch)

    pall = sub.add_parser("patch-all", help="batch-patch many sfx into a cart from a manifest")
    pall.add_argument("cart", help="path to the .p8 cartridge file")
    pall.add_argument("manifest", help="text file of 'slot path' lines, # comments allowed")
    pall.set_defaults(func=cmd_patch_all)

    st = sub.add_parser("selftest", help="verify the encoder/decoder against real authored carts")
    st.set_defaults(func=cmd_selftest)

    args = p.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
