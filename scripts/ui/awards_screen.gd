extends Screen
## Race results: podium, prize money and pickup bonus.

var lost_life := false
var _trophy: Texture2D


func _ready() -> void:
	super()
	_trophy = load("res://assets/sprites/trophy.png")
	var player := _player()
	if player and player.position == 1:
		Audio.music("ending")
	elif lost_life:
		Audio.play("lose")
	title("RACE RESULTS", 18, 32)

	panel(Rect2(140, 262, 680, 196))
	var cols := [Vector2(170, 280), Vector2(260, 280), Vector2(470, 280), Vector2(640, 280)]
	var heads := ["POS", "DRIVER", "PRIZE", "BONUS"]
	for i in 4:
		label(heads[i], cols[i], 16, UITheme.SKY)
	var res := GameState.last_results
	for i in res.size():
		var r: Dictionary = res[i]
		var y := 316 + i * 32
		var c: Color = UITheme.YELLOW if r.is_player else Color.WHITE
		label("%d" % r.position, Vector2(cols[0].x, y), 16, c)
		label(r.name, Vector2(cols[1].x, y), 16, GameState.TEAM_COLORS[r.team])
		label(money_str(r.prize), Vector2(cols[2].x, y), 16, UITheme.GREEN)
		label(money_str(r.bonus), Vector2(cols[3].x, y), 16, UITheme.YELLOW)

	if player:
		label("CASH " + money_str(GameState.money) + "      LIVES %d" % GameState.lives, Vector2(0, 470), 16,
			Color.WHITE, W, HORIZONTAL_ALIGNMENT_CENTER)
		var msg := ""
		var mcol := UITheme.YELLOW
		if lost_life:
			msg = "4TH PLACE - YOU LOSE A LIFE" if GameState.lives > 0 else "4TH PLACE - NO LIVES LEFT"
			mcol = UITheme.RED
		elif player.position == 1:
			msg = "WINNER!"
		label(msg, Vector2(0, 494), 16, mcol, W, HORIZONTAL_ALIGNMENT_CENTER)
	var b := button("CONTINUE", _next, self, 220)
	b.position = Vector2(W - 250, H - 52)
	b.call_deferred("grab_focus")


func _player() -> Dictionary:
	for r in GameState.last_results:
		if r.is_player:
			return r
	return {}


func _next() -> void:
	done.emit("gameover" if GameState.lives <= 0 else "shop")


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color8(10, 14, 34))
	# Spotlight cone behind the podium.
	draw_colored_polygon(PackedVector2Array([Vector2(420, 60), Vector2(540, 60), Vector2(700, 250), Vector2(260, 250)]),
		Color(1, 1, 0.8, 0.05))
	var heights := [86, 62, 44]
	var xs := [480, 370, 590]
	var res := GameState.last_results
	for i in mini(3, res.size()):
		var h: int = heights[i]
		var x: int = xs[i]
		var top := 248 - h
		draw_rect(Rect2(x - 52, top, 104, h), Color8(140, 140, 156))
		draw_rect(Rect2(x - 52, top, 104, 6), Color8(200, 200, 214))
		draw_rect(Rect2(x - 52, top, 104, h), Color8(40, 40, 50), false, 2.0)
		text(Vector2(x - 12, top + 40), str(i + 1), Color8(40, 40, 50), 32, false)
		var bounce := absf(sin(time * 4.0 + i)) * (6.0 if i == 0 else 2.0)
		draw_truck(Vector2(x, top - 22 - bounce), res[i].team, Truck.HEADINGS / 4, 0, 1.5)
	draw_texture(_trophy, Vector2(459, 78 + absf(sin(time * 2.0)) * 4.0))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_next()
