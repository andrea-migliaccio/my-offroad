class_name Race
extends Node2D
## One race: builds the track, places 4 trucks, runs countdown, laps, pickups,
## collisions and ranking. Emits `finished(results)` when the first truck has
## completed GameState.laps laps (like the arcade, the others are ranked by
## where they are at that moment).

signal finished(results: Array)

enum State { COUNTDOWN, RACING, FINISHED }

const TRUCK_RADIUS := 8.0
const PICKUP_MAX := 2

var track_id := 0
var reverse := false
var demo := false
var show_hud := true

var track: Track
var trucks: Array[Truck] = []
var player_truck: Truck
var pickups: Array[Pickup] = []
var state := State.COUNTDOWN
var race_time := 0.0
var lap_times: Array[float] = []  # player's completed laps
var _lap_start := 0.0
var _player_lap := -1
var message := ""
var message_time := 0.0

var _marks_img: Image
var _marks_tex: ImageTexture
var _marks_dirty := false
var _crowd: Sprite2D
var _flagman: Sprite2D
var _flag_frame := 0
var _countdown := 3.6
var _beeps := 3
var _spawn_timer := 3.0
var _finish_timer := 0.0
var _results: Array = []
var _final_lap_announced := false
var _entities: Node2D
var hud: Control


func _ready() -> void:
	track = Track.build(track_id, reverse)
	var bg := Sprite2D.new()
	bg.texture = track.background
	bg.centered = false
	bg.z_index = -4000
	add_child(bg)
	_crowd = Sprite2D.new()
	_crowd.texture = track.crowd_frames[0]
	_crowd.centered = false
	_crowd.z_index = -3999
	add_child(_crowd)
	_marks_img = Image.create(Track.W, Track.H, false, Image.FORMAT_RGBA8)
	_marks_tex = ImageTexture.create_from_image(_marks_img)
	var marks := Sprite2D.new()
	marks.texture = _marks_tex
	marks.centered = false
	marks.z_index = -3998
	add_child(marks)
	_entities = Node2D.new()
	add_child(_entities)
	_add_sponsors()
	_place_flagman()
	_spawn_trucks()
	hud = preload("res://scripts/ui/hud.gd").new()
	hud.race = self
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.visible = show_hud
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	layer.add_child(hud)
	show_message("GET READY", 2.0)
	if not demo:
		Audio.music(["race1", "race2", "race3"][track_id % 3])


func _spawn_trucks() -> void:
	var order := ["gray", "blue", "red", "yellow"]
	var slot := 0
	for team in order:
		var row := slot / 2
		var col := slot % 2
		var s := track.length - 26.0 - row * 46.0
		var p := track.sample_at_s(s)
		var tan := track.tangent_at_s(s)
		var nrm := Vector2(-tan.y, tan.x)
		var t := Truck.new()
		t.position = p + nrm * (-14.0 if col == 0 else 14.0)
		t.heading = tan.angle()
		t.race = self
		var is_player: bool = team == GameState.player_team and not demo
		t.is_player = is_player
		if is_player:
			t.setup(track, team, GameState.player_name, GameState.upgrades, GameState.nitro)
			t.controller = PlayerInput.new()
			player_truck = t
		else:
			var ups: Dictionary = GameState.cpu_upgrades.get(team, {})
			t.setup(track, team, GameState.CPU_NAMES[team], ups, GameState.cpu_nitro.get(team, 2))
			var ai := AIDriver.new()
			ai.race = self
			ai.lane = [-12.0, 12.0, -5.0, 5.0][slot]
			var d := GameState.difficulty_ramp()
			ai.base_skill = (0.9 + 0.08 * d) if team == "gray" else (0.84 + 0.1 * d + randf_range(-0.02, 0.02))
			ai.base_skill += GameState.ai_skill_offset()
			ai.rubber_band = team == "gray" and not demo
			ai.rubber_scale = GameState.rubber_band_scale()
			t.controller = ai
		t.lap = -1
		trucks.append(t)
		_entities.add_child(t)
		slot += 1


const SPONSORS := ["TURBO OIL", "MUD KING", "BIG WHEELS", "NITRO-X", "DUSTY'S", "ROCK CAFE", "4X4 MAG", "OFFROAD TV"]


## Sponsor names on the advertising boards along the back wall.
func _add_sponsors() -> void:
	var ink := [Color8(255, 240, 220), Color8(200, 30, 30), Color8(250, 214, 32), Color8(30, 40, 120)]
	for b in Track.W / Track.BOARD_W:
		var l := Label.new()
		l.theme = GameState.theme
		l.text = SPONSORS[(b + track_id) % SPONSORS.size()]
		l.position = Vector2(b * Track.BOARD_W, Track.STANDS_BOTTOM + 2)
		l.size = Vector2(Track.BOARD_W, Track.FIELD_TOP - Track.STANDS_BOTTOM - 4)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 8)
		l.add_theme_color_override("font_color", ink[b % ink.size()])
		l.add_theme_constant_override("shadow_offset_x", 0)
		l.add_theme_constant_override("shadow_offset_y", 0)
		l.z_index = -3990
		add_child(l)


func _place_flagman() -> void:
	var p := track.sample_at_s(0.0)
	var tan := track.tangent_at_s(0.0)
	var nrm := Vector2(-tan.y, tan.x)
	# Stand on whichever side has more open infield.
	var pos := p + nrm * (Track.HALF_WIDTH + 26.0)
	for side: float in [1.0, -1.0]:
		var c := p + nrm * side * (Track.HALF_WIDTH + 26.0)
		var far := c + nrm * side * 24.0
		if track.surface_at(c) == Track.Surface.INFIELD and track.surface_at(far) == Track.Surface.INFIELD:
			pos = c
			break
	_flagman = Sprite2D.new()
	_flagman.texture = load("res://assets/sprites/flagman.png")
	_flagman.hframes = 8
	_flagman.offset = Vector2(0, -22)
	_flagman.position = Vector2(pos.x, pos.y - track.height_at(pos))
	_flagman.z_index = int(pos.y)
	add_child(_flagman)


func _sfx(sfx_name: String, volume_db := 0.0, pitch := 1.0, min_gap := 0.05) -> void:
	if not demo:
		Audio.play(sfx_name, volume_db, pitch, min_gap)


func show_message(text: String, duration: float) -> void:
	message = text
	message_time = duration


func add_mark(ground_pos: Vector2, h: float) -> void:
	var x := int(ground_pos.x)
	var y := int(ground_pos.y - h)
	if x < 0 or y < 0 or x >= Track.W or y >= Track.H:
		return
	for o in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		var px := mini(x + o.x, Track.W - 1)
		var py := mini(y + o.y, Track.H - 1)
		var c := _marks_img.get_pixel(px, py)
		_marks_img.set_pixel(px, py, Color(0.22, 0.13, 0.06, minf(0.5, c.a + 0.12)))
	_marks_dirty = true


func _process(delta: float) -> void:
	message_time -= delta
	_crowd.texture = track.crowd_frames[int(Time.get_ticks_msec() / 300) % 2]
	if _marks_dirty and Engine.get_process_frames() % 3 == 0:
		_marks_tex.update(_marks_img)
		_marks_dirty = false
	_update_flagman()


func _update_flagman() -> void:
	var blink := int(Time.get_ticks_msec() / 180) % 2
	match state:
		State.COUNTDOWN:
			_flag_frame = 0 if _countdown > 0.6 else 2
		State.RACING:
			var leader_lap := 0
			for t in trucks:
				leader_lap = maxi(leader_lap, t.lap)
			if race_time < 2.0:
				_flag_frame = 2 + blink
			elif leader_lap >= GameState.laps - 1:
				_flag_frame = 4 + blink
			else:
				_flag_frame = 0
		State.FINISHED:
			_flag_frame = 6 + blink
	_flagman.frame = _flag_frame


func _physics_process(delta: float) -> void:
	match state:
		State.COUNTDOWN:
			_countdown -= delta
			var n := int(ceil(_countdown - 0.6))
			if n < _beeps and n >= 0:
				_beeps = n
				if n > 0:
					_sfx("beep")
					show_message(str(n), 0.8)
			if _countdown <= 0.6:
				state = State.RACING
				for t in trucks:
					t.frozen = false
				_sfx("beep_go")
				show_message("GO!", 1.0)
		State.RACING:
			race_time += delta
			_spawn_pickups(delta)
		State.FINISHED:
			_finish_timer -= delta
			if _finish_timer <= 0.0 and _results.size() > 0:
				var r := _results
				_results = []
				finished.emit(r)

	for t in trucks:
		t.physics_step(delta)
	_collide_trucks()
	_collect_pickups()
	if state == State.RACING:
		_check_laps()


func _collide_trucks() -> void:
	var n := trucks.size()
	for i in n:
		for j in range(i + 1, n):
			var a := trucks[i]
			var b := trucks[j]
			if absf(a.altitude - b.altitude) > 7.0 * Truck.U:
				continue
			var d := b.position - a.position
			var dist := d.length()
			var min_d := TRUCK_RADIUS * 2.0
			if dist >= min_d or dist < 0.001:
				continue
			var nrm := d / dist
			var push := (min_d - dist) * 0.5
			a.position -= nrm * push
			b.position += nrm * push
			# A shove must not push a truck through the bank.
			for t: Truck in [a, b]:
				var res := track.constrain(t.position, Truck.RADIUS, t.last_idx)
				t.position = res[0]
			var rel := (b.velocity - a.velocity).dot(nrm)
			if rel < 0.0:
				var imp := -rel * 0.75
				a.velocity -= nrm * imp
				b.velocity += nrm * imp
				if imp > 14.0 * Truck.U and (a.is_player or b.is_player):
					_sfx("bump_light", -4.0, randf_range(0.9, 1.15), 0.12)


func _spawn_pickups(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer > 0.0 or pickups.size() >= PICKUP_MAX:
		return
	_spawn_timer = randf_range(3.5, 6.5)
	var leader_lap := 0
	for t in trucks:
		leader_lap = maxi(leader_lap, t.lap)
	leader_lap = clampi(leader_lap, 0, GameState.laps - 1)
	for attempt in 12:
		var s := randf() * track.length
		var tan := track.tangent_at_s(s)
		var pos := track.sample_at_s(s) + Vector2(-tan.y, tan.x) * randf_range(-22.0, 22.0)
		if track.surface_at(pos) != Track.Surface.DIRT:
			continue
		var near_truck := false
		for t in trucks:
			if t.position.distance_to(pos) < 72.0:
				near_truck = true
		if near_truck:
			continue
		var p := Pickup.new()
		if randf() < 0.55:
			p.kind = Pickup.Kind.MONEY
			p.value = mini(40_000, 10_000 * (1 + leader_lap))
		else:
			p.kind = Pickup.Kind.NITRO
			p.value = mini(4, 1 + leader_lap)
		p.position = pos
		p.ground_h = track.height_at(pos)
		_entities.add_child(p)
		pickups.append(p)
		p.tree_exiting.connect(func(): pickups.erase(p))
		return


func _collect_pickups() -> void:
	for p in pickups.duplicate():
		if not is_instance_valid(p) or p.is_queued_for_deletion():
			continue
		for t in trucks:
			if t.altitude - t.ground_h > 14.0:
				continue
			if t.position.distance_to(p.position) < 18.0:
				if p.kind == Pickup.Kind.MONEY:
					t.bonus += p.value
					if t.is_player:
						_sfx("money")
				else:
					t.nitro_count = mini(99, t.nitro_count + p.value)
					if t.is_player:
						_sfx("nitro_pickup")
				hud.popup(p.label(), Vector2(p.position.x, p.position.y - p.ground_h - 24.0), GameState.TEAM_COLORS[t.team])
				pickups.erase(p)
				p.queue_free()
				break


func _check_laps() -> void:
	if player_truck and player_truck.lap != _player_lap:
		if player_truck.lap > _player_lap and _player_lap >= 0:
			lap_times.append(race_time - _lap_start)
		if player_truck.lap > _player_lap:
			_lap_start = race_time
		_player_lap = player_truck.lap
	for t in trucks:
		if t.is_player and t.lap == GameState.laps - 1 and not _final_lap_announced:
			_final_lap_announced = true
			show_message("FINAL LAP", 1.5)
		if t.lap >= GameState.laps:
			_finish(t)
			return


func _finish(_winner: Truck) -> void:
	state = State.FINISHED
	_finish_timer = 3.0
	var ranked := trucks.duplicate()
	ranked.sort_custom(func(a, b): return a.progress() > b.progress())
	_results = []
	for i in ranked.size():
		var t: Truck = ranked[i]
		t.frozen = true
		_results.append({
			"team": t.team,
			"name": t.display_name,
			"position": i + 1,
			"prize": GameState.PRIZES[i],
			"bonus": t.bonus,
			"is_player": t.is_player,
			"nitro_left": t.nitro_count,
		})
	if player_truck:
		var pos: int = _results.filter(func(r): return r.is_player)[0].position
		show_message("YOU WIN!" if pos == 1 else "FINISH", 3.0)
		_sfx("fanfare" if pos == 1 else "beep_go")
	else:
		show_message("FINISH", 3.0)


func ranking() -> Array:
	var ranked := trucks.duplicate()
	ranked.sort_custom(func(a, b): return a.progress() > b.progress())
	return ranked
