class_name AIDriver
extends RefCounted
## CPU driver: follows the centerline with a personal lane offset, lifts before
## sharp corners, grabs nearby pickups and fires nitro on straights.

var lane := 0.0
var base_skill := 0.9
var rubber_band := false  # Ivan's "dynamic play adjustment"
var race: Node

var _stuck_time := 0.0
var _reverse_time := 0.0
var _lane_drift := 0.0
var _nitro_cooldown := 2.0


func update(truck: Truck, delta: float) -> void:
	var track := truck.track
	var sp := truck.speed()
	_lane_drift = move_toward(_lane_drift, sin(Time.get_ticks_msec() * 0.0007 + lane) * 3.0, delta * 4.0)

	# Skill / rubber band.
	var skill := base_skill
	if rubber_band and race and race.player_truck:
		var gap: float = race.player_truck.progress() - truck.progress()
		skill += clampf(gap / 600.0, -0.08, 0.1)
	truck.skill = skill

	# Unstick: reverse briefly when stopped against something.
	if _reverse_time > 0.0:
		_reverse_time -= delta
		truck.in_throttle = -1.0
		truck.in_steer = -1.0 if lane > 0.0 else 1.0
		truck.in_nitro = false
		return
	if sp < 6.0 and not truck.frozen:
		_stuck_time += delta
		if _stuck_time > 1.2:
			_stuck_time = 0.0
			_reverse_time = 0.6
	else:
		_stuck_time = 0.0

	var look := 16.0 + sp * 0.32
	var s_now := truck.s
	var tan_now := track.tangent_at_s(s_now)
	var target := _target(track, s_now + look)
	# Don't aim across the infield on hairpins: shorten the look-ahead until the
	# straight line to the target stays on the track.
	for k in 3:
		if _line_on_track(track, truck.position, target):
			break
		look *= 0.5
		target = _target(track, s_now + look)

	# Chase a pickup if it is close and roughly ahead.
	if race:
		for p in race.pickups:
			var to: Vector2 = p.position - truck.position
			if to.length() < 46.0 and to.normalized().dot(truck.forward()) > 0.6:
				target = p.position
				break

	var desired := (target - truck.position).angle()
	var diff := wrapf(desired - truck.heading, -PI, PI)
	truck.in_steer = clampf(diff * 2.6, -1.0, 1.0)

	# Corner ahead? Compare tangents over a longer distance.
	var tan_far := track.tangent_at_s(s_now + 40.0 + sp * 0.4)
	var bend := absf(tan_now.angle_to(tan_far))
	var corner_speed := lerpf(80.0, 38.0, clampf(bend / 2.2, 0.0, 1.0)) * (0.9 + 0.25 * skill)
	if (absf(diff) > 0.9 and sp > 30.0) or sp > corner_speed:
		truck.in_throttle = 0.0
	else:
		truck.in_throttle = 1.0

	# Nitro on straights, eagerly on the last lap.
	_nitro_cooldown -= delta
	truck.in_nitro = false
	if truck.nitro_count > 0 and truck.nitro_time <= 0.0 and _nitro_cooldown <= 0.0 and not truck.airborne:
		var last_lap := truck.lap >= GameState.LAPS - 1
		if bend < 0.35 and absf(diff) < 0.2 and sp > 30.0:
			if last_lap or randf() < delta * 0.25:
				truck.in_nitro = true
				_nitro_cooldown = 2.5


func _target(track: Track, s: float) -> Vector2:
	var tan := track.tangent_at_s(s)
	return track.sample_at_s(s) + Vector2(-tan.y, tan.x) * (lane + _lane_drift)


func _line_on_track(track: Track, a: Vector2, b: Vector2) -> bool:
	for u in [0.33, 0.66]:
		var p := a.lerp(b, u)
		var i := track.nearest_sample(p)
		if i < 0 or p.distance_to(track.samples[i]) > Track.HALF_WIDTH - 3.0:
			return false
	return true
