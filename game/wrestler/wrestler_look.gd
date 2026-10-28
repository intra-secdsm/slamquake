class_name WrestlerLook
extends Resource
## Everything about how a wrestler looks. Used by the roster and create-a-wrestler.

@export_group("Body")
@export_range(-1.0, 1.0) var mass: float = 0.0          ## -1 slim .. +1 heavy
@export_range(0.0, 1.0) var muscle: float = 0.3
@export_range(0.0, 1.0) var gut: float = 0.0
@export_range(0.88, 1.12) var height: float = 1.0
@export var skin_color: Color = Color(0.80, 0.56, 0.42)

@export_group("Head")
@export_enum("bald", "mullet", "mohawk", "flattop", "long") var hair_style: String = "mullet"
@export var hair_color: Color = Color(0.15, 0.1, 0.06)
@export var brow_color: Color = Color(0.12, 0.08, 0.05)
@export var eye_color: Color = Color(0.25, 0.4, 0.6)

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
@export_range(0.9, 1.15) var waist: float = 1.06
@export_range(0.7, 0.95) var trunks_bottom: float = 0.86
@export_range(0.25, 0.5) var boot_top: float = 0.40
@export var shirt: bool = false
@export var shirt_color: Color = Color(0.95, 0.95, 0.95)
@export var stripe_color: Color = Color(0.05, 0.05, 0.05)
@export_range(0, 24) var stripes: int = 0
