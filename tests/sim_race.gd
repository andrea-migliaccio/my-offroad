extends Node
## Headless check: CPU-only race on every track and direction.
## godot --headless --path . res://tests/sim_race.tscn

const DT := 1.0 / 60.0
const MAX_TIME := 300.0

func _ready() -> void:
	GameState.demo_mode = true
	var failures := 0
	var only := OS.get_environment("SIM_TRACK")
	for id in Track.track_count():
		if only != "" and int(only) != id:
			continue
		for rev in [false, true]:
			var race := Race.new()
			race.track_id = id
			race.reverse = rev
			race.demo = true
			var done := [false]
			race.finished.connect(func(_r): done[0] = true)
			add_child(race)
			var t := 0.0
			var max_off := 0.0
			var air_time := 0.0
			while t < MAX_TIME and not done[0]:
				race._physics_process(DT)
				t += DT
				for tr in race.trucks:
					var i := race.track.nearest_sample(tr.position)
					if i < 0:
						max_off = INF
					else:
						max_off = maxf(max_off, tr.position.distance_to(race.track.samples[i]))
					if tr.airborne:
						air_time += DT
			var laps := []
			for tr in race.ranking():
				laps.append("%s:%d" % [tr.team, tr.lap])
			var ok: bool = done[0] and max_off <= Track.HALF_WIDTH + 1.0
			if not ok:
				failures += 1
			print("%s %-16s %s time=%5.1fs race=%5.1fs off=%.1f air=%.1fs %s" % [
				"OK  " if ok else "FAIL", race.track.name, "REV" if rev else "FWD", t, race.race_time,
				max_off, air_time, " ".join(laps)])
			race.queue_free()
			await get_tree().process_frame
	print("SIM_DONE failures=%d" % failures)
	get_tree().quit(1 if failures > 0 else 0)
