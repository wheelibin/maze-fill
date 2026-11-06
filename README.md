# Maze Fill

A Godot 4.7 slide-puzzle game: the player slides until hitting a wall
(Ricochet Robots style), painting every tile it crosses.

## Running the game

Open the project in Godot 4.7 and run `game.tscn` (set as the main scene).

### Debug keybinds (`main.gd`)

| Key | Action |
|-----|--------|
| `M` | Regenerate a random procedural maze (any difficulty) |
| `1` / `2` / `3` | Regenerate targeting easy / medium / hard difficulty |
| `L` | Load the next stored level from `levels/levels.json`, wrapping around |

## Pregenerated levels

Levels are generated offline and stored in `levels/levels.json` as a flat
array (index `i` = level `i + 1`). Each entry has the board `size`
(including the 1-tile border), the player `start` cell, interior `walls`,
the `goal` cell, and a `difficulty_score`/`difficulty_label`
(`easy`/`medium`/`hard`, computed *relative to that level's size tier* —
see `tools/generate_levels.gd` for why).

At runtime, `main.gd`'s `load_level(n)` reads this file and builds the
board from the stored data instead of generating one live.

### Regenerating levels

Levels are produced by a headless Godot script:

```sh
godot --headless --script res://tools/generate_levels.gd
```

(If `godot` isn't on your `PATH`, use the full path to the binary, e.g.
on macOS: `/Applications/Godot.app/Contents/MacOS/Godot --headless --script res://tools/generate_levels.gd`.)

This overwrites `levels/levels.json`. Generation is deterministic (fixed
seed) — rerunning with the same config produces byte-identical output.

### Tuning the level set

Edit the constants at the top of `tools/generate_levels.gd`:

| Constant | Meaning |
|---|---|
| `LEVELS_PER_TIER` | Levels per size tier (default 10) |
| `TIER_COUNT` | Number of tiers (default 3, i.e. 30 levels total) |
| `BASE_LEVEL_SIZE` | Full board size (incl. border) for tier 0 (default 9x5) |
| `TIER_GROWTH_STEP` | Added to the board size per tier (default +2/+2) |
| `CANDIDATES_PER_TIER` | How many candidate layouts to sample per tier before picking levels (default 2000) — raise if difficulty bands look noisy |
| `EASY_FRACTION` / `MEDIUM_FRACTION` | Share of each tier's levels in the easy/medium bands (remainder is hard) |
| `GENERATION_SEED` | RNG seed — change to get a different level set |

Difficulty within a tier is tier-relative: each tier's own pool of
sampled candidates is split into terciles, so "hard" means "hardest
achievable at that board size," not a fixed global slide-count. On very
small boards, a target band can come up empty — the generator falls back
to an easier band and prints a warning; this is expected, not a bug.
