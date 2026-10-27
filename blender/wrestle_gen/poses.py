"""Readable pose authoring on top of the shared rig.

A pose is a dict: bone -> {semantic: degrees}. Semantics are defined in rest space so they
read like anatomy regardless of bone roll:

  torso (hips, spine, chest, neck, head): bend (forward), lean (to own left), turn (to own left)
  clavicle.*:  shrug (up), reach (forward)
  upper_arm.*: raise (up), swing (forward), twist
  forearm.*:   bend (elbow flex), twist
  hand.*:      bend (toward palm), tilt (forward)
  fingers.*, thumb.*: curl (toward palm)
  thigh.*:     raise (forward), spread (outward), twist (toes out)
  shin.*:      bend (knee flex)
  foot.*, toe.*: flex (toes up)

Translations: "hips"/"root" accept move=(left, forward, up) in metres; "root" also accepts
turn. Left/right semantics mirror, so `sym()` copies .L values onto .R.
"""
import math

from mathutils import Quaternion, Vector

from . import rig

FWD, BACK, UP, LEFT = Vector((0, -1, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)), Vector((1, 0, 0))
TORSO = ("hips", "spine", "chest", "neck", "head")


def _palm(side):
    s = rig.side_sign(side)
    return Vector((-s * 0.64, 0, -0.76)).normalized()


def _semantics():
    sem = {}
    for b in TORSO:
        sem[b] = {"bend": ("swing", FWD), "lean": ("swing", LEFT), "turn": ("twist", 1)}
    sem["root"] = {"turn": ("axis", UP)}
    for side in rig.SIDES:
        s = rig.side_sign(side)
        out = Vector((s, 0, 0))
        sem[f"clavicle.{side}"] = {"shrug": ("swing", UP), "reach": ("swing", FWD)}
        sem[f"upper_arm.{side}"] = {"raise": ("swing", UP), "swing": ("swing", FWD), "twist": ("twist", s)}
        sem[f"forearm.{side}"] = {"bend": ("swing", FWD), "twist": ("twist", s)}
        sem[f"hand.{side}"] = {"bend": ("swing", _palm(side)), "tilt": ("swing", FWD)}
        sem[f"fingers.{side}"] = {"curl": ("swing", _palm(side))}
        sem[f"thumb.{side}"] = {"curl": ("swing", _palm(side))}
        sem[f"thigh.{side}"] = {"raise": ("swing", FWD), "spread": ("swing", out), "twist": ("twist", s)}
        sem[f"shin.{side}"] = {"bend": ("swing", BACK)}
        sem[f"foot.{side}"] = {"flex": ("swing", UP)}
        sem[f"toe.{side}"] = {"flex": ("swing", UP)}
    return sem


SEMANTICS = _semantics()


def _axis(bone, kind, ref):
    d = (rig.tail(bone) - rig.head(bone)).normalized()
    if kind == "swing":
        return d.cross(ref).normalized()
    if kind == "twist":
        return d * ref
    return ref  # fixed axis


def armature_rotation(bone, values):
    """Rotation in armature rest space for a dict of semantic angles (degrees)."""
    q = Quaternion()
    # twist first, then swings in declaration order
    order = sorted(values, key=lambda k: 0 if SEMANTICS[bone][k][0] == "twist" else 1)
    for name in order:
        if name == "move":
            continue
        kind, ref = SEMANTICS[bone][name]
        q = Quaternion(_axis(bone, kind, ref), math.radians(values[name])) @ q
    return q


def move_vector(move):
    left, fwd, up = move
    return Vector((left, -fwd, up))


# ------------------------------------------------------------------ pose helpers

def sym(pose):
    """Copy every .L entry to .R (unless .R already given)."""
    out = {k: dict(v) for k, v in pose.items()}
    for k, v in pose.items():
        if k.endswith(".L"):
            out.setdefault(k[:-2] + ".R", dict(v))
    return out


def merge(*poses):
    """Later poses override/extend earlier ones per semantic."""
    out = {}
    for p in poses:
        for bone, vals in p.items():
            out.setdefault(bone, {}).update(vals)
    return out


def add(*poses):
    """Sum semantic angles (for layering breathing/sway on a base pose)."""
    out = {}
    for p in poses:
        for bone, vals in p.items():
            dst = out.setdefault(bone, {})
            for k, v in vals.items():
                if k == "move":
                    old = dst.get("move", (0, 0, 0))
                    dst["move"] = tuple(a + b for a, b in zip(old, v))
                else:
                    dst[k] = dst.get(k, 0) + v
    return out


def mirror(pose):
    """Swap left and right (for making a left-handed version of a move)."""
    out = {}
    for bone, vals in pose.items():
        if bone.endswith(".L"):
            nb = bone[:-2] + ".R"
        elif bone.endswith(".R"):
            nb = bone[:-2] + ".L"
        else:
            nb = bone
        v = dict(vals)
        for k in ("lean", "turn"):
            if k in v:
                v[k] = -v[k]
        if "move" in v:
            m = v["move"]
            v["move"] = (-m[0], m[1], m[2])
        out[nb] = v
    return out


class Anim:
    """keys: list of (time_seconds, pose). ground: keep the lowest foot on the floor."""

    def __init__(self, name, keys, loop=False, ground=True, events=None, fps=30):
        self.name, self.keys, self.loop = name, keys, loop
        self.ground, self.events, self.fps = ground, events or {}, fps

    @property
    def length(self):
        return self.keys[-1][0]


# ------------------------------------------------------------------ baking into Blender

def _rest_quat(armature, bone):
    return armature.data.bones[bone].matrix_local.to_quaternion()


def apply_pose(armature, pose):
    for pb in armature.pose.bones:
        pb.rotation_quaternion = Quaternion()
        pb.location = Vector()
    for bone, vals in pose.items():
        pb = armature.pose.bones[bone]
        r = _rest_quat(armature, bone)
        rot_vals = {k: v for k, v in vals.items() if k != "move"}
        if rot_vals:
            pb.rotation_quaternion = r.inverted() @ armature_rotation(bone, rot_vals) @ r
        if "move" in vals:
            pb.location = r.inverted() @ move_vector(vals["move"])


def _sole_height(armature):
    """Height of the lowest boot sole above z=0 in the current pose."""
    import bpy
    bpy.context.view_layer.update()
    lowest = math.inf
    for side in rig.SIDES:
        foot = armature.pose.bones[f"foot.{side}"]
        toe = armature.pose.bones[f"toe.{side}"]
        lowest = min(lowest, foot.head.z - 0.10, foot.tail.z - 0.035, toe.tail.z - 0.025)
    return lowest


def bake(armature, anim):
    import bpy
    act = bpy.data.actions.new(anim.name)
    act.use_fake_user = True
    armature.animation_data_create()
    armature.animation_data.action = act

    prev = {}
    for t, pose in anim.keys:
        frame = round(t * anim.fps)
        apply_pose(armature, pose)
        if anim.ground:
            dz = _sole_height(armature)
            hips = armature.pose.bones["hips"]
            r = _rest_quat(armature, "hips")
            hips.location = hips.location + r.inverted() @ Vector((0, 0, -dz))
        for pb in armature.pose.bones:
            q = pb.rotation_quaternion.copy()
            if pb.name in prev and prev[pb.name].dot(q) < 0:
                q.negate()
                pb.rotation_quaternion = q
            prev[pb.name] = q
            pb.keyframe_insert("rotation_quaternion", frame=frame)
            if pb.name in ("hips", "root"):
                pb.keyframe_insert("location", frame=frame)
    armature.animation_data.action = None
    return act
