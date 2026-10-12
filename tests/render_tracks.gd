extends SceneTree
## Renders every track background to user-independent _render/ for inspection.
## godot --headless --path . -s tests/render_tracks.gd

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://_render"))
	for i in Track.track_count():
		var t0 := Time.get_ticks_msec()
		var t := Track.build(i, false)
		var img := t.background.get_image()
		img.save_png("res://_render/track_%d.png" % i)
		print("%s: %d samples, len %.0f, %d ms" % [t.name, t.samples.size(), t.length, Time.get_ticks_msec() - t0])
	quit()
