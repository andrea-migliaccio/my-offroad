extends Node
## Screen state machine: title -> name -> shop -> race -> awards -> shop ...

const SCREENS := {
	"title": "res://scripts/ui/title_screen.gd",
	"name": "res://scripts/ui/name_screen.gd",
	"shop": "res://scripts/ui/shop_screen.gd",
	"awards": "res://scripts/ui/awards_screen.gd",
	"continue": "res://scripts/ui/continue_screen.gd",
	"hof": "res://scripts/ui/hof_screen.gd",
}

var _current: Node
var _race: Race
var _lost_credit := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Debug flags (after `--`): --screen=<name>  --shot=<png path> --shot-time=<seconds>
	var start := "title"
	var shot := ""
	var shot_time := 3.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--screen="):
			start = a.get_slice("=", 1)
		elif a.begins_with("--shot="):
			shot = a.get_slice("=", 1)
		elif a.begins_with("--shot-time="):
			shot_time = float(a.get_slice("=", 1))
		elif a.begins_with("--race-index="):
			GameState.race_index = int(a.get_slice("=", 1))
	if start == "awards":
		GameState.last_results = [
			{"team": "gray", "name": "IVAN", "position": 1, "prize": 150000, "bonus": 20000, "is_player": false, "nitro_left": 0},
			{"team": "red", "name": GameState.player_name, "position": 2, "prize": 100000, "bonus": 30000, "is_player": true, "nitro_left": 2},
			{"team": "blue", "name": "EARL", "position": 3, "prize": 50000, "bonus": 0, "is_player": false, "nitro_left": 0},
			{"team": "yellow", "name": "JOHN", "position": 4, "prize": 0, "bonus": 10000, "is_player": false, "nitro_left": 1},
		]
	goto(start)
	if shot != "":
		await get_tree().create_timer(shot_time, true, false, true).timeout
		get_viewport().get_texture().get_image().save_png(shot)
		get_tree().quit()


func goto(screen: String) -> void:
	get_tree().paused = false
	if _current:
		_current.queue_free()
		_current = null
	_race = null
	GameState.demo_mode = screen == "demo"
	match screen:
		"race", "demo":
			_race = Race.new()
			_race.process_mode = Node.PROCESS_MODE_PAUSABLE
			if screen == "demo":
				_race.track_id = randi() % Track.track_count()
				_race.reverse = randf() < 0.5
				_race.demo = true
				Audio.music("")
			else:
				var ct := GameState.current_track()
				_race.track_id = ct.id
				_race.reverse = ct.reverse
			_race.finished.connect(_on_race_finished.bind(screen == "demo"))
			_current = _race
		_:
			var sc: Screen = load(SCREENS[screen]).new()
			if screen == "awards":
				sc.lost_credit = _lost_credit
			sc.done.connect(goto)
			_current = sc
	add_child(_current)


func _on_race_finished(results: Array, demo: bool) -> void:
	if demo:
		goto("title")
		return
	_lost_credit = GameState.apply_results(results)
	goto("awards")


func _unhandled_input(event: InputEvent) -> void:
	if _race == null:
		return
	if _race.demo:
		if event.is_action_pressed("confirm"):
			goto("title")
		return
	if event.is_action_pressed("pause"):
		get_tree().paused = not get_tree().paused
