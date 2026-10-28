"""Quick tie-up moves: knee lift, knife-edge chop and arm drag.

Paired moves authored in the attacker's frame, starting from the tie-up like the
other front grapples (see grapples.py). Defenders left standing end on the groggy
loop's first frame so the "stun" hand-off doesn't pop.
"""
from ..poses import Paired, at, merge, sym
from .basic import STANCE
from .grapples import D_TIEUP, TIEUP
from .reactions import groggy

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

PAIRED = [knee_lift]
ALL = [a for p in PAIRED for a in p.anims()]
