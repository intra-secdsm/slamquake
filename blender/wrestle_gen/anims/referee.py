"""Referee animations (same rig as the wrestlers)."""
from ..poses import Anim, merge, sym
from .basic import STANCE

KNEEL = merge({
    "thigh.L": {"raise": 80, "spread": 12}, "shin.L": {"bend": 110}, "foot.L": {"flex": 30},
    "thigh.R": {"raise": 0, "spread": 10}, "shin.R": {"bend": 100}, "foot.R": {"flex": -40},
    "spine": {"bend": 30}, "chest": {"bend": 15}, "neck": {"bend": -15},
    "upper_arm.L": {"raise": -40, "swing": 30}, "forearm.L": {"bend": 40},
})
ARM_UP = {"upper_arm.R": {"raise": 85, "swing": 10, "twist": 0}, "forearm.R": {"bend": 10},
          "fingers.R": {"curl": 0}}
ARM_SLAP = {"upper_arm.R": {"raise": -35, "swing": 45, "twist": 0}, "forearm.R": {"bend": 5},
            "fingers.R": {"curl": 0}, "spine": {"bend": 40}}

ref_count = Anim("ref_count", [
    (0.0, merge(KNEEL, ARM_UP)),
    (0.3, merge(KNEEL, ARM_UP, {"chest": {"bend": 5}})),
    (0.45, merge(KNEEL, ARM_SLAP)),
    (0.9, merge(KNEEL, ARM_UP)),
], loop=True, events={"slap": 0.45})

WAVE = merge(STANCE, sym({"upper_arm.L": {"raise": 110, "swing": 20, "twist": 0}, "forearm.L": {"bend": 10},
                          "fingers.L": {"curl": 0}}), {"head": {"bend": -10}})

ref_signal = Anim("ref_signal", [
    (0.0, STANCE),
    (0.25, WAVE),
    (0.5, merge(WAVE, sym({"upper_arm.L": {"swing": 45}}))),
    (0.75, WAVE),
    (1.0, merge(WAVE, sym({"upper_arm.L": {"swing": 45}}))),
    (1.6, STANCE),
])

ALL = [ref_count, ref_signal]
