"""Shared humanoid rig used by every wrestler (and the referee).

Coordinates are Blender armature space: +X = character's left, -Y = forward, +Z = up,
metres, feet on z=0. The glTF exporter converts to Godot's Y-up (character faces +Z).

Rest pose is an A-pose (arms ~40 degrees below horizontal), which skins shoulders better
than a T-pose for a game where arms are mostly down.
"""
from mathutils import Vector

# name: (head, tail, parent, deform)
_CENTER = {
    "root":  ((0, 0, 0),         (0, 0.25, 0),     None,    False),
    "hips":  ((0, 0, 1.00),      (0, 0, 1.12),     "root",  True),
    "spine": ((0, 0, 1.12),      (0, 0, 1.30),     "hips",  True),
    "chest": ((0, 0, 1.30),      (0, 0, 1.52),     "spine", True),
    "neck":  ((0, 0.01, 1.55),   (0, 0, 1.66),     "chest", True),
    "head":  ((0, 0, 1.66),      (0, 0, 1.90),     "neck",  True),
}

# Left side; right side is mirrored in X.
_LEFT = {
    "clavicle":  ((0.03, 0.0, 1.50),      (0.19, 0.03, 1.53),      "chest"),
    "upper_arm": ((0.21, 0.03, 1.52),     (0.447, 0.03, 1.321),    "clavicle"),
    "forearm":   ((0.447, 0.03, 1.321),   (0.660, 0.002, 1.142),   "upper_arm"),
    "hand":      ((0.660, 0.002, 1.142),  (0.736, -0.008, 1.078),  "forearm"),
    "fingers":   ((0.736, -0.008, 1.078), (0.805, -0.017, 1.020),  "hand"),
    "thumb":     ((0.675, -0.03, 1.115),  (0.715, -0.07, 1.090),   "hand"),
    "thigh":     ((0.11, 0.0, 0.98),      (0.13, -0.01, 0.54),     "hips"),
    "shin":      ((0.13, -0.01, 0.54),    (0.14, 0.02, 0.10),      "thigh"),
    "foot":      ((0.14, 0.02, 0.10),     (0.145, -0.11, 0.035),   "shin"),
    "toe":       ((0.145, -0.11, 0.035),  (0.15, -0.19, 0.025),    "foot"),
}

SIDES = ("L", "R")


def _mirror(v):
    return (-v[0], v[1], v[2])


def _build_table():
    bones = {}
    for name, (h, t, parent, deform) in _CENTER.items():
        bones[name] = (Vector(h), Vector(t), parent, deform)
    for side in SIDES:
        for base, (h, t, parent) in _LEFT.items():
            if side == "R":
                h, t = _mirror(h), _mirror(t)
            p = parent if parent in _CENTER else f"{parent}.{side}"
            bones[f"{base}.{side}"] = (Vector(h), Vector(t), p, True)
    return bones


BONES = _build_table()
DEFORM_BONES = [n for n, b in BONES.items() if b[3]]


def head(name):
    return BONES[name][0].copy()


def tail(name):
    return BONES[name][1].copy()


def lerp(name, t):
    """Point at fraction t along a bone in rest pose."""
    h, tl = BONES[name][0], BONES[name][1]
    return h.lerp(tl, t)


def side_sign(side):
    return 1.0 if side == "L" else -1.0


def build_armature(name="Armature"):
    import bpy

    arm = bpy.data.armatures.new(name)
    ob = bpy.data.objects.new(name, arm)
    bpy.context.scene.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    for bname, (h, t, parent, deform) in BONES.items():
        eb = arm.edit_bones.new(bname)
        eb.head, eb.tail = h, t
        eb.roll = 0.0
        eb.use_deform = deform
    for bname, (_, _, parent, _) in BONES.items():
        if parent:
            arm.edit_bones[bname].parent = arm.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in ob.pose.bones:
        pb.rotation_mode = "QUATERNION"
    return ob
