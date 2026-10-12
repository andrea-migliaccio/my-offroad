extends Screen
## Out of lives: season summary and hall of fame entry.

var _rank := -1


func _ready() -> void:
	super()
	Audio.music("")
	Audio.play("lose")
	_rank = GameState.add_hof(GameState.player_name, GameState.points, GameState.race_index)
	GameState.delete_career()
	title("GAME OVER", 90, 64, Color8(236, 70, 44))
	panel(Rect2(250, 210, 460, 170))
	label(GameState.player_name, Vector2(250, 232), 16, UITheme.YELLOW, 460, HORIZONTAL_ALIGNMENT_CENTER)
	label("RACES   %d" % GameState.race_index, Vector2(300, 272), 16)
	label("POINTS  %d" % GameState.points, Vector2(300, 302), 16)
	var rank_text := "HALL OF FAME: #%d" % (_rank + 1) if _rank >= 0 else "NOT IN THE HALL OF FAME"
	label(rank_text, Vector2(250, 342), 16, UITheme.GREEN if _rank >= 0 else UITheme.GRAY, 460,
		HORIZONTAL_ALIGNMENT_CENTER)
	var hb := HBoxContainer.new()
	hb.position = Vector2(250, 420)
	hb.add_theme_constant_override("separation", 20)
	add_child(hb)
	var b := button("HALL OF FAME", func(): done.emit("hof"), hb, 220)
	button("MAIN MENU", func(): done.emit("menu"), hb, 220)
	b.call_deferred("grab_focus")


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color8(24, 4, 4))
