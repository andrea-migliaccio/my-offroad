extends Control
## In-race scoreboard: one box per truck along the top (name, place, lap, nitro),
## centre messages and floating pickup labels.

const ORD := ["1ST", "2ND", "3RD", "4TH"]
const BAR_H := 20

var race: Race
var _popups: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func popup(text: String, pos: Vector2, color: Color) -> void:
	_popups.append({"text": text, "pos": pos, "color": color, "t": 1.0})


func _process(delta: float) -> void:
	for p in _popups:
		p.t -= delta
		p.pos.y -= delta * 12.0
	_popups = _popups.filter(func(p): return p.t > 0.0)
	queue_redraw()


func text(pos: Vector2, s: String, color: Color, size := 8) -> void:
	var f: Font = GameState.font
	draw_string(f, pos + Vector2(1, 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.9))
	draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func centered(y: float, s: String, color: Color, size := 8) -> void:
	var f: Font = GameState.font
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	text(Vector2(round((Track.W - w) * 0.5), y), s, color, size)


func _draw() -> void:
	if race == null:
		return
	draw_rect(Rect2(0, 0, Track.W, BAR_H), Color(0, 0, 0))
	var ranked := race.ranking()
	var teams := ["red", "yellow", "blue", "gray"]
	for i in teams.size():
		var t: Truck = null
		for tr in race.trucks:
			if tr.team == teams[i]:
				t = tr
		if t == null:
			continue
		var col: Color = GameState.TEAM_COLORS[t.team]
		var x := i * 80
		draw_rect(Rect2(x + 1, 1, 78, BAR_H - 2), col.darkened(0.65))
		draw_rect(Rect2(x + 1, 1, 78, BAR_H - 2), col, false, 1.0)
		var place := ranked.find(t)
		text(Vector2(x + 4, 10), t.display_name.substr(0, 4), col)
		text(Vector2(x + 52, 10), ORD[place], Color.WHITE)
		var lap_n := clampi(t.lap + 1, 1, GameState.LAPS)
		text(Vector2(x + 4, 19), "L%d" % lap_n, Color.WHITE)
		text(Vector2(x + 36, 19), "N%02d" % mini(t.nitro_count, 99), Color8(140, 200, 255))
	for p in _popups:
		var c: Color = p.color
		c.a = clampf(p.t * 2.0, 0.0, 1.0)
		var f: Font = GameState.font
		var w := f.get_string_size(p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		text(p.pos - Vector2(w * 0.5, 0), p.text, c)
	if race.message_time > 0.0 and race.message != "":
		var y := 124.0
		centered(y, race.message, Color8(255, 236, 80), 16)
	if race.demo:
		if int(Time.get_ticks_msec() / 500) % 2 == 0:
			centered(228, "PRESS START", Color.WHITE)
	if get_tree().paused:
		centered(124, "PAUSED", Color.WHITE, 16)
