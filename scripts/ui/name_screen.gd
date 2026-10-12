extends Screen
## Enter three initials, arcade style.

const LETTERS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789."

var _chars := [0, 0, 0]
var _pos := 0


func _ready() -> void:
	super()
	var prev := GameState.player_name
	for i in 3:
		var c := prev[i] if i < prev.length() else "A"
		_chars[i] = maxi(0, LETTERS.find(c))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up") or event.is_action_pressed("steer_right"):
		_chars[_pos] = (_chars[_pos] + 1) % LETTERS.length()
		Audio.play("menu_move")
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("steer_left"):
		_chars[_pos] = (_chars[_pos] - 1 + LETTERS.length()) % LETTERS.length()
		Audio.play("menu_move")
	elif event.is_action_pressed("ui_cancel") and _pos > 0:
		_pos -= 1
	elif confirm_pressed(event):
		Audio.play("menu_select")
		_pos += 1
		if _pos >= 3:
			GameState.new_game()
			GameState.player_name = "".join(_chars.map(func(i): return LETTERS[i]))
			done.emit("shop")


func _draw() -> void:
	draw_rect(Rect2(0, 0, 320, 240), Color8(10, 10, 24))
	logo(48, "DRIVER", Color8(255, 250, 160), Color8(250, 200, 30), 16)
	centered(80, "ENTER YOUR INITIALS", Color.WHITE)
	for i in 3:
		var x := 112 + i * 36
		var col := Color8(250, 214, 32) if i == _pos else Color.WHITE
		if i == _pos and blink(0.25):
			col = Color8(228, 56, 40)
		text(Vector2(x, 130), LETTERS[_chars[i]], col, 24)
		draw_rect(Rect2(x - 2, 136, 28, 2), col)
	draw_truck(Vector2(160, 170), "red", int(time * 8.0) % 32)
	centered(200, "LEFT/RIGHT: LETTER", Color8(160, 160, 170))
	centered(212, "ENTER: NEXT", Color8(160, 160, 170))
