"""Generate all game assets headlessly.

    blender -b --factory-startup -P blender/build.py -- [targets...] [--quick]

Targets: wrestler, ring, props, arena (default: all). --quick uses coarse meshes for fast iteration.
Prefer tools/build_assets.sh, which wraps this.
"""
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from wrestle_gen import anims, arena, body, poses, props, rig, ring  # noqa: E402
from wrestle_gen.util import GENERATED, export_glb, reset_scene, write_json  # noqa: E402


def build_wrestler(quick):
    reset_scene()
    armature = rig.build_armature()
    objs = [armature, body.build_body(armature, quick)]
    objs += [body.build_hair(armature, style, quick) for style in body.HAIR_STYLES]
    objs.append(body.build_eyes(armature))

    manifest = {"blend_shapes": list(body.BLEND_SHAPES), "hair_styles": body.HAIR_STYLES,
                "animations": {}}
    for anim in anims.all_anims():
        poses.bake(armature, anim)
        manifest["animations"][anim.name] = {
            "loop": anim.loop, "length": anim.length, "events": anim.events,
            "root_start": poses.root_info(anim.keys[0][1]),
            "root_end": poses.root_info(anim.keys[-1][1])}
    export_glb(GENERATED / "wrestler.glb", objs, animations=True)
    write_json(GENERATED / "wrestler.json", manifest)


def build_ring(quick):
    reset_scene()
    export_glb(GENERATED / "ring.glb", ring.build_ring())


def build_props(quick):
    reset_scene()
    export_glb(GENERATED / "props.glb", props.build_props())


def build_arena(quick):
    reset_scene()
    export_glb(GENERATED / "arena.glb", arena.build_arena())


TARGETS = {"wrestler": build_wrestler, "ring": build_ring, "props": build_props, "arena": build_arena}


def main(argv):
    quick = "--quick" in argv
    targets = [a for a in argv if not a.startswith("--")] or list(TARGETS)
    for t in targets:
        start = time.time()
        TARGETS[t](quick)
        print(f"[build] {t} done in {time.time() - start:.1f}s")


main(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
