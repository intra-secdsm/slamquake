extends GutTest
## Career mode: starting, the monthly schedule, results, titles, rivalries, unlocks and saves.
## (Save paths are test files, set up by tests/pre_run.gd.)

var c: Career


func before_each() -> void:
	Career.erase_save()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Unlocks.path))
	Unlocks.reload()
	c = Career.start("thunder_mack", 2, 1234)


func after_all() -> void:
	Career.erase_save()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Unlocks.path))
	Unlocks.reload()


func test_never_touches_the_real_saves() -> void:
	assert_ne(Career.path, "user://career.json")
	assert_ne(Unlocks.path, "user://unlocks.json")
	assert_ne(CawStore.path, "user://created_wrestlers.json")


func test_a_new_career() -> void:
	assert_eq(c.roster.size(), 7)
	assert_false("thunder_mack" in c.roster)
	assert_eq(c.points["thunder_mack"], 0, "a rookie starts at the bottom")
	assert_eq(c.rank_of("thunder_mack"), c.ranking().size())
	assert_ne(c.champion, c.partner)
	assert_ne(c.partner, "")
	assert_eq(c.teams.size(), 3)
	for t in c.teams:
		assert_false(c.partner in t)
	assert_true(c.tag_champs in c.teams)
	assert_ne(c.rival, c.partner)
	assert_ne(c.rival, c.contender)
	assert_eq(c.date_text(), "JANUARY 1996  ·  WEEK 1")
	assert_eq(c.event_name(), Career.SHOW)


func test_the_monthly_schedule() -> void:
	var kinds := []
	for i in 4:
		var card := c.card()
		kinds.append(card["kind"])
		assert_false(card["opponents"].is_empty())
		assert_false(c.you in card["opponents"])
		assert_false(c.partner in card["opponents"])
		var ents := c.entrants()
		assert_eq(ents.size(), 4 if card["kind"] == "tag" else 2)
		assert_eq(ents[0]["control"], "human")
		for e in ents:
			assert_gt(e["roster"], -1)
		c.record("win")
	assert_eq(kinds, ["singles", "tag", "singles", "grudge"])
	assert_eq(c.week, 4)
	assert_eq(c.history.size(), 4)


func test_the_first_shows_have_their_story() -> void:
	var b := c.beats()
	assert_eq(b.size(), 2, "debut, then the month's rivalry")
	assert_string_contains(b[0]["lines"][0][1], "Thunder Mack")
	for beat in b:
		for line in beat["lines"]:
			assert_false(String(line[1]).contains("{"), "every placeholder filled: " + line[1])
	c.record("win")
	assert_eq(c.beats()[0]["cast"]["partner"], c.partner, "week 2 introduces your partner")


func test_winning_climbs_the_rankings_to_a_title_shot() -> void:
	var months := 0
	while c.you != c.contender and months < 8:
		for i in 4:
			c.record("win")
		months += 1
	assert_eq(c.contender, c.you, "number one contender within %d months" % months)
	assert_eq(c.rival, c.champion)
	c.week += 3     # skip to the PPV
	var card := c.card()
	assert_eq(card["kind"], "title")
	assert_eq(card["title"], "world")
	assert_eq(card["opponents"], [c.champion])
	assert_eq(card["difficulty"], 3, "title matches are a step harder")
	var report := c.record("win")
	assert_eq(c.champion, "thunder_mack")
	assert_true(Unlocks.has("mister_midnight"))
	assert_true("Hidden wrestler: Mister Midnight" in report["unlocked"])
	assert_eq(c.belts()["thunder_mack"], 1)
	# as champion: the new month's challenger is the top contender
	assert_eq(c.story, "title_defence")
	assert_eq(c.rival, c.contender)


func test_losing_the_title() -> void:
	c.champion = c.you
	c._start_month()
	c.week += 3
	var challenger := c.contender
	c.record("loss")
	assert_eq(c.champion, challenger)


func test_tag_titles_after_two_tag_wins() -> void:
	for month in 3:
		c.week = month * 4 + 1
		var card := c.card()
		if month < 2:
			assert_eq(card["kind"], "tag")
		else:
			assert_eq(card["kind"], "tag_title")
			assert_eq(card["opponents"], c.tag_champs)
		var report := c.record("win")
		if month == 2:
			assert_eq(c.tag_champs, [c.you, c.partner])
			assert_true(Unlocks.has("roxy_ravage"))
			assert_false(report["beats"].is_empty())
	c.week = 13
	assert_eq(c.card()["kind"], "tag_title", "defending the tag titles")


func test_grudge_match_is_no_dq_and_ppv_win_unlocks_champion_pyro() -> void:
	c.week = 3
	var card := c.card()
	assert_eq(card["kind"], "grudge")
	assert_eq(card["rules"], "nodq")
	assert_eq(card["opponents"], [c.rival])
	assert_false("champion" in Roster.pyro_styles())
	c.record("win")
	assert_true("champion" in Roster.pyro_styles())


func test_draws_change_nothing() -> void:
	var before: Dictionary = c.points.duplicate()
	var opp: String = c.card()["opponents"][0]
	c.record("draw")
	assert_eq(c.points[c.you], before[c.you])
	assert_eq(c.points[opp], before[opp])


func test_save_and_load() -> void:
	c.record("win")
	c.record("loss")
	var d := Career.load_saved()
	assert_not_null(d)
	assert_eq(d.week, 2)
	assert_eq(d.points, c.points)
	assert_eq(d.champion, c.champion)
	assert_eq(d.teams, c.teams)
	assert_eq(d.card(), c.card(), "the same card after loading")
	assert_true(d.playable())
	Career.erase_save()
	assert_null(Career.load_saved())


func test_hidden_wrestlers_are_unlocked_for_play() -> void:
	var n := Roster.all().size()
	assert_eq(Roster.find("roxy_ravage"), -1)
	Unlocks.unlock("roxy_ravage")
	assert_eq(Roster.all().size(), n + 1)
	assert_eq(Roster.find("roxy_ravage"), Roster.builtin().size())
	var d := Career.start("roxy_ravage", 2, 99)
	assert_eq(d.roster.size(), 8, "the other eight")


func _career_match(card_week: int) -> Match:
	c.week = card_week
	var card := c.card()
	GameState.career = c
	GameState.career_card = card
	GameState.match_entrants = c.entrants()
	GameState.rules = card["rules"]
	GameState.belts = c.belts()
	var m: Match = load("res://match/match.tscn").instantiate()
	add_child_autofree(m)
	return m


func after_each() -> void:
	GameState.career = null
	GameState.career_result = ""
	GameState.end_career_match()


func test_champions_wear_belts_to_the_ring_and_titles_change_hands() -> void:
	c.champion = c.you
	c._start_month()
	var entrances := Settings.entrances
	Settings.entrances = true       # headless runs skip entrances, and the bell, straight away
	var m := _career_match(3)
	Settings.entrances = entrances
	await wait_physics_frames(2)
	var me := m.wrestlers[0]
	var belt := func(w: Wrestler) -> int: return w.model._body_mat.get_shader_parameter("belt")
	assert_eq(belt.call(me), 1, "the champion's belt, before the bell")
	m._begin_fight()
	assert_eq(belt.call(me), 0, "handed over at the bell")
	assert_eq(m._title_result(m.wrestlers[1]), "AND NEW WORLD CHAMPION")
	assert_eq(belt.call(m.wrestlers[1]), 1)


func test_a_tag_match_with_your_partner() -> void:
	var m := _career_match(1)
	await wait_physics_frames(2)
	assert_true(m.tag_mode)
	assert_eq(m.wrestlers[0].display_name, c.name_of(c.you))
	assert_true(m.wrestlers[0].controller is PlayerController)
	assert_eq(m.wrestlers[0].teammate.display_name, c.name_of(c.partner))


func test_the_result_goes_back_to_the_career() -> void:
	var m := _career_match(0)
	await wait_physics_frames(2)
	m.winner = m.wrestlers[0]
	m.wrestlers[0].state = Wrestler.State.CELEBRATE
	assert_eq(m.career_result(), "win")
	m.wrestlers[0].state = Wrestler.State.IDLE
	assert_eq(m.career_result(), "draw")
	m.winner = m.wrestlers[1]
	m.wrestlers[1].state = Wrestler.State.CELEBRATE
	assert_eq(m.career_result(), "loss")
	# the career screen records it when it opens
	GameState.career_result = "loss"
	var screen: Node = load("res://ui/career.tscn").instantiate()
	add_child_autofree(screen)
	await wait_frames(2)
	assert_eq(c.week, 1, "a week has passed")
	assert_eq(c.losses[c.you], 1)
	assert_eq(screen._page, "results")
	assert_eq(GameState.career_result, "", "recorded once")
	screen._on_row_pressed(0)       # Continue
	assert_true(screen._page in ["hub", "story"])


func test_a_career_as_a_created_wrestler() -> void:
	var e := CawStore.blank()
	e["name"] = "Rookie Rex"
	CawStore.put(e)
	var d := Career.start(e["id"], 2, 5)
	assert_eq(d.roster.size(), 8, "all eight built-in wrestlers to face")
	assert_eq(d.entrants()[0]["roster"], Roster.find(e["id"]))
	d.save()
	CawStore.remove(e["id"])
	assert_false(Career.load_saved().playable(), "the career can't go on without its wrestler")
