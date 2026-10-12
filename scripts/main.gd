extends Node
## Screen flow:
##   menu -> name -> shop -> race -> awards -> shop ... -> gameover -> hof -> menu
## plus options / hall of fame from the menu and the in-race pause overlay.

const SCREENS := {
	"menu": "res://scripts/ui/main_menu.gd",
	"options": "res://scripts/ui/options_screen.gd",
	"name": "res://scripts/ui/name_screen.gd",
	"shop": "res://scripts/ui/shop_screen.gd",
	"awards": "res://scripts/ui/awards_screen.gd",
	"gameover": "res://scripts/ui/game_over_screen.gd",
	"hof": "res://scripts/ui/hof_screen.gd",
}

var _current: Node
var _race: Race
var _lost_life := false
var _overlay: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Debug flags (after `--`): --screen=<name> --shot=<png path> --shot-time=<seconds>
	#   --race-index=<n> --pause
	var start := "menu"
	var shot := ""
	var shot_time := 3.0
	var pause := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--screen="):
			start = a.get_slice("=", 1)
		elif a.begins_with("--shot="):
			shot = a.get_slice("=", 1)
		elif a.begins_with("--shot-time="):
			shot_time = float(a.get_slice("=", 1))
		elif a.begins_with("--race-index="):
			GameState.race_index = int(a.get_slice("=", 1))
		elif a == "--pause":
			pause = true
	if start == "awards":
		GameState.last_results = [
			{"team": "gray", "name": "IVAN", "position": 1, "prize": 150000, "bonus": 20000, "is_player": false, "nitro_left": 0},
			{"team": "red", "name": GameState.player_name, "position": 2, "prize": 100000, "bonus": 30000, "is_player": true, "nitro_left": 2},
			{"team": "blue", "name": "EARL", "position": 3, "prize": 50000, "bonus": 0, "is_player": false, "nitro_left": 0},
			{"team": "yellow", "name": "JOHN", "position": 4, "prize": 0, "bonus": 10000, "is_player": false, "nitro_left": 1},
		]
	goto(start)
	if shot != "":
		if pause:
			await get_tree().create_timer(shot_time * 0.5, true, false, true).timeout
			_open_pause()
		await get_tree().create_timer(shot_time * (0.5 if pause else 1.0), true, false, true).timeout
		get_viewport().get_texture().get_image().save_png(shot)
		get_tree().quit()


func goto(screen: String) -> void:
	get_tree().paused = false
	_close_overlay()
	if _current:
		_current.queue_free()
		_current = null
	_race = null
	GameState.demo_mode = false
	if screen == "race":
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		_race = Race.new()
		_race.process_mode = Node.PROCESS_MODE_PAUSABLE
		var ct := GameState.current_track()
		_race.track_id = ct.id
		_race.reverse = ct.reverse
		_race.finished.connect(_on_race_finished)
		_current = _race
	else:
		var sc: Screen = load(SCREENS[screen]).new()
		if screen == "awards":
			sc.lost_life = _lost_life
		sc.done.connect(_on_screen_done.bind(screen))
		_current = sc
	add_child(_current)


func _on_screen_done(next: String, from: String) -> void:
	if next == "back":
		next = "menu"
	if from == "options" and next == "menu":
		goto("menu")
		return
	goto(next)


func _on_race_finished(results: Array) -> void:
	_lost_life = GameState.apply_results(results)
	goto("awards")


# --- pause overlay ------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _race and _overlay == null and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_open_pause()


func _open_pause() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_overlay(load("res://scripts/ui/pause_menu.gd").new())


func _show_overlay(sc: Screen) -> void:
	_close_overlay()
	_overlay = CanvasLayer.new()
	_overlay.layer = 20
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_overlay)
	sc.process_mode = Node.PROCESS_MODE_ALWAYS
	sc.done.connect(_on_overlay_done)
	_overlay.add_child(sc)


func _close_overlay() -> void:
	if _overlay:
		_overlay.queue_free()
		_overlay = null


func _on_overlay_done(next: String) -> void:
	match next:
		"resume":
			_close_overlay()
			get_tree().paused = false
			Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		"options":
			var opt: Screen = load(SCREENS["options"]).new()
			opt._overlay = true
			_show_overlay(opt)
		"back":
			_show_overlay(load("res://scripts/ui/pause_menu.gd").new())
		"quit":
			goto("menu")
