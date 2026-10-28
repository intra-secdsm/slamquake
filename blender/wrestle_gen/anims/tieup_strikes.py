"""Quick tie-up moves: knee lift, knife-edge chop and arm drag.

Paired moves authored in the attacker's frame, starting from the tie-up like the
other front grapples (see grapples.py). Defenders left standing end on the groggy
loop's first frame so the "stun" hand-off doesn't pop.
"""
from ..poses import Paired, at, merge, sym
from .basic import STANCE
from .grapples import D_TIEUP, STIFF, TIEUP
from .reactions import CROUCH, DOWN_BACK, groggy

GROGGY_0 = groggy.keys[0][1]


def _waist(bend, legs=(28, -6)):
    """Bend forward at the waist, raising the thighs so the feet stay put (hips is the root bone)."""
    return {"thigh.L": {"raise": legs[0] + bend * 0.6}, "thigh.R": {"raise": legs[1] + bend * 0.6},
            "hips": {"bend": bend * 0.6}, "spine": {"bend": bend * 0.25}, "chest": {"bend": bend * 0.15}}


# ---------------------------------------------------------------- knee lift

# both hands slide round the back of the defender's head...
CLINCH_A = merge(TIEUP, sym({
    "clavicle.L": {"shrug": 8, "reach": 16},
    "upper_arm.L": {"raise": 39, "swing": 76, "twist": -18}, "forearm.L": {"bend": 69},
    "hand.L": {"bend": 20}, "fingers.L": {"curl": 45},
}), {"spine": {"bend": 12}, "chest": {"bend": 6}})
CLINCH_D = merge(TIEUP, _waist(25), sym({
    "upper_arm.L": {"raise": 8, "swing": 58, "twist": -16}, "forearm.L": {"bend": 46}, "fingers.L": {"curl": 30},
}), {"neck": {"bend": 10}, "head": {"bend": 6}})

# ...yank it down while the right knee cocks back...
YANK_A = merge(CLINCH_A, sym({
    "upper_arm.L": {"raise": 20, "swing": 43, "twist": 1}, "forearm.L": {"bend": 99},
}), {
    "spine": {"bend": 10}, "chest": {"bend": 2},
    "thigh.L": {"raise": 22}, "shin.L": {"bend": 26},
    "thigh.R": {"raise": -6}, "shin.R": {"bend": 72}, "foot.R": {"flex": -20},
})
YANK_D = merge(TIEUP, _waist(62), sym({
    "upper_arm.L": {"raise": 41, "swing": 115, "twist": -32}, "forearm.L": {"bend": 34}, "fingers.L": {"curl": 30},
}), {"neck": {"bend": 8}, "head": {"bend": 6}})

# ...and drive the knee up into the face
KNEE_A = merge(CLINCH_A, sym({
    "upper_arm.L": {"raise": 12, "swing": 42, "twist": 21}, "forearm.L": {"bend": 86},
}), {
    "hips": {"bend": -4, "move": (0, 0.05, 0)}, "spine": {"bend": 6}, "chest": {"bend": 8},
    "thigh.R": {"raise": 96, "spread": -10, "twist": 0}, "shin.R": {"bend": 125}, "foot.R": {"flex": -30},
    "thigh.L": {"raise": -2, "spread": 6}, "shin.L": {"bend": 6}, "foot.L": {"flex": -12},
})
KNEED_D = merge(TIEUP, _waist(70), sym({
    "upper_arm.L": {"raise": 41, "swing": 115, "twist": -32}, "forearm.L": {"bend": 34}, "fingers.L": {"curl": 30},
}), {"neck": {"bend": 5}, "head": {"bend": 0}})

# the head snaps back up and the defender reels away
FOLLOW_A = merge(KNEE_A, sym({
    "upper_arm.L": {"raise": 30, "swing": 60, "twist": 0}, "forearm.L": {"bend": 40}, "fingers.L": {"curl": 15},
}), {"thigh.R": {"raise": 108}, "shin.R": {"bend": 120}, "chest": {"bend": 2}})
LIFTED_D = merge(TIEUP, _waist(34), sym({"fingers.L": {"curl": 20}}), {
    "upper_arm.L": {"raise": 62, "swing": 28, "twist": 0}, "forearm.L": {"bend": 62},
    "upper_arm.R": {"raise": 40, "swing": 46, "twist": 0}, "forearm.R": {"bend": 38},
    "neck": {"bend": -26}, "head": {"bend": -14},
})
SNAP_D = merge(STANCE, sym({"fingers.L": {"curl": 25}}), {
    "upper_arm.L": {"raise": 48, "swing": -6, "twist": 0}, "forearm.L": {"bend": 55},
    "upper_arm.R": {"raise": 30, "swing": 8, "twist": 0}, "forearm.R": {"bend": 40},
    "hips": {"bend": -2}, "spine": {"bend": -4}, "chest": {"bend": -8}, "neck": {"bend": -10}, "head": {"bend": -12},
    "thigh.L": {"raise": 30}, "shin.L": {"bend": 20}, "thigh.R": {"raise": 4}, "shin.R": {"bend": 30},
})
STAGGER_D = merge(GROGGY_0, {
    "upper_arm.R": {"raise": -5, "swing": 70, "twist": 0}, "forearm.R": {"bend": 120}, "hand.R": {"bend": 20},
    "spine": {"bend": 16}, "chest": {"bend": 10}, "head": {"bend": 18, "turn": 10},
    "thigh.L": {"raise": 26}, "shin.L": {"bend": 34},
})
SET_DOWN_A = merge(STANCE, {"thigh.R": {"raise": 34}, "shin.R": {"bend": 52}, "spine": {"bend": 10}})

knee_lift = Paired("knee_lift", [
    (0.0, TIEUP, D_TIEUP),
    (0.16, CLINCH_A, at(CLINCH_D, 0.8, turn=180)),
    (0.3, YANK_A, at(YANK_D, 1.07, turn=180)),
    (0.4, KNEE_A, at(KNEED_D, 1.12, turn=180)),
    (0.45, FOLLOW_A, at(LIFTED_D, 1.12, turn=180)),
    (0.55, merge(FOLLOW_A, {"thigh.R": {"raise": 90}, "shin.R": {"bend": 110}}), at(SNAP_D, 1.14, turn=180)),
    (0.68, SET_DOWN_A, at(STAGGER_D, 1.2, turn=180)),
    (0.9, STANCE, at(GROGGY_0, 1.25, turn=180)),
], events={"impact": 0.4})

# ---------------------------------------------------------------- knife-edge chop

SHOVE_A = merge(STANCE, sym({"upper_arm.L": {"raise": 40, "swing": 85, "twist": 0}, "forearm.L": {"bend": 10},
                             "fingers.L": {"curl": 5}}), {"spine": {"bend": 10}})
# right arm cocked high and back, chest turned away
WINDUP_A = merge(STANCE, {
    "upper_arm.R": {"raise": 110, "swing": -30, "twist": 0}, "forearm.R": {"bend": 40}, "fingers.R": {"curl": 0},
    "upper_arm.L": {"raise": 35, "swing": 70, "twist": 0}, "forearm.L": {"bend": 30},
    "chest": {"turn": -30, "bend": -6}, "spine": {"turn": -12}, "head": {"turn": 15},
})
# open hand slashed across the defender's chest
CHOP_A = merge(STANCE, {
    "upper_arm.R": {"raise": 60, "swing": 95, "twist": 0}, "forearm.R": {"bend": 8}, "fingers.R": {"curl": 0},
    "upper_arm.L": {"raise": -10, "swing": 20}, "forearm.L": {"bend": 60},
    "chest": {"turn": 30, "bend": 8}, "spine": {"turn": 12}, "head": {"turn": -10},
    "thigh.L": {"raise": 35}, "shin.L": {"bend": 30},
})
BRACE_D = merge(STANCE, {"spine": {"bend": -4}, "chest": {"bend": -6}, "head": {"bend": -6}})
# rocked back, both hands clutching the chest
REEL_D = merge(STANCE, sym({"upper_arm.L": {"raise": 10, "swing": 70, "twist": 0}, "forearm.L": {"bend": 130},
                            "hand.L": {"bend": 30}, "fingers.L": {"curl": 30}}),
               {"hips": {"bend": -10}, "spine": {"bend": -12}, "chest": {"bend": -16}, "neck": {"bend": -10},
                "head": {"bend": -20}, "thigh.R": {"raise": 30}, "shin.R": {"bend": 30}})
CLUTCH_D = merge(GROGGY_0, sym({"upper_arm.L": {"raise": 0, "swing": 65, "twist": 0}, "forearm.L": {"bend": 130},
                                "hand.L": {"bend": 30}}), {"chest": {"bend": 18}})

chop = Paired("chop", [
    (0.0, TIEUP, D_TIEUP),
    (0.12, SHOVE_A, at(BRACE_D, 0.95, turn=180)),
    (0.3, WINDUP_A, at(BRACE_D, 1.05, turn=180)),
    (0.42, CHOP_A, at(BRACE_D, 1.0, turn=180)),
    (0.48, CHOP_A, at(REEL_D, 1.1, turn=180)),
    (0.68, merge(CHOP_A, {"upper_arm.R": {"raise": 30}}), at(CLUTCH_D, 1.3, turn=180)),
    (0.9, STANCE, at(GROGGY_0, 1.35, turn=180)),
], events={"impact": 0.44})

# ---------------------------------------------------------------- arm drag

# attacker grabs the defender's right arm with both hands
ARM_HOOK_A = merge(TIEUP, {"upper_arm.L": {"raise": 30, "swing": 75, "twist": 0}, "forearm.L": {"bend": 60},
                           "upper_arm.R": {"raise": 40, "swing": 60, "twist": 0}, "forearm.R": {"bend": 80},
                           "chest": {"turn": -15}})
# dropping to the left knee and turning, dragging the arm down and across
DRAG_A = merge(sym({"thigh.L": {"raise": 90, "spread": 15}, "shin.L": {"bend": 100}, "foot.L": {"flex": 20}}), {
    "thigh.R": {"raise": 5}, "shin.R": {"bend": 110}, "foot.R": {"flex": -30},
    "spine": {"bend": 30, "turn": -30}, "chest": {"turn": -25, "bend": 10},
    "upper_arm.L": {"raise": -20, "swing": 40, "twist": 0}, "forearm.L": {"bend": 50},
    "upper_arm.R": {"raise": 10, "swing": 50, "twist": 0}, "forearm.R": {"bend": 60},
})
ARM_STIFF_D = merge(STIFF, {"upper_arm.R": {"raise": 30, "swing": 80, "twist": 0}, "forearm.R": {"bend": 10}})

arm_drag = Paired("arm_drag", [
    (0.0, TIEUP, D_TIEUP),
    (0.18, ARM_HOOK_A, at(merge(TIEUP, {"upper_arm.R": {"raise": 30, "swing": 70}}), 0.75, turn=180)),
    (0.34, merge(DRAG_A, {"spine": {"bend": 20}}), at(merge(ARM_STIFF_D, {"hips": {"bend": 60}}), 0.55, left=-0.1,
                                                       turn=180), {"air_d": 0.2}),
    (0.48, DRAG_A, at(merge(ARM_STIFF_D, {"hips": {"bend": 160}}), 0.25, left=-0.45, turn=180), {"air_d": 0.95}),
    (0.6, DRAG_A, at(merge(DOWN_BACK, {"hips": {"bend": 240}}), 0.0, left=-0.85, turn=180), {"air_d": 0.35}),
    (0.68, DRAG_A, at(DOWN_BACK, -0.1, left=-1.05, turn=90)),
    (0.85, CROUCH, at(DOWN_BACK, -0.1, left=-1.05, turn=90)),
    (1.05, STANCE, at(DOWN_BACK, -0.1, left=-1.05, turn=90)),
], events={"impact": 0.68})

PAIRED = [knee_lift, chop, arm_drag]
ALL = [a for p in PAIRED for a in p.anims()]
