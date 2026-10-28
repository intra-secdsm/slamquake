class_name Match
extends Node3D
## Sets up and runs a match from GameState.match_entrants: wrestlers, referee, camera,
## HUD and rules. 1v1. Win by pinfall (pins under the ropes are broken), or in normal
## rules by count-out (20 while on the floor) or disqualification (weapon shots).

signal match_ended(winner: Wrestler)

const START_SPOTS := [Vector3(-1.5, 0, 0.5), Vector3(1.5, 0, -0.5), Vector3(-1.5, 0, -1.2), Vector3(1.5, 0, 1.2)]
const COUNT_OUT := 20
var count_period := 1.0         ## seconds per count-out number

var ring: Ring
var camera: BroadcastCamera
var hud: MatchHud
var referee: Referee
var wrestlers: Array[Wrestler] = []
var winner: Wrestler               ## set when the match ends (a wrestler even on a draw)
var finish_reason := ""
var _finished := false
var tables: Array[FoldingTable] = []
var chairs: Array[Chair] = []
var _pin: Dictionary = {}          # {attacker, defender}
var _count := 0
var _count_t := 0.0
var _pause_menu: Control
var _end_menu: Control


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
		w.finisher = entry.get("finisher", "thunder_bomb")
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
		w.landed_on_canvas.connect(_on_landed)
		w.pin_started.connect(_on_pin_started)
		w.kicked_out.connect(_on_kicked_out)
		w.landed_outside.connect(_on_landed_outside)
		w.move_performed.connect(_on_move_performed)
		w.reversed.connect(_on_reversed)
		w.special_ready.connect(_on_special_ready)
		wrestlers.append(w)
		camera.targets.append(w)

	# 1v1 for now: everyone else is an opponent
	for w in wrestlers:
		for o in wrestlers:
			if o != w:
				w.opponents.append(o)

	_place_props()

	referee = Referee.new()
	add_child(referee)
	referee.global_position = Vector3(0, Ring.canvas_height(), -2.2)
	referee.wrestlers = wrestlers
	referee.counted.connect(_on_count)

	hud = MatchHud.new()
	add_child(hud)
	help.append("Tie-up (grapple): punch = headbutt / +dir body slam · kick = suplex / +dir DDT · run = Irish whip"
		+ " · taunt with SPECIAL = FINISHER\n"
		+ "Tap block just before a hit lands to PARRY · tap block as they start a move on you to REVERSE\n"
		+ "Opponent down: grapple = pick up · punch = elbow drop · kick = stomp · block = PIN\n"
		+ "Push into the ropes to roll out · grapple near a corner to climb · grapple near a chair to pick it up")
	hud.setup(wrestlers, "\n".join(help))
	AudioDirector.play("bell", camera.global_position + Vector3.FORWARD * 3.0, -4.0)
	hud.banner("FIGHT!", 1.2)
	# the director keeps listening for unpause; everything else freezes
	process_mode = Node.PROCESS_MODE_ALWAYS
	for c in get_children():
		c.process_mode = Node.PROCESS_MODE_PAUSABLE
	_build_pause_menu()


func _physics_process(delta: float) -> void:
	if get_tree().paused or winner:
		return
	_count_out(delta)
	if _pin.is_empty():
		return
	var d: Wrestler = _pin["defender"]
	hud.show_kickout(d, d.kickout_progress())
	if referee.is_counting() and _near_ropes(d):
		hud.banner("ROPE BREAK!", 1.2)
		d.kick_out()


func _unhandled_input(event: InputEvent) -> void:
	for slot in InputRouter.SLOTS:
		if event.is_action_pressed(InputRouter.action_name(slot, "pause")) and winner == null:
			_toggle_pause()
			get_viewport().set_input_as_handled()
			return


# ---------------------------------------------------------------- rules

func _on_pin_started(attacker: Wrestler, defender: Wrestler) -> void:
	if winner:
		return
	_pin = {"attacker": attacker, "defender": defender}
	referee.start_count(defender)


func _on_count(n: int) -> void:
	if _pin.is_empty():
		return
	hud.banner(str(n) if n < 3 else "THREE!", 0.8 if n < 3 else 2.0)
	if n >= 3:
		_finish(_pin["attacker"], _pin["defender"])


func _on_kicked_out(defender: Wrestler) -> void:
	if _pin.is_empty() or _pin["defender"] != defender:
		return
	if referee.count == 2:
		hud.banner("KICK OUT AT 2!", 1.2)
	_pin = {}
	hud.show_kickout(null, 0.0)
	referee.stop_count()


## The referee's current count-out number (0 when nobody is outside).
func outside_count() -> int:
	return _count


func _count_out(delta: float) -> void:
	var out: Array[Wrestler] = []
	for w in wrestlers:
		if w.outside:
			out.append(w)
	if out.is_empty() or GameState.rules != "normal":
		if _count > 0:
			_count = 0
			hud.show_count(0)
			referee.stop_watching()
		return
	referee.watch_outside(out[0])
	_count_t += delta
	if _count_t >= count_period:
		_count_t = 0.0
		_count += 1
		hud.show_count(_count)
		if _count >= COUNT_OUT:
			if out.size() == wrestlers.size():
				_finish(null, null, "DOUBLE COUNT-OUT")
			else:
				var inside := wrestlers.filter(func(w: Wrestler) -> bool: return not w.outside)
				_finish(inside[0], out[0], "COUNT-OUT")


func _near_ropes(w: Wrestler) -> bool:
	var lim := float(Ring.spec()["post_half"]) - Wrestler.ROPE_MARGIN
	for p in [w.global_position, w.head_position()]:
		if absf(p.x) > lim - 0.05 or absf(p.z) > lim - 0.05:
			return true
	return false


func _finish(win: Wrestler, lose: Wrestler, reason: String = "") -> void:
	winner = win if win else lose if lose else wrestlers[0]
	finish_reason = reason if reason != "" else "PINFALL"
	_finished = true
	_pin = {}
	hud.show_kickout(null, 0.0)
	hud.show_count(0)
	for w in wrestlers:
		if w == win:
			w.win()
		else:
			w.lose()
	AudioDirector.play("bell_triple", camera.global_position + Vector3.FORWARD * 3.0, -2.0)
	camera.shake(0.6)
	if reason != "":
		hud.banner(reason + "!", 1.2)
	await get_tree().create_timer(1.2).timeout
	hud.banner("WINNER: %s" % win.display_name.to_upper() if win else "NO CONTEST", 3.5)
	match_ended.emit(win)
	await get_tree().create_timer(3.0).timeout
	if is_inside_tree():
		_show_end_menu()


# ---------------------------------------------------------------- feedback

func _on_struck(attacker: Wrestler, victim: Wrestler, move: Dictionary, blocked: bool) -> void:
	if blocked:
		return
	if move.get("weapon", false) and GameState.rules == "normal" and not winner:
		_finish(victim, attacker, "DISQUALIFIED")
	var heavy := float(move.get("damage", 0)) >= 8.0
	var at := victim.body_center().lerp(attacker.global_position + Vector3.UP * 1.3, 0.25)
	HitFx.spawn(self, at, heavy)
	camera.shake(1.0 if heavy else 0.35)


func _on_landed(w: Wrestler) -> void:
	camera.shake(0.8)
	if w.is_inside_tree():
		HitFx.dust(self, Vector3(w.body_center().x, w.global_position.y + 0.02, w.body_center().z))


func _on_move_performed(w: Wrestler, id: String) -> void:
	var mv: Dictionary = Grapples.ALL.get(id, {})
	if mv.get("finisher", false):
		_finisher_cinematic(w, id)
	elif float(mv.get("damage", 0.0)) >= 14.0:
		_crowd("crowd_ooh", -8.0)


func _on_reversed(by: Wrestler, _victim: Wrestler, kind: String) -> void:
	hud.popup("REVERSAL!" if kind == "reversal" else "PARRY!", by)
	if camera.in_cinematic():
		camera.end_cinematic()
		hud.banner("REVERSED!", 1.2)
	if kind == "reversal":
		_crowd("crowd_ooh", -6.0)


func _on_special_ready(w: Wrestler) -> void:
	hud.popup("SPECIAL!", w)


## Slow-motion, a camera cut and a crowd pop for a finisher.
func _finisher_cinematic(w: Wrestler, id: String) -> void:
	var mv := Grapples.get_move(id)
	var impact := float(mv["events"].get("impact", 1.0))
	hud.banner(w.finisher_name() + "!", impact + 0.6)
	camera.cinematic([w, w.partner], w.facing(), float(mv["length"]) + 0.3)
	_crowd("crowd_ooh", -6.0)
	await get_tree().create_timer(maxf(0.0, impact - 0.12), false, true).timeout
	if not is_inside_tree() or w.state != Wrestler.State.PAIRED or w.partner == null:
		Engine.time_scale = 1.0
		return       # reversed
	Engine.time_scale = 0.3
	await get_tree().create_timer(0.38, false, true, true).timeout
	Engine.time_scale = 1.0
	if not is_inside_tree():
		return
	hud.flash()
	camera.shake(2.0)
	_crowd("crowd_pop", -2.0)


func _crowd(sfx: String, volume: float) -> void:
	AudioDirector.play(sfx, camera.global_position + camera.global_basis.z * -2.0, volume, 0.04)


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _on_landed_outside(w: Wrestler, at: Vector3) -> void:
	for t in tables:
		if t.intact and t.covers(at):
			t.smash()
			w._damage(10.0)
			camera.shake(1.6)
			hud.banner("THROUGH THE TABLE!", 1.6)
			_crowd("crowd_pop", -4.0)
			for o in w.opponents:
				o.gain_momentum(15.0)
			return


func _place_props() -> void:
	var ch := Ring.canvas_half()
	var table := FoldingTable.new()
	add_child(table)
	table.global_position = Vector3(ch + 1.1, 0.03, 0.0)
	table.rotation.y = PI / 2
	tables.append(table)
	var chair := Chair.new()
	chair.add_to_group("chairs")
	add_child(chair)
	chair.global_position = Vector3(-(ch + 1.0), 0.05, 1.6)
	chair.rotation.y = 0.6
	chairs.append(chair)


# ---------------------------------------------------------------- menus

func _toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
	_pause_menu.visible = get_tree().paused
	if get_tree().paused:
		_pause_menu.get_child(0).get_child(1).grab_focus()


func _build_pause_menu() -> void:
	_pause_menu = _menu("PAUSED", [["Resume", _toggle_pause], ["Restart", _restart], ["Main Menu", _quit_to_menu]])


func _show_end_menu() -> void:
	var title := "%s WINS" % winner.display_name.to_upper() if winner.state == Wrestler.State.CELEBRATE else "DRAW"
	_end_menu = _menu(title, [["Rematch", _restart], ["Main Menu", _quit_to_menu]])
	_end_menu.visible = true
	_end_menu.get_child(0).get_child(1).grab_focus()


func _menu(title_text: String, items: Array) -> Control:
	var layer := CanvasLayer.new()
	layer.layer = 10
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.visible = false
	layer.add_child(shade)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-220, -120)
	box.custom_minimum_size = Vector2(440, 0)
	box.add_theme_constant_override("separation", 14)
	shade.add_child(box)
	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color("ff2bd6"))
	box.add_child(title)
	for item in items:
		var b := Button.new()
		b.text = item[0]
		b.add_theme_font_size_override("font_size", 30)
		b.pressed.connect(item[1])
		box.add_child(b)
	return shade


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _quit_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")
