"""Ground and top-rope moves: leg drop, knee drop, moonsault and flying headbutt.

The ground moves are done to an opponent lying across in front of the attacker
(align "attacker", like elbow_drop), head to the attacker's right. The defender's
near arm lies spread toward the attacker, so they flinch it in along their side
while the attacker is in the air; nobody lands on it.

The dives play while the game flies the wrestler along an arc from the perch to the
target (Wrestler._st_dive), then blend into dive_land. They start exactly where the
perch pose stands (the flight starts 0.5 m above the perch) and end lying flat on the
target in dive_land's first pose, grounded, so neither end pops.
"""
from ..poses import Anim, Paired, add, at, merge, sym
from .basic import STANCE
from .environment import PERCH, SPLASH
from .reactions import CROUCH, DOWN_BACK


def _root(pose, fwd=0.0, left=0.0):
    return merge(pose, {"root": {"move": (left, fwd, 0.0)}})


# the near (left) arm drawn in along the side, and lifted on the way there
TUCKED_ARM = {"upper_arm.L": {"raise": -48, "swing": 4, "twist": 0}, "forearm.L": {"bend": 15}}
FLINCH_D = merge(DOWN_BACK, {"upper_arm.L": {"raise": -10, "swing": 25, "twist": 0}, "forearm.L": {"bend": 50},
                             "head": {"bend": 14}})
GUARD_D = merge(DOWN_BACK, TUCKED_ARM, {"head": {"bend": 12}})
# the reflex when something lands on them: legs and the free arm jerk up
JOLT_D = merge(DOWN_BACK, TUCKED_ARM, sym({"thigh.L": {"raise": 40}, "shin.L": {"bend": 50}, "foot.L": {"flex": 10}}), {
    "upper_arm.R": {"raise": 55, "swing": 45}, "forearm.R": {"bend": 60}, "fingers.R": {"curl": 70},
    "forearm.L": {"bend": 45}, "fingers.L": {"curl": 70},
    "spine": {"bend": 5}, "chest": {"bend": 4}})
# ...and settling back
SETTLE_D = merge(DOWN_BACK, TUCKED_ARM, sym({"thigh.L": {"raise": 22}, "shin.L": {"bend": 35}}),
                 {"head": {"turn": 20}})

# ---------------------------------------------------------------- leg drop

LEG_D = (0.5, 0.49)    # defender root: forward, left (throat under the right leg)


def _d_leg(pose):
    return at(pose, LEG_D[0], left=LEG_D[1], turn=90)


LEG_CROUCH = merge(STANCE, sym({"thigh.L": {"raise": 55}, "shin.L": {"bend": 85}, "foot.L": {"flex": 28},
                                "upper_arm.L": {"raise": -45, "swing": -45, "twist": 0}, "forearm.L": {"bend": 25}}),
                   {"spine": {"bend": 28}, "chest": {"bend": 8}, "neck": {"bend": -20}})
LEG_SPRING = merge(sym({"thigh.L": {"raise": 8, "spread": 6}, "shin.L": {"bend": 8}, "foot.L": {"flex": -35},
                        "upper_arm.L": {"raise": 70, "swing": 70, "twist": 0}, "forearm.L": {"bend": 20}}),
                   {"spine": {"bend": -4}, "chest": {"bend": -4}, "neck": {"bend": -10}})
# airborne "sitting", legs out straight over the throat and chest
LEG_AIR = merge(sym({"thigh.L": {"raise": 68, "spread": 3}, "shin.L": {"bend": 4}, "foot.L": {"flex": -15},
                     "upper_arm.L": {"raise": 100, "swing": 10, "twist": 0}, "forearm.L": {"bend": 15},
                     "fingers.L": {"curl": 20}}),
                {"hips": {"bend": -25}, "spine": {"bend": 10}, "chest": {"bend": 6}, "neck": {"bend": 5}})
# seated: the backs of the legs across throat (right) and chest (left), hands posted behind
LEG_SIT = merge(sym({"upper_arm.L": {"raise": -15, "swing": -55, "twist": 0}, "forearm.L": {"bend": 5},
                     "hand.L": {"bend": -50}, "fingers.L": {"curl": 10}}), {
    "hips": {"bend": -32},
    "spine": {"bend": 16}, "chest": {"bend": 8}, "neck": {"bend": 5}, "head": {"bend": 5},
    "thigh.R": {"raise": 76, "spread": 2}, "shin.R": {"bend": 8}, "foot.R": {"flex": -10},
    "thigh.L": {"raise": 80, "spread": 2}, "shin.L": {"bend": 6}, "foot.L": {"flex": -10},
})
# knees drawn up off the defender, then the feet planted to stand
LEG_LIFT = merge(LEG_SIT, sym({"thigh.L": {"raise": 105, "spread": 10}, "shin.L": {"bend": 110}, "foot.L": {"flex": 5}}),
                 {"hips": {"bend": -25}, "spine": {"bend": 22}})
LEG_TUCK = merge(sym({"thigh.L": {"raise": 115, "spread": 14}, "shin.L": {"bend": 140}, "foot.L": {"flex": 20},
                      "upper_arm.L": {"raise": -20, "swing": -40, "twist": 0}, "forearm.L": {"bend": 10},
                      "hand.L": {"bend": -50}}),
                 {"hips": {"bend": -10}, "spine": {"bend": 30}, "chest": {"bend": 15}, "neck": {"bend": -10}})

leg_drop = Paired("leg_drop", [
    (0.0, STANCE, _d_leg(DOWN_BACK)),
    (0.18, LEG_CROUCH, _d_leg(DOWN_BACK)),
    (0.27, LEG_SPRING, _d_leg(DOWN_BACK), {"air_a": 0.12}),
    (0.37, LEG_AIR, _d_leg(FLINCH_D), {"air_a": 0.55}),
    (0.43, LEG_AIR, _d_leg(GUARD_D), {"air_a": 0.45}),
    (0.47, LEG_AIR, _d_leg(GUARD_D), {"air_a": 0.2}),
    (0.5, LEG_SIT, _d_leg(GUARD_D)),
    (0.57, add(LEG_SIT, {"hips": {"bend": -6}, "thigh.R": {"raise": -5}, "thigh.L": {"raise": -5},
                         "head": {"bend": -10}}), _d_leg(JOLT_D)),
    (0.75, LEG_SIT, _d_leg(SETTLE_D)),
    (0.88, LEG_LIFT, _d_leg(SETTLE_D)),
    (1.0, LEG_TUCK, _d_leg(SETTLE_D)),
    (1.14, CROUCH, _d_leg(SETTLE_D)),
    (1.35, STANCE, _d_leg(DOWN_BACK)),
], events={"impact": 0.5})

# ---------------------------------------------------------------- knee drop

KNEE_D = (0.6, 0.34)   # defender root: forward, left (chest under the right knee)
KNEE_FWD = 0.38        # how far the attacker hops in


def _d_knee(pose):
    return at(pose, KNEE_D[0], left=KNEE_D[1], turn=90)


KNEE_CROUCH = merge(STANCE, sym({"thigh.L": {"raise": 45}, "shin.L": {"bend": 70}, "foot.L": {"flex": 25},
                                 "upper_arm.L": {"raise": -40, "swing": -30, "twist": 0}, "forearm.L": {"bend": 40}}),
                    {"spine": {"bend": 22}, "chest": {"bend": 8}})
# hop: right knee drawn up high, left leg hanging
KNEE_HOP = merge(sym({"upper_arm.L": {"raise": 75, "swing": 30, "twist": 0}, "forearm.L": {"bend": 35},
                      "fingers.L": {"curl": 60}}), {
    "thigh.R": {"raise": 105, "spread": 4}, "shin.R": {"bend": 125}, "foot.R": {"flex": -20},
    "thigh.L": {"raise": 10, "spread": 6}, "shin.L": {"bend": 25}, "foot.L": {"flex": -25},
    "spine": {"bend": 8}, "chest": {"bend": 4}, "neck": {"bend": -10},
})
# the right knee driven into the chest, shin out behind; the left foot planted behind
KNEE_DOWN = merge(sym({"upper_arm.L": {"raise": 35, "swing": -20, "twist": 0}, "forearm.L": {"bend": 30},
                       "fingers.L": {"curl": 70}}), {
    "thigh.R": {"raise": 28, "spread": 2}, "shin.R": {"bend": 103}, "foot.R": {"flex": -30},
    "thigh.L": {"raise": -18, "spread": 10}, "shin.L": {"bend": 48}, "foot.L": {"flex": -20},
    "spine": {"bend": 25}, "chest": {"bend": 12}, "neck": {"bend": -15},
})
KNEE_RISE = merge(STANCE, {"thigh.R": {"raise": 45}, "shin.R": {"bend": 70}, "thigh.L": {"raise": 5},
                           "shin.L": {"bend": 25}, "spine": {"bend": 18}})

knee_drop = Paired("knee_drop", [
    (0.0, STANCE, _d_knee(DOWN_BACK)),
    (0.14, KNEE_CROUCH, _d_knee(DOWN_BACK)),
    (0.27, _root(KNEE_HOP, KNEE_FWD * 0.5), _d_knee(FLINCH_D), {"air_a": 0.35}),
    (0.36, _root(KNEE_HOP, KNEE_FWD * 0.85), _d_knee(GUARD_D), {"air_a": 0.22}),
    (0.42, _root(KNEE_DOWN, KNEE_FWD), _d_knee(GUARD_D)),
    (0.49, _root(add(KNEE_DOWN, {"spine": {"bend": 6}, "chest": {"bend": 4}}), KNEE_FWD), _d_knee(JOLT_D)),
    (0.66, _root(merge(KNEE_DOWN, {"spine": {"bend": 12}, "chest": {"bend": 0}}), KNEE_FWD), _d_knee(SETTLE_D)),
    (0.82, _root(KNEE_RISE, KNEE_FWD * 0.4), _d_knee(SETTLE_D)),
    (1.0, STANCE, _d_knee(DOWN_BACK)),
], events={"impact": 0.42})

# ---------------------------------------------------------------- top-rope dives

HIP_H = 1.0   # rest height of the hips above the root (rig.py)


def _fly(pose, h, back=None):
    """An airborne pose with the hips h metres above the root (the game flies the root along the arc),
    optionally turned `back` degrees backward about the hips (90 = flat on the back, 270 = face down)."""
    hips = {"move": (0.0, 0.0, h - HIP_H)}
    if back is not None:
        hips["bend"] = -back
    return merge(pose, {"hips": hips})


PERCHED = {"ground": True, "air": -0.5}    # the flight starts 0.5 m above the perch
LANDED = {"ground": True}

# moonsault: launch leaning out, then a full backward somersault into a splash
MOON_LAUNCH = merge(sym({"thigh.L": {"raise": 5, "spread": 6}, "shin.L": {"bend": 10}, "foot.L": {"flex": -35},
                         "upper_arm.L": {"raise": 150, "swing": 20, "twist": 0}, "forearm.L": {"bend": 10}}),
                    {"hips": {"bend": 20}, "spine": {"bend": -5}, "neck": {"bend": -15}})
MOON_ARCH = merge(sym({"thigh.L": {"raise": 30, "spread": 8}, "shin.L": {"bend": 50}, "foot.L": {"flex": -30},
                       "upper_arm.L": {"raise": 160, "swing": -20, "twist": 0}, "forearm.L": {"bend": 15}}),
                  {"spine": {"bend": -15}, "chest": {"bend": -10}, "neck": {"bend": -30}, "head": {"bend": -15}})
MOON_TUCK = merge(sym({"thigh.L": {"raise": 110, "spread": 12}, "shin.L": {"bend": 95}, "foot.L": {"flex": -25},
                       "upper_arm.L": {"raise": 20, "swing": 60, "twist": 0}, "forearm.L": {"bend": 70},
                       "fingers.L": {"curl": 70}}),
                  {"spine": {"bend": 20}, "chest": {"bend": 15}, "neck": {"bend": 15}})
MOON_OPEN = merge(SPLASH, sym({"thigh.L": {"raise": 30}, "shin.L": {"bend": 40}}))

dive_moonsault = Anim("dive_moonsault", [
    (0.0, PERCH, PERCHED),
    (0.07, _fly(MOON_LAUNCH, 0.25)),
    (0.14, _fly(MOON_ARCH, 0.5, back=40)),
    (0.21, _fly(MOON_TUCK, 0.55, back=110)),
    (0.28, _fly(MOON_TUCK, 0.5, back=180)),
    (0.35, _fly(MOON_TUCK, 0.42, back=230)),
    (0.42, _fly(MOON_OPEN, 0.3, back=262)),
    (0.5, SPLASH, LANDED),
    (1.0, SPLASH, LANDED),
], ground=False)

# flying headbutt: out flat like a missile, arms swept back, head leading
HEAD_LAUNCH = merge(sym({"thigh.L": {"raise": -5, "spread": 4}, "shin.L": {"bend": 15}, "foot.L": {"flex": -35},
                         "upper_arm.L": {"raise": -20, "swing": -60, "twist": 0}, "forearm.L": {"bend": 10}}),
                    {"hips": {"bend": 45}, "spine": {"bend": -5}, "neck": {"bend": -30}, "head": {"bend": -10}})
MISSILE = merge(sym({"thigh.L": {"raise": -10, "spread": 3}, "shin.L": {"bend": 25}, "foot.L": {"flex": -40},
                     "clavicle.L": {"shrug": -5, "reach": -10},
                     "upper_arm.L": {"raise": -40, "swing": -45, "twist": 0}, "forearm.L": {"bend": 5},
                     "fingers.L": {"curl": 10}}),
                {"hips": {"bend": 82}, "spine": {"bend": -8}, "chest": {"bend": -6}, "neck": {"bend": -40},
                 "head": {"bend": -12}})
HEAD_IMPACT = merge(MISSILE, sym({"upper_arm.L": {"raise": 15, "swing": -10}, "thigh.L": {"raise": -18},
                                  "shin.L": {"bend": 35}}),
                    {"hips": {"bend": 102}, "neck": {"bend": -20}, "head": {"bend": 0}})

dive_headbutt = Anim("dive_headbutt", [
    (0.0, PERCH, PERCHED),
    (0.08, _fly(HEAD_LAUNCH, 0.1)),
    (0.18, _fly(MISSILE, 0.25)),
    (0.3, _fly(add(MISSILE, {"hips": {"bend": 6}}), 0.3)),
    (0.42, _fly(merge(MISSILE, {"hips": {"bend": 98}}), 0.28)),
    (0.52, HEAD_IMPACT, LANDED),
    (1.0, HEAD_IMPACT, LANDED),
], ground=False)

ALL = leg_drop.anims() + knee_drop.anims() + [dive_moonsault, dive_headbutt]
