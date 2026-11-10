extends Node2D

@export var color: Color = Color.ORANGE
@export var slide_speed: float = 4000.0
const RADIUS := 24.0

@onready var floor_layer: TileMapLayer = $"../Floor"
@onready var wall_layer: TileMapLayer = $"../Walls"
@onready var painted_layer: TileMapLayer = $"../Painted"
@onready var wall_hit_sound: AudioStreamPlayer = $WallHitSound
@onready var trail_particles: CPUParticles2D = $TrailParticles
@onready var main = $"../.."

var grid_pos := Vector2i(2, 2)
var moving := false
var move_count := 0
var total_paintable := 0
var level_complete := false
const PAINT_SOURCE_ID := 5
const PAINT_ATLAS_COORDS := Vector2i(0, 0)
var last_painted_cell := Vector2i(-999, -999)
var touch_start := Vector2.ZERO
const MIN_SWIPE := 30.0

const SQUASH_STRENGTH := 0.25
const SQUASH_SETTLE_DURATION := 0.18
var _squash_tween: Tween

const NOTE_MIX_RATE := 44100.0
const NOTE_DURATION := 0.12
const NOTE_ATTACK := 0.05 # fraction of NOTE_DURATION
const NOTE_RELEASE := 0.4 # fraction of NOTE_DURATION
const ROOT_FREQ := 220.0

const NotePitch := preload("res://note_pitch.gd")
const TuneSets := preload("res://tune_sets.gd")

## Experimental: step sequentially through a preset melody (tune_sets.gd)
## instead of bouncing through a per-level pentatonic scale. Toggle off in
## the Inspector to compare against the original scale-walk below.
@export var use_tune_mode: bool = true

var _scale_semitones: Array = GameState.SCALE_SETS[0]
var _scale_step := 0
var _scale_direction := 1
var _tune_notes: Array = TuneSets.TUNE_SETS[0]
var _tune_step := 0
var _note_streams: Array[AudioStreamWAV] = []

func _ready() -> void:
	position = floor_layer.map_to_local(grid_pos)
	paint_cell(grid_pos)
	last_painted_cell = grid_pos
	_rebuild_note_streams()
	if OS.is_debug_build():
		assert(is_equal_approx(snappedf(NotePitch.note_to_freq("A4"), 0.01), 440.0))
		assert(is_equal_approx(snappedf(NotePitch.note_to_freq("C4"), 0.01), 261.63))
		assert(is_equal_approx(snappedf(NotePitch.note_to_freq("F#3"), 0.01), 185.0))

## Called by main.gd when a level loads, so each level's wall-hit notes use
## a different rotation of the pentatonic scale (see GameState.SCALE_SETS).
func set_level_scale(semitones: Array) -> void:
	_scale_semitones = semitones
	_scale_step = 0
	_scale_direction = 1
	_rebuild_note_streams()

## Tune-mode counterpart to set_level_scale (see GameState.tune_for_level).
func set_level_tune(note_names: Array) -> void:
	_tune_notes = note_names
	_tune_step = 0
	_rebuild_note_streams()

## Single entry point for main.gd -- it picks which mode is active, so
## callers don't need to know about use_tune_mode.
func set_level_notes(global_level: int) -> void:
	if use_tune_mode:
		set_level_tune(GameState.tune_for_level(global_level))
	else:
		set_level_scale(GameState.scale_for_level(global_level))

# Precomputed once into finite AudioStreamWAVs, played via plain .play().
# Previously used AudioStreamGenerator's manual ring buffer, but that
# assumes continuous real-time consumption — on mobile, backgrounding the
# tab suspends the Web Audio context, and the generator's frame bookkeeping
# doesn't recover cleanly on resume, leaving a permanent growing delay for
# the rest of the session. A finite, fully-managed stream has no such state
# to desync.
func _rebuild_note_streams() -> void:
	var count := _tune_notes.size() if use_tune_mode else _scale_semitones.size()
	_note_streams.resize(count)
	for i in count:
		var freq: float = NotePitch.note_to_freq(_tune_notes[i]) if use_tune_mode \
			else ROOT_FREQ * pow(2.0, _scale_semitones[i] / 12.0)
		_note_streams[i] = _build_note_stream(freq)

func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS, color, true, -1.0, true)
	var border_color := color.darkened(0.35)
	border_color.a = 0.35
	draw_circle(Vector2.ZERO, RADIUS - 1.0, border_color, false, 2.0, true)

func _process(_delta: float) -> void:
	if moving:
		update_painting()

func _unhandled_input(event: InputEvent) -> void:
	if moving or level_complete:
		return

	if event.is_action_pressed("ui_right"):
		slide(Vector2i.RIGHT)
	elif event.is_action_pressed("ui_left"):
		slide(Vector2i.LEFT)
	elif event.is_action_pressed("ui_up"):
		slide(Vector2i.UP)
	elif event.is_action_pressed("ui_down"):
		slide(Vector2i.DOWN)


func slide(direction: Vector2i) -> void:
	var target := grid_pos

	while true:
		var next := target + direction

		# Stop at walls or outside the floor.
		if floor_layer.get_cell_source_id(next) == -1:
			break

		if wall_layer.get_cell_source_id(next) != -1:
			break

		target = next

	if target == grid_pos:
		squash(direction)
		return

	grid_pos = target
	moving = true
	trail_particles.emitting = true

	var destination := floor_layer.map_to_local(grid_pos)
	var duration := maxf(
		position.distance_to(destination) / slide_speed,
		0.08
	)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", destination, duration)

	tween.finished.connect(func():
		update_painting()
		moving = false
		trail_particles.emitting = false
		squash(direction)
		play_wall_hit_note()
		move_count += 1
		main.update_move_count(move_count)
		if not level_complete and painted_layer.get_used_cells().size() >= total_paintable:
			level_complete = true
			main.show_win_popup(move_count)
	)

## Rubber-ball squash: compress along the travel axis, bulge perpendicular,
## then spring back. Used both when blocked outright (no movement) and when
## landing at the end of a slide (every slide ends against a wall/edge).
func squash(direction: Vector2i) -> void:
	if _squash_tween:
		_squash_tween.kill()

	var squashed: Vector2
	if direction.x != 0:
		squashed = Vector2(1.0 - SQUASH_STRENGTH, 1.0 + SQUASH_STRENGTH)
	else:
		squashed = Vector2(1.0 + SQUASH_STRENGTH, 1.0 - SQUASH_STRENGTH)

	_squash_tween = create_tween()
	_squash_tween.tween_property(self, "scale", squashed, 0.05) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_squash_tween.tween_property(self, "scale", Vector2.ONE, SQUASH_SETTLE_DURATION) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

## Plays a precomputed blip: steps through the level's tune (or bounces
## through its scale, in the old mode) one note per wall-hit.
func play_wall_hit_note() -> void:
	if not GameState.get_sound_effects_enabled():
		return
	var index := _tune_step_advance() if use_tune_mode else _sequential_scale_step()
	wall_hit_sound.stream = _note_streams[index]
	wall_hit_sound.play()

## shortcut: plain sine only, no filtered-square option — swap the
## sin(TAU * freq * t) line for sign(sin(...)) through a one-pole lowpass
## if a buzzier tone is wanted later.
func _build_note_stream(freq: float) -> AudioStreamWAV:
	var sample_count := int(NOTE_MIX_RATE * NOTE_DURATION)
	var data := PackedByteArray()
	data.resize(sample_count * 2) # 16-bit mono
	for i in sample_count:
		var t := i / NOTE_MIX_RATE
		var progress := float(i) / sample_count
		var envelope := 1.0
		if progress < NOTE_ATTACK:
			envelope = progress / NOTE_ATTACK
		elif progress > 1.0 - NOTE_RELEASE:
			envelope = (1.0 - progress) / NOTE_RELEASE
		var sample := sin(TAU * freq * t) * envelope
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = int(NOTE_MIX_RATE)
	stream.stereo = false
	stream.data = data
	return stream

func _random_scale_step() -> int:
	return randi() % _scale_semitones.size()

# walk up and down the scale, bouncing direction at either end
func _sequential_scale_step() -> int:
	var step := _scale_step
	_scale_step += _scale_direction
	if _scale_step >= _scale_semitones.size() - 1 or _scale_step <= 0:
		_scale_direction *= -1
	return step

# walk forward through the tune, looping back to the start -- a melody has
# a direction, unlike the scale's back-and-forth bounce above.
func _tune_step_advance() -> int:
	var step := _tune_step
	_tune_step = (_tune_step + 1) % _tune_notes.size()
	return step

func paint_cell(cell: Vector2i) -> void:
	if floor_layer.get_cell_source_id(cell) == -1:
		return

	if wall_layer.get_cell_source_id(cell) != -1:
		return

	painted_layer.set_cell(
		cell,
		PAINT_SOURCE_ID,
		PAINT_ATLAS_COORDS
	)

func update_painting() -> void:
	var current_cell := floor_layer.local_to_map(position)

	if current_cell == last_painted_cell:
		return

	var direction := Vector2i(
		signi(current_cell.x - last_painted_cell.x),
		signi(current_cell.y - last_painted_cell.y)
	)

	var cell := last_painted_cell

	while cell != current_cell:
		cell += direction
		paint_cell(cell)

	last_painted_cell = current_cell

func _input(event: InputEvent) -> void:
	
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_start = event.position
		else:
			var swipe: Vector2 = event.position - touch_start

			if swipe.length() < MIN_SWIPE or moving or level_complete:
				return

			if absf(swipe.x) > absf(swipe.y):
				slide(Vector2i.RIGHT if swipe.x > 0 else Vector2i.LEFT)
			else:
				slide(Vector2i.DOWN if swipe.y > 0 else Vector2i.UP)
