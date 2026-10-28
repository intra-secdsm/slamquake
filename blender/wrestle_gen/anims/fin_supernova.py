"""Supernova: Nova Reyes's finisher, a fireman's-carry driver.

From the tie-up she ducks under the defender's left arm, drives up with the defender
across the backs of her shoulders (head on her right, legs on her left), stands tall
for a beat, then falls to her right and drives the defender's head and shoulders into
the canvas. Both end on their backs.
"""
from ..poses import Paired, add, at, merge, sym
from .grapples import D_TIEUP, TIEUP
from .reactions import DOWN_BACK


def _root(pose, fwd=0.0, left=0.0, up=0.0, turn=0.0):
    return merge(pose, {"root": {"move": (left, fwd, up), "turn": turn}})


# ---------------------------------------------------------------- duck under, load up

# low and forward, head under the defender's left arm: left arm between their legs,
# right hand reaching up for the arm
DUCK_A = merge(sym({"thigh.L": {"raise": 80, "spread": 18, "twist": 10}, "shin.L": {"bend": 105},
                    "foot.L": {"flex": 26}}), {
    "spine": {"bend": 38}, "chest": {"bend": 14}, "neck": {"bend": -30}, "head": {"bend": -10},
    "upper_arm.L": {"raise": -25, "swing": 70, "twist": 0}, "forearm.L": {"bend": 40}, "fingers.L": {"curl": 60},
    "upper_arm.R": {"raise": 55, "swing": 55, "twist": 0}, "forearm.R": {"bend": 95}, "fingers.R": {"curl": 70},
})
# pulled forward over her back
DRAPE_D = merge(TIEUP, sym({"thigh.L": {"raise": 30}, "shin.L": {"bend": 25}}), {
    "hips": {"bend": 35}, "spine": {"bend": 20}, "chest": {"bend": 10}, "neck": {"bend": 10},
    "upper_arm.L": {"raise": 10, "swing": 40}, "forearm.L": {"bend": 30},
    "upper_arm.R": {"raise": -20, "swing": 50}, "forearm.R": {"bend": 40},
})

# left arm hooked over their thighs, right hand holding their left wrist
HOLD_ARMS = {
    "clavicle.L": {"shrug": 10}, "clavicle.R": {"shrug": 4},
    "upper_arm.L": {"raise": 11, "swing": 24, "twist": -112}, "forearm.L": {"bend": 115}, "fingers.L": {"curl": 75},
    "upper_arm.R": {"raise": -41, "swing": -26, "twist": -13}, "forearm.R": {"bend": 94}, "fingers.R": {"curl": 80},
}
# standing tall under the load: wide base
CARRY_A = merge(sym({"thigh.L": {"raise": 16, "spread": 15, "twist": 8}, "shin.L": {"bend": 24},
                     "foot.L": {"flex": 8}}),
                {"spine": {"bend": 8}, "chest": {"bend": 2}, "neck": {"bend": -2}, "head": {"bend": -8}},
                HOLD_ARMS)
# driving up out of the squat with the load
HEAVE_A = merge(CARRY_A, sym({"thigh.L": {"raise": 68, "spread": 18}, "shin.L": {"bend": 92}, "foot.L": {"flex": 24}}),
                {"spine": {"bend": 30}, "chest": {"bend": 12}, "neck": {"bend": -26}, "head": {"bend": -8}})
RISE_A = merge(CARRY_A, sym({"thigh.L": {"raise": 46, "spread": 17}, "shin.L": {"bend": 66}, "foot.L": {"flex": 18}}),
               {"spine": {"bend": 16}, "chest": {"bend": 6}, "neck": {"bend": -14}})
# dip and load before throwing herself over to the right
DIP_A = merge(CARRY_A, sym({"thigh.L": {"raise": 34}, "shin.L": {"bend": 52}, "foot.L": {"flex": 16}}),
              {"hips": {"lean": 6}, "spine": {"bend": 14}})
# falling to her right: right leg folding under, left leg kicking out
TIP_A = merge(HOLD_ARMS, {
    "hips": {"lean": -40},
    "thigh.R": {"raise": 70, "spread": 10}, "shin.R": {"bend": 100}, "foot.R": {"flex": 10},
    "thigh.L": {"raise": 30, "spread": 35}, "shin.L": {"bend": 25}, "foot.L": {"flex": 0},
    "spine": {"bend": 10, "lean": -8}, "chest": {"bend": 4}, "neck": {"bend": -10, "lean": 10},
})
# landed on her right hip and shoulder
LAND_A = merge(HOLD_ARMS, {
    "hips": {"turn": -90, "bend": -70},
    "thigh.R": {"raise": 60, "spread": 8}, "shin.R": {"bend": 80},
    "thigh.L": {"raise": 45, "spread": 25}, "shin.L": {"bend": 40},
    "spine": {"bend": 10}, "chest": {"bend": 8}, "neck": {"bend": 10},
})
ROLL_A = merge(DOWN_BACK, sym({"thigh.L": {"raise": 45}, "shin.L": {"bend": 60}}),
               {"spine": {"bend": 15}, "head": {"bend": 15}})

# face down across her shoulders, head to her right: limp, limbs hanging
ACROSS_D = merge(sym({"thigh.L": {"raise": 28, "spread": 8}, "shin.L": {"bend": 22}, "foot.L": {"flex": -25},
                      "fingers.L": {"curl": 30}}), {
    "hips": {"bend": 93}, "spine": {"bend": 4}, "chest": {"bend": 6}, "neck": {"bend": 24}, "head": {"bend": 12},
    "upper_arm.L": {"raise": 29, "swing": 90, "twist": 5}, "forearm.L": {"bend": 12},
    "upper_arm.R": {"raise": 26, "swing": 105, "twist": 1}, "forearm.R": {"bend": 12},
})
SWING_D = merge(ACROSS_D, sym({"thigh.L": {"raise": 20}, "shin.L": {"bend": 35}}), {"hips": {"bend": 78}})
# head first: going over, then driven into the canvas, then flopping onto the back
DRIVE_D = merge(ACROSS_D, sym({"upper_arm.L": {"raise": 80, "swing": 20}, "forearm.L": {"bend": 15},
                               "thigh.L": {"raise": 5, "spread": 14}, "shin.L": {"bend": 15}}),
                {"hips": {"bend": 130}, "neck": {"bend": 10}})
SPIKED_D = merge(DRIVE_D, {"hips": {"bend": 160}, "neck": {"bend": 15}, "head": {"bend": 5}, "chest": {"bend": 5}})
FLOP_D = merge(DOWN_BACK, sym({"thigh.L": {"raise": 70}, "shin.L": {"bend": 35}, "upper_arm.L": {"raise": 70}}),
               {"hips": {"bend": 240}})

IN = 0.15             # she steps in to duck under, and works from there

CARRY_D = _root(ACROSS_D, fwd=IN - 0.19, left=0.18, up=0.61, turn=270)

supernova = Paired("supernova", [
    (0.0, TIEUP, D_TIEUP),
    (0.24, _root(DUCK_A, IN), at(DRAPE_D, IN + 0.4, left=0.26, turn=180)),
    (0.37, _root(HEAVE_A, IN), _root(SWING_D, fwd=IN + 0.1, left=0.2, up=0.25, turn=225), {"ground_d": False}),
    (0.55, _root(RISE_A, IN), _root(merge(ACROSS_D, {"hips": {"bend": 100}}), fwd=IN - 0.12, left=0.18, up=0.47,
                                    turn=270), {"ground_d": False}),
    (0.8, _root(CARRY_A, IN), CARRY_D, {"ground_d": False}),
    (1.28, _root(add(CARRY_A, {"chest": {"bend": -3}, "neck": {"bend": -6}}), IN), CARRY_D, {"ground_d": False}),
    (1.4, _root(DIP_A, IN), _root(merge(ACROSS_D, {"hips": {"bend": 86}}), fwd=IN - 0.19, left=0.2, up=0.5, turn=270),
     {"ground_d": False}),
    (1.5, _root(TIP_A, IN, left=-0.1), _root(DRIVE_D, fwd=IN - 0.19, left=-0.65, up=0.3, turn=270), {"ground_d": False}),
    (1.58, _root(LAND_A, IN, left=-0.05, turn=90), at(SPIKED_D, IN - 0.19, left=-0.8, turn=270)),
    (1.78, _root(ROLL_A, IN, left=0.15, turn=90), at(FLOP_D, IN - 0.19, left=-1.6, turn=270)),
    (2.15, _root(DOWN_BACK, IN, left=0.2, turn=90), at(DOWN_BACK, IN - 0.19, left=-1.95, turn=270)),
], events={"impact": 1.58})

ALL = supernova.anims()
