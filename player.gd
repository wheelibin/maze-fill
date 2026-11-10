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

var _scale_semitones: Array = GameState.SCALE_SETS[0]
var _scale_step := 0
var _scale_direction := 1
var _note_streams: Array[AudioStreamWAV] = []

func _ready() -> void:
	position = floor_layer.map_to_local(grid_pos)
	paint_cell(grid_pos)
	last_painted_cell = grid_pos
	_rebuild_note_streams()

## Called by main.gd when a level loads, so each level's wall-hit notes use
## a different rotation of the pentatonic scale (see GameState.SCALE_SETS).
func set_level_scale(semitones: Array) -> void:
	_scale_semitones = semitones
	_scale_step = 0
	_scale_direction = 1
	_rebuild_note_streams()

# Precomputed once into finite AudioStreamWAVs, played via plain .play().
# Previously used AudioStreamGenerator's manual ring buffer, but that
# assumes continuous real-time consumption — on mobile, backgrounding the
# tab suspends the Web Audio context, and the generator's frame bookkeeping
# doesn't recover cleanly on resume, leaving a permanent growing delay for
# the rest of the session. A finite, fully-managed stream has no such state
# to desync.
func _rebuild_note_streams() -> void:
	_note_streams.resize(_scale_semitones.size())
	for i in _scale_semitones.size():
		var freq := ROOT_FREQ * pow(2.0, _scale_semitones[i] / 12.0)
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

## Plays a precomputed blip, picking a note from _scale_semitones each hit
## so it always sounds musical without ever repeating a predictable pattern.
func play_wall_hit_note() -> void:
	if not GameState.get_sound_effects_enabled():
		return
	wall_hit_sound.stream = _note_streams[_sequential_scale_step()]
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
