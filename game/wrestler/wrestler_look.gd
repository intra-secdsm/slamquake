class_name WrestlerLook
extends Resource
## Everything about how a wrestler looks. Used by the roster and create-a-wrestler.

@export_group("Body")
@export_range(-1.0, 1.0) var mass: float = 0.0          ## -1 slim .. +1 heavy
@export_range(0.0, 1.0) var muscle: float = 0.3
@export_range(0.0, 1.0) var gut: float = 0.0
@export_range(0.88, 1.12) var height: float = 1.0
@export_range(0.0, 1.0) var feminine: float = 0.0       ## body type: 0 masculine .. 1 feminine
@export var skin_color: Color = Color(0.80, 0.56, 0.42)

@export_group("Head")
@export_enum("bald", "mullet", "mohawk", "flattop", "long", "ponytail", "spiky", "buzz", "afro", "slick")
var hair_style: String = "mullet"
@export var hair_color: Color = Color(0.15, 0.1, 0.06)
@export_enum("none", "moustache", "goatee", "beard", "horseshoe") var facial_hair: String = "none"  ## uses hair_color
@export var brow_color: Color = Color(0.12, 0.08, 0.05)
@export var eye_color: Color = Color(0.25, 0.4, 0.6)
@export_enum("none", "warrior", "skull", "half", "stripes", "star", "cyber") var face_paint: String = "none"
@export var paint_color: Color = Color(0.95, 0.95, 0.95)
@export var paint_color2: Color = Color(0.05, 0.05, 0.05)
@export_enum("none", "classic", "wings", "half") var mask: String = "none"   ## luchador masks
@export var mask_color: Color = Color(0.1, 0.75, 0.35)
@export var mask_trim: Color = Color(1.0, 0.85, 0.1)

@export_group("Attire")
@export var trunks_color: Color = Color(0.85, 0.05, 0.35)
@export var trim_color: Color = Color(1.0, 0.85, 0.1)
@export var boots_color: Color = Color(0.08, 0.08, 0.1)
@export var pads_color: Color = Color(0.85, 0.05, 0.35)
@export var tights_color: Color = Color(0.1, 0.1, 0.12)
@export var tights: bool = false
@export var kneepads: bool = true
@export var wristbands: bool = true
@export var elbowpads: bool = false
@export var boots: bool = true                            ## false: barefoot
@export_range(0.9, 1.15) var waist: float = 1.06
@export_range(0.7, 0.95) var trunks_bottom: float = 0.86
@export_range(0.25, 0.5) var boot_top: float = 0.40
@export var singlet: bool = false                         ## one-piece: trunks colour up over the chest with straps
@export var top: bool = false                             ## sports top / crop top
@export var top_color: Color = Color(0.85, 0.05, 0.35)
@export var shirt: bool = false
@export var shirt_color: Color = Color(0.95, 0.95, 0.95)
@export var stripe_color: Color = Color(0.05, 0.05, 0.05)
@export_range(0, 24) var stripes: int = 0
@export_enum("none", "stripe", "flames", "stars", "bolt", "split") var pattern: String = "none"  ## on trunks and tights
@export var pattern_color: Color = Color(1.0, 0.85, 0.1)
@export_enum("none", "armband", "sleeve", "chest") var tattoo: String = "none"
@export var tattoo_color: Color = Color(0.08, 0.1, 0.2)


## Every exported property as plain JSON-friendly values (colours as "#rrggbb").
func to_dict() -> Dictionary:
	var out := {}
	for p in _exported():
		var v: Variant = get(p)
		out[p] = "#" + (v as Color).to_html(false) if v is Color else v
	return out


## A look from to_dict() output. Unknown keys are ignored and missing ones keep their
## defaults, so saves from older versions still load.
static func from_dict(d: Dictionary) -> WrestlerLook:
	var l := WrestlerLook.new()
	for p in l._exported():
		if not d.has(p):
			continue
		var cur: Variant = l.get(p)
		var v: Variant = d[p]
		if cur is Color:
			if v is String and Color.html_is_valid(v):
				l.set(p, Color.html(v))
		elif cur is bool:
			l.set(p, bool(v))
		elif cur is int:
			l.set(p, int(v))
		elif cur is float:
			l.set(p, float(v))
		elif cur is String and String(v) in l.choices(p):
			l.set(p, String(v))
	return l


## The allowed values of an enum property such as hair_style or mask.
func choices(property: String) -> PackedStringArray:
	for p in get_property_list():
		if p["name"] == property and p["hint"] == PROPERTY_HINT_ENUM:
			return String(p["hint_string"]).split(",")
	return PackedStringArray()


func _exported() -> Array[String]:
	var out: Array[String] = []
	for p in get_property_list():
		if p["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE and p["usage"] & PROPERTY_USAGE_STORAGE:
			out.append(p["name"])
	return out
