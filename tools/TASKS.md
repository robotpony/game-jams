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

---

## 4. Build a `/tic80` skill

Encodes TIC-80 knowledge so future sessions don't have to rediscover it, mirroring task 3's `/pico8` skill. Started once game 4 got a TIC-80 upscale folder ([`../4/tic-80/`](../4/tic-80/)).

First draft landed as [`tic80.md`](tic80.md): spec, RAM/VRAM layout, cart format, CLI workflow, and Lua dialect/API notes, all verified against the local build's own binary output and source (`help spec`/`help ram`/`help vram`, `src/api/luaapi.c`, `src/api.h`) rather than general familiarity. Thinner than `pico8.md` on purpose: there's no TIC-80 game built yet to draw a real playtesting pipeline or pitfalls list from, and inventing either ahead of a real pain point is exactly what `pico8.md` didn't do.

- [x] Spec/constraints table — see `tic80.md`'s [Spec](tic80.md#spec)
- [x] RAM/VRAM memory layout — see `tic80.md`'s [RAM layout](tic80.md#ram-layout-96kb-total) and [VRAM layout](tic80.md#vram-layout-16kb)
- [x] Cart format and CLI workflow (external `.lua` source + `import code`, since `.tic` is binary, unlike Pico-8's plain-text `.p8`) — see `tic80.md`'s [Cart format](tic80.md#cart-format) and [CLI workflow](tic80.md#cli-workflow)
- [x] Lua dialect/API notes, including the traps that bite when porting from Pico-8 (`circ`/`circb` naming inversion, `spr()`'s unified scale/flip/rotate signature, no `pal()` equivalent) — see `tic80.md`'s [Lua dialect & API notes](tic80.md#lua-dialect--api-notes)
- [ ] Playtesting technique (accessibility-driven live play, mirroring `pico8.md`'s pipeline) — can't write this honestly until `4/tic-80` has a real cart to test against
- [x] A generalized pitfalls list, mirroring `pico8.md`'s — seeded, see `tic80.md`'s [Known pitfalls](tic80.md#known-pitfalls), drawn from task 5's CLI-scripting bug history (confirm dialogs hanging non-interactive `--cmd` chains, `run` never returning control, palette-index-0 export transparency). Still thin (four entries from one debugging session, not six games' worth) — keep adding as more TIC-80 work happens, don't treat it as finished
- [ ] Package the above as an actual skill (`.claude/skills/tic80/`), same open item as task 3's Pico-8 equivalent

---

## 5. Build TIC-80 asset tooling

Encodes TIC-80 asset generation, mirroring tasks 1–2's Pico-8 `sprites/`/`sfx/` tools. Started because [`../4/tic-80/PLAN.md`](../4/tic-80/PLAN.md)'s Phase 0b (palette mapping, sprite roster) can't be decided honestly without knowing what's scriptable vs. hand-authored-only — see that file's Phase 0a.

- [x] Verify the `pal()`-equivalent `poke4()` convention against `tic_vram`'s palette-map offset (`03FF0`, 8 bytes) — confirmed against this build's own source rather than a screenshot; see [`tic80.md`](tic80.md)'s Lua dialect & API notes for the formula (`poke4(32736 + c0, c1)`) and derivation. A live GUI smoke-test is still worth doing by hand before shipping (this session's sandbox can't run TIC-80's blocking event loop headlessly to screenshot it), but the math no longer blocks anything
- [x] Sprite sheet tool: `tools/tic80/sprite_tool.py`, same hex-grid def format as the Pico-8 tool (`preview`/`sheet`/`ascii`/`generate` reused near-verbatim), but `patch`/`patch-all`/`dump` delegate to the local `tic80` binary's own `import`/`export` console commands instead of hex-splicing (`.tic` is binary, unlike `.p8`), addressed per-bank (`tiles`/`sprites`, 0-255 each). Verified end to end: repeated single `patch` calls, a multi-entry `patch-all` manifest across both banks, and a `dump` round-trip, all confirmed by diffing raw PNG pixel bytes against a pre-patch export, not just a visual skim.
  - One real bug found, root-caused, and fixed during that verification, worth knowing if this tool's approach gets reused elsewhere: `save`-ing to any filename that already exists on disk — including an empty placeholder `tempfile.NamedTemporaryFile` itself creates just to reserve a unique name — hits a blocking "overwrite?" confirmation with no non-interactive answer. Fixed by generating temp save-target names (`uuid4`) that deliberately never touch disk before `save` runs. Documented inline at `save_cart`, and now also in [`tic80.md`](tic80.md)'s Known pitfalls section.
  - A second cause (inherited stdin) was suspected first, "fixed" with `stdin=subprocess.DEVNULL`, and only looked confirmed because the one test of it happened to also dodge the real bug above. A proper A/B (6/6 clean without the stdin fix once the real bug was gone; 3/3 hung with the stdin fix but the real bug reintroduced) disproved it. Left in `run_tic80` anyway since it's free, but documented as unconfirmed rather than as a fix — worth remembering as a reminder to A/B a hang theory before trusting it, not just re-test once after changing one thing.
  - Palette caveat carried into the tool's docstrings rather than resolved: colours a def file "means" (indices into the Pico-8 PALETTE table reused as a placeholder) won't match what a cart actually shows until [`../4/tic-80/PLAN.md`](../4/tic-80/PLAN.md)'s Phase 0b locks the real TIC-80 palette; import nearest-matches against TIC-80's own current palette, not Pico-8's.
- [ ] SFX/music tool, if time allows: TIC-80's tracker-style format is a different encoding than Pico-8's `__sfx__` hex lines (see [`tic80.md`](tic80.md)'s RAM layout for the SFX/music-pattern/music-track byte ranges), not a reuse of `sfx/sfx_tool.py`'s encoder
- [x] Place in `tools/tic80/`, mirroring `sprites/`'s and `sfx/`'s folder shape (`defs/`, `manifests/` created; no defs committed yet since none of Phase 0b's real sprite roster exists to author)
