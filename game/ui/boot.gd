extends Control
## Placeholder boot screen. Replaced by the real front end in M7.

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("120018")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := Label.new()
	title.text = "WRESTLE\n(working title)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.add_theme_font_size_override("font_size", 96)
	title.add_theme_color_override("font_color", Color("ff2bd6"))
	title.add_theme_color_override("font_outline_color", Color("00e5ff"))
	title.add_theme_constant_override("outline_size", 12)
	add_child(title)
