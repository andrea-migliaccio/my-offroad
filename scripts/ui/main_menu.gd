extends Screen
## Main menu over a CPU demo race running in a SubViewport behind it.

var _viewport: SubViewport
var _race: Race


func _ready() -> void:
	super()
	var container := SubViewportContainer.new()
	container.size = Vector2(W, H)
	container.modulate = Color(0.55, 0.55, 0.62)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(W, H)
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	container.add_child(_viewport)
	_start_demo()
	Audio.music("title")

	title("SUPER", 70, 64, UITheme.YELLOW)
	title("OFF-ROAD", 140, 64, Color8(236, 70, 44))
	label("ENHANCED EDITION", Vector2(0, 222), 16, Color8(220, 220, 235), W, HORIZONTAL_ALIGNMENT_CENTER)

	var items := []
	if GameState.has_career():
		items.append(["CONTINUE SEASON", _continue])
	items.append(["NEW SEASON", func(): done.emit("name")])
	items.append(["OPTIONS", func(): done.emit("options")])
	items.append(["HALL OF FAME", func(): done.emit("hof")])
	if not OS.has_feature("web"):
		items.append(["QUIT", func(): get_tree().quit()])
	menu(items, 270, 380)
	if GameState.has_career():
		var cfg := ConfigFile.new()
		cfg.load(GameState.CAREER_PATH)
		var info := "%s  RACE %d  %s" % [cfg.get_value("career", "player_name", ""),
			int(cfg.get_value("career", "race_index", 0)) + 1, money_str(cfg.get_value("career", "money", 0))]
		label(info, Vector2(0, 250), 8, UITheme.SKY, W, HORIZONTAL_ALIGNMENT_CENTER)
	label("ARROWS / MOUSE TO SELECT   ENTER TO CONFIRM   F11 FULLSCREEN", Vector2(0, 516), 8, UITheme.GRAY, W,
		HORIZONTAL_ALIGNMENT_CENTER)


func _start_demo() -> void:
	GameState.demo_mode = true
	if _race:
		_race.queue_free()
	_race = Race.new()
	_race.track_id = randi() % Track.track_count()
	_race.reverse = randf() < 0.5
	_race.demo = true
	_race.show_hud = false
	_race.finished.connect(func(_r): _start_demo.call_deferred())
	_viewport.add_child(_race)


func _continue() -> void:
	if GameState.load_career():
		GameState.demo_mode = false
		done.emit("shop")


func _exit_tree() -> void:
	GameState.demo_mode = false
