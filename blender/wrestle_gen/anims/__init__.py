"""Animation library. Each module exposes ALL: list[Anim]."""
from . import basic, environment, finishers, grapples, reactions, referee, strikes, tag

MODULES = [basic, strikes, reactions, grapples, environment, finishers, tag, referee]


def all_anims():
    out = []
    for m in MODULES:
        out.extend(m.ALL)
    names = [a.name for a in out]
    dupes = {n for n in names if names.count(n) > 1}
    if dupes:
        raise ValueError(f"duplicate animation names: {sorted(dupes)}")
    return out
