"""Being hit: recoils, knockdowns, lying down, getting up, groggy."""
from ..poses import Anim, add, merge, sym
from .basic import STANCE

hit_head = Anim("hit_head", [
    (0.0, STANCE),
    (0.07, add(STANCE, {"head": {"bend": -28, "turn": 22}, "neck": {"bend": -10},
                        "chest": {"bend": -12, "turn": 12}, "spine": {"bend": -5},
                        "upper_arm.L": {"raise": 15}, "upper_arm.R": {"raise": 10}})),
    (0.4, STANCE),
])

hit_body = Anim("hit_body", [
    (0.0, STANCE),
    (0.08, add(STANCE, {"spine": {"bend": 22}, "chest": {"bend": 18}, "head": {"bend": 12},
                        "hips": {"move": (0, -0.06, 0)},
                        "upper_arm.L": {"swing": 10}, "upper_arm.R": {"swing": 10},
                        "thigh.L": {"raise": 8}, "thigh.R": {"raise": 8},
                        "shin.L": {"bend": 12}, "shin.R": {"bend": 12}})),
    (0.45, STANCE),
])

DOWN_BACK = merge(sym({
    "thigh.L": {"raise": 15, "spread": 10, "twist": 15},
    "shin.L": {"bend": 25},
    "foot.L": {"flex": -20},
    "clavicle.L": {"shrug": 0},
    "upper_arm.L": {"raise": 30, "swing": -10, "twist": 0},
    "forearm.L": {"bend": 25},
    "fingers.L": {"curl": 35},
}), {
    "hips": {"bend": -90},
    "spine": {"bend": 3},
    "head": {"bend": 8, "turn": 10},
})

down = Anim("down", [
    (0.0, DOWN_BACK),
    (1.0, add(DOWN_BACK, {"chest": {"bend": 3}, "head": {"turn": -6}})),
    (2.0, DOWN_BACK),
], loop=True)

RECOIL = add(STANCE, {"head": {"bend": -30}, "chest": {"bend": -20}, "spine": {"bend": -8},
                      "hips": {"bend": -8},
                      "upper_arm.L": {"raise": 45, "swing": -10},
                      "upper_arm.R": {"raise": 45, "swing": -10},
                      "forearm.L": {"bend": -60}, "forearm.R": {"bend": -60}})

FALLING = merge(DOWN_BACK, sym({
    "thigh.L": {"raise": 40},
    "shin.L": {"bend": 35},
    "upper_arm.L": {"raise": 60, "swing": 10},
}), {"hips": {"bend": -55}, "head": {"bend": 20}})

knockdown = Anim("knockdown", [
    (0.0, STANCE),
    (0.12, RECOIL),
    (0.38, FALLING),
    (0.52, merge(DOWN_BACK, {"head": {"bend": -5}}, sym({"thigh.L": {"raise": 30}}))),
    (0.62, merge(DOWN_BACK, {"head": {"bend": 15}})),
    (0.8, DOWN_BACK),
], events={"impact": 0.5})

SIT_UP = merge(sym({
    "thigh.L": {"raise": 70, "spread": 12, "twist": 10},
    "shin.L": {"bend": 110},
    "foot.L": {"flex": 10},
    "upper_arm.L": {"raise": -30, "swing": -35, "twist": 0},
    "forearm.L": {"bend": 10},
    "fingers.L": {"curl": 10},
}), {"hips": {"bend": -40}, "spine": {"bend": 20}, "chest": {"bend": 15}, "head": {"bend": 5}})

CROUCH = merge(sym({
    "thigh.L": {"raise": 105, "spread": 10, "twist": 10},
    "shin.L": {"bend": 125},
    "foot.L": {"flex": 22},
    "upper_arm.L": {"raise": -30, "swing": 40, "twist": -10},
    "forearm.L": {"bend": 40},
    "fingers.L": {"curl": 60},
}), {"hips": {"bend": 15}, "spine": {"bend": 25}, "chest": {"bend": 10}, "head": {"bend": -20}})

getup = Anim("getup", [
    (0.0, DOWN_BACK),
    (0.4, SIT_UP),
    (0.8, CROUCH),
    (1.2, STANCE),
])

GROGGY = merge(STANCE, sym({
    "upper_arm.L": {"raise": -40, "swing": 10, "twist": 0},
    "forearm.L": {"bend": 30},
    "fingers.L": {"curl": 40},
    "thigh.L": {"raise": 12},
    "shin.L": {"bend": 22},
}), {"spine": {"bend": 18}, "chest": {"bend": 12}, "head": {"bend": 20}})

groggy = Anim("groggy", [
    (0.0, add(GROGGY, {"hips": {"lean": 6}, "head": {"lean": -8}})),
    (0.8, add(GROGGY, {"hips": {"lean": -6}, "head": {"lean": 8}})),
    (1.6, add(GROGGY, {"hips": {"lean": 6}, "head": {"lean": -8}})),
], loop=True)

ALL = [hit_head, hit_body, down, knockdown, getup, groggy]
