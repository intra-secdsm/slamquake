"""Tie-up power moves: neckbreaker, powerslam and piledriver.

Paired moves authored in the attacker's frame, starting from the tie-up (see grapples.py).
"""
from ..poses import Paired, at, merge, sym
from .basic import STANCE
from .grapples import D_TIEUP, SCOOP_A, SCOOP_D, STIFF, TIEUP
from .reactions import CROUCH, DOWN_BACK, SIT_UP

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

# ---------------------------------------------------------------- neckbreaker

# the attacker steps round beside the defender (facing the same way), head trapped under the left arm
NB_FACELOCK_D = merge(STANCE, sym({"thigh.L": {"raise": 60, "spread": 8}, "shin.L": {"bend": 30}}),
                      {"hips": {"bend": 45}, "spine": {"bend": 15}, "chest": {"bend": 8}, "neck": {"bend": -15},
                       "upper_arm.L": {"raise": -40, "swing": 30}, "upper_arm.R": {"raise": -40, "swing": 30}})
NB_LOCK_A = merge(STANCE, {"upper_arm.L": {"raise": 15, "swing": 70, "twist": 30}, "forearm.L": {"bend": 120},
                           "upper_arm.R": {"raise": 20, "swing": 50, "twist": 0}, "forearm.R": {"bend": 70},
                           "spine": {"bend": 15, "lean": 8}, "chest": {"bend": 5}})
NB_DROP_A = merge(SIT_UP, {"upper_arm.L": {"raise": 25, "swing": 60, "twist": 30}, "forearm.L": {"bend": 120},
                           "hips": {"bend": -55}})
NB_SNAP_D = merge(STIFF, sym({"upper_arm.L": {"raise": 40, "swing": -10}}),
                  {"hips": {"bend": -55}, "neck": {"bend": 20}, "head": {"bend": 10}})
NB_LAND_D = merge(DOWN_BACK, sym({"thigh.L": {"raise": 40}, "shin.L": {"bend": 35}, "upper_arm.L": {"raise": 60}}),
                  {"head": {"bend": 25}})
NB_SIDE = 0.42

neckbreaker = Paired("neckbreaker", [
    (0.0, TIEUP, D_TIEUP),
    (0.22, at(NB_LOCK_A, 0.3, left=NB_SIDE * 0.7, turn=-90), at(NB_FACELOCK_D, 0.8, turn=180)),
    (0.4, at(NB_LOCK_A, 0.32, left=NB_SIDE, turn=180), at(NB_FACELOCK_D, 0.8, turn=180)),
    (0.6, at(merge(NB_DROP_A, {"hips": {"bend": -35}}), 0.38, left=NB_SIDE, turn=180),
     at(NB_SNAP_D, 0.85, turn=180), {"air_d": 0.35}),
    (0.72, at(NB_DROP_A, 0.45, left=NB_SIDE, turn=180), at(NB_LAND_D, 1.05, turn=180)),
    (0.9, at(merge(DOWN_BACK, {"hips": {"bend": -70}}), 0.5, left=NB_SIDE, turn=180), at(DOWN_BACK, 1.05, turn=180)),
    (1.15, at(DOWN_BACK, 0.5, left=NB_SIDE, turn=180), at(DOWN_BACK, 1.05, turn=180)),
], events={"impact": 0.72})

# ---------------------------------------------------------------- piledriver

PD_BENT_D = merge(STANCE, sym({"thigh.L": {"raise": 85, "spread": 6}, "shin.L": {"bend": 20}, "foot.L": {"flex": 14},
                               "upper_arm.L": {"raise": -50, "swing": 20}}),
                  {"hips": {"bend": 85}, "spine": {"bend": 20}, "chest": {"bend": 10}, "neck": {"bend": -5}})
PD_GRAB_A = merge(sym({"thigh.L": {"raise": 30, "spread": 18}, "shin.L": {"bend": 40}, "foot.L": {"flex": 12},
                       "upper_arm.L": {"raise": -10, "swing": 85, "twist": 0}, "forearm.L": {"bend": 100},
                       "fingers.L": {"curl": 80}}),
                  {"spine": {"bend": 45}, "chest": {"bend": 15}, "neck": {"bend": -25}})
PD_LIFT_A = merge(sym({"thigh.L": {"raise": 10, "spread": 16}, "shin.L": {"bend": 18}, "foot.L": {"flex": 6},
                       "upper_arm.L": {"raise": 0, "swing": 75, "twist": 0}, "forearm.L": {"bend": 105},
                       "fingers.L": {"curl": 80}}),
                  {"spine": {"bend": -6}, "chest": {"bend": -8}, "neck": {"bend": -15}})
# upside down, legs straight up, head between the attacker's knees
PD_INVERTED_D = merge(STIFF, sym({"thigh.L": {"raise": 10, "spread": 6}, "upper_arm.L": {"raise": -10, "swing": 20}}),
                      {"hips": {"bend": 178}})
# sitting out on the canvas, legs spread either side of the defender's head
PD_SIT_A = merge(sym({"thigh.L": {"raise": 85, "spread": 34, "twist": 10}, "shin.L": {"bend": 15}, "foot.L": {"flex": 10},
                      "upper_arm.L": {"raise": 0, "swing": 70, "twist": 0}, "forearm.L": {"bend": 100},
                      "fingers.L": {"curl": 80}}),
                 {"hips": {"bend": -5}, "spine": {"bend": 12}, "chest": {"bend": 5}, "neck": {"bend": -10}})

piledriver = Paired("piledriver", [
    (0.0, TIEUP, D_TIEUP),
    (0.3, PD_GRAB_A, at(PD_BENT_D, 0.48, turn=180)),
    (0.55, merge(PD_GRAB_A, sym({"thigh.L": {"raise": 50}, "shin.L": {"bend": 70}})),
     at(merge(PD_BENT_D, {"hips": {"bend": 110}}), 0.42, turn=180), {"air_d": 0.15}),
    (0.8, PD_LIFT_A, at(PD_INVERTED_D, 0.3, turn=180), {"air_d": 0.55}),
    (1.05, PD_LIFT_A, at(PD_INVERTED_D, 0.3, turn=180), {"air_d": 0.6}),
    (1.2, PD_SIT_A, at(PD_INVERTED_D, 0.38, turn=180), {"air_d": 0.0}),
    (1.38, PD_SIT_A, at(merge(STIFF, {"hips": {"bend": 140}, "neck": {"bend": 30}}), 0.6, turn=180)),
    (1.6, SIT_UP, at(merge(DOWN_BACK, {"hips": {"bend": -110}}), 1.15, turn=0)),
    (1.75, CROUCH, at(DOWN_BACK, 1.15, turn=0)),
    (2.0, STANCE, at(DOWN_BACK, 1.15, turn=0)),
], events={"impact": 1.2})

ALL = powerslam.anims() + neckbreaker.anims() + piledriver.anims()
