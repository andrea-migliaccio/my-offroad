extends Node
## Headless checks for season logic: save/load, lives, life-for-cash trade.
## godot --headless --path . res://tests/career_test.tscn

var _fails := 0


func check(cond: bool, what: String) -> void:
	print(("OK   " if cond else "FAIL ") + what)
	if not cond:
		_fails += 1


func _result(position: int) -> Array:
	var r := []
	for i in 4:
		r.append({"team": GameState.TEAMS[i], "name": "X", "position": i + 1, "prize": GameState.PRIZES[i],
			"bonus": 0, "is_player": i + 1 == position, "nitro_left": 1})
	return r


func _ready() -> void:
	# Keep the player's real save and hall of fame untouched.
	var backup := {}
	for path in [GameState.CAREER_PATH, GameState.HOF_PATH]:
		if FileAccess.file_exists(path):
			backup[path] = FileAccess.get_file_as_bytes(path)

	GameState.new_game()
	GameState.player_name = "TESTER"
	check(GameState.lives == 3 and GameState.money == 100_000, "new season: 3 lives, $100K")
	check(GameState.buy("tires") == "ok" and GameState.upgrades.tires == 1, "buy tires")
	check(GameState.buy("speed") == "life" and GameState.lives == 2, "short of cash trades a life")
	var lost := GameState.apply_results(_result(1))
	check(not lost and GameState.race_index == 1 and GameState.has_career(), "win: no life lost, autosaved")
	var money := GameState.money
	GameState.new_game()
	check(GameState.load_career() and GameState.money == money and GameState.player_name == "TESTER"
		and GameState.upgrades.speed == 1, "load restores money, name and upgrades")
	check(GameState.current_track().id == 1, "race 2 is track 1")
	GameState.lives = 1
	while GameState.money >= 10_000:
		GameState.buy("nitro")
	check(GameState.buy("tires") == "broke", "last life is never traded")
	lost = GameState.apply_results(_result(4))
	check(lost and GameState.lives == 0 and not GameState.has_career(), "4th with 1 life: game over, save deleted")
	GameState.race_index = Track.track_count()
	check(GameState.current_track().reverse, "second half of the season is reversed")
	var rank := GameState.add_hof("TESTER", 99999, 5)
	check(rank == 0, "hall of fame entry ranked first")

	for path in [GameState.CAREER_PATH, GameState.HOF_PATH]:
		if backup.has(path):
			var f := FileAccess.open(path, FileAccess.WRITE)
			f.store_buffer(backup[path])
		elif FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("CAREER_DONE failures=%d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)
