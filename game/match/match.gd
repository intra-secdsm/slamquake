class_name Match
extends Node3D
## Sets up and runs a match from GameState.match_entrants: wrestlers, referee, camera,
## HUD and rules. 1v1, or 2v2 tag team when there are four entrants (legal men in the
## ring, partners on the apron). Win by pinfall (pins under the ropes are broken), or in
## normal rules by count-out (20 while on the floor) or disqualification (weapon shots).

signal match_ended(winner: Wrestler)

const START_SPOTS := [Vector3(-1.5, 0, 0.5), Vector3(1.5, 0, -0.5), Vector3(-1.5, 0, -1.2), Vector3(1.5, 0, 1.2)]
const COUNT_OUT := 20
var count_period := 1.0         ## seconds per count-out number

var ring: Ring
var arena: Arena
var camera: BroadcastCamera
var hud: MatchHud
var referee: Referee
var wrestlers: Array[Wrestler] = []
var tag_mode := false
var intro := false                 ## entrances are playing; the match hasn't started
var replay: Replay
var winner: Wrestler               ## set when the match ends (a wrestler even on a draw)
var finish_reason := ""
var _finished := false
var tables: Array[FoldingTable] = []
var chairs: Array[Chair] = []
var _pin: Dictionary = {}          # {attacker, defender}
var _saved := false
var _finisher_by: Array = []
var _last_pin_attacker: Wrestler
var _last_pin_defender: Wrestler
var _count := 0
var _count_t := 0.0
var _pause_menu: Control
var _move_list: Control
var _move_list_text: Array[Label] = []   # header, inputs column, moves column, footer
var _move_list_who := 0
var _end_menu: Control


func _ready() -> void:
	add_child(ArenaLighting.new())
	arena = Arena.new()
	add_child(arena)
	ring = Ring.new()
	add_child(ring)
	camera = BroadcastCamera.new()
	add_child(camera)
	camera.current = true

	var help: Array[String] = []
	var used := {}
	tag_mode = GameState.match_entrants.size() == 4
	for i in GameState.match_entrants.size():
		var e: Dictionary = GameState.match_entrants[i]
		var entry := Roster.get_entry(e["roster"])
		var w := Wrestler.new()
		w.name = "Wrestler%d" % (i + 1)
		w.look = entry["look"]
		if used.has(e["roster"]):
			w.look = Roster.alt_look(entry["look"])   # same wrestler twice: alternate colours
		used[e["roster"]] = true
		w.team = int(e.get("team", i % 2))
		w.set_meta("roster", e["roster"])
		w.display_name = entry["name"]
		w.moves = (entry.get("moves", {}) as Dictionary).duplicate()
		w.stats = (entry.get("stats", Stats.defaults()) as Dictionary).duplicate()
		w.ring = ring
		if e["control"] == "human":
			w.controller = PlayerController.new(e["slot"])
			help.append("P%d  " % (e["slot"] + 1) + InputRouter.describe(e["slot"]).replace("\n", "\n      "))
		else:
			w.controller = CpuController.new(e["difficulty"], 0, CpuController.style_for(entry))
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
		w.tagged.connect(_on_tagged)
		w.pin_saved.connect(_on_pin_saved)
		w.double_team.connect(_on_double_team)
		w.move_performed.connect(_on_move_performed)
		w.reversed.connect(_on_reversed)
		w.special_ready.connect(_on_special_ready)
		wrestlers.append(w)
		camera.targets.append(w)

	for w in wrestlers:
		for o in wrestlers:
			if o == w:
				continue
			if o.team != w.team:
				w.opponents.append(o)
			else:
				w.teammate = o
	if tag_mode:
		_setup_tag_teams()

	_place_props()

	referee = Referee.new()
	add_child(referee)
	referee.global_position = Vector3(0, Ring.canvas_height(), -2.2)
	referee.wrestlers = wrestlers
	referee.counted.connect(_on_count)
	replay = Replay.new()
	add_child(replay)
	replay.setup(self)

	hud = MatchHud.new()
	add_child(hud)
	if tag_mode:
		help.append("TAG: grapple at your corner = tag · on the apron, push toward the ring = come in (5 s)"
			+ " · hit a pinner = save · grapple a foe your partner has tied up = double team")
	# the moves named are the first human's (everyone's are in the pause menu's move list)
	var you: Wrestler = wrestlers[0]
	for w in wrestlers:
		if w.controller is PlayerController:
			you = w
			break
	var mv := func(slot_id: String) -> String: return Movesets.move_name(you.move_for(slot_id)).to_lower()
	help.append("Tie-up (grapple): punch = %s / +dir %s · kick = %s / +dir %s · run = Irish whip"
			% [mv.call("tieup_punch"), mv.call("tieup_punch_dir"), mv.call("tieup_kick"), mv.call("tieup_kick_dir")]
		+ " · taunt with SPECIAL = %s\n" % you.finisher_name()
		+ "Tap block just before a hit lands to PARRY · tap block as they start a move on you to REVERSE\n"
		+ "Opponent down: grapple = pick up · punch = %s · kick = stomp · block = PIN\n" % mv.call("ground_punch")
		+ "Push into the ropes to roll out · grapple near a corner to climb · grapple near a chair to pick it up")
	hud.setup(wrestlers, "\n".join(help))
	AudioDirector.crowd_ambience(true)
	# the director keeps listening for unpause; everything else freezes
	process_mode = Node.PROCESS_MODE_ALWAYS
	for c in get_children():
		c.process_mode = Node.PROCESS_MODE_PAUSABLE
	_build_pause_menu()
	if DevTools.has_arg("movelist"):      # dev: screenshot the pause menu's move list
		get_tree().create_timer(0.5).timeout.connect(func() -> void:
			_toggle_pause()
			_open_move_list())
	var dummy := GameState.match_entrants.any(func(e: Dictionary) -> bool:
		return e["control"] == "cpu" and int(e["difficulty"]) == 0)
	if Settings.entrances and not dummy:
		intro = true
		var ent := Entrance.new()
		ent.match_node = self
		add_child(ent)
		ent.finished.connect(_begin_fight)
		ent.run()
	else:
		AudioDirector.play_music("", 0.5)
		_begin_fight()


func _begin_fight() -> void:
	intro = false
	AudioDirector.play_music("", 1.5)
	arena.titantron.show_text(team_name(wrestlers[0]), "VS  " + team_name(wrestlers[1]))
	AudioDirector.play("bell", camera.global_position + Vector3.FORWARD * 3.0, -4.0)
	hud.banner("FIGHT!", 1.2)


## Crowd heat: big moments push it up, it settles back to a murmur.
func excite(amount: float, flash: float = 0.0) -> void:
	arena.heat += amount
	if flash > 0.0:
		arena.crowd.pop(flash)


func _process(delta: float) -> void:
	arena.heat = move_toward(arena.heat, 0.3, delta * 0.04)
	AudioDirector.set_crowd(arena.heat)


func _physics_process(delta: float) -> void:
	if tag_mode and not intro:
		_update_tag_view()
	if get_tree().paused or winner or intro:
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
	if _move_list and _move_list.visible:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
			_close_move_list()
		elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
			_move_list_who = wrapi(_move_list_who + (1 if event.is_action_pressed("ui_right") else -1), 0, wrestlers.size())
			_refresh_move_list()
		get_viewport().set_input_as_handled()
		return
	if get_tree().paused and _pause_menu.visible and event.is_action_pressed("ui_cancel"):
		_toggle_pause()
		get_viewport().set_input_as_handled()
		return
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
	replay.mark("pin")
	referee.start_count(defender)
	excite(0.08)


func _on_count(n: int) -> void:
	if _pin.is_empty():
		return
	_last_pin_attacker = _pin["attacker"]
	_last_pin_defender = _pin["defender"]
	hud.banner(str(n) if n < 3 else "THREE!", 0.8 if n < 3 else 2.0)
	if n >= 3:
		_finish(_pin["attacker"], _pin["defender"])


func _on_kicked_out(defender: Wrestler) -> void:
	if _pin.is_empty() or _pin["defender"] != defender:
		return
	if referee.count == 2 and not _saved:
		hud.banner("KICK OUT AT 2!", 1.2)
		excite(0.3, 0.6)
	_saved = false
	_pin = {}
	hud.show_kickout(null, 0.0)
	referee.stop_count()


## The referee's current count-out number (0 when nobody is outside).
func outside_count() -> int:
	return _count


func _count_out(delta: float) -> void:
	var out: Array[Wrestler] = []
	for w in wrestlers:
		if w.outside and w.legal and not w.on_apron():
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
			var teams_out := {}
			for w in out:
				teams_out[w.team] = true
			if teams_out.size() > 1:
				_finish(null, null, "DOUBLE COUNT-OUT")
			else:
				_finish(out[0].opponents[0], out[0], "COUNT-OUT")


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
		if win and w.team == win.team:
			w.win()
		else:
			w.lose()
	AudioDirector.play("bell_triple", camera.global_position + Vector3.FORWARD * 3.0, -2.0)
	excite(1.0, 1.0)
	camera.shake(0.6)
	if reason != "":
		hud.banner(reason + "!", 1.2)
	await get_tree().create_timer(1.2).timeout
	if reason == "" and Settings.replays:
		await _play_replay()
	if win:
		AudioDirector.play_music("victory", 0.2, false)
		var entry := Roster.get_entry(int(win.get_meta("roster", 0)))
		var c: Color = entry.get("color", Color("ffd400"))
		arena.titantron.show_text(team_name(win), "WINNER", c, c.lerp(Color.WHITE, 0.4), entry.get("motif", "grid"))
	hud.banner("WINNER: %s" % team_name(win) if win else "NO CONTEST", 3.5)
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
	excite(float(move.get("damage", 0)) * 0.006)
	var at := victim.body_center().lerp(attacker.global_position + Vector3.UP * 1.3, 0.25)
	HitFx.spawn(self, at, heavy)
	camera.shake(1.0 if heavy else 0.35)


## "THUNDER MACK" or "THUNDER MACK & ZIP VOLTA".
func team_name(w: Wrestler) -> String:
	var n := w.display_name.to_upper()
	if w.teammate:
		n += " & " + w.teammate.display_name.to_upper()
	return n


func _setup_tag_teams() -> void:
	var y := Ring.canvas_height()
	var post := float(Ring.spec()["post_half"])
	var first := {}
	for w in wrestlers:
		w.apron_spot = Vector3(-1.9 if w.team == 0 else 1.9, y, -(post + 0.25))
		w.legal = not first.has(w.team)
		first[w.team] = true
		if not w.legal:
			w.global_position = w.apron_spot
			w._enter(Wrestler.State.APRON)


## Camera and referee follow whoever is in the action, not the partners waiting on the apron.
func _update_tag_view() -> void:
	var active: Array[Wrestler] = []
	for w in wrestlers:
		if w.state != Wrestler.State.APRON:
			active.append(w)
		hud.set_status(w, _tag_status(w))
	camera.targets.assign(active)
	referee.wrestlers = active


func _tag_status(w: Wrestler) -> String:
	if winner or w.legal:
		return ""
	if w.on_apron():
		return "on the apron"
	if w.forced_return:
		return "REF: BACK TO YOUR CORNER!"
	return "ILLEGAL  %d" % ceili(Wrestler.ILLEGAL_TIME - w.illegal_time)


func _on_tagged(_out: Wrestler, into: Wrestler, hot: bool) -> void:
	hud.banner("HOT TAG!" if hot else "TAG!", 1.2)
	hud.popup("TAGGED IN!", into)
	AudioDirector.play("mat_slap", into.global_position + Vector3.UP * 1.3, 2.0)
	if hot:
		_crowd("crowd_pop", -4.0)
		excite(0.35, 0.5)


func _on_pin_saved(by: Wrestler, _pinner: Wrestler) -> void:
	_saved = true
	hud.banner("SAVE!", 1.2)
	hud.popup("SAVE!", by)
	_crowd("crowd_ooh", -4.0)


func _on_double_team(_a: Wrestler, _b: Wrestler, _victim: Wrestler) -> void:
	hud.banner("DOUBLE TEAM!", 1.4)
	_crowd("crowd_ooh", -5.0)


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
		excite(0.12)
	# call out the big moves by name (finishers get the full cinematic instead)
	if not mv.get("finisher", false) and (float(mv.get("damage", 0.0)) >= 12.0 or id.begins_with("dive_")) \
			and id not in ["dive_whiff", "dive_crossbody", "double_suplex"]:
		hud.popup(Movesets.move_name(id).to_upper() + "!", w)


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
	replay.mark("finisher")
	_finisher_by = [w, w.partner]
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
	excite(0.6, 1.0)


## The finish again, on tape: the last finisher if it was recent, else the run-up to the pin.
func _play_replay() -> void:
	var hz := Engine.physics_ticks_per_second
	var ago := replay.frames_since("finisher")
	var subjects: Array = _finisher_by.filter(func(n: Variant) -> bool: return is_instance_valid(n))
	var start := ago + int(0.3 * hz)
	var length := int(3.2 * hz)
	if ago < 0 or subjects.size() < 2:
		ago = replay.frames_since("pin")
		if ago < 0:
			return
		start = ago + int(3.5 * hz)
		length = int(4.0 * hz)
		subjects = [_last_pin_attacker, _last_pin_defender]
	hud.banner("", 0.0)
	await replay.play(start, length, subjects)


func _crowd(sfx: String, volume: float) -> void:
	AudioDirector.play(sfx, camera.global_position + camera.global_basis.z * -2.0, volume, 0.04)


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	AudioDirector.crowd_ambience(false)


func _on_landed_outside(w: Wrestler, at: Vector3) -> void:
	for t in tables:
		if t.intact and t.covers(at):
			t.smash()
			w._damage(10.0)
			camera.shake(1.6)
			hud.banner("THROUGH THE TABLE!", 1.6)
			_crowd("crowd_pop", -4.0)
			excite(0.45, 0.8)
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
	_move_list.visible = false
	if get_tree().paused:
		_pause_menu.get_child(0).get_child(1).grab_focus()


func _build_pause_menu() -> void:
	_pause_menu = _menu("PAUSED", [["Resume", _toggle_pause], ["Move List", _open_move_list], ["Restart", _restart],
		["Main Menu", _quit_to_menu]])
	_build_move_list()


func _build_move_list() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 11
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	_move_list = ColorRect.new()
	(_move_list as ColorRect).color = Color(0.02, 0.0, 0.06, 0.88)
	_move_list.set_anchors_preset(Control.PRESET_FULL_RECT)
	_move_list.visible = false
	layer.add_child(_move_list)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-600, -430)
	box.custom_minimum_size = Vector2(1200, 0)
	box.add_theme_constant_override("separation", 18)
	_move_list.add_child(box)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 48)
	for i in 4:
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 40 if i == 0 else (26 if i < 3 else 22))
		l.add_theme_color_override("font_color", [Color.WHITE, Color(1, 1, 1, 0.75), Color("ffd400"),
			Color(1, 1, 1, 0.8)][i])
		l.add_theme_color_override("font_outline_color", Color("ff2bd6") if i == 0 else Color.BLACK)
		l.add_theme_constant_override("outline_size", 10 if i == 0 else 6)
		_move_list_text.append(l)
		if i == 1 or i == 2:
			columns.add_child(l)
		else:
			box.add_child(l)
		if i == 0:
			box.add_child(columns)


## The pause menu's move list starts on the first human's wrestler; ←→ flips through everyone.
func _open_move_list() -> void:
	_move_list_who = 0
	for i in wrestlers.size():
		if wrestlers[i].controller is PlayerController:
			_move_list_who = i
			break
	_refresh_move_list()
	_pause_menu.visible = false
	_move_list.visible = true


func _close_move_list() -> void:
	_move_list.visible = false
	_pause_menu.visible = true
	_pause_menu.get_child(0).get_child(2).grab_focus()


func _refresh_move_list() -> void:
	var w := wrestlers[_move_list_who]
	var who := "CPU"
	if w.controller is PlayerController:
		who = "P%d" % ((w.controller as PlayerController).slot + 1)
	_move_list_text[0].text = "◀  %s · %s  ▶" % [w.display_name.to_upper(), who]
	var inputs: Array[String] = []
	var names: Array[String] = []
	for row in Movesets.move_list(w.moves):
		inputs.append(row[0])
		names.append(String(row[1]).to_upper() + ("   ★ FINISHER" if names.is_empty() else ""))
	_move_list_text[1].text = "\n".join(inputs)
	_move_list_text[2].text = "\n".join(names)
	var lines: Array[String] = [
		"Block: hold to guard · tap just before a hit = PARRY · tap as a move starts on you = REVERSE",
		"Run: hold · Downed opponent: grapple = pick up · kick = stomp · block = PIN",
		"Grapple at a corner = climb · at a chair = pick it up · into the ropes = roll out"]
	if tag_mode:
		lines.append("Grapple at your corner = TAG · hit a pinner = SAVE")
	lines.append("")
	lines.append("←→ other wrestlers    A / B: back")
	_move_list_text[3].text = "\n".join(lines)


func _show_end_menu() -> void:
	var title := "%s WIN%s" % [team_name(winner), "" if tag_mode else "S"] \
		if winner.state == Wrestler.State.CELEBRATE else "DRAW"
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
