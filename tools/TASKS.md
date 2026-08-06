# Tasks

Tooling improvements identified after the first Pico-8 game session.

---

## 1. Build a Pico-8 game spec template — done, see [`../SPEC-FORMAT.md`](../SPEC-FORMAT.md)

A fill-in-the-blank template that forces resolution of every ambiguous dimension before any code is written. Prevents two-round Q&A and missing-spec problems.

- [x] Create the spec format doc — landed at repo root as `SPEC-FORMAT.md` rather than `pico8-spec-template.md`, since it governs the whole README/DESIGN/PLAN/CLAUDE document set, not just README
- [x] Required fields: game states + transitions (Scenes in README, State machine in DESIGN), tile type IDs and palette choices (Tile/sprite visuals, DESIGN's Palette section)
- [x] Optional fields: score system, timer behaviour, level seeding (Player, Progression sections)
- [ ] Playfield dimensions, sprite slot assignments, SFX slot assignments, and control mapping aren't yet broken out as their own required DESIGN.md fields; fold in if they turn out to need more structure than the current Screen layout / Core system design sections give them

---

## 2. Build an SFX notation utility

A script that converts human-readable note descriptions into valid Pico-8 `__sfx__` hex lines. Eliminates hand-authoring risk.

- [x] Input format: note pitch, wave, volume, effect per step, plus speed — `sfx_tool.py`'s def-file format (`speed:`/`loop:` header lines, then one `pitch wave vol fx` per note; wave/effect accept either the numeric 0-7 or a name like `square`/`slide`)
- [x] Output: a valid 168-char `__sfx__` line — `encode_sfx()`, asserted at generation time
- [x] Verify output against a known-good `.p8` file (use `1/1.p8` as reference) — `selftest` subcommand: hand-decoded fixtures from `1/1.p8`, `3/3.p8`, and `4/4.p8` (not just `1/1.p8` alone), checked both against the real line and via encode-decode-reencode round-trip
- [x] Place in `sfx/` — `tools/sfx/sfx_tool.py`, `tools/sfx/defs/`, `tools/sfx/manifests/`, mirroring `sprites/`'s layout and `patch`/`patch-all` CLI shape

Used for real on game 6: all 16 events in `6/README.md`'s Sound table (`tools/sfx/defs/g6_*.txt`, `tools/sfx/manifests/g6.txt`), including two that explicitly echo/mirror another game's existing sound (`g6_book_find.txt` decodes `2/2.p8` slot 6, `g6_player_death.txt` decodes `3/3.p8` slot 10) rather than composing a from-scratch guess at "sounds similar." Built this way specifically because nothing in this pipeline can listen to the output to verify it — see `6/PLAN.md`'s SFX addendum for the reasoning; a human still needs to actually hear these in Pico-8 before calling the sound design itself correct, only the *encoding* is self-verified here.

---

## 3. Build a `/pico8` skill

Encodes Pico-8 knowledge so future sessions don't have to rediscover it.

First draft landed as [`pico8.md`](pico8.md): workflow overview, tool/lib reference, token vs. export budgeting, Lua dialect notes, state machine convention, the accessibility-driven playtest pipeline, and a generalized pitfalls list drawn from `BUGS.md`. That covers the content below in doc form; packaging it as an actual `/pico8` skill is still open.

- [x] Token counting heuristics and short-name conventions — see `pico8.md`'s [Two different size limits](pico8.md#two-different-size-limits)
- [x] Standard state machine pattern for multi-screen games — see `pico8.md`'s [State machine convention](pico8.md#state-machine-convention)
- [x] Lua dialect notes: no `string.format`, `tostr()` vs `tostring()`, `add()` for tables — see `pico8.md`'s [Lua dialect notes](pico8.md#lua-dialect-notes)
- [x] Link to the spec template from task 1 — see `pico8.md`'s [Related](pico8.md#related)
- [ ] `__sfx__` and `__gfx__` format with worked examples — still only in `tools/CLAUDE.md`'s data-format reference, no worked examples yet
- [ ] Package the above as an actual skill (`.claude/skills/pico8/`), not just a reference doc
