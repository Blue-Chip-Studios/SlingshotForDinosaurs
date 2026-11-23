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
    "Leather": (0.48, 0.29, 0.16), "Pouch": (0.48, 0.29, 0.16), "TipL": (1, 0, 1), "TipR": (1, 0, 1), "PouchMark": (1, 0, 1),
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
        if bevel > 0:
            m = o.modifiers.new("Bevel", "BEVEL")
            m.width = bevel * min(scale)
            m.segments = 2
            m.limit_method = "NONE"
        return self._add(o, role)

    def torus(self, role, loc, major, minor, rot=(0, 0, 0), segs=(24, 8)):
        bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=segs[0], minor_segments=segs[1], location=loc, rotation=Euler([math.radians(a) for a in rot]))
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
            # Free the plain role name first so the export carries "Rock", not "Rock.003".
            clash = bpy.data.objects.get(role)
            if clash and clash != o:
                clash.name = f"{clash.name}_old"
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


def _limb(b, role, pts, radii, verts=10):
    """Bent branch: tapered segments between the points, with a ball at each bend so it reads as
    one smooth piece of wood."""
    pts = [Vector(p) for p in pts]
    for i in range(len(pts) - 1):
        a, c = pts[i], pts[i + 1]
        d = c - a
        rot = d.to_track_quat("Z", "Y").to_euler()
        b.cyl(role, tuple((a + c) / 2), radii[i], d.length, rot=tuple(math.degrees(x) for x in rot), verts=verts, r2=radii[i + 1])
    for p, r in zip(pts[1:-1], radii[1:-1]):
        b.ico(role, tuple(p), (r, r, r), sub=2)


def _slingshot(b, k=1.0, base=True):
    """The game's slingshot: a gnarled wooden fork with leather grip wraps, dino-tooth tips, fat
    rubber bands and a leather pouch. TipL / TipR mark the band anchors (hidden in game) so the
    launch stand can stretch the bands back while the player charges; Pouch moves with them."""
    def v(x, y, z):
        return (x * k, y * k, z * k)
    random.seed(7)
    z0 = 0.0
    if base:
        # Mossy boulder base with two crossed dino bones and a few pebbles.
        b.ico("Rock", v(0, 0, 0.35), (2.5 * k, 2.1 * k, 0.75 * k), sub=2, jitter=0.12 * k)
        b.ico("Leaves", v(-0.6, -0.5, 0.75), (1.3 * k, 1.0 * k, 0.32 * k), sub=2, jitter=0.08 * k)
        for (x, y, s) in ((1.9, 1.1, 0.45), (-2.1, 0.9, 0.38), (1.4, -1.5, 0.32)):
            b.ico("RockDark", v(x, y, 0.2), (s * k, s * k, s * 0.7 * k), sub=1, jitter=0.05 * k)
        for ang in (25, -35):
            a = math.radians(ang)
            dx, dy = math.cos(a) * 1.15, math.sin(a) * 1.15
            _limb(b, "Stone", [v(-dx, -dy + 0.9, 1.0), v(dx, dy + 0.9, 1.0)], [0.14 * k, 0.14 * k], verts=8)
            for s in (-1, 1):
                for o in (-0.13, 0.13):
                    b.ico("Stone", v(s * dx + o * math.sin(a), s * dy + 0.9 - o * math.cos(a), 1.0), (0.17 * k,) * 3, sub=1)
        z0 = 0.8
    # Trunk: slightly bent, wide at the root.
    _limb(b, "Wood", [v(0, 0, z0), v(0.12, 0.05, z0 + 1.5), v(-0.06, 0, z0 + 2.9), v(0, 0, z0 + 3.6)], [0.85 * k, 0.66 * k, 0.6 * k, 0.66 * k])
    for z in (1.5, 1.95, 2.4):                        # leather grip wrap
        b.torus("Leather", v(0.04, 0.02, z0 + z), 0.66 * k, 0.12 * k, rot=(4, 0, 0), segs=(14, 6))
    # Fork: two curving prongs ending in knobs, each wrapped and capped with a big dino tooth.
    for side, tip in ((-1, "TipL"), (1, "TipR")):
        pts = [v(0, 0, z0 + 3.6), v(side * 0.85, 0, z0 + 4.4), v(side * 1.6, 0, z0 + 5.5), v(side * 1.85, 0, z0 + 6.7)]
        _limb(b, "Wood", pts, [0.58 * k, 0.48 * k, 0.42 * k, 0.4 * k])
        b.ico("Wood", v(side * 1.88, 0, z0 + 6.85), (0.5 * k, 0.5 * k, 0.45 * k), sub=2)
        b.torus("Leather", v(side * 1.8, 0, z0 + 6.25), 0.44 * k, 0.11 * k, rot=(0, side * -12, 0), segs=(12, 6))
        b.cyl("Stone", v(side * 1.98, 0, z0 + 7.45), 0.26 * k, 0.8 * k, rot=(0, side * 14, 0), verts=8, r2=0.02 * k)
        # Band anchor marker (just inside the knob, on the pouch side).
        b.box(tip, v(side * 1.75, 0.25, z0 + 6.55), (0.04 * k,) * 3, bevel=0)
        # Rubber band from the prong back to the pouch.
        _limb(b, "Band", [v(side * 1.75, 0.25, z0 + 6.55), v(side * 0.95, 0.85, z0 + 6.2), v(side * 0.45, 1.05, z0 + 6.05)], [0.17 * k, 0.16 * k, 0.15 * k], verts=8)
    # Pouch: a soft leather cup with a stitched seam, holding the bait.
    b.ico("Pouch", v(0, 1.1, z0 + 6.0), (0.62 * k, 0.32 * k, 0.5 * k), sub=2)
    b.torus("Pouch", v(0, 1.1, z0 + 6.0), 0.5 * k, 0.05 * k, rot=(90, 0, 0), segs=(14, 4))
    b.box("PouchMark", v(0, 1.1, z0 + 6.0), (0.04 * k,) * 3, bevel=0)


def launch_slingshot(b):
    # Giant slingshot at each plot's launch stand (its bands stretch back while charging, in game).
    _slingshot(b, 1.0, base=True)


def slingshot_item(b):
    # Hand slingshot for the shop pedestals (Wood recoloured per tier in game).
    _slingshot(b, 0.36, base=False)


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


# ===== New-area props (Desert Badlands, Coral Coast, Redwood Forest, Crystal Caves, Sky Islands, Volcano) =====

def cactus(b):
    b.cyl("Leaves", (0, 0, 2.2), 0.55, 4.4, verts=10, r2=0.45, bevel=0.1)
    b.ico("Leaves", (0, 0, 4.4), (0.45, 0.45, 0.35), sub=2)
    for side, h in ((-1, 2.0), (1, 2.8)):
        b.cyl("Leaves", (side * 0.75, 0, h), 0.32, 0.9, rot=(0, 90, 0), verts=8)
        b.cyl("Leaves", (side * 1.15, 0, h + 0.7), 0.32, 1.4, verts=8, r2=0.26)
        b.ico("Leaves", (side * 1.15, 0, h + 1.4), (0.27, 0.27, 0.22), sub=2)
    b.ico("Band", (0, -0.1, 4.75), (0.18, 0.18, 0.12), sub=1)  # flower


def mesa(b):
    # A craggy butte: a wide talus skirt, alternating sandstone strata with ragged edges, a flat cap,
    # and fallen boulders. Uses the jittered lathe so no two layers line up.
    random.seed(21)
    _lathe(b, "RockDark", [(8.2, -0.5), (7.2, 1.2), (6.0, 2.2), (4.6, 3.0)], 14, 0.12, 31)
    layers = [(6.0, 2.0), (5.7, 4.4), (5.9, 4.8), (5.4, 7.0), (5.6, 7.4), (5.1, 9.4), (5.3, 9.7)]
    for i in range(0, len(layers) - 1):
        (r0, z0), (r1, z1) = layers[i], layers[i + 1]
        # each layer starts tucked inside the one below so the jittered rims never leave see-through gaps
        _lathe(b, "Rock" if i % 2 == 0 else "RockDark", [(r0 * 0.8, z0 - 1.0), (r0, z0), (r1, z1)], 14, 0.12, 40 + i)
    _lathe(b, "Rock", [(4.3, 9.0), (5.3, 9.7), (5.0, 10.2)], 14, 0.1, 50, close_top=True)
    for k in range(6):
        a = random.uniform(0, math.tau)
        rr = random.uniform(7, 9.5)
        b.ico("Rock" if k % 2 else "RockDark", (math.cos(a) * rr, math.sin(a) * rr, 0.5), (random.uniform(0.7, 1.4),) * 3, sub=1, jitter=0.25)


def palm_tree(b):
    random.seed(22)
    pts = [(0, 0, 0), (0.3, 0, 2), (0.9, 0, 4), (1.7, 0, 5.8), (2.4, 0, 7.2)]
    for i in range(len(pts) - 1):
        a, c = Vector(pts[i]), Vector(pts[i + 1])
        mid = (a + c) / 2
        d = c - a
        tilt = math.degrees(math.atan2(d.x, d.z))
        b.cyl("Trunk", tuple(mid), 0.42 - i * 0.06, d.length + 0.25, rot=(0, tilt, 0), verts=8)
    top = Vector(pts[-1])
    for k in range(7):
        ang = k * (360 / 7)
        dirv = Vector((math.cos(math.radians(ang)), math.sin(math.radians(ang)), 0))
        b.ico("Leaves", tuple(top + dirv * 1.6 + Vector((0, 0, -0.4))), (1.9, 0.45, 0.12), sub=2, rot=(0, 18, ang))
    for k in range(3):
        b.ico("Trunk", tuple(top + Vector((0.35 * math.cos(k * 2.1), 0.35 * math.sin(k * 2.1), -0.4))), (0.28, 0.28, 0.32), sub=1)


def coral(b):
    random.seed(23)
    b.ico("Rock", (0, 0, 0.5), (1.6, 1.4, 0.7), sub=2, jitter=0.15)
    for i in range(7):
        a = random.uniform(0, math.tau)
        h = random.uniform(1.4, 3.2)
        role = ("Band", "Gold", "Glow")[i % 3]
        x, y = math.cos(a) * random.uniform(0.2, 1.1), math.sin(a) * random.uniform(0.2, 1.1)
        b.cyl(role, (x, y, h / 2 + 0.6), 0.22, h, rot=(random.uniform(-25, 25), random.uniform(-25, 25), 0), verts=8, r2=0.12)
        b.ico(role, (x, y, h + 0.7), (0.3, 0.3, 0.3), sub=2)


def redwood(b):
    b.cyl("Trunk", (0, 0, 9), 1.5, 18, verts=10, r2=1.0, bevel=0.1)
    for i, (r, z) in enumerate(((4.2, 12), (3.6, 15), (3.0, 18), (2.2, 20.6), (1.3, 22.6))):
        b.cyl("Leaves" if i % 2 == 0 else "Leaves2", (0, 0, z), r, 3.2, verts=10, r2=r * 0.35)
    for a in range(4):  # root flares
        ang = math.radians(a * 90 + 20)
        b.cyl("Trunk", (math.cos(ang) * 1.3, math.sin(ang) * 1.3, 0.8), 0.55, 2.2, rot=(math.cos(ang) * 30, -math.sin(ang) * 30, 0), verts=6, r2=0.2)


def crystal_cluster(b):
    random.seed(24)
    b.ico("RockDark", (0, 0, 0.6), (2.2, 1.9, 0.9), sub=1, jitter=0.2)
    for i in range(9):
        a = random.uniform(0, math.tau)
        h = random.uniform(3, 8)
        r = random.uniform(0.35, 0.8)
        d = random.uniform(0, 1.4)
        b.cyl("Glow", (math.cos(a) * d, math.sin(a) * d, h / 2 + 0.6), r, h, rot=(random.uniform(-25, 25), random.uniform(-25, 25), 0), verts=6, r2=0.05)


def sky_island(b):
    # A floating chunk of land: lumpy grass cap with an overhanging lip, a soil band, a craggy rock
    # underside tapering to a point with hanging spikes, little trees, a pond and a waterfall off the edge.
    random.seed(25)
    _lathe(b, "Leaves", [(9.9, 0.0), (10.1, 0.9), (9.4, 1.7), (6, 2.1)], 22, 0.08, 11, close_top=True)
    _lathe(b, "Trunk", [(9.6, 0.3), (9.3, -1.3)], 22, 0.08, 11)
    _lathe(b, "Rock", [(9.3, -1.3), (8.6, -3.0), (7.0, -5.4), (4.8, -7.8), (2.6, -10.2), (1.0, -12.4), (0.05, -13.6)], 22, 0.2, 12)
    for k in range(5):                                                   # hanging spikes
        a = random.uniform(0, math.tau)
        rr = random.uniform(3, 6.5)
        h = random.uniform(2.5, 4.5)
        b.cyl("RockDark", (math.cos(a) * rr, math.sin(a) * rr, -4.5 - rr * -0.0 - h / 2 - (6.5 - rr)), random.uniform(1, 1.6), h, verts=6, r2=0.1, rot=(180, 0, 0))
    for (x, y, s) in ((-4, 2.5, 1.0), (3.5, 4, 0.8)):                   # little trees
        b.cyl("Trunk", (x, y, 3.2), 0.35 * s, 3.2 * s, verts=7)
        b.ico("Leaves2", (x, y, 4.6 * s + 0.6), (1.7 * s, 1.7 * s, 1.5 * s), sub=2, jitter=0.15)
        b.ico("Leaves2", (x + 0.7 * s, y, 5.6 * s + 0.6), (1.1 * s, 1.1 * s, 1.0 * s), sub=2, jitter=0.1)
    for k in range(3):                                                   # bushes and rocks
        a = random.uniform(0, math.tau)
        b.ico("Leaves2", (math.cos(a) * 6.5, math.sin(a) * 6.5, 2.2), (1.2, 1.2, 0.9), sub=2)
        b.ico("Rock", (math.cos(a + 1) * 5, math.sin(a + 1) * 5, 2.1), (0.8, 0.7, 0.6), sub=1, jitter=0.15)
    b.cyl("Water", (4.5, -3.5, 2.0), 2.4, 0.4, verts=16)                # pond
    b.box("Water", (7.4, -5.9, -3.5), (1.1, 0.25, 5.6), rot=(0, 0, 38), bevel=0.05)   # waterfall off the edge


def cloud(b):
    random.seed(26)
    for i in range(7):
        b.ico("Snow", (random.uniform(-4, 4), random.uniform(-1.5, 1.5), random.uniform(0, 1.6)), (random.uniform(1.6, 2.8),) * 3, sub=2)


def _mesh(b, role, verts, faces):
    me = bpy.data.meshes.new(f"{b.name}_{role}_tmp")
    me.from_pydata(verts, [], faces)
    me.update()
    o = bpy.data.objects.new(f"{role}_tmp", me)
    bpy.context.scene.collection.objects.link(o)
    return b._add(o, role)


def _lathe(b, role, profile, segs, jitter, seed, close_top=False):
    """Revolve a (radius, z) profile; each vertex jittered radially for a hand-made, low-poly look."""
    rnd = random.Random(seed)
    offs = [rnd.uniform(-1, 1) for _ in range(segs)]
    verts, faces = [], []
    for i, (r, z) in enumerate(profile):
        for s in range(segs):
            a = s / segs * math.tau
            k = 1 + jitter * (offs[s] * 0.6 + rnd.uniform(-0.4, 0.4))
            verts.append((math.cos(a) * r * k, math.sin(a) * r * k, z + rnd.uniform(-0.6, 0.6) * (i > 0)))
    for i in range(len(profile) - 1):
        for s in range(segs):
            a0, a1 = i * segs + s, i * segs + (s + 1) % segs
            faces.append((a0, a1, a1 + segs, a0 + segs))
    if close_top:
        c = len(verts)
        verts.append((0, 0, profile[-1][1]))
        base = (len(profile) - 1) * segs
        for s in range(segs):
            faces.append((base + s, base + (s + 1) % segs, c))
    return _mesh(b, role, verts, faces)


def volcano_big(b):
    # A towering stratovolcano: concave slopes (lathe), lighter ash cap, a jagged rim around a sunken
    # crater lake of lava, and continuous lava rivers meandering down the slope.
    random.seed(27)
    # concave profile: wide skirt, steepening towards the rim
    lower = [(74, -2), (66, 6), (55, 16), (44, 28), (35, 40)]
    upper = [(35, 40), (27, 52), (21, 62), (18, 69), (17, 72)]
    crater = [(17, 72), (14, 70), (11.5, 66.5)]
    _lathe(b, "RockDark", lower, 32, 0.07, 1)
    _lathe(b, "Rock", upper, 32, 0.06, 2)
    _lathe(b, "RockDark", crater, 32, 0.05, 3, close_top=True)
    b.cyl("Lava", (0, 0, 67.2), 12.5, 1.2, verts=24)                     # crater lava lake
    for k in range(9):                                                   # jagged rim teeth
        a = math.radians(k * 40 + random.uniform(-10, 10))
        b.cyl("RockDark", (math.cos(a) * 16.5, math.sin(a) * 16.5, 73), random.uniform(2.5, 4), random.uniform(4, 8), verts=5, r2=0.6,
              rot=(random.uniform(-12, 12), random.uniform(-12, 12), 0))
    # lava rivers: ribbons hugging the slope from the rim notch to the skirt, meandering and widening
    prof = lower + upper[1:]
    def slope_r(z):
        for (r0, z0), (r1, z1) in zip(prof, prof[1:]):
            if z0 <= z <= z1:
                return r0 + (r1 - r0) * (z - z0) / (z1 - z0)
        return prof[-1][0]
    for k, a0 in enumerate((20, 140, 250)):
        verts, faces = [], []
        steps = 18
        for j in range(steps + 1):
            t = j / steps
            z = 71 - t * 70
            r = slope_r(z) + 0.7
            a = math.radians(a0 + math.sin(t * 7 + k) * 9)
            w = 1.6 + t * 3.4
            d = Vector((math.cos(a), math.sin(a), 0))
            side = Vector((-d.y, d.x, 0))
            c = d * r + Vector((0, 0, z))
            verts += [tuple(c - side * w), tuple(c + side * w)]
            if j:
                i0 = (j - 1) * 2
                faces.append((i0, i0 + 2, i0 + 3, i0 + 1))
        _mesh(b, "Lava", verts, faces)
        # a pool of lava where the river meets the ground
        b.ico("Lava", (math.cos(math.radians(a0)) * 78, math.sin(math.radians(a0)) * 78, 0.2), (7, 7, 0.8), sub=2)
    for k in range(10):                                                  # boulders on the skirt
        a = random.uniform(0, math.tau)
        rr = random.uniform(58, 78)
        b.ico("RockDark", (math.cos(a) * rr, math.sin(a) * rr, 1.5), (random.uniform(3, 6),) * 3, sub=1, jitter=0.6)


PROPS = {
    "Cactus": cactus,
    "Mesa": mesa,
    "PalmTree": palm_tree,
    "Coral": coral,
    "Redwood": redwood,
    "CrystalCluster": crystal_cluster,
    "SkyIsland": sky_island,
    "Cloud": cloud,
    "VolcanoBig": volcano_big,
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
