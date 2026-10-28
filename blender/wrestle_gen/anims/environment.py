"""Using the ring: leaving/entering, going over the top rope, turnbuckles and dives,
and carrying/swinging a folding chair.

Root motion: these clips move the root bone (including height, relative to where
the clip starts) and the game moves the wrestler there when the clip ends.
CANVAS is the canvas height above the floor (game/data/ring_spec.json).
"""
from ..poses import Anim, Paired, add, at, merge, sym
from .basic import STANCE, walk
from .grapples import D_TIEUP, STIFF, TIEUP, TIEUP_DIST
from .reactions import CROUCH, DOWN_BACK, RECOIL

CANVAS = 1.15
EXIT_DIST = 1.25      # rope line to the floor outside the apron


def root(pose, fwd=0.0, up=0.0, left=0.0, turn=0.0):
    return merge(pose, {"root": {"move": (left, fwd, up), "turn": turn}})


LOW_CRAWL = merge(sym({"thigh.L": {"raise": 90, "spread": 15}, "shin.L": {"bend": 120}, "foot.L": {"flex": 0},
                       "upper_arm.L": {"raise": -40, "swing": 70}, "forearm.L": {"bend": 20}}),
                  {"hips": {"bend": 40}, "spine": {"bend": 35}, "chest": {"bend": 10}, "neck": {"bend": -30}})

# facing the ropes: duck under the bottom rope, slide off the apron, land on the floor
exit_ring = Anim("exit_ring", [
    (0.0, STANCE),
    (0.25, root(CROUCH, 0.2)),
    (0.55, root(LOW_CRAWL, 0.75)),
    (0.8, root(CROUCH, 1.05, -0.5), {"air": -0.5}),
    (1.0, root(CROUCH, EXIT_DIST, -CANVAS), {"air": -CANVAS}),
    (1.3, root(STANCE, EXIT_DIST, -CANVAS), {"air": -CANVAS}),
])

# on the floor facing the ring: climb onto the apron and roll in under the ropes
enter_ring = Anim("enter_ring", [
    (0.0, STANCE),
    (0.3, root(merge(LOW_CRAWL, {"hips": {"bend": 60}}), 0.3, 0.2), {"air": 0.7}),
    (0.6, root(LOW_CRAWL, 0.75, CANVAS), {"air": CANVAS}),
    (0.95, root(CROUCH, EXIT_DIST, CANVAS), {"air": CANVAS}),
    (1.3, root(STANCE, EXIT_DIST, CANVAS), {"air": CANVAS}),
])

TOPPLE = merge(STIFF, sym({"upper_arm.L": {"raise": 70, "swing": -20}}), {"head": {"bend": 25}})

# knocked backward over the top rope to the floor
fall_over_ropes = Anim("fall_over_ropes", [
    (0.0, STANCE),
    (0.12, RECOIL),
    (0.3, root(merge(TOPPLE, {"hips": {"bend": -60}}), -0.35), {"air": 0.9}),
    (0.5, root(merge(TOPPLE, {"hips": {"bend": -150}}), -0.9), {"air": 0.9}),
    (0.75, root(merge(DOWN_BACK, {"hips": {"bend": -270}}), -1.6, -CANVAS), {"air": -CANVAS}),
    (1.1, root(merge(DOWN_BACK, {"hips": {"bend": -270}}), -1.6, -CANVAS), {"air": -CANVAS}),
], events={"impact": 0.75})

# end pose of fall_over_ropes is lying face down... settle onto the back for "down"
fall_over_ropes.keys[-1] = (1.1, root(merge(DOWN_BACK, {"hips": {"bend": -90}}), -1.6, -CANVAS, turn=180),
                            {"air": -CANVAS})

# tie-up near the ropes: heave the opponent over the top rope to the floor
SHOVE_A = merge(STANCE, sym({"upper_arm.L": {"raise": 45, "swing": 80, "twist": 0}, "forearm.L": {"bend": 15},
                             "fingers.L": {"curl": 10}}), {"spine": {"bend": 20}, "chest": {"bend": 10}})

rope_toss = Paired("rope_toss", [
    (0.0, TIEUP, D_TIEUP),
    (0.25, SHOVE_A, at(merge(TOPPLE, {"hips": {"bend": -40}}), TIEUP_DIST + 0.3, turn=180), {"air_d": 0.5}),
    (0.45, SHOVE_A, at(merge(TOPPLE, {"hips": {"bend": -130}}), TIEUP_DIST + 0.8, turn=180), {"air_d": 1.1}),
    (0.75, STANCE, root(merge(DOWN_BACK, {"hips": {"bend": -270}}), TIEUP_DIST + 2.0, -CANVAS, turn=180),
     {"air_d": -CANVAS}),
    (1.1, STANCE, root(DOWN_BACK, TIEUP_DIST + 2.0, -CANVAS, turn=0), {"air_d": -CANVAS}),
], events={"impact": 0.75})

# ---------------------------------------------------------------- turnbuckles

PERCH_H = 1.25        # feet on the top turnbuckle, above the canvas
PERCH = merge(sym({"thigh.L": {"raise": 60, "spread": 18, "twist": 10}, "shin.L": {"bend": 85}, "foot.L": {"flex": 25},
                   "upper_arm.L": {"raise": 30, "swing": -30}, "forearm.L": {"bend": 20}, "fingers.L": {"curl": 20}}),
              {"spine": {"bend": 25}, "chest": {"bend": 5}, "neck": {"bend": -25}})
CLIMB = merge(sym({"upper_arm.L": {"raise": 80, "swing": 40}, "forearm.L": {"bend": 40}}), {
    "thigh.L": {"raise": 70}, "shin.L": {"bend": 90}, "foot.L": {"flex": 20},
    "thigh.R": {"raise": 10}, "shin.R": {"bend": 20},
    "spine": {"bend": 10}, "neck": {"bend": -20},
})

# facing the corner: climb up and turn round to face the ring
climb_corner = Anim("climb_corner", [
    (0.0, STANCE),
    (0.3, root(CLIMB, 0.15, 0.45), {"air": 0.45}),
    (0.65, root(merge(CLIMB, {"thigh.R": {"raise": 70}, "shin.R": {"bend": 90}, "thigh.L": {"raise": 15}}), 0.3, 0.9),
     {"air": 0.9}),
    (0.95, root(PERCH, 0.35, PERCH_H, turn=90), {"air": PERCH_H}),
    (1.15, root(PERCH, 0.35, PERCH_H, turn=180), {"air": PERCH_H}),
])

perch = Anim("perch", [(0.0, PERCH), (0.7, add(PERCH, {"chest": {"bend": -6}, "head": {"bend": -6}})), (1.4, PERCH)],
             loop=True)

climb_down = Anim("climb_down", [
    (0.0, PERCH),
    (0.3, root(CLIMB, 0.1, -0.6, turn=180), {"air": -0.6}),
    (0.6, root(STANCE, 0.35, -PERCH_H, turn=180), {"air": -PERCH_H}),
])

# airborne poses: the game flies the wrestler along an arc while these play
SPLASH = merge(sym({"upper_arm.L": {"raise": 60, "swing": 30}, "forearm.L": {"bend": 15}, "fingers.L": {"curl": 0},
                    "thigh.L": {"raise": 0, "spread": 15}, "shin.L": {"bend": 20}}),
               {"hips": {"bend": 90}, "neck": {"bend": -30}})
ELBOW = merge(SPLASH, {"upper_arm.R": {"raise": -10, "swing": 90}, "forearm.R": {"bend": 150},
                       "upper_arm.L": {"raise": 70, "swing": -20}, "chest": {"lean": -15}})

dive_splash = Anim("dive_splash", [(0.0, PERCH), (0.15, SPLASH), (1.0, SPLASH)], ground=False)
dive_elbow = Anim("dive_elbow", [(0.0, PERCH), (0.15, ELBOW), (1.0, ELBOW)], ground=False)

# landed face down from a dive: roll onto the back
dive_land = Anim("dive_land", [
    (0.0, SPLASH),
    (0.25, merge(SPLASH, {"hips": {"lean": 90}})),
    (0.5, merge(DOWN_BACK, {"head": {"bend": 15}})),
    (0.8, DOWN_BACK),
])

# ---------------------------------------------------------------- folding chair (held in the right hand)

CHAIR_ARMS = {
    "upper_arm.R": {"raise": -20, "swing": 40, "twist": 0}, "forearm.R": {"bend": 70}, "fingers.R": {"curl": 85},
    "upper_arm.L": {"raise": -15, "swing": 45, "twist": 0}, "forearm.L": {"bend": 75}, "fingers.L": {"curl": 85},
    "clavicle.R": {"reach": 8}, "clavicle.L": {"reach": 8},
}

chair_hold = Anim("chair_hold", [(0.0, merge(STANCE, CHAIR_ARMS)), (0.9, merge(add(STANCE, {"chest": {"bend": -2}}), CHAIR_ARMS)),
                                 (1.8, merge(STANCE, CHAIR_ARMS))], loop=True)
chair_walk = Anim("chair_walk", [(k[0], merge(k[1], CHAIR_ARMS)) for k in walk.keys], loop=True)

CHAIR_UP = merge(STANCE, sym({"upper_arm.L": {"raise": 100, "swing": 30, "twist": 0}, "forearm.L": {"bend": 70},
                              "fingers.L": {"curl": 85}}), {"chest": {"bend": -15}, "spine": {"bend": -8}})
CHAIR_DOWN = merge(STANCE, sym({"upper_arm.L": {"raise": 0, "swing": 85, "twist": 0}, "forearm.L": {"bend": 10},
                                "fingers.L": {"curl": 85}}), {"chest": {"bend": 25}, "spine": {"bend": 15}})

chair_swing = Anim("chair_swing", [
    (0.0, merge(STANCE, CHAIR_ARMS)),
    (0.25, CHAIR_UP),
    (0.4, CHAIR_DOWN),
    (0.55, CHAIR_DOWN),
    (0.9, merge(STANCE, CHAIR_ARMS)),
], events={"hit": 0.4})

item_pickup = Anim("item_pickup", [
    (0.0, STANCE),
    (0.3, merge(CROUCH, sym({"upper_arm.L": {"raise": -50, "swing": 50}, "forearm.L": {"bend": 20}}))),
    (0.65, merge(STANCE, CHAIR_ARMS)),
], events={"grab": 0.3})

ALL = [exit_ring, enter_ring, fall_over_ropes, climb_corner, perch, climb_down, dive_splash, dive_elbow, dive_land,
       chair_hold, chair_walk, chair_swing, item_pickup] + rope_toss.anims()
