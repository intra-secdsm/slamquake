"""Animation library. Each module exposes ALL: list[Anim]."""
from . import basic, reactions, strikes

MODULES = [basic, strikes, reactions]


def all_anims():
    out = []
    for m in MODULES:
        out.extend(m.ALL)
    names = [a.name for a in out]
    dupes = {n for n in names if names.count(n) > 1}
    if dupes:
        raise ValueError(f"duplicate animation names: {sorted(dupes)}")
    return out
