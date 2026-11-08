extends RefCounted

## Shared color tokens for UI scripts. .tscn files can't reference this (scene
## resource properties are plain data, not code), but every GDScript-driven
## style should pull from here instead of re-declaring its own copy -- that's
## exactly how the locked-tile grey and the theme's disabled grey, and the
## level-button border teal and the win-popup pressed teal, drifted apart.
const NAVY := Color(0.235, 0.247, 0.31, 1)
const ORANGE := Color(1, 0.647, 0, 1)
const TEAL := Color(0.31, 0.851, 0.69, 1)
const TEAL_HOVER := Color(0.22, 0.74, 0.6, 1)
const TEAL_DARK := Color(0.2, 0.68, 0.54, 1)
const GOLD := Color(1, 0.82, 0.1, 1)
const DISABLED_BG := Color(0.78, 0.8, 0.85, 1)
const DISABLED_TEXT := Color(0.55, 0.58, 0.64, 1)
const MUTED_TEXT := Color(0.45, 0.47, 0.54, 1)
