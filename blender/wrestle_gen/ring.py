"""Ring and ringside geometry: canvas, apron, posts, turnbuckle pads, steps, floor mats,
barricade and arena floor. Ropes are dynamic and built in Godot (game/ring/ring_ropes.gd).
"""
import json
import math

import bmesh
import bpy
from mathutils import Matrix, Vector

from .util import ROOT


def load_spec():
    with open(ROOT / "game/data/ring_spec.json") as f:
        return json.load(f)


_MATS = {
    "canvas":      dict(color=(0.62, 0.62, 0.61), rough=0.9),
    "apron":       dict(color=(0.05, 0.05, 0.07), rough=0.7),
    "apron_trim":  dict(color=(0.9, 0.1, 0.55), rough=0.5),
    "post":        dict(color=(0.75, 0.76, 0.8), rough=0.25, metal=1.0),
    "pad":         dict(color=(0.75, 0.05, 0.45), rough=0.45),
    "steps":       dict(color=(0.55, 0.56, 0.6), rough=0.35, metal=1.0),
    "floor_mat":   dict(color=(0.08, 0.12, 0.35), rough=0.8),
    "barricade":   dict(color=(0.04, 0.04, 0.05), rough=0.6),
    "barricade_pad": dict(color=(0.1, 0.55, 0.85), rough=0.5),
    "arena_floor": dict(color=(0.035, 0.035, 0.04), rough=0.9),
}


def _mat(name):
    mat = bpy.data.materials.get(name)
    if mat:
        return mat
    spec = _MATS[name]
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*spec["color"], 1)
    bsdf.inputs["Roughness"].default_value = spec["rough"]
    bsdf.inputs["Metallic"].default_value = spec.get("metal", 0.0)
    return mat


class _Builder:
    """Accumulates boxes/cylinders per material into one mesh object."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.mats = []

    def _mat_index(self, mat):
        if mat not in self.mats:
            self.mats.append(mat)
        return self.mats.index(mat)

    def _tag(self, geom, mat, bevel=0.0):
        faces = [g for g in geom if isinstance(g, bmesh.types.BMFace)]
        idx = self._mat_index(mat)
        for f in faces:
            f.material_index = idx
        if bevel > 0:
            edges = list(dict.fromkeys(e for f in faces for e in f.edges))
            bmesh.ops.bevel(self.bm, geom=edges, offset=bevel, segments=3, affect="EDGES",
                            profile=0.5)

    def box(self, mat, center, size, rot_z=0.0, bevel=0.0):
        m = (Matrix.Translation(center) @ Matrix.Rotation(rot_z, 4, "Z")
             @ Matrix.Diagonal((*size, 1)))
        res = bmesh.ops.create_cube(self.bm, size=1.0, matrix=m)
        geom = list(dict.fromkeys(f for v in res["verts"] for f in v.link_faces))
        self._tag(geom, mat, bevel)

    def cylinder(self, mat, base, height, radius, segments=20):
        m = Matrix.Translation(Vector(base) + Vector((0, 0, height / 2)))
        res = bmesh.ops.create_cone(self.bm, cap_ends=True, segments=segments, radius1=radius,
                                    radius2=radius, depth=height, matrix=m)
        geom = list(dict.fromkeys(f for v in res["verts"] for f in v.link_faces))
        self._tag(geom, mat)

    def finish(self, smooth_angle=math.radians(35)):
        me = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(me)
        self.bm.free()
        for m in self.mats:
            me.materials.append(_mat(m))
        ob = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(ob)
        for p in me.polygons:
            p.use_smooth = True
        me.set_sharp_from_angle(angle=smooth_angle)
        return ob


def build_ring():
    s = load_spec()
    ph, ch, mh = s["post_half"], s["canvas_half"], s["mat_height"]
    ct = s["canvas_thickness"]
    objs = []

    ring = _Builder("ring")
    ring.box("canvas", (0, 0, mh - ct / 2), (2 * ch, 2 * ch, ct), bevel=0.035)
    ring.box("apron", (0, 0, (mh - ct) / 2), (2 * ch - 0.04, 2 * ch - 0.04, mh - ct))
    ring.box("apron_trim", (0, 0, mh - ct - 0.04), (2 * ch - 0.03, 2 * ch - 0.03, 0.06))
    for sx in (-1, 1):
        for sy in (-1, 1):
            ring.cylinder("post", (sx * ph, sy * ph, 0), mh + s["post_top"], s["post_radius"])
            # pads face the ring centre along the diagonal
            inward = Vector((-sx, -sy, 0)).normalized()
            rot = math.atan2(inward.y, inward.x) + math.pi / 2
            for h in s["rope_heights"]:
                c = Vector((sx * ph, sy * ph, mh + h)) + inward * s["pad_inset"]
                ring.box("pad", c, s["pad_size"], rot_z=rot, bevel=0.03)
    objs.append(ring.finish())

    # steel steps on two opposite corners, along the +x/-x sides
    steps = _Builder("steps")
    sw = s["steps_width"]
    for sx in (-1, 1):
        for i in range(3):
            h = mh * (i + 1) / 3
            depth = 0.36 * (3 - i)
            x = sx * (ch + depth / 2)
            y = -sx * (ph - 0.75)
            steps.box("steps", (x, y, h / 2), (depth, sw, h), bevel=0.015)
    objs.append(steps.finish())

    floor = _Builder("ringside")
    fw = s["floor_mat_width"]
    outer = ch + fw
    for sx, sy, w, d in ((0, 1, 2 * outer, fw), (0, -1, 2 * outer, fw),
                         (1, 0, fw, 2 * ch), (-1, 0, fw, 2 * ch)):
        cx = sx * (ch + fw / 2)
        cy = sy * (ch + fw / 2)
        floor.box("floor_mat", (cx, cy, 0.015), (w, d, 0.03), bevel=0.01)
    floor.box("arena_floor", (0, 0, -0.05), (60, 60, 0.1))

    # barricade around ringside with an entrance aisle gap on the +y (back) side
    bh, bhalf, aisle = s["barricade_height"], s["barricade_half"], s["aisle_width"]
    t = 0.1
    for sx in (-1, 1):
        floor.box("barricade", (sx * bhalf, 0, bh / 2), (t, 2 * bhalf, bh))
        floor.box("barricade_pad", (sx * bhalf, 0, bh + 0.04), (t + 0.06, 2 * bhalf, 0.08), bevel=0.02)
    floor.box("barricade", (0, -bhalf, bh / 2), (2 * bhalf, t, bh))
    floor.box("barricade_pad", (0, -bhalf, bh + 0.04), (2 * bhalf, t + 0.06, 0.08), bevel=0.02)
    seg = bhalf - aisle / 2
    for sx in (-1, 1):
        cx = sx * (aisle / 2 + seg / 2)
        floor.box("barricade", (cx, bhalf, bh / 2), (seg, t, bh))
        floor.box("barricade_pad", (cx, bhalf, bh + 0.04), (seg, t + 0.06, 0.08), bevel=0.02)
    objs.append(floor.finish())
    return objs
