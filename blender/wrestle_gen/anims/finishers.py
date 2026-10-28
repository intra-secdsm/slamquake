"""Finishers (one per roster wrestler), the tie-up reversal and the strike parry.

Finishers start from the tie-up like the other front grapples, so the game can
launch one from a tie-up or straight onto a groggy opponent.
"""
from ..poses import Anim, Paired, at, merge, sym
from .basic import STANCE
from .grapples import D_TIEUP, SLAM_A, STIFF, TIEUP
from .reactions import DOWN_BACK, SIT_UP

# ---------------------------------------------------------------- Thunder Bomb (powerbomb)

BOMB_GRAB_A = merge(sym({"thigh.L": {"raise": 45, "spread": 16}, "shin.L": {"bend": 70}, "foot.L": {"flex": 22},
                         "upper_arm.L": {"raise": -20, "swing": 75, "twist": 0}, "forearm.L": {"bend": 50},
                         "fingers.L": {"curl": 70}}),
                    {"spine": {"bend": 45}, "chest": {"bend": 15}, "neck": {"bend": -25}})
BOMB_BENT_D = merge(STANCE, sym({"thigh.L": {"raise": 70}, "shin.L": {"bend": 15}}),
                    {"hips": {"bend": 75}, "spine": {"bend": 15}, "neck": {"bend": -10},
                             "upper_arm.L": {"raise": -60, "swing": 10}, "upper_arm.R": {"raise": -60, "swing": 10}})
BOMB_LIFT_A = merge(sym({"thigh.L": {"raise": 8, "spread": 14}, "shin.L": {"bend": 14}, "foot.L": {"flex": 6},
                         "upper_arm.L": {"raise": 95, "swing": 55, "twist": 0}, "forearm.L": {"bend": 70},
                         "fingers.L": {"curl": 70}}),
                    {"spine": {"bend": -6}, "chest": {"bend": -8}, "neck": {"bend": -10}})
# sitting on the attacker's shoulders, legs hanging down the attacker's back
BOMB_SIT_D = merge(sym({"thigh.L": {"raise": 95, "spread": 22}, "shin.L": {"bend": 95}, "foot.L": {"flex": 10},
                        "upper_arm.L": {"raise": 70, "swing": -10}, "forearm.L": {"bend": 25}}),
                   {"hips": {"bend": -20}, "spine": {"bend": -10}, "neck": {"bend": 15}, "head": {"bend": 10}})
BOMB_SLAM_A = merge(SLAM_A, sym({"thigh.L": {"raise": 70, "spread": 18}, "shin.L": {"bend": 100}}),
                    {"spine": {"bend": 50}})

thunder_bomb = Paired("thunder_bomb", [
    (0.0, TIEUP, D_TIEUP),
    (0.3, BOMB_GRAB_A, at(BOMB_BENT_D, 0.45, turn=180)),
    (0.6, merge(BOMB_LIFT_A, {"spine": {"bend": 20}}), at(merge(BOMB_SIT_D, {"hips": {"bend": 40}}), 0.3, turn=180),
     {"air_d": 0.55}),
    (0.85, BOMB_LIFT_A, at(BOMB_SIT_D, 0.18, turn=180), {"air_d": 1.15}),
    (1.15, BOMB_LIFT_A, at(merge(BOMB_SIT_D, {"spine": {"bend": -14}}), 0.18, turn=180), {"air_d": 1.22}),
    (1.38, merge(BOMB_SLAM_A, {"spine": {"bend": 25}}), at(merge(STIFF, {"hips": {"bend": -60}}), 0.55, turn=180),
     {"air_d": 0.7}),
    (1.5, BOMB_SLAM_A, at(merge(DOWN_BACK, sym({"thigh.L": {"raise": 80}, "shin.L": {"bend": 30}})), 0.95, turn=180)),
    (2.1, STANCE, at(DOWN_BACK, 0.95, turn=180)),
], events={"impact": 1.5})

# ---------------------------------------------------------------- Volt Shock (jawbreaker drop)

SHOCK_TURN_A = merge(STANCE, {"upper_arm.R": {"raise": 120, "swing": -20, "twist": 0}, "forearm.R": {"bend": 110},
                              "fingers.R": {"curl": 60}, "upper_arm.L": {"raise": 40, "swing": 40},
                              "spine": {"bend": 10}, "neck": {"bend": 10}})
SHOCK_SIT_A = merge(SIT_UP, {"upper_arm.R": {"raise": 120, "swing": -20, "twist": 0}, "forearm.R": {"bend": 110},
                             "neck": {"bend": 15}})
SHOCK_HOOK_D = merge(STANCE, sym({"thigh.L": {"raise": 25}, "shin.L": {"bend": 35}}),
                     {"spine": {"bend": 30}, "chest": {"bend": 10}, "neck": {"bend": -15}})
JOLT_D = merge(STIFF, sym({"upper_arm.L": {"raise": 80, "swing": -10}, "thigh.L": {"raise": 20}, "shin.L": {"bend": 25}}),
               {"hips": {"bend": -35}, "neck": {"bend": -40}, "head": {"bend": -25}})


def _root(pose, fwd=0.0, up=0.0, left=0.0, turn=0.0):
    return merge(pose, {"root": {"move": (left, fwd, up), "turn": turn}})


volt_shock = Paired("volt_shock", [
    (0.0, TIEUP, D_TIEUP),
    (0.22, _root(SHOCK_TURN_A, 0.15, turn=180), at(SHOCK_HOOK_D, 0.62, turn=180), {"air_a": 0.15}),
    (0.4, _root(SHOCK_SIT_A, 0.2, turn=180), at(merge(SHOCK_HOOK_D, {"neck": {"bend": -40}}), 0.55, turn=180)),
    (0.6, _root(SHOCK_SIT_A, 0.2, turn=180), at(JOLT_D, 0.85, turn=180), {"air_d": 0.35}),
    (0.85, _root(merge(DOWN_BACK, {"spine": {"bend": 20}}), 0.2, turn=180),
     at(merge(DOWN_BACK, sym({"thigh.L": {"raise": 55}, "shin.L": {"bend": 40}})), 1.55, turn=180)),
    (1.3, _root(DOWN_BACK, 0.2, turn=180), at(DOWN_BACK, 1.55, turn=180)),
], events={"impact": 0.4})

# ---------------------------------------------------------------- Iron Drop (one-handed chokeslam)

THROAT_A = merge(STANCE, {"upper_arm.R": {"raise": 55, "swing": 85, "twist": 0}, "forearm.R": {"bend": 20},
                          "fingers.R": {"curl": 60}, "chest": {"bend": -4}})
RAISE_A = merge(STANCE, {"upper_arm.R": {"raise": 70, "swing": 85, "twist": 0}, "forearm.R": {"bend": 10},
                         "fingers.R": {"curl": 60}, "upper_arm.L": {"raise": 20, "swing": 40},
                         "chest": {"bend": -12}, "spine": {"bend": -8}, "neck": {"bend": -15}})
CHOKED_D = merge(STIFF, sym({"upper_arm.L": {"raise": 60, "swing": 70}, "forearm.L": {"bend": 80},
                             "thigh.L": {"raise": 15}, "shin.L": {"bend": 30}}),
                 {"neck": {"bend": -25}, "head": {"bend": -20}})
DROP_A = merge(SLAM_A, {"upper_arm.R": {"raise": -10, "swing": 85}, "forearm.R": {"bend": 10}})

iron_drop = Paired("iron_drop", [
    (0.0, TIEUP, D_TIEUP),
    (0.3, THROAT_A, at(CHOKED_D, 0.7, turn=180)),
    (0.55, merge(THROAT_A, {"upper_arm.R": {"raise": 95}}), at(CHOKED_D, 0.65, turn=180), {"air_d": 0.3}),
    (0.85, RAISE_A, at(merge(CHOKED_D, {"hips": {"bend": -5}}), 0.55, turn=180), {"air_d": 0.85}),
    (1.15, RAISE_A, at(merge(CHOKED_D, {"hips": {"bend": -12}}), 0.55, turn=180), {"air_d": 0.9}),
    (1.32, merge(DROP_A, {"spine": {"bend": 25}}), at(merge(STIFF, {"hips": {"bend": -55}}), 0.8, turn=180),
     {"air_d": 0.5}),
    (1.45, DROP_A, at(merge(DOWN_BACK, sym({"thigh.L": {"raise": 60}, "shin.L": {"bend": 25}})), 1.05, turn=180)),
    (2.0, STANCE, at(DOWN_BACK, 1.05, turn=180)),
], events={"impact": 1.45})

# ---------------------------------------------------------------- reversal: hip toss out of the tie-up

HIP_A = merge(sym({"thigh.L": {"raise": 30, "spread": 16}, "shin.L": {"bend": 40}, "foot.L": {"flex": 10}}),
              {"hips": {"turn": 40}, "spine": {"bend": 25, "turn": 20}, "chest": {"turn": 20},
               "upper_arm.R": {"raise": 30, "swing": 70, "twist": 0}, "forearm.R": {"bend": 80},
               "upper_arm.L": {"raise": -20, "swing": 60}, "forearm.L": {"bend": 40}})

hip_toss = Paired("hip_toss", [
    (0.0, TIEUP, D_TIEUP),
    (0.18, HIP_A, at(merge(STIFF, {"hips": {"bend": 30}}), 0.55, left=0.15, turn=180), {"air_d": 0.15}),
    (0.38, merge(HIP_A, {"spine": {"bend": 40}}), at(merge(STIFF, {"hips": {"bend": 150}}), 0.25, left=0.3, turn=180),
     {"air_d": 0.95}),
    (0.6, merge(SLAM_A, {"spine": {"bend": 35}}), at(merge(DOWN_BACK, {"hips": {"bend": 260}}), -0.1, left=0.9,
                                                     turn=180), {"air_d": 0.2}),
    (0.72, SLAM_A, at(DOWN_BACK, -0.2, left=1.1, turn=90)),
    (1.05, STANCE, at(DOWN_BACK, -0.2, left=1.1, turn=90)),
], events={"impact": 0.72})

# ---------------------------------------------------------------- strike parry (timed block)

PARRY_SWEEP = merge(STANCE, {"upper_arm.L": {"raise": 60, "swing": 95, "twist": 0}, "forearm.L": {"bend": 40},
                             "chest": {"turn": -25}, "spine": {"turn": -10}, "head": {"turn": 10}})

parry = Anim("parry", [(0.0, STANCE), (0.08, PARRY_SWEEP), (0.25, PARRY_SWEEP), (0.45, STANCE)])

FINISHERS = [thunder_bomb, volt_shock, iron_drop]
ALL = [a for p in FINISHERS + [hip_toss] for a in p.anims()] + [parry]
