"""Checkmate: Silas Wren's finisher, an exploder (overhead belly-to-belly) suplex."""
from ..poses import Paired, at, merge, sym
from .basic import STANCE
from .grapples import STIFF, TIEUP, D_TIEUP
from .reactions import DOWN_BACK

# attacker crouched chest-to-chest, head under the defender's right arm; the left arm hooks the
# defender's right thigh, the right arm wraps over the left shoulder and round the back of the neck
HOOK_A = merge(sym({"thigh.L": {"raise": 55, "spread": 16, "twist": 10}, "shin.L": {"bend": 80},
                    "foot.L": {"flex": 24}}), {
    "spine": {"bend": 15, "lean": 8}, "chest": {"bend": 5, "lean": 6, "turn": -8},
    "neck": {"bend": -5, "lean": 16}, "head": {"bend": -6, "turn": -20},
    "clavicle.L": {"reach": 10}, "upper_arm.L": {"raise": -30, "swing": 15, "twist": -30},
    "forearm.L": {"bend": 90}, "hand.L": {"bend": 20}, "fingers.L": {"curl": 70},
    "clavicle.R": {"reach": 16, "shrug": 10}, "upper_arm.R": {"raise": 60, "swing": -30, "twist": -90},
    "forearm.R": {"bend": 90}, "fingers.R": {"curl": 70},
})
# defender bent over the attacker's back, right thigh hooked up, standing on the left foot
HOOK_D = merge(STANCE, {
    "thigh.R": {"raise": 30, "spread": 15, "twist": 10}, "shin.R": {"bend": 50}, "foot.R": {"flex": -15},
    "thigh.L": {"raise": 4, "spread": 6}, "shin.L": {"bend": 12}, "foot.L": {"flex": 6},
    "hips": {"bend": 5}, "spine": {"bend": 8}, "chest": {"bend": 6, "lean": -8}, "neck": {"bend": 15},
    "head": {"bend": 15, "turn": -10},
    "upper_arm.R": {"raise": 20, "swing": 70, "twist": 0}, "forearm.R": {"bend": 95}, "fingers.R": {"curl": 40},
    "upper_arm.L": {"raise": -30, "swing": 30, "twist": 0}, "forearm.L": {"bend": 45}, "fingers.L": {"curl": 50},
})
D_HOOK = at(HOOK_D, 0.55, left=-0.02, turn=190)

# halfway in: knees giving, head dipping to the left, hands sliding off the collar tie
DUCK_A = merge(TIEUP, sym({"thigh.L": {"raise": 42, "spread": 14}, "shin.L": {"bend": 58}, "foot.L": {"flex": 18}}), {
    "spine": {"bend": 24, "lean": 6}, "chest": {"bend": 6}, "neck": {"bend": -12, "lean": 10},
    "upper_arm.L": {"raise": -10, "swing": 40, "twist": -20}, "forearm.L": {"bend": 70},
    "upper_arm.R": {"raise": 35, "swing": 30, "twist": -60}, "forearm.R": {"bend": 95},
})
DUCK_D = merge(TIEUP, {"spine": {"bend": 22}, "chest": {"bend": 8}, "neck": {"bend": 5}, "head": {"bend": 10},
                       "upper_arm.R": {"raise": 25, "swing": 60}, "forearm.R": {"bend": 75}})

# the set: sink, squeeze, the hooked leg comes up
SET_A = merge(HOOK_A, sym({"thigh.L": {"raise": 64}, "shin.L": {"bend": 94}, "foot.L": {"flex": 28}}), {
    "spine": {"bend": 18, "lean": 8}, "neck": {"bend": 0, "lean": 18},
    "upper_arm.L": {"raise": -18, "swing": 22}, "forearm.L": {"bend": 100},
    "upper_arm.R": {"raise": 62, "swing": -25}, "forearm.R": {"bend": 100},
})
SET_D = merge(HOOK_D, {"thigh.R": {"raise": 48, "spread": 18}, "shin.R": {"bend": 70},
                       "foot.L": {"flex": -8}, "hips": {"bend": 9}, "spine": {"bend": 12}, "neck": {"bend": 20}})

# the drive: legs straighten, the defender leaves the canvas tipping over the right shoulder
DRIVE_A = merge(STANCE, sym({"thigh.L": {"raise": 30, "spread": 14}, "shin.L": {"bend": 40}, "foot.L": {"flex": 6}}), {
    "spine": {"bend": 4, "lean": 6}, "chest": {"bend": -4, "lean": 4, "turn": -10},
    "neck": {"bend": -16, "lean": 10}, "head": {"bend": -10, "turn": -15},
    "clavicle.L": {"shrug": 12}, "upper_arm.L": {"raise": -45, "swing": 0, "twist": 30}, "forearm.L": {"bend": 60},
    "clavicle.R": {"shrug": 14}, "upper_arm.R": {"raise": 15, "swing": 0, "twist": -60}, "forearm.R": {"bend": 120},
    "fingers.L": {"curl": 70}, "fingers.R": {"curl": 70},
})
DRIVE_D = merge(STIFF, {
    "thigh.R": {"raise": 62, "spread": 16}, "shin.R": {"bend": 70}, "thigh.L": {"raise": 12}, "shin.L": {"bend": 28},
    "foot.L": {"flex": -20}, "foot.R": {"flex": -20},
    "spine": {"bend": 10}, "chest": {"bend": 4}, "neck": {"bend": 15},
    "upper_arm.R": {"raise": 70, "swing": 50}, "forearm.R": {"bend": 60},
    "upper_arm.L": {"raise": 30, "swing": 10}, "forearm.L": {"bend": 40},
})

# full extension onto the toes, arms whipping the defender up and over the right shoulder
RELEASE_A = merge(sym({"thigh.L": {"raise": 6, "spread": 12}, "shin.L": {"bend": 8}, "foot.L": {"flex": -24},
                       "fingers.L": {"curl": 50}}), {
    "hips": {"bend": -12}, "spine": {"bend": -8, "lean": 4}, "chest": {"bend": -10, "turn": -14},
    "neck": {"bend": -22}, "head": {"bend": -15, "turn": -10},
    "clavicle.L": {"shrug": 18}, "upper_arm.L": {"raise": 0, "swing": 45, "twist": 60}, "forearm.L": {"bend": 90},
    "clavicle.R": {"shrug": 18}, "upper_arm.R": {"raise": 120, "swing": 30, "twist": 60}, "forearm.R": {"bend": 90},
})
# thrown body: hooked leg still bent, the other trailing, arms flung wide
FLY_D = merge(STIFF, {
    "thigh.R": {"raise": 55, "spread": 22}, "shin.R": {"bend": 75}, "thigh.L": {"raise": 5, "spread": 12},
    "shin.L": {"bend": 18}, "foot.L": {"flex": -25}, "foot.R": {"flex": -25},
    "spine": {"bend": 6}, "neck": {"bend": 5},
    "upper_arm.L": {"raise": 100, "swing": -10}, "forearm.L": {"bend": 35},
    "upper_arm.R": {"raise": 95, "swing": 15}, "forearm.R": {"bend": 40},
})

# arching back under the flying defender, hands released overhead
ARCH_A = merge(sym({"thigh.L": {"raise": 2, "spread": 12}, "shin.L": {"bend": 26}, "foot.L": {"flex": -12},
                    "upper_arm.L": {"raise": 150, "swing": 25, "twist": 0}, "forearm.L": {"bend": 30},
                    "fingers.L": {"curl": 30}}), {
    "hips": {"bend": -38}, "spine": {"bend": -16}, "chest": {"bend": -16, "turn": -12},
    "neck": {"bend": -28}, "head": {"bend": -15},
})
# falling back off planted feet, arms reaching for the canvas behind the head
FALL_A = merge(sym({"thigh.L": {"raise": -15, "spread": 14}, "shin.L": {"bend": 75}, "foot.L": {"flex": 5},
                    "upper_arm.L": {"raise": 125, "swing": -10, "twist": 0}, "forearm.L": {"bend": 25},
                    "hand.L": {"bend": -30}, "fingers.L": {"curl": 20}}), {
    "hips": {"bend": -78}, "spine": {"bend": -22}, "chest": {"bend": -20, "turn": -8}, "neck": {"bend": -30},
    "head": {"bend": -10},
})
# bridge: feet flat, hips up, back arched onto the shoulders, hands planted by the head
BRIDGE_A = merge(sym({"thigh.L": {"raise": -26, "spread": 12}, "shin.L": {"bend": 84}, "foot.L": {"flex": -5},
                      "upper_arm.L": {"raise": 125, "swing": -20, "twist": 0}, "forearm.L": {"bend": 35},
                      "hand.L": {"bend": -50}, "fingers.L": {"curl": 10}}), {
    "hips": {"bend": -100}, "spine": {"bend": -25}, "chest": {"bend": -20}, "neck": {"bend": -32}, "head": {"bend": -8},
})
# bridge let down: hips on the canvas, knees still up, then the legs slide out
LOWER_A = merge(DOWN_BACK, sym({"thigh.L": {"raise": 62, "spread": 14}, "shin.L": {"bend": 105}, "foot.L": {"flex": 15},
                                "upper_arm.L": {"raise": 60, "swing": 40}, "forearm.L": {"bend": 70}}),
                {"spine": {"bend": -4}, "head": {"bend": -10}})
KNEES_UP = merge(DOWN_BACK, sym({"thigh.L": {"raise": 35, "spread": 12}, "shin.L": {"bend": 60}, "foot.L": {"flex": 0}}))

# defender coming down head first onto the upper back, then flat
TUCK_D = merge(FLY_D, {"thigh.R": {"raise": 40, "spread": 18}, "shin.R": {"bend": 50}, "thigh.L": {"raise": 22},
                       "shin.L": {"bend": 22}, "neck": {"bend": 30}, "head": {"bend": 25},
                       "upper_arm.L": {"raise": 60, "swing": -40}, "upper_arm.R": {"raise": 60, "swing": -40}})
LAND_D = merge(DOWN_BACK, sym({"thigh.L": {"raise": 38, "spread": 16}, "shin.L": {"bend": 30}, "foot.L": {"flex": -20},
                               "upper_arm.L": {"raise": 20, "swing": -30}, "forearm.L": {"bend": 20}}),
               {"neck": {"bend": 28}, "head": {"bend": 20}})
BOUNCE_D = merge(DOWN_BACK, sym({"thigh.L": {"raise": 28}, "shin.L": {"bend": 35}}), {"head": {"bend": 15}})


def _a(pose, fwd=0.0, left=0.0, turn=0.0):
    """Attacker pose with its root moved (it steps in, then falls back off its planted feet)."""
    return merge(pose, {"root": {"move": (left, fwd, 0.0), "turn": turn}})


def _fly(pose, bend, height, fwd, left, turn, lean=0.0):
    """Airborne defender: hips rotated `bend` (head over toward its front) at `height` metres."""
    return at(merge(pose, {"hips": {"bend": bend, "lean": lean, "move": (0.0, 0.0, height - 1.0)}}), fwd, left, turn)


FREE = {"ground_d": False}
D_END = at(DOWN_BACK, -1.84, left=-1.05, turn=210)

checkmate = Paired("checkmate", [
    (0.0, TIEUP, D_TIEUP),
    (0.16, _a(DUCK_A, 0.04), at(DUCK_D, 0.66, turn=185)),
    (0.36, _a(HOOK_A, 0.06), D_HOOK),
    (0.5, _a(merge(HOOK_A, {"spine": {"bend": 17}, "neck": {"lean": 18}}), 0.06),
     at(merge(HOOK_D, {"thigh.R": {"raise": 40}, "shin.R": {"bend": 62}}), 0.55, left=-0.02, turn=190)),
    (0.62, _a(SET_A, 0.05), at(SET_D, 0.54, left=-0.03, turn=190)),
    (0.7, _a(DRIVE_A, 0.02), _fly(DRIVE_D, 25, 1.2, 0.44, -0.08, 192), FREE),
    (0.78, _a(RELEASE_A, -0.06), _fly(FLY_D, 58, 1.6, 0.24, -0.16, 196, lean=15), dict(FREE, air_a=0.05)),
    (0.88, _a(ARCH_A, -0.18), _fly(FLY_D, 100, 1.88, -0.15, -0.34, 201, lean=30), FREE),
    (0.98, _a(FALL_A, -0.17), _fly(FLY_D, 140, 1.68, -0.6, -0.55, 205, lean=35), FREE),
    (1.08, _a(BRIDGE_A, -0.2), _fly(TUCK_D, 180, 1.2, -1.08, -0.8, 208, lean=30), FREE),
    (1.18, _a(BRIDGE_A, -0.2), at(merge(LAND_D, {"hips": {"bend": 222 - 360, "lean": 15}}), -1.55, -0.95, 210)),
    (1.26, _a(BRIDGE_A, -0.2), at(merge(LAND_D, {"hips": {"bend": 250 - 360, "lean": 6}}), -1.74, -1.01, 210)),
    (1.34, _a(BRIDGE_A, -0.2), at(BOUNCE_D, -1.84, -1.05, 210)),
    (1.48, _a(merge(BRIDGE_A, {"hips": {"bend": -96}}), -0.2), D_END),
    (1.64, _a(LOWER_A, -0.32), D_END),
    (1.82, _a(KNEES_UP, -0.32), D_END),
    (2.0, _a(DOWN_BACK, -0.32), D_END),
], events={"impact": 1.18})

ALL = checkmate.anims()
