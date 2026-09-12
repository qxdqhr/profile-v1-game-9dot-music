"""
Refine a Hunyuan-generated OC mesh for MyRoom.
Expects the generated mesh already in the scene (typical name geometry_0*).
Exports: art/myroom_oc/ai_raw/oc_q_ai_raw.glb, oc_q.glb, myroom/placeholder/oc_q.glb
"""
from __future__ import annotations

import math
import traceback
from pathlib import Path

import bpy
from mathutils import Euler, Matrix, Vector

try:
    ART = Path(__file__).resolve().parent.parent
except NameError:
    ART = Path("/Users/qihongrui/Desktop/project/profile-v1/app_games/9dot-music/art/myroom_oc")

GAME = ART.parent.parent
AI_RAW = ART / "ai_raw"
OUT_BLEND = ART / "oc_q.blend"
OUT_GLB = ART / "oc_q.glb"
RES_GLB = GAME / "myroom" / "placeholder" / "oc_q.glb"
CONCEPT = ART / "concept" / "oc_q_concept_front.png"
TARGET_HEIGHT = 1.08


def view3d_override() -> dict | None:
    win = bpy.context.window
    if win is None:
        return None
    for area in win.screen.areas:
        if area.type != "VIEW_3D":
            continue
        region = next((r for r in area.regions if r.type == "WINDOW"), None)
        if region is None:
            continue
        return {
            "window": win,
            "screen": win.screen,
            "area": area,
            "region": region,
            "scene": bpy.context.scene,
            "view_layer": bpy.context.view_layer,
        }
    return None


def set_mode(mode: str) -> None:
    ov = view3d_override()
    obj = bpy.context.view_layer.objects.active
    if ov and obj:
        ov["active_object"] = obj
        ov["object"] = obj
        ov["selected_objects"] = [obj]
        with bpy.context.temp_override(**ov):
            bpy.ops.object.mode_set(mode=mode)
    else:
        bpy.ops.object.mode_set(mode=mode)


def apply_modifiers(obj: bpy.types.Object) -> None:
    if not obj.modifiers:
        return
    bpy.context.view_layer.update()
    deps = bpy.context.evaluated_depsgraph_get()
    eval_obj = obj.evaluated_get(deps)
    new_mesh = bpy.data.meshes.new_from_object(eval_obj, depsgraph=deps)
    new_mesh.name = obj.data.name + "_eval"
    for mod in list(obj.modifiers):
        obj.modifiers.remove(mod)
    old = obj.data
    obj.data = new_mesh
    bpy.data.meshes.remove(old)


def pick_hunyuan_mesh() -> bpy.types.Object:
    candidates = [
        o
        for o in bpy.context.scene.objects
        if o.type == "MESH" and o.name.startswith("geometry_0")
    ]
    if not candidates:
        dense = [
            o
            for o in bpy.context.scene.objects
            if o.type == "MESH" and len(o.data.vertices) > 8000
        ]
        candidates = dense
    if not candidates:
        raise RuntimeError("No Hunyuan mesh found (expected geometry_0*)")
    candidates.sort(key=lambda o: len(o.data.vertices), reverse=True)
    return candidates[0]


def isolate(keep: bpy.types.Object) -> None:
    keep.hide_set(False)
    keep.hide_viewport = False
    for o in list(bpy.context.scene.objects):
        if o == keep:
            continue
        if o.name.startswith("Studio"):
            o.hide_set(True)
            continue
        if o.type == "MESH" and o.name.startswith("geometry_0") and o != keep:
            bpy.data.objects.remove(o, do_unlink=True)
            continue
        o.hide_set(True)
        o.hide_render = True


def origin_feet_and_scale(obj: bpy.types.Object) -> None:
    bpy.context.view_layer.update()
    corners = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    min_z = min(c.z for c in corners)
    cx = (min(c.x for c in corners) + max(c.x for c in corners)) * 0.5
    cy = (min(c.y for c in corners) + max(c.y for c in corners)) * 0.5
    inv = obj.matrix_world.inverted()
    delta = obj.matrix_world @ Vector((0, 0, 0))  # noqa: F841
    offset = Vector((cx, cy, min_z))
    local_off = inv @ offset
    for v in obj.data.vertices:
        v.co -= local_off
    obj.data.update()
    obj.location = (0.0, 0.0, 0.0)
    bpy.context.view_layer.update()
    height = max((obj.matrix_world @ v.co).z for v in obj.data.vertices)
    if height < 1e-4:
        raise RuntimeError("Mesh has no height")
    s = TARGET_HEIGHT / height
    obj.scale = (s, s, s)
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
    for p in obj.data.polygons:
        p.use_smooth = True
    print("SCALED height", TARGET_HEIGHT, "from", round(height, 3), "factor", round(s, 3))


def decimate(obj: bpy.types.Object, ratio: float = 0.14) -> None:
    faces = len(obj.data.polygons)
    print("FACES_BEFORE", faces)
    if faces <= 14000:
        return
    # Aim ~10k faces
    want = 10000 / max(faces, 1)
    ratio = max(0.08, min(ratio, want))
    mod = obj.modifiers.new("Decimate", "DECIMATE")
    mod.ratio = ratio
    apply_modifiers(obj)
    print("FACES_AFTER", len(obj.data.polygons))


def crop_concept_image() -> bpy.types.Image:
    src = bpy.data.images.load(str(CONCEPT), check_existing=True)
    w, h = src.size
    pix = list(src.pixels)

    def is_bg(r, g, b):
        avg = (r + g + b) / 3.0
        return abs(r - g) < 0.05 and abs(g - b) < 0.05 and 0.52 < avg < 0.88

    mins, maxs = [w, h], [0, 0]
    for y in range(h):
        for x in range(w):
            i = (y * w + x) * 4
            r, g, b = pix[i], pix[i + 1], pix[i + 2]
            if not is_bg(r, g, b):
                mins[0] = min(mins[0], x)
                mins[1] = min(mins[1], y)
                maxs[0] = max(maxs[0], x)
                maxs[1] = max(maxs[1], y)
    margin = 8
    x0, y0 = max(0, mins[0] - margin), max(0, mins[1] - margin)
    x1, y1 = min(w - 1, maxs[0] + margin), min(h - 1, maxs[1] + margin)
    cw, ch = x1 - x0 + 1, y1 - y0 + 1
    cropped = bpy.data.images.new("OC_Concept_Crop", cw, ch, alpha=True)
    cp = [0.0] * (cw * ch * 4)
    for y in range(ch):
        for x in range(cw):
            si = ((y0 + y) * w + (x0 + x)) * 4
            di = (y * cw + x) * 4
            cp[di : di + 4] = pix[si : si + 4]
    cropped.pixels = cp
    cropped.pack()
    return cropped


def project_concept(obj: bpy.types.Object) -> None:
    img = crop_concept_image()
    mat = bpy.data.materials.new("OC_Concept")
    mat.use_nodes = True
    mat.diffuse_color = (0.85, 0.88, 0.86, 1.0)
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.location = (-300, 200)
    if bsdf:
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        if "Specular IOR Level" in bsdf.inputs:
            bsdf.inputs["Specular IOR Level"].default_value = 0.12
        if "Roughness" in bsdf.inputs:
            bsdf.inputs["Roughness"].default_value = 0.62
    obj.data.materials.clear()
    obj.data.materials.append(mat)

    cam_data = bpy.data.cameras.new("StudioUVCam")
    cam_data.lens = 50
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = 1.35
    cam = bpy.data.objects.new("StudioUVCam", cam_data)
    bpy.context.collection.objects.link(cam)
    cam.location = (0.0, -2.4, TARGET_HEIGHT * 0.52)
    direction = Vector((0.0, 0.0, TARGET_HEIGHT * 0.52)) - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam

    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    ov = view3d_override()
    if ov is None:
        print("NO_VIEW3D skip UV project, using smart project")
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.smart_project(angle_limit=66.0, island_margin=0.02)
        bpy.ops.object.mode_set(mode="OBJECT")
        return
    ov["active_object"] = obj
    ov["object"] = obj
    ov["selected_objects"] = [obj]
    ov["selected_editable_objects"] = [obj]
    with bpy.context.temp_override(**ov):
        bpy.ops.view3d.view_camera()
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.project_from_view(camera_bounds=True, correct_aspect=True, scale_to_bounds=True)  # cropped concept fills mesh AABB
        bpy.ops.object.mode_set(mode="OBJECT")
    print("UV_PROJECTED")


def build_armature(obj: bpy.types.Object) -> bpy.types.Object:
    h = TARGET_HEIGHT
    arm_data = bpy.data.armatures.new("OCArmature")
    arm_data.display_type = "STICK"
    arm_obj = bpy.data.objects.new("OCArmature", arm_data)
    bpy.context.collection.objects.link(arm_obj)
    bpy.context.view_layer.objects.active = arm_obj
    arm_obj.select_set(True)
    set_mode("EDIT")
    bones = arm_data.edit_bones

    def add(name, head, tail, parent=None):
        b = bones.new(name)
        b.head = Vector(head)
        b.tail = Vector(tail)
        b.use_connect = False
        b.use_deform = True
        if parent:
            b.parent = bones[parent]
        return b

    add("Root", (0, 0, 0), (0, 0, 0.05))
    add("Hips", (0, 0, h * 0.30), (0, 0, h * 0.38), "Root")
    add("Spine", (0, 0, h * 0.38), (0, 0, h * 0.50), "Hips")
    add("Chest", (0, 0, h * 0.50), (0, 0, h * 0.64), "Spine")
    add("Neck", (0, 0, h * 0.64), (0, 0, h * 0.70), "Chest")
    add("Head", (0, 0, h * 0.70), (0, 0, h * 0.92), "Neck")
    add("HairL", (-0.16, 0, h * 0.82), (-0.20, 0, h * 0.48), "Head")
    add("HairR", (0.16, 0, h * 0.82), (0.20, 0, h * 0.48), "Head")
    add("ArmL", (-0.10, 0, h * 0.60), (-0.28, 0, h * 0.38), "Chest")
    add("ArmR", (0.10, 0, h * 0.60), (0.28, 0, h * 0.38), "Chest")
    add("LegL", (-0.07, 0, h * 0.30), (-0.07, 0, 0.04), "Hips")
    add("LegR", (0.07, 0, h * 0.30), (0.07, 0, 0.04), "Hips")
    set_mode("OBJECT")

    bind_proximity(obj, arm_obj)
    return arm_obj


def bind_proximity(obj: bpy.types.Object, arm: bpy.types.Object) -> None:
    """Heat weights often fail on Hunyuan scans; fall back to 2-nearest bones."""
    for vg in list(obj.vertex_groups):
        obj.vertex_groups.remove(vg)
    segs = []
    for b in arm.data.bones:
        if not b.use_deform:
            continue
        head = arm.matrix_world @ b.head_local
        tail = arm.matrix_world @ b.tail_local
        vg = obj.vertex_groups.new(name=b.name)
        segs.append((head, tail, vg))
    mw = obj.matrix_world
    for i, v in enumerate(obj.data.vertices):
        p = mw @ v.co
        dists = []
        for head, tail, vg in segs:
            ab = tail - head
            denom = ab.length_squared or 1e-8
            t = max(0.0, min(1.0, (p - head).dot(ab) / denom))
            d = (p - (head + ab * t)).length
            dists.append((d, vg))
        dists.sort(key=lambda x: x[0])
        d0, vg0 = dists[0]
        d1, vg1 = dists[1]
        w0 = math.exp(-d0 / 0.08)
        w1 = math.exp(-d1 / 0.08)
        s = w0 + w1
        vg0.add([i], w0 / s, "REPLACE")
        vg1.add([i], w1 / s, "REPLACE")
    mod = next((m for m in obj.modifiers if m.type == "ARMATURE"), None)
    if mod is None:
        mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    mod.use_vertex_groups = True
    obj.parent = arm
    obj.parent_type = "OBJECT"


def add_shape_keys(obj: bpy.types.Object) -> None:
    mesh = obj.data
    if mesh.shape_keys:
        return
    obj.shape_key_add(name="Basis")
    blink = obj.shape_key_add(name="blink")
    smile = obj.shape_key_add(name="smile")
    angry = obj.shape_key_add(name="angry")
    sad = obj.shape_key_add(name="sad")
    h = TARGET_HEIGHT
    for i, v in enumerate(mesh.vertices):
        x, y, z = v.co.x, v.co.y, v.co.z
        front = y < -0.04
        # blink: collapse eye band
        if front and h * 0.68 < z < h * 0.82 and abs(x) < 0.14:
            cz = h * 0.75
            blink.data[i].co.z = cz + (z - cz) * 0.15
            blink.data[i].co.y += 0.004
        # smile: mouth corners
        if front and h * 0.58 < z < h * 0.66 and abs(x) < 0.08:
            smile.data[i].co.z += 0.006 * min(abs(x) / 0.04, 1.0)
        # angry: inner brow
        if front and h * 0.78 < z < h * 0.88 and abs(x) < 0.12:
            inward = 1.0 - min(abs(x) / 0.12, 1.0)
            angry.data[i].co.z -= 0.012 * inward
        # sad: outer brow
        if front and h * 0.76 < z < h * 0.86 and 0.04 < abs(x) < 0.14:
            sad.data[i].co.z -= 0.010
    print("SHAPE_KEYS", [k.name for k in mesh.shape_keys.key_blocks])


def make_idle(arm_obj: bpy.types.Object) -> None:
    arm_obj.animation_data_create()
    action = bpy.data.actions.new(name="idle")
    arm_obj.animation_data.action = action
    bpy.context.view_layer.objects.active = arm_obj
    set_mode("POSE")
    pb = arm_obj.pose.bones
    frames = (1, 20, 40, 60, 80)

    def keyed(bone_name, axis_index, degrees):
        b = pb.get(bone_name)
        if b is None:
            return
        b.rotation_mode = "XYZ"
        for f, deg in zip(frames, degrees):
            b.rotation_euler[axis_index] = math.radians(deg)
            b.keyframe_insert(data_path="rotation_euler", index=axis_index, frame=f)

    keyed("Head", 0, (0, 4, 0, -3, 0))
    keyed("Head", 2, (0, -3, 0, 3, 0))
    keyed("Hips", 2, (0, 2, 0, -2, 0))
    keyed("ArmL", 1, (0, 6, 0, -4, 0))
    keyed("ArmR", 1, (0, -4, 0, 6, 0))
    keyed("HairL", 1, (0, 7, 0, -5, 0))
    keyed("HairR", 1, (0, -5, 0, 7, 0))
    set_mode("OBJECT")
    for fcu in action.fcurves:
        fcu.modifiers.new(type="CYCLES")
        for kp in fcu.keyframe_points:
            kp.interpolation = "BEZIER"
    scene = bpy.context.scene
    scene.frame_start = 1
    scene.frame_end = 80
    scene.render.fps = 30
    track = arm_obj.animation_data.nla_tracks.new()
    track.name = "idle"
    track.strips.new("idle", 1, action)
    print("IDLE_ACTION", action.name)


def export_glb(path: Path, objects: list[bpy.types.Object]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    for o in bpy.context.scene.objects:
        o.select_set(False)
    for o in objects:
        o.hide_set(False)
        o.select_set(True)
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
        export_texcoords=True,
        export_image_format="AUTO",
    )
    print("EXPORTED", path)


def frame_view(obj: bpy.types.Object) -> None:
    ov = view3d_override()
    if ov is None:
        return
    space = ov["area"].spaces.active
    space.shading.type = "SOLID"
    space.shading.light = "STUDIO"
    space.shading.color_type = "TEXTURE"
    space.overlay.show_overlays = False
    space.show_gizmo = False
    r3d = space.region_3d
    r3d.view_perspective = "PERSP"
    r3d.view_location = (0.0, 0.0, TARGET_HEIGHT * 0.52)
    r3d.view_distance = 2.1
    r3d.view_rotation = Euler((math.radians(80.0), 0.0, 0.0), "XYZ").to_quaternion()


def main() -> None:
    AI_RAW.mkdir(parents=True, exist_ok=True)
    RES_GLB.parent.mkdir(parents=True, exist_ok=True)
    src = pick_hunyuan_mesh()
    src.name = "OC_Q_Hunyuan"
    isolate(src)
    export_glb(AI_RAW / "oc_q_ai_raw.glb", [src])
    origin_feet_and_scale(src)
    decimate(src, 0.14)
    project_concept(src)
    arm = build_armature(src)
    add_shape_keys(src)
    make_idle(arm)
    src.name = "OC_Q_Body"
    frame_view(src)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT_BLEND))
    export_glb(OUT_GLB, [src, arm])
    export_glb(RES_GLB, [src, arm])
    print("DONE Hunyuan refine verts", len(src.data.vertices), "faces", len(src.data.polygons))


if __name__ == "__main__":
    try:
        main()
    except Exception:
        traceback.print_exc()
        raise
