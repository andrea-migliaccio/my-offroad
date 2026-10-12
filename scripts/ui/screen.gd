class_name Screen
extends Control
## Base for full-screen menus. Builds Control widgets with the pixel theme,
## keeps keyboard focus and mouse hover in sync, and emits `done(next)` so that
## main.gd can switch screens.

signal done(next: String)

const W := 960
const H := 540

var time := 0.0
var _truck_tex := {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size = Vector2(W, H)
	theme = GameState.theme
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(delta: float) -> void:
	time += delta
	queue_redraw()


func blink(rate := 0.5) -> bool:
	return fmod(time, rate * 2.0) < rate


# --- widgets ----------------------------------------------------------------

func label(text: String, pos: Vector2, font_size := 16, color := Color.WHITE, width := 0.0,
		align := HORIZONTAL_ALIGNMENT_LEFT, parent: Node = null) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if width > 0.0:
		l.size.x = width
		l.horizontal_alignment = align
	(parent if parent else self).add_child(l)
	return l


## Big arcade-style heading with a thick outline, centred horizontally.
func title(text: String, y: float, font_size := 48, color := UITheme.YELLOW) -> Label:
	var l := label(text, Vector2(0, y), font_size, color, W, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_constant_override("outline_size", font_size / 4)
	l.add_theme_constant_override("shadow_offset_x", 4)
	l.add_theme_constant_override("shadow_offset_y", 4)
	return l


func button(text: String, callback: Callable, parent: Node = null, min_width := 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 40)
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func():
		Audio.play("menu_select")
		callback.call())
	b.mouse_entered.connect(func():
		if not b.disabled:
			b.grab_focus())
	b.focus_entered.connect(func(): Audio.play("menu_move", -6.0))
	(parent if parent else self).add_child(b)
	return b


## Vertical menu of [text, callable] pairs centred at y. Returns the container.
func menu(items: Array, y: float, width := 360.0) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.position = Vector2((W - width) * 0.5, y)
	box.size = Vector2(width, 0)
	add_child(box)
	for it in items:
		var b := button(it[0], it[1], box, width)
		if it.size() > 2 and it[2] == false:
			b.disabled = true
	_focus_first(box)
	return box


func panel(rect: Rect2) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	add_child(p)
	return p


func _focus_first(container: Node) -> void:
	for c in container.get_children():
		if c is Button and not c.disabled:
			c.call_deferred("grab_focus")
			return


# --- drawing helpers (podium, previews) ----------------------------------------

func text(pos: Vector2, s: String, color := Color.WHITE, font_size := 16, shadow := true) -> void:
	var f: Font = GameState.font
	if shadow:
		draw_string(f, pos + Vector2(2, 2), s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.85))
	draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func text_width(s: String, font_size := 16) -> float:
	return GameState.font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


func centered(y: float, s: String, color := Color.WHITE, font_size := 16) -> void:
	text(Vector2(roundf((W - text_width(s, font_size)) * 0.5), y), s, color, font_size)


func draw_truck(pos: Vector2, team: String, frame: int, pitch := 0, scale := 1.0) -> void:
	if not _truck_tex.has(team):
		_truck_tex[team] = load("res://assets/sprites/truck_%s.png" % team)
	var f := Truck.FRAME
	var src := Rect2((frame % Truck.HEADINGS) * f, pitch * f, f, f)
	var sz := Vector2(f, f) * scale
	draw_texture_rect_region(_truck_tex[team], Rect2(pos - sz * 0.5, sz), src)


static func frame_for_angle(angle: float) -> int:
	return int(round(fposmod(angle, TAU) / TAU * Truck.HEADINGS)) % Truck.HEADINGS


static func money_str(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-$" if v < 0 else "$") + s + out
