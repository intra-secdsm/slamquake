extends Node
## Global session state: the match being set up from the menus.

const DIFFICULTIES := ["Dummy", "Easy", "Normal", "Hard"]

## One entry per wrestler in the match.
## { "roster": int (index into Roster.all()), "control": "human"|"cpu", "slot": int (pad/keys),
##   "difficulty": int }
var match_entrants: Array[Dictionary] = [
	{"roster": 0, "control": "human", "slot": 0, "difficulty": 2},
	{"roster": 2, "control": "cpu", "slot": 1, "difficulty": 2},
]
