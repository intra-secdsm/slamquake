extends Node3D
## Dev tool: a row of wrestlers frozen at given animation times, for checking poses.
##   tools/screenshot.sh res://dev/pose_lineup.tscn out.png 20 --poses=idle@0,knockdown@0.4 --view=side [--zoom=0.6 --look=1.2 --ring=0]

func _ready() -> void:
	add_child(ArenaLighting.new())
	if DevTools.get_arg("ring", "1") == "1":
		add_child(Ring.new())
	var y := Ring.canvas_height()
	var poses := DevTools.get_arg("poses", "idle@0").split(",")
	var pairs := poses[0].begins_with("pair:")
	var spacing := 3.4 if pairs else 1.25
	var x0 := -spacing * (poses.size() - 1) / 2.0
	var side := DevTools.get_arg("view", "side") == "side"
	for i in poses.size():
		var parts := poses[i].trim_prefix("pair:").split("@")
		var t := float(parts[1]) if parts.size() > 1 else 0.0
		var anims: Array = [parts[0]]
		if pairs:
			anims = [parts[0] + "_a", parts[0] + "_d"]
		for j in anims.size():
			var w := WrestlerModel.new()
			if j == 1:
				var l := WrestlerLook.new()
				l.trunks_color = Color(0.1, 0.5, 0.95)
				l.hair_style = "bald"
				w.look = l
			w.position = Vector3(x0 + i * spacing, y, 0)
			add_child(w)
			# side view: wrestlers face +x, so the camera at +z sees them in profile
			w.rotation.y = PI / 2 if side else 0.0
			w.play(anims[j], 0.0)
			w.anim_player.seek(t, true)
			w.anim_player.pause()
		var label := Label3D.new()
		label.text = poses[i]
		label.position = Vector3(x0 + i * spacing, y + 2.25, 0)
		label.pixel_size = 0.004
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(label)
	var cam := Camera3D.new()
	add_child(cam)
	var width := maxf(poses.size() * spacing * (0.75 if pairs else 1.0), 3.0)
	cam.fov = 35
	var dist := (width * 1.25 + 1.5) * float(DevTools.get_arg("zoom", "1"))
	var look_h := float(DevTools.get_arg("look", "0.85"))
	cam.look_at_from_position(Vector3(0, y + look_h + 0.25, dist), Vector3(0, y + look_h, 0))
