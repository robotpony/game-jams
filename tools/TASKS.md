# Tasks

Tooling improvements identified after the first Pico-8 game session.

---

## 1. Build a Pico-8 game spec template

A fill-in-the-blank template that forces resolution of every ambiguous dimension before any code is written. Prevents two-round Q&A and missing-spec problems.

- [ ] Create `pico8-spec-template.md`
- [ ] Required fields: playfield dimensions, HUD layout, game states + transitions, tile type IDs, sprite slot assignments, SFX slot assignments, control mapping, palette choices
- [ ] Optional fields: score system, timer behaviour, level seeding

---

## 2. Build an SFX notation utility

A script that converts human-readable note descriptions into valid Pico-8 `__sfx__` hex lines. Eliminates hand-authoring risk.

- [ ] Input format: note pitch, wave, volume, effect per step, plus speed
- [ ] Output: a valid 168-char `__sfx__` line
- [ ] Verify output against a known-good `.p8` file (use `1/1.p8` as reference)
- [ ] Place in `sfx/`

---

## 3. Build a `/pico8` skill

Encodes Pico-8 knowledge so future sessions don't have to rediscover it.

- [ ] `__sfx__` and `__gfx__` format with worked examples
- [ ] Token counting heuristics and short-name conventions
- [ ] Standard state machine pattern for multi-screen games
- [ ] Lua dialect notes: no `string.format`, `tostr()` vs `tostring()`, `add()` for tables
- [ ] Link to the spec template from task 1
