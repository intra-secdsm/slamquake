"""Tie-up power moves: neckbreaker, powerslam and piledriver.

Paired moves authored in the attacker's frame, starting from the tie-up (see grapples.py).
"""
from ..poses import Paired, at, merge, sym
from .basic import STANCE
from .grapples import D_TIEUP, SCOOP_A, SCOOP_D, TIEUP
from .reactions import CROUCH, DOWN_BACK

# ---------------------------------------------------------------- powerslam

# scooped: the defender leans over the attacker's left shoulder, legs hooked by the right arm
PS_SCOOP_D = merge(SCOOP_D, {"spine": {"lean": -16}, "chest": {"lean": -12}})
# tipped sideways on the way up: head toward the attacker's left, legs swinging up on the right
PS_TIP_D = merge(DOWN_BACK, sym({"thigh.L": {"raise": 35, "spread": 8}, "shin.L": {"bend": 45},
                                 "upper_arm.L": {"raise": 20, "swing": 30}, "forearm.L": {"bend": 30}}),
                 {"hips": {"bend": 10, "lean": -60}, "spine": {"bend": 15}, "head": {"bend": 10}})
# carried across the chest, face up: head on the attacker's left, legs on the right
PS_CARRY_D = merge(DOWN_BACK, sym({"thigh.L": {"raise": 28, "spread": 8}, "shin.L": {"bend": 40},
                                   "upper_arm.L": {"raise": 0, "swing": 20}, "forearm.L": {"bend": 30}}),
                   {"spine": {"bend": 8}, "head": {"bend": 15, "turn": 0}})
PS_CARRY_A = merge(sym({"thigh.L": {"raise": 12, "spread": 10}, "shin.L": {"bend": 18}, "foot.L": {"flex": 6},
                        "upper_arm.L": {"raise": -5, "swing": 62, "twist": 60}, "forearm.L": {"bend": 100},
                        "fingers.L": {"curl": 70}}),
                   {"spine": {"bend": -8}, "chest": {"bend": -8}, "neck": {"bend": -4}})
PS_STEP_A = merge(PS_CARRY_A, {"thigh.L": {"raise": 38}, "shin.L": {"bend": 22}, "foot.L": {"flex": 10},
                               "thigh.R": {"raise": -14}, "shin.R": {"bend": 14}, "foot.R": {"flex": 20},
                               "spine": {"bend": 6}, "chest": {"bend": 2}})
# falling forward on top of the defender, legs stretched out behind
PS_PRESS_A = merge(sym({"thigh.L": {"raise": -4, "spread": 9}, "shin.L": {"bend": 12}, "foot.L": {"flex": -40},
                        "upper_arm.L": {"raise": 10, "swing": 70, "twist": 0}, "forearm.L": {"bend": 70},
                        "fingers.L": {"curl": 70}}),
                   {"hips": {"bend": 78}, "spine": {"bend": 4}, "chest": {"bend": 2}, "neck": {"bend": -30},
                    "head": {"bend": -10}})
# pushing up off the defender's chest onto the knees
PS_PUSH_A = merge(sym({"thigh.L": {"raise": 25, "spread": 12}, "shin.L": {"bend": 115}, "foot.L": {"flex": -30},
                       "upper_arm.L": {"raise": -10, "swing": 70, "twist": 0}, "forearm.L": {"bend": 15},
                       "fingers.L": {"curl": 10}}),
                  {"hips": {"bend": 25}, "spine": {"bend": 25}, "chest": {"bend": 10}, "neck": {"bend": -25}})
PS_SLAMMED_D = merge(DOWN_BACK, sym({"thigh.L": {"raise": 45}, "shin.L": {"bend": 50},
                                     "upper_arm.L": {"raise": 55, "swing": 10}}), {"head": {"bend": 25}})

PS_LAND = 0.98
powerslam = Paired("powerslam", [
    (0.0, TIEUP, D_TIEUP),
    (0.28, SCOOP_A, at(PS_SCOOP_D, 0.6, turn=180)),
    (0.42, merge(SCOOP_A, sym({"thigh.L": {"raise": 30}, "shin.L": {"bend": 45}}), {"spine": {"bend": 15}}),
     at(PS_TIP_D, 0.5, left=0.05, turn=180), {"air_d": 0.5}),
    (0.58, PS_CARRY_A, at(PS_CARRY_D, 0.4, left=-0.12, turn=-90), {"air_d": 1.0}),
    (0.78, at(PS_STEP_A, 0.3), at(PS_CARRY_D, 0.7, left=-0.12, turn=-90), {"air_d": 0.98}),
    (0.9, at(merge(PS_PRESS_A, {"hips": {"bend": 45}, "thigh.L": {"raise": 30}, "shin.L": {"bend": 30}}), 0.42),
     at(PS_CARRY_D, 0.85, left=-0.12, turn=-90), {"air_d": 0.45}),
    (PS_LAND, at(PS_PRESS_A, 0.5), at(PS_SLAMMED_D, 0.95, left=-0.12, turn=-90), {"air_a": 0.2}),
    (1.15, at(PS_PUSH_A, 0.42), at(DOWN_BACK, 0.95, left=-0.12, turn=-90)),
    (1.32, at(CROUCH, 0.36), at(DOWN_BACK, 0.95, left=-0.12, turn=-90)),
    (1.5, at(STANCE, 0.36), at(DOWN_BACK, 0.95, left=-0.12, turn=-90)),
], events={"impact": PS_LAND})

ALL = powerslam.anims()
