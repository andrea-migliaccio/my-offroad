extends Node
## Finds spots where CPU trucks stop making progress.
func _ready() -> void:
	GameState.demo_mode = true
	for cfg in [[3, true], [6, false]]:
		for run in 3:
			var race := Race.new()
			race.track_id = cfg[0]
			race.reverse = cfg[1]
			race.demo = true
			add_child(race)
			var best := {}
			var since := {}
			var reported := {}
			for f in 60 * 150:
				race._physics_process(1.0 / 60.0)
				if race.state == Race.State.FINISHED:
					break
				for tr in race.trucks:
					var p: float = tr.progress()
					if p > best.get(tr, -INF) + 4.0:
						best[tr] = p
						since[tr] = f
					elif f - since.get(tr, f) > 240 and not reported.has(tr):
						reported[tr] = true
						print("%s run%d %s stuck at %s s=%.0f lap=%d heading=%.0f v=%.1f surf=%d" % [race.track.name, run, tr.team, tr.position, tr.s, tr.lap, rad_to_deg(tr.heading), tr.speed(), tr.surface])
			race.free()
	get_tree().quit()
