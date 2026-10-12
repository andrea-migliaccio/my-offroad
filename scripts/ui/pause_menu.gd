extends Screen
## In-race pause overlay. Emits done("resume" | "options" | "quit").


func _ready() -> void:
	super()
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.size = Vector2(W, H)
	dim.color = Color(0, 0, 0, 0.55)
	add_child(dim)
	panel(Rect2(300, 130, 360, 280))
	title("PAUSED", 150, 32)
	menu([
		["RESUME", func(): done.emit("resume")],
		["OPTIONS", func(): done.emit("options")],
		["QUIT TO MENU", func(): done.emit("quit")],
	], 230, 300)
	label("THE RACE WILL NOT COUNT IF YOU QUIT", Vector2(0, 380), 8, UITheme.GRAY, W, HORIZONTAL_ALIGNMENT_CENTER)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		done.emit("resume")
