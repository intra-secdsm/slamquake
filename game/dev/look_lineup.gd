extends Node3D
## Dev tool: wrestlers with given looks standing side by side, for checking attire, masks,
## hair and body types.
##   tools/screenshot.sh res://dev/look_lineup.tscn out.png 20 --looks=<look>|<look>|... \
##     [--cam=full|head|torso|legs] [--turn=DEGREES] [--anim=idle@0.0] [--ring=0]
## A <look> is a roster id (e.g. quetzal_neon), "default", or property overrides separated
## by ";" applied to a default look or to a roster look: "zip_volta;mask=classic;mask_color=#ff0000"
## "--turn=180" shows their backs, 90 their left sides.

func _ready() -> void:
	add_child(ArenaLighting.new())
	if DevTools.get_arg("ring", "1") == "1":
		add_child(Ring.new())
	var y := Ring.canvas_height()
	var specs := DevTools.get_arg("looks", "default").split("|")
	var cam_mode := DevTools.get_arg("cam", "full")
	var spacing := 0.45 if cam_mode == "head" else 1.1
	var x0 := -spacing * (specs.size() - 1) / 2.0
	var anim := DevTools.get_arg("anim", "idle@0.0").split("@")
	for i in specs.size():
		var w := WrestlerModel.new()
		w.look = parse_look(specs[i])
		w.position = Vector3(x0 + i * spacing, y, 0)
		add_child(w)
		w.rotation.y = deg_to_rad(float(DevTools.get_arg("turn", "0")))
		w.play(anim[0], 0.0)
		w.anim_player.seek(float(anim[1]) if anim.size() > 1 else 0.0, true)
		w.anim_player.pause()
		var label := Label3D.new()
		label.text = specs[i].left(40)
		label.position = Vector3(x0 + i * spacing, y + (2.02 if cam_mode == "head" else 2.2), 0)
		label.pixel_size = 0.0016 if cam_mode == "head" else 0.003
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(label)
	var cam := Camera3D.new()
	add_child(cam)
	# [look-at height, minimum frame width, extra distance]
	var focus := {"full": [1.0, 2.6, 1.6], "head": [1.74, 0.6, 0.45], "torso": [1.3, 1.2, 0.6], "legs": [0.55, 1.2, 0.6]}
	var f: Array = focus.get(cam_mode, focus["full"])
	var width := maxf(specs.size() * spacing, float(f[1]))
	cam.fov = 30
	var dist := width * 1.1 + float(f[2])
	cam.look_at_from_position(Vector3(0, y + float(f[0]) + 0.05, dist), Vector3(0, y + float(f[0]), 0))


static func parse_look(spec: String) -> WrestlerLook:
	var parts := spec.split(";")
	var l := WrestlerLook.new()
	var start := 0
	if parts[0] != "default" and not parts[0].contains("="):
		for e in Roster.builtin():
			if e["id"] == parts[0]:
				l = (e["look"] as WrestlerLook).duplicate()
		start = 1
	var d := l.to_dict()
	for i in range(start, parts.size()):
		var kv := parts[i].split("=", true, 1)
		if kv.size() == 2:
			var v: Variant = kv[1]
			if kv[1] == "true" or kv[1] == "false":
				v = kv[1] == "true"
			elif kv[1].is_valid_float():
				v = float(kv[1])
			d[kv[0]] = v
	return WrestlerLook.from_dict(d)
