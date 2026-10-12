extends Screen
## Out of credits: classic 9-to-0 continue countdown.

const SECONDS := 10.0


func _ready() -> void:
	super()
	Audio.music("")


func _unhandled_input(event: InputEvent) -> void:
	if confirm_pressed(event) and time > 0.5:
		Audio.play("menu_select")
		GameState.continue_game()
		done.emit("shop")


func _process(delta: float) -> void:
	var before := int(SECONDS - time)
	super(delta)
	var after := int(SECONDS - time)
	if after != before and after >= 0:
		Audio.play("beep")
	if time >= SECONDS:
		set_process(false)
		GameState.add_hof(GameState.player_name, GameState.points, GameState.race_index)
		done.emit("hof")


func _draw() -> void:
	draw_rect(Rect2(0, 0, 320, 240), Color8(20, 0, 0))
	logo(70, "CONTINUE?", Color8(255, 160, 120), Color8(228, 56, 40), 24)
	var n := clampi(int(ceil(SECONDS - time)) - 1, 0, 9)
	logo(140, str(n), Color.WHITE, Color8(250, 214, 32), 32)
	if blink(0.4):
		centered(180, "PRESS START", Color.WHITE)
	centered(204, "POINTS %d" % GameState.points, Color8(180, 200, 255))
