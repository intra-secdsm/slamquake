"""Animation library. Each module exposes ALL: list[Anim]."""
from . import (basic, environment, fin_checkmate, fin_quetzal_rana, fin_supernova, fin_system_crash, fin_wipeout,
               finishers, grapples, ground_air, power_moves, reactions, referee, strike_moves, strikes, suplexes, tag,
               taunts, tieup_strikes)

MODULES = [basic, strikes, reactions, grapples, environment, finishers, tag, referee,
           # M8 movesets and finishers
           strike_moves, tieup_strikes, suplexes, power_moves, ground_air, taunts,
           fin_quetzal_rana, fin_checkmate, fin_wipeout, fin_system_crash, fin_supernova]


def all_anims():
    out = []
    for m in MODULES:
        out.extend(m.ALL)
    names = [a.name for a in out]
    dupes = {n for n in names if names.count(n) > 1}
    if dupes:
        raise ValueError(f"duplicate animation names: {sorted(dupes)}")
    return out
