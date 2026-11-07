extends Node2D

@export var color: Color = Color.ORANGE
@export var slide_speed: float = 4000.0

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
const PAINT_SOURCE_ID := 2
const PAINT_ATLAS_COORDS := Vector2i(2, 0)
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
## Pentatonic semitone offsets — no dissonant steps, so any order sounds musical.
const SCALE_SEMITONES := [0, 2, 4, 7, 9, 12, 14, 16]
#const SCALE_SEMITONES := [0]

var _scale_step := 0
var _scale_direction := 1

func _ready() -> void:
	position = floor_layer.map_to_local(grid_pos)
	paint_cell(grid_pos)
	last_painted_cell = grid_pos

	var generator := AudioStreamGenerator.new()
	generator.mix_rate = NOTE_MIX_RATE
	generator.buffer_length = 0.3
	wall_hit_sound.stream = generator

func _draw() -> void:
	draw_rect(Rect2(-24, -24, 48, 48), color)

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
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position", destination, duration)

	tween.finished.connect(func():
		update_painting()
		moving = false
		trail_particles.emitting = false
		squash(direction)
		play_wall_hit_note()
		move_count += 1
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

## Synthesizes a short sine-wave blip, picking a random note from
## SCALE_SEMITONES each hit so it always sounds musical without ever
## repeating a predictable pattern.
## shortcut: plain sine only, no filtered-square option — swap the
## sin(TAU * freq * t) line for sign(sin(...)) through a one-pole lowpass
## if a buzzier tone is wanted later.
func play_wall_hit_note() -> void:
	var freq := ROOT_FREQ * pow(2.0, SCALE_SEMITONES[_sequential_scale_step()] / 12.0)

	wall_hit_sound.play()
	var playback: AudioStreamGeneratorPlayback = wall_hit_sound.get_stream_playback()
	var sample_count := int(NOTE_MIX_RATE * NOTE_DURATION)
	var buffer := PackedVector2Array()
	buffer.resize(sample_count)
	for i in sample_count:
		var t := i / NOTE_MIX_RATE
		var progress := float(i) / sample_count
		var envelope := 1.0
		if progress < NOTE_ATTACK:
			envelope = progress / NOTE_ATTACK
		elif progress > 1.0 - NOTE_RELEASE:
			envelope = (1.0 - progress) / NOTE_RELEASE
		var sample := sin(TAU * freq * t) * envelope
		buffer[i] = Vector2(sample, sample)
	playback.push_buffer(buffer)

func _random_scale_step() -> int:
	return randi() % SCALE_SEMITONES.size()

# walk up and down the scale, bouncing direction at either end
func _sequential_scale_step() -> int:
	var step := _scale_step
	_scale_step += _scale_direction
	if _scale_step >= SCALE_SEMITONES.size() - 1 or _scale_step <= 0:
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
