extends Screen
## New season: driver name (typed) and a reminder of the chosen difficulty.

var _edit: LineEdit


func _ready() -> void:
	super()
	title("NEW SEASON", 50, 40)
	panel(Rect2(230, 130, 500, 300))
	label("DRIVER NAME", Vector2(230, 160), 16, UITheme.SKY, 500, HORIZONTAL_ALIGNMENT_CENTER)
	_edit = LineEdit.new()
	_edit.max_length = 8
	_edit.text = GameState.player_name
	_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_edit.position = Vector2(300, 196)
	_edit.size = Vector2(360, 60)
	_edit.text_changed.connect(func(t):
		var col := _edit.caret_column
		_edit.text = t.to_upper()
		_edit.caret_column = col)
	_edit.text_submitted.connect(func(_t): _start())
	add_child(_edit)
	label("DIFFICULTY: %s   LAPS: %d" % [GameState.DIFFICULTIES[GameState.difficulty], GameState.laps],
		Vector2(230, 280), 8, UITheme.GRAY, 500, HORIZONTAL_ALIGNMENT_CENTER)
	if GameState.has_career():
		label("THIS REPLACES YOUR SAVED SEASON", Vector2(230, 300), 8, UITheme.RED, 500, HORIZONTAL_ALIGNMENT_CENTER)
	var hb := HBoxContainer.new()
	hb.position = Vector2(270, 340)
	hb.add_theme_constant_override("separation", 20)
	add_child(hb)
	button("START", _start, hb, 200)
	button("BACK", func(): done.emit("back"), hb, 200)
	var tp := TruckPreview.new()
	tp.position = Vector2(430, 430)
	tp.size = Vector2(100, 100)
	add_child(tp)
	_edit.call_deferred("grab_focus")
	_edit.call_deferred("select_all")


func _start() -> void:
	var n := _edit.text.strip_edges().to_upper()
	GameState.new_game()
	GameState.player_name = n if n != "" else "DRIVER"
	GameState.save_career()
	done.emit("shop")


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color8(8, 10, 30))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		done.emit("back")
