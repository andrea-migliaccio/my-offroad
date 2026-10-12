extends Screen
## Race results: podium, prize money and pickup bonus.

var lost_credit := false
var _trophy: Texture2D


func _ready() -> void:
	super()
	_trophy = load("res://assets/sprites/trophy.png")
	var player := _player()
	if player and player.position == 1:
		Audio.music("ending")
	elif lost_credit:
		Audio.play("lose")


func _player() -> Dictionary:
	for r in GameState.last_results:
		if r.is_player:
			return r
	return {}


func _unhandled_input(event: InputEvent) -> void:
	if confirm_pressed(event) and time > 1.0:
		_next()


func _process(delta: float) -> void:
	super(delta)
	if time > 9.0:
		_next()
		set_process(false)


func _next() -> void:
	Audio.play("menu_select")
	if GameState.credits <= 0:
		done.emit("continue")
	else:
		done.emit("shop")


func _draw() -> void:
	draw_rect(Rect2(0, 0, 320, 240), Color8(10, 14, 30))
	logo(26, "RACE RESULTS", Color8(255, 250, 160), Color8(250, 200, 30), 16)
	# Podium.
	var heights := [36, 26, 18]
	var xs := [160, 110, 210]
	var res := GameState.last_results
	for i in mini(3, res.size()):
		var h: int = heights[i]
		var x: int = xs[i]
		var top := 110 - h
		draw_rect(Rect2(x - 22, top, 44, h), Color8(140, 140, 156))
		draw_rect(Rect2(x - 22, top, 44, 3), Color8(200, 200, 214))
		draw_rect(Rect2(x - 22, top, 44, h), Color8(40, 40, 50), false, 1.0)
		text(Vector2(x - 4, top + 14), str(i + 1), Color8(40, 40, 50), 8, false)
		var bounce := absf(sin(time * 4.0 + i)) * (3.0 if i == 0 else 1.0)
		draw_truck(Vector2(x, top - 8 - bounce), res[i].team, 8)
	draw_texture(_trophy, Vector2(153, 34 + absf(sin(time * 2.0)) * 2.0))
	# Table.
	text(Vector2(14, 128), "POS NAME   PRIZE    BONUS", Color8(180, 200, 255))
	for i in res.size():
		var r: Dictionary = res[i]
		var y := 142 + i * 13
		var col: Color = GameState.TEAM_COLORS[r.team]
		if r.is_player:
			draw_rect(Rect2(8, y - 9, 304, 12), Color(1, 1, 1, 0.12))
		text(Vector2(14, y), "%d" % r.position, Color.WHITE)
		text(Vector2(46, y), r.name, col)
		text(Vector2(102, y), "$%dK" % (r.prize / 1000), Color8(120, 255, 120))
		text(Vector2(174, y), "$%dK" % (r.bonus / 1000), Color8(250, 214, 32))
	var y2 := 204
	var player := _player()
	if player:
		text(Vector2(14, y2), "CASH " + preload("res://scripts/ui/shop_screen.gd").money_str(GameState.money), Color8(120, 255, 120))
		text(Vector2(200, y2), "CREDITS %d" % GameState.credits, Color.WHITE)
		if lost_credit and blink(0.4):
			centered(220, "4TH PLACE! YOU LOSE A CREDIT", Color8(228, 56, 40))
		elif player.position == 1:
			centered(220, "WINNER!", Color8(250, 214, 32))
	if time > 1.0:
		centered(234, "PRESS START", Color8(160, 160, 170))
