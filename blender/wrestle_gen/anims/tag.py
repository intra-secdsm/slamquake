"""Tag team: waiting on the apron, reaching for the tag, and stepping through the ropes.

The apron is at canvas height just outside the ropes, so these move horizontally:
APRON_STEP is the distance between the apron spot and the spot just inside the ropes.
"""
from ..poses import Anim, add, merge, sym
from .basic import STANCE
from .reactions import CROUCH

APRON_STEP = 0.85


def root(pose, fwd=0.0, turn=0.0):
    return merge(pose, {"root": {"move": (0.0, fwd, 0.0), "turn": turn}})


# standing on the apron facing the ring, right hand on the top rope
APRON_WAIT = merge(STANCE, {
    "upper_arm.R": {"raise": 35, "swing": 70, "twist": 0}, "forearm.R": {"bend": 35}, "fingers.R": {"curl": 70},
    "upper_arm.L": {"raise": -5, "swing": 15}, "forearm.L": {"bend": 25},
    "spine": {"bend": 8}, "chest": {"bend": 4},
})
APRON_REACH = merge(STANCE, {
    "upper_arm.R": {"raise": 75, "swing": 80, "twist": 0}, "forearm.R": {"bend": 5}, "fingers.R": {"curl": 5},
    "upper_arm.L": {"raise": 30, "swing": 70, "twist": 0}, "forearm.L": {"bend": 40}, "fingers.L": {"curl": 70},
    "spine": {"bend": 18}, "chest": {"bend": 10}, "neck": {"bend": -15},
})

apron_wait = Anim("apron_wait", [
    (0.0, APRON_WAIT), (1.0, add(APRON_WAIT, {"chest": {"bend": 3}, "head": {"turn": 8}})), (2.0, APRON_WAIT),
], loop=True)
apron_reach = Anim("apron_reach", [
    (0.0, APRON_REACH), (0.25, add(APRON_REACH, {"upper_arm.R": {"raise": 8}, "chest": {"bend": 4}})),
    (0.5, APRON_REACH),
], loop=True)

STEP_OVER = merge(CROUCH, {"thigh.L": {"raise": 80, "spread": 10}, "shin.L": {"bend": 95},
                           "thigh.R": {"raise": 20}, "shin.R": {"bend": 30},
                           "spine": {"bend": 40}, "chest": {"bend": 15}, "neck": {"bend": -30}},
                  sym({"upper_arm.L": {"raise": 20, "swing": 60}, "forearm.L": {"bend": 40}}))
STEP_THROUGH = merge(STEP_OVER, {"thigh.L": {"raise": 25}, "shin.L": {"bend": 30},
                                 "thigh.R": {"raise": 75}, "shin.R": {"bend": 100}})

# apron -> ring, between the top and middle ropes
apron_enter = Anim("apron_enter", [
    (0.0, APRON_WAIT),
    (0.22, root(STEP_OVER, 0.2)),
    (0.45, root(STEP_THROUGH, 0.55)),
    (0.7, root(STANCE, APRON_STEP)),
])

TAG_SLAP = merge(STANCE, {"upper_arm.R": {"raise": 80, "swing": 75, "twist": 0}, "forearm.R": {"bend": 10},
                          "fingers.R": {"curl": 0}, "spine": {"bend": 10}})

# ring -> apron after making the tag: slap hands, step out, turn to face the ring
apron_exit = Anim("apron_exit", [
    (0.0, STANCE),
    (0.12, TAG_SLAP),
    (0.4, root(STEP_OVER, 0.3)),
    (0.65, root(STEP_THROUGH, 0.65)),
    (0.85, root(STANCE, APRON_STEP, turn=90)),
    (1.05, root(APRON_WAIT, APRON_STEP, turn=180)),
], events={"tag": 0.12})

ALL = [apron_wait, apron_reach, apron_enter, apron_exit]
