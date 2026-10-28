"""Procedural wrestler body, hair and eyes.

The body is one signed-distance shape built from bone-tagged primitives. Its base mesh
is polygonized once; body-type blend shapes are made by projecting that same mesh onto
variant shapes (heavier, more muscular, gut...), so every variant shares topology and
can be mixed freely in Godot.

Per-vertex data consumed by the Godot wrestler shader:
  UV0   = (rest_x * 0.25 + 0.5, rest_z * 0.25)        rest-pose position (front plane)
  UV1   = (limb_t, rest_y * 0.25 + 0.5)               0..1 along arm/leg chain, depth
  Color = (arm, leg, head+neck, torso) region weights (linear float)
"""
import bmesh
import bpy
import numpy as np

from . import rig
from .sdf import Prim, Shape, ellipsoid, half_space, polygonize, round_cone, sphere

BASE_PARAMS = dict(mass=0.0, muscle=0.4, gut=0.0, kneepads=0.0)
# Blend shape name -> parameter overrides relative to BASE_PARAMS.
BLEND_SHAPES = {
    "heavy": dict(mass=1.0),
    "slim": dict(mass=-1.0),
    "muscle": dict(muscle=1.0),
    "gut": dict(gut=1.0),
    "kneepads": dict(kneepads=1.0),
    "fem": dict(fem=1.0),
}

ARM_CHAIN = ["upper_arm", "forearm", "hand", "fingers"]
LEG_CHAIN = ["thigh", "shin", "foot", "toe"]


def _t(v):
    return tuple(float(x) for x in v)


def _dir(bone):
    return _t((rig.tail(bone) - rig.head(bone)).normalized())


# ------------------------------------------------------------------ shapes

def body_shape(mass=0.0, muscle=0.4, gut=0.0, kneepads=0.0, fem=0.0):
    """fem 0..1 morphs to a feminine build on the same skeleton: narrower shoulders and
    ribcage, slimmer neck and arms, a defined waist above wider hips, fuller thighs and
    glutes, a bust, smaller hands and feet, and a softer jaw and brow."""
    mt = 1 + (0.22 if mass > 0 else 0.15) * mass   # torso girth
    ml = 1 + (0.17 if mass > 0 else 0.14) * mass   # limb girth
    mu = 0.55 + 0.75 * muscle                      # muscle bulk
    fs = 1 - 0.12 * fem                            # shoulder, ribcage and upper back width
    fg = 1 - 0.14 * fem                            # neck and arm girth
    fx = 1 - 0.08 * fem                            # hands and feet
    P = []

    def add(fn, bone, k=0.03, **kw):
        P.append(Prim(fn, bone, k, **kw))

    def boot_cone(bone, a, b, r1, r2):
        """A foot part shrunk by fx about its underside, so the sole stays on the floor."""
        add(round_cone, bone, 0.03, a=_t(a - rig.Vector((0, 0, r1 * (1 - fx)))),
            b=_t(b - rig.Vector((0, 0, r2 * (1 - fx)))), r1=r1 * fx, r2=r2 * fx)

    # torso
    add(ellipsoid, "hips", 0.04, c=(0, 0.015, 1.00),
        radii=((0.165 + 0.03 * fem) * mt, (0.12 + 0.008 * fem) * mt, 0.125))
    add(ellipsoid, "spine", 0.05, c=(0, 0.005, 1.16),
        radii=(0.15 * mt * (1 - 0.16 * fem), 0.11 * mt * (1 - 0.06 * fem), 0.15))
    add(ellipsoid, "chest", 0.05, c=(0, 0.0, 1.36), radii=(0.18 * mt * fs, 0.125 * mt * fs, 0.17))
    add(ellipsoid, "chest", 0.04, c=(0, 0.005, 1.465),
        radii=((0.2 * mt + 0.02 * muscle) * fs, 0.115 * mt, 0.10))
    add(ellipsoid, "spine", 0.05, c=(0, -0.075 * mt, 1.22), radii=(0.10 * fs, 0.04, 0.13))
    if gut > 0:
        add(ellipsoid, "spine", 0.07, c=(0, -0.05 - 0.06 * gut, 1.14),
            radii=(0.15 + 0.03 * gut, 0.08 + 0.07 * gut, 0.13 + 0.04 * gut))
    add(round_cone, "neck", 0.04, a=(0, 0.015, 1.49), b=(0, 0.0, 1.71),
        r1=0.078 * (1 + 0.3 * muscle) * ml * fg, r2=0.066 * ml * (1 - 0.1 * fem))

    # head
    add(ellipsoid, "head", 0.03, c=(0, 0.012, 1.80), radii=(0.083, 0.098, 0.10))
    add(ellipsoid, "head", 0.03, c=(0, -0.035, 1.745), radii=(0.07, 0.07, 0.08))
    add(ellipsoid, "head", 0.02, c=(0, -0.083, 1.69),
        radii=(0.032 - 0.006 * fem, 0.022 - 0.003 * fem, 0.028 - 0.004 * fem))
    add(ellipsoid, "head", 0.02, c=(0, -0.086 + 0.003 * fem, 1.814),
        radii=(0.07, 0.024 - 0.003 * fem, 0.019 - 0.002 * fem))
    add(round_cone, "head", 0.012, a=(0, -0.092, 1.80), b=(0, -0.112, 1.758), r1=0.010, r2=0.016)
    add(ellipsoid, "head", 0.01, c=(0, -0.092, 1.727), radii=(0.026, 0.012, 0.010))

    for side in rig.SIDES:
        s = rig.side_sign(side)
        b = lambda name: f"{name}.{side}"  # noqa: E731

        # torso muscles
        add(ellipsoid, "hips", 0.04, c=(s * (0.075 + 0.01 * fem), 0.07 + 0.008 * fem, 0.935),
            radii=((0.085 + 0.012 * fem) * ml, (0.075 + 0.014 * fem) * mt, 0.095 + 0.01 * fem))
        add(ellipsoid, "chest", 0.04, c=(s * 0.08, -0.075 * mt, 1.42),
            radii=(0.085 * mu, 0.045 * mu, 0.06 * mu))
        if fem > 0:
            # bust: a teardrop from the upper chest to a fuller lower curve, rising out
            # of the chest as fem grows
            add(round_cone, "chest", 0.05, a=(s * 0.07, -0.02 - 0.03 * fem, 1.45),
                b=(s * 0.085, -0.04 - 0.055 * fem, 1.36), r1=0.04, r2=0.05)
        add(ellipsoid, "chest", 0.05, c=(s * 0.13 * mt * fs, 0.03, 1.33),
            radii=(0.06 * mu * fs, 0.08 * fs, 0.12))
        add(ellipsoid, b("clavicle"), 0.05, c=(s * 0.07, 0.035, 1.53),
            radii=(0.10 * mu * fg, 0.06 * mu * fg, 0.06 * mu * fg))

        # face details
        add(ellipsoid, "head", 0.025, c=(s * (0.048 - 0.004 * fem), -0.025, 1.705 + 0.003 * fem),
            radii=(0.032 - 0.004 * fem, 0.045, 0.03 - 0.003 * fem))
        add(ellipsoid, "head", 0.02, c=(s * 0.045, -0.072, 1.765), radii=(0.028, 0.02, 0.02))
        add(ellipsoid, "head", 0.01, c=(s * 0.085, 0.008, 1.775), radii=(0.012, 0.024, 0.033))
        add(ellipsoid, "head", 0.006, c=(s * 0.032, -0.083, 1.797), radii=(0.019, 0.012, 0.009))

        # arm
        sh, el = rig.head(b("upper_arm")), rig.tail(b("upper_arm"))
        wr = rig.tail(b("forearm"))
        ua, fa = _dir(b("upper_arm")), _dir(b("forearm"))
        add(ellipsoid, b("upper_arm"), 0.04, c=_t(sh + rig.Vector((s * 0.025, 0, -0.02))),
            radii=(0.075 * mu * ml * fg, 0.08 * mu * fg, 0.075 * mu * fg))
        add(round_cone, b("upper_arm"), 0.03, a=_t(sh), b=_t(el),
            r1=0.06 * ml * fg, r2=0.047 * ml * fg)
        add(ellipsoid, b("upper_arm"), 0.03,
            c=_t(rig.lerp(b("upper_arm"), 0.55) + rig.Vector((0, -0.022, 0))),
            radii=(0.09, 0.042 * mu * fg, 0.045 * mu * fg), axis=ua)
        add(ellipsoid, b("upper_arm"), 0.03,
            c=_t(rig.lerp(b("upper_arm"), 0.45) + rig.Vector((0, 0.025, 0))),
            radii=(0.10, 0.04 * mu * fg, 0.045 * mu * fg), axis=ua)
        add(round_cone, b("forearm"), 0.03, a=_t(el), b=_t(wr),
            r1=0.048 * ml * fg, r2=0.036 * ml * fg)
        add(ellipsoid, b("forearm"), 0.03, c=_t(rig.lerp(b("forearm"), 0.3)),
            radii=(0.09, 0.042 * mu * fg, 0.045 * mu * fg), axis=fa)
        add(ellipsoid, b("hand"), 0.02, c=_t(rig.lerp(b("hand"), 0.5)),
            radii=(0.05 * fx, 0.045 * fx, 0.024 * fx), axis=_dir(b("hand")))
        add(ellipsoid, b("fingers"), 0.015, c=_t(rig.lerp(b("fingers"), 0.45)),
            radii=(0.05 * fx, 0.043 * fx, 0.022 * fx), axis=_dir(b("fingers")))
        add(round_cone, b("thumb"), 0.012, a=_t(rig.head(b("thumb"))), b=_t(rig.tail(b("thumb"))),
            r1=0.015 * fx, r2=0.012 * fx)

        # leg
        hp, kn, an = rig.head(b("thigh")), rig.tail(b("thigh")), rig.tail(b("shin"))
        th, sn = _dir(b("thigh")), _dir(b("shin"))
        # fem widens the hips from the outside, keeping the gap between the thighs
        add(round_cone, b("thigh"), 0.03, a=_t(hp + rig.Vector((s * 0.012 * fem, 0, 0))), b=_t(kn),
            r1=(0.10 + 0.008 * fem) * ml, r2=(0.062 - 0.004 * fem) * ml)
        add(ellipsoid, b("thigh"), 0.04,
            c=_t(rig.lerp(b("thigh"), 0.45) + rig.Vector((0, -0.03, 0))),
            radii=(0.2, 0.065 * mu * ml, 0.06 * mu), axis=th)
        add(ellipsoid, b("thigh"), 0.04,
            c=_t(rig.lerp(b("thigh"), 0.5) + rig.Vector((0, 0.03, 0))),
            radii=(0.18, (0.06 + 0.006 * fem) * ml, 0.05 * mu), axis=th)
        add(sphere, b("shin"), 0.03, c=_t(kn + rig.Vector((0, -0.01, 0))), r=0.058 * ml * (1 - 0.06 * fem))
        if kneepads > 0:
            add(ellipsoid, b("shin"), 0.015, c=_t(kn + rig.Vector((0, -0.022, 0.005))),
                radii=(0.08, 0.072 * ml, 0.06), axis=sn)
        add(round_cone, b("shin"), 0.03, a=_t(kn), b=_t(an),
            r1=0.055 * ml * (1 - 0.06 * fem), r2=0.047 * fx)
        add(ellipsoid, b("shin"), 0.04,
            c=_t(rig.lerp(b("shin"), 0.28) + rig.Vector((0, 0.035, 0))),
            radii=(0.13, 0.05 * ml, 0.05 * mu), axis=sn)
        # boot shaft, foot, heel, toe cap
        add(round_cone, b("shin"), 0.02, a=_t(rig.lerp(b("shin"), 0.62)),
            b=_t(an + rig.Vector((0, 0, -0.02))), r1=0.056 * fx, r2=0.058 * fx)
        boot_cone(b("foot"), an + rig.Vector((0, 0, -0.035)),
                  rig.tail(b("foot")) + rig.Vector((0, 0, 0.005)), 0.056, 0.045)
        add(sphere, b("foot"), 0.03, c=(s * 0.14, 0.035, 0.05 * fx), r=0.05 * fx)
        boot_cone(b("toe"), rig.head(b("toe")), rig.tail(b("toe")), 0.045, 0.035)

    # eye sockets, flat soles
    for side in rig.SIDES:
        P.append(Prim(sphere, None, 0.012, op="sub",
                      c=(rig.side_sign(side) * 0.032, -0.1, 1.79), r=0.017))
    P.append(Prim(half_space, None, 0.006, op="and", normal=(0, 0, 1), offset=0.0))
    return Shape(P)


HAIR_FRONT = dict(normal=(0, 1, 0.8), offset=float(np.dot(np.array([0, 1, 0.8]) / np.linalg.norm([0, 1, 0.8]),
                                                         [0, -0.07, 1.85])))


def _sdf(p, shape, grow=0.0):
    """A whole Shape used as one primitive, grown outwards by `grow` metres."""
    return shape.eval(p) - grow


def _head():
    """The bare head and neck. Short hair and facial hair are layers on its skin. Only the neck
    changes with build, so this takes the heaviest one: the swelling neck stays under the hair."""
    big = body_shape(**{**BASE_PARAMS, "mass": 1.0, "muscle": 1.0})
    return Shape([p for p in big.prims if p.bone in ("head", "neck")])


def _layer(head, thickness):
    """Hair lying on the skin; it fills the head too, which the cuts after it close off."""
    return Prim(_sdf, "head", shape=head, grow=thickness)


def _combed(p, shape, grow, pole, aim, lines, depth):
    """A layer `grow` thick on `shape` with `lines` comb grooves `depth` deep. They run back from
    where the line from `pole` along `aim` leaves the face and fade out as they gather at `pole`."""
    a = np.asarray(aim, np.float32) / np.linalg.norm(aim)
    across = np.array([1, 0, 0], np.float32)
    q = p - np.asarray(pole, np.float32)
    u, v = q @ across, q @ np.cross(a, across)
    fade = np.clip((np.hypot(u, v) - 0.015) / 0.04, 0, 1)
    return shape.eval(p) - grow + depth * fade * 0.5 * (1 - np.cos(np.arctan2(u, v) * lines))


def _ear_gaps(k=0.008):
    """Cut the hair back around both ears."""
    return [Prim(ellipsoid, None, k, op="sub", c=(s * 0.088, 0.008, 1.772), radii=(0.03, 0.034, 0.044))
            for s in (1, -1)]


def _scalp_point(polar, azimuth, depth=1.0):
    """Point on the skull: polar degrees from the crown, azimuth degrees round from the face
    towards the left ear. `depth` < 1 sinks it into the head."""
    t, f = np.radians(polar), np.radians(azimuth)
    d = np.array([np.sin(t) * np.sin(f), -np.sin(t) * np.cos(f), np.cos(t)])
    return np.array([0, 0.012, 1.80]) + d * np.array([0.083, 0.098, 0.10]) * depth, d


# Gelled spikes: (polar, azimuth, length) on the top of the head. They stand up, fan out a
# little and sweep back.
SPIKES = [(0, 0, 0.07), (26, 0, 0.064), (26, 72, 0.068), (26, 144, 0.062), (26, 216, 0.066), (26, 288, 0.068),
          (50, 35, 0.054), (50, 105, 0.058), (50, 180, 0.052), (50, 255, 0.058), (50, 325, 0.054),
          (70, 140, 0.04), (70, 220, 0.04)]


def _spikes():
    P = []
    for polar, azimuth, length in SPIKES:
        base, d = _scalp_point(polar, azimuth, 0.7)
        tip, _ = _scalp_point(polar, azimuth)
        lean = d * (0.6, 0.6, 0) + np.array([0, 0.25, 1.0])
        P.append(Prim(round_cone, "head", 0.014, a=_t(base), b=_t(tip + lean / np.linalg.norm(lean) * length),
                      r1=0.032, r2=0.006))
    return P


def _puffs(centre, radii, count, r, rise):
    """Round curls spread evenly over an ellipsoid (a Fibonacci spiral), each rising `rise` above it."""
    P = []
    for i in range(count):
        z = 1 - 2 * (i + 0.5) / count
        a = i * np.pi * (3 - np.sqrt(5))
        d = np.array([np.sqrt(1 - z * z) * np.cos(a), np.sqrt(1 - z * z) * np.sin(a), z])
        c = np.asarray(centre) + d * (np.asarray(radii) - (r - rise))
        P.append(Prim(sphere, "head", 0.012, c=_t(c), r=r))
    return P


def hair_shape(style):
    P = []
    scalp = dict(c=(0, 0.016, 1.805), radii=(0.091, 0.106, 0.106))
    if style == "mullet":
        P += [Prim(ellipsoid, "head", **scalp),
              Prim(half_space, None, 0.01, op="and", **HAIR_FRONT),
              Prim(half_space, None, 0.01, op="and", normal=(0, 0, 1), offset=1.75),
              Prim(round_cone, "head", 0.04, a=(0, 0.06, 1.79), b=(0, 0.085, 1.58), r1=0.075, r2=0.058)]
    elif style == "mohawk":
        P += [Prim(ellipsoid, "head", c=(0, 0.02, 1.87), radii=(0.022, 0.115, 0.075)),
              Prim(half_space, None, 0.01, op="and", normal=(0, 0, 1), offset=1.80)]
    elif style == "flattop":
        P += [Prim(ellipsoid, "head", c=(0, 0.012, 1.83), radii=(0.094, 0.108, 0.115)),
              Prim(half_space, None, 0.008, op="and", normal=(0, 0, -1), offset=-1.95),
              Prim(half_space, None, 0.01, op="and", **HAIR_FRONT),
              Prim(half_space, None, 0.01, op="and", normal=(0, 0, 1), offset=1.76)]
    elif style == "long":
        P += [Prim(ellipsoid, "head", **scalp),
              Prim(half_space, None, 0.01, op="and", **HAIR_FRONT),
              Prim(half_space, None, 0.01, op="and", normal=(0, 0, 1), offset=1.74)]
        for s in (1, -1):
            P.append(Prim(round_cone, "head", 0.04, a=(s * 0.07, 0.03, 1.79),
                          b=(s * 0.085, 0.06, 1.52), r1=0.04, r2=0.045))
        P.append(Prim(round_cone, "head", 0.04, a=(0, 0.07, 1.79), b=(0, 0.09, 1.50), r1=0.07, r2=0.07))
    elif style == "ponytail":
        # pulled back tight, gathered at the back of the head, then a thick tail
        P += [Prim(_combed, "head", shape=_head(), grow=0.005, pole=(0, 0.11, 1.815), aim=(0, -1, 0.05),
                   lines=36, depth=0.0012),
              Prim(half_space, None, 0.006, op="and", **HAIR_FRONT),
              *_ear_gaps(),
              Prim(half_space, None, 0.006, op="and", normal=(0, 0, 1), offset=1.735),
              Prim(ellipsoid, "head", 0.02, c=(0, 0.11, 1.815), radii=(0.036, 0.028, 0.032)),
              Prim(round_cone, "head", 0.025, a=(0, 0.13, 1.805), b=(0, 0.158, 1.70), r1=0.03, r2=0.034),
              Prim(round_cone, "head", 0.025, a=(0, 0.158, 1.70), b=(0, 0.152, 1.615), r1=0.034, r2=0.016)]
    elif style == "spiky":
        P += [_layer(_head(), 0.007), *_spikes(),
              Prim(half_space, None, 0.006, op="and", **HAIR_FRONT),
              *_ear_gaps(),
              Prim(half_space, None, 0.006, op="and", normal=(0, 0, 1), offset=1.74)]
    elif style == "buzz":
        P += [_layer(_head(), 0.0035),
              Prim(half_space, None, 0.003, op="and", **HAIR_FRONT),
              *_ear_gaps(0.004),
              # nape rounded off at the corners
              *[Prim(ellipsoid, None, 0.004, op="sub", c=(s * 0.085, 0.075, 1.705), radii=(0.05, 0.05, 0.05))
                for s in (1, -1)],
              Prim(half_space, None, 0.003, op="and", normal=(0, 0, 1), offset=1.73)]
    elif style == "afro":
        centre, radii = (0, 0.035, 1.88), (0.15, 0.15, 0.128)
        P += [_layer(_head(), 0.006),
              Prim(ellipsoid, "head", 0.04, c=centre, radii=radii),
              *_puffs(centre, radii, 64, 0.042, 0.01),
              Prim(half_space, None, 0.03, op="and", **HAIR_FRONT),
              # the bottom edge covers the ears and drops towards the nape
              Prim(half_space, None, 0.02, op="and", normal=(0, 0.5, 1), offset=1.745 / np.hypot(0.5, 1))]
    elif style == "slick":
        # combed straight back from a little lift behind the hairline
        top = Shape([_layer(_head(), 0.006),
                     Prim(ellipsoid, "head", 0.035, c=(0, 0.02, 1.87), radii=(0.066, 0.08, 0.038))])
        P += [Prim(_combed, "head", shape=top, grow=0.0, pole=(0, 0.09, 1.71), aim=(0, -0.904, 0.428),
                   lines=30, depth=0.0015),
              Prim(half_space, None, 0.006, op="and", **HAIR_FRONT),
              *_ear_gaps(),
              # tapering to a point at the nape
              *[Prim(ellipsoid, None, 0.012, op="sub", c=(s * 0.088, 0.08, 1.70), radii=(0.055, 0.06, 0.085))
                for s in (1, -1)],
              Prim(half_space, None, 0.006, op="and", normal=(0, 0, 1), offset=1.70)]
    else:
        raise ValueError(style)
    return Shape(P)


HAIR_STYLES = ["mullet", "mohawk", "flattop", "long", "ponytail", "spiky", "buzz", "afro", "slick"]

# Facial hair. The shader paints the mouth line at z ~1.7275 between x = +-0.026; it stays clear.
# Strokes are (x, z, radius) points on one side of the face, seen from the front.
MOUSTACHE = [(0.0, 1.7392, 0.0068), (0.012, 1.7385, 0.0068), (0.022, 1.7357, 0.0064),
             (0.030, 1.731, 0.0056), (0.036, 1.724, 0.0045)]


def _on_face(head, x, z):
    """The point of the face at (x, z), found by marching in from the front."""
    ys = np.arange(-0.2, 0.05, 0.0005, dtype=np.float32)
    d = head.eval(np.stack([np.full_like(ys, x), ys, np.full_like(ys, z)], 1))
    return (x, float(ys[np.argmax(d < 0)]), z)


def _stroke(head, points, k=0.004):
    """Capsules laid over the face through `points`, on both sides."""
    P = []
    for s in (1, -1):
        c = [_on_face(head, s * x, z) for x, z, _ in points]
        P += [Prim(round_cone, "head", k, a=c[i], b=c[i + 1], r1=points[i][2], r2=points[i + 1][2])
              for i in range(len(points) - 1)]
    return P


def facial_hair_shape(style):
    head = _head()
    P = []
    if style == "moustache":
        P += _stroke(head, MOUSTACHE)
    elif style == "goatee":
        # chin patch with a point, joined to a lighter moustache round the mouth
        P += [_layer(head, 0.0055),
              Prim(ellipsoid, None, 0.006, op="and", c=(0, -0.1, 1.684), radii=(0.027, 0.04, 0.028)),
              Prim(round_cone, "head", 0.01, a=(0, -0.097, 1.672), b=(0, -0.094, 1.652), r1=0.008, r2=0.005)]
        P += _stroke(head, [(x, z, r * 0.8) for x, z, r in MOUSTACHE[:-1]])
        P += _stroke(head, [(0.031, 1.731, 0.0048), (0.033, 1.718, 0.0046), (0.027, 1.704, 0.005)])
    elif style == "beard":
        cheeks = Shape([Prim(half_space, None, 0.0, normal=(s * 0.85, 0, -1), offset=-1.715 / np.hypot(0.85, 1))
                        for s in (1, -1)])
        P += [_layer(head, 0.007),
              # below a line from the mouth corners up to the sideburns, in front of the ears
              Prim(_sdf, None, 0.008, op="and", shape=cheeks),
              Prim(half_space, None, 0.008, op="and", normal=(0, -1, -0.32), offset=-0.5476 / np.hypot(1, 0.32)),
              Prim(half_space, None, 0.008, op="and", normal=(0, -0.333, 1), offset=1.685 / np.hypot(0.333, 1)),
              Prim(ellipsoid, None, 0.006, op="sub", c=(0, -0.105, 1.7245), radii=(0.03, 0.03, 0.0105)),
              Prim(ellipsoid, "head", 0.02, c=(0, -0.088, 1.674), radii=(0.038, 0.028, 0.025))]
        P += _stroke(head, MOUSTACHE)
    elif style == "horseshoe":
        # a heavy moustache whose ends run down past the chin
        P += _stroke(head, MOUSTACHE[:-1])
        P += _stroke(head, [(0.031, 1.731, 0.006), (0.034, 1.716, 0.0058), (0.034, 1.700, 0.0055),
                            (0.032, 1.684, 0.0052)])
        for s in (1, -1):
            end = _on_face(head, s * 0.032, 1.684)
            P.append(Prim(round_cone, "head", 0.004, a=end, b=(end[0], end[1] - 0.003, 1.664), r1=0.0052, r2=0.0045))
    else:
        raise ValueError(style)
    return Shape(P)


FACIAL_HAIR = ["moustache", "goatee", "beard", "horseshoe"]

# ------------------------------------------------------------------ meshing helpers

def _mesh_from_shape(name, shape, bmin, bmax, h, target_tris):
    verts, quads = polygonize(shape, bmin, bmax, h)
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts.tolist(), [], quads.tolist())
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)

    tris = len(quads) * 2
    if tris > target_tris:
        mod = ob.modifiers.new("decimate", "DECIMATE")
        mod.ratio = target_tris / tris
        dg = bpy.context.evaluated_depsgraph_get()
        new_me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
        ob.modifiers.clear()
        ob.data = new_me
        bpy.data.meshes.remove(me)
        me = new_me

    # snap decimated vertices back onto the exact surface
    co = _get_co(me)
    _set_co(me, shape.project(co, iters=2))
    for poly in me.polygons:
        poly.use_smooth = True
    me.update()
    return ob


def _get_co(me):
    co = np.empty(len(me.vertices) * 3, np.float32)
    me.vertices.foreach_get("co", co)
    return co.reshape(-1, 3)


def _set_co(me, co):
    me.vertices.foreach_set("co", np.ascontiguousarray(co, np.float32).ravel())


def _normals(me):
    n = np.empty(len(me.vertices) * 3, np.float32)
    me.vertices.foreach_get("normal", n)
    return n.reshape(-1, 3)


def _set_weights(ob, weights):
    """weights: dict bone -> (N,) array."""
    for bone, w in weights.items():
        vg = ob.vertex_groups.new(name=bone)
        idx = np.nonzero(w > 0.005)[0]
        for i in idx:
            vg.add([int(i)], float(w[i]), "REPLACE")


def _skin_weights(dists, sigma=0.012, max_influences=4):
    names = list(dists)
    D = np.stack([dists[n] for n in names], 1)            # (N, B)
    dmin = D.min(1, keepdims=True)
    W = np.exp(-(D - dmin) / sigma)
    if W.shape[1] > max_influences:
        cut = np.partition(W, -max_influences, axis=1)[:, -max_influences][:, None]
        W = np.where(W >= cut, W, 0)
    W /= W.sum(1, keepdims=True)
    return {n: W[:, i] for i, n in enumerate(names)}


def _chain_t(co, weights, chain_names):
    """0..1 position along a limb chain, blended by skin weights."""
    lengths = [(rig.tail(n) - rig.head(n)).length for n in chain_names]
    total = sum(lengths)
    acc = np.zeros(len(co), np.float32)
    wsum = np.zeros(len(co), np.float32)
    start = 0.0
    for n, ln in zip(chain_names, lengths):
        if n in weights:
            h = np.array(rig.head(n), np.float32)
            d = np.array(rig.tail(n) - rig.head(n), np.float32) / ln
            proj = np.clip((co - h) @ d, 0, ln)
            acc += weights[n] * (start + proj) / total
            wsum += weights[n]
        start += ln
    return np.where(wsum > 1e-4, acc / np.maximum(wsum, 1e-4), 0.0)


def _write_attributes(me, co, weights):
    def wsum(names):
        return sum((weights[n] for n in names if n in weights), np.zeros(len(co), np.float32))

    arms = [f"{b}.{s}" for s in rig.SIDES for b in ARM_CHAIN + ["thumb"]]
    legs = [f"{b}.{s}" for s in rig.SIDES for b in LEG_CHAIN]
    region = np.stack([wsum(arms), wsum(legs), wsum(["head", "neck"]),
                       wsum(["hips", "spine", "chest", "clavicle.L", "clavicle.R"])], 1)
    col = me.color_attributes.new("Color", "FLOAT_COLOR", "POINT")
    col.data.foreach_set("color", region.astype(np.float32).ravel())
    me.color_attributes.active_color = col

    limb = np.zeros(len(co), np.float32)
    for s in rig.SIDES:
        for chain in (ARM_CHAIN, LEG_CHAIN):
            names = [f"{b}.{s}" for b in chain]
            t = _chain_t(co, weights, names)
            limb = np.maximum(limb, t * np.clip(wsum(names), 0, 1))

    uv0 = np.stack([co[:, 0] * 0.25 + 0.5, co[:, 2] * 0.25], 1)
    uv1 = np.stack([limb, co[:, 1] * 0.25 + 0.5], 1)
    loops = np.empty(len(me.loops), np.int64)
    me.loops.foreach_get("vertex_index", loops)
    for name, uv in (("UVMap", uv0), ("Body", uv1)):
        layer = me.uv_layers.new(name=name)
        layer.data.foreach_set("uv", uv[loops].astype(np.float32).ravel())


def _material(name, color):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    return mat


def _bind(ob, armature):
    ob.parent = armature
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = armature


# ------------------------------------------------------------------ builders

def build_body(armature, quick=False):
    h = 0.016 if quick else 0.008
    target = 8000 if quick else 26000
    base = body_shape(**BASE_PARAMS)
    ob = _mesh_from_shape("body", base, (-0.95, -0.42, -0.03), (0.95, 0.3, 2.0), h, target)
    me = ob.data
    co = _get_co(me)

    _, dists = base.eval(co, want_bones=True)
    weights = _skin_weights(dists)
    _set_weights(ob, weights)
    _write_attributes(me, co, weights)
    me.materials.append(_material("body", (0.8, 0.55, 0.42)))

    # blend shapes: each vertex moves along its normal onto the variant surface. A few
    # vertices next to decimation slivers have skewed normals and would slide along the
    # surface into spikes; those move along the field gradient (the true normal) instead.
    ob.shape_key_add(name="Basis", from_mix=False)
    nrm = _normals(me)
    grad = base.gradient(co)
    grad /= np.maximum(np.linalg.norm(grad, axis=1, keepdims=True), 1e-8)
    nrm = np.where(np.einsum("ij,ij->i", nrm, grad)[:, None] < 0.7, grad, nrm)
    for key, overrides in BLEND_SHAPES.items():
        variant = body_shape(**{**BASE_PARAMS, **overrides})
        p = co.copy()
        for _ in range(5):
            p -= nrm * variant.eval(p)[:, None]
        sk = ob.shape_key_add(name=key, from_mix=False)
        sk.data.foreach_set("co", p.astype(np.float32).ravel())

    _bind(ob, armature)
    return ob


def build_hair(armature, style, quick=False):
    return _hair_mesh(armature, f"hair_{style}", hair_shape(style), (-0.2, -0.14, 1.45), (0.2, 0.23, 2.03),
                      0.008 if quick else 0.0045, 2500 if quick else 6000)


def build_facial_hair(armature, style, quick=False):
    return _hair_mesh(armature, f"facial_{style}", facial_hair_shape(style), (-0.12, -0.16, 1.6),
                      (0.12, 0.05, 1.82), 0.005 if quick else 0.003, 1200 if quick else 2500)


def _hair_mesh(armature, name, shape, bmin, bmax, h, target_tris):
    """A mesh in the hair material, skinned entirely to the head."""
    ob = _mesh_from_shape(name, shape, bmin, bmax, h, target_tris)
    me = ob.data
    _set_weights(ob, {"head": np.ones(len(me.vertices), np.float32)})
    me.materials.append(_material("hair", (0.15, 0.1, 0.06)))
    _bind(ob, armature)
    return ob


def build_eyes(armature):
    """Two eyeballs facing forward. Color R = angle from the eye's forward axis / 90 deg."""
    me = bpy.data.meshes.new("eyes")
    bm = bmesh.new()
    from mathutils import Matrix
    for side in rig.SIDES:
        s = rig.side_sign(side)
        m = Matrix.Translation((s * 0.032, -0.079, 1.79)) @ Matrix.Rotation(np.pi / 2, 4, "X")
        bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=16, radius=0.0128, matrix=m)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("eyes", me)
    bpy.context.scene.collection.objects.link(ob)

    # Point colors (corner colors export in a non-deterministic order).
    co = _get_co(me)
    centre = np.array([[0.032, -0.079, 1.79]], np.float32) * np.where(co[:, :1] > 0, 1, [[-1, 1, 1]])
    local = co - centre
    fwd = -local[:, 1] / np.maximum(np.linalg.norm(local, axis=1), 1e-6)
    data = np.zeros((len(co), 4), np.float32)
    data[:, 0] = np.degrees(np.arccos(np.clip(fwd, -1, 1))) / 90.0
    data[:, 3] = 1
    col = me.color_attributes.new("Color", "FLOAT_COLOR", "POINT")
    col.data.foreach_set("color", data.ravel())
    for poly in me.polygons:
        poly.use_smooth = True
    me.color_attributes.active_color = col
    _set_weights(ob, {"head": np.ones(len(me.vertices), np.float32)})
    me.materials.append(_material("eyes", (1, 1, 1)))
    _bind(ob, armature)
    return ob
