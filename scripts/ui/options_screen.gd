extends Screen
## Options: difficulty, laps, volumes, fullscreen and key remapping.
## Emits done("back") when closed; main.gd decides where "back" goes.

var _rows: VBoxContainer
var _waiting_action := ""
var _bind_buttons := {}
var _controls := false
var _overlay := false  # opened from the pause menu (game paused behind)


func _ready() -> void:
	super()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	_bind_buttons.clear()
	var bg := ColorRect.new()
	bg.size = Vector2(W, H)
	bg.color = Color(0.03, 0.03, 0.1, 0.92 if _overlay else 1.0)
	add_child(bg)
	title("CONTROLS" if _controls else "OPTIONS", 40, 40)
	panel(Rect2(150, 110, 660, 380))
	_rows = VBoxContainer.new()
	_rows.position = Vector2(180, 134)
	_rows.size = Vector2(600, 0)
	_rows.add_theme_constant_override("separation", 12)
	add_child(_rows)
	if _controls:
		_build_controls()
	else:
		_build_options()


func _row(caption: String) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	_rows.add_child(hb)
	var l := Label.new()
	l.text = caption
	l.custom_minimum_size = Vector2(300, 40)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(l)
	return hb


## A button that cycles through values with Enter/click and Left/Right.
func _selector(caption: String, values: Array, current: int, on_change: Callable) -> Button:
	var hb := _row(caption)
	var idx := [current]
	var b := button("", func(): pass, hb, 280)
	var refresh := func(): b.text = "<  %s  >" % str(values[idx[0]])
	refresh.call()
	var step := func(d: int):
		idx[0] = (idx[0] + d + values.size()) % values.size()
		refresh.call()
		on_change.call(idx[0])
		Audio.play("menu_move")
	b.pressed.connect(func(): step.call(1))
	b.gui_input.connect(func(ev: InputEvent):
		if ev.is_action_pressed("ui_left"):
			step.call(-1)
			b.accept_event()
		elif ev.is_action_pressed("ui_right"):
			step.call(1)
			b.accept_event())
	return b


func _slider(caption: String, value: float, on_change: Callable) -> HSlider:
	var hb := _row(caption)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(280, 40)
	s.focus_mode = Control.FOCUS_ALL
	s.value_changed.connect(func(v): on_change.call(v))
	s.mouse_entered.connect(func(): s.grab_focus())
	hb.add_child(s)
	return s


func _build_options() -> void:
	var first := _selector("DIFFICULTY", GameState.DIFFICULTIES, GameState.difficulty, func(i):
		GameState.difficulty = i
		GameState.save_settings())
	_selector("LAPS PER RACE", [3, 4, 5], [3, 4, 5].find(GameState.laps), func(i):
		GameState.laps = [3, 4, 5][i]
		GameState.save_settings())
	_slider("MUSIC VOLUME", GameState.music_volume, func(v):
		GameState.music_volume = v
		Audio.set_volumes(v, GameState.sfx_volume)
		GameState.save_settings())
	_slider("EFFECTS VOLUME", GameState.sfx_volume, func(v):
		GameState.sfx_volume = v
		Audio.set_volumes(GameState.music_volume, v)
		Audio.play("bump_light", 0.0, 1.0, 0.2)
		GameState.save_settings())
	_selector("DISPLAY", ["WINDOW", "FULLSCREEN"], 1 if GameState.fullscreen else 0, func(i):
		GameState.fullscreen = i == 1
		GameState.apply_settings()
		GameState.save_settings())
	var hb := _row("")
	button("CONTROLS...", func():
		_controls = true
		_build(), hb, 280)
	var back_row := _row("")
	button("BACK", _back, back_row, 280)
	first.call_deferred("grab_focus")


func _build_controls() -> void:
	var first: Button = null
	for action in GameState.BINDABLE:
		var hb := _row(GameState.BINDABLE_LABELS[action])
		var a: String = action
		var b := button(GameState.key_label(a), func(): _start_wait(a), hb, 280)
		_bind_buttons[a] = b
		if first == null:
			first = b
	var hb2 := _row("")
	button("RESET DEFAULTS", func():
		GameState.reset_keys()
		_build(), hb2, 280)
	var hb3 := _row("")
	button("BACK", func():
		_controls = false
		_build(), hb3, 280)
	label("JOYPAD: D-PAD/STICK STEER, A GAS, B NITRO", Vector2(0, 500), 8, UITheme.GRAY, W, HORIZONTAL_ALIGNMENT_CENTER)
	first.call_deferred("grab_focus")


func _start_wait(action: String) -> void:
	_waiting_action = action
	_bind_buttons[action].text = "PRESS A KEY..."


func _input(event: InputEvent) -> void:
	if _waiting_action == "" or not (event is InputEventKey) or not event.pressed:
		return
	get_viewport().set_input_as_handled()
	var b: Button = _bind_buttons[_waiting_action]
	if event.physical_keycode != KEY_ESCAPE:
		GameState.bind_key(_waiting_action, event.physical_keycode)
		Audio.play("buy")
	b.text = GameState.key_label(_waiting_action)
	_waiting_action = ""


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _controls:
			_controls = false
			_build()
		else:
			_back()


func _back() -> void:
	done.emit("back")
