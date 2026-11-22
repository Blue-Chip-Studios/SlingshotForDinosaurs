"""
SlingshotForDinosaurs: stylised world props (Blender 5.x).

Same visual language as dino_generator.py: soft, chunky, exaggerated
shapes. Each prop is exported as an FBX whose meshes are named by colour
role; WorldBuilder colours/material-izes them in game (PROP_ROLES in
Modules/Server/WorldBuilder.luau). Feet on z = 0, forward -Y.

Roles used: Trunk, Leaves, Leaves2, Rock, RockDark, Ice, Snow, Lava, Glow,
Wood, Band, Stone, Gold, Bait, BaitAccent, Water.
"""

import math
import os
import random

import bpy
from mathutils import Euler, Vector

exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)) if "__file__" in dir() else r"C:\Users\santa\SlingshotForDinosaurs\Assets\Blender\scripts", "dino_generator.py")).read()) if "Builder" not in dir() else None

PREVIEW = {
    "Trunk": (0.55, 0.35, 0.17), "Leaves": (0.18, 0.66, 0.18), "Leaves2": (0.42, 0.56, 0.14), "Rock": (0.55, 0.47, 0.40),
    "RockDark": (0.23, 0.18, 0.16), "Ice": (0.66, 0.87, 0.96), "Snow": (0.96, 0.98, 1.0), "Lava": (1.0, 0.42, 0.1),
    "Glow": (0.37, 0.78, 0.95), "Wood": (0.55, 0.35, 0.17), "Band": (0.85, 0.2, 0.25), "Stone": (0.93, 0.9, 0.85),
    "Gold": (1.0, 0.77, 0.19), "Bait": (0.85, 0.15, 0.35), "BaitAccent": (0.2, 0.6, 0.2), "Water": (0.3, 0.7, 0.9),
}


class PropBuilder:
    def __init__(self, name):
        self.name = name
        coll = bpy.data.collections.get(name)
        if coll:
            for obj in list(coll.objects):
                bpy.data.objects.remove(obj, do_unlink=True)
        else:
            coll = bpy.data.collections.new(name)
            bpy.context.scene.collection.children.link(coll)
        self.coll = coll
        self.parts = {}

    def _add(self, obj, role):
        for c in obj.users_collection:
            c.objects.unlink(obj)
        self.coll.objects.link(obj)
        self.parts.setdefault(role, []).append(obj)
        return obj

    def ico(self, role, loc, scale, sub=2, jitter=0.0, rot=(0, 0, 0)):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub, location=loc, rotation=Euler([math.radians(a) for a in rot]))
        o = bpy.context.active_object
        o.scale = scale
        if jitter:
            for v in o.data.vertices:
                v.co += Vector((random.uniform(-jitter, jitter), random.uniform(-jitter, jitter), random.uniform(-jitter, jitter)))
        return self._add(o, role)

    def cyl(self, role, loc, r, depth, rot=(0, 0, 0), verts=12, r2=None, bevel=0.0):
        if r2 is None:
            bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc, rotation=Euler([math.radians(a) for a in rot]))
        else:
            bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=depth, location=loc, rotation=Euler([math.radians(a) for a in rot]))
        o = bpy.context.active_object
        if bevel:
            m = o.modifiers.new("Bevel", "BEVEL")
            m.width = bevel
            m.segments = 2
        return self._add(o, role)

    def box(self, role, loc, scale, rot=(0, 0, 0), bevel=0.2):
        bpy.ops.mesh.primitive_cube_add(location=loc, rotation=Euler([math.radians(a) for a in rot]))
        o = bpy.context.active_object
        o.scale = scale
        m = o.modifiers.new("Bevel", "BEVEL")
        m.width = bevel * min(scale)
        m.segments = 2
        m.limit_method = "NONE"
        return self._add(o, role)

    def torus(self, role, loc, major, minor, rot=(0, 0, 0)):
        bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=24, minor_segments=8, location=loc, rotation=Euler([math.radians(a) for a in rot]))
        return self._add(bpy.context.active_object, role)

    def finish(self, smooth_roles=("Leaves", "Leaves2", "Bait", "Snow", "Water")):
        out = {}
        for role, objs in self.parts.items():
            bpy.ops.object.select_all(action="DESELECT")
            for o in objs:
                bpy.context.view_layer.objects.active = o
                for m in list(o.modifiers):
                    bpy.ops.object.modifier_apply(modifier=m.name)
                o.select_set(True)
            bpy.context.view_layer.objects.active = objs[0]
            if len(objs) > 1:
                bpy.ops.object.join()
            o = bpy.context.active_object
            o.name = role
            o.data.name = f"{self.name}_{role}"
            if role in smooth_roles:
                bpy.ops.object.shade_smooth()
            else:
                bpy.ops.object.shade_flat()
            bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
            mat = bpy.data.materials.get(f"SFD_{role}") or bpy.data.materials.new(f"SFD_{role}")
            mat.use_nodes = True
            mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*PREVIEW.get(role, (1, 1, 1)), 1)
            o.data.materials.clear()
            o.data.materials.append(mat)
            out[role] = o
        return out


def jungle_tree(b):
    random.seed(1)
    b.cyl("Trunk", (0, 0, 3), 0.55, 6, verts=8, r2=0.35)
    for i, (x, y, z, s) in enumerate(((0, 0, 7.2, 2.6), (1.6, 0.4, 6.4, 1.8), (-1.5, -0.3, 6.6, 1.9), (0.3, -1.4, 6.8, 1.7), (-0.2, 1.3, 7.8, 1.6))):
        b.ico("Leaves" if i % 2 == 0 else "Leaves2", (x, y, z), (s, s, s * 0.8), sub=2, jitter=0.12)


def swamp_tree(b):
    random.seed(2)
    for a in range(4):  # mangrove roots
        ang = a * math.pi / 2 + 0.4
        b.cyl("Trunk", (math.cos(ang) * 0.9, math.sin(ang) * 0.9, 0.9), 0.18, 2.2, rot=(math.degrees(math.sin(ang)) * 0.5, -math.degrees(math.cos(ang)) * 0.5, 0), verts=6)
    b.cyl("Trunk", (0, 0, 3.2), 0.45, 4.8, verts=8, r2=0.3)
    for (x, y, z, s) in ((0, 0, 6.2, 2.3), (1.4, 0.6, 5.6, 1.5), (-1.3, -0.5, 5.8, 1.6)):
        b.ico("Leaves2", (x, y, z), (s * 1.2, s * 1.2, s * 0.55), sub=2, jitter=0.15)


def rock(b, role="Rock", seed=3):
    random.seed(seed)
    b.ico(role, (0, 0, 0.8), (1.6, 1.3, 1.1), sub=1, jitter=0.25)
    b.ico(role, (1.1, 0.4, 0.5), (0.8, 0.7, 0.6), sub=1, jitter=0.2)


def tar_rock(b):
    rock(b, "RockDark", 4)
    random.seed(5)
    for i in range(3):  # amber nuggets
        b.ico("Gold", (random.uniform(-1, 1), random.uniform(-0.8, 0.8), random.uniform(1.2, 1.7)), (0.25, 0.25, 0.25), sub=1, jitter=0.05)


def ice_block(b):
    random.seed(6)
    b.box("Ice", (0, 0, 1.3), (1.3, 1.1, 1.3), rot=(0, 0, 12), bevel=0.25)
    b.box("Ice", (1.4, 0.3, 0.7), (0.7, 0.6, 0.7), rot=(0, 0, -20), bevel=0.25)
    b.ico("Snow", (0, 0, 2.55), (1.25, 1.05, 0.25), sub=2)


def lava_rock(b):
    rock(b, "RockDark", 7)
    random.seed(8)
    for i in range(4):  # glowing cracks
        b.box("Lava", (random.uniform(-0.8, 0.8), random.uniform(-0.6, 0.6), random.uniform(1.4, 1.75)), (0.5, 0.08, 0.06), rot=(0, 0, random.uniform(0, 180)), bevel=0.4)


def volcano(b):
    random.seed(9)
    b.cyl("RockDark", (0, 0, 22), 60, 44, verts=18, r2=14)
    b.cyl("Lava", (0, 0, 44.2), 13, 1.2, verts=18)
    for i in range(10):  # lava streams down the flanks
        a = i / 10 * math.tau
        b.box("Lava", (math.cos(a) * 30, math.sin(a) * 30, 24), (1.2, 18, 0.6), rot=(math.degrees(math.atan2(44, 46)) * 0.9, 0, math.degrees(a) - 90), bevel=0.4)
    for i in range(14):
        a = random.uniform(0, math.tau)
        r = random.uniform(40, 62)
        b.ico("Rock", (math.cos(a) * r, math.sin(a) * r, 2), (random.uniform(3, 6),) * 3, sub=1, jitter=0.8)


def geyser_vent(b):
    random.seed(10)
    for i in range(7):
        a = i / 7 * math.tau
        b.ico("Rock", (math.cos(a) * 2.2, math.sin(a) * 2.2, 0.4), (0.9, 0.9, 0.7), sub=1, jitter=0.15)
    b.cyl("Water", (0, 0, 0.25), 1.8, 0.5, verts=16)
    b.cyl("Glow", (0, 0, 0.55), 1.2, 0.2, verts=16)


def launch_slingshot(b):
    # Giant Y-frame at each plot's launch stand.
    b.cyl("Wood", (0, 0, 2.2), 0.7, 4.4, verts=10, bevel=0.1)
    for side in (-1, 1):
        b.cyl("Wood", (side * 1.6, 0, 5.8), 0.5, 4.2, rot=(0, side * 25, 0), verts=10, bevel=0.1)
        b.ico("Wood", (side * 2.5, 0, 7.6), (0.6, 0.6, 0.6), sub=2)
    b.box("Band", (0, 0.6, 6.4), (2.5, 0.12, 0.25), bevel=0.4)
    b.box("Band", (0, 1.2, 6.3), (0.6, 0.5, 0.4), bevel=0.4)  # pouch
    b.cyl("Stone", (0, 0, 0.25), 2.4, 0.5, verts=16, bevel=0.1)


def slingshot_item(b):
    # Hand slingshot for pedestals (recoloured per tier in game).
    b.cyl("Wood", (0, 0, 1.0), 0.18, 2.0, verts=8, bevel=0.03)
    for side in (-1, 1):
        b.cyl("Wood", (side * 0.45, 0, 2.45), 0.14, 1.2, rot=(0, side * 25, 0), verts=8)
    b.box("Band", (0, 0.1, 2.75), (0.7, 0.05, 0.08), bevel=0.4)
    b.box("Band", (0, 0.35, 2.7), (0.2, 0.18, 0.15), bevel=0.4)


def bait_item(b, kind):
    random.seed(11)
    if kind == "Berries":
        for (x, y, z) in ((0, 0, 0.6), (0.5, 0.2, 0.55), (-0.45, 0.25, 0.55), (0.1, -0.4, 0.5), (0.05, 0.1, 1.05)):
            b.ico("Bait", (x, y, z), (0.42,) * 3, sub=2)
        b.box("BaitAccent", (0, 0, 1.45), (0.35, 0.12, 0.05), rot=(0, 0, 30), bevel=0.4)
    elif kind == "Fish":
        b.ico("Bait", (0, 0, 0.8), (1.0, 0.35, 0.55), sub=2)
        b.cyl("BaitAccent", (1.15, 0, 0.8), 0.45, 0.1, rot=(90, 0, 0), verts=3)
        b.ico("Stone", (-0.65, -0.28, 0.95), (0.1,) * 3, sub=1)
    elif kind == "Steak":
        b.ico("Bait", (0, 0, 0.5), (1.0, 0.75, 0.3), sub=2, jitter=0.06)
        b.cyl("Stone", (0.9, 0, 0.5), 0.12, 1.0, rot=(0, 90, 0), verts=8)
        b.ico("Stone", (1.45, 0, 0.5), (0.2,) * 3, sub=1)
    elif kind == "GoldenEgg":
        b.ico("Gold", (0, 0, 0.9), (0.7, 0.7, 0.95), sub=3)
        b.torus("Stone", (0, 0, 0.9), 0.62, 0.06)
    elif kind == "AmberMosquito":
        b.ico("Gold", (0, 0, 0.9), (0.75, 0.6, 0.85), sub=1, jitter=0.05)
        b.ico("RockDark", (0, -0.1, 0.95), (0.18, 0.4, 0.15), sub=1)
    elif kind == "MeteorMeat":
        b.ico("RockDark", (0, 0, 0.8), (0.85, 0.8, 0.75), sub=1, jitter=0.15)
        for i in range(5):
            b.box("Lava", (random.uniform(-0.5, 0.5), random.uniform(-0.5, 0.5), random.uniform(0.9, 1.4)), (0.35, 0.06, 0.05), rot=(0, 0, random.uniform(0, 180)), bevel=0.4)


def cliff_wall(b):
    # 40 wide (X) x 20 deep (Y) x ~70 tall chunky rock wall module with strata bands and a grassy cap.
    random.seed(12)
    for i in range(7):  # stacked, overlapping boulder strata form the face
        for j in range(4):
            x = -18 + j * 12 + random.uniform(-1.5, 1.5) + (6 if i % 2 else 0)
            z = 5 + i * 10 + random.uniform(-1, 1)
            s = random.uniform(7.5, 9.5)
            b.ico("Rock" if i % 2 == 0 else "RockDark", (x, random.uniform(-1.0, 1.0), z), (s, 8, s * 0.7), sub=2, jitter=0.12)
    for j in range(5):  # grass cap
        b.ico("Leaves", (-18 + j * 9, 0, 73), (6.5, 8.5, 2.4), sub=2, jitter=0.12)


def fence_segment(b):
    for x in (-2.2, 2.2):
        b.box("Wood", (x, 0, 1.6), (0.35, 0.35, 1.6), bevel=0.3)
        b.cone("Wood", (x, 0, 3.45), 0.4, 0.5, verts=4) if hasattr(b, "cone") else b.cyl("Wood", (x, 0, 3.45), 0.4, 0.5, verts=4, r2=0)
    for z in (1.2, 2.5):
        b.box("Wood", (0, 0, z), (2.6, 0.18, 0.28), rot=(0, random.uniform(-3, 3), 0), bevel=0.3)


def signpost(b):
    b.box("Wood", (0, 0, 2.5), (0.3, 0.3, 2.5), bevel=0.3)
    b.box("Wood", (0, -0.1, 4.6), (2.4, 0.2, 0.9), rot=(0, 3, 0), bevel=0.25)


def training_pad(b):
    b.cyl("Stone", (0, 0, 0.4), 8.6, 0.8, verts=24, bevel=0.15)
    b.cyl("Glow", (0, 0, 0.85), 6.4, 0.2, verts=24)
    for i in range(8):  # stone studs around the rim
        a = i / 8 * math.tau
        b.ico("Rock", (math.cos(a) * 7.6, math.sin(a) * 7.6, 1.0), (0.9, 0.9, 0.7), sub=1, jitter=0.1)


def grass_clump(b):
    random.seed(13)
    for i in range(7):
        a = random.uniform(0, math.tau)
        b.cyl("Leaves", (math.cos(a) * 0.5, math.sin(a) * 0.5, 0.8), 0.25, 1.6, rot=(random.uniform(-25, 25), random.uniform(-25, 25), 0), verts=4, r2=0)


def bones(b):
    b.cyl("Stone", (0, 0, 0.4), 0.3, 4, rot=(0, 90, 0), verts=8)
    for i in range(5):  # ribcage
        b.torus("Stone", (-1.4 + i * 0.7, 0, 1.0), 0.9, 0.12, rot=(0, 90, 0))
    b.ico("Stone", (2.4, 0, 0.7), (0.8, 0.6, 0.6), sub=2)


def crystal(b):
    random.seed(14)
    for i in range(5):
        a = random.uniform(0, math.tau)
        h = random.uniform(2, 4.5)
        b.cyl("Ice", (math.cos(a) * 0.7, math.sin(a) * 0.7, h / 2), 0.45, h, rot=(random.uniform(-20, 20), random.uniform(-20, 20), 0), verts=6, r2=0.05)


PROPS = {
    "CliffWall": cliff_wall,
    "FenceSegment": fence_segment,
    "Signpost": signpost,
    "TrainingPad": training_pad,
    "GrassClump": grass_clump,
    "Bones": bones,
    "Crystal": crystal,
    "JungleTree": jungle_tree,
    "SwampTree": swamp_tree,
    "Rock": rock,
    "TarRock": tar_rock,
    "IceBlock": ice_block,
    "LavaRock": lava_rock,
    "Volcano": volcano,
    "GeyserVent": geyser_vent,
    "LaunchSlingshot": launch_slingshot,
    "SlingshotItem": slingshot_item,
    "Bait_Berries": lambda b: bait_item(b, "Berries"),
    "Bait_Fish": lambda b: bait_item(b, "Fish"),
    "Bait_Steak": lambda b: bait_item(b, "Steak"),
    "Bait_GoldenEgg": lambda b: bait_item(b, "GoldenEgg"),
    "Bait_AmberMosquito": lambda b: bait_item(b, "AmberMosquito"),
    "Bait_MeteorMeat": lambda b: bait_item(b, "MeteorMeat"),
}


def build_prop(name, location=(0, 0, 0)):
    b = PropBuilder(name)
    PROPS[name](b)
    objs = b.finish()
    for o in objs.values():
        o.location = Vector(o.location) + Vector(location)
    return objs


def export_prop(name, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    coll = bpy.data.collections[name]
    objs = list(coll.objects)
    offset = Vector((sum(o.location.x for o in objs) / len(objs), sum(o.location.y for o in objs) / len(objs), 0))
    for o in objs:
        o.location -= offset
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    path = os.path.join(out_dir, f"{name}.fbx")
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"MESH"}, apply_unit_scale=True,
                             apply_scale_options="FBX_SCALE_ALL", axis_forward="-Z", axis_up="Y", mesh_smooth_type="FACE",
                             add_leaf_bones=False, bake_anim=False)
    for o in objs:
        o.location += offset
    return path
