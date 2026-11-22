"""
SlingshotForDinosaurs: store thumbnails + icon (Blender 5.x).

Matches the reference style the team supplied (Docs/UI/References + the
"DOHA RP" examples): saturated sunset sky, glossy chrome 3D logo with a
hot-pink second word and a silhouette ornament top-left, cheering blocky
Roblox-style avatars in the foreground, one hero subject, sparkle/glow.

Builds into its own scene ("Thumbs") so the asset scene stays clean.
    exec(open(r"<repo>/Assets/Blender/scripts/thumbnails.py").read())
    render_all(out_dir)
"""

import math
import os
import random

import bpy
from mathutils import Euler, Vector

ROOT = r"C:\Users\santa\SlingshotForDinosaurs\Assets\Blender\scripts"
exec(open(os.path.join(ROOT, "dino_generator.py")).read())
exec(open(os.path.join(ROOT, "world_props.py")).read())

FONT = r"C:\Windows\Fonts\ariblk.ttf"


def mat(name, rgb, metal=0.0, rough=0.4, emit=0.0, alpha=1.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    if emit > 0:
        b.inputs["Emission Color"].default_value = (*rgb, 1)
        b.inputs["Emission Strength"].default_value = emit
    if alpha < 1:
        b.inputs["Alpha"].default_value = alpha
    return m


def outline(obj, thick=0.04):
    ink = mat("THUMB_Ink", (0.02, 0.015, 0.04), rough=1)
    ink.use_backface_culling = True
    obj.data.materials.append(ink)
    s = obj.modifiers.new("Outline", "SOLIDIFY")
    s.thickness = thick
    s.offset = 1
    s.use_flip_normals = True
    s.use_rim = False
    s.material_offset = len(obj.data.materials) - 1


def setup_scene():
    sc = bpy.data.scenes.get("Thumbs") or bpy.data.scenes.new("Thumbs")
    # Never delete asset-scene objects: unlink foreign collections first, then
    # remove only this scene's own loose objects.
    for c in list(sc.collection.children):
        if not (c.name.startswith("THUMB_") or c.name.startswith("Av")):
            sc.collection.children.unlink(c)
    for o in list(sc.collection.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for c in list(bpy.data.collections):
        if c.name.startswith("THUMB_") or c.name.startswith("Av"):
            for o in list(c.objects):
                bpy.data.objects.remove(o, do_unlink=True)
            bpy.data.collections.remove(c)
    bpy.context.window.scene = sc
    sc.render.engine = "BLENDER_EEVEE"
    sc.view_settings.view_transform = "Standard"
    sc.render.film_transparent = False
    # Sunset sky gradient
    w = bpy.data.worlds.get("THUMB_Sky") or bpy.data.worlds.new("THUMB_Sky")
    w.use_nodes = True
    nt = w.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputWorld")
    bg = nt.nodes.new("ShaderNodeBackground")
    # Sunset: physical sky with a low sun, tinted warm-pink for the punchy thumbnail look.
    sky = nt.nodes.new("ShaderNodeTexSky")
    try:
        sky.sun_elevation = math.radians(4)
        sky.sun_rotation = math.radians(200)
    except Exception:
        pass
    tint = nt.nodes.new("ShaderNodeMix")
    tint.data_type = "RGBA"
    tint.blend_type = "MULTIPLY"
    tint.inputs[0].default_value = 0.8
    tint.inputs[7].default_value = (1.0, 0.55, 0.8, 1)
    nt.links.new(sky.outputs["Color"], tint.inputs[6])
    nt.links.new(tint.outputs[2], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = 0.3  # physical sky is very bright in Standard view
    nt.links.new(bg.outputs["Background"], out.inputs["Surface"])
    sc.world = w
    # Sun (warm, low) + cool fill
    sun = bpy.data.objects.new("THUMB_Sun", bpy.data.lights.new("THUMB_Sun", "SUN"))
    sun.data.energy = 4.0
    sun.data.color = (1.0, 0.85, 0.7)
    sun.rotation_euler = (math.radians(55), 0, math.radians(25))  # from behind the camera: lit faces
    sc.collection.objects.link(sun)
    fill = bpy.data.objects.new("THUMB_Fill", bpy.data.lights.new("THUMB_Fill", "SUN"))
    fill.data.energy = 2.5  # pink rim light from behind
    fill.data.color = (1.0, 0.45, 0.8)
    fill.rotation_euler = (math.radians(70), 0, math.radians(150))
    sc.collection.objects.link(fill)
    cam = bpy.data.objects.new("THUMB_Cam", bpy.data.cameras.new("THUMB_Cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    return sc, cam


def link_collection(name):
    """Clones a built generator collection (from the asset scene) into the thumbnail scene."""
    src = bpy.data.collections[name]
    sc = bpy.context.scene
    new = bpy.data.collections.new("THUMB_" + name)
    sc.collection.children.link(new)
    for o in src.objects:
        d = o.copy()
        d.data = o.data.copy()
        d.name = o.name.split(".")[0]
        for m in list(d.modifiers):
            d.modifiers.remove(m)
        new.objects.link(d)
    # Recentre on the origin (feet stay at z = 0): the asset scene lays models out in a grid.
    objs = list(new.objects)
    if objs:
        cx = sum(o.matrix_world.translation.x for o in objs) / len(objs)
        cy = sum(o.matrix_world.translation.y for o in objs) / len(objs)
        for o in objs:
            o.matrix_world = Matrix.Translation(Vector((-cx, -cy, 0))) @ o.matrix_world
    return new


def place(coll, loc, rot_z=0.0, scale=1.0):
    for o in coll.objects:
        o.matrix_world = (
            Matrix.Translation(Vector(loc)) @ Matrix.Rotation(math.radians(rot_z), 4, "Z") @ Matrix.Scale(scale, 4) @ o.matrix_world
        )


def avatar(name, loc, shirt, pants, rot_z=0, arms="up", hat=None):
    """Blocky Roblox-style R6 avatar cheering. Returns the collection."""
    coll = bpy.data.collections.get(name) or bpy.data.collections.new(name)
    for o in list(coll.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    if coll.name not in bpy.context.scene.collection.children:
        bpy.context.scene.collection.children.link(coll)
    skin = mat("THUMB_Skin", (1.0, 0.82, 0.5), rough=0.35, emit=0.35)
    parts = []

    def block(n, size, pos, m, rot=(0, 0, 0), bevel=0.12):
        bpy.ops.mesh.primitive_cube_add(location=pos, rotation=Euler([math.radians(a) for a in rot]))
        o = bpy.context.active_object
        o.name = f"{name}_{n}"
        o.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
        bv = o.modifiers.new("Bevel", "BEVEL")
        bv.width = bevel
        bv.segments = 3
        bpy.ops.object.shade_smooth()
        o.data.materials.append(m)
        for c in o.users_collection:
            c.objects.unlink(o)
        coll.objects.link(o)
        parts.append(o)
        return o

    block("Torso", (2, 1, 2), (0, 0, 3), mat(f"THUMB_{name}_Shirt", shirt, rough=0.5, emit=0.25))
    block("LegL", (1, 1, 2), (-0.5, 0, 1), mat(f"THUMB_{name}_Pants", pants, rough=0.6))
    block("LegR", (1, 1, 2), (0.5, 0, 1), mat(f"THUMB_{name}_Pants", pants, rough=0.6))
    if arms == "up":
        # Arms raised in a wide V, clear of the head (the cheering pose from the references).
        block("ArmL", (1, 1, 2), (-1.9, 0, 4.5), mat(f"THUMB_{name}_Shirt", shirt), rot=(0, 140, 0))
        block("ArmR", (1, 1, 2), (1.9, 0, 4.5), mat(f"THUMB_{name}_Shirt", shirt), rot=(0, -140, 0))
    else:  # pulling a slingshot: arms forward
        block("ArmL", (1, 1, 2), (-1.4, -0.9, 3.6), mat(f"THUMB_{name}_Shirt", shirt), rot=(70, 0, 10))
        block("ArmR", (1, 1, 2), (1.4, -0.9, 3.6), mat(f"THUMB_{name}_Shirt", shirt), rot=(70, 0, -10))
    head = block("Head", (1.3, 1.3, 1.25), (0, 0, 4.65), skin, bevel=0.3)
    # Face: big happy eyes + smile
    ink = mat("THUMB_Face", (0.05, 0.04, 0.06), rough=0.3)
    for sx in (-0.25, 0.25):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.11, location=(sx, -0.66, 4.8))
        e = bpy.context.active_object
        e.scale = (1, 0.4, 1.3)
        e.data.materials.append(ink)
        for c in e.users_collection:
            c.objects.unlink(e)
        coll.objects.link(e)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.3, minor_radius=0.05, location=(0, -0.64, 4.45), rotation=(math.radians(90), 0, 0))
    sm = bpy.context.active_object
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="DESELECT")
    bpy.ops.object.mode_set(mode="OBJECT")
    for v in sm.data.vertices:
        v.select = v.co.z > 0.0  # local before rotation -> top half
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.delete(type="VERT")
    bpy.ops.object.mode_set(mode="OBJECT")
    sm.data.materials.append(ink)
    for c in sm.users_collection:
        c.objects.unlink(sm)
    coll.objects.link(sm)
    if hat == "cap":
        block("Cap", (1.4, 1.4, 0.5), (0, 0, 5.4), mat("THUMB_CapWhite", (0.97, 0.97, 0.97)), bevel=0.2)
        block("Brim", (1.2, 0.8, 0.15), (0, -0.85, 5.25), mat("THUMB_CapWhite", (0.97, 0.97, 0.97)), bevel=0.05)
    elif hat == "safari":
        block("Hat", (1.8, 1.8, 0.2), (0, 0, 5.3), mat("THUMB_Safari", (0.85, 0.72, 0.45)), bevel=0.08)
        block("HatTop", (1.3, 1.3, 0.6), (0, 0, 5.6), mat("THUMB_Safari", (0.85, 0.72, 0.45)), bevel=0.2)
    for o in coll.objects:
        o.matrix_world = Matrix.Translation(Vector(loc)) @ Matrix.Rotation(math.radians(rot_z), 4, "Z") @ o.matrix_world
        if o.type == "MESH":
            outline(o, 0.05)
    return coll


def logo(cam, words=("SLINGSHOT", "FOR DINOSAURS")):
    """Chrome + hot-pink 3D logo parented to the camera, top-left of frame."""
    parent = bpy.data.objects.new("THUMB_LogoRoot", None)
    bpy.context.scene.collection.objects.link(parent)
    parent.parent = cam
    parent.location = (-3.0, 1.15, -6)
    parent.rotation_euler = (0, 0, math.radians(4))
    font = bpy.data.fonts.load(FONT, check_existing=True)
    chrome = mat("THUMB_Chrome", (0.95, 0.96, 1.0), metal=1.0, rough=0.12)
    pink = mat("THUMB_Pink", (1.0, 0.12, 0.45), metal=0.3, rough=0.25, emit=0.6)
    gold = mat("THUMB_LogoGold", (1.0, 0.75, 0.15), metal=0.8, rough=0.2)

    def txt(body, size, y, m, x=0.0):
        cu = bpy.data.curves.new(f"THUMB_{body}", "FONT")
        cu.body = body
        cu.font = font
        cu.size = size
        cu.extrude = 0.06 * size
        cu.bevel_depth = 0.02 * size
        cu.bevel_resolution = 2
        cu.shear = 0.18
        o = bpy.data.objects.new(f"THUMB_{body}", cu)
        bpy.context.scene.collection.objects.link(o)
        o.parent = parent
        o.location = (x, y, 0)
        o.data.materials.append(m)
        return o

    t1 = txt(words[0], 0.74, 0.0, chrome)
    t2 = txt(words[1], 0.5, -0.72, pink, x=0.05)
    # Convert to mesh so the inverted-hull outline works.
    for o in (t1, t2):
        bpy.context.view_layer.objects.active = o
        o.select_set(True)
        bpy.ops.object.convert(target="MESH")
        outline(o, 0.035)
        o.select_set(False)
    return parent


def sparkles(center, radius, count, colour=(1, 0.9, 0.5), size=0.15, seed=1):
    random.seed(seed)
    m = mat(f"THUMB_Sparkle_{seed}", colour, emit=8)
    for i in range(count):
        p = Vector(center) + Vector((random.uniform(-1, 1), random.uniform(-1, 1), random.uniform(-0.5, 1))) * radius
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=size * random.uniform(0.5, 1.4), location=p)
        bpy.context.active_object.data.materials.append(m)


def cosmic_trex(loc, rot_z, scale):
    pass  # TRex already built in the asset scene
    coll = link_collection("TRex")
    cosmic = mat("THUMB_Cosmic", (0.45, 0.15, 0.95), metal=0.4, rough=0.15, emit=1.2)
    cosmic2 = mat("THUMB_Cosmic2", (1.0, 0.35, 0.85), metal=0.3, rough=0.2, emit=1.6)
    for o in coll.objects:
        if o.name.startswith(("Body", "Belly")):
            o.data.materials.clear()
            o.data.materials.append(cosmic if o.name.startswith("Body") else cosmic2)
        elif o.name.startswith("Accent"):
            o.data.materials.clear()
            o.data.materials.append(cosmic2)
        o.matrix_world = Matrix.Translation(Vector(loc)) @ Matrix.Rotation(math.radians(rot_z), 4, "Z") @ Matrix.Scale(scale, 4) @ o.matrix_world
        outline(o, 0.03)
    sparkles(Vector(loc) + Vector((0, 0, 4 * scale)), 3.5 * scale, 40, (0.85, 0.6, 1.0), 0.18, seed=7)
    return coll


def ground_and_world(volcano=True):
    sc = bpy.context.scene
    bpy.ops.mesh.primitive_plane_add(size=400, location=(0, 60, 0))
    g = bpy.context.active_object
    g.data.materials.append(mat("THUMB_Grass", (0.3, 0.75, 0.2), rough=0.8))
    if volcano:
        pass
        c = link_collection("Volcano")
        for o in c.objects:
            o.matrix_world = Matrix.Translation(Vector((10, 160, -5))) @ Matrix.Scale(1.2, 4) @ o.matrix_world
            if o.name.startswith("Lava"):
                o.data.materials.clear()
                o.data.materials.append(mat("THUMB_Lava", (1.0, 0.4, 0.05), emit=6))
    random.seed(3)
    for i in range(10):
        pass
        c = link_collection("JungleTree")
        # clone the tree each time by duplicating its objects
        side = -1 if i % 2 == 0 else 1
        pos = Vector((side * random.uniform(14, 30), random.uniform(10, 70), 0))
        for o in list(c.objects):
            d = o.copy()
            d.data = o.data.copy()
            sc.collection.objects.link(d)
            d.matrix_world = Matrix.Translation(pos) @ Matrix.Scale(random.uniform(1.2, 1.8), 4) @ o.matrix_world
            col = (0.18, 0.72, 0.22) if d.name.startswith("Leaves") else (0.55, 0.33, 0.16)
            d.data.materials.clear()
            d.data.materials.append(mat(f"THUMB_Tree_{col}", col, rough=0.6))
        c.hide_render = True


def render(sc, path, w=1920, h=1080):
    sc.render.resolution_x = w
    sc.render.resolution_y = h
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return path


def thumb_launch(out_dir):
    """Thumbnail 1: avatar at the giant slingshot, bait streaking at the glowing volcano, Cosmic T-Rex roaring."""
    sc, cam = setup_scene()
    ground_and_world()
    pass
    sl = link_collection("LaunchSlingshot")
    for o in sl.objects:
        o.matrix_world = Matrix.Translation(Vector((-4, 2, 0))) @ Matrix.Scale(1.15, 4) @ o.matrix_world
        outline(o, 0.05)
    avatar("AvA", (-7, -6.5, 0), (0.1, 0.75, 0.6), (0.15, 0.15, 0.2), rot_z=-20, arms="up", hat="cap")
    avatar("AvB", (-2.2, -10, 0), (1.0, 0.5, 0.1), (0.1, 0.1, 0.12), rot_z=15, arms="up", hat="safari")
    cosmic_trex((6, 4, 0), -28, 3.6)
    # Bait with a glowing trail heading to the volcano
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.9, location=(-1, 30, 16))
    bpy.context.active_object.data.materials.append(mat("THUMB_Bait", (1.0, 0.85, 0.2), emit=4))
    bpy.ops.mesh.primitive_cone_add(vertices=16, radius1=0.9, depth=14, location=(-2.2, 23, 12), rotation=(math.radians(-62), 0, math.radians(8)))
    bpy.context.active_object.data.materials.append(mat("THUMB_Trail", (1.0, 0.6, 0.2), emit=3, alpha=0.6))
    cam.location = (0, -24, 4.5)
    cam.rotation_euler = (Vector((1, 6, 8.5)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = 25
    logo(cam)
    return render(sc, os.path.join(out_dir, "Thumb_Launch.png"))


def thumb_cosmic(out_dir):
    """Thumbnail 2: giant Colossal Cosmic T-Rex centre stage, cheering avatars, sparkles."""
    sc, cam = setup_scene()
    ground_and_world(volcano=True)
    cosmic_trex((7.5, 10, 0), -24, 4.3)
    avatar("AvA", (-6, -4, 0), (0.95, 0.95, 0.97), (0.85, 0.85, 0.9), rot_z=15, hat="cap")
    avatar("AvB", (0, -7, 0), (0.55, 0.2, 0.85), (0.12, 0.1, 0.2), rot_z=0, hat="safari")
    avatar("AvC", (6, -4, 0), (1.0, 0.45, 0.1), (0.1, 0.1, 0.12), rot_z=-15)
    sparkles((0, 0, 8), 12, 60, (1.0, 0.85, 0.3), 0.2, seed=11)
    cam.location = (0, -26, 7)
    cam.rotation_euler = (Vector((0, 6, 10)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = 28
    logo(cam)
    return render(sc, os.path.join(out_dir, "Thumb_Cosmic.png"))


def icon(out_dir):
    """512x512 game icon: Cosmic T-Rex head close-up + cheering avatar, bold sky."""
    sc, cam = setup_scene()
    ground_and_world(volcano=False)
    cosmic_trex((2.2, 4, 0), -22, 3.4)
    avatar("AvA", (-3, -2, 0), (0.1, 0.75, 0.6), (0.15, 0.15, 0.2), rot_z=10, hat="cap")
    cam.location = (-0.5, -15, 7)
    cam.rotation_euler = (Vector((0.5, 4, 9)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = 28
    return render(sc, os.path.join(out_dir, "GameIcon.png"), 512, 512)


def render_all(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    return [thumb_launch(out_dir), thumb_cosmic(out_dir), icon(out_dir)]
