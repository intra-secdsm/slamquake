"""Suplex variations: snap suplex, gutwrench suplex, and from behind the back suplex and atomic drop."""
from ..poses import Paired, at, merge, sym
from .basic import STANCE
from .grapples import D_TIEUP, STIFF, TIEUP
from .reactions import DOWN_BACK, GROGGY

# ---------------------------------------------------------------- snap suplex: up and straight over, no hang

# defender bent over, head tucked under the attacker's left arm, right arm over the attacker's shoulder
SNAP_HOOK_D = merge(STANCE, sym({"thigh.L": {"raise": 70, "spread": 8}, "shin.L": {"bend": 36}, "foot.L": {"flex": 14}}), {
    "hips": {"bend": 50}, "spine": {"bend": 18}, "chest": {"bend": 10}, "neck": {"bend": -10}, "head": {"bend": -12},
    "upper_arm.R": {"raise": 35, "swing": 80, "twist": 0}, "forearm.R": {"bend": 45}, "fingers.R": {"curl": 40},
    "upper_arm.L": {"raise": -30, "swing": 35, "twist": 0}, "forearm.L": {"bend": 30}, "fingers.L": {"curl": 30},
})
# left arm wrapped round the defender's neck, right hand on their back
SNAP_HOOK_A = merge(TIEUP, {"spine": {"bend": 8},
                            "upper_arm.L": {"raise": 31, "swing": 85, "twist": 100}, "forearm.L": {"bend": 94},
                            "upper_arm.R": {"raise": -9, "swing": 90, "twist": 30}, "forearm.R": {"bend": 22}})
SNAP_DIP_A = merge(SNAP_HOOK_A, sym({"thigh.L": {"raise": 48, "spread": 12}, "shin.L": {"bend": 70}, "foot.L": {"flex": 22}}),
                   {"spine": {"bend": 4}, "chest": {"bend": 0},
                    "upper_arm.L": {"raise": 25, "swing": 98, "twist": 110}, "forearm.L": {"bend": 105},
                    "upper_arm.R": {"raise": -19, "swing": 85, "twist": 10}, "forearm.R": {"bend": 24}})
SNAP_LIFT_A = merge(SNAP_HOOK_A, sym({"thigh.L": {"raise": 22, "spread": 12}, "shin.L": {"bend": 26}, "foot.L": {"flex": 8}}),
                    {"hips": {"bend": -18}, "spine": {"bend": -12}, "chest": {"bend": -10}, "neck": {"bend": -12},
                     "upper_arm.L": {"raise": 27, "swing": 80, "twist": 100}, "forearm.L": {"bend": 97},
                     "upper_arm.R": {"raise": -30, "swing": 86, "twist": 40}, "forearm.R": {"bend": 5}})
SNAP_FALL_A = merge(DOWN_BACK, {"hips": {"bend": -55}, "spine": {"bend": 8}, "neck": {"bend": 15}},
                    sym({"thigh.L": {"raise": 55}, "shin.L": {"bend": 70}, "foot.L": {"flex": 10},
                         "upper_arm.L": {"raise": 150, "swing": -10, "twist": 0}, "forearm.L": {"bend": 35}}))
SNAP_LAND_A = merge(DOWN_BACK, sym({"thigh.L": {"raise": 35}, "shin.L": {"bend": 45},
                                    "upper_arm.L": {"raise": 140, "swing": 30, "twist": 0}, "forearm.L": {"bend": 40}}))
# thrown defender: body straight, arms tucked in until they slap the mat
TUCKED = merge(STIFF, sym({"upper_arm.L": {"raise": -15, "swing": 45, "twist": 0}, "forearm.L": {"bend": 95},
                           "fingers.L": {"curl": 60}}))
SLAP_D = merge(DOWN_BACK, sym({"upper_arm.L": {"raise": 55, "swing": 0}, "forearm.L": {"bend": 10},
                               "thigh.L": {"raise": 30}, "shin.L": {"bend": 20}}))

snap_suplex = Paired("snap_suplex", [
    (0.0, TIEUP, D_TIEUP),
    (0.18, SNAP_HOOK_A, at(SNAP_HOOK_D, 0.92, left=0.22, turn=180)),
    (0.3, SNAP_DIP_A, at(merge(SNAP_HOOK_D, {"hips": {"bend": 58}}), 0.88, left=0.22, turn=180)),
    (0.42, SNAP_LIFT_A, at(merge(TUCKED, {"hips": {"bend": 125}}), 0.66, left=0.24, turn=180), {"air_d": 1.0}),
    (0.52, SNAP_FALL_A, at(merge(TUCKED, {"hips": {"bend": 210}}), -0.95, left=0.24, turn=180), {"air_d": 0.85}),
    (0.62, SNAP_LAND_A, at(merge(SLAP_D, {"hips": {"bend": 270}}), -1.85, left=0.24, turn=180)),
    (1.05, DOWN_BACK, at(DOWN_BACK, -1.85, left=0.24, turn=180)),
], events={"impact": 0.62})

# ---------------------------------------------------------------- gutwrench suplex

# defender doubled over in front, the attacker draped over their back, arms locked round the waist
GUT_BENT_D = merge(STANCE, sym({"thigh.L": {"raise": 80, "spread": 8}, "shin.L": {"bend": 30}, "foot.L": {"flex": 14},
                                "upper_arm.L": {"raise": -40, "swing": 30, "twist": 0}, "forearm.L": {"bend": 30}}),
                   {"hips": {"bend": 70}, "spine": {"bend": 20}, "chest": {"bend": 10}, "neck": {"bend": -10}})
GUT_LOCK_A = merge(sym({"thigh.L": {"raise": 40, "spread": 14}, "shin.L": {"bend": 55}, "foot.L": {"flex": 18},
                        "upper_arm.L": {"raise": 10, "swing": 85, "twist": 0}, "forearm.L": {"bend": 110},
                        "fingers.L": {"curl": 80}}),
                   {"spine": {"bend": 55}, "chest": {"bend": 15}, "neck": {"bend": -25}})
# deadlift: upright, the defender horizontal and face down across the chest
GUT_LIFT_A = merge(sym({"thigh.L": {"raise": 8, "spread": 12}, "shin.L": {"bend": 14}, "foot.L": {"flex": 6},
                        "upper_arm.L": {"raise": 20, "swing": 70, "twist": 0}, "forearm.L": {"bend": 95},
                        "fingers.L": {"curl": 80}}),
                   {"spine": {"bend": -14}, "chest": {"bend": -10}, "neck": {"bend": -12}})
GUT_HELD_D = merge(STIFF, sym({"upper_arm.L": {"raise": -10, "swing": 40}, "thigh.L": {"raise": 10}}),
                   {"hips": {"bend": 95}, "neck": {"bend": -20}})

gutwrench = Paired("gutwrench", [
    (0.0, TIEUP, D_TIEUP),
    (0.3, GUT_LOCK_A, at(GUT_BENT_D, 0.62, turn=180)),
    (0.5, merge(GUT_LOCK_A, sym({"thigh.L": {"raise": 55}, "shin.L": {"bend": 75}})), at(GUT_BENT_D, 0.6, turn=180)),
    (0.75, GUT_LIFT_A, at(GUT_HELD_D, 0.42, turn=180), {"air_d": 1.15}),
    (0.95, merge(GUT_LIFT_A, {"spine": {"bend": -20}}), at(merge(GUT_HELD_D, {"hips": {"bend": 120}}), 0.35, turn=180),
     {"air_d": 1.25}),
    (1.12, merge(DOWN_BACK, {"hips": {"bend": -50}}, sym({"thigh.L": {"raise": 45}, "shin.L": {"bend": 55},
                                                                     "upper_arm.L": {"raise": 90, "swing": 20}})),
     at(merge(TUCKED, {"hips": {"bend": 200}}), -0.6, turn=180), {"air_d": 0.8}),
    (1.25, DOWN_BACK, at(merge(SLAP_D, {"hips": {"bend": 270}}), -1.75, turn=180)),
    (1.55, DOWN_BACK, at(DOWN_BACK, -1.75, turn=180)),
], events={"impact": 1.25})

# ---------------------------------------------------------------- from behind: back suplex

WAIST_A = merge(STANCE, sym({"upper_arm.L": {"raise": -10, "swing": 65, "twist": -20}, "forearm.L": {"bend": 90},
                             "fingers.L": {"curl": 70}}), {"spine": {"bend": 12}, "head": {"bend": -5}})
DIP_A = merge(WAIST_A, sym({"thigh.L": {"raise": 50, "spread": 14}, "shin.L": {"bend": 75}, "foot.L": {"flex": 22}}),
              {"spine": {"bend": 25}})
HOIST_A = merge(WAIST_A, sym({"thigh.L": {"raise": 6, "spread": 12}, "shin.L": {"bend": 10}}),
                {"spine": {"bend": -18}, "chest": {"bend": -14}, "neck": {"bend": -10}})
BACK_FALL_A = merge(DOWN_BACK, {"hips": {"bend": -40}}, sym({"thigh.L": {"raise": 35}, "shin.L": {"bend": 40},
                                                             "upper_arm.L": {"raise": 60, "swing": 40}}))

back_suplex = Paired("back_suplex", [
    (0.0, WAIST_A, at(GROGGY, 0.45)),
    (0.25, DIP_A, at(GROGGY, 0.42)),
    (0.5, HOIST_A, at(merge(STIFF, {"hips": {"bend": -10}}), 0.3), {"air_d": 0.9}),
    (0.7, merge(HOIST_A, {"spine": {"bend": -28}}), at(merge(STIFF, {"hips": {"bend": -40}}), 0.25), {"air_d": 1.05}),
    (0.88, BACK_FALL_A, at(merge(TUCKED, {"hips": {"bend": -75}}), -0.75, left=0.15), {"air_d": 0.95}),
    (1.0, DOWN_BACK, at(SLAP_D, -1.3, left=0.25)),
    (1.4, DOWN_BACK, at(DOWN_BACK, -1.3, left=0.25)),
], events={"impact": 1.0})

# ---------------------------------------------------------------- from behind: atomic drop

# scooped up in a seated position, then dropped tailbone-first on the raised knee
SEATED_D = merge(STIFF, sym({"thigh.L": {"raise": 75, "spread": 10}, "shin.L": {"bend": 60},
                             "upper_arm.L": {"raise": 30, "swing": 20}, "forearm.L": {"bend": 30}}),
                 {"hips": {"bend": 0}, "spine": {"bend": 8}})
CRADLE_A = merge(STANCE, sym({"upper_arm.L": {"raise": 0, "swing": 70, "twist": 0}, "forearm.L": {"bend": 80},
                              "fingers.L": {"curl": 70}}),
                 {"spine": {"bend": -6}, "chest": {"bend": -6}})
KNEE_UP_A = merge(CRADLE_A, {"thigh.R": {"raise": 80}, "shin.R": {"bend": 90}, "foot.R": {"flex": 10},
                             "thigh.L": {"raise": 10}, "shin.L": {"bend": 25}, "spine": {"bend": 12}})
# hopping away, both hands on the backside
OUCH_D = merge(STANCE, sym({"upper_arm.L": {"raise": -40, "swing": -40, "twist": 0}, "forearm.L": {"bend": 70},
                            "hand.L": {"bend": 30}}),
               {"hips": {"bend": -15}, "spine": {"bend": -10}, "chest": {"bend": -12}, "neck": {"bend": -20},
                "head": {"bend": -20}, "thigh.L": {"raise": 45}, "shin.L": {"bend": 60}})

atomic_drop = Paired("atomic_drop", [
    (0.0, WAIST_A, at(GROGGY, 0.45)),
    (0.25, DIP_A, at(GROGGY, 0.42)),
    (0.5, CRADLE_A, at(SEATED_D, 0.35), {"air_d": 0.75}),
    (0.66, CRADLE_A, at(SEATED_D, 0.35), {"air_d": 0.82}),
    (0.78, KNEE_UP_A, at(merge(SEATED_D, {"neck": {"bend": -30}, "head": {"bend": -20}}), 0.38), {"air_d": 0.42}),
    (0.92, merge(KNEE_UP_A, {"thigh.R": {"raise": 60}}), at(OUCH_D, 0.7), {"air_d": 0.25}),
    (1.1, STANCE, at(merge(OUCH_D, {"thigh.L": {"raise": 10}, "thigh.R": {"raise": 45}, "shin.R": {"bend": 60}}), 1.05),
     {"air_d": 0.08}),
    (1.3, STANCE, at(GROGGY, 1.2)),
], events={"impact": 0.8})

PAIRED = [snap_suplex, gutwrench, back_suplex, atomic_drop]
ALL = [a for p in PAIRED for a in p.anims()]
