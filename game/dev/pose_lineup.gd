extends Node3D
## Dev tool: a row of wrestlers frozen at given animation times, for checking poses.
##   tools/screenshot.sh res://dev/pose_lineup.tscn out.png 20 --poses=idle@0,knockdown@0.4 --view=side

func _ready() -> void:
	add_child(ArenaLighting.new())
	var ring := Ring.new()
	add_child(ring)
	var y := Ring.canvas_height()
	var poses := DevTools.get_arg("poses", "idle@0").split(",")
	var spacing := 1.25
	var x0 := -spacing * (poses.size() - 1) / 2.0
	var side := DevTools.get_arg("view", "side") == "side"
	for i in poses.size():
		var parts := poses[i].split("@")
		var w := WrestlerModel.new()
		w.position = Vector3(x0 + i * spacing, y, 0)
		add_child(w)
		# side view: wrestlers face +x... so the camera at +z sees them in profile
		w.rotation.y = PI / 2 if side else 0.0
		w.play(parts[0], 0.0)
		w.anim_player.seek(float(parts[1]) if parts.size() > 1 else 0.0, true)
		w.anim_player.pause()
		var label := Label3D.new()
		label.text = poses[i]
		label.position = Vector3(x0 + i * spacing, y + 2.25, 0)
		label.pixel_size = 0.004
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(label)
	var cam := Camera3D.new()
	add_child(cam)
	var width := maxf(poses.size() * spacing, 3.0)
	cam.fov = 35
	cam.look_at_from_position(Vector3(0, y + 1.1, width * 1.25 + 1.5), Vector3(0, y + 0.85, 0))
