extends Screen
## Speed Shop between races: buy nitro and upgrades, then race.

const ROW_H := 62

var _icons: Texture2D
var _rows: Array[Button] = []
var _focused := 0
var _flash := ""
var _flash_time := 0.0
var _cash_label: Label
var _lives_label: Label
var _desc_label: Label
var _race_button: Button


func _ready() -> void:
	super()
	_icons = load("res://assets/sprites/shop_icons.png")
	Audio.music("title")
	var ct := GameState.current_track()
	title("SPEED SHOP", 22, 40)

	# Header: driver, cash, lives, next race.
	panel(Rect2(24, 84, 912, 54))
	label(GameState.player_name, Vector2(44, 102), 16, GameState.TEAM_COLORS.red)
	_cash_label = label("", Vector2(250, 102), 16, UITheme.GREEN)
	_lives_label = label("", Vector2(520, 102), 16, Color.WHITE)
	label("RACE %d  -  %s%s  -  %d LAPS" % [GameState.race_index + 1, Track.track_name(ct.id),
		"  (REVERSE)" if ct.reverse else "", GameState.laps], Vector2(24, 146), 8, UITheme.SKY, 912,
		HORIZONTAL_ALIGNMENT_CENTER)

	# Item rows.
	var list := VBoxContainer.new()
	list.position = Vector2(24, 168)
	list.add_theme_constant_override("separation", 6)
	add_child(list)
	for i in GameState.SHOP_ITEMS.size():
		var it: Array = GameState.SHOP_ITEMS[i]
		var idx := i
		var b := button("", func(): _buy(idx), list, 600)
		b.custom_minimum_size.y = ROW_H - 6
		b.focus_entered.connect(func(): _focused = idx)
		b.mouse_entered.connect(func(): _focused = idx)
		_rows.append(b)
		var row := _ShopRow.new()
		row.item = it
		row.icon_tex = _icons
		row.icon_index = i
		row.size = Vector2(600, ROW_H - 6)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(row)

	# Right column: truck preview and stats.
	panel(Rect2(644, 168, 292, 290))
	var tp := TruckPreview.new()
	tp.position = Vector2(690, 176)
	tp.size = Vector2(200, 130)
	tp.zoom = 3.0
	add_child(tp)
	var stats := _Stats.new()
	stats.position = Vector2(664, 312)
	stats.size = Vector2(252, 130)
	add_child(stats)
	_desc_label = label("", Vector2(24, 486), 8, Color8(220, 220, 235), 600, HORIZONTAL_ALIGNMENT_CENTER)

	var hb := HBoxContainer.new()
	hb.position = Vector2(644, 470)
	hb.add_theme_constant_override("separation", 12)
	add_child(hb)
	_race_button = button("RACE!", func(): _leave("race"), hb, 160)
	_race_button.add_theme_stylebox_override("normal", UITheme.box(Color8(170, 30, 24), UITheme.YELLOW))
	button("MENU", func(): _leave("menu"), hb, 120)
	_race_button.call_deferred("grab_focus")
	_refresh()


func _buy(idx: int) -> void:
	var item: String = GameState.SHOP_ITEMS[idx][0]
	match GameState.buy(item):
		"ok":
			Audio.play("buy")
			_show("SOLD!")
		"life":
			Audio.play("buy")
			_show("A LIFE WAS TRADED FOR $200,000")
		"max":
			Audio.play("error")
			_show("ALREADY MAXED OUT")
		"broke":
			Audio.play("error")
			_show("NOT ENOUGH CASH")
	_refresh()


func _leave(next: String) -> void:
	GameState.save_career()
	done.emit(next)


func _show(s: String) -> void:
	_flash = s
	_flash_time = 1.6


func _refresh() -> void:
	_cash_label.text = "CASH " + money_str(GameState.money)
	_lives_label.text = "LIVES %d" % GameState.lives
	for r in _rows:
		r.get_child(0).queue_redraw()


func _process(delta: float) -> void:
	super(delta)
	_flash_time -= delta
	if _flash_time > 0.0:
		_desc_label.text = _flash
		_desc_label.add_theme_color_override("font_color", UITheme.YELLOW)
	else:
		var focus := get_viewport().gui_get_focus_owner()
		var desc := "BUY UPGRADES, THEN START THE RACE"
		if focus in _rows:
			desc = GameState.SHOP_ITEMS[_rows.find(focus)][4].to_upper()
		_desc_label.text = desc
		_desc_label.add_theme_color_override("font_color", Color8(220, 220, 235))


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color8(14, 14, 40))
	# Checkered bands top and bottom.
	for x in W / 12:
		for y in 2:
			var c := Color.WHITE if (x + y) % 2 == 0 else Color.BLACK
			draw_rect(Rect2(x * 12, y * 6, 12, 6), c)
			draw_rect(Rect2(x * 12, H - 12 + y * 6, 12, 6), c)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_leave("menu")


## Content drawn inside one shop row button.
class _ShopRow:
	extends Control
	var item: Array
	var icon_tex: Texture2D
	var icon_index := 0

	func _draw() -> void:
		var f: Font = GameState.font
		var h := size.y
		draw_texture_rect_region(icon_tex, Rect2(12, (h - 42) * 0.5, 42, 42), Rect2(icon_index * 42, 0, 42, 42))
		draw_string(f, Vector2(70, h * 0.5 - 2), item[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
		draw_string(f, Vector2(70, h * 0.5 + 18), Screen.money_str(item[2]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UITheme.GREEN)
		var lvl := GameState.level_of(item[0])
		if item[0] == "nitro":
			draw_string(f, Vector2(330, h * 0.5 + 8), "x%02d" % lvl, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UITheme.SKY)
		else:
			for p in item[3]:
				var r := Rect2(330 + p * 40, h * 0.5 - 10, 32, 20)
				draw_rect(r, UITheme.YELLOW if p < lvl else Color8(50, 50, 80))
				draw_rect(r, Color.BLACK, false, 2.0)


## Bars summarising the current truck.
class _Stats:
	extends Control

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var f: Font = GameState.font
		var rows := [["SPEED", "speed"], ["ACCEL", "accel"], ["GRIP", "tires"], ["SHOCKS", "shocks"]]
		for i in rows.size():
			var y := i * 30.0
			draw_string(f, Vector2(0, y + 14), rows[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)
			var lvl: int = GameState.upgrades.get(rows[i][1], 0)
			var w := size.x - 90.0
			draw_rect(Rect2(86, y + 4, w, 12), Color8(40, 40, 70))
			draw_rect(Rect2(86, y + 4, w * (lvl + 1) / 7.0, 12), UITheme.YELLOW.lerp(UITheme.RED, lvl / 6.0))
			draw_rect(Rect2(86, y + 4, w, 12), Color.BLACK, false, 2.0)
		draw_string(f, Vector2(0, 4 * 30.0 + 6), "NITRO x%d" % GameState.nitro, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UITheme.SKY)
