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
    """keys: list of (time_seconds, pose) or (time_seconds, pose, opts).

    ground: keep the lowest body point on the floor. Per-key opts override it:
    {"ground": bool, "air": metres the lowest point is lifted off the floor}.
    """

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


# (bone, position along bone, body surface radius) sampled to find what touches the floor
_CONTACTS = [("head", 0.55, 0.11), ("neck", 0.5, 0.08), ("chest", 0.75, 0.13),
             ("chest", 0.2, 0.13), ("spine", 0.3, 0.13), ("hips", 0.0, 0.16)]
for _s in rig.SIDES:
    _CONTACTS += [(f"upper_arm.{_s}", 0.0, 0.08), (f"forearm.{_s}", 0.0, 0.05),
                  (f"hand.{_s}", 0.6, 0.045), (f"thigh.{_s}", 0.5, 0.09),
                  (f"shin.{_s}", 0.0, 0.065), (f"foot.{_s}", 0.0, 0.10),
                  (f"foot.{_s}", 1.0, 0.035), (f"toe.{_s}", 1.0, 0.025)]


def _lowest_point(armature):
    """Height of the lowest body surface point above z=0 in the current pose."""
    import bpy
    bpy.context.view_layer.update()
    lowest = math.inf
    for bone, t, radius in _CONTACTS:
        pb = armature.pose.bones[bone]
        lowest = min(lowest, pb.head.lerp(pb.tail, t).z - radius)
    return lowest


def bake(armature, anim):
    import bpy
    act = bpy.data.actions.new(anim.name)
    act.use_fake_user = True
    armature.animation_data_create()
    armature.animation_data.action = act

    prev = {}
    for key in anim.keys:
        t, pose = key[0], key[1]
        opts = key[2] if len(key) > 2 else {}
        frame = round(t * anim.fps)
        apply_pose(armature, pose)
        if opts.get("ground", anim.ground):
            dz = _lowest_point(armature) - opts.get("air", 0.0)
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


def root_info(pose):
    """Root bone placement of a pose in Godot coordinates: pos (x=left, y=up, z=fwd), yaw deg."""
    root = pose.get("root", {})
    left, fwd, up = root.get("move", (0.0, 0.0, 0.0))
    return {"pos": [round(left, 4), round(up, 4), round(fwd, 4)], "yaw": root.get("turn", 0.0)}


def at(pose, fwd=0.0, left=0.0, turn=0.0):
    """Place a pose in pair space: the partner's root offset from the attacker."""
    return merge(pose, {"root": {"move": (left, fwd, 0.0), "turn": turn}})


class Paired:
    """A two-wrestler move authored in the attacker's frame.

    keys: (time, attacker_pose, defender_pose[, opts]) where defender poses include their
    root offset (see at()). opts: air_a / air_d / ground_a / ground_d.
    Produces animations "<name>_a" and "<name>_d" sharing timing and events.
    """

    def __init__(self, name, keys, events=None):
        self.name, self.keys, self.events = name, keys, events or {}

    def anims(self):
        ka, kd = [], []
        for k in self.keys:
            t, pa, pd = k[0], k[1], k[2]
            o = k[3] if len(k) > 3 else {}
            ka.append((t, pa, {"air": o.get("air_a", 0.0), "ground": o.get("ground_a", True)}))
            kd.append((t, pd, {"air": o.get("air_d", 0.0), "ground": o.get("ground_d", True)}))
        return [Anim(self.name + "_a", ka, events=self.events),
                Anim(self.name + "_d", kd, events=self.events)]

