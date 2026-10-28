"""Locomotion and basic strike animations."""
from ..poses import Anim, add, merge, sym

GUARD_ARMS = sym({
    "clavicle.L": {"shrug": 6, "reach": 4},
    "upper_arm.L": {"raise": -42, "swing": 42, "twist": -30},
    "forearm.L": {"bend": 118},
    "hand.L": {"bend": -5},
    "fingers.L": {"curl": 100},
    "thumb.L": {"curl": 45},
})

STANCE = merge(GUARD_ARMS, sym({
    "thigh.L": {"raise": 20, "spread": 7, "twist": 8},
    "shin.L": {"bend": 32},
    "foot.L": {"flex": 12},
}), {
    "spine": {"bend": 7},
    "chest": {"bend": 6},
    "neck": {"bend": -7},
    "head": {"bend": -5},
})

BREATHE_IN = {
    "chest": {"bend": -2},
    "clavicle.L": {"shrug": 3},
    "clavicle.R": {"shrug": 3},
    "thigh.L": {"raise": 2},
    "thigh.R": {"raise": 2},
    "shin.L": {"bend": 4},
    "shin.R": {"bend": 4},
    "foot.L": {"flex": 2},
    "foot.R": {"flex": 2},
}

idle = Anim("idle", [
    (0.0, STANCE),
    (0.9, add(STANCE, BREATHE_IN, {"spine": {"turn": 3}})),
    (1.8, STANCE),
], loop=True)


def _stride(lead, trail, lift_trail):
    """Leg pose for one walk phase. lead/trail are 'L' or 'R'."""
    return {
        f"thigh.{lead}": {"raise": 24 if not lift_trail else 4, "spread": 5},
        f"shin.{lead}": {"bend": 8 if not lift_trail else 14},
        f"foot.{lead}": {"flex": 12 if not lift_trail else -4},
        f"thigh.{trail}": {"raise": -14 if not lift_trail else 26, "spread": 5},
        f"shin.{trail}": {"bend": 18 if not lift_trail else 58},
        f"foot.{trail}": {"flex": -6 if not lift_trail else 18},
    }


WALK_BODY = merge(GUARD_ARMS, {"spine": {"bend": 6}, "chest": {"bend": 4}, "neck": {"bend": -6}})

walk = Anim("walk", [
    (0.0, merge(WALK_BODY, _stride("L", "R", False), {"hips": {"turn": 5}, "chest": {"turn": -6}})),
    (0.25, merge(WALK_BODY, _stride("L", "R", True))),
    (0.5, merge(WALK_BODY, _stride("R", "L", False), {"hips": {"turn": -5}, "chest": {"turn": 6}})),
    (0.75, merge(WALK_BODY, _stride("R", "L", True))),
    (1.0, merge(WALK_BODY, _stride("L", "R", False), {"hips": {"turn": 5}, "chest": {"turn": -6}})),
], loop=True)

PUNCH_WINDUP = merge(STANCE, {
    "chest": {"turn": -14, "bend": 6},
    "spine": {"turn": -6, "bend": 7},
    "upper_arm.R": {"raise": -42, "swing": 25, "twist": -10},
    "forearm.R": {"bend": 125},
})

PUNCH_EXTEND = merge(STANCE, {
    "hips": {"turn": 10, "move": (0, 0.05, 0)},
    "spine": {"turn": 10, "bend": 10},
    "chest": {"turn": 18, "bend": 8},
    "head": {"turn": -12, "bend": -4},
    "clavicle.R": {"reach": 25, "shrug": 0},
    "upper_arm.R": {"raise": 38, "swing": 82, "twist": -30},
    "forearm.R": {"bend": 8},
    "hand.R": {"bend": 0},
    "thigh.L": {"raise": 30},
    "shin.L": {"bend": 36},
    "foot.L": {"flex": 6},
    "thigh.R": {"raise": 4},
    "shin.R": {"bend": 22},
    "foot.R": {"flex": 16},
})

punch = Anim("punch", [
    (0.0, STANCE),
    (0.12, PUNCH_WINDUP),
    (0.22, PUNCH_EXTEND),
    (0.30, PUNCH_EXTEND),
    (0.55, STANCE),
], events={"hit": 0.22})

ALL = [idle, walk, punch]  # punch = right cross
