"""System Crash: Overclock's finisher, a spinebuster.

From the tie-up the attacker scoops the defender round the waist, hoists them onto his
right shoulder, pivots 180 degrees in two planted steps (the defender's legs fly out),
then drives them down back-first in front of him, dropping to one knee, and rises into a
stiff robotic power pose.
"""
import math

from ..poses import Paired, merge, sym
from .basic import STANCE
from .grapples import D_TIEUP, TIEUP
from .reactions import DOWN_BACK


def _rot(left, fwd, deg):
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return left * c + fwd * s, fwd * c - left * s


def _place(pose, frame, fwd=0.0, left=0.0, turn=0.0, up=0.0):
    """Put a pose's root at (left, fwd, up, turn) relative to frame = (left, fwd, turn) in pair space."""
    fl, ff, ft = frame
    dl, df = _rot(left, fwd, ft)
    yaw = (ft + turn + 180.0) % 360.0 - 180.0
    return merge(pose, {"root": {"move": (fl + dl, ff + df, up), "turn": yaw}})


# ---------------------------------------------------------------- the pivot

BALL = (0.25, 0.15)   # ball of the attacker's left foot (left, fwd) while he turns; the right one mirrors it


def _pivot(theta):
    """Attacker's frame after turning theta degrees to his left: pivoting on the ball of the
    right foot for the first 90 degrees (the left foot drop-steps back), then on the left one."""
    bl, bf = BALL
    if theta <= 90.0:
        dl, df = _rot(bl, -bf, theta)
        return -bl + dl, bf + df, theta
    ml, mf = _rot(bl, -bf, 90.0)
    ll, lf = _rot(bl, bf, 90.0)
    pl, pf = -bl + ml + ll, bf + mf + lf         # left ball, planted after the first quarter
    dl, df = _rot(-bl, -bf, theta)
    return pl + dl, pf + df, theta


SPUN = _pivot(180.0)


def _spun(fwd=0.0):
    """Frame `fwd` metres along the attacker's facing after the spin."""
    fl, ff, ft = SPUN
    dl, df = _rot(0.0, fwd, ft)
    return fl + dl, ff + df, ft


# ---------------------------------------------------------------- attacker

CLINCH_A = merge(sym({"thigh.L": {"raise": 55, "spread": 16, "twist": 10}, "shin.L": {"bend": 85}, "foot.L": {"flex": 25},
                      "fingers.L": {"curl": 70}}),
                 {"spine": {"bend": 35}, "chest": {"bend": 12, "turn": 8}, "neck": {"bend": -25, "lean": 12},
                  "head": {"bend": -10, "lean": 8},
                  "upper_arm.L": {"raise": -5, "swing": 80, "twist": 0}, "forearm.L": {"bend": 80},
                  "upper_arm.R": {"raise": 5, "swing": 65, "twist": 0}, "forearm.R": {"bend": 70}})
HOIST_A = merge(sym({"thigh.L": {"raise": 10, "spread": 6, "twist": 6}, "shin.L": {"bend": 14}, "foot.L": {"flex": 4},
                     "fingers.L": {"curl": 70}}),
                {"spine": {"bend": -8}, "chest": {"bend": -6, "turn": -6}, "neck": {"bend": -5, "lean": 14},
                 "head": {"bend": -5, "lean": 8},
                 "upper_arm.L": {"raise": -18, "swing": 79, "twist": 41}, "forearm.L": {"bend": 32},
                 "upper_arm.R": {"raise": -2, "swing": 61, "twist": 47}, "forearm.R": {"bend": 42}})
STEP_R_A = merge(HOIST_A, {"thigh.R": {"raise": 35}, "shin.R": {"bend": 60}, "foot.R": {"flex": -10}})
STEP_L_A = merge(HOIST_A, {"thigh.L": {"raise": 35}, "shin.L": {"bend": 60}, "foot.L": {"flex": -10}})
LUNGE_A = merge({"thigh.L": {"raise": 60, "spread": 12}, "shin.L": {"bend": 60}, "foot.L": {"flex": 0},
                 "thigh.R": {"raise": 0, "spread": 10}, "shin.R": {"bend": 60}, "foot.R": {"flex": -20},
                 "spine": {"bend": 25}, "chest": {"bend": 10}, "neck": {"bend": -15},
                 "upper_arm.L": {"raise": -10, "swing": 80, "twist": 30}, "forearm.L": {"bend": 40},
                 "upper_arm.R": {"raise": -10, "swing": 70, "twist": 30}, "forearm.R": {"bend": 40}},
                sym({"fingers.L": {"curl": 70}}))
KNEEL_A = merge({"thigh.L": {"raise": 85, "spread": 14}, "shin.L": {"bend": 85}, "foot.L": {"flex": 5},
                 "thigh.R": {"raise": -5, "spread": 10}, "shin.R": {"bend": 95}, "foot.R": {"flex": -40},
                 "spine": {"bend": 40}, "chest": {"bend": 20}, "neck": {"bend": -25},
                 "upper_arm.L": {"raise": -20, "swing": 80, "twist": 0}, "forearm.L": {"bend": 40},
                 "upper_arm.R": {"raise": -20, "swing": 80, "twist": 0}, "forearm.R": {"bend": 40}},
                sym({"fingers.L": {"curl": 70}}))
RISE_A = merge(STANCE, {"thigh.L": {"raise": 45}, "shin.L": {"bend": 55}, "thigh.R": {"raise": 5}, "shin.R": {"bend": 30},
                        "spine": {"bend": 20}, "chest": {"bend": 8}})
POWER_A = merge(STANCE, sym({"thigh.L": {"raise": 12, "spread": 14}, "shin.L": {"bend": 16},
                             "clavicle.L": {"shrug": 12, "reach": 0},
                             "upper_arm.L": {"raise": 40, "swing": 0, "twist": -70}, "forearm.L": {"bend": 90},
                             "hand.L": {"bend": 0}, "fingers.L": {"curl": 100}}),
                {"spine": {"bend": -4}, "chest": {"bend": -10}, "neck": {"bend": 0}, "head": {"bend": 8, "turn": 25}})

# ---------------------------------------------------------------- defender

HOLD = dict(fwd=0.3, left=-0.17, turn=180.0, up=0.5)   # defender's root, held on the attacker's right shoulder

CLINCH_D = merge(TIEUP, {"hips": {"bend": 10}, "spine": {"bend": 25}, "chest": {"bend": 15}, "neck": {"bend": 10},
                         "thigh.L": {"raise": 30}, "thigh.R": {"raise": 0}})
DRAPED_D = merge(sym({"thigh.L": {"raise": 45, "spread": 8}, "shin.L": {"bend": 45}, "foot.L": {"flex": -25},
                      "upper_arm.L": {"raise": -20, "swing": 120, "twist": 0}, "forearm.L": {"bend": 20},
                      "fingers.L": {"curl": 30}}),
                 {"hips": {"bend": 45}, "spine": {"bend": 25}, "chest": {"bend": 30}, "neck": {"bend": 20},
                  "head": {"bend": 10}})
WHIP_D = merge(DRAPED_D, {"thigh.L": {"raise": -10, "spread": 25}, "thigh.R": {"raise": -15, "spread": 0},
                          "shin.L": {"bend": 20}, "shin.R": {"bend": 25}})
DRIVE_D = merge(DOWN_BACK, sym({"thigh.L": {"raise": 60, "spread": 35}, "shin.L": {"bend": 50},
                                "upper_arm.L": {"raise": 60, "swing": 30}}),
                {"hips": {"bend": -30}, "spine": {"bend": 10}, "neck": {"bend": 15}})
SLAMMED_D = merge(DOWN_BACK, sym({"thigh.L": {"raise": 100, "spread": 38}, "shin.L": {"bend": 70},
                                  "upper_arm.L": {"raise": 70, "swing": 10}}))


def _held(theta, a_pose, d_pose):
    frame = _pivot(theta)
    return _place(a_pose, frame), _place(d_pose, frame, **HOLD), {"ground_d": False}


LAND = 1.15           # defender's root ahead of the attacker's final spot


system_crash = Paired("system_crash", [
    (0.0, TIEUP, D_TIEUP),
    (0.2, CLINCH_A, _place(CLINCH_D, (0, 0, 0), 0.55, -0.1, 180.0)),
    (0.52, *_held(0.0, HOIST_A, DRAPED_D)),
    (0.64, *_held(45.0, STEP_L_A, WHIP_D)),
    (0.75, *_held(90.0, HOIST_A, WHIP_D)),
    (0.86, *_held(135.0, STEP_R_A, WHIP_D)),
    (0.97, *_held(180.0, HOIST_A, WHIP_D)),
    (1.15, _place(LUNGE_A, _spun(0.15)), _place(DRIVE_D, _spun(0.15), 0.5, -0.1, 180.0, 0.0), {"ground_d": False}),
    (1.27, _place(KNEEL_A, _spun(0.3)), _place(SLAMMED_D, _spun(-0.1), LAND, 0.0, 180.0)),
    (1.45, _place(KNEEL_A, _spun(0.3)), _place(DOWN_BACK, _spun(-0.1), LAND, 0.0, 180.0)),
    (1.56, _place(RISE_A, _spun(0.1)), _place(DOWN_BACK, _spun(-0.1), LAND, 0.0, 180.0)),
    (1.68, _place(POWER_A, _spun(-0.1)), _place(DOWN_BACK, _spun(-0.1), LAND, 0.0, 180.0)),
    (1.85, _place(POWER_A, _spun(-0.1)), _place(DOWN_BACK, _spun(-0.1), LAND, 0.0, 180.0)),
    (1.98, _place(STANCE, _spun(-0.1)), _place(DOWN_BACK, _spun(-0.1), LAND, 0.0, 180.0)),
], events={"impact": 1.27})

ALL = system_crash.anims()
