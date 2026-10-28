extends Node3D
## M1 pipeline showcase: ring, lighting and a few differently-built wrestlers.
## Camera presets via DevTools: --cam=wide|body|face|back

var wrestlers: Array[WrestlerModel] = []


func _ready() -> void:
	add_child(ArenaLighting.new())
	add_child(Arena.new())
	var ring := Ring.new()
	add_child(ring)
	var y := Ring.canvas_height()

	var looks := [_look_brawler(), _look_highflyer(), _look_big_man()]
	var anims := ["idle", "walk", "punch"]
	var xs := [0.0, -1.6, 1.7]
	for i in looks.size():
		var w := WrestlerModel.new()
		w.look = looks[i]
		w.position = Vector3(xs[i], y, 0.4 if i == 0 else -0.2)
		add_child(w)
		w.rotation.y = [0.0, 0.5, -0.5][i]
		var anim_name := DevTools.get_arg("anim", anims[i])
		if anim_name != "rest":
			w.play(anim_name, 0.0)
			if DevTools.has_arg("anim_time"):
				w.anim_player.seek(float(DevTools.get_arg("anim_time")), true)
				w.anim_player.pause()
		wrestlers.append(w)

	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 40
	match DevTools.get_arg("cam", "wide"):
		"arena":
			cam.fov = 60
			cam.look_at_from_position(Vector3(0.0, 9.0, 16.0), Vector3(0, 2.5, -4.0))
		"stage":
			cam.fov = 50
			cam.look_at_from_position(Vector3(3.0, 3.0, -2.0), Vector3(0, 3.5, -14.0))
		"face":
			cam.fov = 22
			cam.look_at_from_position(Vector3(0.0, y + 1.78, 1.6), Vector3(0, y + 1.74, 0.4))
		"body":
			cam.look_at_from_position(Vector3(0.0, y + 1.75, 4.6), Vector3(0, y + 0.95, 0.4))
		"side":
			cam.look_at_from_position(Vector3(4.2, y + 0.9, 0.3), Vector3(0, y + 0.85, 0.2))
		"back":
			cam.look_at_from_position(Vector3(0.5, y + 1.6, -4.2), Vector3(0, y + 0.95, 0.4))
		_:
			cam.look_at_from_position(Vector3(0, 5.2, 11.5), Vector3(0, 1.6, 0))


func _look_brawler() -> WrestlerLook:
	var l := WrestlerLook.new()
	l.muscle = 0.6
	l.hair_style = "mullet"
	l.hair_color = Color(0.55, 0.38, 0.18)
	return l


func _look_highflyer() -> WrestlerLook:
	var l := WrestlerLook.new()
	l.mass = -0.6
	l.muscle = 0.2
	l.height = 0.95
	l.skin_color = Color(0.55, 0.36, 0.24)
	l.hair_style = "mohawk"
	l.hair_color = Color(0.1, 0.9, 0.8)
	l.trunks_color = Color(0.1, 0.8, 0.9)
	l.trim_color = Color(0.95, 0.95, 0.95)
	l.pads_color = Color(0.1, 0.8, 0.9)
	l.tights = true
	l.tights_color = Color(0.1, 0.12, 0.35)
	l.boots_color = Color(0.9, 0.9, 0.95)
	return l


func _look_big_man() -> WrestlerLook:
	var l := WrestlerLook.new()
	l.mass = 1.0
	l.gut = 0.6
	l.muscle = 0.3
	l.height = 1.08
	l.skin_color = Color(0.9, 0.68, 0.55)
	l.hair_style = "bald"
	l.trunks_color = Color(0.1, 0.1, 0.1)
	l.trim_color = Color(0.9, 0.1, 0.1)
	l.pads_color = Color(0.1, 0.1, 0.1)
	l.elbowpads = true
	return l
