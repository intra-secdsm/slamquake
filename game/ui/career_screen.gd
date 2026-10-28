extends Node
## Career mode's screens, over the live arena (MenuStage):
##   start    continue the saved career, or start a new one
##   new      pick your wrestler and the CPU difficulty
##   story    promo scenes: the cast in the ring, a comic-style caption per line
##   hub      tonight's show and your match, with the rankings, titles and record a press away
##   results  after a match: how it went, the rest of the card, anything unlocked
## A match result arrives in GameState.career_result (set by the match's Continue button).

const PINK := Color("ff2bd6")
const CYAN := Color("00e5ff")
const GOLD := Color("ffd400")

var career: Career
var _stage: MenuStage
var _page := ""
var _panel: Control
var _title: Label
var _sub: Label
var _body: RichTextLabel
var _list: VBoxContainer
var _hint: Label
var _rows: Array[Button] = []
var _defs: Array[Dictionary] = []
var _confirm := ""
# new career picks
var _pick := 0
var _level := 2
# story scenes
var _scenes: Array = []          # beats still to show
var _line := 0
var _after_story := Callable()
var _caption: PanelContainer
var _speaker: Label
var _words: Label
var _typing: Tween
# results waiting to be shown after the story scenes
var _report := {}


func _ready() -> void:
	if DevTools.has_arg("career_page"):
		# dev screenshots make throwaway careers: never in the player's real saves
		Career.path = "user://dev_career.json"
		Unlocks.path = "user://dev_unlocks.json"
		Career.erase_save()
		Unlocks.reload()
	_stage = MenuStage.new()
	add_child(_stage)
	var crt := CrtOverlay.new()
	crt.visible = Settings.crt
	add_child(crt)
	AudioDirector.crowd_ambience(true)
	AudioDirector.set_crowd(0.35)
	var layer := CanvasLayer.new()
	add_child(layer)
	_build_panel(layer)
	_build_caption(layer)

	career = GameState.career
	if career and GameState.career_result != "":
		var result := GameState.career_result
		GameState.career_result = ""
		GameState.end_career_match()
		_show_results(career.record(result))
	elif career:
		GameState.end_career_match()
		_show_hub()
	else:
		_show_start()
	# dev: --career_page=new|hub|story|rankings|record|results [--career_pick=N --career_weeks=N
	#      --career_champ --career_play --career_line=N]
	if DevTools.has_arg("career_page"):
		_dev_page(DevTools.get_arg("career_page"))


# ---------------------------------------------------------------- pages

func _show_start() -> void:
	AudioDirector.play_music("theme_menu", 0.6)
	var saved := Career.load_saved()
	if saved == null or not saved.playable():
		if saved:
			_page = "start"
			_layout("CAREER", "Your career's wrestler no longer exists (a created wrestler that was deleted).")
			_build([{"text": "★  NEW CAREER  ★", "press": _show_new}, {"text": "Back", "press": _to_menu}])
			return
		_show_new()
		return
	_page = "start"
	_layout("CAREER", "")
	_body.text = "[b]%s[/b]\n%s\n%s" % [saved.name_of(saved.you), saved.date_text(), _standing(saved)]
	_stage.show_lineup([saved.entry(saved.you)["look"]], [saved.belts().get(saved.you, 0)])
	_build([
		{"text": "★  CONTINUE  ★", "press": func() -> void:
			career = saved
			GameState.career = saved
			_show_hub()},
		{"text": func() -> String: return "Start over? This career will be lost. Press again" \
				if _confirm == "new" else "New career",
			"press": func() -> void:
				if _confirm == "new":
					_show_new()
				else:
					_confirm = "new"
					_refresh()},
		{"text": "Back", "press": _to_menu},
	])


func _show_new() -> void:
	_page = "new"
	_confirm = ""
	_pick = clampi(_pick, 0, Roster.all().size() - 1)
	_layout("NEW CAREER", "")
	_build([
		{"text": func() -> String: return "◀  Wrestler: %s  ▶" % Roster.get_entry(_pick)["name"],
			"change": func(step: int) -> void:
				_pick = wrapi(_pick + step, 0, Roster.all().size())
				_new_preview()},
		{"text": func() -> String: return "◀  CPU Difficulty: %s  ▶" % GameState.DIFFICULTIES[_level],
			"change": func(step: int) -> void: _level = wrapi(_level + step, 1, GameState.DIFFICULTIES.size())},
		{"text": "★  START CAREER  ★", "press": _start_career},
		{"text": "Back", "press": _to_menu},
	])
	_new_preview()


func _new_preview() -> void:
	var e := Roster.get_entry(_pick)
	_stage.show_lineup([e["look"]])
	_body.text = "[color=#ffd400]%s[/color]\nStart at the bottom of the rankings on %s. Win to climb: " % [
		e.get("tagline", ""), Career.SHOW.capitalize()] \
		+ "whoever is number one when a month begins gets a World title shot at that month's pay-per-view. " \
		+ "A tag partner, rivals, and a few secrets along the way."


func _start_career() -> void:
	career = Career.start(Roster.get_entry(_pick)["id"], _level)
	career.save()
	GameState.career = career
	_show_hub()


func _show_hub() -> void:
	_page = "hub"
	_confirm = ""
	AudioDirector.play_music("theme_anthem" if career.is_ppv() else "theme_menu", 0.6)
	var beats := career.beats()
	if not beats.is_empty() and not _seen_story():
		_play_story(beats, _show_hub)
		return
	var card := career.card()
	_layout(career.event_name(), career.date_text())
	_titantron()
	var us: Array = [career.you] + ([card["partner"]] if card["partner"] != "" else [])
	var lines := "[color=#ffd400]TONIGHT: %s[/color]\n[b]%s[/b]\n[i]vs[/i]\n[b]%s[/b]\n\n%s" % [card["label"],
		" & ".join(us.map(_who)), " & ".join((card["opponents"] as Array).map(_who)), _standing(career)]
	_body.text = lines
	var looks := []
	var belts := []
	var belt_of := career.belts()
	for id in us + card["opponents"]:
		looks.append(career.entry(id)["look"])
		belts.append(belt_of.get(id, 0))
	_stage.show_lineup(looks, belts)
	_build([
		{"text": "★  TO THE RING  ★", "press": _play_match},
		{"text": "Rankings & titles", "press": _show_rankings},
		{"text": "Record & unlocks", "press": _show_record},
		{"text": "Save & quit", "press": func() -> void:
			career.save()
			_to_menu()},
	])


## The show's name up on the titantron.
func _titantron() -> void:
	var ppv := career.is_ppv()
	_stage.arena.titantron.show_text(career.event_name(), "PAY-PER-VIEW" if ppv else "LIVE TONIGHT",
		GOLD if ppv else PINK, CYAN, "stars" if ppv else "grid")


## Story scenes play once per week: remember which week was last told.
func _seen_story() -> bool:
	return GameState.get_meta("career_story_week", -1) == career.week


func _play_match() -> void:
	var card := career.card()
	GameState.career = career
	GameState.career_card = card
	GameState.career_result = ""
	GameState.match_entrants = career.entrants()
	GameState.rules = card["rules"]
	GameState.belts = career.belts()
	AudioDirector.play_music("", 0.6)
	AudioDirector.crowd_ambience(false)
	get_tree().change_scene_to_file("res://match/match.tscn")


func _show_rankings() -> void:
	_page = "rankings"
	_layout("RANKINGS", career.date_text())
	var t := "[color=#ffd400]WORLD HEAVYWEIGHT CHAMPION[/color]\n   %s\n" % _row_text(career.champion, 0)
	t += "[color=#ffd400]TAG TEAM CHAMPIONS[/color]\n   %s\n\n" % career.team_name(career.tag_champs)
	var r := career.ranking()
	for i in r.size():
		t += "%2d.  %s\n" % [i + 1, _row_text(r[i], i + 1)]
	t += "\nNumber one when the month begins challenges for the World title at %s." % career.ppv_name()
	_body.text = t
	_build([{"text": "Back", "press": _show_hub}])


func _row_text(id: String, rank: int) -> String:
	var line := "%s   [color=#9aa0b0]%d pts  ·  %d-%d[/color]" % [career.name_of(id), career.points[id],
		career.wins[id], career.losses[id]]
	if id == career.you:
		line = "[color=#00e5ff]%s  ◀ YOU[/color]" % line
	elif id == career.contender and rank >= 0:
		line += "  [color=#ff2bd6]%s CONTENDER[/color]" % career.ppv_name()
	return line


func _show_record() -> void:
	_page = "record"
	_layout("RECORD", career.name_of(career.you))
	var t := "%d wins, %d losses\n" % [career.wins[career.you], career.losses[career.you]]
	t += "World title reigns: %d  ·  Tag title reigns: %d\n\n" % [career.reigns["world"], career.reigns["tag"]]
	t += "[color=#ffd400]LATELY[/color]\n"
	var recent := career.history.slice(maxi(0, career.history.size() - 5))
	recent.reverse()
	for h in recent:
		t += "%s: %s\n" % [String(h[0]).capitalize(), h[1]]
	if recent.is_empty():
		t += "Nothing yet. Your debut awaits.\n"
	t += "\n[color=#ffd400]UNLOCKS[/color]\n"
	for id in Unlocks.ITEMS:
		var item: Dictionary = Unlocks.ITEMS[id]
		t += ("[color=#3dff6e]✔ %s[/color]\n" % item["name"]) if Unlocks.has(id) else "✘ %s\n" % item["how"]
	_body.text = t
	_build([{"text": "Back", "press": _show_hub}])


func _show_results(report: Dictionary) -> void:
	_page = "results"
	_report = report
	var verdict := {"win": "VICTORY!", "loss": "DEFEAT", "draw": "DRAW"}
	_layout(verdict.get(report["result"], ""), report["headline"])
	AudioDirector.play_music("victory" if report["result"] == "win" else "theme_menu", 0.4,
		report["result"] != "win")
	var t := ""
	if not report["unlocked"].is_empty():
		t += "[color=#3dff6e]UNLOCKED![/color]\n"
		for u in report["unlocked"]:
			t += "★ %s\n" % u
		t += "\n"
	t += "[color=#ffd400]ELSEWHERE TONIGHT[/color]\n"
	for line in report["results"]:
		t += "%s\n" % line
	t += "\n" + _standing(career)
	_body.text = t
	_stage.show_lineup([career.entry(career.you)["look"]], [career.belts().get(career.you, 0)])
	_build([{"text": "Continue", "press": func() -> void:
		var beats: Array = report["beats"].filter(func(b: Dictionary) -> bool: return not b["lines"].is_empty())
		if beats.is_empty():
			_show_hub()
		else:
			_play_story(beats, _show_hub)}])


func _to_menu() -> void:
	GameState.career = null
	GameState.end_career_match()
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")


## "Bruno Kessler (#3)" / "(CHAMPION)"
func _who(id: String) -> String:
	var r := career.rank_of(id)
	return "%s (%s)" % [career.name_of(id), "CHAMPION" if r == 0 else "#%d" % r]


func _standing(c: Career) -> String:
	var r := c.rank_of(c.you)
	var t := "WORLD HEAVYWEIGHT CHAMPION" if r == 0 else "Ranked #%d of %d  ·  %d pts" % [r, c.ranking().size(),
		c.points[c.you]]
	t += "  ·  %d-%d" % [c.wins[c.you], c.losses[c.you]]
	if c.you in c.tag_champs:
		t += "\nTag team champions with %s" % c.name_of(c.partner)
	elif c.week >= 1:
		t += "\nTag team with %s: %d of %d wins toward a title shot" % [c.name_of(c.partner),
			mini(c.tag_wins, Career.TAG_WINS_FOR_SHOT), Career.TAG_WINS_FOR_SHOT]
	return t


# ---------------------------------------------------------------- story scenes

func _play_story(beats: Array, then: Callable) -> void:
	_page = "story"
	_scenes = beats.duplicate()
	_after_story = then
	if career:
		GameState.set_meta("career_story_week", career.week)
	_panel.visible = false
	_caption.visible = true
	for b in _rows:
		b.release_focus()
	_start_scene()


func _start_scene() -> void:
	_titantron()
	_line = 0
	var beat: Dictionary = _scenes[0]
	_show_line(beat)


func _show_line(beat: Dictionary) -> void:
	var line: Array = beat["lines"][_line]
	var who: String = line[0]
	var cast: Array = beat["cast"].keys()
	var looks := []
	var belts := []
	var belt_of := career.belts()
	for role in cast:
		var id: String = beat["cast"][role]
		looks.append(career.entry(id)["look"])
		belts.append(belt_of.get(id, 0))
	if looks.is_empty():
		looks.append(career.entry(career.you)["look"])
		belts.append(belt_of.get(career.you, 0))
	_stage.promo(looks, belts, cast.find(who))
	var host := who == "host"
	_speaker.text = Stories.HOST if host else career.name_of(beat["cast"][who]).to_upper()
	var col: Color = GOLD if host else career.entry(beat["cast"][who]).get("color", PINK)
	_speaker.add_theme_color_override("font_color", col)
	var sb := _caption.get_theme_stylebox("panel") as StyleBoxFlat
	sb.bg_color = Color(1.0, 0.93, 0.55) if host else Color(0.98, 0.98, 0.96)
	sb.border_color = col.darkened(0.2) if not host else Color(0.1, 0.08, 0.02)
	_words.text = line[1]
	_words.visible_ratio = 0.0
	if _typing:
		_typing.kill()
	_typing = create_tween()
	_typing.tween_property(_words, "visible_ratio", 1.0, clampf(String(line[1]).length() * 0.022, 0.3, 2.5))


func _next_line() -> void:
	if _words.visible_ratio < 1.0:
		_typing.kill()
		_words.visible_ratio = 1.0
		return
	AudioDirector.play("hit_light", Vector3.ZERO, -16.0)
	var beat: Dictionary = _scenes[0]
	_line += 1
	if _line < beat["lines"].size():
		_show_line(beat)
		return
	_scenes.pop_front()
	if not _scenes.is_empty():
		_start_scene()
	else:
		_end_story()


func _end_story() -> void:
	_caption.visible = false
	_panel.visible = true
	_scenes.clear()
	_after_story.call()


func _unhandled_input(event: InputEvent) -> void:
	if _page == "story":
		if event.is_action_pressed("ui_accept") or event is InputEventMouseButton and event.pressed:
			_next_line()
		elif event.is_action_pressed("ui_cancel"):
			_end_story()
		else:
			return
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		match _page:
			"rankings", "record": _show_hub()
			"new", "start": _to_menu()
			_: return
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- building blocks

func _build_panel(layer: CanvasLayer) -> void:
	_panel = Control.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_panel)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.0, 0.06, 0.8)
	shade.position = Vector2(40, 40)
	shade.size = Vector2(840, 1000)
	_panel.add_child(shade)
	var box := VBoxContainer.new()
	box.position = Vector2(80, 60)
	box.custom_minimum_size = Vector2(760, 0)
	box.add_theme_constant_override("separation", 10)
	_panel.add_child(box)
	_title = _label(64, PINK, CYAN, 10)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.custom_minimum_size = Vector2(760, 0)
	box.add_child(_title)
	_sub = _label(24, GOLD, Color.BLACK, 6)
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub.custom_minimum_size = Vector2(760, 0)
	box.add_child(_sub)
	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = true
	_body.scroll_active = false
	_body.custom_minimum_size = Vector2(760, 0)
	_body.add_theme_font_size_override("normal_font_size", 24)
	_body.add_theme_font_size_override("bold_font_size", 30)
	_body.add_theme_font_size_override("italics_font_size", 22)
	_body.add_theme_constant_override("outline_size", 4)
	_body.add_theme_color_override("font_outline_color", Color.BLACK)
	box.add_child(_body)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	box.add_child(_list)
	_hint = _label(18, Color(1, 1, 1, 0.7), Color.BLACK, 4)
	_hint.text = "↑↓ select   ←→ change   A: press   B: back"
	box.add_child(_hint)


func _build_caption(layer: CanvasLayer) -> void:
	_caption = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.set_border_width_all(6)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 36
	sb.content_margin_right = 36
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_offset = Vector2(10, 10)
	_caption.add_theme_stylebox_override("panel", sb)
	_caption.position = Vector2(160, 760)
	_caption.custom_minimum_size = Vector2(1600, 250)
	_caption.visible = false
	layer.add_child(_caption)
	var v := VBoxContainer.new()
	_caption.add_child(v)
	_speaker = _label(34, PINK, Color.BLACK, 8)
	v.add_child(_speaker)
	_words = Label.new()
	_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_words.custom_minimum_size = Vector2(1520, 0)
	_words.add_theme_font_size_override("font_size", 36)
	_words.add_theme_color_override("font_color", Color(0.06, 0.05, 0.08))
	v.add_child(_words)
	var more := _label(18, Color(0.2, 0.2, 0.25), Color.TRANSPARENT, 0)
	more.text = "A / Enter: next      B / Esc: skip"
	more.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(more)


func _label(font_size: int, color: Color, outline: Color, outline_size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", outline)
	l.add_theme_constant_override("outline_size", outline_size)
	return l


func _layout(title: String, sub: String) -> void:
	_panel.visible = true
	_caption.visible = false
	_title.text = title
	_sub.text = sub
	_sub.visible = sub != ""
	_body.text = ""


## Rows: {text: String or Callable, press: Callable} or {text, change: Callable(step)}.
func _build(defs: Array[Dictionary]) -> void:
	_defs = defs
	for b in _rows:
		b.queue_free()
	_rows.clear()
	for i in defs.size():
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 30)
		b.gui_input.connect(_on_row_input.bind(i))
		b.pressed.connect(_on_row_pressed.bind(i))
		_list.add_child(b)
		_rows.append(b)
	_refresh()
	_grab_focus.call_deferred(_rows[0].get_instance_id())


func _refresh() -> void:
	for i in _rows.size():
		var t: Variant = _defs[i]["text"]
		_rows[i].text = t.call() if t is Callable else String(t)


## Deferred so a fresh row is in the tree; skipped if the rows were rebuilt meanwhile.
func _grab_focus(id: int) -> void:
	var b := instance_from_id(id) as Control
	if b and b.is_inside_tree() and not b.is_queued_for_deletion() and _page != "story":
		b.grab_focus()


func _on_row_input(event: InputEvent, i: int) -> void:
	var step := 0
	if event.is_action_pressed("ui_left", true):
		step = -1
	elif event.is_action_pressed("ui_right", true):
		step = 1
	if step == 0 or not _defs[i].has("change"):
		return
	_defs[i]["change"].call(step)
	AudioDirector.play("hit_light", Vector3.ZERO, -14.0)
	_refresh()
	get_viewport().set_input_as_handled()


func _on_row_pressed(i: int) -> void:
	var d := _defs[i]
	if d.has("press"):
		d["press"].call()
	elif d.has("change"):
		d["change"].call(1)
	if i < _rows.size():
		_refresh()


func _dev_page(page: String) -> void:
	if career == null:
		career = Career.start(Roster.get_entry(int(DevTools.get_arg("career_pick", "0")))["id"], 2, 7)
		GameState.career = career
		for i in int(DevTools.get_arg("career_weeks", "0")):
			career.record("win")
		if DevTools.has_arg("career_champ"):     # dev: start as the World champion
			career.champion = career.you
			career._start_month()
	match page:
		"new": _show_new()
		"hub":
			GameState.set_meta("career_story_week", career.week)
			_show_hub()
			if DevTools.has_arg("career_play"):  # dev: straight to the ring
				_play_match()
		"story":
			var beats := career.beats()
			_play_story(beats, _show_hub)
			for k in int(DevTools.get_arg("career_line", "0")):
				_words.visible_ratio = 1.0
				_next_line()
		"rankings": _show_rankings()
		"record": _show_record()
		"results":
			var r := career.record("win")
			_show_results(r)
