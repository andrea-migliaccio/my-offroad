extends SceneTree
## Bakes track fields + backgrounds into assets/tracks/baked/.
##   godot --headless --path . -s tests/bake_tracks.gd            (all tracks)
##   godot --headless --path . -s tests/bake_tracks.gd -- 3 5     (only ids 3 and 5)

func _init() -> void:
	var ids := []
	for a in OS.get_cmdline_user_args():
		ids.append(int(a))
	if ids.is_empty():
		ids = range(Track.track_count())
	for i in ids:
		var t0 := Time.get_ticks_msec()
		Track.bake(i)
		print("baked %02d %-16s %5d ms" % [i, Track.track_name(i), Time.get_ticks_msec() - t0])
	quit()
