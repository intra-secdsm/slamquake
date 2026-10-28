"""Suplex variations: snap suplex, gutwrench suplex, and from behind the back suplex and atomic drop."""
from ..poses import Paired, at, merge, sym
from .basic import STANCE
from .grapples import D_TIEUP, STIFF, TIEUP
from .reactions import DOWN_BACK

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

PAIRED = [snap_suplex]
ALL = [a for p in PAIRED for a in p.anims()]
