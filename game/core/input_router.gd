extends Node
## Creates per-player input actions ("p1_punch", ...) for up to 4 local players.
## Player N always gets gamepad N-1; players 1 and 2 also get a keyboard layout.

const SLOTS := 4
const DEADZONE := 0.25

const PAD := {
	"punch": JOY_BUTTON_X,
	"kick": JOY_BUTTON_Y,
	"grapple": JOY_BUTTON_A,
	"run": JOY_BUTTON_B,
	"block": JOY_BUTTON_RIGHT_SHOULDER,
	"taunt": JOY_BUTTON_LEFT_SHOULDER,
	"pause": JOY_BUTTON_START,
}

const KEYS := [
	{"up": KEY_W, "down": KEY_S, "left": KEY_A, "right": KEY_D, "punch": KEY_J, "kick": KEY_I,
	 "grapple": KEY_K, "run": KEY_L, "block": KEY_SPACE, "taunt": KEY_U, "pause": KEY_ESCAPE},
	{"up": KEY_UP, "down": KEY_DOWN, "left": KEY_LEFT, "right": KEY_RIGHT, "punch": KEY_KP_1,
	 "kick": KEY_KP_5, "grapple": KEY_KP_2, "run": KEY_KP_3, "block": KEY_KP_0, "taunt": KEY_KP_4,
	 "pause": KEY_KP_ENTER},
]

const ACTIONS := ["up", "down", "left", "right", "punch", "kick", "grapple", "run", "block", "taunt", "pause"]


func _ready() -> void:
	for slot in SLOTS:
		for a in ACTIONS:
			var action := action_name(slot, a)
			if InputMap.has_action(action):
				InputMap.erase_action(action)
			InputMap.add_action(action, DEADZONE)
			if slot < KEYS.size() and KEYS[slot].has(a):
				var k := InputEventKey.new()
				k.physical_keycode = KEYS[slot][a]
				InputMap.action_add_event(action, k)
			if PAD.has(a):
				var b := InputEventJoypadButton.new()
				b.device = slot
				b.button_index = PAD[a]
				InputMap.action_add_event(action, b)
		_add_axis(slot, "left", JOY_AXIS_LEFT_X, -1.0, JOY_BUTTON_DPAD_LEFT)
		_add_axis(slot, "right", JOY_AXIS_LEFT_X, 1.0, JOY_BUTTON_DPAD_RIGHT)
		_add_axis(slot, "up", JOY_AXIS_LEFT_Y, -1.0, JOY_BUTTON_DPAD_UP)
		_add_axis(slot, "down", JOY_AXIS_LEFT_Y, 1.0, JOY_BUTTON_DPAD_DOWN)
	# Godot's menu actions only map the D-pad and stick by default: A confirms, B backs out
	_add_ui_button("ui_accept", JOY_BUTTON_A)
	_add_ui_button("ui_cancel", JOY_BUTTON_B)
	# shoulder buttons flip between pages/tabs (create-a-wrestler)
	_add_ui_button("ui_page_up", JOY_BUTTON_LEFT_SHOULDER)
	_add_ui_button("ui_page_down", JOY_BUTTON_RIGHT_SHOULDER)


## Any gamepad's button triggers this UI action.
func _add_ui_button(action: String, button: JoyButton) -> void:
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton and e.button_index == button:
			return
	var b := InputEventJoypadButton.new()
	b.device = -1
	b.button_index = button
	InputMap.action_add_event(action, b)


func _add_axis(slot: int, a: String, axis: JoyAxis, dir: float, dpad: JoyButton) -> void:
	var m := InputEventJoypadMotion.new()
	m.device = slot
	m.axis = axis
	m.axis_value = dir
	InputMap.action_add_event(action_name(slot, a), m)
	var b := InputEventJoypadButton.new()
	b.device = slot
	b.button_index = dpad
	InputMap.action_add_event(action_name(slot, a), b)


static func action_name(slot: int, a: String) -> StringName:
	return StringName("p%d_%s" % [slot + 1, a])


func move_vector(slot: int) -> Vector2:
	return Input.get_vector(action_name(slot, "left"), action_name(slot, "right"),
		action_name(slot, "up"), action_name(slot, "down"))


func pressed(slot: int, a: String) -> bool:
	return Input.is_action_just_pressed(action_name(slot, a))


func held(slot: int, a: String) -> bool:
	return Input.is_action_pressed(action_name(slot, a))


func any_pressed(slot: int) -> bool:
	for a in ["punch", "kick", "grapple", "run", "block", "taunt"]:
		if pressed(slot, a):
			return true
	return false


## Human-readable control summary for the HUD help overlay.
func describe(slot: int) -> String:
	var lines := ["Gamepad %d: Stick move  X punch  Y kick  A grapple  B run  RB block  LB taunt" % (slot + 1)]
	if slot == 0:
		lines.append("Keyboard: WASD move  J punch  I kick  K grapple  L run  Space block  U taunt")
	elif slot == 1:
		lines.append("Keyboard: Arrows move  Num1 punch  Num5 kick  Num2 grapple  Num3 run  Num0 block  Num4 taunt")
	return "\n".join(lines)
