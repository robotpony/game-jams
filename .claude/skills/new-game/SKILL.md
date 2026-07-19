---
name: new-game
description: "Scaffold the base README.md, DESIGN.md, PLAN.md, and CLAUDE.md for a new game folder in this jam repo, following SPEC-FORMAT.md. Trigger when the user says 'new game', 'scaffold a game', 'start game N', 'add a game folder', or asks to set up a new entry for the jam."
allowed-tools: "Read, Glob, Bash, Write, Edit, AskUserQuestion"
---

# /new-game — Scaffold a new game folder

Creates the four documents [`SPEC-FORMAT.md`](../../../SPEC-FORMAT.md) requires for a new game entry (`README.md`, `DESIGN.md`, `PLAN.md`, `CLAUDE.md`), pre-populated with what's actually known and an Open Questions section for what isn't. Doesn't invent game design: `2/README.md`, `2/DESIGN.md`, `2/PLAN.md`, and `2/CLAUDE.md` are the reference for what "honestly incomplete" scaffolding looks like, as opposed to a bracket-placeholder template.

## 0. Read the format first

Read `SPEC-FORMAT.md` at the repo root before writing anything. It's the source of truth for section names, order, and the required-vs-optional rules; this skill orchestrates against it and shouldn't restate it. If `SPEC-FORMAT.md` has changed since this skill was written, follow the file, not this description.

## 1. Figure out the number

List existing numbered folders at the repo root (`ls -d [0-9]*/` or a `Glob` for `[0-9]*/`). Propose the next integer. Confirm with the user rather than assuming; they may want to skip a number or reuse a gap.

## 2. Confirm the platform

The three existing games are all Pico-8, and `SPEC-FORMAT.md`'s CLAUDE.md and DESIGN.md sections are written specifically for Pico-8's constraints (token limits, `.p8` carts, `__sfx__`/`__gfx__`). The jam (see root `README.md`) also has Picotron and Pygame weeks.

- Pico-8 game: proceed as below.
- Picotron or Pygame game: say so plainly. `SPEC-FORMAT.md` doesn't have a non-Pico-8 variant of the Development or Constraints sections yet. Ask whether the user wants to extend `SPEC-FORMAT.md` first (recommended, keeps one source of truth for every game) or scaffold this one game ad hoc. Don't silently invent Picotron/Pygame constraint sections to fill the gap.

## 3. Interview

Ask about the game in as few questions as it takes to get a usable README, not more. At minimum:

- Name/title and one-line pitch: genre, and what makes it distinct
- Core mechanic: the one system that makes the game what it is
- Aesthetic: confirm it's the same Atari-2600-via-Pico-8 look as games 1-3, or ask what's different
- Scenes: what screens exist and roughly what moves the player between them. Title/Game/End is the default shape across games 1-3; ask whether this game needs more, the way game 1 has a Transitioning scene and game 3 has a Combo flash

Don't push for every field `SPEC-FORMAT.md` lists (Items, exact colours, sound events, tuning numbers) in one sitting. Game 2 shipped with a half-built README and a substantial Open Questions list, and that's a fine place to stop. Ask for what the user readily has; route the rest to Open Questions rather than guessing or leaving `[bracket]` placeholders in the body.

## 4. Write README.md

Follow `SPEC-FORMAT.md`'s required section order. Fill in whatever the interview produced. For anything not resolved:

- Omit optional sections that don't apply (Items, Progression) rather than leaving an empty template row
- For required sections with a real gap (Sound and Tile/sprite visuals are the usual ones this early), write one line saying it isn't decided yet and add the specific question to Open Questions. Don't write `[Item]`-style brackets
- Add a `**Status: not yet built.**` line near the top, since a fresh scaffold normally has no cart yet

## 5. Write DESIGN.md, PLAN.md, CLAUDE.md

These are pre-implementation skeletons, not full technical designs. Don't invent pixel layouts, palettes, or state IDs the interview didn't establish.

- **DESIGN.md** — Screen layout ASCII sketches only for scenes with known structure; a plain TBD note (not a guess) for anything undecided. A State machine table derived directly from README's Scenes table (mechanical translation, not invention). A Palette table with TBD rows if colours aren't chosen yet. Core system design covering whatever mechanics the interview did establish.
- **PLAN.md** — A phased checklist shaped by the game's actual systems, following the phase-per-system pattern in `1/PLAN.md`, `2/PLAN.md`, and `3/PLAN.md`: core movement/loop first, then resources, then screens and flow, then visuals/sound polish, then a token/performance check. Everything unchecked.
- **CLAUDE.md** — Project line linking to README, Development (standard Pico-8 workflow; copy from any existing game's CLAUDE.md), Pico-8 Constraints (copy verbatim, these don't vary game to game), a short Design summary bullet list, a `**Status: not yet built.**` line, and a Reusable code pointer to [`../lib/CLAUDE.md`](../../../lib/CLAUDE.md).

## 6. Wire up cross-references

- Add the new game to the root `README.md`'s "My entries" list, one line, matching the existing numbered format
- Confirm the new README opens with "Follows the format in [`../SPEC-FORMAT.md`](../SPEC-FORMAT.md)." like games 1-3
- Don't touch any other game's files

## 7. Report back

Summarize what got filled in from the interview versus what landed in Open Questions. That asymmetry is the point, the same way it is in game 2: the user should be able to tell at a glance what still needs a decision before implementation starts.
