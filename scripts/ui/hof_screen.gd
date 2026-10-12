extends Screen
## Hall of fame (top 10, saved in user://).

var _list: Array = []


func _ready() -> void:
	super()
	_list = GameState.load_hof()


func _unhandled_input(event: InputEvent) -> void:
	if confirm_pressed(event):
		Audio.play("menu_select")
		done.emit("title")


func _process(delta: float) -> void:
	super(delta)
	if time > 8.0:
		set_process(false)
		done.emit("title")


func _draw() -> void:
	draw_rect(Rect2(0, 0, 320, 240), Color8(8, 8, 24))
	logo(34, "HALL OF FAME", Color8(255, 250, 160), Color8(250, 200, 30), 16)
	text(Vector2(40, 56), "RANK NAME  POINTS RACES", Color8(180, 200, 255))
	var cols := [Color8(250, 214, 32), Color8(220, 220, 230), Color8(230, 150, 70)]
	for i in _list.size():
		var e: Dictionary = _list[i]
		var y := 72 + i * 14
		var c: Color = cols[i] if i < 3 else Color.WHITE
		var mine: bool = e.name == GameState.player_name and e.points == GameState.points
		if mine and blink(0.25):
			c = Color8(228, 56, 40)
		text(Vector2(48, y), "%2d" % (i + 1), c)
		text(Vector2(80, y), str(e.name), c)
		text(Vector2(136, y), "%6d" % e.points, c)
		text(Vector2(208, y), "%3d" % e.races, c)
