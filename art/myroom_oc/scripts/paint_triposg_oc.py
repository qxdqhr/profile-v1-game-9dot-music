"""Paint the TripOSG OC to the concept palette and add face assets.

Body mesh is a single gray shell. Face/hair jaggies are avoided by painting
the whole head mint, then seating a skin face plate + eyes in the scanned
sockets. Socks, bow, badge and clover ties are separate meshes.
"""
from __future__ import annotations

import importlib.util
from collections import Counter
from pathlib import Path

import bpy
from mathutils import Vector
import math

try:
    ART = Path(__file__).resolve().parent.parent
except NameError:
    ART = Path("/Users/qihongrui/Desktop/project/profile-v1/app_games/9dot-music/art/myroom_oc")

GAME = ART.parent.parent
SRC = Path("/Users/qihongrui/Downloads/LanDrop/triposg_20260913_.glb")
RAW = ART / "ai_raw" / "oc_q_triposg.glb"
OUT_BLEND = ART / "oc_q.blend"
OUT_GLB = ART / "oc_q.glb"
RES_GLB = GAME / "myroom" / "placeholder" / "oc_q.glb"
PREVIEW = ART / "preview"
BUILD = ART / "scripts" / "build_oc_q.py"

spec = importlib.util.spec_from_file_location("build_oc_q", BUILD)
bq = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bq)

H = 1.10

# Face shell: UV-sphere front section, centred so the shell surface at the
# eye position (x=±0.052, z=0.700) sits ~0.04 in front of the mesh face.
SHELL_R = 0.16
SHELL_CZ = 0.665
SHELL_CY = -0.04  # flush with mesh surface (~-0.20)  # = -0.22 + sqrt(R²-0.052²-0.035²)

EYE_X = 0.048
EYE_Z = 0.690

# Vertex-colour palette (matches concept).
VCOLORS = {
    "skin":  (0.96, 0.86, 0.80),
    "hair":   (0.42, 0.78, 0.74),
    "cream":  (0.96, 0.92, 0.84),
    "char":   (0.16, 0.17, 0.20),
    "mint":   (0.62, 0.88, 0.82),
    "boot":   (0.14, 0.15, 0.17),
}


def world_bounds(obj):
    corners = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    xs = [c.x for c in corners]
    ys = [c.y for c in corners]
    zs = [c.z for c in corners]
    return min(xs), max(xs), min(ys), max(ys), min(zs), max(zs)


def apply_tr(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def _find_bsdf(m):
    """Find Principled BSDF node by bl_idname (works with any locale)."""
    if not m.use_nodes:
        return None
    for n in m.node_tree.nodes:
        if n.bl_idname == "ShaderNodeBsdfPrincipled":
            return n
    return None


def mat(name, color, rough=0.58):
    """Create material with correct BSDF Base Color (locale-independent)."""
    m = bpy.data.materials.new(name=name)
    m.use_nodes = True
    m.diffuse_color = color
    m.roughness = rough
    bsdf = _find_bsdf(m)
    if bsdf:
        if "Base Color" in bsdf.inputs:
            bsdf.inputs["Base Color"].default_value = color
        if "Roughness" in bsdf.inputs:
            bsdf.inputs["Roughness"].default_value = rough
        if "Specular IOR Level" in bsdf.inputs:
            bsdf.inputs["Specular IOR Level"].default_value = 0.12
    return m


def in_ellipse(x, z, cx, cz, rx, rz):
    return ((x - cx) / max(rx, 1e-6)) ** 2 + ((z - cz) / max(rz, 1e-6)) ** 2 <= 1.0


def shell_y(z):
    """World y of the face-shell surface at a given z."""
    dz = z - SHELL_CZ
    dy = math.sqrt(max(SHELL_R * SHELL_R - dz * dz, 0.001))
    return SHELL_CY - dy


def fix_all_base_colors():
    """Ensure every material's BSDF Base Color matches its diffuse_color."""
    for m in bpy.data.materials:
        bsdf = _find_bsdf(m)
        if bsdf and "Base Color" in bsdf.inputs:
            bsdf.inputs["Base Color"].default_value = m.diffuse_color


def classify(p, h):
    """Conservative body regions. Head is hair only — face is a separate asset."""
    t = p.z / max(h, 1e-5)
    ax = abs(p.x)

    if 0.24 < t < 0.52 and ax > 0.195 * h:
        return "skin"
    if t < 0.012:
        return "mint"
    if t < 0.102:
        return "boot"
    if t < 0.218 and ax < 0.125 * h:
        return "skin"
    if 0.198 < t < 0.292 and ax < 0.215 * h:
        return "char"
    if t > 0.548:
        return "hair"
    return "cream"


def smooth_labels(obj, vkeys, rounds=6):
    adj = [[] for _ in obj.data.vertices]
    for e in obj.data.edges:
        a, b = e.vertices
        adj[a].append(b)
        adj[b].append(a)
    cur = list(vkeys)
    for _ in range(rounds):
        nxt = cur[:]
        for i, nbrs in enumerate(adj):
            if not nbrs:
                continue
            votes = [cur[j] for j in nbrs]
            votes.append(cur[i])
            nxt[i] = Counter(votes).most_common(1)[0][0]
        cur = nxt
    return cur


def render_views(center, size, prefix: str):
    PREVIEW.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x = 720
    scene.render.resolution_y = 900
    scene.render.image_settings.file_format = "PNG"
    # Add lights if none exist.
    if not any(o.type == "LIGHT" for o in bpy.data.objects):
        import math as _m
        for nm, loc, rot, energy in (
            ("Key", (0, -3, 2), (_m.radians(30), 0, 0), 200),
            ("Fill", (3, -1, 1.5), (_m.radians(20), _m.radians(-30), 0), 80),
            ("Rim", (0, 3, 2), (_m.radians(-30), 0, 0), 100),
        ):
            ld = bpy.data.lights.new(nm, "AREA")
            ld.energy = energy; ld.size = 2.0
            lo = bpy.data.objects.new(nm, ld)
            scene.collection.objects.link(lo)
            lo.location = loc; lo.rotation_euler = rot
    # Light world background.
    world = scene.world or bpy.data.worlds.new("World")
    scene.world = world; world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs["Color"].default_value = (0.5, 0.5, 0.55, 1.0)
        bg.inputs["Strength"].default_value = 0.5
    dist = max(size) * 2.2
    camdata = bpy.data.cameras.new("prev")
    camdata.type = "ORTHO"
    camdata.ortho_scale = max(size) * 1.35
    cam = bpy.data.objects.new("prev", camdata)
    scene.collection.objects.link(cam)
    scene.camera = cam
    views = {
        "front": Vector((0.0, -dist, 0.0)),
        "left": Vector((dist, 0.0, 0.0)),
        "back": Vector((0.0, dist, 0.0)),
    }
    for name, offset in views.items():
        cam.location = center + offset
        to = (center - cam.location).normalized()
        cam.rotation_euler = to.to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(PREVIEW / f"{prefix}_{name}.png")
        bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam, do_unlink=True)
    bpy.data.cameras.remove(camdata)


def export_glb(path):
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in bpy.context.scene.objects:
        if o.type == "MESH" and not o.hide_render:
            o.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_materials="EXPORT",
        export_cameras=False,
        export_lights=False,
        export_animations=False,
    )
    print("EXPORTED", path, path.stat().st_size)


def add_face_cap(mats):
    """Curved shell: gentle chin curve + nose bump, no hard bottom edge."""
    import bmesh
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=64, ring_count=32, radius=SHELL_R, location=(0, 0, 0)
    )
    sph = bpy.context.active_object
    sph.name = "FaceShell"
    bpy.ops.object.mode_set(mode="EDIT")
    bm = bmesh.from_edit_mesh(sph.data)
    # Keep front 60%
    to_del = [v for v in bm.verts if v.co.y > 0.02]
    bmesh.ops.delete(bm, geom=to_del, context="VERTS")
    bmesh.update_edit_mesh(sph.data)
    bpy.ops.object.mode_set(mode="OBJECT")
    sph.location = (0.0, SHELL_CY, SHELL_CZ)
    apply_tr(sph)

    # Shape: chin curve + nose bump (no hard trim)
    mw = sph.matrix_world
    for v in sph.data.vertices:
        wv = mw @ v.co
        lz = wv.z - SHELL_CZ
        # Chin: moderate narrowing at bottom
        if lz < -0.04:
            pinch = 1.0 - 0.15 * min((-0.04 - lz) / 0.12, 1.0)
            v.co.x *= pinch
            # Also pull bottom forward slightly for chin curve
            if lz < -0.08:
                v.co.y -= 0.01 * min((-0.08 - lz) / 0.08, 1.0)
        # Nose bump - more prominent
        if abs(wv.x) < 0.025 and -0.050 < lz < -0.012:
            v.co.y -= 0.012

    sph.data.materials.clear()
    sph.data.materials.append(mats["skin"])
    for p in sph.data.polygons:
        p.use_smooth = True
    return sph


def add_neck(mats):
    """Very thin neck, mostly hidden by hoodie."""
    neck = bq.make_cyl("Neck", 0.030, 0.024, 0.12, 16, mats["skin"], (0, 0, 0.58))
    return neck


def add_eyes(mats):
    """Almond eyes: very flat spheres + upper lash bar."""
    eyes = []
    for tag, sx in (("L", -1.0), ("R", 1.0)):
        ex = sx * EYE_X
        ez = EYE_Z
        yf = shell_y(ez)
        # White sclera - very flat almond
        eyes.append(bq.make_sphere(f"Eye{tag}White", 0.042, 20, 12, mats["white"], (ex, yf-0.001, ez), scale=(1.30, 0.12, 0.85)))
        # Iris - flat circle
        eyes.append(bq.make_sphere(f"Eye{tag}Iris", 0.028, 20, 12, mats["iris"], (ex, yf-0.005, ez-0.002), scale=(1.0, 0.12, 1.0)))
        # Pupil
        eyes.append(bq.make_sphere(f"Eye{tag}Pupil", 0.012, 16, 10, mats["pupil"], (ex, yf-0.008, ez-0.001), scale=(1.0, 0.12, 1.0)))
        # Highlights
        eyes.append(bq.make_sphere(f"Eye{tag}Hi", 0.007, 12, 8, mats["white"], (ex-sx*0.010, yf-0.010, ez+0.010), scale=(1.0, 0.12, 1.0)))
        eyes.append(bq.make_sphere(f"Eye{tag}Hi2", 0.004, 10, 6, mats["white"], (ex+sx*0.007, yf-0.009, ez-0.008), scale=(1.0, 0.12, 1.0)))
        # Upper lash line: thin dark bar
        lash_y = yf - 0.003
        eyes.append(bq.make_sphere(f"Lash{tag}", 0.036, 20, 10, mats["char"], (ex, lash_y, ez+0.022), scale=(1.10, 0.10, 0.18)))
    return eyes


def add_face_extras(mats):
    """Nose + blush + mouth + brows on the shell surface."""
    extras = []
    # Nose: small but visible bump
    nz = 0.638
    ny = shell_y(nz) - 0.010
    extras.append(bq.make_sphere("Nose", 0.014, 12, 8, mats["skin"], (0, ny, nz), scale=(1.0, 0.55, 0.85)))
    # Brows: thin dark strokes above eyes
    for tag, sx in (("L", -1.0), ("R", 1.0)):
        bz = EYE_Z + 0.040
        by = shell_y(bz) - 0.002
        extras.append(bq.make_sphere(f"Brow{tag}", 0.010, 10, 6, mats["hair_d"], (sx*EYE_X, by, bz), scale=(1.5, 0.18, 0.35)))
    # Blush
    bz2 = 0.628
    by2 = shell_y(bz2) - 0.002
    extras.append(bq.make_sphere("BlushL", 0.026, 12, 8, mats["blush"], (-0.078, by2, bz2), scale=(1.25, 0.18, 0.50)))
    extras.append(bq.make_sphere("BlushR", 0.026, 12, 8, mats["blush"], (0.078, by2, bz2), scale=(1.25, 0.18, 0.50)))
    # Mouth: small smile curve, close to nose
    mz = 0.628
    my = shell_y(mz) - 0.004
    extras.append(
        bq.make_lock(
            "Mouth",
            [(-0.016, my, mz+0.003), (0.0, my-0.005, mz), (0.016, my, mz+0.003)],
            0.004,
            mats["hair_d"],
        )
    )
    return extras


def add_clothes_extras(mats):
    extras = []
    extras.extend(bq.make_bow("Bow", (0.0, -0.148, 0.528), mats["coral"], s=0.72))
    extras.append(bq.make_sphere("Badge", 0.013, 12, 8, mats["mint"], (0.078, -0.132, 0.488), scale=(1.0, 0.32, 1.0)))
    extras.extend(bq.make_clover("BadgeClover", (0.078, -0.136, 0.488), mats["white"], size=0.008))
    return extras


def add_hair_ties(obj, mats):
    extras = []
    mw = obj.matrix_world
    bun_l, bun_r = [], []
    for v in obj.data.vertices:
        p = mw @ v.co
        if p.z < 0.92 or abs(p.y) > 0.10 or not (0.12 < abs(p.x) < 0.28):
            continue
        (bun_l if p.x < 0 else bun_r).append(p)
    mw_inv = mw.inverted()
    for pts, tag, sx in ((bun_l, "L", -1.0), (bun_r, "R", 1.0)):
        if not pts:
            continue
        c = Vector(
            (
                sum(p.x for p in pts) / len(pts),
                sum(p.y for p in pts) / len(pts),
                sum(p.z for p in pts) / len(pts),
            )
        )
        origin_w = Vector((c.x + sx * 0.25, c.y - 0.20, c.z))
        direction = (c - origin_w).normalized()
        hit, loc, _n, _i = obj.ray_cast(mw_inv @ origin_w, (mw_inv.to_3x3() @ direction).normalized())
        pos = (mw @ loc) if hit else c + Vector((sx * 0.02, -0.02, 0.0))
        print("tie", tag, tuple(round(v, 3) for v in pos), "hit", hit)
        extras.append(bq.make_sphere(f"Tie{tag}", 0.016, 12, 8, mats["mint"], tuple(pos), scale=(0.55, 1.0, 1.0)))
        extras.extend(bq.make_clover(f"Clover{tag}", (pos.x + sx * 0.003, pos.y - 0.003, pos.z), mats["white"], size=0.010))
    return extras


def pose_source():
    if not SRC.exists():
        raise SystemExit(f"missing {SRC}")
    RAW.parent.mkdir(parents=True, exist_ok=True)
    RAW.write_bytes(SRC.read_bytes())
    bpy.ops.import_scene.gltf(filepath=str(SRC))
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for o in list(bpy.context.scene.objects):
        if o.type != "MESH":
            bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = "OC_Q"
    apply_tr(obj)

    x0, x1, y0, y1, z0, z1 = world_bounds(obj)
    print("imported size", round(x1 - x0, 3), round(y1 - y0, 3), round(z1 - z0, 3))
    dx, dy, dz = x1 - x0, y1 - y0, z1 - z0
    if dy > dz * 1.15 and dy > dx:
        obj.rotation_euler = (1.57079632679, 0, 0)
        apply_tr(obj)
        x0, x1, y0, y1, z0, z1 = world_bounds(obj)

    s = H / max(z1 - z0, 1e-5)
    obj.scale = (s, s, s)
    apply_tr(obj)
    x0, x1, y0, y1, z0, z1 = world_bounds(obj)
    obj.location.x -= (x0 + x1) * 0.5
    obj.location.y -= (y0 + y1) * 0.5
    obj.location.z -= z0
    apply_tr(obj)
    x0, x1, y0, y1, z0, z1 = world_bounds(obj)
    print("posed size", round(x1 - x0, 3), round(y1 - y0, 3), round(z1 - z0, 3), "z", round(z0, 3), round(z1, 3))
    return obj, z1 - z0


def paint_body(obj, h, mats, keys):
    """Vertex-colour painting with blurring — replaces face-based slots."""
    import bmesh
    mesh = obj.data
    mw = obj.matrix_world
    vcolors = []
    for v in mesh.vertices:
        c = VCOLORS[classify(mw @ v.co, h)]
        vcolors.append([c[0], c[1], c[2], 1.0])
    adj = [[] for _ in mesh.vertices]
    for e in mesh.edges:
        a, b = e.vertices
        adj[a].append(b)
        adj[b].append(a)
    for _ in range(8):
        nxt = [c[:] for c in vcolors]
        for i, nbrs in enumerate(adj):
            if not nbrs:
                continue
            r = g = b = 0.0
            for n in nbrs:
                r += vcolors[n][0]; g += vcolors[n][1]; b += vcolors[n][2]
            nn = len(nbrs)
            nxt[i][0] = vcolors[i][0]*0.6 + r/nn*0.4
            nxt[i][1] = vcolors[i][1]*0.6 + g/nn*0.4
            nxt[i][2] = vcolors[i][2]*0.6 + b/nn*0.4
        vcolors = nxt
    if mesh.vertex_colors:
        vcol = mesh.vertex_colors[0]
    else:
        vcol = mesh.vertex_colors.new(name="Color")
    for loop in mesh.loops:
        c = vcolors[loop.vertex_index]
        vcol.data[loop.index].color = (c[0], c[1], c[2], 1.0)
    bodyvc = bpy.data.materials.get("BodyVC") or bpy.data.materials.new("BodyVC")
    bodyvc.use_nodes = True
    nt = bodyvc.node_tree; nt.nodes.clear()
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    vc = nt.nodes.new("ShaderNodeVertexColor"); vc.layer_name = "Color"
    nt.links.new(vc.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    bodyvc.diffuse_color = (0.8, 0.8, 0.8, 1.0)
    mesh.materials.clear()
    mesh.materials.append(bodyvc)
    bpy.ops.object.shade_smooth()


def smooth_hair(obj):
    """Subdivide body mesh for smoother hair, push back extreme bangs."""
    mw = obj.matrix_world
    # Push back bangs that cover eyes
    for v in obj.data.vertices:
        wv = mw @ v.co
        if 0.64 < wv.z < 0.80 and wv.y < -0.17:
            v.co = mw.inverted() @ Vector((wv.x, -0.14, wv.z))
    # Subdivision surface for smooth hair
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    mod = obj.modifiers.new("Subsurf", "SUBSURF")
    mod.subdivision_type = "CATMULL_CLARK"
    mod.levels = 3
    mod.render_levels = 3
    bpy.ops.object.modifier_apply(modifier="Subsurf")
    bpy.ops.object.shade_smooth()


def main():
    bq.clear_scene()
    obj, h = pose_source()

    mats = {
        "skin": mat("Skin", (0.98, 0.88, 0.82, 1.0), 0.68),
        "hair": mat("Hair", (0.48, 0.84, 0.80, 1.0), 0.46),
        "hair_d": mat("HairDark", bq.C_HAIR_DARK, 0.52),
        "cream": mat("Cream", bq.C_CREAM, 0.62),
        "coral": mat("Coral", bq.C_CORAL, 0.50),
        "char": mat("Charcoal", bq.C_CHAR, 0.58),
        "mint": mat("Mint", bq.C_MINT, 0.50),
        "boot": mat("Boot", bq.C_BOOT, 0.42),
        "iris": mat("Iris", bq.C_IRIS, 0.35),
        "pupil": mat("Pupil", bq.C_PUPIL, 0.40),
        "white": mat("White", bq.C_WHITE, 0.45),
        "blush": mat("Blush", bq.C_BLUSH, 0.80),
    }
    body_keys = ["skin", "hair", "cream", "char", "mint", "boot"]
    paint_body(obj, h, mats, body_keys)
    smooth_hair(obj)

    extras = [add_face_cap(mats)]
    extras.append(add_neck(mats))
    extras.extend(add_eyes(mats))
    extras.extend(add_face_extras(mats))
    extras.extend(add_clothes_extras(mats))
    extras.extend(add_hair_ties(obj, mats))

    face = bpy.data.objects.new("Face", None)
    bpy.context.collection.objects.link(face)
    for o in extras:
        o.parent = face

    x0, x1, y0, y1, z0, z1 = world_bounds(obj)
    center = Vector(((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2))
    size = Vector((x1 - x0, y1 - y0, z1 - z0))
    render_views(center, size, "triposg")
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT_BLEND))
    export_glb(OUT_GLB)
    export_glb(RES_GLB)
    print("DONE face assets", [o.name for o in extras])


if __name__ == "__main__":
    main()
