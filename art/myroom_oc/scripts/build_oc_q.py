"""
Build original Q-OC (Mint Ribbon) for MyRoom — Blender 4.4.

Matches concept/oc_q_concept_front.png:
  twin buns + clover ties, bangs, mint hair bows, amber eyes,
  cream hoodie + coral sailor bow, pleated skirt, mint socks, sneakers.

Works headless (`blender --background --python ...`) and via BlenderMCP
(`runpy.run_path`). Avoids VIEW_3D-only operators where possible.
"""
from __future__ import annotations

import math
import traceback
from pathlib import Path

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

try:
    ART = Path(__file__).resolve().parent.parent
except NameError:
    ART = Path("/Users/qihongrui/Desktop/project/profile-v1/app_games/9dot-music/art/myroom_oc")

GAME = ART.parent.parent  # app_games/9dot-music
AI_RAW = ART / "ai_raw"
OUT_BLEND = ART / "oc_q.blend"
OUT_GLB = ART / "oc_q.glb"
RES_GLB = GAME / "myroom" / "placeholder" / "oc_q.glb"

# Concept palette (not Crypton trademark colors)
C_SKIN = (0.96, 0.86, 0.80, 1.0)
C_HAIR = (0.42, 0.78, 0.74, 1.0)
C_HAIR_DARK = (0.32, 0.66, 0.64, 1.0)
C_CREAM = (0.96, 0.92, 0.84, 1.0)
C_CORAL = (0.93, 0.42, 0.36, 1.0)
C_CHAR = (0.16, 0.17, 0.20, 1.0)
C_MINT = (0.62, 0.88, 0.82, 1.0)
C_BOOT = (0.14, 0.15, 0.17, 1.0)
C_IRIS = (0.72, 0.42, 0.16, 1.0)
C_PUPIL = (0.16, 0.09, 0.05, 1.0)
C_WHITE = (0.99, 0.99, 0.995, 1.0)
C_BLUSH = (1.0, 0.62, 0.62, 1.0)
C_CLOVER = (0.93, 0.95, 0.88, 1.0)

BINDS: list[tuple[bpy.types.Object, str]] = []


def M(loc, rot=(0.0, 0.0, 0.0), scale=(1.0, 1.0, 1.0)) -> Matrix:
    return (
        Matrix.Translation(Vector(loc))
        @ Euler(rot, "XYZ").to_matrix().to_4x4()
        @ Matrix.Diagonal((*scale, 1.0))
    )


def track(obj: bpy.types.Object, bone: str) -> bpy.types.Object:
    BINDS.append((obj, bone))
    return obj


def clear_scene() -> None:
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for coll in (
        bpy.data.meshes,
        bpy.data.materials,
        bpy.data.armatures,
        bpy.data.actions,
        bpy.data.cameras,
        bpy.data.lights,
        bpy.data.curves,
        bpy.data.images,
    ):
        for block in list(coll):
            if getattr(block, "users", 1) == 0 or True:
                try:
                    coll.remove(block)
                except Exception:
                    pass
    BINDS.clear()


def mat(name: str, color, roughness: float = 0.58) -> bpy.types.Material:
    m = bpy.data.materials.new(name=name)
    m.use_nodes = True
    m.diffuse_color = color
    m.roughness = roughness
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = color
        if "Roughness" in bsdf.inputs:
            bsdf.inputs["Roughness"].default_value = roughness
        if "Specular IOR Level" in bsdf.inputs:
            bsdf.inputs["Specular IOR Level"].default_value = 0.12
        if "Coat Weight" in bsdf.inputs:
            bsdf.inputs["Coat Weight"].default_value = 0.0
    return m


def _finish_mesh(name: str, bm: bmesh.types.BMesh, material) -> bpy.types.Object:
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    for p in mesh.polygons:
        p.use_smooth = True
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    if material:
        mesh.materials.append(material)
    return obj


def make_sphere(name, radius, u, v, material, loc, scale=(1, 1, 1), rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(
        bm, u_segments=u, v_segments=v, radius=radius, matrix=M(loc, rot, scale), calc_uvs=True
    )
    return _finish_mesh(name, bm, material)


def make_cyl(name, r1, r2, depth, segments, material, loc, scale=(1, 1, 1), rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cone(
        bm,
        cap_ends=True,
        cap_tris=False,
        segments=segments,
        radius1=r1,
        radius2=r2,
        depth=depth,
        matrix=M(loc, rot, scale),
        calc_uvs=True,
    )
    return _finish_mesh(name, bm, material)


def make_cube(name, size, material, loc, scale=(1, 1, 1), rot=(0, 0, 0), bevel=0.0, bseg=2):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=size, matrix=M(loc, rot, scale), calc_uvs=True)
    if bevel > 0:
        bmesh.ops.bevel(
            bm,
            geom=list(bm.edges),
            offset=bevel,
            offset_type="OFFSET",
            segments=bseg,
            profile=0.5,
            affect="EDGES",
            clamp_overlap=True,
        )
    return _finish_mesh(name, bm, material)


def make_lock(name, points: list[tuple], radius: float, material, radii=None):
    """Bezier lock with circular bevel, converted to mesh."""
    curve = bpy.data.curves.new(name + "_crv", "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = radius
    curve.bevel_resolution = 3
    curve.fill_mode = "FULL"
    curve.use_fill_caps = True
    spline = curve.splines.new("BEZIER")
    spline.bezier_points.add(len(points) - 1)
    for bp, p in zip(spline.bezier_points, points):
        bp.co = Vector(p)
        bp.handle_left_type = "AUTO"
        bp.handle_right_type = "AUTO"
        bp.radius = 1.0
    if radii:
        for bp, r in zip(spline.bezier_points, radii):
            bp.radius = r
    tmp = bpy.data.objects.new(name + "_tmp", curve)
    bpy.context.collection.objects.link(tmp)
    bpy.context.view_layer.update()
    deps = bpy.context.evaluated_depsgraph_get()
    eval_obj = tmp.evaluated_get(deps)
    mesh = bpy.data.meshes.new_from_object(eval_obj, depsgraph=deps)
    mesh.name = name
    for p in mesh.polygons:
        p.use_smooth = True
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    if material:
        mesh.materials.append(material)
    bpy.data.objects.remove(tmp, do_unlink=True)
    bpy.data.curves.remove(curve)
    return obj


def make_bow(name, loc, material, s=1.0, yaw=0.0):
    x, y, z = loc
    loop_s = (1.35 * s, 0.32 * s, 0.85 * s)
    objs = [
        make_sphere(name + "L", 0.032 * s, 12, 8, material, (x - 0.028 * s, y, z), loop_s, rot=(0, 0, yaw)),
        make_sphere(name + "R", 0.032 * s, 12, 8, material, (x + 0.028 * s, y, z), loop_s, rot=(0, 0, yaw)),
        make_sphere(name + "K", 0.016 * s, 10, 6, material, (x, y - 0.004, z)),
        make_cube(
            name + "T1",
            0.04 * s,
            material,
            (x - 0.018 * s, y, z - 0.045 * s),
            scale=(0.35, 0.18, 1.5),
            rot=(0, math.radians(18), yaw),
            bevel=0.006,
        ),
        make_cube(
            name + "T2",
            0.04 * s,
            material,
            (x + 0.018 * s, y, z - 0.045 * s),
            scale=(0.35, 0.18, 1.5),
            rot=(0, math.radians(-18), yaw),
            bevel=0.006,
        ),
    ]
    return objs


def make_clover(name, loc, material, size=0.018):
    x, y, z = loc
    offs = size * 0.62
    objs = [
        make_sphere(name + "N", size * 0.5, 10, 6, material, (x, y, z + offs)),
        make_sphere(name + "S", size * 0.5, 10, 6, material, (x, y, z - offs)),
        make_sphere(name + "W", size * 0.5, 10, 6, material, (x - offs, y, z)),
        make_sphere(name + "E", size * 0.5, 10, 6, material, (x + offs, y, z)),
        make_sphere(name + "C", size * 0.28, 8, 6, material, (x, y - 0.002, z)),
    ]
    return objs


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


def build_parts(mats: dict) -> None:
    skin, hair, hair_d = mats["skin"], mats["hair"], mats["hair_d"]
    cream, coral, char = mats["cream"], mats["coral"], mats["char"]
    mint, boot = mats["mint"], mats["boot"]
    iris, pupil, white = mats["iris"], mats["pupil"], mats["white"]
    blush, clover = mats["blush"], mats["clover"]

    # --- Head / face (chibi: ~3 heads tall, face toward -Y) ---
    track(make_sphere("Head", 0.185, 32, 16, skin, (0, 0.015, 0.84), scale=(1.04, 0.92, 1.00)), "Head")

    for sx, tag in ((-1.0, "L"), (1.0, "R")):
        ex, ey, ez = sx * 0.058, -0.162, 0.818
        track(make_sphere(f"Eye{tag}White", 0.056, 16, 10, white, (ex, ey, ez), scale=(1.00, 0.28, 1.22)), "Head")
        track(make_sphere(f"Eye{tag}Iris", 0.036, 14, 10, iris, (ex, ey - 0.006, ez - 0.006), scale=(0.96, 0.32, 1.10)), "Head")
        track(make_sphere(f"Eye{tag}Pupil", 0.013, 10, 8, pupil, (ex, ey - 0.016, ez - 0.004)), "Head")
        track(make_sphere(f"Eye{tag}Hi", 0.012, 8, 6, white, (ex + sx * -0.012, ey - 0.022, ez + 0.014)), "Head")
        track(make_sphere(f"Eye{tag}Hi2", 0.006, 8, 6, white, (ex + sx * 0.010, ey - 0.020, ez - 0.012)), "Head")
        track(
            make_cube(
                f"Lid{tag}",
                0.04,
                hair,
                (ex, ey - 0.004, ez + 0.048),
                scale=(1.35, 0.28, 0.32),
                bevel=0.005,
            ),
            "Head",
        )
        track(
            make_cube(
                f"Brow{tag}",
                0.036,
                hair_d,
                (ex, ey + 0.008, ez + 0.048),
                scale=(1.10, 0.18, 0.24),
                rot=(0, 0, sx * math.radians(-10)),
                bevel=0.004,
            ),
            "Head",
        )

    track(make_sphere("BlushL", 0.030, 12, 8, blush, (-0.105, -0.150, 0.755), scale=(1.20, 0.32, 0.60)), "Head")
    track(make_sphere("BlushR", 0.030, 12, 8, blush, (0.105, -0.150, 0.755), scale=(1.20, 0.32, 0.60)), "Head")
    track(make_cube("Mouth", 0.03, hair_d, (0, -0.172, 0.732), scale=(1.45, 0.14, 0.18), bevel=0.006), "Head")

    # --- Hair: cap covers crown; buns sit on the SIDES (not Mickey ears) ---
    track(make_sphere("HairCap", 0.198, 28, 14, hair, (0, 0.02, 0.90), scale=(1.14, 1.04, 0.86)), "Head")
    track(make_sphere("HairBack", 0.17, 24, 12, hair_d, (0, 0.10, 0.80), scale=(1.18, 0.62, 1.10)), "Head")
    track(make_sphere("BangsMain", 0.138, 24, 12, hair, (0, -0.108, 0.925), scale=(1.48, 0.36, 0.58)), "Head")
    track(make_sphere("BangsL", 0.072, 16, 10, hair, (-0.11, -0.118, 0.88), scale=(1.08, 0.38, 0.85)), "Head")
    track(make_sphere("BangsR", 0.072, 16, 10, hair, (0.11, -0.118, 0.88), scale=(1.08, 0.38, 0.85)), "Head")
    track(make_sphere("BangsMid", 0.048, 14, 8, hair, (0.0, -0.125, 0.875), scale=(1.20, 0.32, 0.70)), "Head")
    track(make_sphere("FrameL", 0.082, 16, 10, hair, (-0.168, -0.05, 0.80), scale=(0.72, 0.68, 1.35)), "Head")
    track(make_sphere("FrameR", 0.082, 16, 10, hair, (0.168, -0.05, 0.80), scale=(0.72, 0.68, 1.35)), "Head")

    for sx, tag in ((-1.0, "L"), (1.0, "R")):
        track(make_sphere(f"Bun{tag}", 0.112, 22, 12, hair, (sx * 0.205, 0.03, 0.95), scale=(1.10, 0.95, 1.12)), "Head")
        track(make_sphere(f"BunRoot{tag}", 0.072, 14, 8, hair, (sx * 0.13, 0.02, 0.92)), "Head")
        track(make_sphere(f"Tie{tag}", 0.032, 12, 8, mint, (sx * 0.168, -0.078, 0.935)), "Head")
        for c in make_clover(f"Clover{tag}", (sx * 0.168, -0.098, 0.935), clover, 0.017):
            track(c, "Head")
        lock = make_lock(
            f"HairHang{tag}",
            [
                (sx * 0.23, -0.02, 0.90),
                (sx * 0.25, -0.05, 0.72),
                (sx * 0.22, -0.04, 0.55),
                (sx * 0.19, -0.02, 0.44),
            ],
            0.050,
            hair,
            radii=(1.20, 1.05, 0.72, 0.38),
        )
        lock.scale = (1.0, 0.40, 1.0)
        track(lock, f"Hair{tag}")
        side = make_lock(
            f"HairSide{tag}",
            [
                (sx * 0.14, -0.12, 0.84),
                (sx * 0.16, -0.13, 0.68),
                (sx * 0.14, -0.10, 0.54),
            ],
            0.036,
            hair,
            radii=(1.05, 0.88, 0.48),
        )
        side.scale = (1.0, 0.42, 1.0)
        track(side, f"Hair{tag}")
        for b in make_bow(f"Ribbon{tag}", (sx * 0.215, -0.05, 0.60), mint, s=1.08, yaw=sx * math.radians(12)):
            track(b, f"Hair{tag}")

    # --- Hoodie ---
    track(
        make_cube("Hoodie", 0.26, cream, (0, 0.01, 0.54), scale=(1.22, 0.72, 1.18), bevel=0.045, bseg=3),
        "Chest",
    )
    track(make_sphere("Hood", 0.12, 20, 12, cream, (0, 0.07, 0.70), scale=(1.25, 0.70, 0.55)), "Chest")
    track(
        make_cube("Pocket", 0.08, cream, (0, -0.115, 0.50), scale=(1.85, 0.28, 0.85), bevel=0.012, bseg=2),
        "Chest",
    )
    track(
        make_cube("PocketMint", 0.07, mint, (0, -0.122, 0.505), scale=(1.55, 0.12, 0.55), bevel=0.006),
        "Chest",
    )
    for b in make_bow("Scarf", (0, -0.135, 0.675), coral, s=1.15):
        track(b, "Chest")
    track(make_cyl("Badge", 0.022, 0.022, 0.012, 16, mint, (0.09, -0.145, 0.595), rot=(math.radians(90), 0, 0)), "Chest")
    for c in make_clover("BadgeClover", (0.09, -0.152, 0.595), clover, 0.011):
        track(c, "Chest")

    # --- Arms ---
    for sx, tag in ((-1.0, "L"), (1.0, "R")):
        tilt = sx * math.radians(-16)
        track(
            make_cyl(
                f"Sleeve{tag}",
                0.048,
                0.055,
                0.26,
                16,
                cream,
                (sx * 0.20, 0.0, 0.55),
                rot=(0, tilt, 0),
            ),
            f"Arm{tag}",
        )
        track(
            make_sphere(f"Hand{tag}", 0.042, 14, 10, skin, (sx * 0.245, 0.0, 0.42), scale=(1.05, 0.85, 0.90)),
            f"Arm{tag}",
        )

    # --- Skirt ---
    track(make_cyl("SkirtBase", 0.14, 0.18, 0.11, 20, char, (0, 0.0, 0.365)), "Hips")
    for i in range(10):
        ang = i * (2 * math.pi / 10)
        x, y = math.sin(ang) * 0.155, math.cos(ang) * 0.12
        track(
            make_cube(
                f"Pleat{i}",
                0.06,
                char,
                (x, y, 0.36),
                scale=(0.42, 0.55, 1.05),
                rot=(0, 0, ang),
                bevel=0.004,
            ),
            "Hips",
        )

    # --- Legs / socks / sneakers ---
    for sx, tag in ((-1.0, "L"), (1.0, "R")):
        track(make_cyl(f"Leg{tag}", 0.038, 0.040, 0.14, 14, skin, (sx * 0.065, 0.0, 0.255)), f"Leg{tag}")
        track(make_cyl(f"Sock{tag}", 0.042, 0.044, 0.09, 14, mint, (sx * 0.065, 0.0, 0.145)), f"Leg{tag}")
        track(
            make_cube(
                f"Shoe{tag}",
                0.09,
                boot,
                (sx * 0.065, 0.030, 0.048),
                scale=(0.88, 1.70, 0.62),
                bevel=0.014,
                bseg=2,
            ),
            f"Leg{tag}",
        )
        track(
            make_cube(
                f"Sole{tag}",
                0.09,
                mint,
                (sx * 0.065, 0.032, 0.012),
                scale=(0.94, 1.78, 0.30),
                bevel=0.010,
            ),
            f"Leg{tag}",
        )
        track(
            make_cube(
                f"Stripe{tag}",
                0.05,
                coral,
                (sx * 0.065, 0.072, 0.052),
                scale=(0.55, 0.22, 0.32),
                bevel=0.004,
            ),
            f"Leg{tag}",
        )


def build_armature() -> bpy.types.Object:
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

    add("Root", (0, 0, 0), (0, 0, 0.06))
    add("Hips", (0, 0, 0.32), (0, 0, 0.42), "Root")
    add("Spine", (0, 0, 0.42), (0, 0, 0.54), "Hips")
    add("Chest", (0, 0, 0.54), (0, 0, 0.70), "Spine")
    add("Neck", (0, 0, 0.70), (0, 0, 0.78), "Chest")
    add("Head", (0, 0, 0.74), (0, 0, 1.02), "Neck")
    add("HairL", (-0.22, 0, 0.92), (-0.22, 0, 0.38), "Head")
    add("HairR", (0.22, 0, 0.92), (0.22, 0, 0.38), "Head")
    add("ArmL", (-0.12, 0, 0.66), (-0.26, 0, 0.42), "Chest")
    add("ArmR", (0.12, 0, 0.66), (0.26, 0, 0.42), "Chest")
    add("LegL", (-0.065, 0, 0.32), (-0.065, 0, 0.04), "Hips")
    add("LegR", (0.065, 0, 0.32), (0.065, 0, 0.04), "Hips")
    set_mode("OBJECT")
    return arm_obj


def bind_parts(arm_obj: bpy.types.Object) -> None:
    for obj, bone in BINDS:
        if obj.type != "MESH" or not obj.data.vertices:
            continue
        vg = obj.vertex_groups.new(name=bone)
        vg.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
        mod = obj.modifiers.new("Armature", "ARMATURE")
        mod.object = arm_obj
        mod.use_vertex_groups = True
        obj.parent = arm_obj


def _centroid_z(obj) -> float:
    verts = obj.data.vertices
    if not verts:
        return 0.0
    return sum(v.co.z for v in verts) / len(verts)


def add_shape_keys() -> None:
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        n = obj.name
        mesh = obj.data
        if n.startswith("Eye") and any(n.endswith(s) for s in ("White", "Iris", "Pupil", "Hi", "Hi2")):
            if mesh.shape_keys:
                continue
            cz = _centroid_z(obj)
            obj.shape_key_add(name="Basis")
            blink = obj.shape_key_add(name="blink")
            angry = obj.shape_key_add(name="angry")
            sad = obj.shape_key_add(name="sad")
            for i, v in enumerate(mesh.vertices):
                blink.data[i].co.z = cz + (v.co.z - cz) * 0.10
                blink.data[i].co.y = v.co.y + 0.003
                if v.co.z > cz:
                    inward = 1.0 - min(abs(v.co.x) / 0.12, 1.0)
                    angry.data[i].co.z -= 0.012 * inward
                    outward = min(abs(v.co.x) / 0.09, 1.0)
                    sad.data[i].co.z -= 0.010 * outward
        elif n.startswith("Brow"):
            obj.shape_key_add(name="Basis")
            angry = obj.shape_key_add(name="angry")
            sad = obj.shape_key_add(name="sad")
            cx = 1.0 if "R" in n else -1.0
            for i, v in enumerate(mesh.vertices):
                angry.data[i].co.z -= 0.016
                angry.data[i].co.x -= cx * 0.008
                sad.data[i].co.z -= 0.012
                sad.data[i].co.x += cx * 0.006
        elif n == "Mouth":
            obj.shape_key_add(name="Basis")
            smile = obj.shape_key_add(name="smile")
            sad = obj.shape_key_add(name="sad")
            cz = _centroid_z(obj)
            for i, v in enumerate(mesh.vertices):
                side = min(abs(v.co.x) / 0.02, 1.0)
                smile.data[i].co.z += 0.008 * side
                smile.data[i].co.x *= 1.08
                sad.data[i].co.z -= 0.006 + 0.004 * side


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

    keyed("Head", 0, (0, 5, 0, -3, 0))
    keyed("Head", 2, (0, -3, 0, 3, 0))
    keyed("Hips", 2, (0, 2, 0, -2, 0))
    keyed("ArmL", 1, (0, 6, 0, -4, 0))
    keyed("ArmR", 1, (0, -4, 0, 6, 0))
    keyed("HairL", 1, (0, 8, 0, -6, 0))
    keyed("HairR", 1, (0, -6, 0, 8, 0))
    set_mode("OBJECT")
    for fcu in action.fcurves:
        mod = fcu.modifiers.new(type="CYCLES")
        mod.mode_before = "REPEAT"
        mod.mode_after = "REPEAT"
        for kp in fcu.keyframe_points:
            kp.interpolation = "BEZIER"
    scene = bpy.context.scene
    scene.frame_start = 1
    scene.frame_end = 80
    scene.render.fps = 30
    track_nla = arm_obj.animation_data.nla_tracks.new()
    track_nla.name = "idle"
    track_nla.strips.new("idle", 1, action)
    print("IDLE_ACTION", action.name)


def setup_studio() -> None:
    world = bpy.context.scene.world
    if world is None:
        world = bpy.data.worlds.new("World")
        bpy.context.scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs[0].default_value = (0.70, 0.72, 0.74, 1.0)
        bg.inputs[1].default_value = 0.85

    key = bpy.data.lights.new("StudioKey", "AREA")
    key.energy = 180
    key.size = 1.4
    key_o = bpy.data.objects.new("StudioKey", key)
    key_o.location = (1.1, -1.4, 1.8)
    bpy.context.collection.objects.link(key_o)

    fill = bpy.data.lights.new("StudioFill", "AREA")
    fill.energy = 60
    fill.size = 1.6
    fill.color = (0.75, 0.85, 1.0)
    fill_o = bpy.data.objects.new("StudioFill", fill)
    fill_o.location = (-1.2, -0.8, 1.2)
    bpy.context.collection.objects.link(fill_o)

    cam_data = bpy.data.cameras.new("StudioCam")
    cam_data.lens = 50
    cam = bpy.data.objects.new("StudioCam", cam_data)
    cam.location = (0.0, -2.15, 0.72)
    direction = Vector((0.0, 0.0, 0.58)) - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    bpy.context.collection.objects.link(cam)
    bpy.context.scene.camera = cam

    ref_path = ART / "concept" / "oc_q_concept_front.png"
    if ref_path.exists():
        img = bpy.data.images.load(str(ref_path))
        empty = bpy.data.objects.new("StudioRef", None)
        empty.empty_display_type = "IMAGE"
        empty.data = img
        empty.empty_display_size = 1.15
        empty.location = (0.72, 0.0, 0.58)
        empty.rotation_euler = (math.radians(90), 0, 0)
        bpy.context.collection.objects.link(empty)

    ov = view3d_override()
    if ov:
        space = ov["area"].spaces.active
        space.shading.type = "SOLID"
        space.shading.light = "STUDIO"
        space.shading.color_type = "MATERIAL"
        space.shading.show_specular_highlight = True
        space.shading.use_scene_lights = False
        space.shading.use_scene_world = False
        space.overlay.show_bones = False
        space.overlay.show_cursor = False
        space.overlay.show_extras = False
        space.overlay.show_relationship_lines = False
        space.overlay.show_motion_paths = False
        space.overlay.show_outline_selected = False
        space.show_gizmo = False
        space.overlay.show_floor = True
        space.clip_start = 0.01
        r3d = space.region_3d
        r3d.view_perspective = "PERSP"
        r3d.view_location = (0.0, 0.0, 0.58)
        r3d.view_distance = 2.05
        r3d.view_rotation = Euler((math.radians(78.0), 0.0, 0.0), "XYZ").to_quaternion()


def export_glb(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    for o in bpy.context.scene.objects:
        o.select_set(False)
    for o in bpy.context.scene.objects:
        if o.name.startswith("Studio"):
            continue
        if o.type in {"MESH", "ARMATURE"}:
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
    )
    print("EXPORTED", path)


def main() -> None:
    AI_RAW.mkdir(parents=True, exist_ok=True)
    RES_GLB.parent.mkdir(parents=True, exist_ok=True)
    clear_scene()
    mats = {
        "skin": mat("Skin", C_SKIN, 0.72),
        "hair": mat("Hair", C_HAIR, 0.48),
        "hair_d": mat("HairDark", C_HAIR_DARK, 0.52),
        "cream": mat("Cream", C_CREAM, 0.62),
        "coral": mat("Coral", C_CORAL, 0.50),
        "char": mat("Charcoal", C_CHAR, 0.58),
        "mint": mat("Mint", C_MINT, 0.50),
        "boot": mat("Boot", C_BOOT, 0.42),
        "iris": mat("Iris", C_IRIS, 0.35),
        "pupil": mat("Pupil", C_PUPIL, 0.40),
        "white": mat("White", C_WHITE, 0.45),
        "blush": mat("Blush", C_BLUSH, 0.80),
        "clover": mat("Clover", C_CLOVER, 0.55),
    }
    build_parts(mats)
    for obj, _bone in BINDS:
        sc = obj.scale
        if abs(sc.x - 1.0) > 1e-4 or abs(sc.y - 1.0) > 1e-4 or abs(sc.z - 1.0) > 1e-4:
            obj.data.transform(Matrix.Diagonal((sc.x, sc.y, sc.z, 1.0)))
            obj.scale = (1.0, 1.0, 1.0)
            obj.data.update()
    # Raw snapshot before armature (all current meshes)
    export_glb(AI_RAW / "oc_q_ai_raw.glb")
    arm = build_armature()
    bind_parts(arm)
    add_shape_keys()
    make_idle(arm)
    setup_studio()
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT_BLEND))
    export_glb(OUT_GLB)
    export_glb(RES_GLB)
    verts = sum(len(m.vertices) for m in bpy.data.meshes)
    tris = sum(len(m.polygons) for m in bpy.data.meshes)
    print("DONE OC_Q verts", verts, "faces", tris, "binds", len(BINDS))


if __name__ == "__main__":
    try:
        main()
    except Exception:
        traceback.print_exc()
        raise
