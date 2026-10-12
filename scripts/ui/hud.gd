extends Control
## In-race HUD: translucent corner panels instead of the arcade top bar.
##   top-left: lap and times     top-right: live standings
##   bottom-left: nitro + bonus  bottom-right: your position
## plus big centre messages and floating pickup labels.

const ORD := ["1ST", "2ND", "3RD", "4TH"]
const W := 960
const H := 540
const M := 14  # screen margin

var race: Race
var _popups: Array = []
var _box: StyleBoxFlat
var _nitro_icon: Texture2D


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nitro_icon = load("res://assets/sprites/nitro_small.png")
	_box = StyleBoxFlat.new()
	_box.bg_color = Color(0.02, 0.02, 0.06, 0.62)
	_box.border_color = Color(1, 1, 1, 0.22)
	_box.set_border_width_all(2)


func popup(s: String, pos: Vector2, color: Color) -> void:
	_popups.append({"text": s, "pos": pos, "color": color, "t": 1.2})


func _process(delta: float) -> void:
	for p in _popups:
		p.t -= delta
		p.pos.y -= delta * 28.0
	_popups = _popups.filter(func(p): return p.t > 0.0)
	queue_redraw()


func text(pos: Vector2, s: String, color: Color, size := 16, outline := 0) -> void:
	var f: Font = GameState.font
	if outline > 0:
		draw_string_outline(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, Color(0, 0, 0))
	else:
		draw_string(f, pos + Vector2(2, 2), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.8))
	draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func width(s: String, size := 16) -> float:
	return GameState.font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


static func time_str(t: float) -> String:
	return "%d:%05.2f" % [int(t) / 60, fmod(t, 60.0)]


func _draw() -> void:
	if race == null:
		return
	var ranked := race.ranking()
	var player := race.player_truck
	var laps := GameState.laps

	# Top-left: lap counter and timing.
	if player:
		draw_style_box(_box, Rect2(M, M, 268, 86))
		text(Vector2(M + 14, M + 22), "LAP", UITheme.GRAY, 8)
		var lap_n := clampi(player.lap + 1, 1, laps)
		text(Vector2(M + 14, M + 54), "%d/%d" % [lap_n, laps], Color.WHITE, 32)
		text(Vector2(M + 140, M + 32), time_str(race.race_time), Color.WHITE, 16)
		var best := "--:--.--"
		if not race.lap_times.is_empty():
			best = time_str(race.lap_times.min())
		text(Vector2(M + 140, M + 52), "BEST", UITheme.GRAY, 8)
		text(Vector2(M + 140, M + 70), best, UITheme.YELLOW, 8)

	# Top-right: standings.
	var sw := 236.0
	var sx := W - M - sw
	draw_style_box(_box, Rect2(sx, M, sw, 22 + ranked.size() * 24))
	for i in ranked.size():
		var t: Truck = ranked[i]
		var y := M + 30 + i * 24
		var col: Color = GameState.TEAM_COLORS[t.team]
		if t == player:
			draw_rect(Rect2(sx + 4, y - 16, sw - 8, 22), Color(1, 1, 1, 0.12))
		text(Vector2(sx + 12, y), str(i + 1), Color.WHITE, 16)
		draw_rect(Rect2(sx + 38, y - 14, 14, 14), col)
		draw_rect(Rect2(sx + 38, y - 14, 14, 14), Color.BLACK, false, 2.0)
		text(Vector2(sx + 60, y), t.display_name.substr(0, 6), col, 8)
		text(Vector2(sx + 140, y), "L%d" % clampi(t.lap + 1, 1, laps), Color.WHITE, 8)
		text(Vector2(sx + 180, y), "N%d" % t.nitro_count, UITheme.SKY, 8)

	if player:
		# Bottom-left: nitro canisters and money picked up this race.
		var bw := 300.0
		draw_style_box(_box, Rect2(M, H - M - 66, bw, 66))
		text(Vector2(M + 14, H - M - 46), "NITRO", UITheme.GRAY, 8)
		var n := player.nitro_count
		for k in mini(n, 10):
			draw_texture_rect(_nitro_icon, Rect2(M + 14 + k * 22, H - M - 38, 18, 22), false)
		if n > 10:
			text(Vector2(M + 14 + 10 * 22 + 4, H - M - 20), "+%d" % (n - 10), UITheme.SKY, 8)
		if n == 0:
			text(Vector2(M + 14, H - M - 20), "EMPTY", UITheme.RED, 8)
		var bonus := "$%dK" % (player.bonus / 1000)
		text(Vector2(M + bw - 14 - width(bonus, 16), H - M - 20), bonus, UITheme.YELLOW, 16)
		text(Vector2(M + bw - 14 - width("BONUS", 8), H - M - 46), "BONUS", UITheme.GRAY, 8)

		# Bottom-right: big position.
		var place := ranked.find(player)
		var pw := 200.0
		draw_style_box(_box, Rect2(W - M - pw, H - M - 80, pw, 80))
		var ps: String = ORD[place]
		var pcol := UITheme.YELLOW if place == 0 else (UITheme.RED if place == 3 else Color.WHITE)
		var px := W - M - pw + 16
		text(Vector2(px, H - M - 18), ps, pcol, 48, 8)
		text(Vector2(px + width(ps, 48) + 6, H - M - 18), "/%d" % ranked.size(), UITheme.GRAY, 16)

	for p in _popups:
		var c: Color = p.color
		c.a = clampf(p.t * 2.0, 0.0, 1.0)
		text(p.pos - Vector2(width(p.text, 16) * 0.5, 0), p.text, c, 16, 4)

	if race.message_time > 0.0 and race.message != "":
		var size := 48
		var msg := race.message
		var pulse := 1.0 + 0.06 * sin(Time.get_ticks_msec() * 0.02)
		text(Vector2(roundf((W - width(msg, size)) * 0.5), H * 0.5 + 16), msg,
			UITheme.YELLOW.lerp(Color.WHITE, pulse - 1.0), size, 10)
