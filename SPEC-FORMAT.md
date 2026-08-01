# Spec format

This defines the document set and section structure for each game in this repo. It exists so any folder is predictable: an agent or collaborator can open any numbered game folder and know where to find the player-facing spec, the technical design, the build checklist, and the current architecture.

The pattern below is written up from game 3, which established it in practice before it was documented. [Adoption](#adoption) covers how games 1 and 2 fit in.

## Document set

Each game folder (`1/`, `2/`, `3/`, ...) holds four documents, each with a distinct audience and lifecycle.

| Document | Answers | Audience | Written |
| -------- | ------- | -------- | ------- |
| README.md | What is this game? | Player, reviewer, collaborator | Before implementation; stays fixed once gameplay is locked |
| DESIGN.md | How is it built, pixel by pixel? | Implementer, human or agent | Before implementation; superseded once the cart exists |
| PLAN.md | What's done, what's left? | Implementer | Alongside implementation; updated as phases complete |
| CLAUDE.md | What are the constraints, and what did we actually build? | Claude Code, working in this folder | Constraints written before implementation; an Architecture section is added once a `.p8` cart exists |

### Document lifecycle

DESIGN.md is a pre-implementation document. Once a cart exists, the Architecture section in CLAUDE.md is the source of truth for how the game actually works. At that point DESIGN.md is either deleted or kept as historical context and marked superseded at the top. Don't maintain both in parallel once the cart exists; that's how they drift.

CLAUDE.md always exists, even pre-build. Early on it holds Pico-8 constraints and a "not yet built" status note. Once the cart exists, it grows an Architecture section (see [`1/CLAUDE.md`](1/CLAUDE.md) for a worked example).

## README.md

Open with the game's name, its genre in half a sentence, and a one-line aesthetic note. Every game in this project targets an Atari-2600-via-Pico-8 look, but say so anyway; it's what makes the palette and sprite choices legible to a reader who hasn't seen the game run.

Required sections, in order:

1. **Game overview** — one to three paragraphs, prose. What does a player do, moment to moment.
2. **Scenes** — a table naming every screen or scene, what it shows, and what moves the player to the next one. This is the storyboard; see [Scenes format](#scenes-format) below.
3. **Core mechanic(s)** — the system that makes the game what it is (maze generation, elevator plus rooms, falling items). Rename the header to the actual mechanic name.
4. **Player** — movement, resources (HP, score, inventory), and any state that carries across scenes or levels.
5. **Game over conditions** — bullet list. Include win conditions here too if the game has them; don't split those into a separate section.
6. **Sound** — table or list of events that need sound. Doesn't need note-level detail (that belongs in DESIGN.md); name the trigger and the character of the sound ("percussive," "ascending melodic run").
7. **Tile / sprite visuals** — table: tile or sprite, colour (name and Pico-8 index), visual description.

Sections required only when relevant:

- **Items** — table: item, effect, visual feedback. Omit the whole section if the game has no discrete pickups; don't leave an empty template row.
- **Progression** — level seeding, difficulty ramp, wave scaling. Omit if the game is a single fixed round.

**Open questions** — include whenever a section above can't be filled in with a real decision yet. Name the specific unknown (a number, a rule, a visual choice), not a restated placeholder. A README with unresolved sections should say so here rather than ship a bracket like `[Item]` in the body.

### Scenes format

| Scene | Shows | Enters from | Exits to |
| ----- | ----- | ------------ | -------- |
| Title | Game name, start prompt | Startup | Any button → Game |
| Game | Playfield, HUD | Title, or retry from End | Win/lose condition → End |
| End | Result, final stats | Game | Any button → Title |

Add a row for every distinct scene, including transitional ones (a level-transition flicker, a fade between rooms) if they're visible to the player for more than a frame or two. Name the trigger, not just the destination: "score < 0" is more useful than "Game over."

## DESIGN.md

Pre-implementation technical design. Required sections:

- **Screen layout** — an ASCII pixel-layout sketch per scene that has meaningful structure (skip the title screen if it's just centred text). Use indentation, not box-drawing characters; annotate the y-range or x-range of each region. See [`3/DESIGN.md`](3/DESIGN.md) for the pattern.
- **Palette** — table: element, colour name, Pico-8 index.
- **State machine** — table: state id, name, entered from, exits to. This is the README's Scenes table translated into the `gs` values the code will actually use.
- **Core system design** — whatever the central mechanic needs: generation algorithm, collision rules, spawn tables, tuning constants.

Required when the game has one:

- **Difficulty ramp / win condition** — the formula or rule, not just "gets harder."

Recommended:

- **Token budget** — a note on what's likely to be expensive (state count, table sizes) and what to lean on `lib/` for instead of rederiving.

## PLAN.md

A phased checklist. Each phase is a header with checkbox items; end each phase with one `Verify:` item describing how to confirm it worked, marked manual if it needs a play test. Follow [`1/PLAN.md`](1/PLAN.md) or [`3/PLAN.md`](3/PLAN.md) as worked examples.

## CLAUDE.md

Required sections, in order:

1. **Project** — one line: game name, genre, aesthetic, link to README.md. If no cart exists yet, say so plainly ("Status: not yet built") rather than letting an empty Architecture section imply otherwise.
2. **Development** — the Pico-8 workflow (no build system; `pico8 -run <n>.p8`, or load plus Ctrl+R).
3. **Pico-8 constraints** — token limit, display, sprites, map, sound, Lua variant gaps. These don't change game to game; copy from an existing game's CLAUDE.md.
4. **Architecture** (once built) — key systems, state table, SFX slot table, state variables. This is the as-built version of DESIGN.md; write it by reading the finished cart, not by copying DESIGN.md unchanged.
5. **Reusable code** — pointer to [`../lib/CLAUDE.md`](lib/CLAUDE.md).

## Formatting conventions

- Tables for anything with more than two parallel attributes (items, tiles, sound events, states). Prose for everything else.
- No bracket placeholders in committed files (`[Item]`, `[Effect]`). Either fill it in or move the gap to Open Questions.
- Filenames are `README.md` and `CLAUDE.md`, uppercase, consistent across every folder.
- Numbers over words for anything a reader might need to check against the code: frame counts, pixel coordinates, colour indices.

## Adoption

Game 3 already follows this format; it's where the pattern came from.

Game 1 shipped before DESIGN.md existed as a convention. It doesn't get one backfilled: the architecture that would go in it already lives in CLAUDE.md's Architecture section, and reconstructing a "pre-implementation" document after the fact would just be a copy with the tenses changed.

Game 2 predates the four-document split entirely. Its README has been restructured to this format; DESIGN.md, PLAN.md, and CLAUDE.md are new, and unresolved design details are called out in the README's Open Questions rather than invented. Unlike game 1, game 2's DESIGN.md is deliberately kept updated alongside CLAUDE.md's Architecture section rather than marked superseded, a second, explicit exception to the [document lifecycle](#document-lifecycle) rule above: DESIGN.md's own preamble says why (it tracks design decisions; CLAUDE.md's Architecture section carries the line-level as-built detail), so don't treat the two as drifting duplicates or "fix" it by deleting one.

## Related

- [`BUGS.md`](BUGS.md) — a root-level, cross-game bug tracker for implementation bugs and build-vs-spec mismatches found by reading a cart's source. Distinct from a README's Open Questions: Open Questions are pre-implementation design gaps, BUGS.md entries are things the shipped code gets wrong relative to README.md/DESIGN.md.
- [`tools/TASKS.md`](tools/TASKS.md) — this document fulfills task 1, originally scoped there as `pico8-spec-template.md`.
- [`lib/CLAUDE.md`](lib/CLAUDE.md) — shared Lua snippets; check before writing a game's Core system design from scratch.
- [`tools/CLAUDE.md`](tools/CLAUDE.md) — asset-generation scripts and the Pico-8 data format reference (`__gfx__`, `__map__`, `__sfx__`, `__music__`), useful when filling in DESIGN.md's palette and sprite sections.
