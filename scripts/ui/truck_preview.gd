class_name TruckPreview
extends Control
## Spinning truck sprite for menus (drawn above the panels it sits on).

var team := "red"
var spin := 1.5
var zoom := 2.0
var bounce := 0.0
var _tex: Texture2D
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tex = load("res://assets/sprites/truck_%s.png" % team)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var f := Truck.FRAME
	var frame := Screen.frame_for_angle(_t * spin) if spin != 0.0 else 16
	var sz := Vector2(f, f) * zoom
	var off := Vector2(0, -absf(sin(_t * 4.0)) * bounce)
	draw_texture_rect_region(_tex, Rect2(size * 0.5 - sz * 0.5 + off, sz), Rect2(frame * f, 0, f, f))
