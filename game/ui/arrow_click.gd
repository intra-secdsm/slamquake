class_name ArrowClick
## "◀  value  ▶" menu rows: a mouse click left of the middle of the row's text steps back,
## right of it forward. Enter / gamepad A press the row too, and those step forward.

static var _dir := 1
static var _frame := -1


## Watch `b` for clicks so step() knows which arrow a click hit.
static func track(b: Button) -> void:
	b.gui_input.connect(func(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb and mb.button_index == MOUSE_BUTTON_LEFT:
			ArrowClick._dir = -1 if mb.position.x < text_middle(b) else 1
			ArrowClick._frame = Engine.get_process_frames())


## The step for the row press happening now: the clicked arrow's direction, or 1.
static func step() -> int:
	return _dir if _frame == Engine.get_process_frames() else 1


## Where the middle of the button's text is, across the button (it may be left-aligned).
static func text_middle(b: Button) -> float:
	var width := b.get_theme_font("font").get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		b.get_theme_font_size("font_size")).x
	var pad := b.get_theme_stylebox("normal").get_margin(SIDE_LEFT)
	match b.alignment:
		HORIZONTAL_ALIGNMENT_LEFT:
			return pad + width / 2.0
		HORIZONTAL_ALIGNMENT_RIGHT:
			return b.size.x - b.get_theme_stylebox("normal").get_margin(SIDE_RIGHT) - width / 2.0
	return b.size.x / 2.0
