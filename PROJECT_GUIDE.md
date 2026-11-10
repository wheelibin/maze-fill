# Navigating this project in the Godot editor

This project used to be easy to browse because everything lived under one
scene tree. It no longer does: the game flows through **four separate
scenes**, swapped in and out at runtime with `get_tree().change_scene_to_file()`
rather than nested as children of a single root. That means the editor's
default Scene tab only ever shows you _one screen at a time_, and opening
`game.tscn` directly in the editor won't show you how you got there.

## Runtime scene flow

```
size_select.tscn  --(pick a board size)-->  level_select.tscn  --(pick a level)-->  game.tscn
      |
      --(Options button)-->  options.tscn  --(Back)-->  size_select.tscn
```

- `project.godot`'s `run/main_scene` is `size_select.tscn` — that's what
  starts when you hit Play (F5).
- Each arrow is `get_tree().change_scene_to_file("res://....tscn")` inside
  that screen's script (`size_select.gd`, `level_select.gd`). The old scene
  is freed; nothing is nested.
- `game.tscn`'s `go_to_level_select()` / `go_to_next_level()` (in `main.gd`)
  and `win_popup.gd`'s button handlers go back the other way the same way.

**To jump straight to one screen without playing through the whole flow**:
open that `.tscn` file in the editor and press "Run Current Scene" (the
scene-specific play button, or F6) instead of F5. `game.tscn` run this way
still works standalone — it just uses whatever `GameState.selected_level`
currently defaults to (1) instead of whatever you picked in `level_select`.

**To inspect the live tree of whichever scene is currently running** (since
the Scene dock only shows editor-time scenes, not the swapped-in runtime
one): while playing, open the Debugger panel's Scene tab and switch its
dropdown from "Local" to "Remote" — that shows the actual tree of the
currently active scene, live.

## The one thing that persists across scene swaps: `GameState`

`game_state.gd` is registered as an **autoload singleton** (Project Settings
→ Autoload, name `GameState`). It's the only thing that survives a scene
swap, so it's where cross-screen state lives:

- `selected_size_index`, `selected_level` — what the player picked, read by
  the next screen.
- `PAINT_COLORS` — the 8 flood-fill colors, cycled per level.
- `SCALE_SETS` — the 5 pentatonic note sets used for the wall-hit sound in
  the original scale-walk mode, cycled per level.
- `TUNE_SETS` (in `tune_sets.gd`, not `game_state.gd`) — the preset melodies
  played instead, when `player.gd`'s `use_tune_mode` export is on (the
  default). `GameState.tune_for_level()` cycles them the same way
  `scale_for_level()` cycles `SCALE_SETS`.
- Save data (`user://save.json` — on desktop this is
  `~/Library/Application Support/Godot/app_userdata/Paint Flow/save.json`,
  delete it to reset all progress) and the star-rating formula
  (`compute_stars`).

## Where things actually live — cheat sheet

| Want to tweak...                                                         | Look here                                                                                                                                                                                                                                                                             |
| ------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Button/label colors, fonts, corner radius, shadows (global)              | `game_theme.tres` — this is the single Godot **Theme** resource set as the project-wide default (`project.godot` → `[gui] theme/custom`). Edit it in the editor's theme editor, or by hand (it's a plain text resource).                                                              |
| The font itself                                                          | `fonts/Fredoka.ttf` (OFL-licensed, variable weight). The `FontVariation_semibold` sub-resource inside `game_theme.tres` picks the weight (`wght`) and synthetic emboldening (`variation_embolden`) applied everywhere.                                                                |
| Tooltip styling                                                          | `TooltipPanel`/`TooltipLabel` entries at the bottom of `game_theme.tres`.                                                                                                                                                                                                             |
| One specific button's colors (not the global default)                    | Look for a script next to it: `level_button.gd` (level-select tiles) and `win_popup.gd` (`_recolor_button`/`_make_outline_button`) both build their own `StyleBoxFlat` overrides in code rather than using the theme.                                                                 |
| The shared color _names_ used by those scripts (navy, teal, gold, etc.)  | `ui_colors.gd` — a `RefCounted` of `const Color` tokens. This is separate from `game_theme.tres` on purpose: `.tscn` files can only reference theme/resource colors, not GDScript constants, so anything styled from a _script_ pulls from here instead of re-declaring its own copy. |
| Button text itself, static labels, spacing between UI elements           | Directly in the relevant `.tscn` file (`size_select.tscn`, `level_select.tscn`, `game.tscn`) — these are plain data, no script needed.                                                                                                                                                |
| Paint flood-fill colors per level                                        | `GameState.PAINT_COLORS` in `game_state.gd`.                                                                                                                                                                                                                                          |
| Wall-hit note content per level | Default is tune mode: edit `TuneSets.TUNE_SETS` in `tune_sets.gd` (flat note-name lists like `"C4"`, `"F#3"`) to add/change melodies — `GameState.tune_for_level()` cycles them per level, `note_pitch.gd` converts the names to Hz. Toggle `Player`'s `use_tune_mode` export off in the Inspector to fall back to the old scale-walk (`GameState.SCALE_SETS` in `game_state.gd`). |
| The sound effects on/off setting | `options.tscn`/`options.gd` is the UI; `GameState.get_sound_effects_enabled()`/`set_sound_effects_enabled()` persist it (default on) in the save file under `sound_effects_enabled`. `player.gd`'s `play_wall_hit_note()` checks it. |
| Camera fit/zoom behavior (how much a board is scaled to fill the screen) | `camera_2d.gd` — `margin` (edge padding) and `max_zoom_desktop` (cap on desktop so small boards don't balloon on huge monitors; skipped on touch-primary devices, detected via `_is_touch_primary()`).                                                                                |
| Star-rating thresholds                                                   | `GameState.compute_stars()` in `game_state.gd` (currently 3★ at ≤115% of par, 2★ at ≤150%, 1★ for finishing).                                                                                                                                                                         |
| Player feel: slide speed, squash animation, trail particles              | `player.gd` (`slide_speed`, `SQUASH_STRENGTH`/`SQUASH_SETTLE_DURATION`, `$TrailParticles`).                                                                                                                                                                                           |
| Debug keybinds while playing                                             | `main.gd`'s `_unhandled_input` — `L` cycles through stored levels. See `README.md`.                                                                                                                                                                                                   |
| Tile art (floor/wall/painted look)                                       | `maze_tileset.tres` (tile size 64×64) + the source PNGs (`flat_tileset_256x64.png`, `godot_tileset_192x64.png`).                                                                                                                                                                      |
| Window size, stretch mode, app icon, splash screen                       | `project.godot` → `[display]` and `[application]`.                                                                                                                                                                                                                                    |
| The actual level layouts (board size, walls, par)                        | **Not editable by hand** — generated offline into `levels/levels.json` by the Go program in `generator/`. See `README.md`'s "Regenerating levels" section to change board sizes, level counts, or difficulty curve.                                                                   |
| Testing the real Web export without pushing to GitHub Pages              | `./deploy-local.sh` — exports via the same command CI uses and serves it locally (needs Godot's export templates installed once; see `scripts/serve_web.py` for the local server).                                                                                                    |

## Quick orientation for new scripts/scenes

If you add a new screen, follow the existing pattern: a `Control`-derived
`.tscn` + `.gd` pair, navigated to via `change_scene_to_file`, reading/writing
state through `GameState` rather than passing data through scene
parameters (there's no mechanism for that here — swapped scenes start fresh).
