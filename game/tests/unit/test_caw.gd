extends GutTest
## The create-a-wrestler editor: hub, tabs, rows, stats budget, name entry, saving,
## deleting, and playing a match as a created wrestler.

var TEST_PATH := "user://test_caw_%d.json" % OS.get_process_id()
var _saved_path := ""
var stage: MenuStage
var ed: CawEditor


func before_each() -> void:
	CawStore.path = TEST_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	CawStore.reload()
	stage = MenuStage.new()
	add_child_autofree(stage)
	ed = CawEditor.new()
	ed.stage = stage
	add_child_autofree(ed)
	ed.open()


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	CawStore.reload()


# the test file is used for the whole script, so nothing can ever touch the real saves
func before_all() -> void:
	_saved_path = CawStore.path
	CawStore.path = TEST_PATH


func after_all() -> void:
	CawStore.path = _saved_path
	CawStore.reload()


func _row(prefix: String) -> int:
	for i in ed._rows.size():
		if ed._rows[i].text.strip_edges().trim_prefix("◀").strip_edges().begins_with(prefix):
			return i
	return -1


func _press(prefix: String) -> void:
	var i := _row(prefix)
	assert_gt(i, -1, "row " + prefix)
	ed._on_row_pressed(i)


func _step(prefix: String, step: int) -> void:
	var i := _row(prefix)
	assert_gt(i, -1, "row " + prefix)
	ed._defs[i]["change"].call(step)
	ed._changed()
	ed._refresh()


func test_new_wrestler_is_edited_and_saved() -> void:
	_press("★  NEW WRESTLER")
	assert_eq(ed._page, "edit")
	var before: Color = ed._entry["color"]
	_step("Colour", 1)
	assert_ne(ed._entry["color"], before)
	ed._set_tab(1)
	_step("Body type", 1)
	assert_eq(ed._look.feminine, 1.0)
	_step("Height", 1)
	assert_gt(ed._look.height, 1.0)
	ed._set_tab(2)
	_step("Hair:", 1)
	assert_ne(ed._look.hair_style, "mullet")
	ed._set_tab(4)
	_step("Kick", 1)
	assert_eq(ed._entry["moves"]["kick"], Movesets.options("kick")[1])
	_press("★  SAVE")
	assert_false(ed._dirty)
	CawStore.reload()
	assert_eq(CawStore.entries().size(), 1)
	var e: Dictionary = CawStore.entries()[0]
	assert_eq((e["look"] as WrestlerLook).feminine, 1.0)
	assert_eq(e["moves"]["kick"], Movesets.options("kick")[1])


func test_stats_never_exceed_the_budget() -> void:
	_press("★  NEW WRESTLER")
	ed._set_tab(5)
	assert_eq(Stats.total(ed._entry["stats"]), Stats.BUDGET)
	_step("Power", 1)
	assert_eq(ed._entry["stats"]["power"], 3, "no points left")
	_step("Speed", -1)
	_step("Power", 1)
	assert_eq(ed._entry["stats"]["power"], 4)
	for i in 5:
		_step("Charisma", -1)
	assert_eq(ed._entry["stats"]["charisma"], Stats.MIN)


func test_copy_a_roster_wrestler() -> void:
	ed._copy_pick = 2
	_press("Copy")
	assert_string_contains(ed._entry["name"], "Bruno")
	assert_eq(ed._entry["moves"]["finisher"], "iron_drop")
	assert_ne(ed._look, Roster.builtin()[2]["look"], "a copy, not the roster's own look")


func test_name_entry() -> void:
	_press("★  NEW WRESTLER")
	var n: NameEntry = ed._names
	n.open("NAME", "", 18)
	for c in "rex":
		n._type(c)
	n._finish()
	assert_false(n.visible)
	n.open("NAME", "", 18)
	n._cycle(1)        # A
	n._cursor = 1
	n._cycle(2)        # B
	watch_signals(n)
	n._finish()
	assert_signal_emitted_with_parameters(n, "done", ["Ab"])


func test_unsaved_exit_asks_first_and_delete_confirms() -> void:
	_press("★  NEW WRESTLER")
	_press("Exit")
	assert_eq(ed._page, "edit", "first press only warns")
	_press("Exit without saving")
	assert_eq(ed._page, "hub")
	_press("★  NEW WRESTLER")
	_press("★  SAVE")
	ed._set_tab(0)
	_press("Delete this wrestler")
	assert_eq(CawStore.entries().size(), 1)
	_press("Really delete")
	assert_eq(CawStore.entries().size(), 0)
	assert_eq(ed._page, "hub")


func test_match_with_a_created_wrestler() -> void:
	var e := CawStore.blank()
	e["name"] = "Test Grappler"
	e["moves"]["finisher"] = "supernova"
	e["stats"] = {"power": 5, "speed": 3, "toughness": 3, "charisma": 1}
	CawStore.put(e)
	GameState.rules = "nodq"
	GameState.match_entrants = [
		{"roster": Roster.builtin().size(), "control": "cpu", "slot": 0, "difficulty": 2},
		{"roster": 0, "control": "cpu", "slot": 1, "difficulty": 2},
	]
	var m: Match = load("res://match/match.tscn").instantiate()
	add_child_autofree(m)
	await wait_physics_frames(2)
	var w := m.wrestlers[0]
	assert_eq(w.display_name, "Test Grappler")
	assert_eq(w.finisher, "supernova")
	assert_eq(w.stats["power"], 5)
	assert_eq((w.controller as CpuController).style, "powerhouse")
