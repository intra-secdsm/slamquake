"""Signature taunts (the original flex is strikes.taunt).

Each one starts and ends in STANCE, so it blends in and out of the idle and loops cleanly
as the post-match celebration. They double as entrance poses on the stage (shown for the
first 1.8 s, facing the camera), so the big moment of each lands early and reads from the front.
Hands stay clear of the belly: created wrestlers can have the biggest gut with any taunt.
"""
from ..poses import Anim, add, merge, sym
from .basic import STANCE

FISTS = sym({"fingers.L": {"curl": 108}, "thumb.L": {"curl": 55}})
OPEN = sym({"fingers.L": {"curl": -12}, "thumb.L": {"curl": -20}})


def _scale(offset, k):
    """An offset pose (angles only, for add()) multiplied by k."""
    return {bone: {s: k * v for s, v in vals.items()} for bone, vals in offset.items()}


def _shake(pose, offset, t0, dt, amps):
    """Keys alternating +offset / -offset on top of pose, one per amplitude in amps."""
    return [(t0 + i * dt, add(pose, _scale(offset, a * (1 if i % 2 == 0 else -1)))) for i, a in enumerate(amps)]


# ---------------------------------------------------------------- Roar (Bruno Kessler)
# Loads up in a hunch, then lunges into a wide-armed roar at the crowd, shaking with rage.

ROAR_GATHER = merge(STANCE, sym({
    "thigh.L": {"raise": 42, "spread": 16, "twist": 14}, "shin.L": {"bend": 62}, "foot.L": {"flex": 16},
    "clavicle.L": {"shrug": -4, "reach": 18},
    "upper_arm.L": {"raise": -8, "swing": 40, "twist": -10}, "forearm.L": {"bend": 40}, "hand.L": {"bend": 12},
}), FISTS, {"spine": {"bend": 28}, "chest": {"bend": 16}, "neck": {"bend": 8}, "head": {"bend": 18}})

ROAR = merge(STANCE, sym({
    "thigh.L": {"raise": 36, "spread": 20, "twist": 16}, "shin.L": {"bend": 52}, "foot.L": {"flex": 12},
    "clavicle.L": {"shrug": 14, "reach": -12},
    "upper_arm.L": {"raise": -18, "swing": 22, "twist": 5}, "forearm.L": {"bend": 72}, "hand.L": {"bend": 30},
}), FISTS, {"spine": {"bend": 26}, "chest": {"bend": 2}, "neck": {"bend": -30}, "head": {"bend": -12}})

LUNGE = {"spine": {"bend": 6}, "neck": {"bend": -6}, "upper_arm.L": {"raise": 4}, "upper_arm.R": {"raise": 4}}

SHUDDER = {"chest": {"turn": 2.5, "lean": 1.5}, "head": {"turn": -3, "bend": 2},
           "clavicle.L": {"shrug": 4}, "clavicle.R": {"shrug": -2},
           "upper_arm.L": {"raise": 3}, "upper_arm.R": {"raise": -3},
           "forearm.L": {"bend": -5}, "forearm.R": {"bend": 5}}

taunt_roar = Anim("taunt_roar", [
    (0.0, STANCE),
    # a heavy little hop out into the wide stance
    (0.16, merge(STANCE, sym({"thigh.L": {"raise": 30, "spread": 13}, "shin.L": {"bend": 40}}),
                 {"spine": {"bend": 14}}), {"air": 0.05}),
    (0.35, ROAR_GATHER),
    (0.6, add(ROAR, LUNGE)),
    *_shake(ROAR, SHUDDER, 0.72, 0.08, [1, 1, 1, 1, 0.9, 0.8, 0.6, 0.4]),
    (1.4, ROAR),
    (1.62, merge(ROAR_GATHER, {"spine": {"bend": 16}, "head": {"bend": 4}})),
    (1.9, STANCE),
])

# ---------------------------------------------------------------- Power Surge (Zip Volta)
# Rubs the hands together to build a charge, then fires it from both palms, crackling.

ZAP_RUB = merge(STANCE, sym({
    "thigh.L": {"raise": 28, "spread": 9}, "shin.L": {"bend": 44}, "foot.L": {"flex": 14},
    "upper_arm.L": {"raise": -51, "swing": 55, "twist": -19}, "forearm.L": {"bend": 78, "twist": 32},
    "hand.L": {"bend": -26, "tilt": 18}, "fingers.L": {"curl": 5}, "thumb.L": {"curl": 10},
}), {"spine": {"bend": 12}, "chest": {"bend": 6}, "neck": {"bend": 6}, "head": {"bend": 10}})

RUB = {"upper_arm.L": {"swing": 5}, "forearm.L": {"bend": -8}, "upper_arm.R": {"swing": -5}, "forearm.R": {"bend": 8},
       "chest": {"turn": 2}}

# the charge goes off: he springs up tall, chest out, both palms shooting up and forward
ZAP_FIRE = merge(STANCE, sym({
    "thigh.L": {"raise": 8, "spread": 9}, "shin.L": {"bend": 10}, "foot.L": {"flex": 2},
    "clavicle.L": {"shrug": 8, "reach": 16},
    "upper_arm.L": {"raise": 40, "swing": 90, "twist": 0}, "forearm.L": {"bend": 4},
    "hand.L": {"bend": -45},
}), OPEN, {"spine": {"bend": 4}, "chest": {"bend": -10}, "neck": {"bend": -8}, "head": {"bend": -4}})

SURGE = {"clavicle.L": {"shrug": 12}, "clavicle.R": {"shrug": -5}, "chest": {"lean": 4, "turn": 3},
         "head": {"turn": -5, "lean": -6}, "upper_arm.L": {"raise": 4}, "upper_arm.R": {"raise": -3},
         "hand.L": {"bend": -8}, "hand.R": {"bend": 8}}

taunt_zap = Anim("taunt_zap", [
    (0.0, STANCE),
    *_shake(ZAP_RUB, RUB, 0.2, 0.1, [1, 1, 1, 1, 1]),
    (0.7, merge(ZAP_RUB, {"spine": {"bend": 18}, "chest": {"bend": 12}})),
    (0.82, ZAP_FIRE),
    *_shake(ZAP_FIRE, SURGE, 0.9, 0.07, [1, 1, 0.8, 1, 0.7, 0.9, 0.5]),
    (1.42, ZAP_FIRE),
    (1.8, STANCE),
])

# ---------------------------------------------------------------- Spread the Wings (Quetzal Neón)
# Rises onto the toes and spreads both arms like wings for one slow, graceful flap.

TIPTOE = sym({"thigh.L": {"raise": 2, "spread": 6, "twist": 6}, "shin.L": {"bend": 3},
              "foot.L": {"flex": -38}, "toe.L": {"flex": 38}})
LOOK_UP = {"spine": {"bend": -4}, "chest": {"bend": -12}, "neck": {"bend": -12}, "head": {"bend": -16}}


def _wings(raise_, elbow, wrist, swing=-16):
    """Both arms spread like wings: the wrist trails the stroke (bent up on the way down)."""
    return sym({"clavicle.L": {"shrug": 6, "reach": -6},
                "upper_arm.L": {"raise": raise_, "swing": swing, "twist": 10},
                "forearm.L": {"bend": elbow}, "hand.L": {"bend": wrist}, "fingers.L": {"curl": 4},
                "thumb.L": {"curl": 8}})


taunt_wings = Anim("taunt_wings", [
    (0.0, STANCE),
    (0.45, merge(STANCE, TIPTOE, _wings(14, 24, -14, 0), {"spine": {"bend": 0}, "chest": {"bend": -6},
                                                          "neck": {"bend": -6}, "head": {"bend": -6}})),
    (0.85, merge(STANCE, TIPTOE, _wings(58, 16, -8), LOOK_UP)),
    # the downstroke lifts him to the very tips of his toes, the upstroke lets him sink a little
    (1.18, merge(STANCE, TIPTOE, _wings(18, 30, -34), LOOK_UP, sym({"foot.L": {"flex": -46}, "toe.L": {"flex": 46}}),
                 {"chest": {"bend": -8}})),
    (1.5, merge(STANCE, TIPTOE, _wings(72, 18, 28), LOOK_UP, sym({"shin.L": {"bend": 9}, "foot.L": {"flex": -30}}),
                {"chest": {"bend": -16}})),
    (1.76, merge(STANCE, TIPTOE, _wings(46, 16, 0), LOOK_UP, sym({"foot.L": {"flex": -16}, "toe.L": {"flex": 16}}))),
    (2.1, STANCE),
])

# ---------------------------------------------------------------- Mastermind (Silas Wren)
# One hand behind the back, taps a finger on the temple, then points: three moves ahead.

THINK_LEGS = {"thigh.L": {"raise": 6, "spread": 6, "twist": 10}, "shin.L": {"bend": 6}, "foot.L": {"flex": 2},
              "thigh.R": {"raise": 14, "spread": 7, "twist": 12}, "shin.R": {"bend": 20}, "foot.R": {"flex": 0}}
BEHIND_BACK = {"upper_arm.L": {"raise": -27, "swing": -47, "twist": 95}, "forearm.L": {"bend": 69, "twist": -24},
               "hand.L": {"bend": 35}, "fingers.L": {"curl": 30}, "thumb.L": {"curl": 20}}
THINK = merge(STANCE, THINK_LEGS, BEHIND_BACK, {
    "upper_arm.R": {"raise": 3, "swing": 55, "twist": -27}, "forearm.R": {"bend": 137, "twist": -2},
    "hand.R": {"bend": -6, "tilt": -3}, "fingers.R": {"curl": 25}, "thumb.R": {"curl": 70},
    "spine": {"bend": 2}, "chest": {"bend": -2}, "neck": {"bend": 4}, "head": {"bend": 6, "lean": -10},
})
TAP_OFF = {"forearm.R": {"bend": -10}, "hand.R": {"bend": -12}}
POINT = merge(STANCE, THINK_LEGS, BEHIND_BACK, {
    "clavicle.R": {"reach": 4},
    "upper_arm.R": {"raise": 16, "swing": 80, "twist": 0}, "forearm.R": {"bend": 22},
    "hand.R": {"bend": -6}, "fingers.R": {"curl": 4}, "thumb.R": {"curl": 70},
    "spine": {"bend": 4, "turn": -6}, "chest": {"bend": -6, "turn": -8},
    "neck": {"bend": -8}, "head": {"bend": -6, "lean": 7},
})

taunt_think = Anim("taunt_think", [
    (0.0, STANCE),
    (0.38, THINK),
    (0.48, add(THINK, TAP_OFF)),
    (0.56, THINK),
    (0.66, add(THINK, TAP_OFF)),
    (0.74, THINK),
    (0.98, add(POINT, {"upper_arm.R": {"swing": 6}, "chest": {"turn": -4}})),
    (1.12, POINT),
    (1.38, add(POINT, {"head": {"bend": 10}})),
    (1.6, POINT),
    (2.0, STANCE),
])

# ---------------------------------------------------------------- Hang Loose (Kai Breakwater)
# Hops into a surfing stance and rides a wave, then throws a shaka to the crowd.

SURF = merge(STANCE, {
    "thigh.L": {"raise": 30, "spread": 30, "twist": 24}, "shin.L": {"bend": 64}, "foot.L": {"flex": 14},
    "thigh.R": {"raise": 40, "spread": 22, "twist": 2}, "shin.R": {"bend": 82}, "foot.R": {"flex": 18},
    "hips": {"turn": 12, "lean": 3.5},     # the lean plants the front foot
    "spine": {"bend": 20, "turn": 5}, "chest": {"bend": 8, "turn": 6, "lean": 8},
    "neck": {"bend": -14}, "head": {"turn": 46, "bend": -4},
    "clavicle.L": {"shrug": 0, "reach": 10},
    "upper_arm.L": {"raise": 6, "swing": 34, "twist": 0}, "forearm.L": {"bend": 14}, "hand.L": {"bend": -10},
    "fingers.L": {"curl": 15}, "thumb.L": {"curl": 10},
    "clavicle.R": {"shrug": 10, "reach": -10},
    "upper_arm.R": {"raise": 62, "swing": -36, "twist": -20}, "forearm.R": {"bend": 46}, "hand.R": {"bend": 10},
    "fingers.R": {"curl": 15}, "thumb.R": {"curl": 10},
})
RIDE = {"chest": {"lean": 6}, "spine": {"lean": 3}, "upper_arm.L": {"raise": -8}, "upper_arm.R": {"raise": 8},
        "shin.L": {"bend": 8}, "shin.R": {"bend": 8}, "thigh.L": {"raise": 5}, "thigh.R": {"raise": 5}}
SHAKA = merge(SURF, {
    "thigh.L": {"raise": 22}, "shin.L": {"bend": 46}, "thigh.R": {"raise": 30}, "shin.R": {"bend": 62},
    "spine": {"bend": 8, "turn": 0}, "chest": {"bend": 0, "turn": -6, "lean": 0}, "neck": {"bend": -8},
    "head": {"turn": -6, "bend": -6, "lean": -6},
    "clavicle.R": {"shrug": 6, "reach": 10},
    "upper_arm.R": {"raise": 19, "swing": 30, "twist": -42}, "forearm.R": {"bend": 71, "twist": 35},
    "hand.R": {"bend": 0}, "fingers.R": {"curl": 115}, "thumb.R": {"curl": -40},
})
WIGGLE = {"forearm.R": {"twist": 32}, "hand.R": {"tilt": 8}}

taunt_shaka = Anim("taunt_shaka", [
    (0.0, STANCE),
    (0.15, merge(STANCE, sym({"thigh.L": {"raise": 34}, "shin.L": {"bend": 58}}), {"spine": {"bend": 14}})),
    (0.3, merge(STANCE, sym({"thigh.L": {"raise": 20, "spread": 18}, "shin.L": {"bend": 30},
                             "upper_arm.L": {"raise": 10, "swing": 20}, "forearm.L": {"bend": 40}})), {"air": 0.12}),
    (0.45, SURF),
    (0.7, add(SURF, RIDE)),
    (0.95, add(SURF, _scale(RIDE, -1))),
    (1.2, SURF),
    (1.38, SHAKA),
    *_shake(SHAKA, WIGGLE, 1.48, 0.1, [1, 1, 1, 1]),
    (1.86, SHAKA),
    (2.2, STANCE),
])

# ---------------------------------------------------------------- Reboot (Overclock)
# Stiff servo moves: the head snaps side to side, the arms lock into right angles step by
# step, then the whole body charges up with fists clenched.

ROBOT = merge(STANCE, sym({
    "thigh.L": {"raise": 4, "spread": 8, "twist": 6}, "shin.L": {"bend": 6}, "foot.L": {"flex": 2},
    "clavicle.L": {"shrug": 0, "reach": 0},
    "upper_arm.L": {"raise": -36, "swing": 8, "twist": 0}, "forearm.L": {"bend": 8}, "hand.L": {"bend": 0},
    "fingers.L": {"curl": 10}, "thumb.L": {"curl": 15},
}), {"spine": {"bend": 0}, "chest": {"bend": 0}, "neck": {"bend": 0}, "head": {"bend": 0}})
UP_ARM = {"raise": 40, "swing": 0, "twist": -90}
ARM_UP_R = {"upper_arm.R": UP_ARM, "forearm.R": {"bend": 90}}
ARM_UP_L = {"upper_arm.L": UP_ARM, "forearm.L": {"bend": 90}}
CHARGE = merge(STANCE, sym({
    "thigh.L": {"raise": 30, "spread": 16, "twist": 10}, "shin.L": {"bend": 46}, "foot.L": {"flex": 12},
    "clavicle.L": {"shrug": 6},
    "upper_arm.L": {"raise": -18, "swing": 22, "twist": -10}, "forearm.L": {"bend": 96},
}), FISTS, {"spine": {"bend": 14}, "chest": {"bend": 6}, "neck": {"bend": 8}, "head": {"bend": 10}})
# fully charged: elbows driven back, fists clenched at the hips, chest out, a scream at the lights
POWERED = merge(CHARGE, sym({
    "thigh.L": {"raise": 24}, "shin.L": {"bend": 36},
    "clavicle.L": {"shrug": 16, "reach": -10},
    "upper_arm.L": {"raise": -27, "swing": -13, "twist": 46}, "forearm.L": {"bend": 68}, "hand.L": {"bend": 25},
}), {"spine": {"bend": 4}, "chest": {"bend": -16}, "neck": {"bend": -16}, "head": {"bend": -14}})
BUZZ = {"chest": {"lean": 1.5, "turn": 1.5}, "head": {"turn": -2},
        "clavicle.L": {"shrug": 3}, "clavicle.R": {"shrug": -3}, "forearm.L": {"bend": 4}, "forearm.R": {"bend": -4}}
LOOK_L = merge(ROBOT, {"neck": {"turn": 12}, "head": {"turn": 62}})
LOOK_R = merge(ROBOT, {"neck": {"turn": -12}, "head": {"turn": -62}})
ARMS_UP = merge(ROBOT, ARM_UP_R, ARM_UP_L)


def _servo(t, old, new, over=0.15):
    """Hold old until t, then lock into new like a servo: two frames there, one frame of overshoot."""
    tip = {b: {s: v + over * (v - old.get(b, {}).get(s, 0.0)) for s, v in vals.items()} for b, vals in new.items()}
    return [(t, old), (t + 2 / 30, tip), (t + 3 / 30, new)]


taunt_robot = Anim("taunt_robot", [
    (0.0, STANCE),
    (0.1, ROBOT),
    *_servo(0.167, ROBOT, LOOK_L),
    *_servo(0.367, LOOK_L, LOOK_R),
    *_servo(0.567, LOOK_R, merge(ROBOT, ARM_UP_R)),
    *_servo(0.767, merge(ROBOT, ARM_UP_R), ARMS_UP),
    *_servo(0.967, ARMS_UP, merge(ARMS_UP, {"upper_arm.R": {"twist": 90}})),
    *_servo(1.167, merge(ARMS_UP, {"upper_arm.R": {"twist": 90}}), merge(ARMS_UP, {"upper_arm.L": {"twist": 90}})),
    (1.433, CHARGE),
    *_shake(CHARGE, BUZZ, 1.5, 0.067, [0.8, 1.2]),
    (1.633, POWERED),
    (1.733, add(POWERED, BUZZ)),
    (1.833, POWERED),
    (2.1, STANCE),
])

# ---------------------------------------------------------------- Reach for the Stars (Nova Reyes)
# Points to the sky, pulls it all in, bursts open in a star jump, then tosses her hair.

HIP_L = {"upper_arm.L": {"raise": -4, "swing": -18, "twist": 70}, "forearm.L": {"bend": 88, "twist": -12},
         "hand.L": {"bend": 3, "tilt": 31}, "fingers.L": {"curl": 90}, "thumb.L": {"curl": 40}}
SKY = merge(STANCE, HIP_L, {
    "thigh.L": {"raise": 18, "spread": 8, "twist": 12}, "shin.L": {"bend": 15}, "foot.L": {"flex": -10},
    "thigh.R": {"raise": 4, "spread": 7, "twist": 8}, "shin.R": {"bend": 4}, "foot.R": {"flex": 2},
    "clavicle.R": {"shrug": 16},
    "upper_arm.R": {"raise": 120, "swing": -26, "twist": 17}, "forearm.R": {"bend": 2},
    "hand.R": {"bend": -5}, "fingers.R": {"curl": 0}, "thumb.R": {"curl": 60},
    "spine": {"bend": 0}, "chest": {"bend": -8}, "neck": {"bend": -18}, "head": {"bend": -16, "turn": -10},
})
COLLAPSE = merge(STANCE, sym({
    "thigh.L": {"raise": 38, "spread": 9}, "shin.L": {"bend": 58}, "foot.L": {"flex": 16},
    "upper_arm.L": {"raise": -20, "swing": 55, "twist": -20}, "forearm.L": {"bend": 125},
}), FISTS, {"spine": {"bend": 22}, "chest": {"bend": 12}, "neck": {"bend": 8}, "head": {"bend": 16}})
BURST = merge(STANCE, sym({
    "thigh.L": {"raise": 6, "spread": 22, "twist": 8}, "shin.L": {"bend": 6}, "foot.L": {"flex": -24},
    "clavicle.L": {"shrug": 14},
    "upper_arm.L": {"raise": 76, "swing": -4, "twist": 0}, "forearm.L": {"bend": 6}, "hand.L": {"bend": -30},
}), OPEN, {"spine": {"bend": -4}, "chest": {"bend": -14}, "neck": {"bend": -12}, "head": {"bend": -10}})
HIPS_BOTH = merge(STANCE, sym(HIP_L), {"spine": {"bend": 2}, "chest": {"bend": -6}})

taunt_star = Anim("taunt_star", [
    (0.0, STANCE),
    (0.4, SKY),
    (0.62, add(SKY, {"upper_arm.R": {"raise": 6}, "clavicle.R": {"shrug": 4}})),
    (0.84, COLLAPSE),
    (0.98, BURST, {"air": 0.12}),
    (1.12, merge(BURST, sym({"thigh.L": {"raise": 22, "spread": 9}, "shin.L": {"bend": 34}, "foot.L": {"flex": 10}}),
                 {"spine": {"bend": 6}})),
    (1.3, merge(BURST, sym({"thigh.L": {"raise": 12, "spread": 9}, "shin.L": {"bend": 16}, "foot.L": {"flex": 6},
                            "upper_arm.L": {"raise": 80}}))),
    (1.5, merge(HIPS_BOTH, {"chest": {"lean": 6}, "neck": {"bend": 10}, "head": {"bend": 18, "turn": -24, "lean": 14}})),
    (1.64, merge(HIPS_BOTH, {"chest": {"lean": -4}, "neck": {"bend": -12},
                             "head": {"bend": -24, "turn": 18, "lean": -16}})),
    (1.8, merge(HIPS_BOTH, {"neck": {"bend": -6}, "head": {"bend": -8, "turn": 6, "lean": -5}})),
    (2.1, STANCE),
])

ALL = [taunt_roar, taunt_zap, taunt_wings, taunt_think, taunt_shaka, taunt_robot, taunt_star]
