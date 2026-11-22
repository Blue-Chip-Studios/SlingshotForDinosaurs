"""
SlingshotForDinosaurs: stylised dinosaur generator v1 (Blender 5.x).
SUPERSEDED by dino_v2.py (all 15 species); kept for reference only.

Builds chunky, toy-like stylised dinos from soft primitives on four shared
body plans (Theropod, Quadruped, Sauropod, Ornithopod, plus Small = tiny
theropod), so all 15 species share one visual language.

Each dino is exported as an FBX with separately named colour regions:
    Body, Belly, Accent, EyeWhite, Pupil
The game colours those MeshParts from Config/DinoConfig (and recolours
them for mutations), so the meshes carry no textures.

Conventions: feet on z = 0, facing -Y (forward), +Z up, ~4 units tall
before the game normalises height per species.

Usage inside Blender (Blender MCP):
    exec(open(r"<repo>/Assets/Blender/scripts/dino_generator.py").read())
    build_species("Velociraptor")            # builds into a fresh collection
    export_species("Velociraptor", out_dir)  # FBX + returns path
"""

import math
import os

import bpy
from mathutils import Euler, Vector

# Preview colours (game overrides them; used for renders and style review).
SPECIES = {
    "Compy":              dict(plan="Small",      body=(0.49, 0.85, 0.34), belly=(0.91, 0.97, 0.78), accent=(0.24, 0.56, 0.18), extras=["stripes"]),
    "Velociraptor":       dict(plan="Theropod",   body=(0.85, 0.54, 0.23), belly=(0.97, 0.89, 0.76), accent=(0.48, 0.24, 0.07), extras=["stripes", "sickle"], head=0.95, tail=1.15),
    "Parasaurolophus":    dict(plan="Ornithopod", body=(0.31, 0.70, 0.66), belly=(0.89, 0.96, 0.93), accent=(0.91, 0.33, 0.18), extras=["tube_crest"]),
    "Dilophosaurus":      dict(plan="Theropod",   body=(0.64, 0.76, 0.29), belly=(0.95, 0.94, 0.78), accent=(0.90, 0.29, 0.55), extras=["double_crest", "frill_neck"]),
    "Baryonyx":           dict(plan="Theropod",   body=(0.37, 0.55, 0.42), belly=(0.90, 0.88, 0.77), accent=(0.18, 0.29, 0.23), extras=["long_snout", "thumb_claw"], head=1.0),
    "Spinosaurus":        dict(plan="Theropod",   body=(0.29, 0.49, 0.55), belly=(0.87, 0.91, 0.88), accent=(0.91, 0.64, 0.24), extras=["sail", "long_snout"], head=1.05, tail=1.25),
    "Pachycephalosaurus": dict(plan="Ornithopod", body=(0.69, 0.48, 0.31), belly=(0.94, 0.85, 0.75), accent=(0.36, 0.23, 0.13), extras=["dome"]),
    "Ankylosaurus":       dict(plan="Quadruped",  body=(0.55, 0.48, 0.36), belly=(0.85, 0.80, 0.69), accent=(0.24, 0.20, 0.15), extras=["armor", "club"]),
    "Triceratops":        dict(plan="Quadruped",  body=(0.42, 0.56, 0.75), belly=(0.88, 0.91, 0.95), accent=(0.95, 0.76, 0.31), extras=["frill", "three_horns"]),
    "Cryolophosaurus":    dict(plan="Theropod",   body=(0.91, 0.93, 0.96), belly=(1.00, 1.00, 1.00), accent=(0.25, 0.56, 0.85), extras=["fan_crest", "stripes"]),
    "Therizinosaurus":    dict(plan="Theropod",   body=(0.79, 0.72, 0.61), belly=(0.96, 0.93, 0.89), accent=(0.43, 0.35, 0.27), extras=["scythe_claws", "fluff"], head=0.75, neck=1.5),
    "Brachiosaurus":      dict(plan="Sauropod",   body=(0.56, 0.72, 0.79), belly=(0.90, 0.95, 0.97), accent=(0.29, 0.43, 0.50), extras=["nose_crest"]),
    "Carnotaurus":        dict(plan="Theropod",   body=(0.72, 0.25, 0.18), belly=(0.95, 0.79, 0.66), accent=(0.16, 0.10, 0.09), extras=["bull_horns", "tiny_arms"], head=0.95),
    "Giganotosaurus":     dict(plan="Theropod",   body=(0.42, 0.35, 0.31), belly=(0.88, 0.79, 0.68), accent=(1.00, 0.42, 0.10), extras=["brow_ridges", "stripes"], head=1.2),
    "TRex":               dict(plan="Theropod",   body=(0.31, 0.42, 0.23), belly=(0.85, 0.82, 0.66), accent=(0.66, 0.23, 0.12), extras=["tiny_arms", "brow_ridges"], head=1.3, tail=1.1),
}

REGIONS = ("Body", "Belly", "Accent", "EyeWhite", "Pupil")


class Builder:
    """Collects primitives per colour region, then joins/smooths each region into one mesh."""

    def __init__(self, name):
        self.name = name
        self.parts = {r: [] for r in REGIONS}
        coll = bpy.data.collections.get(name)
        if coll:
            for obj in list(coll.objects):
                bpy.data.objects.remove(obj, do_unlink=True)
        else:
            coll = bpy.data.collections.new(name)
            bpy.context.scene.collection.children.link(coll)
        self.coll = coll

    def _metaball(self, region):
        if not hasattr(self, "metas"):
            self.metas = {}
        if region not in self.metas:
            data = bpy.data.metaballs.new(f"{self.name}_{region}_meta")
            data.resolution = 0.2
            data.render_resolution = 0.2
            data.threshold = 0.6
            obj = bpy.data.objects.new(f"{self.name}_{region}_meta", data)
            self.coll.objects.link(obj)
            self.metas[region] = obj
        return self.metas[region]

    def _link(self, obj, region):
        for c in obj.users_collection:
            c.objects.unlink(obj)
        self.coll.objects.link(obj)
        self.parts[region].append(obj)
        return obj

    def blob(self, region, loc, scale, rot=(0, 0, 0), seg=14, rings=9):
        if region == "Body":
            # Body blobs are metaball ellipsoids so they fuse into one smooth, sculpted surface.
            mb = self._metaball(region)
            el = mb.data.elements.new()
            el.type = "ELLIPSOID"
            el.co = Vector(loc)
            el.radius = 1.0
            el.size_x, el.size_y, el.size_z = (scale[0] * 1.4, scale[1] * 1.4, scale[2] * 1.4)
            el.rotation = Euler([math.radians(a) for a in rot]).to_quaternion()
            el.stiffness = 2.0
            return el
        bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, location=loc, rotation=Euler([math.radians(a) for a in rot]))
        obj = bpy.context.active_object
        obj.scale = scale
        return self._link(obj, region)

    def box(self, region, loc, scale, rot=(0, 0, 0), bevel=0.35):
        bpy.ops.mesh.primitive_cube_add(location=loc, rotation=Euler([math.radians(a) for a in rot]))
        obj = bpy.context.active_object
        obj.scale = scale
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel * min(scale)
        mod.segments = 2
        mod.limit_method = "NONE"
        return self._link(obj, region)

    def cone(self, region, loc, radius, depth, rot=(0, 0, 0), verts=10, radius2=0.0):
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=radius, radius2=radius2, depth=depth, location=loc, rotation=Euler([math.radians(a) for a in rot]))
        return self._link(bpy.context.active_object, region)

    def finish(self, subdiv=1, target_tris=2400):
        """Join each region, smooth it, and keep the whole dino near target_tris."""
        results = {}
        # Convert metaball regions to meshes first, then treat them like any other part.
        for region, mobj in getattr(self, "metas", {}).items():
            bpy.ops.object.select_all(action="DESELECT")
            bpy.context.view_layer.objects.active = mobj
            mobj.select_set(True)
            bpy.ops.object.convert(target="MESH")
            converted = bpy.context.active_object
            self.parts[region].insert(0, converted)
        for region, objs in self.parts.items():
            if not objs:
                continue
            bpy.ops.object.select_all(action="DESELECT")
            for o in objs:
                o.select_set(True)
            bpy.context.view_layer.objects.active = objs[0]
            for o in objs:
                bpy.context.view_layer.objects.active = o
                for m in list(o.modifiers):
                    bpy.ops.object.modifier_apply(modifier=m.name)
            bpy.context.view_layer.objects.active = objs[0]
            bpy.ops.object.join()
            obj = bpy.context.active_object
            obj.name = region
            obj.data.name = f"{self.name}_{region}"
            if region in ("Belly", "Accent") and subdiv > 0:
                sub = obj.modifiers.new("Subsurf", "SUBSURF")
                sub.levels = subdiv
                sub.render_levels = subdiv
                bpy.ops.object.modifier_apply(modifier=sub.name)
            bpy.ops.object.shade_smooth()
            bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
            results[region] = obj
        # Budget: decimate the big regions if the total is over target.
        total = sum(_tris(o) for o in results.values())
        if total > target_tris:
            ratio = target_tris / total
            for region in ("Body", "Belly", "Accent"):
                o = results.get(region)
                if o:
                    bpy.context.view_layer.objects.active = o
                    dec = o.modifiers.new("Decimate", "DECIMATE")
                    dec.ratio = max(0.45, ratio)
                    bpy.ops.object.modifier_apply(modifier=dec.name)
        return results


def _tris(obj):
    return sum(max(0, len(p.vertices) - 2) for p in obj.data.polygons)


def _eyes(b, head_loc, head_r, spread=0.55, up=0.25, fwd=0.55):
    for side in (-1, 1):
        loc = Vector(head_loc) + Vector((side * head_r * spread, -head_r * fwd, head_r * up))
        b.blob("EyeWhite", tuple(loc), (head_r * 0.30,) * 3, seg=10, rings=7)
        b.blob("Pupil", tuple(loc + Vector((side * head_r * 0.06, -head_r * 0.20, head_r * 0.03))), (head_r * 0.15,) * 3, seg=8, rings=6)


def build_theropod(b, s, small=False):
    hs = s.get("head", 1.0)
    tl = s.get("tail", 1.0)
    nk = s.get("neck", 1.0)
    k = 0.75 if small else 1.0
    # Torso: chunky, slightly forward-tilted
    b.blob("Body", (0, 0.1, 2.05 * k), (0.85 * k, 1.25 * k, 0.9 * k), rot=(-12, 0, 0))
    b.blob("Belly", (0, -0.15, 1.75 * k), (0.7 * k, 1.0 * k, 0.62 * k), rot=(-12, 0, 0))
    # Neck + head (big head = toy-like)
    b.blob("Body", (0, -0.85 * k, (2.75 + 0.25 * (nk - 1)) * k), (0.45 * k, 0.55 * k, 0.6 * k * nk), rot=(30, 0, 0))
    head = (0, -1.45 * k * (1 + 0.15 * (nk - 1)), (3.3 + 0.5 * (nk - 1)) * k)
    hr = 0.62 * k * hs
    b.blob("Body", head, (hr * 1.05, hr * 1.35, hr * 0.95))
    snout = 1.6 if "long_snout" in s["extras"] else 1.0
    b.blob("Body", (head[0], head[1] - hr * 1.0 * snout, head[2] - hr * 0.15), (hr * 0.75, hr * 0.95 * snout, hr * 0.6))
    b.blob("Belly", (head[0], head[1] - hr * 0.85 * snout, head[2] - hr * 0.55), (hr * 0.7, hr * 0.95 * snout, hr * 0.32))
    _eyes(b, head, hr, spread=0.62, up=0.35, fwd=0.35)
    # Tail: three tapering segments with a lift
    for i, (y, z, r) in enumerate(((1.25, 2.0, 0.6), (2.15, 2.15, 0.42), (2.95, 2.35, 0.26))):
        b.blob("Body" if i < 2 else "Accent", (0, y * k * tl, z * k), (r * k, 0.7 * k * tl, r * 0.9 * k), rot=(-8 - i * 6, 0, 0))
    # Legs: thick thighs, shins, feet
    for side in (-1, 1):
        b.blob("Body", (side * 0.55 * k, 0.25 * k, 1.35 * k), (0.42 * k, 0.55 * k, 0.6 * k))
        b.blob("Body", (side * 0.58 * k, 0.35 * k, 0.6 * k), (0.25 * k, 0.28 * k, 0.55 * k))
        b.box("Accent", (side * 0.58 * k, 0.05 * k, 0.12 * k), (0.28 * k, 0.45 * k, 0.12 * k))
        if "tiny_arms" in s["extras"]:
            b.blob("Body", (side * 0.55 * k, -0.85 * k, 2.05 * k), (0.11 * k, 0.11 * k, 0.24 * k), rot=(40, 0, 0))
        else:
            b.blob("Body", (side * 0.6 * k, -0.85 * k, 1.95 * k), (0.15 * k, 0.15 * k, 0.4 * k), rot=(35, 0, side * 10))
    ex = s["extras"]
    if "stripes" in ex:
        for i in range(3):
            b.blob("Accent", (0, -0.2 + i * 0.45, 2.85 * k), (0.5 * k, 0.12 * k, 0.14 * k), rot=(-12, 0, 0))
    if "sickle" in ex:
        for side in (-1, 1):
            b.cone("Accent", (side * 0.58 * k, -0.35 * k, 0.3 * k), 0.08 * k, 0.4 * k, rot=(-60, 0, 0))
    if "sail" in ex:
        b.box("Accent", (0, 0.2, 3.35 * k), (0.08 * k, 1.15 * k, 0.75 * k), rot=(-10, 0, 0), bevel=0.8)
    if "double_crest" in ex:
        for side in (-1, 1):
            b.box("Accent", (side * hr * 0.3, head[1] - hr * 0.2, head[2] + hr * 0.85), (0.05, hr * 0.8, hr * 0.38), bevel=0.8)
    if "frill_neck" in ex:
        b.blob("Accent", (0, head[1] + hr * 0.6, head[2] - hr * 0.2), (hr * 1.4, 0.08, hr * 1.1))
    if "fan_crest" in ex:
        b.box("Accent", (0, head[1] - hr * 0.1, head[2] + hr * 0.95), (hr * 0.8, 0.07, hr * 0.38), bevel=0.8)
    if "thumb_claw" in ex or "scythe_claws" in ex:
        n = 3 if "scythe_claws" in ex else 1
        L = 0.9 if "scythe_claws" in ex else 0.35
        for side in (-1, 1):
            for j in range(n):
                b.cone("Accent", (side * (0.62 + j * 0.06) * k, -1.25 * k, 1.55 * k), 0.06 * k, L * k, rot=(115, 0, 0))
    if "fluff" in ex:
        b.blob("Belly", (0, -0.6 * k, 2.55 * k), (0.6 * k, 0.5 * k, 0.5 * k))
    if "bull_horns" in ex:
        for side in (-1, 1):
            b.cone("Accent", (side * hr * 0.55, head[1] + hr * 0.1, head[2] + hr * 0.85), hr * 0.18, hr * 0.7, rot=(0, side * 35, 0))
    if "brow_ridges" in ex:
        for side in (-1, 1):
            b.blob("Accent", (side * hr * 0.5, head[1] - hr * 0.35, head[2] + hr * 0.62), (hr * 0.28, hr * 0.32, hr * 0.15))


def build_quadruped(b, s):
    b.blob("Body", (0, 0.2, 2.0), (1.35, 1.9, 1.05))
    b.blob("Belly", (0, 0.2, 1.45), (1.1, 1.6, 0.55))
    head = (0, -2.0, 1.9)
    hr = 0.8
    b.blob("Body", head, (hr, hr * 1.15, hr * 0.85))
    b.blob("Belly", (0, head[1] - hr * 0.8, head[2] - hr * 0.35), (hr * 0.6, hr * 0.6, hr * 0.4))
    _eyes(b, head, hr, spread=0.6, up=0.3, fwd=0.45)
    for i, (y, z, r) in enumerate(((2.2, 1.9, 0.6), (3.1, 1.75, 0.38))):
        b.blob("Body", (0, y, z), (r, 0.75, r * 0.85))
    for sx in (-1, 1):
        for y in (-1.0, 1.25):
            b.blob("Body", (sx * 0.85, y, 0.75), (0.38, 0.4, 0.75))
            b.box("Accent", (sx * 0.85, y - 0.1, 0.12), (0.4, 0.42, 0.12))
    ex = s["extras"]
    if "armor" in ex:
        for i in range(4):
            for sx in (-1, 0, 1):
                b.cone("Accent", (sx * 0.65, -0.9 + i * 0.75, 2.95 - abs(sx) * 0.3), 0.2, 0.35, rot=(0, sx * 25, 0), verts=6)
    if "club" in ex:
        b.blob("Accent", (0, 3.85, 1.7), (0.55, 0.4, 0.4))
    if "frill" in ex:
        b.blob("Accent", (0, head[1] + 0.55, head[2] + 0.55), (1.35, 0.15, 1.05), rot=(-20, 0, 0))
    if "three_horns" in ex:
        for sx in (-1, 1):
            b.cone("EyeWhite", (sx * 0.38, head[1] - 0.3, head[2] + 0.75), 0.12, 0.9, rot=(-55, 0, 0))
        b.cone("EyeWhite", (0, head[1] - 0.95, head[2] + 0.1), 0.1, 0.45, rot=(-60, 0, 0))


def build_sauropod(b, s):
    b.blob("Body", (0, 0.4, 2.6), (1.45, 2.1, 1.25))
    b.blob("Belly", (0, 0.4, 1.95), (1.2, 1.75, 0.6))
    for i in range(9):  # long curving neck: many overlapping elements fuse into one smooth tube
        t = i / 8
        b.blob("Body", (0, -1.2 - t * 1.9, 3.2 + t * 4.0), (0.5 - t * 0.14, 0.5 - t * 0.12, 0.55))
    head = (0, -3.25, 7.4)
    hr = 0.55
    b.blob("Body", head, (hr, hr * 1.3, hr * 0.8))
    _eyes(b, head, hr, spread=0.6, up=0.25, fwd=0.4)
    if "nose_crest" in s["extras"]:
        b.blob("Accent", (0, head[1] + 0.05, head[2] + hr * 0.75), (hr * 0.45, hr * 0.7, hr * 0.4))
    for i, (y, z, r) in enumerate(((2.6, 2.6, 0.7), (3.7, 2.4, 0.45), (4.6, 2.2, 0.25))):
        b.blob("Body" if i < 2 else "Accent", (0, y, z), (r, 0.8, r * 0.85), rot=(10, 0, 0))
    for sx in (-1, 1):
        for y in (-0.9, 1.6):
            b.blob("Body", (sx * 0.85, y, 1.35), (0.5, 0.52, 1.25))
            b.box("Accent", (sx * 0.85, y - 0.05, 0.12), (0.46, 0.46, 0.12))


def build_ornithopod(b, s):
    b.blob("Body", (0, 0.1, 2.15), (0.95, 1.35, 0.95), rot=(-8, 0, 0))
    b.blob("Belly", (0, -0.15, 1.8), (0.78, 1.05, 0.62), rot=(-8, 0, 0))
    b.blob("Body", (0, -0.95, 2.95), (0.45, 0.5, 0.6), rot=(25, 0, 0))
    head = (0, -1.45, 3.55)
    hr = 0.6
    b.blob("Body", head, (hr, hr * 1.2, hr * 0.9))
    b.blob("Belly", (0, head[1] - hr * 0.95, head[2] - hr * 0.2), (hr * 0.65, hr * 0.7, hr * 0.38))  # duck bill
    _eyes(b, head, hr, spread=0.62, up=0.3, fwd=0.35)
    for i, (y, z, r) in enumerate(((1.35, 2.05, 0.6), (2.3, 2.1, 0.4), (3.05, 2.2, 0.24))):
        b.blob("Body" if i < 2 else "Accent", (0, y, z), (r, 0.7, r * 0.9), rot=(-6, 0, 0))
    for side in (-1, 1):
        b.blob("Body", (side * 0.6, 0.3, 1.35), (0.45, 0.55, 0.65))
        b.blob("Body", (side * 0.62, 0.4, 0.6), (0.27, 0.3, 0.55))
        b.box("Accent", (side * 0.62, 0.1, 0.12), (0.3, 0.45, 0.12))
        b.blob("Body", (side * 0.6, -0.9, 1.9), (0.16, 0.16, 0.45), rot=(30, 0, 0))
    if "tube_crest" in s["extras"]:
        b.blob("Accent", (0, head[1] + 0.6, head[2] + 0.45), (0.22, 0.9, 0.22), rot=(-28, 0, 0))
    if "dome" in s["extras"]:
        b.blob("Accent", (0, head[1] + 0.05, head[2] + hr * 0.6), (hr * 0.85, hr * 0.85, hr * 0.7))


PLANS = {
    "Theropod": build_theropod,
    "Small": lambda b, s: build_theropod(b, s, small=True),
    "Quadruped": build_quadruped,
    "Sauropod": build_sauropod,
    "Ornithopod": build_ornithopod,
}


def _material(name, rgb):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
        bsdf.inputs["Roughness"].default_value = 0.55
    return mat


def build_species(species_id, location=(0, 0, 0)):
    s = SPECIES[species_id]
    b = Builder(species_id)
    PLANS[s["plan"]](b, s)
    objs = b.finish()
    colours = {"Body": s["body"], "Belly": s["belly"], "Accent": s["accent"], "EyeWhite": (1, 1, 1), "Pupil": (0.05, 0.04, 0.08)}
    for region, obj in objs.items():
        obj.data.materials.clear()
        obj.data.materials.append(_material(f"SFD_{species_id}_{region}", colours[region]))
        obj.location = Vector(obj.location) + Vector(location)
    return objs


def export_species(species_id, out_dir):
    coll = bpy.data.collections[species_id]
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, f"Dino_{species_id}.fbx")
    bpy.ops.object.select_all(action="DESELECT")
    for o in coll.objects:
        o.select_set(True)
    bpy.ops.export_scene.fbx(
        filepath=path,
        use_selection=True,
        object_types={"MESH"},
        apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_ALL",
        axis_forward="-Z",
        axis_up="Y",
        mesh_smooth_type="FACE",
        add_leaf_bones=False,
        bake_anim=False,
    )
    return path


def triangle_count(species_id):
    return sum(_tris(o) for o in bpy.data.collections[species_id].objects)
