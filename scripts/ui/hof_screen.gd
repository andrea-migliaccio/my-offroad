extends Screen
## Hall of fame (top 10, saved in user://).


func _ready() -> void:
	super()
	title("HALL OF FAME", 30, 40)
	panel(Rect2(180, 100, 600, 370))
	var cols := [210, 300, 520, 670]
	var heads := ["RANK", "NAME", "POINTS", "RACES"]
	for i in 4:
		label(heads[i], Vector2(cols[i], 120), 16, UITheme.SKY)
	var medal := [UITheme.YELLOW, Color8(220, 220, 230), Color8(230, 150, 70)]
	var list := GameState.load_hof()
	for i in list.size():
		var e: Dictionary = list[i]
		var y := 156 + i * 30
		var c: Color = medal[i] if i < 3 else Color.WHITE
		label("%2d" % (i + 1), Vector2(cols[0] + 16, y), 16, c)
		label(str(e.name), Vector2(cols[1], y), 16, c)
		label("%6d" % e.points, Vector2(cols[2], y), 16, c)
		label("%3d" % e.races, Vector2(cols[3] + 16, y), 16, c)
	var b := button("BACK", func(): done.emit("menu"), self, 200)
	b.position = Vector2(380, 484)
	b.call_deferred("grab_focus")


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color8(8, 8, 26))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		done.emit("menu")
