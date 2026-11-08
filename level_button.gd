extends Button

func configure(local: int, unlocked: bool, completed: bool, stars: int, best_moves: int) -> void:
	disabled = not unlocked # Godot's default theme already renders disabled buttons dimmed/muted
	if not unlocked:
		text = "%d\n🔒" % local
	elif completed:
		text = "%d\n%s (%d)" % [local, "★".repeat(stars) + "☆".repeat(3 - stars), best_moves]
	else:
		text = str(local)
