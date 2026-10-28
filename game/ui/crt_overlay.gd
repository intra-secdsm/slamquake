class_name CrtOverlay
extends CanvasLayer
## Full-screen CRT filter (menus). Toggle with Settings.crt.

func _ready() -> void:
	layer = 100
	var fx := ColorRect.new()
	fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://fx/crt.gdshader")
	fx.material = mat
	add_child(fx)
	visible = Settings.crt
