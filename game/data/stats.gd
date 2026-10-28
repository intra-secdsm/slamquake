class_name Stats
## Wrestler attributes, 1-5 each with 3 as average. Roster wrestlers and created
## wrestlers spend the same budget, so a strength somewhere is paid for elsewhere.

const NAMES := ["power", "speed", "toughness", "charisma"]
const LABELS := {"power": "Power", "speed": "Speed", "toughness": "Toughness", "charisma": "Charisma"}
const HELP := {
	"power": "damage dealt",
	"speed": "moving, getting up, reversals",
	"toughness": "damage taken, kicking out",
	"charisma": "momentum from offence and taunts",
}
const MIN := 1
const MAX := 5
const BUDGET := 12


static func defaults() -> Dictionary:
	return {"power": 3, "speed": 3, "toughness": 3, "charisma": 3}


## Clamp every stat to MIN..MAX, then take points back from the highest stats
## until the total fits the budget.
static func sanitize(s: Dictionary) -> Dictionary:
	var out := {}
	for n in NAMES:
		out[n] = clampi(int(s.get(n, 3)), MIN, MAX)
	while total(out) > BUDGET:
		var top: String = NAMES[0]
		for n in NAMES:
			if out[n] > out[top]:
				top = n
		out[top] -= 1
	return out


static func total(s: Dictionary) -> int:
	var t := 0
	for n in NAMES:
		t += int(s.get(n, 3))
	return t


static func damage_dealt(s: Dictionary) -> float:
	return 1.0 + 0.04 * (int(s.get("power", 3)) - 3)


static func damage_taken(s: Dictionary) -> float:
	return 1.0 - 0.035 * (int(s.get("toughness", 3)) - 3)


static func kickout_ease(s: Dictionary) -> float:
	return 1.0 - 0.04 * (int(s.get("toughness", 3)) - 3)


static func speed(s: Dictionary) -> float:
	return 1.0 + 0.06 * (int(s.get("speed", 3)) - 3)


## How long a knockdown keeps you down (fast wrestlers bounce back up).
static func time_down(s: Dictionary) -> float:
	return 1.0 - 0.1 * (int(s.get("speed", 3)) - 3)


## Reversal timing window (players) and how often the CPU reverses: quick hands.
static func reversal(s: Dictionary) -> float:
	return 1.0 + 0.12 * (int(s.get("speed", 3)) - 3)


static func momentum(s: Dictionary) -> float:
	return 1.0 + 0.2 * (int(s.get("charisma", 3)) - 3)
