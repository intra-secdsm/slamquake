"""The arena around ringside: seating tiers on all sides, the entrance stage with a
titantron screen, the ramp down to the aisle, a lighting truss over the ring and
the dark outer walls. Dimensions come from ring_spec.json ("arena").

Blender +Y is Godot -Z: the stage is at +Y here, behind the ring from the hard camera.
The crowd itself is instanced in Godot (game/arena/crowd.gd) on the same tiers.
"""
import math

from .ring import _Builder, _MATS, load_spec

_MATS.update({
    "seat_tier": dict(color=(0.07, 0.07, 0.09), rough=0.8),
    "tier_edge": dict(color=(0.12, 0.1, 0.2), rough=0.6),
    "wall": dict(color=(0.02, 0.02, 0.03), rough=0.9),
    "stage": dict(color=(0.05, 0.05, 0.06), rough=0.35, metal=0.6),
    "stage_floor": dict(color=(0.09, 0.09, 0.11), rough=0.25, metal=0.3),
    "neon_pink": dict(color=(1.0, 0.17, 0.84), rough=0.4, emit=(1.0, 0.17, 0.84), emit_strength=4.0),
    "neon_cyan": dict(color=(0.0, 0.9, 1.0), rough=0.4, emit=(0.0, 0.9, 1.0), emit_strength=4.0),
    "screen": dict(color=(0.02, 0.02, 0.02), rough=0.3),
    "truss": dict(color=(0.25, 0.25, 0.28), rough=0.35, metal=1.0),
    "lamp": dict(color=(1.0, 0.95, 0.85), rough=0.2, emit=(1.0, 0.95, 0.85), emit_strength=6.0),
    "ramp": dict(color=(0.06, 0.06, 0.08), rough=0.5, metal=0.4),
})


def _tiers(b, a):
    """Stepped seating: four sides of a square bowl, with the far side cut away for the stage."""
    inner, rows, depth, rise = a["stands_inner"], a["rows"], a["row_depth"], a["row_rise"]
    gap = a["stage_half_width"] + 0.5
    for r in range(rows):
        d = inner + r * depth
        h = (r + 1) * rise
        outer = d + depth
        for side in range(4):
            # side 0: -y (near, behind the camera), 1: +x, 2: +y (far, around the stage), 3: -x
            ang = side * math.pi / 2
            ca, sa = math.cos(ang), math.sin(ang)
            def place(cx, length):
                # tier block centred at local (cx, -(d + depth/2)) rotated about z
                lx, ly = cx, -(d + depth / 2)
                x, y = lx * ca - ly * sa, lx * sa + ly * ca
                b.box("seat_tier", (x, y, h / 2), (length, depth, h), rot_z=ang)
                ex, ey = lx * ca - (-d) * sa, lx * sa + (-d) * ca
                b.box("tier_edge", (ex, ey, h + 0.01), (length, 0.06, 0.03), rot_z=ang)
            if side == 2:
                seg = outer - gap
                for sx in (-1, 1):
                    place(sx * (gap + seg / 2), seg)
            else:
                place(0.0, 2 * outer)


def _stage(b, a, s):
    front, back, hw, sh = a["stage_front"], a["stage_back"], a["stage_half_width"], a["stage_height"]
    b.box("stage", (0, (front + back) / 2, sh / 2), (2 * hw, back - front, sh))
    b.box("stage_floor", (0, (front + back) / 2, sh + 0.01), (2 * hw - 0.1, back - front - 0.1, 0.02))
    b.box("neon_pink", (0, front - 0.01, sh - 0.05), (2 * hw, 0.04, 0.05))
    # ramp from the stage lip down to the arena floor, with glowing edges
    aisle, ramp_end = s["aisle_width"], a["ramp_end"]
    length = front - ramp_end
    slope = math.atan2(sh, length)
    for i in range(16):
        t0, t1 = i / 16, (i + 1) / 16
        y0, y1 = front - t0 * length, front - t1 * length
        h = sh * (1 - (t0 + t1) / 2)
        b.box("ramp", (0, (y0 + y1) / 2, h / 2), (aisle, y0 - y1 + 0.002, max(h, 0.02)))
    for sx in (-1, 1):
        mid = (front + ramp_end) / 2
        m_h = sh / 2
        b.box("neon_cyan", (sx * aisle / 2, mid, m_h + 0.02), (0.04, length / math.cos(slope), 0.04),
              rot_z=0.0)
    _ = slope
    # titantron: frame, screen (textured in Godot) and truss legs
    sw, sb, st = a["screen_half_width"], a["screen_bottom"], a["screen_top"]
    y = back - 0.3
    b.box("stage", (0, y + 0.12, (sb + st) / 2), (2 * sw + 0.5, 0.2, st - sb + 0.5))
    for sx in (-1, 1):
        b.box("neon_pink", (sx * (sw + 0.22), y - 0.02, (sb + st) / 2), (0.05, 0.05, st - sb + 0.4))
        b.box("truss", (sx * (sw + 0.6), y, st / 2 + sh / 2), (0.25, 0.25, st - sh + 0.6))
    b.box("neon_cyan", (0, y - 0.02, st + 0.2), (2 * sw + 0.4, 0.05, 0.05))
    b.box("neon_cyan", (0, y - 0.02, sb - 0.2), (2 * sw + 0.4, 0.05, 0.05))


def _screen(a):
    """The titantron's display surface, its own object so Godot can put a live texture on it."""
    sw, sb, st = a["screen_half_width"], a["screen_bottom"], a["screen_top"]
    b = _Builder("titantron_screen")
    b.box("screen", (0, a["stage_back"] - 0.3 - 0.03, (sb + st) / 2), (2 * sw, 0.02, st - sb))
    return b.finish()


def _truss(b, a):
    th, half = a["truss_height"], a["truss_half"]
    for sx in (-1, 1):
        b.box("truss", (sx * half, 0, th), (0.3, 2 * half + 0.3, 0.3))
        b.box("truss", (0, sx * half, th), (2 * half + 0.3, 0.3, 0.3))
    # light cans pointing down at the ring
    for i in range(6):
        for sx in (-1, 1):
            p = -half + 0.7 + i * (2 * half - 1.4) / 5
            for (x, y) in ((sx * half, p), (p, sx * half)):
                b.cylinder("truss", (x, y, th - 0.45), 0.35, 0.14, segments=10)
                b.cylinder("lamp", (x, y, th - 0.47), 0.03, 0.11, segments=10)
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box("truss", (sx * half, sy * half, th + 6), (0.12, 0.12, 12))  # rigging up into the dark


def _walls(b, a):
    far = a["stands_inner"] + a["rows"] * a["row_depth"] + 1.0
    hgt = a["rows"] * a["row_rise"] + 8
    for side in range(4):
        ang = side * math.pi / 2
        x, y = -math.sin(ang) * far, math.cos(ang) * far
        b.box("wall", (x, y, hgt / 2), (2 * far + 1, 0.4, hgt), rot_z=ang)


def build_arena():
    s = load_spec()
    a = s["arena"]
    b = _Builder("arena")
    _tiers(b, a)
    _stage(b, a, s)
    _truss(b, a)
    _walls(b, a)
    return [b.finish(), _screen(a)]
