extends Node
## Global session state: the match being set up from the menus.

const DIFFICULTIES := ["Dummy", "Easy", "Normal", "Hard", "Legend"]
const RULES := {"normal": "Normal (count-out, DQ)", "nodq": "No DQ (anything goes)"}

var rules := "normal"

## One entry per wrestler in the match.
## { "roster": int (index into Roster.all()), "control": "human"|"cpu", "slot": int (pad/keys),
##   "difficulty": int }
var match_entrants: Array[Dictionary] = [
	{"roster": 0, "control": "human", "slot": 0, "difficulty": 2},
	{"roster": 2, "control": "cpu", "slot": 1, "difficulty": 2},
]

## Career mode: the career being played (null in exhibition matches), tonight's card
## (Career.card()) while its match is on, and the result waiting to be recorded
## ("win", "loss", "draw"; "" = none).
var career: Career = null
var career_card := {}
var career_result := ""
## Championship belts worn to the ring: roster id -> 1 (World title) or 2 (tag titles).
var belts := {}


## Back to plain exhibition matches.
func end_career_match() -> void:
	career_card = {}
	belts = {}
