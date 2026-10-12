extends Screen
## Speed Shop between races: buy nitro and upgrades, then race.

var _cursor := 0
var _icons: Texture2D
var _flash := ""
var _flash_time := 0.0
var _track_name := ""
var _reverse := false


func _ready() -> void:
	super()
	_icons = load("res://assets/sprites/shop_icons.png")
	var ct := GameState.current_track()
	_reverse = ct.reverse
	_track_name = Track._load_json()[ct.id].name
	Audio.music("title")
	_cursor = GameState.SHOP_ITEMS.size()  # start on RACE


func _rows() -> int:
	return GameState.SHOP_ITEMS.size() + 1


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up"):
		_cursor = (_cursor - 1 + _rows()) % _rows()
		Audio.play("menu_move")
	elif event.is_action_pressed("ui_down"):
		_cursor = (_cursor + 1) % _rows()
		Audio.play("menu_move")
	elif confirm_pressed(event):
		if _cursor >= GameState.SHOP_ITEMS.size():
			Audio.play("menu_select")
			done.emit("race")
			return
		var item: String = GameState.SHOP_ITEMS[_cursor][0]
		var r := GameState.buy(item)
		match r:
			"ok":
				Audio.play("buy")
				_show("SOLD!")
			"credit":
				Audio.play("buy")
				_show("CREDIT CASHED $200K")
			"max":
				Audio.play("error")
				_show("MAXED OUT")
			"broke":
				Audio.play("error")
				_show("NOT ENOUGH CASH")


func _show(s: String) -> void:
	_flash = s
	_flash_time = 1.4


func _process(delta: float) -> void:
	super(delta)
	_flash_time -= delta


static func money_str(v: int) -> String:
	var s := str(v)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return "$" + s + out


func _draw() -> void:
	draw_rect(Rect2(0, 0, 320, 240), Color8(16, 16, 40))
	# Checkered header band.
	for x in 40:
		for y in 2:
			draw_rect(Rect2(x * 8, y * 4, 8, 4), Color.WHITE if (x + y) % 2 == 0 else Color.BLACK)
	logo(30, "SPEED SHOP", Color8(255, 250, 160), Color8(250, 200, 30), 16)
	text(Vector2(8, 46), GameState.player_name, GameState.TEAM_COLORS.red)
	text(Vector2(48, 46), money_str(GameState.money), Color8(120, 255, 120))
	text(Vector2(200, 46), "CREDITS %d" % GameState.credits, Color.WHITE)
	text(Vector2(8, 58), "RACE %d: %s%s" % [GameState.race_index + 1, _track_name, " REV" if _reverse else ""], Color8(180, 200, 255))

	for i in GameState.SHOP_ITEMS.size():
		var it: Array = GameState.SHOP_ITEMS[i]
		var y := 72 + i * 26
		var sel := i == _cursor
		draw_rect(Rect2(6, y - 2, 308, 24), Color8(60, 60, 120) if sel else Color8(30, 30, 64))
		if sel:
			draw_rect(Rect2(6, y - 2, 308, 24), Color8(250, 214, 32), false, 1.0)
		draw_texture_rect_region(_icons, Rect2(10, y + 3, 14, 14), Rect2(i * 14, 0, 14, 14))
		text(Vector2(30, y + 9), it[1], Color.WHITE)
		text(Vector2(30, y + 19), money_str(it[2]), Color8(120, 255, 120))
		var lvl := GameState.level_of(it[0])
		if it[0] == "nitro":
			text(Vector2(150, y + 14), "x%02d" % lvl, Color8(140, 200, 255))
		else:
			for p in it[3]:
				var r := Rect2(150 + p * 14, y + 6, 11, 10)
				draw_rect(r, Color8(250, 214, 32) if p < lvl else Color8(50, 50, 80))
				draw_rect(r, Color.BLACK, false, 1.0)
	var ry := 72 + GameState.SHOP_ITEMS.size() * 26
	var rsel := _cursor >= GameState.SHOP_ITEMS.size()
	draw_rect(Rect2(100, ry, 120, 18), Color8(200, 40, 30) if rsel else Color8(90, 20, 20))
	if rsel:
		draw_rect(Rect2(100, ry, 120, 18), Color8(250, 214, 32), false, 1.0)
	centered(ry + 13, "RACE!" if not rsel or blink(0.3) else "RACE!", Color.WHITE)
	draw_truck(Vector2(280, 36), "red", int(time * 6.0) % 32)
	if _flash_time > 0.0:
		draw_rect(Rect2(40, 110, 240, 20), Color(0, 0, 0, 0.85))
		centered(124, _flash, Color8(250, 214, 32))
