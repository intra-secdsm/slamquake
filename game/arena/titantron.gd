class_name Titantron
extends SubViewport
## The big screen over the entrance stage: an animated neon backdrop with a caption,
## rendered offscreen and shown on the arena's "titantron_screen" mesh.

var _bg: ColorRect
var _label: Label
var _sub: Label
var _mat := ShaderMaterial.new()


func _init() -> void:
	size = Vector2i(640, 360)
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	disable_3d = true


func _ready() -> void:
	_mat.shader = preload("res://arena/titantron.gdshader")
	_bg = ColorRect.new()
	_bg.size = Vector2(size)
	_bg.material = _mat
	add_child(_bg)
	_label = _caption(64, 110)
	_sub = _caption(28, 200)
	show_text("WRESTLE", "LIVE TONIGHT")


func _caption(font_size: int, y: float) -> Label:
	var l := Label.new()
	l.position = Vector2(0, y)
	l.size = Vector2(size.x, font_size * 1.4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color("ff2bd6"))
	l.add_theme_constant_override("outline_size", 10)
	add_child(l)
	return l


func show_text(title: String, subtitle: String = "", color: Color = Color("ff2bd6"),
		color2: Color = Color("00e5ff")) -> void:
	_label.text = title
	_sub.text = subtitle
	_mat.set_shader_parameter("tint", color)
	_mat.set_shader_parameter("tint2", color2)
	_label.add_theme_color_override("font_outline_color", color)


## Material for the screen mesh: the live picture, glowing.
func screen_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = get_texture()
	m.albedo_color = Color(1.6, 1.6, 1.6)
	return m
