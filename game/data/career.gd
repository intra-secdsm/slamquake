class_name Career
extends RefCounted
## A career: your wrestler's weeks in the promotion, saved as JSON (one career at a time).
##
## Each month has three TV shows and then a pay-per-view (PPV):
##   week 1  ranking match                 (the month's rivalry starts)
##   week 2  tag match with your partner   (two wins earn a shot at the tag titles)
##   week 3  ranking match                 (the rivalry builds)
##   PPV     World title match if you're the champion or the number one contender,
##           otherwise a no-DQ grudge match with your rival
## Wins earn ranking points and losses cost one. Whoever is top of the rankings when a
## month starts challenges the champion at its PPV. Everyone else's matches are
## simulated, so the rankings and titles move without you.

const VERSION := 1
const SHOW := "SATURDAY SLAMTIME"
const PPVS := ["NEON NIGHTMARE", "STEEL SUNRISE", "RAMP RIOT", "CHROME CROWN", "MIDNIGHT MAYHEM", "THE BIG BLOWOUT"]
const MONTHS := ["JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE", "JULY", "AUGUST", "SEPTEMBER",
	"OCTOBER", "NOVEMBER", "DECEMBER"]
const FIRST_YEAR := 1996
const WEEKS := 4                    # per month; the last is the PPV
const WIN_POINTS := 3
const PPV_WIN_POINTS := 5
const TAG_WIN_POINTS := 2
const LOSS_POINTS := -1
const TAG_WINS_FOR_SHOT := 2
const DEFENCES_FOR_HALL_OF_FAME := 3
const SIM_MATCHES := 3              # other matches on each show
const SIM_WIN_POINTS := 2           # simulated wins count for less, so you can climb past them

## Tests point this somewhere else (kept in ProjectSettings, like CawStore.path).
static var path: String:
	get:
		return ProjectSettings.get_setting("wrestle/career_save_path", "user://career.json")
	set(value):
		ProjectSettings.set_setting("wrestle/career_save_path", value)

var you := ""                       # roster id of your wrestler
var difficulty := 2                 # CPU difficulty (GameState.DIFFICULTIES)
var rng_seed := 0
var week := 0                       # weeks since the career started
var roster: Array = []              # everyone else in the promotion (ids)
var points := {}                    # id -> ranking points (you included)
var wins := {}
var losses := {}
var champion := ""                  # World champion
var tag_champs: Array = []          # two ids
var partner := ""
var teams: Array = []               # other tag teams, [[id, id], ...]
var tag_wins := 0                   # your team's wins toward a tag title shot
var contender := ""                 # this month's World title challenger
var rival := ""                     # this month's rival (the title opponent in a title month)
var story := ""                     # this month's Stories template
var defences := 0                   # successful World title defences, this reign
var reigns := {"world": 0, "tag": 0}
var history: Array = []             # one line per show: [event, text]


# ---------------------------------------------------------------- start, save, load

## A new career for the wrestler with this roster id.
static func start(you_id: String, level: int, seed_value: int = 0) -> Career:
	var c := Career.new()
	c.you = you_id
	c.difficulty = clampi(level, 1, GameState.DIFFICULTIES.size() - 1)
	c.rng_seed = seed_value if seed_value != 0 else randi()
	var rng := c._rng(-1)
	for e in Roster.all():
		if e["id"] != you_id and not e.get("caw", false):
			c.roster.append(e["id"])
	_shuffle(c.roster, rng)
	for id in c.roster:
		c.points[id] = rng.randi_range(3, 12)
	c.points[you_id] = 0
	for id in c.roster + [you_id]:
		c.wins[id] = 0
		c.losses[id] = 0
	c.champion = c.roster[0]
	# a partner whose style differs from yours if possible, never the champion
	var my_style := CpuController.style_for(c.entry(you_id))
	c.partner = c.roster[1]
	for id in c.roster.slice(1):
		if CpuController.style_for(c.entry(id)) != my_style:
			c.partner = id
			break
	var free: Array = c.roster.filter(func(id: String) -> bool: return id != c.partner)
	for i in range(0, free.size() - 1, 2):
		c.teams.append([free[i], free[i + 1]])
	c.tag_champs = c.teams[0].duplicate()
	c._start_month()
	return c


static func has_save() -> bool:
	return FileAccess.file_exists(path)


## The saved career, or null if there isn't one (or it can't be played any more).
static func load_saved() -> Career:
	if not has_save():
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		push_warning("Career: %s is not valid JSON; ignoring it" % path)
		return null
	var c := Career.new()
	var d: Dictionary = json.data
	for key in _saved_keys():
		if d.has(key):
			var v: Variant = d[key]
			c.set(key, int(v) if c.get(key) is int else v)
	for dict in [c.points, c.wins, c.losses, c.reigns]:
		for id in dict:
			dict[id] = int(dict[id])
	return c


static func erase_save() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func save() -> bool:
	var d := {"version": VERSION}
	for key in _saved_keys():
		d[key] = get(key)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("Career: can't write %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(JSON.stringify(d, "\t"))
	return true


static func _saved_keys() -> Array[String]:
	return ["you", "difficulty", "rng_seed", "week", "roster", "points", "wins", "losses", "champion", "tag_champs",
		"partner", "teams", "tag_wins", "contender", "rival", "story", "defences", "reigns", "history"]


## False if your wrestler has gone (a created wrestler that was deleted).
func playable() -> bool:
	return Roster.find(you) >= 0


# ---------------------------------------------------------------- calendar

func week_in_month() -> int:
	return week % WEEKS


func is_ppv() -> bool:
	return week_in_month() == WEEKS - 1


## Tonight's show: the weekly TV show or the month's PPV.
func event_name() -> String:
	return PPVS[(week / WEEKS) % PPVS.size()] if is_ppv() else SHOW


func ppv_name() -> String:
	return PPVS[(week / WEEKS) % PPVS.size()]


## e.g. "MARCH 1996 · WEEK 2"
func date_text() -> String:
	var month := week / WEEKS
	var when := "%s %d" % [MONTHS[month % 12], FIRST_YEAR + month / 12]
	return when + ("  ·  PAY-PER-VIEW" if is_ppv() else "  ·  WEEK %d" % (week_in_month() + 1))


# ---------------------------------------------------------------- people

func entry(id: String) -> Dictionary:
	var i := Roster.find(id)
	return Roster.get_entry(i) if i >= 0 else {}


func name_of(id: String) -> String:
	return String(entry(id).get("name", "?"))


func team_name(ids: Array) -> String:
	return " & ".join(ids.map(func(id: String) -> String: return name_of(id)))


## Singles rankings, best first: everyone but the champion.
func ranking() -> Array:
	var out: Array = (roster + [you]).filter(func(id: String) -> bool: return id != champion)
	out.sort_custom(func(a: String, b: String) -> bool:
		if points[a] != points[b]:
			return points[a] > points[b]
		if wins[a] != wins[b]:
			return wins[a] > wins[b]
		return a < b)
	return out


## 1 = top of the rankings; 0 = the champion.
func rank_of(id: String) -> int:
	return 0 if id == champion else ranking().find(id) + 1


## Belts to wear to the ring: roster id -> 1 (World title) or 2 (tag titles).
func belts() -> Dictionary:
	var out := {}
	for id in tag_champs:
		out[id] = 2
	out[champion] = 1
	return out


# ---------------------------------------------------------------- this week

## Your match tonight:
##   {kind: "singles"|"tag"|"tag_title"|"title"|"grudge", label, opponents: [ids],
##    partner: id or "", rules: "normal"|"nodq", title: ""|"world"|"tag", difficulty}
func card() -> Dictionary:
	var c := {"kind": "singles", "label": "RANKING MATCH", "opponents": [], "partner": "", "rules": "normal",
		"title": "", "difficulty": difficulty}
	match week_in_month():
		1:
			c["partner"] = partner
			c["kind"] = "tag"
			c["label"] = "TAG TEAM MATCH"
			if you in tag_champs:
				c["kind"] = "tag_title"
				c["label"] = "TAG TEAM TITLE MATCH"
				c["opponents"] = _best_team()
			elif tag_wins >= TAG_WINS_FOR_SHOT:
				c["kind"] = "tag_title"
				c["label"] = "TAG TEAM TITLE MATCH"
				c["opponents"] = tag_champs.duplicate()
			else:
				var others := teams.filter(func(t: Array) -> bool: return t != tag_champs)
				c["opponents"] = (others[_rng(1).randi() % others.size()] as Array).duplicate() if others else _best_team()
		WEEKS - 1:
			if you == champion or you == contender:
				c["kind"] = "title"
				c["label"] = "WORLD HEAVYWEIGHT TITLE MATCH"
				c["opponents"] = [rival]
			else:
				c["kind"] = "grudge"
				c["label"] = "GRUDGE MATCH  ·  NO DISQUALIFICATIONS"
				c["rules"] = "nodq"
				c["opponents"] = [rival]
		_:
			c["opponents"] = [_ranking_opponent()]
	if c["kind"] in ["title", "tag_title"]:
		c["title"] = "world" if c["kind"] == "title" else "tag"
		c["difficulty"] = mini(difficulty + 1, GameState.DIFFICULTIES.size() - 1)
	return c


## The match for GameState.match_entrants: you (pad/keys 1) and the CPU, roster indices.
func entrants() -> Array[Dictionary]:
	var c := card()
	var cpu := func(id: String, team: int) -> Dictionary:
		return {"roster": Roster.find(id), "control": "cpu", "slot": 1, "difficulty": c["difficulty"], "team": team}
	var me := {"roster": Roster.find(you), "control": "human", "slot": 0, "difficulty": c["difficulty"], "team": 0}
	var opp: Array = c["opponents"]
	if c["partner"] != "":
		# tag order: A1, B1, A2, B2
		return [me, cpu.call(opp[0], 1), cpu.call(c["partner"], 0), cpu.call(opp[1], 1)]
	return [me, cpu.call(opp[0], 1)]


## Story scenes before tonight's match: [{cast: {role: id}, lines: [[role, text], ...]}].
func beats() -> Array:
	var out := []
	if week == 0:
		out.append(_beat(Stories.MOMENTS["debut"]))
	if week == 1:
		out.append(_beat(Stories.MOMENTS["partner"]))
	var phase: String = ["start", "", "build", "ppv"][week_in_month()]
	if phase != "":
		var lines: Array = _story_lines(phase)
		if lines:
			out.append(_beat(lines))
	return out


# ---------------------------------------------------------------- results

## Record tonight's result ("win", "loss" or "draw"), run the rest of the show, move on
## a week and save. Returns what happened:
##   {result, headline, results: [text...], beats: [...], unlocked: [names...]}
func record(result: String) -> Dictionary:
	var c := card()
	var rng := _rng(2)
	var report := {"result": result, "headline": "", "results": [], "beats": [], "unlocked": []}
	var opp: Array = c["opponents"]
	var us: Array = [you] + ([partner] if c["partner"] != "" else [])
	var them := team_name(opp)
	var won := result == "win"
	var lost := result == "loss"
	if won:
		report["headline"] = "%s defeated %s" % [team_name(us), them]
	elif lost:
		report["headline"] = "%s defeated %s" % [them, team_name(us)]
	else:
		report["headline"] = "%s and %s fought to a draw" % [team_name(us), them]
	var gain := PPV_WIN_POINTS if is_ppv() else TAG_WIN_POINTS if c["partner"] != "" else WIN_POINTS
	if won or lost:
		for id in us:
			_score(id, won, gain)
		for id in opp:
			_score(id, lost, gain)
	match c["kind"]:
		"title":
			if you == champion:
				if lost:
					champion = opp[0]
					defences = 0
					report["beats"].append(_beat(_story_lines("loss")))
				else:
					defences += 1
					report["beats"].append(_beat(_story_lines("win")))
					if defences >= DEFENCES_FOR_HALL_OF_FAME and _unlock("hall_of_fame", report):
						report["beats"].append(_beat(Stories.MOMENTS["hall_of_fame"]))
			elif won:
				champion = you
				defences = 0
				reigns["world"] += 1
				report["beats"].append(_beat(_story_lines("win")))
				_unlock("mister_midnight", report)
			else:
				report["beats"].append(_beat(_story_lines("loss")))
		"tag_title":
			if you in tag_champs and lost:
				tag_champs = opp.duplicate()
				tag_wins = 0
				report["beats"].append(_beat(Stories.MOMENTS["tag_lost"]))
			elif not you in tag_champs and won:
				tag_champs = us.duplicate()
				tag_wins = 0
				reigns["tag"] += 1
				report["beats"].append(_beat(Stories.MOMENTS["tag_won"]))
				_unlock("roxy_ravage", report)
		"tag":
			if won:
				tag_wins += 1
			elif lost:
				tag_wins = maxi(0, tag_wins - 1)
		"grudge":
			if won or lost:
				report["beats"].append(_beat(_story_lines("win" if won else "loss")))
	if is_ppv() and won:
		_unlock("pyro_champion", report)
	report["results"] = _simulate(rng, us + opp)
	history.append([event_name(), report["headline"]])
	week += 1
	if week_in_month() == 0:
		_start_month()
	save()
	return report


func _score(id: String, won: bool, gain: int) -> void:
	if won:
		wins[id] += 1
		points[id] += gain
	else:
		losses[id] += 1
		points[id] = maxi(0, points[id] + LOSS_POINTS)


func _unlock(id: String, report: Dictionary) -> bool:
	if Unlocks.unlock(id):
		report["unlocked"].append(Unlocks.ITEMS[id]["name"])
		return true
	return false


## The rest of the card: at a PPV the World title match (unless it was yours), then a few
## singles matches between whoever's free. Returns a line per match.
func _simulate(rng: RandomNumberGenerator, busy: Array) -> Array:
	var out := []
	if is_ppv() and not you in [champion, contender] and contender != "" and contender != champion:
		var champ_wins := rng.randf() < _odds(champion, contender)
		if champ_wins:
			_score(champion, true, PPV_WIN_POINTS)
			_score(contender, false, PPV_WIN_POINTS)
			out.append("WORLD TITLE: %s retained against %s" % [name_of(champion), name_of(contender)])
		else:
			var old := champion
			champion = contender
			_score(champion, true, PPV_WIN_POINTS)
			_score(old, false, PPV_WIN_POINTS)
			out.append("WORLD TITLE: %s defeated %s. NEW CHAMPION!" % [name_of(champion), name_of(old)])
		busy = busy + [champion, contender]
	var free: Array = roster.filter(func(id: String) -> bool: return not id in busy)
	_shuffle(free, rng)
	for i in range(0, mini(free.size() - 1, SIM_MATCHES * 2), 2):
		var a: String = free[i]
		var b: String = free[i + 1]
		if rng.randf() >= _odds(a, b):
			var t := a
			a = b
			b = t
		_score(a, true, SIM_WIN_POINTS + (1 if is_ppv() else 0))
		_score(b, false, 0)
		out.append("%s defeated %s" % [name_of(a), name_of(b)])
	return out


## Chance that a beats b: better ranked and stronger wrestlers win more often.
func _odds(a: String, b: String) -> float:
	var sa: Dictionary = entry(a).get("stats", Stats.defaults())
	var sb: Dictionary = entry(b).get("stats", Stats.defaults())
	var strength := int(sa["power"]) + int(sa["toughness"]) - int(sb["power"]) - int(sb["toughness"])
	var edge := 0.015 * (int(points[a]) - int(points[b])) + 0.04 * strength
	return clampf(0.5 + edge, 0.25, 0.75)


# ---------------------------------------------------------------- the month

## A new month: lock in the World title match and pick your rival.
func _start_month() -> void:
	var rng := _rng(3)
	var r := ranking().filter(func(id: String) -> bool: return id != partner)
	contender = r[0] if r else ""
	if you == champion:
		rival = contender
		story = "title_defence"
	elif you == contender:
		rival = champion
		story = "title_chase"
	else:
		# someone ranked near you, away from the title match and your partner
		var near := ranking().filter(func(id: String) -> bool: return not id in [you, partner, contender])
		near.sort_custom(func(a: String, b: String) -> bool:
			return absi(rank_of(a) - rank_of(you)) < absi(rank_of(b) - rank_of(you)))
		var pick: Array = near.slice(0, 3)
		rival = pick[rng.randi() % pick.size()] if pick else roster[0]
		var keys := Stories.RIVALRIES.keys()
		var last := story
		story = keys[rng.randi() % keys.size()]
		if story == last:
			story = keys[(keys.find(story) + 1) % keys.size()]
		if week == 0:
			story = "ambush"        # the others assume you've been on a roll; a newcomer gets jumped


func _story_lines(phase: String) -> Array:
	var t: Dictionary = Stories.TITLE.get(story, Stories.RIVALRIES.get(story, {}))
	return t.get(phase, [])


## A story scene with its lines filled in. cast: role -> roster id for everyone who speaks.
func _beat(lines: Array) -> Dictionary:
	var roles := {"you": you, "rival": rival, "partner": partner, "champ": champion, "contender": contender}
	var fill := {"you": name_of(you), "rival": name_of(rival), "partner": name_of(partner),
		"champ": name_of(champion), "contender": name_of(contender), "tag_champs": team_name(tag_champs),
		"ppv": ppv_name(), "show": SHOW, "you_brag": Stories.brag(you), "rival_brag": Stories.brag(rival)}
	var cast := {}
	var out := []
	for line in lines:
		var who: String = line[0]
		if who != "host":
			cast[who] = roles[who]
		out.append([who, String(line[1]).format(fill)])
	return {"cast": cast, "lines": out}


func _ranking_opponent() -> String:
	# someone just above you in the rankings (just below if you're top), not your rival
	# or partner; the second show of the month picks the next one along
	var r := ranking().filter(func(id: String) -> bool: return not id in [partner, rival] or id == you)
	if you == champion:
		r.push_front(you)
	var i := r.find(you)
	var order := []
	for k in range(1, r.size()):
		for j in [i - k, i + k]:
			if j >= 0 and j < r.size():
				order.append(r[j])
	order = order.filter(func(id: String) -> bool: return id != you)
	return order[mini(week_in_month() / 2, order.size() - 1)] if order else roster[0]


## The highest-ranked team that isn't yours or the champions'.
func _best_team() -> Array:
	var best: Array = []
	var best_pts := -1
	for t in teams:
		if t == tag_champs or you in t:
			continue
		var p: int = points[t[0]] + points[t[1]]
		if p > best_pts:
			best_pts = p
			best = t
	return best.duplicate() if best else (teams[0] as Array).duplicate()


## Repeatable randomness for this week (salt keeps different decisions independent).
func _rng(salt: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash([rng_seed, week, salt])
	return r


static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: Variant = a[i]
		a[i] = a[j]
		a[j] = t
