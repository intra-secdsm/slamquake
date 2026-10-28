"""Strikes: dropkick and superkick, and the running shoulder tackle, knee and crossbody."""
from ..poses import Anim, merge, sym
from .basic import STANCE
from .reactions import DOWN_BACK
from .strikes import _run_phase

# ---------------------------------------------------------------- dropkick

DK_CROUCH = merge(STANCE, sym({
    "thigh.L": {"raise": 60, "spread": 9},
    "shin.L": {"bend": 100},
    "foot.L": {"flex": 30},
    "upper_arm.L": {"raise": -25, "swing": -40, "twist": 0},
    "forearm.L": {"bend": 30},
    "fingers.L": {"curl": 60},
}), {"spine": {"bend": 28}, "chest": {"bend": 8}, "neck": {"bend": -24}, "head": {"bend": -8}})

DK_LAUNCH = merge(sym({
    "thigh.L": {"raise": 15, "spread": 5},
    "shin.L": {"bend": 20},
    "foot.L": {"flex": -35},
    "upper_arm.L": {"raise": 30, "swing": 60, "twist": 0},
    "forearm.L": {"bend": 30},
    "fingers.L": {"curl": 40},
}), {"hips": {"bend": -30}, "spine": {"bend": 5}, "neck": {"bend": 10}})

DK_CHAMBER = merge(sym({
    "thigh.L": {"raise": 85, "spread": 5},
    "shin.L": {"bend": 100},
    "foot.L": {"flex": 10},
    "upper_arm.L": {"raise": 35, "swing": 10, "twist": 0},
    "forearm.L": {"bend": 35},
    "fingers.L": {"curl": 40},
}), {"hips": {"bend": -60, "move": (0, -0.05, 0)}, "spine": {"bend": 10}, "neck": {"bend": 25}})

DK_KICK = merge(sym({
    "thigh.L": {"raise": 26, "spread": 3},
    "shin.L": {"bend": 4},
    "foot.L": {"flex": -20},
    "upper_arm.L": {"raise": 40, "swing": -10, "twist": 0},
    "forearm.L": {"bend": 20},
    "fingers.L": {"curl": 30},
}), {"hips": {"bend": -88, "move": (0, -0.1, 0)}, "spine": {"bend": 6}, "neck": {"bend": 30}, "head": {"bend": 8}})

DK_PUSH = merge(DK_KICK, sym({
    "thigh.L": {"raise": 40},
    "shin.L": {"bend": 35},
    "foot.L": {"flex": -5},
}), {"hips": {"bend": -92, "move": (0, -0.08, 0)}})

DK_FALL = merge(DOWN_BACK, sym({
    "thigh.L": {"raise": 40},
    "shin.L": {"bend": 25},
    "upper_arm.L": {"raise": 70, "swing": -10},
    "forearm.L": {"bend": 15},
    "fingers.L": {"curl": 10},
}), {"hips": {"bend": -88, "move": (0, -0.04, 0)}, "neck": {"bend": 20}})

DK_LAND = merge(DOWN_BACK, sym({
    "thigh.L": {"raise": 45},
    "shin.L": {"bend": 30},
    "upper_arm.L": {"raise": 55, "swing": -15},
    "forearm.L": {"bend": 10},
    "fingers.L": {"curl": 10},
}), {"neck": {"bend": 20}})

dropkick = Anim("dropkick", [
    (0.0, STANCE),
    (0.09, DK_CROUCH),
    (0.17, DK_LAUNCH, {"air": 0.12}),
    (0.24, DK_CHAMBER, {"air": 0.55}),
    (0.30, DK_KICK, {"air": 0.72}),
    (0.40, DK_PUSH, {"air": 0.6}),
    (0.52, DK_FALL, {"air": 0.2}),
    (0.60, DK_LAND),
    (0.75, merge(DOWN_BACK, sym({"thigh.L": {"raise": 25}}))),
    (0.92, DOWN_BACK),
], events={"hit": 0.30})

# ---------------------------------------------------------------- superkick (right leg)

SK_CHAMBER = merge(STANCE, {
    "hips": {"bend": -8},
    "spine": {"bend": -2}, "chest": {"bend": -4},
    "thigh.R": {"raise": 105, "spread": 2}, "shin.R": {"bend": 120}, "foot.R": {"flex": -10},
    "thigh.L": {"raise": 12}, "shin.L": {"bend": 24}, "foot.L": {"flex": 6},
})

SK_KICK = merge(STANCE, {
    "hips": {"bend": -30},
    "spine": {"bend": -10}, "chest": {"bend": -8}, "neck": {"bend": 30}, "head": {"bend": 18},
    "thigh.R": {"raise": 108, "spread": 2, "twist": 0}, "shin.R": {"bend": 2}, "foot.R": {"flex": -45},
    "thigh.L": {"raise": -18, "spread": 6}, "shin.L": {"bend": 18}, "foot.L": {"flex": 10},
    "upper_arm.L": {"raise": -10, "swing": 55, "twist": -20}, "forearm.L": {"bend": 100},
    "upper_arm.R": {"raise": 10, "swing": -50, "twist": 0}, "forearm.R": {"bend": 30},
})

SK_RECOIL = merge(STANCE, {
    "hips": {"bend": -12},
    "thigh.R": {"raise": 80, "spread": 2}, "shin.R": {"bend": 100}, "foot.R": {"flex": 0},
    "thigh.L": {"raise": 0}, "shin.L": {"bend": 22},
})

superkick = Anim("superkick", [
    (0.0, STANCE),
    (0.11, SK_CHAMBER),
    (0.25, SK_KICK),
    (0.33, merge(SK_KICK, {"thigh.R": {"raise": 112}, "hips": {"bend": -33}})),
    (0.48, SK_RECOIL),
    (0.7, STANCE),
], events={"hit": 0.25})

# ---------------------------------------------------------------- running shoulder tackle (right shoulder)

ST_DIP = merge(_run_phase("R", "L", False), {
    "hips": {"bend": 8, "turn": 12},
    "spine": {"bend": 22, "turn": 8},
    "chest": {"bend": 10, "turn": 12},
    "neck": {"bend": -20}, "head": {"turn": 10},
    "clavicle.R": {"shrug": 8, "reach": 12},
    "upper_arm.R": {"raise": -50, "swing": 15, "twist": -10}, "forearm.R": {"bend": 110},
    "upper_arm.L": {"raise": -30, "swing": -30}, "forearm.L": {"bend": 85},
})

ST_DRIVE = {
    "hips": {"bend": 12, "turn": 30, "move": (0, 0.3, 0)},
    "spine": {"bend": 28, "turn": 8},
    "chest": {"bend": 8, "turn": 15},
    "neck": {"bend": 5}, "head": {"bend": 5, "turn": 25},
    "clavicle.R": {"shrug": 12, "reach": 20},
    "upper_arm.R": {"raise": -50, "swing": 10, "twist": -10}, "forearm.R": {"bend": 115}, "fingers.R": {"curl": 95},
    "upper_arm.L": {"raise": -25, "swing": -40}, "forearm.L": {"bend": 80}, "fingers.L": {"curl": 90},
    "thigh.R": {"raise": 55, "spread": 6}, "shin.R": {"bend": 60}, "foot.R": {"flex": 20},
    "thigh.L": {"raise": -25, "spread": 4}, "shin.L": {"bend": 15}, "foot.L": {"flex": -15},
}

shoulder_tackle = Anim("shoulder_tackle", [
    (0.0, _run_phase("L", "R", False)),
    (0.09, ST_DIP),
    (0.18, ST_DRIVE),
    (0.3, merge(ST_DRIVE, {"hips": {"move": (0, 0.2, 0)}, "spine": {"bend": 18}})),
    (0.45, merge(STANCE, {"spine": {"bend": 15}, "hips": {"move": (0, 0.08, 0)}})),
    (0.7, STANCE),
], events={"hit": 0.18})

# ---------------------------------------------------------------- running knee (right knee)

RK_TAKEOFF = merge(_run_phase("L", "R", False), {
    "thigh.R": {"raise": 80, "spread": 4}, "shin.R": {"bend": 110}, "foot.R": {"flex": -10},
    "thigh.L": {"raise": 10}, "shin.L": {"bend": 25}, "foot.L": {"flex": -10},
    "upper_arm.L": {"raise": -20, "swing": 50}, "upper_arm.R": {"raise": -20, "swing": -40},
})

RK_KNEE = {
    "hips": {"bend": -12, "move": (0, 0.3, 0)},
    "spine": {"bend": 5}, "chest": {"bend": 4}, "neck": {"bend": 12},
    "thigh.R": {"raise": 115, "spread": 4}, "shin.R": {"bend": 145}, "foot.R": {"flex": -30},
    "thigh.L": {"raise": -35, "spread": 4}, "shin.L": {"bend": 75}, "foot.L": {"flex": -35},
    "upper_arm.R": {"raise": -10, "swing": -50, "twist": 0}, "forearm.R": {"bend": 60}, "fingers.R": {"curl": 90},
    "upper_arm.L": {"raise": 10, "swing": 70, "twist": 0}, "forearm.L": {"bend": 70}, "fingers.L": {"curl": 90},
}

RK_LAND = merge(STANCE, {
    "hips": {"move": (0, 0.2, 0)},
    "thigh.L": {"raise": 60}, "shin.L": {"bend": 90}, "foot.L": {"flex": 25},
    "thigh.R": {"raise": 30}, "shin.R": {"bend": 70}, "foot.R": {"flex": 20},
    "spine": {"bend": 15},
})

running_knee = Anim("running_knee", [
    (0.0, _run_phase("L", "R", False)),
    (0.1, RK_TAKEOFF),
    (0.2, RK_KNEE, {"air": 0.55}),
    (0.3, merge(RK_KNEE, {"hips": {"move": (0, 0.28, 0)}}), {"air": 0.4}),
    (0.44, RK_LAND),
    (0.75, STANCE),
], events={"hit": 0.2})

# ---------------------------------------------------------------- running crossbody

CB_LEAP = merge(_run_phase("L", "R", False), {
    "hips": {"lean": 25, "move": (0, 0.15, 0)},
    "upper_arm.L": {"raise": 60, "swing": 40}, "upper_arm.R": {"raise": 60, "swing": 40},
    "forearm.L": {"bend": 30}, "forearm.R": {"bend": 30},
    "thigh.R": {"raise": 60}, "shin.R": {"bend": 60},
})

CB_FLY = merge(sym({
    "upper_arm.L": {"raise": 30, "swing": 70, "twist": 0},
    "forearm.L": {"bend": 25},
    "fingers.L": {"curl": 20},
    "thigh.L": {"raise": 20, "spread": 10},
    "shin.L": {"bend": 35},
    "foot.L": {"flex": -20},
}), {"hips": {"lean": 85, "bend": 15, "move": (0, 0.45, 0)}, "neck": {"lean": -20}})

CB_TWIST = merge(DOWN_BACK, sym({
    "upper_arm.L": {"raise": 60, "swing": 20},
    "thigh.L": {"raise": 40},
    "shin.L": {"bend": 40},
}), {"hips": {"lean": 45, "bend": -50, "move": (0, 0.3, 0)}})

CB_LAND = merge(DOWN_BACK, sym({
    "thigh.L": {"raise": 40},
    "shin.L": {"bend": 35},
    "upper_arm.L": {"raise": 55, "swing": -15},
    "forearm.L": {"bend": 10},
}), {"hips": {"move": (0, 0.1, 0)}, "neck": {"bend": 20}})

crossbody = Anim("crossbody", [
    (0.0, _run_phase("L", "R", False)),
    (0.12, CB_LEAP, {"air": 0.15}),
    (0.25, CB_FLY, {"air": 1.05}),
    (0.38, CB_TWIST, {"air": 0.5}),
    (0.5, CB_LAND),
    (0.7, merge(DOWN_BACK, sym({"thigh.L": {"raise": 25}}))),
    (0.92, DOWN_BACK),
], events={"hit": 0.25})

ALL = [dropkick, superkick, shoulder_tackle, running_knee, crossbody]
