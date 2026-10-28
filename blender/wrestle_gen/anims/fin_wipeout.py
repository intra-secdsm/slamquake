"""Wipeout: Kai Breakwater's finisher, a spear.

Out of the tie-up Kai shoves the opponent away, sinks into a coiled crouch, then
launches low across the ring, drives a shoulder into the midsection with both arms
round the waist and rides them down to the canvas. He pops back up and roars.
"""
from ..poses import Paired, at, merge, sym
from .basic import STANCE
from .grapples import D_TIEUP, TIEUP
from .reactions import DOWN_BACK, GROGGY

# ---------------------------------------------------------------- shove and stumble

SHOVE_A = merge(STANCE, sym({
    "clavicle.L": {"reach": 22, "shrug": 4},
    "upper_arm.L": {"raise": 34, "swing": 84, "twist": 0}, "forearm.L": {"bend": 14},
    "hand.L": {"bend": -40}, "fingers.L": {"curl": 10},
}), {
    "thigh.L": {"raise": 48, "spread": 6}, "shin.L": {"bend": 52}, "foot.L": {"flex": 12},
    "thigh.R": {"raise": -18, "spread": 6}, "shin.R": {"bend": 14}, "foot.R": {"flex": 28},
    "spine": {"bend": 16}, "chest": {"bend": 6}, "neck": {"bend": -12}, "head": {"bend": -6},
})
SHOVED_D = merge(STANCE, sym({
    "upper_arm.L": {"raise": 50, "swing": 40, "twist": 0}, "forearm.L": {"bend": 40}, "fingers.L": {"curl": 30},
}), {
    "hips": {"bend": -10}, "spine": {"bend": -12}, "chest": {"bend": -10}, "neck": {"bend": 22}, "head": {"bend": 12},
    "thigh.L": {"raise": 22}, "shin.L": {"bend": 25},
    "thigh.R": {"raise": -24}, "shin.R": {"bend": 30}, "foot.R": {"flex": 20},
})
# backpedalling, arms windmilling for balance
STUMBLE_D = merge(STANCE, {
    "upper_arm.L": {"raise": 75, "swing": 40, "twist": 0}, "forearm.L": {"bend": 35}, "fingers.L": {"curl": 25},
    "upper_arm.R": {"raise": 45, "swing": -30, "twist": 0}, "forearm.R": {"bend": 25}, "fingers.R": {"curl": 25},
    "hips": {"bend": -6, "lean": -4}, "spine": {"bend": -6}, "chest": {"bend": -2, "turn": 10}, "neck": {"bend": 12},
    "head": {"bend": 12, "turn": -10},
    "thigh.L": {"raise": -22}, "shin.L": {"bend": 38}, "foot.L": {"flex": 18},
    "thigh.R": {"raise": 30}, "shin.R": {"bend": 28},
})
DAZED_D = merge(GROGGY, {"hips": {"lean": 5}, "head": {"lean": -10, "bend": 26}})

# ---------------------------------------------------------------- the spear

# three-point stance: right hand on the canvas, left fist cocked, eyes on the target
COIL_A = {
    "hips": {"bend": 62}, "spine": {"bend": 14}, "chest": {"bend": 8}, "neck": {"bend": -42}, "head": {"bend": -28},
    "thigh.L": {"raise": 132, "spread": 12}, "shin.L": {"bend": 103}, "foot.L": {"flex": 30},
    "thigh.R": {"raise": 77, "spread": 8}, "shin.R": {"bend": 112}, "foot.R": {"flex": 10}, "toe.R": {"flex": 50},
    "clavicle.R": {"reach": 10}, "upper_arm.R": {"raise": -5, "swing": 88, "twist": 0}, "forearm.R": {"bend": 8},
    "hand.R": {"bend": -30}, "fingers.R": {"curl": 40},
    "upper_arm.L": {"raise": -35, "swing": -50, "twist": -20}, "forearm.L": {"bend": 80}, "fingers.L": {"curl": 95},
    "thumb.L": {"curl": 45},
}
COIL_LOW_A = merge(COIL_A, {"hips": {"bend": 66}, "neck": {"bend": -46}, "thigh.L": {"raise": 140},
                            "shin.L": {"bend": 112}, "foot.L": {"flex": 34}, "forearm.R": {"bend": 24}})
# exploding up over the planted left foot
DRIVE_A = {
    "hips": {"bend": 55}, "spine": {"bend": 16}, "chest": {"bend": 8}, "neck": {"bend": -42}, "head": {"bend": -24},
    "thigh.L": {"raise": 60, "spread": 8}, "shin.L": {"bend": 50}, "foot.L": {"flex": 25},
    "thigh.R": {"raise": 100, "spread": 8}, "shin.R": {"bend": 110}, "foot.R": {"flex": 10}, "toe.R": {"flex": 20},
    "upper_arm.R": {"raise": -20, "swing": 30, "twist": -20}, "forearm.R": {"bend": 80}, "fingers.R": {"curl": 80},
    "upper_arm.L": {"raise": -30, "swing": -10, "twist": -20}, "forearm.L": {"bend": 80}, "fingers.L": {"curl": 90},
}
# first step: left leg drives off, right knee comes through, arms pumping like a sprinter
LAUNCH_A = {
    "hips": {"bend": 50}, "spine": {"bend": 18}, "chest": {"bend": 8}, "neck": {"bend": -40}, "head": {"bend": -20},
    "thigh.L": {"raise": 15, "spread": 6}, "shin.L": {"bend": 15}, "foot.L": {"flex": -20}, "toe.L": {"flex": 40},
    "thigh.R": {"raise": 110, "spread": 8}, "shin.R": {"bend": 95}, "foot.R": {"flex": 10},
    "upper_arm.R": {"raise": -5, "swing": 70, "twist": -20}, "forearm.R": {"bend": 95}, "fingers.R": {"curl": 80},
    "upper_arm.L": {"raise": -20, "swing": -35, "twist": -20}, "forearm.L": {"bend": 80}, "fingers.L": {"curl": 80},
}
# right shoulder buried in the midsection, head to the side, arms locked round the waist
SPEAR_A = {
    "hips": {"bend": 60}, "spine": {"bend": 15, "lean": 10}, "chest": {"bend": 5, "lean": 10},
    "neck": {"bend": -30}, "head": {"turn": 20, "lean": 10},
    "thigh.L": {"raise": 80, "spread": 8}, "shin.L": {"bend": 70},
    "thigh.R": {"raise": 20, "spread": 6}, "shin.R": {"bend": 15}, "foot.R": {"flex": -30},
    "clavicle.L": {"reach": 15}, "upper_arm.L": {"raise": 147, "swing": -14, "twist": -79}, "forearm.L": {"bend": 44},
    "fingers.L": {"curl": 70},
    "clavicle.R": {"reach": 15}, "upper_arm.R": {"raise": 55, "swing": 7, "twist": -65}, "forearm.R": {"bend": 100},
    "fingers.R": {"curl": 70},
}
# a beat before contact: arms wide, about to close round the waist
REACH_A = merge(SPEAR_A, {
    "upper_arm.L": {"raise": 120, "swing": 44, "twist": -6}, "forearm.L": {"bend": 76},
    "upper_arm.R": {"raise": 37, "swing": -17, "twist": -72}, "forearm.R": {"bend": 77},
})
FLY_A = merge(SPEAR_A, {"hips": {"bend": 74}, "thigh.L": {"raise": 32, "spread": 10}, "shin.L": {"bend": 35},
                        "foot.L": {"flex": -30}, "thigh.R": {"raise": 22}, "shin.R": {"bend": 25}})
# folded around the shoulder: hips driven back, legs swept out from under
FOLD_D = merge(sym({
    "thigh.L": {"raise": 25, "spread": 22}, "shin.L": {"bend": 35}, "foot.L": {"flex": -20},
    "upper_arm.L": {"raise": 60, "swing": 50, "twist": 0}, "forearm.L": {"bend": 30}, "fingers.L": {"curl": 30},
}), {"hips": {"bend": -18}, "spine": {"bend": 30, "lean": 8}, "chest": {"bend": 14, "lean": 8}, "neck": {"bend": 18},
     "head": {"bend": 15}})
JACK_D = merge(FOLD_D, sym({"thigh.L": {"raise": 70, "spread": 46}, "shin.L": {"bend": 55},
                            "upper_arm.L": {"raise": 75, "swing": 40}}),
               {"hips": {"bend": -32}, "spine": {"bend": 24, "lean": 12}, "chest": {"bend": 8, "lean": 12},
                "neck": {"bend": 22}})

# ---------------------------------------------------------------- the crash and the roar

CRASH_D = merge(DOWN_BACK, sym({
    "thigh.L": {"raise": 55, "spread": 36, "twist": 10}, "shin.L": {"bend": 55}, "foot.L": {"flex": -10},
    "upper_arm.L": {"raise": 60, "swing": 10}, "forearm.L": {"bend": 30},
}), {"spine": {"bend": 8}, "chest": {"bend": 6}, "neck": {"bend": 20}, "head": {"bend": 10}})
# legs splayed round the attacker until he climbs off
SPLAYED_D = merge(DOWN_BACK, sym({"thigh.L": {"raise": 42, "spread": 32, "twist": 12}, "shin.L": {"bend": 55},
                                  "foot.L": {"flex": -15}}), {"head": {"bend": 14}})
# kneeling between the legs, chest on the belly, arms still round the waist
ON_TOP_A = merge(sym({
    "upper_arm.L": {"raise": 40, "swing": 70, "twist": -30}, "forearm.L": {"bend": 50}, "fingers.L": {"curl": 60},
    "thigh.L": {"raise": 85, "spread": 14}, "shin.L": {"bend": 95}, "foot.L": {"flex": -40},
}), {"hips": {"bend": 85}, "spine": {"bend": 18}, "chest": {"bend": 12}, "neck": {"bend": -30},
     "head": {"turn": 30, "lean": 10}})
KNEEL_A = merge(sym({
    "thigh.L": {"raise": 2, "spread": 14}, "shin.L": {"bend": 95}, "foot.L": {"flex": 25}, "toe.L": {"flex": 60},
    "upper_arm.L": {"raise": 10, "swing": 40, "twist": -30}, "forearm.L": {"bend": 70}, "fingers.L": {"curl": 90},
}), {"hips": {"bend": -2}, "spine": {"bend": 6}, "chest": {"bend": 0}, "neck": {"bend": -6}, "head": {"bend": -4}})
# on the knees, both arms flexed, head thrown back
ROAR_A = merge(KNEEL_A, sym({
    "clavicle.L": {"shrug": 14, "reach": -4},
    "upper_arm.L": {"raise": 50, "swing": 12, "twist": -55}, "forearm.L": {"bend": 110},
    "fingers.L": {"curl": 100}, "thumb.L": {"curl": 50},
}), {"spine": {"bend": -6}, "chest": {"bend": -12}, "neck": {"bend": -14}, "head": {"bend": -22}})
ROAR_PEAK_A = merge(ROAR_A, {"chest": {"bend": -16}, "head": {"bend": -28}})
# fists tucked in while rocking back off him onto the feet
FISTS_UP = sym({"upper_arm.L": {"raise": -5, "swing": 35, "twist": -20}, "forearm.L": {"bend": 115},
                "fingers.L": {"curl": 95}})
SIT_BACK_A = merge(KNEEL_A, FISTS_UP, sym({"thigh.L": {"raise": 35}}), {"hips": {"bend": 25}, "spine": {"bend": 15}})
ROCK_A = merge(FISTS_UP, sym({
    "thigh.L": {"raise": 112, "spread": 16, "twist": 10}, "shin.L": {"bend": 138}, "foot.L": {"flex": 40},
    "toe.L": {"flex": 40},
}), {"hips": {"bend": 30}, "spine": {"bend": 22}, "chest": {"bend": 10}, "neck": {"bend": -20}, "head": {"bend": -10}})
ROCKING_A = merge(ROCK_A, sym({"thigh.L": {"raise": 75}, "shin.L": {"bend": 122}, "foot.L": {"flex": 35},
                               "toe.L": {"flex": 50}}), {"hips": {"bend": 28}, "spine": {"bend": 18}})
SQUAT_A = merge(ROCK_A, sym({"thigh.L": {"raise": 105}, "shin.L": {"bend": 120}, "foot.L": {"flex": 22},
                             "toe.L": {"flex": 0}}), {"hips": {"bend": 18}})
RISE_A = merge(STANCE, sym({"thigh.L": {"raise": 48}, "shin.L": {"bend": 72}, "foot.L": {"flex": 24}}),
               {"spine": {"bend": 16}})

# Kai backs off into his stance as the opponent staggers away, so the charge and the crash
# stay near the middle of the pair (where the finisher camera looks).
D_SPOT = 1.5          # where the stagger leaves the opponent
D_LEFT = -0.02        # opponent's centre lines up with Kai's leading shoulder
D_END = 1.98
A_END = 0.62


def _d(pose, fwd):
    return at(pose, fwd, D_LEFT, turn=180)


wipeout = Paired("wipeout", [
    (0.0, TIEUP, D_TIEUP),
    (0.14, at(SHOVE_A, 0.06), at(SHOVED_D, 0.86, turn=180)),
    (0.3, SHOVE_A, at(SHOVED_D, 1.16, D_LEFT * 0.4, turn=180)),
    (0.46, at(merge(COIL_A, {"hips": {"bend": 40}}), -0.3), at(STUMBLE_D, 1.42, D_LEFT * 0.8, turn=180)),
    (0.62, at(COIL_A, -0.43), _d(DAZED_D, D_SPOT)),
    (0.8, at(COIL_LOW_A, -0.48), _d(merge(DAZED_D, {"hips": {"lean": -5}}), D_SPOT)),
    (0.85, at(DRIVE_A, -0.02), _d(DAZED_D, D_SPOT)),
    (0.9, at(LAUNCH_A, 0.24), _d(merge(DAZED_D, sym({"upper_arm.L": {"raise": -20, "swing": 25}})), D_SPOT)),
    (0.95, at(REACH_A, 0.62), _d(merge(DAZED_D, sym({"upper_arm.L": {"raise": 10, "swing": 35}})), D_SPOT)),
    (0.98, at(SPEAR_A, 0.77), _d(FOLD_D, D_SPOT), {"air_d": 0.08}),
    (1.07, at(FLY_A, 1.07), _d(JACK_D, 1.79), {"air_a": 0.15, "air_d": 0.34}),
    (1.16, at(ON_TOP_A, 1.48), _d(CRASH_D, 1.92)),
    (1.32, at(KNEEL_A, 1.42), _d(SPLAYED_D, D_END)),
    (1.46, at(ROAR_A, 1.42), _d(SPLAYED_D, D_END)),
    (1.58, at(ROAR_PEAK_A, 1.42), _d(SPLAYED_D, D_END)),
    (1.66, at(SIT_BACK_A, 1.34), _d(SPLAYED_D, D_END)),
    (1.695, at(ROCKING_A, 1.24), _d(SPLAYED_D, D_END)),
    (1.73, at(ROCK_A, 1.07), _d(SPLAYED_D, D_END)),
    (1.81, at(SQUAT_A, 0.87), _d(SPLAYED_D, D_END)),
    (1.9, at(RISE_A, 0.7), _d(SPLAYED_D, D_END)),
    (2.0, at(STANCE, A_END), _d(DOWN_BACK, D_END)),
], events={"impact": 1.16})

ALL = wipeout.anims()
