"""Assemble Hunyuan part GLBs into one Mint Ribbon OC matching the turnaround.

Feet at z=0, character faces Blender -Y, target height ~1.10m.
Uses all eight parts (hands are one dumpling, duplicated L/R).
"""
from __future__ import annotations

import importlib.util
import math
from pathlib import Path

import bpy
from mathutils import Euler, Vector

try:
    ART = Path(__file__).resolve().parent.parent
except NameError:
    ART = Path("/Users/qihongrui/Desktop/project/profile-v1/app_games/9dot-music/art/myroom_oc")

GAME = ART.parent.parent
PARTS = ART / "parts"
OUT_BLEND = ART / "oc_q.blend"
OUT_GLB = ART / "oc_q.glb"
RES_GLB = GAME / "myroom" / "placeholder" / "oc_q.glb"
BUILD = ART / "scripts" / "build_oc_q.py"

spec = importlib.util.spec_from_file_location("build_oc_q", BUILD)
bq = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bq)

# Concept front content is 1018px tall / 690px wide. Height 1.10m → width 0.745m.
H = 1.10
CHAR_W = H * 690 / 1018

# Vertical bands as fractions of height from the soles (measured on the front sheet).
LAYOUT = {
    "shoes": {"z0": 0.00 * H, "z1": 0.100 * H, "width": 0.34 * CHAR_W, "depth": 0.20 * CHAR_W},
    "legs": {"z0": 0.090 * H, "z1": 0.230 * H, "width": 0.28 * CHAR_W, "depth": 0.12 * CHAR_W},
    "skirt": {"z0": 0.225 * H, "z1": 0.300 * H, "width": 0.32 * CHAR_W, "depth": 0.16 * CHAR_W},
    "clothes": {"z0": 0.270 * H, "z1": 0.580 * H, "width": 0.50 * CHAR_W, "depth": 0.28 * CHAR_W},
    "hands": {"z0": 0.275 * H, "z1": 0.365 * H, "width": 0.10 * CHAR_W},
    "head": {"z0": 0.520 * H, "z1": 0.800 * H, "width": 0.40 * CHAR_W},
    "face": {"z0": 0.535 * H, "z1": 0.790 * H, "width": 0.36 * CHAR_W},
    "hair": {"z0": 0.530 * H, "z1": 1.000 * H, "width": 0.82 * CHAR_W},
}

PART_FILES = {
    "hair": PARTS / "hair" / "hair.glb",
    "head": PARTS / "head" / "head.glb",
    "face": PARTS / "face" / "face.glb",
    "clothes": PARTS / "clothes" / "clothes.glb",
    "hands": PARTS / "hands" / "hands.glb",
    "skirt": PARTS / "skirt" / "skirt.glb",
    "legs": PARTS / "legs" / "legs.glb",
    "shoes": PARTS / "shoes" / "shoes.glb",
}


def view3d_override():
    win = bpy.context.window
    if win is None:
        return None
    for area in win.screen.areas:
        if area.type != "VIEW_3D":
            continue
        region = next((r for r in area.regions if r.type == "WINDOW"), None)
        if region:
            return {
                "window": win,
                "screen": win.screen,
                "area": area,
                "region": region,
                "scene": bpy.context.scene,
                "view_layer": bpy.context.view_layer,
            }
    return None


def apply_tr(obj):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    ov = view3d_override()
    if ov:
        ov["active_object"] = obj
        ov["object"] = obj
        ov["selected_objects"] = [obj]
        with bpy.context.temp_override(**ov):
            bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    else:
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def world_bounds(obj):
    corners = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    xs = [c.x for c in corners]
    ys = [c.y for c in corners]
    zs = [c.z for c in corners]
    return min(xs), max(xs), min(ys), max(ys), min(zs), max(zs)


def size_xyz(obj):
    x0, x1, y0, y1, z0, z1 = world_bounds(obj)
    return x1 - x0, y1 - y0, z1 - z0


def center_xy(obj):
    x0, x1, y0, y1, _, _ = world_bounds(obj)
    obj.location.x -= (x0 + x1) * 0.5
    obj.location.y -= (y0 + y1) * 0.5
    apply_tr(obj)


def move_min_z(obj, z_target):
    _, _, _, _, z0, _ = world_bounds(obj)
    obj.location.z += z_target - z0
    apply_tr(obj)


def scale_uniform(obj, factor):
    obj.scale = (factor, factor, factor)
    apply_tr(obj)


def scale_box(obj, target_w, target_h, target_d=None):
    dx, dy, dz = size_xyz(obj)
    sx = target_w / max(dx, 1e-5)
    sz = target_h / max(dz, 1e-5)
    sy = (target_d / max(dy, 1e-5)) if target_d else (sx + sz) * 0.5
    obj.scale = (sx, sy, sz)
    apply_tr(obj)


def remesh_smooth(obj, voxel=0.010):
    mod = obj.modifiers.new("Remesh", "REMESH")
    mod.mode = "VOXEL"
    mod.voxel_size = voxel
    bpy.context.view_layer.update()
    deps = bpy.context.evaluated_depsgraph_get()
    eval_obj = obj.evaluated_get(deps)
    new_mesh = bpy.data.meshes.new_from_object(eval_obj, depsgraph=deps)
    for m in list(obj.modifiers):
        obj.modifiers.remove(m)
    old = obj.data
    obj.data = new_mesh
    bpy.data.meshes.remove(old)
    for p in obj.data.polygons:
        p.use_smooth = True


def decimate(obj, target=7000):
    faces = len(obj.data.polygons)
    if faces <= target:
        return
    mod = obj.modifiers.new("Decimate", "DECIMATE")
    mod.ratio = max(0.06, target / faces)
    bpy.context.view_layer.update()
    deps = bpy.context.evaluated_depsgraph_get()
    eval_obj = obj.evaluated_get(deps)
    new_mesh = bpy.data.meshes.new_from_object(eval_obj, depsgraph=deps)
    for m in list(obj.modifiers):
        obj.modifiers.remove(m)
    old = obj.data
    obj.data = new_mesh
    bpy.data.meshes.remove(old)
    print(obj.name, "decimate", faces, "->", len(obj.data.polygons))


def join_imported(name: str) -> bpy.types.Object:
    meshes = [o for o in bpy.context.selected_objects if o.type == "MESH"]
    extras = [o for o in bpy.context.selected_objects if o.type != "MESH"]
    for o in extras:
        bpy.data.objects.remove(o, do_unlink=True)
    if not meshes:
        raise RuntimeError(f"no mesh in {name}")
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = name
    obj.location = (0, 0, 0)
    obj.rotation_euler = (0, 0, 0)
    obj.scale = (1, 1, 1)
    apply_tr(obj)
    for p in obj.data.polygons:
        p.use_smooth = True
    return obj


def import_glb(path: Path, name: str) -> bpy.types.Object:
    bpy.ops.import_scene.gltf(filepath=str(path))
    obj = join_imported(name)
    decimate(obj, 7000)
    return obj


def rotate_obj(obj, euler):
    obj.rotation_euler = Euler(euler, "XYZ")
    apply_tr(obj)


def remap_to_xyz(obj, src_for_x: int, src_for_y: int, src_for_z: int, flip=(1, 1, 1)):
    """Rotate so current axes (0=X,1=Y,2=Z) become world X,Y,Z."""
    # Build a permutation via 90° rotations. Easier: apply matrix from axis map.
    axes = [Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))]
    mx = axes[src_for_x] * flip[0]
    my = axes[src_for_y] * flip[1]
    mz = axes[src_for_z] * flip[2]
    # columns of rotation: where unit X/Y/Z go
    from mathutils import Matrix

    rot = Matrix((mx, my, mz)).transposed()
    obj.matrix_world = rot.to_4x4() @ obj.matrix_world
    apply_tr(obj)


def axis_extents(obj):
    dx, dy, dz = size_xyz(obj)
    return [(0, dx), (1, dy), (2, dz)]


def pair_axis(obj) -> int:
    """Axis along which vertices form two clusters (legs / shoes)."""
    mesh = obj.data
    coords = [v.co.copy() for v in mesh.vertices]
    best_i, best_score = 0, -1.0
    for i in range(3):
        vals = [c[i] for c in coords]
        lo, hi = min(vals), max(vals)
        if hi - lo < 1e-4:
            continue
        mid = (lo + hi) * 0.5
        left = [v for v in vals if v < mid]
        right = [v for v in vals if v >= mid]
        if not left or not right:
            continue
        gap = min(right) - max(left) if min(right) > max(left) else 0.0
        sep = abs(sum(left) / len(left) - sum(right) / len(right)) / (hi - lo)
        score = sep + gap / (hi - lo)
        if score > best_score:
            best_score = score
            best_i = i
    return best_i


def end_openness(obj, axis: int, sign: int) -> float:
    """Smaller value ≈ more of a hole / thinner cap (neck, shoe opening)."""
    x0, x1, y0, y1, z0, z1 = world_bounds(obj)
    mins = (x0, y0, z0)
    maxs = (x1, y1, z1)
    span = maxs[axis] - mins[axis]
    cut = (maxs[axis] if sign > 0 else mins[axis]) - sign * span * 0.12
    xs, ys = [], []
    for v in obj.data.vertices:
        w = obj.matrix_world @ v.co
        val = w[axis]
        if sign > 0 and val < cut:
            continue
        if sign < 0 and val > cut:
            continue
        others = [w[j] for j in range(3) if j != axis]
        xs.append(others[0])
        ys.append(others[1])
    if len(xs) < 8:
        return 1.0
    area = (max(xs) - min(xs)) * (max(ys) - min(ys))
    return area


def orient_generic(obj, kind: str):
    """Put pair-width on X, depth on Y, height on Z. Face -Y when it matters."""
    if kind in {"head", "face", "hands"}:
        # Spheres: make the two ear/thumb blobs sit on X if we can.
        i = pair_axis(obj)
        extents = axis_extents(obj)
        others = [a for a, _s in extents if a != i]
        # thumb/ears -> X
        remap_to_xyz(obj, i, others[0], others[1])
        return

    if kind in {"legs", "shoes"}:
        px = pair_axis(obj)
        extents = sorted(axis_extents(obj), key=lambda t: t[1], reverse=True)
        # height is usually the longest remaining after pair axis
        rest = [a for a, _s in extents if a != px]
        # taller remaining → Z
        hz = rest[0] if size_xyz(obj)[rest[0]] >= size_xyz(obj)[rest[1]] else rest[1]
        hy = rest[1] if hz == rest[0] else rest[0]
        remap_to_xyz(obj, px, hy, hz)
        # shoe opening / leg top should be +Z
        top = end_openness(obj, 2, +1)
        bot = end_openness(obj, 2, -1)
        if kind == "shoes" and bot < top:
            rotate_obj(obj, (math.pi, 0, 0))
        if kind == "legs" and top > bot * 1.15:
            # more mass on +Z means we might be upside down
            pass
        return

    # hair / clothes / skirt: widest → X, second → Z (up), smallest → Y (depth)
    extents = sorted(axis_extents(obj), key=lambda t: t[1], reverse=True)
    wx, hz, hy = extents[0][0], extents[1][0], extents[2][0]
    remap_to_xyz(obj, wx, hy, hz)
    if kind == "clothes":
        top = end_openness(obj, 2, +1)
        bot = end_openness(obj, 2, -1)
        if bot < top:
            rotate_obj(obj, (math.pi, 0, 0))
        front = end_openness(obj, 1, -1)
        back = end_openness(obj, 1, +1)
        if front > back * 1.05:
            rotate_obj(obj, (0, 0, math.pi))


def paint(obj, mat):
    mesh = obj.data
    mesh.materials.clear()
    mesh.materials.append(mat)


def add_eyes(face, mats):
    x0, x1, y0, y1, z0, z1 = world_bounds(face)
    fy = y0 - 0.004
    ez = z0 + (z1 - z0) * 0.52
    span = x1 - x0
    eyes = []
    for sx, tag in ((-1.0, "L"), (1.0, "R")):
        ex = sx * span * 0.22
        eyes.append(bq.make_sphere(f"Eye{tag}W", 0.028, 16, 10, mats["white"], (ex, fy, ez), scale=(0.95, 0.32, 1.12)))
        eyes.append(bq.make_sphere(f"Eye{tag}I", 0.018, 14, 10, mats["iris"], (ex, fy - 0.006, ez - 0.002), scale=(0.95, 0.34, 1.05)))
        eyes.append(bq.make_sphere(f"Eye{tag}P", 0.007, 10, 8, mats["pupil"], (ex, fy - 0.010, ez)))
        eyes.append(bq.make_sphere(f"Eye{tag}H", 0.006, 8, 6, mats["white"], (ex - sx * 0.006, fy - 0.012, ez + 0.008)))
        eyes.append(
            bq.make_sphere(
                f"Blush{tag}",
                0.016,
                10,
                8,
                mats["blush"],
                (sx * span * 0.30, fy + 0.006, ez - 0.042),
                scale=(1.15, 0.28, 0.55),
            )
        )
    mouth = bq.make_sphere("Mouth", 0.010, 10, 8, mats["coral"], (0.0, fy - 0.002, ez - 0.055), scale=(1.6, 0.35, 0.45))
    eyes.append(mouth)
    return eyes


def export_glb(path, objects):
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    active = None
    for o in objects:
        if o is None:
            continue
        o.hide_set(False)
        o.hide_viewport = False
        o.select_set(True)
        if o.type == "ARMATURE":
            active = o
    if active:
        bpy.context.view_layer.objects.active = active
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_animations=True,
        export_skins=True,
        export_morph=True,
        export_materials="EXPORT",
        export_cameras=False,
        export_lights=False,
        export_nla_strips=True,
    )
    print("EXPORTED", path, "bytes", path.stat().st_size)


def main():
    bq.clear_scene()
    bq.BINDS.clear()

    mats = {
        "skin": bq.mat("Skin", bq.C_SKIN, 0.72),
        "hair": bq.mat("Hair", bq.C_HAIR, 0.48),
        "cream": bq.mat("Cream", bq.C_CREAM, 0.62),
        "coral": bq.mat("Coral", bq.C_CORAL, 0.5),
        "char": bq.mat("Charcoal", bq.C_CHAR, 0.58),
        "mint": bq.mat("Mint", bq.C_MINT, 0.5),
        "boot": bq.mat("Boot", bq.C_BOOT, 0.42),
        "iris": bq.mat("Iris", bq.C_IRIS, 0.35),
        "pupil": bq.mat("Pupil", bq.C_PUPIL, 0.4),
        "white": bq.mat("White", bq.C_WHITE, 0.45),
        "blush": bq.mat("Blush", bq.C_BLUSH, 0.8),
    }
    paint_of = {
        "hair": mats["hair"],
        "head": mats["skin"],
        "face": mats["skin"],
        "clothes": mats["cream"],
        "hands": mats["skin"],
        "skirt": mats["char"],
        "legs": mats["skin"],
        "shoes": mats["boot"],
    }

    objs = {}
    for kind, path in PART_FILES.items():
        print("import", kind, path)
        obj = import_glb(path, f"Part_{kind.capitalize()}")
        orient_generic(obj, kind)
        center_xy(obj)
        lay = LAYOUT[kind]
        target_h = lay["z1"] - lay["z0"]
        target_w = lay["width"]
        if kind == "hair":
            remesh_smooth(obj, 0.016)
            decimate(obj, 8000)
        if kind in {"head", "face", "hands", "hair"}:
            scale_uniform(obj, target_w / max(size_xyz(obj)[0], 1e-5))
        else:
            scale_box(obj, target_w, target_h, lay.get("depth"))
        center_xy(obj)
        move_min_z(obj, lay["z0"])
        paint(obj, paint_of[kind])
        objs[kind] = obj
        print(kind, "size", tuple(round(v, 3) for v in size_xyz(obj)), "z", round(world_bounds(obj)[4], 3), round(world_bounds(obj)[5], 3))

    # Head sits inside the hair; face is a touch forward so the face reads -Y.
    head = objs["head"]
    face = objs["face"]
    hair = objs["hair"]
    hx0, hx1, hy0, hy1, hz0, hz1 = world_bounds(hair)
    # Center head on hair mass, a bit forward of the hair back.
    # Sit the skull on the hoodie collar (close the neck gap).
    _cx0, _cx1, _cy0, _cy1, _cz0, cz1 = world_bounds(objs["clothes"])
    hz0 = world_bounds(head)[4]
    drop = hz0 - (cz1 - 0.035)
    head.location.z -= drop
    hair.location.z -= drop
    apply_tr(head)
    apply_tr(hair)
    head.location.y = (hy0 + hy1) * 0.5 - 0.02
    apply_tr(head)
    # Match face to head center, nudge toward -Y (camera).
    fx0, fx1, fy0, fy1, fz0, fz1 = world_bounds(face)
    hx0, hx1, hy0, hy1, hz0, hz1 = world_bounds(head)
    face.location.x += (hx0 + hx1) * 0.5 - (fx0 + fx1) * 0.5
    face.location.y += hy0 - fy0 - 0.012
    face.location.z += (hz0 + hz1) * 0.5 - (fz0 + fz1) * 0.5
    apply_tr(face)

    # Duplicate the single dumpling hand.
    hand_src = objs["hands"]
    bpy.ops.object.select_all(action="DESELECT")
    hand_src.select_set(True)
    bpy.context.view_layer.objects.active = hand_src
    bpy.ops.object.duplicate()
    hand_r = bpy.context.view_layer.objects.active
    hand_r.name = "Part_Hands_R"
    hand_src.name = "Part_Hands_L"
    clothes = objs["clothes"]
    cx0, cx1, cy0, cy1, cz0, cz1 = world_bounds(clothes)
    hem_z = cz0 + (cz1 - cz0) * 0.06
    span = (cx1 - cx0) * 0.48
    hand_src.location.x = -span
    hand_src.location.z += hem_z - world_bounds(hand_src)[4]
    apply_tr(hand_src)
    hand_r.scale.x *= -1
    apply_tr(hand_r)
    hand_r.location.x = span
    hand_r.location.z += hem_z - world_bounds(hand_r)[4]
    apply_tr(hand_r)
    # Re-center Y on torso
    for h in (hand_src, hand_r):
        _x0, _x1, y0, y1, _, _ = world_bounds(h)
        h.location.y -= (y0 + y1) * 0.5
        apply_tr(h)

    # Sock tint: lower 40% of legs → mint (vertex color via two materials).
    legs = objs["legs"]
    lx0, lx1, ly0, ly1, lz0, lz1 = world_bounds(legs)
    cut = lz0 + (lz1 - lz0) * 0.42
    legs.data.materials.clear()
    legs.data.materials.append(mats["skin"])
    legs.data.materials.append(mats["mint"])
    for poly in legs.data.polygons:
        zs = [(legs.matrix_world @ legs.data.vertices[i].co).z for i in poly.vertices]
        poly.material_index = 1 if sum(zs) / len(zs) < cut else 0

    # Shoe soles: lowest 18% mint.
    shoes = objs["shoes"]
    sx0, sx1, sy0, sy1, sz0, sz1 = world_bounds(shoes)
    sole = sz0 + (sz1 - sz0) * 0.18
    shoes.data.materials.clear()
    shoes.data.materials.append(mats["boot"])
    shoes.data.materials.append(mats["mint"])
    for poly in shoes.data.polygons:
        zs = [(shoes.matrix_world @ shoes.data.vertices[i].co).z for i in poly.vertices]
        poly.material_index = 1 if sum(zs) / len(zs) < sole else 0

    eyes = add_eyes(face, mats)

    # Simple coral bow on the hoodie chest.
    cx0, cx1, cy0, cy1, cz0, cz1 = world_bounds(clothes)
    bow_z = cz0 + (cz1 - cz0) * 0.78
    for b in bq.make_bow("Scarf", (0.0, cy0 - 0.004, bow_z), mats["coral"], s=0.85):
        eyes.append(b)

    # Bind
    bq.BINDS.clear()
    bq.track(hair, "Head")
    bq.track(head, "Head")
    bq.track(face, "Head")
    bq.track(clothes, "Chest")
    bq.track(objs["skirt"], "Hips")
    bq.track(legs, "Hips")
    bq.track(shoes, "Root")
    bq.track(hand_src, "ArmL")
    bq.track(hand_r, "ArmR")
    for e in eyes:
        bq.track(e, "Head")

    arm = bq.build_armature()
    bq.bind_parts(arm)
    bq.make_idle(arm)
    bq.add_shape_keys()

    for o in bpy.context.scene.objects:
        if o.type == "MESH":
            o.hide_set(False)
        elif o.type == "ARMATURE":
            o.hide_set(True)

    exportables = [arm]
    for o in bpy.context.scene.objects:
        if o.type == "MESH" and not o.hide_get():
            exportables.append(o)

    OUT_BLEND.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT_BLEND))
    export_glb(OUT_GLB, exportables)
    export_glb(RES_GLB, exportables)
    print("DONE assemble height", round(max(world_bounds(o)[5] for o in exportables if o.type == "MESH"), 3))


if __name__ == "__main__":
    main()
