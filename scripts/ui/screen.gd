class_name Screen
extends Control
## Base for full-screen menus: pixel text helpers and a `done(next)` signal that
## main.gd uses to switch screens.

signal done(next: String)

var time := 0.0
var _truck_tex := {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = Vector2(320, 240)


func _process(delta: float) -> void:
	time += delta
	queue_redraw()


func text(pos: Vector2, s: String, color := Color.WHITE, size := 8, shadow := true) -> void:
	var f: Font = GameState.font
	if shadow:
		draw_string(f, pos + Vector2(1, 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.85))
	draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func text_width(s: String, size := 8) -> float:
	return GameState.font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


func centered(y: float, s: String, color := Color.WHITE, size := 8) -> void:
	text(Vector2(round((320 - text_width(s, size)) * 0.5), y), s, color, size)


func blink(rate := 0.5) -> bool:
	return fmod(time, rate * 2.0) < rate


## Arcade-style logo text: thick dark outline, colour gradient by row.
func logo(y: float, s: String, top: Color, bottom: Color, size := 24) -> void:
	var x := roundf((320 - text_width(s, size)) * 0.5)
	var f: Font = GameState.font
	for o in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2), Vector2(2, 2), Vector2(3, 3)]:
		draw_string(f, Vector2(x, y) + o, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color8(20, 10, 4))
	draw_string(f, Vector2(x, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, bottom)
	# Top half highlight: redraw clipped via a second pass slightly offset.
	draw_string(f, Vector2(x, y - 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, top.lerp(bottom, 0.4))


func draw_truck(pos: Vector2, team: String, frame: int, pitch := 0) -> void:
	if not _truck_tex.has(team):
		_truck_tex[team] = load("res://assets/sprites/truck_%s.png" % team)
	var src := Rect2((frame % 32) * 24, pitch * 24, 24, 24)
	draw_texture_rect_region(_truck_tex[team], Rect2(pos - Vector2(12, 12), Vector2(24, 24)), src)


func confirm_pressed(event: InputEvent) -> bool:
	return event.is_action_pressed("confirm") and not event.is_echo()
