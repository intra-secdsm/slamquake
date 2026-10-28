extends GutTest
## Roster data, movesets, stats, look serialisation and created-wrestler storage.

# per process, so test runs in parallel checkouts never share the file
var TEST_PATH := "user://test_created_wrestlers_%d.json" % OS.get_process_id()
var _saved_path := ""


func before_each() -> void:
	_saved_path = CawStore.path
	CawStore.path = TEST_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	CawStore.reload()


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	CawStore.path = _saved_path
	CawStore.reload()


func test_eight_original_wrestlers() -> void:
	var r := Roster.builtin()
	assert_eq(r.size(), 8)
	var ids := {}
	var finishers := {}
	for e in r:
		ids[e["id"]] = true
		finishers[e["moves"]["finisher"]] = true
		assert_true(e["look"] is WrestlerLook, e["name"])
		assert_true(e["theme"] in Roster.THEMES, e["name"])
		assert_true(e["pyro"] in Roster.PYRO_STYLES, e["name"])
		assert_true(e["motif"] in Roster.MOTIFS, e["name"])
		assert_eq(Stats.total(e["stats"]), Stats.BUDGET, "%s spends the whole budget" % e["name"])
		for slot_id in e["moves"]:
			assert_true(e["moves"][slot_id] in Movesets.slot(slot_id)["options"], "%s: %s" % [e["name"], slot_id])
	assert_eq(ids.size(), 8, "unique ids")
	assert_eq(finishers.size(), 8, "everyone has their own finisher")


func test_slot_defaults_are_built() -> void:
	for s in Movesets.SLOTS:
		assert_true(Movesets.is_available(s["default"]), s["id"])
		assert_true(s["default"] in s["options"], s["id"])


func test_resolve_falls_back_to_defaults() -> void:
	var m := Movesets.resolve({"kick": "no_such_move", "tieup_kick": "suplex", "taunt": "body_slam"})
	assert_eq(m["kick"], "big_boot", "unknown move")
	assert_eq(m["tieup_kick"], "suplex")
	assert_eq(m["taunt"], "taunt", "a move from another slot")
	assert_eq(m.size(), Movesets.SLOTS.size(), "every slot filled")


func test_stats_are_clamped_to_the_budget() -> void:
	var s := Stats.sanitize({"power": 9, "speed": 5, "toughness": 5, "charisma": 0})
	assert_eq(s["charisma"], Stats.MIN)
	assert_lte(Stats.total(s), Stats.BUDGET)
	for n in Stats.NAMES:
		assert_between(s[n], Stats.MIN, Stats.MAX)
	assert_gt(Stats.damage_dealt({"power": 5}), Stats.damage_dealt({"power": 1}))
	assert_lt(Stats.damage_taken({"toughness": 5}), Stats.damage_taken({"toughness": 1}))


func test_look_round_trip() -> void:
	var l := WrestlerLook.new()
	l.mass = -0.4
	l.hair_style = "mohawk"
	l.mask = "classic"
	l.trunks_color = Color("12ab34")
	l.stripes = 7
	l.tights = true
	var back := WrestlerLook.from_dict(JSON.parse_string(JSON.stringify(l.to_dict())))
	assert_almost_eq(back.mass, -0.4, 0.001)
	assert_eq(back.hair_style, "mohawk")
	assert_eq(back.mask, "classic")
	assert_eq(back.trunks_color.to_html(false), "12ab34")
	assert_eq(back.stripes, 7)
	assert_true(back.tights)
	var bad := WrestlerLook.from_dict({"hair_style": "beehive", "mass": 0.5, "junk": 1})
	assert_eq(bad.hair_style, WrestlerLook.new().hair_style, "unknown choices are ignored")
	assert_almost_eq(bad.mass, 0.5, 0.001)


func test_created_wrestlers_are_saved_and_listed() -> void:
	var e := CawStore.blank()
	e["name"] = "Test Dummy"
	e["moves"]["kick"] = "superkick"
	e["stats"] = {"power": 5, "speed": 5, "toughness": 5, "charisma": 5}
	(e["look"] as WrestlerLook).hair_style = "long"
	assert_true(CawStore.put(e))
	CawStore.reload()
	assert_eq(CawStore.entries().size(), 1)
	var back := CawStore.get_by_id(e["id"])
	assert_eq(back["name"], "Test Dummy")
	assert_eq(back["moves"]["kick"], "superkick")
	assert_lte(Stats.total(back["stats"]), Stats.BUDGET)
	assert_eq((back["look"] as WrestlerLook).hair_style, "long")
	assert_eq(Roster.all().size(), Roster.builtin().size() + 1)
	assert_eq(Roster.find(e["id"]), Roster.builtin().size())
	assert_true(CawStore.remove(e["id"]))
	assert_eq(Roster.all().size(), Roster.builtin().size())


func test_broken_save_file_is_ignored() -> void:
	var f := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()
	CawStore.reload()
	assert_eq(CawStore.entries().size(), 0)


func test_match_uses_the_wrestlers_moveset() -> void:
	GameState.rules = "nodq"
	GameState.match_entrants = [
		{"roster": 2, "control": "cpu", "slot": 0, "difficulty": 0},
		{"roster": 0, "control": "cpu", "slot": 1, "difficulty": 0},
	]
	var m: Match = load("res://match/match.tscn").instantiate()
	add_child_autofree(m)
	await wait_physics_frames(2)
	var bruno := m.wrestlers[0]
	assert_eq(bruno.finisher, Movesets.resolve(Roster.builtin()[2]["moves"])["finisher"])
	assert_eq(bruno.stats["power"], 5)
	assert_gt(bruno.damage_boost(), 1.0, "power 5 hits harder")
	assert_eq(bruno.move_for("tieup_kick"), Movesets.resolve(Roster.builtin()[2]["moves"])["tieup_kick"])


func test_cpu_fights_in_character() -> void:
	for e in Roster.builtin():
		assert_true(CpuController.STYLES.has(CpuController.style_for(e)), e["name"])
	var flyer := CpuController.new(2, 1, "highflyer")
	var power := CpuController.new(2, 1, "powerhouse")
	assert_gt(flyer.profile["run"], power.profile["run"])
	assert_gt(power.profile["grapple"], flyer.profile["grapple"])
	assert_eq(CpuController.new(2, 1).profile, CpuController.PROFILES[2], "no style, no change")
	assert_eq(CpuController.style_for({"stats": {"power": 2, "speed": 5, "toughness": 2, "charisma": 3}}), "highflyer")
	assert_eq(CpuController.style_for({"stats": {"power": 5, "speed": 1, "toughness": 4, "charisma": 2}}), "powerhouse")


func test_pause_menu_move_list() -> void:
	GameState.rules = "nodq"
	GameState.match_entrants = [
		{"roster": 4, "control": "human", "slot": 0, "difficulty": 2},
		{"roster": 1, "control": "cpu", "slot": 1, "difficulty": 2},
	]
	var m: Match = load("res://match/match.tscn").instantiate()
	add_child_autofree(m)
	await wait_physics_frames(2)
	m._toggle_pause()
	m._open_move_list()
	assert_true(m._move_list.visible)
	assert_string_contains("\n".join(m._move_list_text.map(func(l: Label) -> String: return l.text)), "SILAS WREN")
	assert_string_contains("\n".join(m._move_list_text.map(func(l: Label) -> String: return l.text)), Movesets.move_name(m.wrestlers[0].finisher).to_upper())
	m._move_list_who = 1
	m._refresh_move_list()
	assert_string_contains("\n".join(m._move_list_text.map(func(l: Label) -> String: return l.text)), "ZIP VOLTA")
	m._close_move_list()
	assert_true(m._pause_menu.visible)
	m._toggle_pause()
	assert_false(get_tree().paused)
