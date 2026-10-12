extends Screen
## Title / attract screen. Idle long enough and it runs a CPU demo race or shows
## the hall of fame, like the arcade attract loop.

const IDLE_TIME := 14.0

static var _attract_toggle := false
var _bg: Texture2D


func _ready() -> void:
	super()
	var t := Track.build(randi() % Track.track_count(), randf() < 0.5)
	_bg = t.background
	Audio.music("title")


func _unhandled_input(event: InputEvent) -> void:
	if confirm_pressed(event):
		Audio.play("menu_select")
		done.emit("name")


func _process(delta: float) -> void:
	super(delta)
	if time > IDLE_TIME:
		_attract_toggle = not _attract_toggle
		done.emit("demo" if _attract_toggle else "hof")
		set_process(false)


func _draw() -> void:
	draw_texture(_bg, Vector2.ZERO, Color(0.45, 0.45, 0.5))
	draw_rect(Rect2(0, 0, 320, 240), Color(0, 0, 0, 0.25))
	logo(64, "SUPER", Color8(255, 250, 160), Color8(250, 200, 30), 24)
	logo(100, "OFF-ROAD", Color8(255, 160, 120), Color8(228, 56, 40), 24)
	centered(118, "ARCADE REMAKE", Color8(200, 200, 210))
	# Trucks driving in a circle.
	var teams := ["red", "yellow", "blue", "gray"]
	for i in 4:
		var a := time * 1.4 + i * TAU / 4.0
		var p := Vector2(160, 160) + Vector2(cos(a) * 70.0, sin(a) * 18.0)
		var heading := a + PI / 2.0
		var frame := int(round(fposmod(heading, TAU) / TAU * 32.0)) % 32
		draw_truck(p, teams[i], frame)
	if blink(0.45):
		centered(204, "PRESS START", Color.WHITE)
	centered(222, "ARROWS STEER  UP/Z GAS  X NITRO", Color8(160, 160, 170))
	centered(234, "ENTER START", Color8(160, 160, 170))
