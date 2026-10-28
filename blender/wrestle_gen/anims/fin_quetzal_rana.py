"""Quetzal Rana: Quetzal Neón's finisher, a hurricanrana out of the tie-up."""
from ..poses import Paired, at, merge, sym
from .grapples import D_TIEUP, STIFF, TIEUP
from .reactions import DOWN_BACK

FREE = {"ground_a": False}


def _a(pose, fwd=0.0, pelvis=None):
    """Attacker pose moved along its own forward axis; airborne keys give the pelvis height."""
    return merge(pose, {"root": {"move": (0.0, fwd, 0.0 if pelvis is None else pelvis - 1.0)}})


def _d(pose, fwd, pelvis=None):
    """Defender facing the attacker; airborne keys give the pelvis height."""
    return merge(at(pose, fwd, turn=180), {"root": {"move": (0.0, fwd, 0.0 if pelvis is None else pelvis - 1.0)}})


# ---------------------------------------------------------------- attacker

LOAD_A = merge(sym({"thigh.L": {"raise": 62, "spread": 12}, "shin.L": {"bend": 100}, "foot.L": {"flex": 28},
                    "upper_arm.L": {"raise": 60, "swing": 70, "twist": 0}, "forearm.L": {"bend": 45},
                    "fingers.L": {"curl": 50}}),
               {"spine": {"bend": 18}, "chest": {"bend": 4}, "neck": {"bend": -20}, "head": {"bend": -10}})
JUMP_A = merge(sym({"thigh.L": {"spread": 30, "raise": 120}, "shin.L": {"bend": 120}, "foot.L": {"flex": -10},
                    "upper_arm.L": {"raise": 70, "swing": 60, "twist": 0}, "forearm.L": {"bend": 70},
                    "fingers.L": {"curl": 60}}),
               {"hips": {"bend": -15}, "spine": {"bend": 10}, "neck": {"bend": -10}})
SEAT_A = merge(sym({"thigh.L": {"spread": 26, "raise": 88}, "shin.L": {"bend": 105}, "foot.L": {"flex": -10},
                    "upper_arm.L": {"raise": 15, "swing": 50, "twist": 0}, "forearm.L": {"bend": 75},
                    "fingers.L": {"curl": 60}}),
               {"hips": {"bend": -4}, "spine": {"bend": 8}, "chest": {"bend": 6}, "neck": {"bend": 5}})
WINGS_A = merge(SEAT_A, sym({"clavicle.L": {"shrug": 10}, "upper_arm.L": {"raise": 70, "swing": -15, "twist": 0},
                             "forearm.L": {"bend": 15}, "fingers.L": {"curl": 5}}),
                {"spine": {"bend": -2}, "chest": {"bend": -12}, "neck": {"bend": -10}, "head": {"bend": -12}})


def _whip(back, thigh, arms_raise, elbow, spread=26, shin=105, arch=1.0):
    """Thrown over backwards from the shoulders: `back` degrees of backward pitch."""
    return merge(sym({"thigh.L": {"spread": spread, "raise": thigh}, "shin.L": {"bend": shin}, "foot.L": {"flex": -10},
                      "upper_arm.L": {"raise": arms_raise, "swing": 0, "twist": 0},
                      "forearm.L": {"bend": elbow}, "hand.L": {"bend": -40}, "fingers.L": {"curl": 0}}),
                 {"hips": {"bend": -back}, "spine": {"bend": -12 * arch}, "chest": {"bend": -10 * arch},
                  "neck": {"bend": -25}, "head": {"bend": -15}})


# ---------------------------------------------------------------- defender

UNDER_D = merge(sym({"thigh.L": {"raise": 34, "spread": 12}, "shin.L": {"bend": 50}, "foot.L": {"flex": 16},
                     "upper_arm.L": {"raise": 20, "swing": 80, "twist": 0}, "forearm.L": {"bend": 110},
                     "fingers.L": {"curl": 70}}),
                {"hips": {"bend": -6}, "spine": {"bend": 4}, "neck": {"bend": 18}, "head": {"bend": 10}})


def _bent_d(bend, thigh, shin, foot=10):
    """Dragged forward over at the waist by the scissors."""
    return merge(sym({"thigh.L": {"raise": thigh, "spread": 10}, "shin.L": {"bend": shin}, "foot.L": {"flex": foot},
                      "upper_arm.L": {"raise": 40, "swing": 50, "twist": 0}, "forearm.L": {"bend": 60},
                      "fingers.L": {"curl": 40}}),
                 {"hips": {"bend": bend}, "spine": {"bend": 6}, "neck": {"bend": 10}})


def _flip_d(bend, thigh=15):
    """Somersaulting forward, body stretched, arms flung out."""
    return merge(STIFF, sym({"thigh.L": {"raise": thigh, "spread": 8}, "shin.L": {"bend": 20},
                             "upper_arm.L": {"raise": 60, "swing": 20}, "forearm.L": {"bend": 30}}),
                 {"hips": {"bend": bend}, "neck": {"bend": 15}})


LAND_D = merge(DOWN_BACK, sym({"thigh.L": {"raise": 55}, "shin.L": {"bend": 30}}))

quetzal_rana = Paired("quetzal_rana", [
    (0.0, TIEUP, D_TIEUP),
    (0.2, _a(LOAD_A, 0.1), D_TIEUP),
    (0.33, _a(JUMP_A, 0.38, 1.3), _d(UNDER_D, 0.8), FREE),
    (0.43, _a(SEAT_A, 0.545, 1.61), _d(UNDER_D, 0.8), FREE),
    (0.6, _a(WINGS_A, 0.545, 1.62), _d(UNDER_D, 0.8), FREE),
    (0.83, _a(WINGS_A, 0.545, 1.63), _d(UNDER_D, 0.8), FREE),
    (0.93, _a(_whip(50, 74, 150, 20), 0.4, 1.57), _d(_bent_d(14, 20, 45), 0.82), FREE),
    (1.0, _a(_whip(120, 35, 160, 20), 0.12, 1.17), _d(_bent_d(50, 50, 25), 0.85), FREE),
    (1.07, _a(_whip(178, 0, 165, 45, arch=0.3), 0.13), _d(_bent_d(68, 70, 5, -35), 0.86)),
    (1.13, _a(_whip(180, 55, 165, 55, arch=0.3), 0.13), _d(_flip_d(115, 45), 0.55, 1.55), {"ground_d": False}),
    (1.2, _a(_whip(180, 85, 165, 55, 30, 50, arch=0.3), 0.13), _d(_flip_d(160), 0.0, 1.8), {"ground_d": False}),
    (1.27, _a(_whip(172, 100, 160, 45, 45, 30, arch=0.3), 0.25), _d(_flip_d(200), -0.55, 1.6),
     {"ground_d": False}),
    (1.33, _a(_whip(150, 80, 140, 40, 45, 30), 0.5), _d(_flip_d(235), -1.05, 1.0), {"ground_d": False}),
    (1.4, _a(merge(DOWN_BACK, {"hips": {"bend": -120}}, sym({"thigh.L": {"raise": 60}})), 0.89),
     _d(merge(LAND_D, {"hips": {"bend": 270}}), -1.4)),
    (1.47, _a(merge(DOWN_BACK, sym({"thigh.L": {"raise": 55}, "shin.L": {"bend": 40}})), 1.0),
     _d(merge(DOWN_BACK, {"hips": {"bend": 270}}), -1.4)),
    (2.0, _a(DOWN_BACK, 1.0), _d(DOWN_BACK, -1.4)),
], events={"impact": 1.4})

ALL = quetzal_rana.anims()
