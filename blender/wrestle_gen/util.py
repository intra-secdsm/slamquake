import json
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parents[2]
GENERATED = ROOT / "game/assets/generated"


def reset_scene(fps=30):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = fps


def triangulate(ob):
    """Fixed-method triangulation; the exporter's own triangle order varies run to run."""
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.triangulate(bm, faces=bm.faces, quad_method="FIXED", ngon_method="EAR_CLIP")
    bm.to_mesh(ob.data)
    bm.free()


def export_glb(path, objects, animations=False):
    for ob in objects:
        if ob.type == "MESH":
            triangulate(ob)
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objects:
        ob.select_set(True)
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".tmp.glb")
    bpy.ops.export_scene.gltf(
        filepath=str(tmp),
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=False,
        export_materials="EXPORT",
        export_image_format="NONE",
        export_vertex_color="ACTIVE",
        export_all_vertex_colors=False,
        export_skins=True,
        export_morph=True,
        export_morph_normal=True,
        export_try_sparse_sk=False,  # sparse index order is not deterministic
        export_animations=animations,
        export_animation_mode="ACTIONS",
        export_force_sampling=True,
        export_optimize_animation_size=False,
        export_def_bones=False,
        export_leaf_bone=False,
    )
    if path.exists() and glb_equivalent(path, tmp):
        tmp.unlink()
        print(f"unchanged {path.relative_to(ROOT)}")
    else:
        tmp.replace(path)
        print(f"exported {path.relative_to(ROOT)}")


def _read_glb(path):
    import struct
    data = path.read_bytes()
    json_len = struct.unpack("<I", data[12:16])[0]
    return json.loads(data[20:20 + json_len]), data[20 + json_len + 8:]


def glb_equivalent(a, b):
    """True if two GLBs differ at most in triangle order within index buffers.

    Blender's exporter occasionally emits the same triangles in a different order;
    treating that as unchanged keeps regenerated assets stable in Git LFS.
    """
    import numpy as np
    ja, ba = _read_glb(a)
    jb, bb = _read_glb(b)
    if ja != jb:
        return False
    index_views = {ja["accessors"][p["indices"]]["bufferView"]: ja["accessors"][p["indices"]]
                   for m in ja.get("meshes", []) for p in m["primitives"] if "indices" in p}
    for i, view in enumerate(ja["bufferViews"]):
        off, n = view.get("byteOffset", 0), view["byteLength"]
        va, vb = ba[off:off + n], bb[off:off + n]
        if va == vb:
            continue
        acc = index_views.get(i)
        if acc is None:
            return False
        dtype = {5121: np.uint8, 5123: np.uint16, 5125: np.uint32}[acc["componentType"]]
        ta = np.sort(np.frombuffer(va, dtype).reshape(-1, 3), axis=1)
        tb = np.sort(np.frombuffer(vb, dtype).reshape(-1, 3), axis=1)
        if not np.array_equal(ta[np.lexsort(ta.T)], tb[np.lexsort(tb.T)]):
            return False
    return True


def write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w") as f:
        json.dump(data, f, indent=2, sort_keys=True)
        f.write("\n")
    print(f"wrote {path.relative_to(ROOT)}")
