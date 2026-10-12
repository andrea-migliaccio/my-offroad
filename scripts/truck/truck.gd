class_name Truck
extends Node2D
## Arcade off-road truck. Physics runs on the ground plane (screen pixels) with a
## separate altitude for hills, jumps and bounces. The sprite is drawn `altitude`
## pixels above its ground position, the shadow at ground height.

signal bumped(strength: float)

const HEADINGS := 64
const FRAME := 40
## World scale: tracks are 2.4x the original 320x240 design, so every speed,
## distance and acceleration below is expressed as (original value) * U.
const U := 2.4
const RADIUS := 8.0
const GRAVITY := 260.0 * U
const SLOPE_GRAVITY := 150.0 * U
const NITRO_TIME := 1.3

var track: Track
var race: Node  # Race, for tire marks / effects
var team := "red"
var display_name := "YOU"
var is_player := false
var controller: Object  # PlayerInput or AIDriver: has update(truck, delta)

# Stats (from upgrades).
var top_speed := 62.0 * U
var accel := 55.0 * U
var grip := 2.8
var turn_rate := 3.7
var shocks := 0
var skill := 1.0  # multiplier on top speed / accel (AI difficulty, rubber-band)

# Input written by the controller each tick.
var in_steer := 0.0
var in_throttle := 0.0
var in_nitro := false

# State.
var velocity := Vector2.ZERO
var heading := 0.0
var altitude := 0.0
var vz := 0.0
var airborne := false
var ground_h := 0.0
var nitro_count := 0
var nitro_time := 0.0
var lap := -1
var s := 0.0
var finished := false
var frozen := true
var bonus := 0
var last_idx := 0
var surface := Track.Surface.DIRT

var _body: Sprite2D
var _shadow: Sprite2D
var _flame: Sprite2D
var _dust: CPUParticles2D
var _engine: AudioStreamPlayer
var _mark_timer := 0.0
var _nitro_held := false


func setup(p_track: Track, p_team: String, p_name: String, ups: Dictionary, nitro: int) -> void:
	track = p_track
	team = p_team
	display_name = p_name
	nitro_count = nitro
	apply_upgrades(ups)


func apply_upgrades(ups: Dictionary) -> void:
	top_speed = (66.0 + 5.0 * ups.get("speed", 0)) * U
	accel = (50.0 + 10.0 * ups.get("accel", 0)) * U
	grip = 2.6 + 0.65 * ups.get("tires", 0)
	turn_rate = 3.6 + 0.08 * ups.get("tires", 0)
	shocks = ups.get("shocks", 0)


func _ready() -> void:
	_shadow = Sprite2D.new()
	_shadow.texture = _make_shadow()
	_shadow.modulate = Color(0, 0, 0, 0.45)
	add_child(_shadow)
	_dust = CPUParticles2D.new()
	_dust.amount = 24
	_dust.lifetime = 0.5
	_dust.emitting = false
	_dust.local_coords = false
	_dust.direction = Vector2(0, -1)
	_dust.spread = 50.0
	_dust.gravity = Vector2(0, -6) * U
	_dust.initial_velocity_min = 4.0 * U
	_dust.initial_velocity_max = 12.0 * U
	_dust.scale_amount_min = 2.0
	_dust.scale_amount_max = 4.0
	_dust.color = Color8(214, 170, 120, 200)
	_dust.color_ramp = _fade_ramp()
	add_child(_dust)
	_body = Sprite2D.new()
	_body.texture = load("res://assets/sprites/truck_%s.png" % team)
	_body.hframes = HEADINGS
	_body.vframes = 3
	add_child(_body)
	_flame = Sprite2D.new()
	_flame.texture = load("res://assets/sprites/flame.png")
	_flame.visible = false
	add_child(_flame)
	if is_player and not GameState.demo_mode:
		_engine = AudioStreamPlayer.new()
		_engine.stream = Audio.engine_stream()
		_engine.volume_db = -14.0
		add_child(_engine)
		_engine.play()
	ground_h = track.height_at(position)
	altitude = ground_h
	last_idx = maxi(0, track.nearest_sample(position))
	s = last_idx * Track.DS
	_update_visuals()


static func _make_shadow() -> Texture2D:
	var img := Image.create(28, 14, false, Image.FORMAT_RGBA8)
	for y in 14:
		for x in 28:
			var dx := (x - 13.5) / 14.0
			var dy := (y - 6.5) / 7.0
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, Color.WHITE)
	return ImageTexture.create_from_image(img)


static func _fade_ramp() -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	return g


func forward() -> Vector2:
	return Vector2.from_angle(heading)


func speed() -> float:
	return velocity.length()


func progress() -> float:
	return lap * track.length + s


func physics_step(delta: float) -> void:
	if controller and not frozen:
		controller.update(self, delta)
	elif frozen:
		in_throttle = 0.0
		in_steer = 0.0
		in_nitro = false

	# Nitro trigger (edge-triggered).
	if in_nitro and not _nitro_held and nitro_time <= 0.0 and nitro_count > 0 and not frozen:
		nitro_count -= 1
		nitro_time = NITRO_TIME
		if is_player:
			Audio.play("nitro_fire", -2.0)
	_nitro_held = in_nitro
	nitro_time = maxf(0.0, nitro_time - delta)

	var fwd := forward()
	var right := Vector2(-fwd.y, fwd.x)
	var vf := velocity.dot(fwd)
	var vl := velocity.dot(right)
	var top := top_speed * skill
	var acc := accel * skill
	if nitro_time > 0.0:
		top *= 1.6
		acc *= 2.6

	surface = track.surface_at(position)
	if not airborne:
		match surface:
			Track.Surface.MUD:
				top *= 0.5
				vf *= exp(-2.4 * delta)
			Track.Surface.WATER:
				top *= 0.62
				vf *= exp(-1.6 * delta)

		# Steering: works even when slow so a stuck truck can turn around.
		var steer_factor := clampf(0.4 + absf(vf) / (45.0 * U), 0.4, 1.0)
		heading = wrapf(heading + in_steer * turn_rate * steer_factor * delta, -PI, PI)

		# Throttle.
		if in_throttle > 0.0:
			if vf < top:
				vf = minf(top, vf + acc * in_throttle * delta * (1.0 - 0.5 * vf / top))
		elif in_throttle < 0.0:
			if vf > -top * 0.35:
				vf -= acc * 0.8 * delta
		else:
			vf *= exp(-1.4 * delta)
		if vf > top:
			vf = lerpf(vf, top, 1.0 - exp(-1.8 * delta))

		# Slope: uphill slows, downhill speeds up.
		var ahead := track.height_at(position + fwd * 2.0 * U) - track.height_at(position - fwd * 2.0 * U)
		var slope_acc := SLOPE_GRAVITY * (ahead / (4.0 * U)) * signf(vf if absf(vf) > 1.0 else 1.0)
		if slope_acc > 0.0:
			# Uphill never fully cancels the engine, so a slow truck can still climb.
			slope_acc = minf(slope_acc, accel * skill * 0.6)
		vf -= slope_acc * signf(vf if absf(vf) > 1.0 else 1.0) * delta

		# Lateral grip: the lower, the more the truck slides through corners.
		vl *= exp(-grip * delta)
		# Re-project onto the new heading.
		fwd = forward()
		right = Vector2(-fwd.y, fwd.x)
		velocity = fwd * vf + right * vl
	else:
		velocity *= exp(-0.15 * delta)

	# Move and resolve walls.
	var prev_alt := altitude
	position += velocity * delta
	var res := track.constrain(position, RADIUS, last_idx)
	var nrm: Vector2 = res[1]
	if nrm != Vector2.ZERO:
		position = res[0]
		var vn := velocity.dot(nrm)
		if vn < 0.0:
			velocity -= nrm * vn * 1.45
			velocity *= 0.9
			if -vn > 20.0 * U:
				bumped.emit(-vn)
				if is_player:
					Audio.play("bump", -6.0 + minf(6.0, -vn * 0.08 / U), randf_range(0.9, 1.1), 0.15)

	# Vertical motion.
	var g := track.height_at(position)
	if airborne:
		vz -= GRAVITY * delta
		altitude += vz * delta
		if altitude <= g:
			_land(g)
	else:
		var ground_vz := (g - ground_h) / delta
		var ballistic := prev_alt + vz * delta - 0.5 * GRAVITY * delta * delta
		if vz > 12.0 * U and g < ballistic - 0.25 * U:
			# Ground falls away faster than gravity: take off.
			airborne = true
			vz *= 0.95 - 0.04 * shocks
			altitude = ballistic
		else:
			vz = lerpf(vz, ground_vz, 0.6)
			altitude = g
	ground_h = g

	_update_progress()
	_effects(delta)
	_update_visuals()


func _land(g: float) -> void:
	var impact := -vz
	altitude = g
	if impact > 45.0 * U:
		vz = impact * (0.32 - 0.04 * shocks)
		var loss := minf(0.3, impact / U * 0.0035 * (1.0 - 0.12 * shocks))
		velocity *= 1.0 - loss
		if is_player:
			Audio.play("land", -4.0, randf_range(0.9, 1.1), 0.2)
		_dust.restart()
		if vz < 10.0 * U:
			airborne = false
			vz = 0.0
	else:
		airborne = false
		vz = 0.0


func _update_progress() -> void:
	var i := track.nearest_sample(position)
	if i < 0:
		return
	var n := track.samples.size()
	if last_idx > n * 3 / 4 and i < n / 4:
		lap += 1
	elif last_idx < n / 4 and i > n * 3 / 4:
		lap -= 1
	last_idx = i
	s = i * Track.DS


func _effects(delta: float) -> void:
	var sp := speed()
	var on_dirt := not airborne and (surface == Track.Surface.DIRT or surface == Track.Surface.MUD)
	var on_water := not airborne and surface == Track.Surface.WATER
	_dust.emitting = (on_dirt and sp > 35.0 * U) or (on_water and sp > 15.0 * U)
	if on_water:
		_dust.color = Color8(170, 210, 250, 220)
		if is_player and sp > 25.0 * U:
			Audio.play("splash", -8.0, randf_range(0.9, 1.2), 0.35)
	elif surface == Track.Surface.MUD:
		_dust.color = Color8(80, 54, 30, 220)
	else:
		_dust.color = Color8(214, 170, 120, 200)
	_dust.position = Vector2(0, -ground_h) - forward() * 13.0
	# Tire marks while sliding or spinning up.
	_mark_timer -= delta
	if on_dirt and _mark_timer <= 0.0 and race:
		var slide := absf(velocity.dot(Vector2(-forward().y, forward().x)))
		if slide > 14.0 * U or (in_throttle > 0.0 and sp < 20.0 * U):
			_mark_timer = 0.03
			var back := position - forward() * 10.0
			var side := Vector2(-forward().y, forward().x) * 6.0
			race.add_mark(back + side, ground_h)
			race.add_mark(back - side, ground_h)
	if _engine:
		_engine.pitch_scale = 0.7 + sp / (70.0 * U) + (0.3 if nitro_time > 0.0 else 0.0)


func _update_visuals() -> void:
	var frame := int(round(fposmod(heading, TAU) / TAU * HEADINGS)) % HEADINGS
	var pitch_row := 0
	if airborne:
		if vz > 15.0 * U:
			pitch_row = 1
		elif vz < -15.0 * U:
			pitch_row = 2
	else:
		var slope := track.height_at(position + forward() * 10.0) - track.height_at(position - forward() * 10.0)
		if slope > 4.8:
			pitch_row = 1
		elif slope < -4.8:
			pitch_row = 2
	_body.frame = pitch_row * HEADINGS + frame
	_body.position = Vector2(0, -altitude - 9.0)
	_shadow.position = Vector2(0, -ground_h + 2.0)
	var air := altitude - ground_h
	_shadow.scale = Vector2.ONE * clampf(1.0 - air * 0.02 / U, 0.6, 1.0)
	_flame.visible = nitro_time > 0.0 and (Engine.get_physics_frames() / 2) % 2 == 0
	if _flame.visible:
		_flame.rotation = heading + PI
		_flame.position = _body.position - forward() * 20.0
	# Draw order: nearer to the bottom of the screen in front.
	z_index = int(position.y)
