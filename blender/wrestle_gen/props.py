"""Ringside props: a steel folding chair and a folding table with pre-broken pieces."""
import math

import bpy

from .ring import _Builder, _MATS

_MATS.update({
    "chair_metal": dict(color=(0.55, 0.57, 0.62), rough=0.3, metal=1.0),
    "chair_seat": dict(color=(0.35, 0.36, 0.4), rough=0.35, metal=1.0),
    "table_top": dict(color=(0.72, 0.58, 0.4), rough=0.7),
    "table_edge": dict(color=(0.45, 0.33, 0.2), rough=0.7),
    "table_legs": dict(color=(0.2, 0.2, 0.22), rough=0.4, metal=1.0),
})

TABLE_W, TABLE_D, TABLE_H, TOP_T = 1.8, 0.75, 0.74, 0.035


def build_chair():
    """Origin at the floor under the chair's centre; seat faces -Y (forward)."""
    b = _Builder("chair")
    seat_h = 0.46
    b.box("chair_seat", (0, 0, seat_h), (0.42, 0.4, 0.03), bevel=0.01)
    b.box("chair_seat", (0, 0.2, seat_h + 0.25), (0.42, 0.025, 0.24), bevel=0.008)
    for sx in (-1, 1):
        # front and back legs as thin tubes, back legs run up into the backrest
        b.box("chair_metal", (sx * 0.2, -0.17, seat_h / 2), (0.022, 0.022, seat_h))
        b.box("chair_metal", (sx * 0.2, 0.2, (seat_h + 0.42) / 2), (0.022, 0.022, seat_h + 0.42))
        b.box("chair_metal", (sx * 0.2, 0.02, 0.06), (0.018, 0.4, 0.018))
    b.box("chair_metal", (0, 0.2, seat_h + 0.41), (0.42, 0.022, 0.022))
    return b.finish()


def _table_top_part(b, x0, x1, y0, y1, z):
    b.box("table_top", ((x0 + x1) / 2, (y0 + y1) / 2, z), (x1 - x0 - 0.004, y1 - y0 - 0.004, TOP_T), bevel=0.004)


def build_table():
    """Intact table plus 'table_piece_N' fragments laid out in the same place."""
    objs = []
    t = _Builder("table")
    t.box("table_top", (0, 0, TABLE_H), (TABLE_W, TABLE_D, TOP_T), bevel=0.008)
    t.box("table_edge", (0, 0, TABLE_H - TOP_T), (TABLE_W - 0.04, TABLE_D - 0.04, 0.02))
    for sx in (-1, 1):
        t.box("table_legs", (sx * 0.7, 0, TABLE_H - 0.06), (0.02, TABLE_D - 0.08, 0.02))
        for sy in (-1, 1):
            t.box("table_legs", (sx * 0.7, sy * 0.3, (TABLE_H - 0.05) / 2), (0.02, 0.02, TABLE_H - 0.05))
    objs.append(t.finish())

    # fragments: the top snaps into a 3x2 grid of slightly irregular slabs, plus the leg frames
    xs = [-TABLE_W / 2, -0.28, 0.33, TABLE_W / 2]
    ys = [-TABLE_D / 2, 0.04, TABLE_D / 2]
    n = 0
    for i in range(3):
        for j in range(2):
            p = _Builder(f"table_piece_{n}")
            _table_top_part(p, xs[i], xs[i + 1], ys[j], ys[j + 1], TABLE_H)
            objs.append(p.finish())
            n += 1
    for sx in (-1, 1):
        p = _Builder(f"table_piece_{n}")
        for sy in (-1, 1):
            p.box("table_legs", (sx * 0.7, sy * 0.3, (TABLE_H - 0.05) / 2), (0.02, 0.02, TABLE_H - 0.05))
        p.box("table_legs", (sx * 0.7, 0, TABLE_H - 0.06), (0.02, TABLE_D - 0.08, 0.02))
        objs.append(p.finish())
        n += 1
    # each piece pivots around its own centre so physics spins it naturally
    for ob in objs[1:]:
        _origin_to_center(ob)
    return objs


def _origin_to_center(ob):
    me = ob.data
    if not me.vertices:
        return
    cx = sum(v.co.x for v in me.vertices) / len(me.vertices)
    cy = sum(v.co.y for v in me.vertices) / len(me.vertices)
    cz = sum(v.co.z for v in me.vertices) / len(me.vertices)
    for v in me.vertices:
        v.co.x -= cx
        v.co.y -= cy
        v.co.z -= cz
    ob.location = (cx, cy, cz)


def build_props():
    return [build_chair()] + build_table()


_ = math, bpy
