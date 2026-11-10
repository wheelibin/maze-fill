# Flow Paint

A Godot 4.7 slide-puzzle game: the player slides until hitting a wall
(Ricochet Robots style), painting every tile it crosses.

## Running the game

Open the project in Godot 4.7 and run `game.tscn` (set as the main scene).

### Debug keybinds (`main.gd`)

| Key | Action |
|-----|--------|
| `L` | Load the next stored level from `levels/levels.json`, wrapping around |

## Pregenerated levels

Levels are generated offline and stored in `levels/levels.json` as a flat
array (index `i` = level `i + 1`). Each entry has the board `size`
(including the 1-tile border), the player `start` cell, interior `walls`,
the `goal` cell, a `difficulty_score`/`difficulty_label`
(`easy`/`medium`/`hard`, computed *relative to that level's size pack* —
see "Tuning the level set" for why), and `min_moves` — the exact minimum
number of slide-moves needed to paint every reachable tile on that
level, intended as the basis for a future star rating (e.g. 3★ for
solving in `min_moves`). The solve has no time budget, so this is always
a true exact value for every level, never an estimate.

At runtime, `main.gd`'s `load_level(n)` reads this file and builds the
board from the stored data instead of generating one live.

### Regenerating levels

Levels are produced by a standalone Go program in `generator/` (a port of
the original GDScript generator — ported because the min-moves solve is
CPU-heavy enough that a compiled, parallelized version matters: the full
1000-level run takes under 8 minutes in Go across all CPU cores, versus
being impractically slow under GDScript's interpreter):

```sh
cd generator
go run .
```

This overwrites `levels/levels.json`. Generation is deterministic (fixed
seed, with each parallel worker given its own derived seed) — rerunning
with the same config reproduces the same level set.

### Tuning the level set

The game's flow is: the player picks a board size, then plays a batch of
levels at that size with their own easy-to-hard arc. Edit the constants
at the top of `generator/main.go`:

| Constant | Meaning |
|---|---|
| `sizes` | Full board sizes (incl. 1-tile border), one size pack per entry (default 14x6, 16x8, 18x10, 20x12) |
| `levelsPerSize` | Levels per size pack (default 250) |
| `candidatesPerSize` | Candidate layouts sampled per size before picking levels (default 3000) — raise if difficulty bands look noisy |
| `easyStart`/`easyEnd`, `hardStart`/`hardEnd` | Target easy/hard fraction at the start and end of a size's run (medium fills whatever's left) — a linear ramp, no sawtooth, since there's no size bump to ease back from within one size's levels |
| `generationSeed` | RNG seed — change to get a different level set |

Difficulty within a size is tier-relative: each size's own pool of
sampled candidates is split into terciles, so "hard" means "hardest
achievable at that board size," not a fixed global slide-count. On very
small boards, a target band can come up empty — the generator falls back
to an easier band and prints a warning; this is expected, not a bug.

### Scaling limits on `min_moves`

`generator/solver.go`'s `MinMovesToCover` is an exact A* search (not a
heuristic approximation), verified against an independent brute-force
reference before trusting it on real data, with no time budget — it
always runs to completion so every level gets a true exact value. On
the largest size (20x12, 180 touched tiles) the typical hard level
solves in milliseconds to a few seconds; the worst-case layouts can take
much longer (minutes), which is why solving is parallelized across
cores and run as a one-off batch job rather than live. If you grow
`sizes` further, watch total run time climb accordingly — there's no
cap to warn you first. The state key packs lanes into a fixed
`[5]uint64` array (`maxLanes` in `solver.go`), covering up to 320 tiles
— bump it if a future size needs more than that.
