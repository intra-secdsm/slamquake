"""Grapples, throws, Irish whips, corner and ground offence, pins.

Paired moves are authored in the attacker's frame (attacker at the origin facing
forward). Defender poses carry their root offset via at(); see poses.Paired.
"""
from ..poses import Anim, Paired, add, at, merge, sym
from .basic import STANCE
from .reactions import CROUCH, DOWN_BACK, GROGGY, SIT_UP
from .strikes import REBOUND_BACK, _run_phase

TIEUP_DIST = 0.8

TIEUP = merge(sym({
    "thigh.L": {"spread": 8, "twist": 6},
    "foot.L": {"flex": 8},
}), {
    "thigh.L": {"raise": 28}, "shin.L": {"bend": 30}, "foot.L": {"flex": 2},
    "thigh.R": {"raise": -6}, "shin.R": {"bend": 22}, "foot.R": {"flex": 26},
    "spine": {"bend": 16}, "chest": {"bend": 10}, "neck": {"bend": -12}, "head": {"bend": -6},
    "clavicle.L": {"reach": 14}, "upper_arm.L": {"raise": 30, "swing": 72, "twist": -10},
    "forearm.L": {"bend": 60}, "fingers.L": {"curl": 55},
    "clavicle.R": {"reach": 8}, "upper_arm.R": {"raise": -12, "swing": 52, "twist": -25},
    "forearm.R": {"bend": 72}, "fingers.R": {"curl": 65},
})

D_TIEUP = at(TIEUP, TIEUP_DIST, turn=180)

# held/looping tie-up while the attacker picks a move
tieup = Paired("tieup", [
    (0.0, TIEUP, D_TIEUP),
    (0.6, add(TIEUP, {"chest": {"turn": 4}}), at(add(TIEUP, {"chest": {"turn": -4}}), TIEUP_DIST, turn=180)),
    (1.2, TIEUP, D_TIEUP),
])

STIFF = merge(sym({"thigh.L": {"raise": 4, "spread": 4}, "shin.L": {"bend": 6},
                   "upper_arm.L": {"raise": 10, "swing": 10}, "forearm.L": {"bend": 20}}),
              {"spine": {"bend": 0}})

# ---------------------------------------------------------------- tie-up offence

headbutt = Paired("headbutt", [
    (0.0, TIEUP, D_TIEUP),
    (0.15, merge(TIEUP, {"spine": {"bend": 4}, "neck": {"bend": -28}, "head": {"bend": -10}}), D_TIEUP),
    (0.25, merge(TIEUP, {"spine": {"bend": 28}, "chest": {"bend": 16}, "neck": {"bend": 18}}),
     at(merge(TIEUP, {"neck": {"bend": -28}, "chest": {"bend": -14}, "spine": {"bend": -4}}), 0.9, turn=180)),
    (0.7, STANCE, at(GROGGY, 1.05, turn=180)),
], events={"impact": 0.25})

SCOOP_A = merge(sym({"thigh.L": {"raise": 55, "spread": 12}, "shin.L": {"bend": 85}, "foot.L": {"flex": 30}}), {
    "spine": {"bend": 32}, "chest": {"bend": 10}, "neck": {"bend": -15},
    "upper_arm.R": {"raise": -35, "swing": 70, "twist": 0}, "forearm.R": {"bend": 35},
    "upper_arm.L": {"raise": 40, "swing": 70, "twist": 0}, "forearm.L": {"bend": 60},
})
SCOOP_D = merge(TIEUP, {"hips": {"bend": 45}, "spine": {"bend": 25}, "chest": {"bend": 10},
                        "upper_arm.L": {"raise": -20, "swing": 40}, "upper_arm.R": {"raise": -20, "swing": 40}})
CARRY_A = merge(sym({"thigh.L": {"raise": 10, "spread": 10}, "shin.L": {"bend": 16}, "foot.L": {"flex": 6},
                     "upper_arm.L": {"raise": 25, "swing": 78, "twist": 0}, "forearm.L": {"bend": 85}}),
                {"spine": {"bend": -8}, "chest": {"bend": -6}, "neck": {"bend": -10}})
FLAT = merge(DOWN_BACK, sym({"upper_arm.L": {"raise": 50, "swing": 0}, "thigh.L": {"raise": 10},
                             "shin.L": {"bend": 15}}))
SLAM_A = merge(sym({"thigh.L": {"raise": 35, "spread": 12}, "shin.L": {"bend": 45}, "foot.L": {"flex": 10},
                    "upper_arm.L": {"raise": -30, "swing": 55, "twist": 0}, "forearm.L": {"bend": 30}}),
               {"spine": {"bend": 45}, "chest": {"bend": 15}, "neck": {"bend": -20}})

body_slam = Paired("body_slam", [
    (0.0, TIEUP, D_TIEUP),
    (0.3, SCOOP_A, at(SCOOP_D, 0.55, turn=180)),
    (0.65, CARRY_A, at(FLAT, 0.38, turn=90), {"air_d": 1.0}),
    (0.8, CARRY_A, at(FLAT, 0.4, turn=90), {"air_d": 1.05}),
    (0.98, SLAM_A, at(DOWN_BACK, 0.75, turn=90)),
    (1.45, STANCE, at(DOWN_BACK, 0.75, turn=90)),
], events={"impact": 0.98})

HOOK_A = merge(TIEUP, {"upper_arm.L": {"raise": 55, "swing": 82, "twist": 0}, "forearm.L": {"bend": 105},
                       "upper_arm.R": {"raise": 20, "swing": 70}, "forearm.R": {"bend": 60}, "spine": {"bend": 12}})
HOOK_D = merge(TIEUP, {"hips": {"bend": 45}, "spine": {"bend": 20}, "chest": {"bend": 10}, "neck": {"bend": -10},
                       "upper_arm.L": {"raise": -10, "swing": 60}, "upper_arm.R": {"raise": -10, "swing": 60}})
LIFT_A = merge(sym({"thigh.L": {"raise": 6, "spread": 10}, "shin.L": {"bend": 12}, "foot.L": {"flex": 6},
                    "upper_arm.L": {"raise": 80, "swing": 60, "twist": 0}, "forearm.L": {"bend": 85}}),
               {"spine": {"bend": -12}, "chest": {"bend": -10}, "neck": {"bend": -15}, "head": {"bend": -15}})
FALL_A = merge(DOWN_BACK, {"hips": {"bend": -45}}, sym({"thigh.L": {"raise": 40}, "shin.L": {"bend": 50},
                                                        "upper_arm.L": {"raise": 90, "swing": 20}}))

suplex = Paired("suplex", [
    (0.0, TIEUP, D_TIEUP),
    (0.3, HOOK_A, at(HOOK_D, 0.5, turn=180)),
    (0.7, LIFT_A, at(merge(STIFF, {"hips": {"bend": 175}}), 0.42, turn=180), {"air_d": 1.0}),
    (1.0, LIFT_A, at(merge(STIFF, {"hips": {"bend": 178}}), 0.42, turn=180), {"air_d": 1.05}),
    (1.18, FALL_A, at(merge(STIFF, {"hips": {"bend": 225}}), -0.6, turn=180), {"air_d": 0.9}),
    (1.35, DOWN_BACK, at(merge(DOWN_BACK, {"hips": {"bend": 270}}), -2.0, turn=180)),
    (1.8, DOWN_BACK, at(DOWN_BACK, -2.0, turn=180)),
], events={"impact": 1.35})

FACELOCK_A = merge(TIEUP, {"upper_arm.L": {"raise": 10, "swing": 82, "twist": 0}, "forearm.L": {"bend": 120},
                           "upper_arm.R": {"raise": 30, "swing": 60}, "forearm.R": {"bend": 90}, "spine": {"bend": 10}})
FACELOCK_D = merge(STANCE, {"hips": {"bend": 60}, "spine": {"bend": 25}, "chest": {"bend": 10}, "neck": {"bend": -5},
                            "upper_arm.L": {"raise": -50, "swing": 20}, "upper_arm.R": {"raise": -50, "swing": 20}})

ddt = Paired("ddt", [
    (0.0, TIEUP, D_TIEUP),
    (0.3, FACELOCK_A, at(FACELOCK_D, 0.45, turn=180)),
    (0.48, merge(FALL_A, {"hips": {"bend": -55}}), at(merge(STIFF, {"hips": {"bend": 100}}), 0.38, turn=180),
     {"air_a": 0.25, "air_d": 0.1}),
    (0.6, DOWN_BACK, at(merge(STIFF, {"hips": {"bend": 125}, "spine": {"bend": 10}}), 0.32, turn=180)),
    (0.95, DOWN_BACK, at(DOWN_BACK, 1.2, turn=0)),
    (1.4, DOWN_BACK, at(DOWN_BACK, 1.2, turn=0)),
], events={"impact": 0.6})

# ---------------------------------------------------------------- rear

WAIST_A = merge(STANCE, sym({"upper_arm.L": {"raise": -10, "swing": 65, "twist": -20}, "forearm.L": {"bend": 90},
                             "fingers.L": {"curl": 70}}), {"spine": {"bend": 12}, "head": {"bend": -5}})
BRIDGE_A = merge(sym({"thigh.L": {"raise": -70, "spread": 14}, "shin.L": {"bend": 100}, "foot.L": {"flex": 30},
                      "upper_arm.L": {"raise": 60, "swing": 40}, "forearm.L": {"bend": 70}}),
                 {"hips": {"bend": -100}, "spine": {"bend": -25}, "chest": {"bend": -20}, "neck": {"bend": -30}})

german = Paired("german", [
    (0.0, WAIST_A, at(GROGGY, 0.45)),
    (0.35, merge(WAIST_A, {"hips": {"bend": -20}, "spine": {"bend": -20}, "chest": {"bend": -20}, "head": {"bend": -25}},
                 sym({"thigh.L": {"raise": 28}, "shin.L": {"bend": 42}})),
     at(merge(STIFF, {"hips": {"bend": -30}}), 0.3), {"air_d": 0.4}),
    (0.62, BRIDGE_A, at(merge(STIFF, {"hips": {"bend": -180}}), -0.55), {"air_d": 0.02}),
    (0.75, BRIDGE_A, at(merge(STIFF, {"hips": {"bend": -185}}), -0.6)),
    (1.2, DOWN_BACK, at(DOWN_BACK, -1.4, turn=180)),
    (1.6, DOWN_BACK, at(DOWN_BACK, -1.4, turn=180)),
], events={"impact": 0.7})

# ---------------------------------------------------------------- running opponent

DUCK_A = merge(sym({"thigh.L": {"raise": 50, "spread": 14}, "shin.L": {"bend": 70}, "foot.L": {"flex": 20},
                    "upper_arm.L": {"raise": -40, "swing": 30}}), {"spine": {"bend": 60}, "chest": {"bend": 20}})
THROW_A = merge(STANCE, sym({"upper_arm.L": {"raise": 70, "swing": 40}, "forearm.L": {"bend": 30}}),
                {"spine": {"bend": -10}, "chest": {"bend": -10}, "head": {"bend": -15}})

back_body_drop = Paired("back_body_drop", [
    (0.0, STANCE, at(_run_phase("L", "R", False), 1.3, turn=180)),
    (0.2, DUCK_A, at(merge(_run_phase("R", "L", False), {"hips": {"bend": 20}}), 0.55, turn=180)),
    (0.45, THROW_A, at(merge(STIFF, {"hips": {"bend": 180}}), -0.1, turn=180), {"air_d": 1.3}),
    (0.75, STANCE, at(merge(DOWN_BACK, {"hips": {"bend": 270}}), -1.3, turn=180)),
    (1.1, STANCE, at(DOWN_BACK, -1.3, turn=180)),
], events={"impact": 0.75})

# ---------------------------------------------------------------- Irish whip

WHIP_A = merge(STANCE, {"chest": {"turn": 30, "bend": 4}, "spine": {"turn": 10},
                        "upper_arm.R": {"raise": 30, "swing": 45, "twist": 0}, "forearm.R": {"bend": 10},
                        "fingers.R": {"curl": 40}})

whip = Paired("whip", [
    (0.0, TIEUP, D_TIEUP),
    (0.22, WHIP_A, at(_run_phase("L", "R", False), TIEUP_DIST, turn=180)),
    (0.6, STANCE, at(_run_phase("L", "R", False), TIEUP_DIST, turn=180)),
], events={"release": 0.22})

# ---------------------------------------------------------------- ground

D_DOWN = at(DOWN_BACK, 1.25)

REACH_A = merge(sym({"thigh.L": {"raise": 45, "spread": 12}, "shin.L": {"bend": 60}, "foot.L": {"flex": 15},
                     "upper_arm.L": {"raise": -40, "swing": 60}, "forearm.L": {"bend": 30}}),
                {"spine": {"bend": 55}, "chest": {"bend": 15}, "neck": {"bend": -20}})

pickup = Paired("pickup", [
    (0.0, STANCE, D_DOWN),
    (0.3, REACH_A, at(SIT_UP, 1.05)),
    (0.62, merge(TIEUP, {"spine": {"bend": 30}}), at(CROUCH, 0.95, turn=90)),
    (0.95, TIEUP, D_TIEUP),
])

# defender lying across in front of the attacker, chest under the attacker's chest
D_ACROSS = at(DOWN_BACK, 0.5, left=0.35, turn=90)

COVER = merge({
    "thigh.L": {"raise": 8, "spread": 14}, "shin.L": {"bend": 100}, "foot.L": {"flex": -40},
    "thigh.R": {"raise": 25, "spread": 10}, "shin.R": {"bend": 112}, "foot.R": {"flex": -30},
    "hips": {"bend": 62}, "spine": {"bend": 18}, "chest": {"bend": 8}, "neck": {"bend": -25},
    "upper_arm.L": {"raise": 10, "swing": 80}, "forearm.L": {"bend": 55}, "fingers.L": {"curl": 70},
    "upper_arm.R": {"raise": -20, "swing": 65}, "forearm.R": {"bend": 35},
})

cover = Paired("cover", [
    (0.0, STANCE, D_ACROSS),
    (0.45, COVER, D_ACROSS),
])

cover_hold = Anim("cover_hold", [(0.0, COVER), (0.5, add(COVER, {"chest": {"bend": 3}})), (1.0, COVER)], loop=True)
cover_release = Anim("cover_release", [(0.0, COVER), (0.3, CROUCH), (0.65, STANCE)])

kickout = Anim("kickout", [
    (0.0, DOWN_BACK),
    (0.12, merge(DOWN_BACK, {"spine": {"bend": 30}, "chest": {"bend": 15}, "head": {"bend": 20},
                             "upper_arm.R": {"raise": 60, "swing": 40}, "forearm.R": {"bend": 10}})),
    (0.5, DOWN_BACK),
])

ELBOW_UP = merge(STANCE, {"upper_arm.R": {"raise": 75, "swing": -10, "twist": 0}, "forearm.R": {"bend": 145},
                          "chest": {"bend": -8, "turn": -10}})
ELBOW_DOWN = merge({"hips": {"bend": 80}, "spine": {"bend": 10},
                    "upper_arm.R": {"raise": -20, "swing": 85}, "forearm.R": {"bend": 145},
                    "upper_arm.L": {"raise": 20, "swing": 40}, "forearm.L": {"bend": 40}},
                   sym({"thigh.L": {"raise": 10, "spread": 10}, "shin.L": {"bend": 30}}))

elbow_drop = Paired("elbow_drop", [
    (0.0, STANCE, D_ACROSS),
    (0.25, ELBOW_UP, D_ACROSS, {"air_a": 0.18}),
    (0.5, ELBOW_DOWN, merge(D_ACROSS, {"chest": {"bend": 12}, "head": {"bend": 15}}), {"air_a": 0.22}),
    (0.9, COVER, D_ACROSS),
    (1.3, STANCE, D_ACROSS),
], events={"impact": 0.5})

stomp = Anim("stomp", [
    (0.0, STANCE),
    (0.2, merge(STANCE, {"thigh.R": {"raise": 65}, "shin.R": {"bend": 80}, "foot.R": {"flex": 0},
                         "spine": {"bend": 12}, "head": {"bend": 15}})),
    (0.32, merge(STANCE, {"thigh.R": {"raise": 30}, "shin.R": {"bend": 12}, "foot.R": {"flex": 15},
                          "spine": {"bend": 18}, "head": {"bend": 20}})),
    (0.6, STANCE),
], events={"hit": 0.32})

down_hit = Anim("down_hit", [
    (0.0, DOWN_BACK),
    (0.08, merge(DOWN_BACK, {"spine": {"bend": 14}, "chest": {"bend": 8}, "head": {"bend": 18}},
                 sym({"thigh.L": {"raise": 35}, "shin.L": {"bend": 50}}))),
    (0.45, DOWN_BACK),
])

grab_whiff = Anim("grab_whiff", [
    (0.0, STANCE),
    (0.15, merge(STANCE, sym({"upper_arm.L": {"raise": 25, "swing": 80, "twist": 0}, "forearm.L": {"bend": 15},
                              "fingers.L": {"curl": 30}}), {"spine": {"bend": 14}})),
    (0.5, STANCE),
])

# ---------------------------------------------------------------- corner (defender's back to the turnbuckle)

SLUMP = merge(sym({"upper_arm.L": {"raise": 40, "swing": -50, "twist": 0}, "forearm.L": {"bend": 25},
                   "fingers.L": {"curl": 60}, "thigh.L": {"raise": 15, "spread": 12}, "shin.L": {"bend": 25},
                   "foot.L": {"flex": 10}}),
              {"hips": {"bend": -8}, "spine": {"bend": -8}, "chest": {"bend": -6}, "head": {"bend": 28}})

corner_hit = Anim("corner_hit", [
    (0.0, _run_phase("L", "R", False)),
    (0.1, merge(REBOUND_BACK, {"head": {"bend": -20}, "chest": {"bend": -20}})),
    (0.5, SLUMP),
], events={"impact": 0.1})

corner_slump = Anim("corner_slump", [
    (0.0, SLUMP), (0.8, add(SLUMP, {"head": {"turn": 10}, "chest": {"bend": 3}})), (1.6, SLUMP),
], loop=True)

corner_exit = Anim("corner_exit", [(0.0, SLUMP), (0.35, GROGGY), (0.7, STANCE)])

PAIRED = [tieup, headbutt, body_slam, suplex, ddt, german, back_body_drop, whip, pickup, cover, elbow_drop]
ALL = [a for p in PAIRED for a in p.anims()] + [
    cover_hold, cover_release, kickout, stomp, down_hit, grab_whiff, corner_hit, corner_slump, corner_exit]
