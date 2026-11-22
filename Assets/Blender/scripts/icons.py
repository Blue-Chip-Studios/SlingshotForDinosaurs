"""
SlingshotForDinosaurs: 3D icon set (Blender 5.x).

Chunky, toy-like icon objects rendered to transparent 512px PNGs for the
HUD buttons, passes and developer products. Same visual language as the
dinos and props. Uses PropBuilder from world_props.py.
"""

import math
import os

import bpy
from mathutils import Vector

exec(open(r"C:\Users\santa\SlingshotForDinosaurs\Assets\Blender\scripts\world_props.py").read())

# Toon look: colours come mostly from self-emission under dim ambient light, so icons
# render flat and saturated (the first set rendered pastel under a bright blue sky).
ICON_EMISSION = 0.75
ICON_WORLD_STRENGTH = 0.08
ICON_SUN_ENERGY = 1.1

ICON_COLOURS = {
    "Gold": (1.0, 0.77, 0.19), "GoldDark": (0.85, 0.55, 0.08), "Green": (0.24, 0.86, 0.31), "Red": (0.95, 0.25, 0.25),
    "Blue": (0.25, 0.72, 1.0), "Purple": (0.7, 0.4, 1.0), "White": (0.97, 0.97, 0.97), "Brown": (0.62, 0.4, 0.2),
    "Orange": (1.0, 0.55, 0.12), "Dark": (0.15, 0.13, 0.2), "Cyan": (0.3, 0.9, 0.95), "Pink": (1.0, 0.4, 0.75),
}


class IconBuilder(PropBuilder):
    def finish(self):
        out = super().finish(smooth_roles=tuple(ICON_COLOURS.keys()))
        # Ink outline material (inverted hull): back faces only, flat dark colour.
        ink = bpy.data.materials.get("SFDIcon_Ink") or bpy.data.materials.new("SFDIcon_Ink")
        ink.use_nodes = True
        ink.use_backface_culling = True
        ib = ink.node_tree.nodes["Principled BSDF"]
        ib.inputs["Base Color"].default_value = (0.03, 0.025, 0.05, 1)
        ib.inputs["Roughness"].default_value = 1.0
        for role, o in out.items():
            # Palette values are sRGB; Blender materials want linear (else everything renders pastel).
            rgb = tuple(c ** 2.2 for c in ICON_COLOURS.get(role, (1, 1, 1)))
            mat = bpy.data.materials.get(f"SFDIcon_{role}") or bpy.data.materials.new(f"SFDIcon_{role}")
            mat.use_nodes = True
            bsdf = mat.node_tree.nodes["Principled BSDF"]
            bsdf.inputs["Base Color"].default_value = (*rgb, 1)
            bsdf.inputs["Roughness"].default_value = 0.6
            # A little self-emission keeps colours punchy and UI-like regardless of lighting.
            if "Emission Color" in bsdf.inputs:
                bsdf.inputs["Emission Color"].default_value = (*rgb, 1)
                bsdf.inputs["Emission Strength"].default_value = ICON_EMISSION
            o.data.materials.clear()
            o.data.materials.append(mat)
            o.data.materials.append(ink)
            sol = o.modifiers.new("Outline", "SOLIDIFY")
            sol.thickness = 0.07
            sol.offset = 1.0
            sol.use_flip_normals = True
            sol.use_rim = False
            sol.material_offset = 1
        return out


def coin(b, x, y, z, s=1.0):
    b.cyl("Gold", (x, y, z), 1.0 * s, 0.32 * s, verts=24, bevel=0.06 * s)
    b.cyl("GoldDark", (x, y, z + 0.17 * s), 0.7 * s, 0.04 * s, verts=24)


ICONS = {}


def icon(fn):
    ICONS[fn.__name__] = fn
    return fn


@icon
def Cash(b):
    for i in range(4):
        coin(b, 0, 0, i * 0.34)
    for i in range(3):
        coin(b, 1.6, 0.4, i * 0.34)
    b.box("Green", (-0.4, -1.4, 0.35), (1.6, 0.9, 0.25), rot=(0, 0, 15), bevel=0.2)


@icon
def DoubleCash(b):
    Cash(b)
    b.box("Orange", (0.9, -0.6, 2.6), (1.1, 0.25, 0.6), bevel=0.3)  # "x2" tag block


@icon
def Power(b):
    pts = [(0.2, 2.4), (-0.9, 0.3), (0.0, 0.3), (-0.4, -2.0), (1.0, 0.6), (0.1, 0.6)]
    for (x1, z1), (x2, z2) in zip(pts, pts[1:]):
        mid = ((x1 + x2) / 2, 0, (z1 + z2) / 2)
        L = math.hypot(x2 - x1, z2 - z1)
        ang = math.degrees(math.atan2(x2 - x1, z2 - z1))
        b.box("Gold", mid, (0.45, 0.35, L / 2 + 0.2), rot=(0, ang, 0), bevel=0.35)


@icon
def DoublePower(b):
    Power(b)
    b.ico("Orange", (1.3, 0, 2.2), (0.6, 0.6, 0.6), sub=2)


@icon
def Meteor(b):
    b.ico("Dark", (0, 0, 0), (1.3, 1.3, 1.3), sub=1, jitter=0.12)
    b.ico("Orange", (0.6, -0.9, 0.5), (0.5, 0.3, 0.3), sub=1)
    b.cyl("Orange", (-1.6, 0.4, 1.6), 1.0, 3.0, rot=(0, -45, 0), verts=12, r2=0.05)
    b.cyl("Gold", (-1.3, 0.2, 1.3), 0.6, 2.0, rot=(0, -45, 0), verts=12, r2=0.05)


@icon
def Potion(b):
    b.ico("Purple", (0, 0, 0.9), (1.2, 1.2, 1.2), sub=3)
    b.cyl("White", (0, 0, 2.3), 0.4, 0.9, verts=16)
    b.cyl("Brown", (0, 0, 2.85), 0.48, 0.35, verts=16, bevel=0.05)
    b.ico("White", (-0.45, -0.85, 1.3), (0.25, 0.15, 0.35), sub=2)


@icon
def Crown(b):
    b.cyl("Gold", (0, 0, 0.5), 1.4, 1.0, verts=24, bevel=0.06)
    for i in range(5):
        a = i / 5 * math.tau
        b.cyl("Gold", (math.cos(a) * 1.2, math.sin(a) * 1.2, 1.5), 0.35, 1.2, verts=8, r2=0.02)
        b.ico("Red" if i % 2 else "Blue", (math.cos(a) * 1.42, math.sin(a) * 1.42, 0.55), (0.22, 0.22, 0.22), sub=2)


@icon
def Gear(b):
    b.cyl("Blue", (0, 0, 0), 1.3, 0.6, rot=(90, 0, 0), verts=24, bevel=0.06)
    for i in range(8):
        a = i / 8 * math.tau
        b.box("Blue", (math.cos(a) * 1.45, 0, math.sin(a) * 1.45), (0.3, 0.3, 0.3), rot=(0, -math.degrees(a), 0), bevel=0.3)
    b.cyl("White", (0, -0.31, 0), 0.5, 0.1, rot=(90, 0, 0), verts=16)


@icon
def Book(b):
    b.box("Blue", (0, 0, 0), (1.3, 0.4, 1.7), rot=(0, 0, 18), bevel=0.15)
    b.box("White", (0.08, -0.05, 0), (1.15, 0.33, 1.6), rot=(0, 0, 18), bevel=0.1)
    b.box("Gold", (-0.2, -0.43, 0.6), (0.6, 0.05, 0.25), rot=(0, 0, 18), bevel=0.3)


@icon
def Bag(b):
    b.box("Green", (0, 0, 0), (1.3, 0.9, 1.2), bevel=0.25)
    b.torus("Brown", (0, 0, 1.25), 0.7, 0.13, rot=(90, 0, 0))
    b.box("Gold", (0, -0.92, 0.1), (0.4, 0.05, 0.4), bevel=0.3)


@icon
def Star(b):
    for i in range(5):
        a = i / 5 * math.tau + math.pi / 2
        b.cyl("Gold", (math.cos(a) * 0.75, 0, math.sin(a) * 0.75), 0.55, 1.6, rot=(0, -math.degrees(a) + 90, 0), verts=4, r2=0.02)
    b.cyl("Gold", (0, 0, 0), 0.9, 0.6, rot=(90, 0, 0), verts=10, bevel=0.05)


@icon
def Gift(b):
    b.box("Red", (0, 0, 0), (1.3, 1.3, 1.1), bevel=0.15)
    b.box("Gold", (0, 0, 0), (0.25, 1.35, 1.15), bevel=0.2)
    b.box("Gold", (0, 0, 0), (1.35, 0.25, 1.15), bevel=0.2)
    for s in (-1, 1):
        b.torus("Gold", (s * 0.45, 0, 1.35), 0.4, 0.12, rot=(90, 0, s * 25))


@icon
def Vault(b):
    b.box("Brown", (0, 0, 0), (1.6, 1.0, 1.0), bevel=0.15)
    b.cyl("Brown", (0, 0, 1.0), 1.0, 3.2, rot=(0, 90, 0), verts=16)
    b.box("Gold", (0, -1.02, 0.6), (0.3, 0.08, 0.35), bevel=0.3)
    for i in range(3):
        coin(b, -0.8 + i * 0.8, 0.0, 2.05, 0.5)


@icon
def Wrench(b):
    b.box("White", (0, 0, 0), (0.3, 0.3, 1.8), rot=(0, 35, 0), bevel=0.3)
    b.torus("White", (1.1, 0, 1.55), 0.55, 0.22, rot=(90, 0, 0))


@icon
def Target(b):
    for i, (r, c) in enumerate(((1.6, "Red"), (1.15, "White"), (0.7, "Red"), (0.3, "White"))):
        b.cyl(c, (0, -i * 0.08, 0), r, 0.3, rot=(90, 0, 0), verts=24)


@icon
def Muscle(b):
    b.ico("Orange", (0, 0, 0), (1.0, 0.8, 0.9), sub=3)
    b.ico("Orange", (-1.0, 0, -0.9), (0.55, 0.55, 1.2), sub=3)
    b.ico("Orange", (0.6, 0, 1.0), (0.5, 0.5, 0.7), sub=3)


# ===== Shop: one slingshot per tier (ShopConfig.Slingshots) and the park-slots icon =====
# Each tier reads as a clear step up: twig -> bamboo -> bone -> tar -> tusk -> obsidian -> meteorite.
ICON_COLOURS.update({
    "Wood": (0.55, 0.33, 0.16), "WoodDark": (0.36, 0.2, 0.09), "Leaf": (0.3, 0.8, 0.25),
    "Bamboo": (0.55, 0.85, 0.3), "BambooDark": (0.3, 0.58, 0.15),
    "Bone": (0.96, 0.93, 0.84), "Leather": (0.5, 0.3, 0.15),
    "Tar": (0.1, 0.08, 0.07), "TarShine": (0.28, 0.24, 0.22),
    "Ivory": (0.98, 0.94, 0.8), "Fur": (0.55, 0.36, 0.2), "Ice": (0.6, 0.9, 1.0),
    "Obsidian": (0.12, 0.08, 0.2), "Glow": (0.75, 0.35, 1.0),
    "Meteor": (0.25, 0.2, 0.2), "Lava": (1.0, 0.45, 0.08), "Fire": (1.0, 0.75, 0.1),
    "Band": (0.95, 0.2, 0.25), "Grass": (0.35, 0.8, 0.25), "Egg": (0.97, 0.94, 0.86), "Spot": (0.4, 0.75, 0.35),
})


def slingshot(b, handle, arm, band, tip=None, tip_size=0.22, thick=0.24, curve=0):
    """Chunky Y-fork. handle/arm/band/tip are colour roles; curve bends the arms (tusks)."""
    b.cyl(handle, (0, 0, -1.25), thick * 1.1, 1.9, verts=12, bevel=0.04)
    for side in (-1, 1):
        # Arms splay out from the fork joint at z = -0.25 to the tips at (+-0.95, 1.35).
        b.cyl(arm, (side * 0.47, 0, 0.55), thick, 1.85, rot=(0, side * (31 + curve), 0), verts=12, bevel=0.04)
        if curve:
            b.cyl(arm, (side * 1.02, 0, 1.45), thick * 0.75, 0.6, rot=(0, -side * 15, 0), verts=12, r2=thick * 0.25)
        b.ico(tip or arm, (side * 0.95, 0, 1.35), (tip_size,) * 3, sub=2)
    b.ico(arm, (0, 0, -0.25), (thick * 1.25,) * 3, sub=2)  # fork joint
    # Band sagging to a pouch, slightly in front so it reads against the arms.
    for side in (-1, 1):
        b.box(band, (side * 0.47, -0.12, 1.08), (0.52, 0.07, 0.07), rot=(0, -side * 27, 0), bevel=0.3)
    b.box(band, (0, -0.14, 0.82), (0.26, 0.14, 0.2), bevel=0.35)


@icon
def Sling_Twig(b):
    slingshot(b, "Wood", "Wood", "Band", thick=0.17, tip_size=0.14)
    b.ico("Leaf", (-1.15, -0.05, 1.55), (0.28, 0.08, 0.16), sub=2, rot=(0, 30, 0))
    b.ico("Leaf", (0.35, -0.1, -0.7), (0.25, 0.07, 0.14), sub=2, rot=(0, -40, 0))


@icon
def Sling_Bamboo(b):
    slingshot(b, "Bamboo", "Bamboo", "Leather", tip="BambooDark", thick=0.22)
    for z in (-1.8, -1.2, -0.6):
        b.torus("BambooDark", (0, 0, z), 0.25, 0.06)
    for side in (-1, 1):
        b.torus("BambooDark", (side * 0.6, 0, 0.75), 0.24, 0.05, rot=(0, side * 31, 0))


@icon
def Sling_Bone(b):
    slingshot(b, "Bone", "Bone", "Leather", tip="Bone", tip_size=0.34, thick=0.23)
    b.ico("Bone", (-0.12, 0, -2.2), (0.3,) * 3, sub=2)
    b.ico("Bone", (0.12, 0, -2.2), (0.3,) * 3, sub=2)
    b.cyl("Leather", (0, 0, -1.1), 0.3, 0.7, verts=12)


@icon
def Sling_TarRubber(b):
    slingshot(b, "WoodDark", "WoodDark", "Tar", tip="Tar", tip_size=0.26, thick=0.25)
    for (x, z, s) in ((-0.55, 0.6, 0.16), (0.62, 0.9, 0.13), (0.05, -0.6, 0.18), (-0.02, -1.5, 0.14)):
        b.ico("Tar", (x, -0.18, z), (s, s * 0.8, s * 1.5), sub=2)
    b.ico("TarShine", (-0.5, -0.27, 0.68), (0.05, 0.03, 0.08), sub=1)


@icon
def Sling_MammothTusk(b):
    slingshot(b, "Fur", "Ivory", "Ice", tip="Ivory", tip_size=0.2, thick=0.26, curve=6)
    b.ico("Fur", (0, 0, -0.95), (0.36, 0.36, 0.5), sub=2, jitter=0.03)


@icon
def Sling_Obsidian(b):
    slingshot(b, "Obsidian", "Obsidian", "Glow", tip="Glow", tip_size=0.24, thick=0.26)
    for (x, z) in ((-0.5, 0.55), (0.45, 0.4), (0.0, -1.0)):
        b.box("Glow", (x, -0.24, z), (0.04, 0.03, 0.2), rot=(0, 25, 0), bevel=0.3)


@icon
def Sling_Meteorite(b):
    random.seed(7)
    slingshot(b, "Meteor", "Meteor", "Fire", tip="Lava", tip_size=0.32, thick=0.28)
    for (x, z) in ((-0.55, 0.65), (0.5, 0.5), (0.05, -0.9), (-0.05, -1.6)):
        b.ico("Lava", (x, -0.25, z), (0.11, 0.05, 0.11), sub=1)
    for side in (-1, 1):
        b.cyl("Fire", (side * 0.95, 0, 1.75), 0.22, 0.55, verts=8, r2=0.02)


@icon
def Park(b):
    # Park slots: grassy patch, picket fence and a spotted dino egg.
    b.cyl("Grass", (0, 0, -0.9), 1.5, 0.35, verts=24, bevel=0.08)
    for i in range(-2, 3):
        b.box("Wood", (i * 0.55, 0.55, -0.15), (0.12, 0.08, 0.55), bevel=0.3)
        b.cyl("Wood", (i * 0.55, 0.55, 0.45), 0.12, 0.25, verts=4, r2=0.01)
    b.box("WoodDark", (0, 0.5, 0.05), (1.3, 0.06, 0.07), bevel=0.3)
    b.box("WoodDark", (0, 0.5, -0.4), (1.3, 0.06, 0.07), bevel=0.3)
    b.ico("Egg", (0.15, -0.35, -0.15), (0.55, 0.55, 0.72), sub=3)
    for (x, z) in ((0.0, 0.1), (0.35, -0.15), (0.05, -0.45)):
        b.ico("Spot", (x, -0.85, z), (0.12, 0.05, 0.12), sub=1)


def render_icon(name, out_dir):
    for c in bpy.data.collections:
        c.hide_render = True
    b = IconBuilder("Icon_" + name)
    ICONS[name](b)
    objs = b.finish()
    coll = bpy.data.collections["Icon_" + name]
    coll.hide_render = False
    pts = [o.matrix_world @ Vector(c) for o in objs.values() for c in o.bound_box]
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    centre = (mn + mx) / 2
    size = max((mx - mn).length, 0.5)
    scene = bpy.context.scene
    cam = bpy.data.objects["Camera"]
    # Tall, narrow shop items (slingshots) get framed tighter so they fill the card.
    zoom = 0.82 if name.startswith("Sling_") else (0.7 if name == "Park" else 1.0)
    cam.location = centre + Vector((-0.35, -1.0, 0.45)).normalized() * size * 1.15 * zoom
    cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.film_transparent = True
    scene.render.resolution_x = 512
    scene.render.resolution_y = 512
    scene.render.filepath = os.path.join(out_dir, f"Icon_{name}.png")
    # Toon lighting for the render only; restore the scene afterwards (thumbnails share it).
    bg = next((n for n in scene.world.node_tree.nodes if n.type == "BACKGROUND"), None) if scene.world and scene.world.use_nodes else None
    sun = next((o for o in scene.objects if o.type == "LIGHT" and o.data.type == "SUN"), None)
    saved = (bg.inputs[1].default_value if bg else None, sun.data.energy if sun else None)
    if bg: bg.inputs[1].default_value = ICON_WORLD_STRENGTH
    if sun: sun.data.energy = ICON_SUN_ENERGY
    bpy.ops.render.render(write_still=True)
    if bg: bg.inputs[1].default_value = saved[0]
    if sun: sun.data.energy = saved[1]
    coll.hide_render = True
    return scene.render.filepath
