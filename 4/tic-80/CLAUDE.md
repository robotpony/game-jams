# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

A TIC-80 game, an upscale of "Gyri #4" (the Pico-8 build at [`../pico-8/`](../pico-8/)) — an arcade shooter with Atari 2600 aesthetics, Space Invaders/Galaga-style but with the player's and enemies' straight lines replaced by concentric arcs. The full spec is in [`../README.md`](../README.md), following [`../../SPEC-FORMAT.md`](../../SPEC-FORMAT.md).

**Status: not yet built. Design pass not yet started.** This is planned as an expanded upscale, not a straight port: bigger playfield/formation, richer sprite art, deeper sound/music, and new mechanics are all in scope, per the design conversation that chose this direction (see [`../../SPEC-FORMAT.md`](../../SPEC-FORMAT.md) for the doc lifecycle this folder follows). None of that is decided yet; [DESIGN.md](DESIGN.md) is a stub until a real design pass happens, tracked as [PLAN.md](PLAN.md)'s Phase 0.

## Development

TIC-80 has no build system, package manager, linter, or test runner, same as Pico-8. The workflow (see [`../../tools/tic80.md`](../../tools/tic80.md) for the full reference):

- Author game code as a plain external `4.lua` file, edited with normal tools (unlike Pico-8's `.p8`, a `.tic` cart is binary and not diffable)
- Bring it into a working cart: `tic80 --fs=4/tic-80 --cli --cmd "load 4.tic & import code 4.lua & save 4.tic & exit"` (or `new lua` in place of `load` on the very first run, before `4.tic` exists)
- Play/test: `tic80 --fs=4/tic-80 4.tic` (opens the GUI; there's no headless run-and-exit equivalent to Pico-8's `-run`)

Verification is manual: load the cart and play it.

## TIC-80 constraints

These constraints shape every implementation decision. Full reference (spec, RAM/VRAM layout, cart format, CLI workflow): [`../../tools/tic80.md`](../../tools/tic80.md).

- **Code cap**: 64KB, not a token count — bigger ceiling than Pico-8's ~8,192 tokens, but still finite
- **Display**: 240×136 pixels, 16-colour palette (remappable, unlike Pico-8's fixed hardware palette)
- **Sprites**: 8×8 pixels each, 256 tile slots + 256 sprite slots (two banks, 512 total vs. Pico-8's 256 shared)
- **Map**: 240×136 cells
- **Sound**: 4 channels, configurable waveforms
- **Language**: Lua (chosen to match Pico-8 Lua and this project's existing `lib/` snippets — see [`../../tools/tic80.md`](../../tools/tic80.md#language-choice))

## Design summary

Not yet written. Once the design pass (PLAN.md Phase 0) lands, this section summarizes the same way every other game's CLAUDE.md does: core mechanic, player state, wave/progression rules, visual and audio direction, pointing at DESIGN.md for exact numbers.

## Reusable code

[`../../lib/`](../../lib/) is Lua written for Pico-8 Lua's stdlib gaps (no `string.format`, etc.) and its token-counted copy-paste model. TIC-80's Lua is closer to standard Lua 5.4 and has a byte cap instead of a token count, so `lib/`'s snippets are a starting reference, not a drop-in include; check [`../../lib/CLAUDE.md`](../../lib/CLAUDE.md) for what exists before reimplementing, but expect to adapt rather than paste verbatim.
