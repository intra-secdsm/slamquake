"""Strikes and running."""
from ..poses import Anim, merge, mirror, sym
from .basic import GUARD_ARMS, STANCE

RUN_BODY = merge(sym({
    "clavicle.L": {"shrug": 2, "reach": 6},
    "upper_arm.L": {"raise": -45, "swing": 20, "twist": -20},
    "forearm.L": {"bend": 95},
    "fingers.L": {"curl": 95},
    "thumb.L": {"curl": 45},
}), {"spine": {"bend": 14}, "chest": {"bend": 6}, "neck": {"bend": -12}, "head": {"bend": -6}})


def _run_phase(lead, trail, flight):
    s = 1 if lead == "L" else -1
    legs = {
        f"thigh.{lead}": {"raise": 50 if flight else 30, "spread": 4},
        f"shin.{lead}": {"bend": 70 if flight else 15},
        f"foot.{lead}": {"flex": 10},
        f"thigh.{trail}": {"raise": -25 if flight else -5, "spread": 4},
        f"shin.{trail}": {"bend": 45 if flight else 35},
        f"foot.{trail}": {"flex": -20 if flight else 5},
        # arms pump opposite to legs
        f"upper_arm.{lead}": {"raise": -45, "swing": -15, "twist": -20},
        f"upper_arm.{trail}": {"raise": -40, "swing": 50, "twist": -20},
        "hips": {"turn": 8 * s},
        "chest": {"turn": -10 * s, "bend": 6},
    }
    return merge(RUN_BODY, legs)


run = Anim("run", [
    (0.0, _run_phase("L", "R", False)),
    (0.16, _run_phase("L", "R", True)),
    (0.32, _run_phase("R", "L", False)),
    (0.48, _run_phase("R", "L", True)),
    (0.64, _run_phase("L", "R", False)),
], loop=True)

# quick left jab: a short, snappy version of the right cross, mirrored
JAB_EXTEND_R = merge(STANCE, {
    "chest": {"turn": 12, "bend": 8},
    "spine": {"turn": 4},
    "head": {"turn": -6},
    "clavicle.R": {"reach": 18},
    "upper_arm.R": {"raise": 35, "swing": 80, "twist": -30},
    "forearm.R": {"bend": 10},
})

jab = Anim("jab", [
    (0.0, STANCE),
    (0.10, mirror(JAB_EXTEND_R)),
    (0.16, mirror(JAB_EXTEND_R)),
    (0.36, STANCE),
], events={"hit": 0.10})

BOOT_CHAMBER = merge(STANCE, {
    "hips": {"bend": -8},
    "chest": {"bend": -6},
    "thigh.R": {"raise": 85, "spread": 4},
    "shin.R": {"bend": 95},
    "foot.R": {"flex": 10},
    "thigh.L": {"raise": 8},
    "shin.L": {"bend": 18},
    "foot.L": {"flex": 10},
    "upper_arm.L": {"raise": 0, "swing": 20},
    "upper_arm.R": {"raise": 5, "swing": -10},
    "forearm.L": {"bend": 60},
    "forearm.R": {"bend": 60},
})

BOOT_EXTEND = merge(BOOT_CHAMBER, {
    "hips": {"bend": -18},
    "spine": {"bend": -4},
    "chest": {"bend": -6},
    "head": {"bend": 12},
    "thigh.R": {"raise": 100},
    "shin.R": {"bend": 4},
    "foot.R": {"flex": 35},
})

big_boot = Anim("big_boot", [
    (0.0, STANCE),
    (0.18, BOOT_CHAMBER),
    (0.30, BOOT_EXTEND),
    (0.42, BOOT_EXTEND),
    (0.75, STANCE),
], events={"hit": 0.30})

LARIAT_ARM = {
    "clavicle.R": {"shrug": 8, "reach": 0},
    "upper_arm.R": {"raise": 42, "swing": 15, "twist": 0},
    "forearm.R": {"bend": 12},
    "fingers.R": {"curl": 60},
}

clothesline = Anim("clothesline", [
    (0.0, _run_phase("L", "R", False)),
    (0.12, merge(_run_phase("R", "L", False), LARIAT_ARM, {"chest": {"turn": -15}})),
    (0.22, merge(_run_phase("L", "R", False), LARIAT_ARM,
                 {"chest": {"turn": 25}, "upper_arm.R": {"swing": 55}})),
    (0.32, merge(STANCE, LARIAT_ARM, {"chest": {"turn": 30}, "upper_arm.R": {"swing": 75}})),
    (0.7, STANCE),
], events={"hit": 0.2})

REBOUND_BACK = merge(STANCE, sym({
    "upper_arm.L": {"raise": 25, "swing": -35, "twist": 0},
    "forearm.L": {"bend": 30},
    "fingers.L": {"curl": 70},
}), {"hips": {"bend": -6}, "spine": {"bend": -12}, "chest": {"bend": -14}, "head": {"bend": 10}})

rope_rebound = Anim("rope_rebound", [
    (0.0, _run_phase("L", "R", False)),
    (0.12, REBOUND_BACK),
    (0.26, REBOUND_BACK),
    (0.42, _run_phase("R", "L", True)),
], events={"release": 0.26})

FLEX = merge(STANCE, sym({
    "clavicle.L": {"shrug": 10, "reach": 0},
    "upper_arm.L": {"raise": 45, "swing": 5, "twist": -60},
    "forearm.L": {"bend": 120},
    "fingers.L": {"curl": 100},
}), {"chest": {"bend": -12}, "spine": {"bend": -6}, "head": {"bend": -18}})

taunt = Anim("taunt", [
    (0.0, STANCE),
    (0.3, FLEX),
    (0.6, merge(FLEX, {"chest": {"bend": -16}, "head": {"bend": -25}})),
    (0.9, FLEX),
    (1.2, merge(FLEX, {"chest": {"bend": -16}, "head": {"bend": -25}})),
    (1.6, STANCE),
])

BLOCK = merge(STANCE, sym({
    "clavicle.L": {"shrug": 10, "reach": 10},
    "upper_arm.L": {"raise": -25, "swing": 55, "twist": -30},
    "forearm.L": {"bend": 145},
    "hand.L": {"bend": 0},
}), {"spine": {"bend": 14}, "chest": {"bend": 10}, "head": {"bend": 14}})

block = Anim("block", [(0.0, BLOCK), (0.5, merge(BLOCK, {"chest": {"bend": 12}})), (1.0, BLOCK)],
             loop=True)

ALL = [run, jab, big_boot, clothesline, rope_rebound, taunt, block]
_ = GUARD_ARMS
