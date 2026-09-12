"""
Assemble Hunyuan part meshes + procedural lower body with palette materials.
No concept-image sticker UVs.
"""
from __future__ import annotations

import importlib.util
import math
import traceback
from pathlib import Path

import bpy
from mathutils import Euler, Vector

try:
    ART = Path(__file__).resolve().parent.parent
except NameError:
    ART = Path("/Users/qihongrui/Desktop/project/profile-v1/app_games/9dot-music/art/myroom_oc")

GAME = ART.parent.parent
OUT_BLEND = ART / "oc_q.blend"
OUT_GLB = ART / "oc_q.glb"
RES_GLB = GAME / "myroom" / "placeholder" / "oc_q.glb"
BUILD = ART / "scripts" / "build_oc_q.py"

spec = importlib.util.spec_from_file_location("build_oc_q", BUILD)
bq = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bq)


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


def apply_mods(obj):
    if not obj.modifiers:
        return
    bpy.context.view_layer.update()
    deps = bpy.context.evaluated_depsgraph_get()
    eval_obj = obj.evaluated_get(deps)
    new_mesh = bpy.data.meshes.new_from_object(eval_obj, depsgraph=deps)
    for m in list(obj.modifiers):
        obj.modifiers.remove(m)
    old = obj.data
    obj.data = new_mesh
    bpy.data.meshes.remove(old)


def decimate(obj, target=6000):
    faces = len(obj.data.polygons)
    if faces <= target:
        return
    mod = obj.modifiers.new("Decimate", "DECIMATE")
    mod.ratio = max(0.08, target / faces)
    apply_mods(obj)
    print(obj.name, "faces", len(obj.data.polygons))


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


def normalize_part(obj, name):
    obj.hide_set(False)
    obj.hide_viewport = False
    obj.name = name
    obj.location = (0, 0, 0)
    obj.rotation_euler = (0, 0, 0)
    obj.scale = (1, 1, 1)
    apply_tr(obj)
    for p in obj.data.polygons:
        p.use_smooth = True
    decimate(obj, 6500)
    # origin to bbox center xz, min z later per-part
    return obj


def scale_to_height(obj, height):
    _, _, _, _, z0, z1 = world_bounds(obj)
    h = z1 - z0
    if h < 1e-5:
        return
    s = height / h
    obj.scale = (s, s, s)
    apply_tr(obj)


def move_min_z(obj, z_target):
    _, _, _, _, z0, _ = world_bounds(obj)
    obj.location.z += z_target - z0
    apply_tr(obj)


def center_xy(obj):
    x0, x1, y0, y1, _, _ = world_bounds(obj)
    obj.location.x -= (x0 + x1) * 0.5
    obj.location.y -= (y0 + y1) * 0.5
    apply_tr(obj)


def assign_slots(obj, mats_and_pred):
    """mats_and_pred: list of (material, vertex_predicate). Last is default."""
    mesh = obj.data
    mesh.materials.clear()
    for mat, _pred in mats_and_pred:
        mesh.materials.append(mat)
    # polygon slot = majority of its verts
    preds = [pred for _m, pred in mats_and_pred]
    vert_slot = []
    for v in mesh.vertices:
        slot = len(preds) - 1
        for i, pred in enumerate(preds):
            if pred(v.co):
                slot = i
                break
        vert_slot.append(slot)
    for poly in mesh.polygons:
        votes = [vert_slot[i] for i in poly.vertices]
        poly.material_index = max(set(votes), key=votes.count)


def is_flat(obj, min_ratio=0.22):
    x0, x1, y0, y1, z0, z1 = world_bounds(obj)
    dims = sorted([x1 - x0, y1 - y0, z1 - z0])
    return dims[0] / max(dims[2], 1e-5) < min_ratio


def paint_solid(obj, mat):
    mesh = obj.data
    mesh.materials.clear()
    mesh.materials.append(mat)


def ensure_face(m_skin):
    """Volumetric Hunyuan head, or a smooth Q sphere if the part came back as a plaque."""
    face = bpy.data.objects.get("Part_Face")
    if face is not None and not is_flat(face):
        normalize_part(face, "Part_Face")
        scale_to_height(face, 0.28)
        center_xy(face)
        move_min_z(face, 0.72)
        paint_solid(face, m_skin)
        return face
    if face is not None:
        face.hide_set(True)
        if "FLAT" not in face.name:
            face.name = "Part_Face_FLAT_DISCARD"
    obj = bq.make_sphere("Part_Face", 0.132, 32, 16, m_skin, (0.0, 0.02, 0.86), scale=(1.04, 0.92, 1.00))
    return obj


def add_eyes(m_white, m_iris, m_pupil, m_blush):
    head = bpy.data.objects.get("Part_Face") or bpy.data.objects["Part_Hair"]
    x0, x1, y0, y1, z0, z1 = world_bounds(head)
    face_y = y0 - 0.012
    ez = z0 + (z1 - z0) * 0.52
    span = max(x1 - x0, 0.18)
    for sx, tag in ((-1.0, "L"), (1.0, "R")):
        ex = sx * span * 0.22
        bq.track(bq.make_sphere(f"Eye{tag}W", 0.038, 16, 10, m_white, (ex, face_y, ez), scale=(0.95, 0.28, 1.15)), "Head")
        bq.track(bq.make_sphere(f"Eye{tag}I", 0.024, 14, 10, m_iris, (ex, face_y - 0.008, ez - 0.003), scale=(0.95, 0.32, 1.05)), "Head")
        bq.track(bq.make_sphere(f"Eye{tag}P", 0.010, 10, 8, m_pupil, (ex, face_y - 0.014, ez - 0.002)), "Head")
        bq.track(bq.make_sphere(f"Eye{tag}H", 0.009, 8, 6, m_white, (ex - sx * 0.009, face_y - 0.018, ez + 0.011)), "Head")
        bq.track(
            bq.make_sphere(f"Blush{tag}", 0.022, 10, 8, m_blush, (sx * span * 0.32, face_y + 0.008, ez - 0.055), scale=(1.1, 0.3, 0.55)),
            "Head",
        )


def add_lower(m_char, m_skin, m_mint, m_boot, m_coral, m_cream):
    bq.track(bq.make_cyl("SkirtBase", 0.13, 0.17, 0.10, 20, m_char, (0, 0.0, 0.355)), "Hips")
    for i in range(10):
        ang = i * (2 * math.pi / 10)
        x, y = math.sin(ang) * 0.145, math.cos(ang) * 0.11
        bq.track(
            bq.make_cube(f"Pleat{i}", 0.055, m_char, (x, y, 0.35), scale=(0.4, 0.5, 1.0), rot=(0, 0, ang), bevel=0.004),
            "Hips",
        )
    for sx, tag in ((-1.0, "L"), (1.0, "R")):
        bq.track(bq.make_cyl(f"Leg{tag}", 0.036, 0.038, 0.13, 14, m_skin, (sx * 0.06, 0.0, 0.25)), f"Leg{tag}")
        bq.track(bq.make_cyl(f"Sock{tag}", 0.040, 0.042, 0.085, 14, m_mint, (sx * 0.06, 0.0, 0.145)), f"Leg{tag}")
        bq.track(
            bq.make_cube(f"Shoe{tag}", 0.085, m_boot, (sx * 0.06, 0.028, 0.048), scale=(0.88, 1.65, 0.62), bevel=0.012),
            f"Leg{tag}",
        )
        bq.track(
            bq.make_cube(f"Sole{tag}", 0.085, m_mint, (sx * 0.06, 0.03, 0.012), scale=(0.94, 1.72, 0.28), bevel=0.008),
            f"Leg{tag}",
        )
        bq.track(
            bq.make_cube(f"Stripe{tag}", 0.048, m_coral, (sx * 0.06, 0.068, 0.05), scale=(0.5, 0.2, 0.3), bevel=0.004),
            f"Leg{tag}",
        )


def add_hoodie_accents(m_coral, m_mint, m_clover):
    hoodie = bpy.data.objects["Part_Hoodie"]
    x0, x1, y0, y1, z0, z1 = world_bounds(hoodie)
    fy = y0 - 0.002
    midz = z0 + (z1 - z0) * 0.72
    for b in bq.make_bow("Scarf", (0, fy, midz), m_coral, s=1.05):
        bq.track(b, "Chest")
    bq.track(
        bq.make_cyl("Badge", 0.02, 0.02, 0.01, 16, m_mint, ((x1 - x0) * 0.18, fy, midz - 0.04), rot=(math.radians(90), 0, 0)),
        "Chest",
    )
    for c in bq.make_clover("BadgeClover", ((x1 - x0) * 0.18, fy - 0.006, midz - 0.04), m_clover, 0.01):
        bq.track(c, "Chest")


def bind_all(arm):
    parts = []
    for obj, bone in bq.BINDS:
        parts.append((obj, bone))
    # hunyuan / assembled volumes
    parts.append((bpy.data.objects["Part_Hair"], "Head"))
    if "Part_Face" in bpy.data.objects:
        parts.append((bpy.data.objects["Part_Face"], "Head"))
    parts.append((bpy.data.objects["Part_Hoodie"], "Chest"))
    for obj, bone in parts:
        if obj.type != "MESH" or not obj.data.vertices:
            continue
        if bone not in [g.name for g in obj.vertex_groups]:
            vg = obj.vertex_groups.new(name=bone)
            vg.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
        mod = next((m for m in obj.modifiers if m.type == "ARMATURE"), None)
        if mod is None:
            mod = obj.modifiers.new("Armature", "ARMATURE")
        mod.object = arm
        mod.use_vertex_groups = True
        obj.parent = arm


def export_glb(path, objects):
    path.parent.mkdir(parents=True, exist_ok=True)
    for o in bpy.context.scene.objects:
        o.select_set(False)
    for o in objects:
        if o is None:
            continue
        o.hide_set(False)
        o.select_set(True)
        if o.type == "ARMATURE":
            bpy.context.view_layer.objects.active = o
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
    print("EXPORTED", path)


def collect_exportables(arm):
    """Visible meshes of the current assembly. Skip leftover Hunyuan plaques."""
    skip = ("DISCARD", "COMBINED_OLD", "_FLAT")
    out = [arm]
    for o in bpy.context.scene.objects:
        if o.type != "MESH" or o.hide_get() or o.hide_viewport:
            continue
        if any(k in o.name for k in skip):
            continue
        if o.parent == arm or o.name in {"Part_Hair", "Part_Face", "Part_Hoodie"}:
            out.append(o)
    return out


def main():
    bq.BINDS.clear()
    hair = bpy.data.objects.get("Part_Hair")
    hoodie = bpy.data.objects.get("Part_Hoodie")
    if hair is None or hoodie is None:
        raise RuntimeError("Need Part_Hair and Part_Hoodie in the scene")

    keep = {hair, hoodie}
    face_existing = bpy.data.objects.get("Part_Face")
    if face_existing is not None:
        keep.add(face_existing)
    for o in bpy.context.scene.objects:
        if o not in keep and o.type in {"MESH", "ARMATURE"} and not o.name.startswith("Studio"):
            o.hide_set(True)

    normalize_part(hair, "Part_Hair")
    normalize_part(hoodie, "Part_Hoodie")

    scale_to_height(hair, 0.42)
    center_xy(hair)
    move_min_z(hair, 0.68)

    scale_to_height(hoodie, 0.32)
    center_xy(hoodie)
    move_min_z(hoodie, 0.36)

    m_skin = bq.mat("Skin", bq.C_SKIN, 0.72)
    m_hair = bq.mat("Hair", bq.C_HAIR, 0.48)
    m_cream = bq.mat("Cream", bq.C_CREAM, 0.62)
    m_coral = bq.mat("Coral", bq.C_CORAL, 0.5)
    m_char = bq.mat("Charcoal", bq.C_CHAR, 0.58)
    m_mint = bq.mat("Mint", bq.C_MINT, 0.5)
    m_boot = bq.mat("Boot", bq.C_BOOT, 0.42)
    m_iris = bq.mat("Iris", bq.C_IRIS, 0.35)
    m_pupil = bq.mat("Pupil", bq.C_PUPIL, 0.4)
    m_white = bq.mat("White", bq.C_WHITE, 0.45)
    m_blush = bq.mat("Blush", bq.C_BLUSH, 0.8)
    m_clover = bq.mat("Clover", bq.C_CLOVER, 0.55)

    paint_solid(hair, m_hair)
    paint_solid(hoodie, m_cream)
    ensure_face(m_skin)

    add_eyes(m_white, m_iris, m_pupil, m_blush)
    add_hoodie_accents(m_coral, m_mint, m_clover)
    add_lower(m_char, m_skin, m_mint, m_boot, m_coral, m_cream)

    arm = bq.build_armature()
    bind_all(arm)
    bq.make_idle(arm)

    # unhide assembled
    for o in bpy.context.scene.objects:
        if o.type == "MESH" and (o.name.startswith("Part_") or o.parent == arm):
            o.hide_set(False)
        elif o.type == "ARMATURE":
            o.hide_set(True)

    ov = view3d_override()
    if ov:
        space = ov["area"].spaces.active
        space.shading.type = "SOLID"
        space.shading.light = "STUDIO"
        space.shading.color_type = "MATERIAL"
        space.overlay.show_overlays = False
        r3d = space.region_3d
        r3d.view_location = (0, 0, 0.55)
        r3d.view_distance = 2.1
        r3d.view_rotation = Euler((math.radians(80), 0, 0), "XYZ").to_quaternion()

    objs = collect_exportables(arm)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT_BLEND))
    export_glb(OUT_GLB, objs)
    export_glb(RES_GLB, objs)
    print("DONE parts", [o.name for o in objs if o.type == "MESH"][:20])


if __name__ == "__main__":
    try:
        main()
    except Exception:
        traceback.print_exc()
        raise
