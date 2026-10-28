class_name Match
extends Node3D
## Sets up and runs a match from GameState.match_entrants.
## M2: exhibition brawl. A KO (health 0) ends the round, then everyone resets.
## Pinfalls and match rules arrive in M3.

const START_SPOTS := [Vector3(-1.5, 0, 0.5), Vector3(1.5, 0, -0.5), Vector3(-1.5, 0, -1.2), Vector3(1.5, 0, 1.2)]

var ring: Ring
var camera: BroadcastCamera
var hud: MatchHud
var wrestlers: Array[Wrestler] = []
var _ko_timer := -1.0
var _pause_menu: Control


func _ready() -> void:
	add_child(ArenaLighting.new())
	ring = Ring.new()
	add_child(ring)
	camera = BroadcastCamera.new()
	add_child(camera)
	camera.current = true

	var help: Array[String] = []
	for i in GameState.match_entrants.size():
		var e: Dictionary = GameState.match_entrants[i]
		var entry := Roster.get_entry(e["roster"])
		var w := Wrestler.new()
		w.name = "Wrestler%d" % (i + 1)
		w.look = entry["look"]
		w.display_name = entry["name"]
		w.ring = ring
		if e["control"] == "human":
			w.controller = PlayerController.new(e["slot"])
			help.append("P%d  " % (e["slot"] + 1) + InputRouter.describe(e["slot"]).replace("\n", "\n      "))
		else:
			w.controller = CpuController.new(e["difficulty"])
			w.infinite_health = e["difficulty"] == 0
		add_child(w)
		var spot: Vector3 = START_SPOTS[i % START_SPOTS.size()]
		w.global_position = spot + Vector3.UP * Ring.canvas_height()
		w.rotation.y = atan2(-spot.x, -spot.z)
		w.struck.connect(_on_struck)
		w.knocked_down.connect(_on_knocked_down)
		w.landed_on_canvas.connect(_on_landed)
		wrestlers.append(w)
		camera.targets.append(w)

	# 1v1 for now: everyone else is an opponent
	for w in wrestlers:
		for o in wrestlers:
			if o != w:
				w.opponents.append(o)

	hud = MatchHud.new()
	add_child(hud)
	hud.setup(wrestlers, "\n".join(help))
	hud.banner("FIGHT!", 1.2)
	# the director keeps listening for unpause; everything else freezes
	process_mode = Node.PROCESS_MODE_ALWAYS
	for c in get_children():
		c.process_mode = Node.PROCESS_MODE_PAUSABLE
	_build_pause_menu()


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if _ko_timer >= 0.0:
		_ko_timer -= delta
		if _ko_timer < 0.0:
			for w in wrestlers:
				w.restore_health()
			hud.banner("ROUND 2... FIGHT!", 1.2)


func _unhandled_input(event: InputEvent) -> void:
	for slot in InputRouter.SLOTS:
		if event.is_action_pressed(InputRouter.action_name(slot, "pause")):
			_toggle_pause()
			get_viewport().set_input_as_handled()
			return


func _on_struck(attacker: Wrestler, victim: Wrestler, move: Dictionary, blocked: bool) -> void:
	if blocked:
		return
	var heavy := float(move.get("damage", 0)) >= 8.0
	var at := (attacker.global_position + victim.global_position) * 0.5 + Vector3.UP * 1.45
	HitFx.spawn(self, at, heavy)
	camera.shake(1.0 if heavy else 0.35)


func _on_knocked_down(w: Wrestler) -> void:
	if w.health <= 0.0 and _ko_timer < 0.0:
		hud.banner("K.O.!", 2.5)
		_ko_timer = 3.5


func _on_landed(_w: Wrestler) -> void:
	camera.shake(0.8)


func _toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
	_pause_menu.visible = get_tree().paused
	if get_tree().paused:
		_pause_menu.get_child(0).get_child(1).grab_focus()


func _build_pause_menu() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	_pause_menu = ColorRect.new()
	(_pause_menu as ColorRect).color = Color(0, 0, 0, 0.6)
	_pause_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_menu.visible = false
	layer.add_child(_pause_menu)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-160, -120)
	box.custom_minimum_size = Vector2(320, 0)
	box.add_theme_constant_override("separation", 14)
	_pause_menu.add_child(box)
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color("ff2bd6"))
	box.add_child(title)
	for item in [["Resume", _toggle_pause], ["Restart", _restart], ["Main Menu", _quit_to_menu]]:
		var b := Button.new()
		b.text = item[0]
		b.add_theme_font_size_override("font_size", 30)
		b.pressed.connect(item[1])
		box.add_child(b)


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _quit_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")
