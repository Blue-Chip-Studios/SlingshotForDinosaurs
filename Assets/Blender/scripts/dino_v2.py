"""
SlingshotForDinosaurs: dinosaur generator v2 (Blender 5.x).

Replaces the v1 lumps (coarse metaballs, brick feet, shared silhouettes) with:
  * smooth fused bodies: fine metaballs, decimated to a per-region triangle budget
  * separate leg meshes (LegL/LegR, or LegFL/LegFR/LegBL/LegBR) so the game can swing them
  * real silhouettes per species: tapered tails, toed feet, toy heads with big eyes
  * species features (teeth, brows, stripes, frill, horns, beak) in Accent / EyeWhite

Regions exported as MeshParts (game colours them from DinoConfig):
    Body, Belly, Accent, EyeWhite (eyes, teeth, horns), Pupil, Leg* (coloured like Body)
Conventions: feet on z = 0, facing -Y, +Z up. The game normalises height per species.

Usage (Blender MCP):
    exec(open(r"<repo>/Assets/Blender/scripts/dino_v2.py").read())
    build("TRex"); render_portrait("TRex", out_dir); export("TRex", out_dir)
"""

import math
import os

import bpy
from mathutils import Euler, Vector

# sRGB colours matching Config/DinoConfig (used for portraits and review renders).
def _hex(s):
    return tuple(int(s[i:i + 2], 16) / 255 for i in (0, 2, 4))


SPECIES = {
    "Compy": dict(plan="theropod", body="7ED957", belly="E8F7C8", accent="3E8E2F",
                  w=0.72, head=0.82, eyes=1.3, neck=1.25, tail=1.35, stripes=4, arms="normal"),
    "TRex": dict(plan="theropod", body="4E6B3A", belly="D8D2A8", accent="A83A1E",
                 w=1.08, head=1.45, eyes=0.9, neck=0.85, tail=1.1, stripes=5, arms="tiny", teeth=True, brow=True),
    "Triceratops": dict(plan="ceratopsian", body="6A8FBF", belly="E0E8F2", accent="F2C14E", spots=True, eyewhite=520),
}

BUDGET = {"Body": 1900, "Belly": 300, "Accent": 320, "EyeWhite": 240, "Pupil": 80, "Leg": 260}


class Builder:
    """Collects shapes per region; big soft regions are metaball families that fuse smoothly."""

    META_RES = 0.1

    def __init__(self, name):
        self.name = name
        self.metas = {}
        self.meshes = {}
        self.eyewhite_budget = BUDGET["EyeWhite"]
        coll = bpy.data.collections.get(name)
        if coll:
            for o in list(coll.objects):
                data = o.data
                bpy.data.objects.remove(o, do_unlink=True)
                if data and data.users == 0:
                    (bpy.data.metaballs if isinstance(data, bpy.types.MetaBall) else bpy.data.meshes).remove(data)
        else:
            coll = bpy.data.collections.new(name)
            bpy.context.scene.collection.children.link(coll)
        coll.hide_render = False
        coll.hide_viewport = False
        self.coll = coll

    def _meta(self, region):
        if region not in self.metas:
            data = bpy.data.metaballs.new(f"{self.name}{region}MB")
            data.resolution = self.META_RES
            data.render_resolution = self.META_RES
            data.threshold = 0.6
            o = bpy.data.objects.new(f"{self.name}{region}MB", data)
            self.coll.objects.link(o)
            self.metas[region] = o
        return self.metas[region]

    def ball(self, region, loc, size, rot=(0, 0, 0), stiff=2.0):
        """Soft ellipsoid (half-extents `size`) fused with everything else in its region."""
        el = self._meta(region).data.elements.new()
        el.type = "ELLIPSOID"
        el.co = Vector(loc)
        el.radius = 1.0
        el.size_x, el.size_y, el.size_z = (size[0] * 1.4, size[1] * 1.4, size[2] * 1.4)
        el.rotation = Euler([math.radians(a) for a in rot]).to_quaternion()
        el.stiffness = stiff
        return el

    def _link(self, o, region):
        for c in o.users_collection:
            c.objects.unlink(o)
        self.coll.objects.link(o)
        self.meshes.setdefault(region, []).append(o)
        return o

    def sphere(self, region, loc, r, scale=(1, 1, 1)):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=10, radius=r, location=loc)
        o = bpy.context.active_object
        o.scale = scale
        return self._link(o, region)

    def cone(self, region, base, direction, r, length, verts=10):
        """Cone from `base` pointing along `direction`."""
        d = Vector(direction).normalized()
        centre = Vector(base) + d * (length / 2)
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=0.0, depth=length, location=centre)
        o = bpy.context.active_object
        o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
        return self._link(o, region)

    def chain(self, region, points, radii, squash=1.0):
        """Smooth tube through points (tails, necks): overlapping balls with tapering radii."""
        out = []
        for i in range(len(points) - 1):
            a, b = Vector(points[i]), Vector(points[i + 1])
            ra, rb = radii[i], radii[i + 1]
            steps = max(2, int((b - a).length / (min(ra, rb) * 0.7 + 1e-3)))
            for s in range(steps):
                t = s / steps
                p = a.lerp(b, t)
                r = ra + (rb - ra) * t
                self.ball(region, tuple(p), (r, r * 1.1, r * squash))
                out.append((p, r))
        last = Vector(points[-1])
        self.ball(region, tuple(last), (radii[-1], radii[-1] * 1.2, radii[-1] * squash))
        out.append((last, radii[-1]))
        return out

    def finish(self):
        regions = set(self.metas) | set(self.meshes)
        out = {}
        for region in regions:
            parts = []
            if region in self.metas:
                bpy.ops.object.select_all(action="DESELECT")
                m = self.metas[region]
                bpy.context.view_layer.objects.active = m
                m.select_set(True)
                bpy.ops.object.convert(target="MESH")
                parts.append(bpy.context.active_object)
            for o in self.meshes.get(region, []):
                bpy.ops.object.select_all(action="DESELECT")
                bpy.context.view_layer.objects.active = o
                o.select_set(True)
                bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
                parts.append(o)
            bpy.ops.object.select_all(action="DESELECT")
            for o in parts:
                o.select_set(True)
            bpy.context.view_layer.objects.active = parts[0]
            if len(parts) > 1:
                bpy.ops.object.join()
            o = bpy.context.active_object
            # Triangle budget per region (legs share one budget each).
            budget = BUDGET["Leg"] if region.startswith("Leg") else BUDGET.get(region, 300)
            if region == "EyeWhite":
                budget = self.eyewhite_budget
            tris = _tris(o)
            if tris > budget:
                dec = o.modifiers.new("Decimate", "DECIMATE")
                dec.ratio = budget / tris
                bpy.ops.object.modifier_apply(modifier=dec.name)
                # Relax decimation facets on the big soft regions only (smoothing would melt horns/teeth/frills).
            if tris > budget and (region in ("Body", "Belly") or region.startswith("Leg")):
                sm = o.modifiers.new("Smooth", "SMOOTH")
                sm.factor = 0.6
                sm.iterations = 3
                bpy.ops.object.modifier_apply(modifier=sm.name)
            bpy.ops.object.shade_smooth()
            clash = bpy.data.objects.get(region)
            if clash and clash != o:
                clash.name = f"{clash.name}_old"
            o.name = region
            o.data.name = f"{self.name}_{region}"
            out[region] = o
        return out


def _tris(o):
    return sum(max(0, len(p.vertices) - 2) for p in o.data.polygons)


def _eye(b, centre, r, outward):
    """Big cartoony eye: white ball with a pupil looking forward and out."""
    c = Vector(centre)
    b.sphere("EyeWhite", tuple(c), r)
    look = (Vector((outward * 0.45, -1.0, 0.1))).normalized()
    b.sphere("Pupil", tuple(c + look * r * 0.72), r * 0.55)


# ---------- Body plans ----------

def theropod(b, s):
    w, hs, tl, nk = s["w"], s["head"], s["tail"], s["neck"]
    # Torso pitched nose-up, hips behind, belly/chest in a lighter region.
    b.ball("Body", (0, 0.1, 2.3), (0.92 * w, 1.3, 0.98 * w), rot=(-18, 0, 0))
    b.ball("Body", (0, 0.8, 2.15), (0.78 * w, 0.75, 0.82 * w))
    b.ball("Belly", (0, -0.4, 1.95), (0.7 * w, 0.95, 0.68 * w), rot=(-18, 0, 0))
    # Neck to head.
    neck_top = Vector((0, -1.0 - 0.25 * (nk - 1), 3.05 + 0.45 * (nk - 1)))
    b.chain("Body", [(0, -0.55, 2.75), tuple(neck_top)], [0.55 * w, 0.45 * w * hs ** 0.3])
    H = neck_top + Vector((0, -0.45 * hs, 0.32 * hs))
    b.ball("Body", tuple(H), (0.6 * hs * w ** 0.5, 0.75 * hs, 0.56 * hs))                    # cranium
    snout = H + Vector((0, -0.78 * hs, -0.08 * hs))
    b.ball("Body", tuple(snout), (0.48 * hs, 0.62 * hs, 0.38 * hs))                          # upper snout
    jaw = H + Vector((0, -0.62 * hs, -0.42 * hs))
    b.ball("Belly", tuple(jaw), (0.44 * hs, 0.66 * hs, 0.17 * hs))                          # lower jaw (smile line)
    er = 0.2 * hs * s.get("eyes", 1.0)
    for side in (-1, 1):
        _eye(b, H + Vector((side * 0.5 * hs, -0.22 * hs, 0.24 * hs)), er, side)
        if s.get("brow"):
            b.ball("Accent", tuple(H + Vector((side * 0.42 * hs, -0.3 * hs, 0.5 * hs))), (0.24 * hs, 0.3 * hs, 0.09 * hs), rot=(0, side * 18, 0))
    if s.get("teeth"):
        for side in (-1, 1):
            for i in range(3):
                base = snout + Vector((side * 0.33 * hs, (0.32 - 0.24 * i) * hs, -0.3 * hs))
                b.cone("EyeWhite", tuple(base), (0, 0, -1), 0.055 * hs, 0.17 * hs, verts=6)
    # Long tapered tail with a slight lift.
    pts = [(0, 1.2, 2.2), (0, 2.1 * tl, 2.35), (0, 3.0 * tl, 2.45), (0, 3.8 * tl, 2.5), (0, 4.4 * tl, 2.52)]
    tail = b.chain("Body", pts, [0.62 * w, 0.42 * w, 0.26 * w, 0.14 * w, 0.06 * w], squash=0.92)
    # Back stripes in Accent, sitting on the torso and tail tops.
    n = s.get("stripes", 0)
    if n:
        spots = [(Vector((0, -0.35, 3.18)), 0.62 * w), (Vector((0, 0.3, 3.08)), 0.66 * w), (Vector((0, 0.95, 2.92)), 0.6 * w)]
        spots += [(p + Vector((0, 0, r * 0.88)), r) for p, r in tail[2:len(tail) - 2:max(1, len(tail) // 6)]]
        for p, r in spots[:n + 2]:
            b.ball("Accent", tuple(p), (r * 0.95, 0.11, 0.12))
    # Arms.
    for side in (-1, 1):
        # Arms grow from the shoulder (inside the body, above the belly) so they fuse instead of floating.
        sc = 0.55 if s.get("arms") == "tiny" else 1.0
        b.chain("Body", [(side * 0.55 * w, -0.7, 2.7), (side * 0.95 * w, -0.95 - 0.25 * sc, 2.45 - 0.35 * sc)], [0.15 * sc ** 0.5, 0.1 * sc ** 0.5])
    # Legs: separate regions so they can swing. Hip pivot ~ top of the thigh.
    for side, name in ((-1, "LegL"), (1, "LegR")):
        x = side * 0.62 * w
        b.ball(name, (x, 0.5, 1.45), (0.48 * w, 0.66, 0.66))
        b.ball(name, (x * 1.04, 0.62, 0.7), (0.3 * w, 0.32, 0.55), rot=(12, 0, 0))
        b.ball(name, (x * 1.04, 0.28, 0.16), (0.36 * w, 0.52, 0.17))
        for dx in (-0.15, 0.0, 0.15):
            b.ball(name, (x * 1.04 + dx * w, -0.2, 0.13), (0.11 * w, 0.18, 0.11))


def ceratopsian(b, s):
    # Barrel body, big head with frill, beak and horns, four column legs.
    b.ball("Body", (0, 0.3, 2.05), (1.25, 1.85, 1.05))
    b.ball("Body", (0, 1.3, 2.0), (1.05, 0.9, 0.95))
    b.ball("Belly", (0, 0.15, 1.5), (1.05, 1.55, 0.6))
    H = Vector((0, -1.95, 1.85))
    b.ball("Body", tuple(H), (0.82, 0.95, 0.74))
    b.ball("Body", tuple(H + Vector((0, -0.75, -0.25))), (0.52, 0.6, 0.46))
    b.ball("Belly", tuple(H + Vector((0, -0.62, -0.58))), (0.46, 0.55, 0.2))
    b.cone("Accent", tuple(H + Vector((0, -1.1, -0.35))), (0, -0.9, -0.42), 0.26, 0.45)       # beak
    # Frill leaning back, with a scalloped rim.
    fc = H + Vector((0, 0.55, 0.75))
    b.ball("Accent", tuple(fc), (1.45, 0.13, 1.08), rot=(-35, 0, 0))
    th = math.radians(-35)
    for i in range(11):
        a = math.radians(-95 + i * 19)
        x, z = 1.42 * math.sin(a), 1.05 * math.cos(a)
        p = fc + Vector((x, -z * math.sin(th), z * math.cos(th)))
        b.sphere("EyeWhite", tuple(p), 0.16)
    # Horns: two long brow horns and a nose horn (ivory).
    for side in (-1, 1):
        b.cone("EyeWhite", tuple(H + Vector((side * 0.36, -0.15, 0.55))), (side * 0.12, -0.87, 0.5), 0.13, 1.05)
    b.cone("EyeWhite", tuple(H + Vector((0, -0.85, 0.15))), (0, -0.5, 0.87), 0.11, 0.5)
    for side in (-1, 1):
        _eye(b, H + Vector((side * 0.66, -0.25, 0.15)), 0.25, side)
    # Tapered tail.
    b.chain("Body", [(0, 2.0, 1.95), (0, 3.0, 1.75), (0, 3.9, 1.5), (0, 4.5, 1.32)], [0.62, 0.38, 0.18, 0.07], squash=0.9)
    # Back spots.
    if s.get("spots"):
        for (x, y) in ((-0.45, -0.6), (0.4, -0.2), (-0.3, 0.45), (0.5, 0.85), (-0.1, 1.35), (0.15, -1.0)):
            z = 2.05 + 1.05 * math.sqrt(max(0.0, 1 - (x / 1.25) ** 2 - ((y - 0.3) / 1.85) ** 2))
            b.ball("Accent", (x, y, z - 0.04), (0.24, 0.27, 0.08))
    # Legs (front pair under the shoulders, back pair under the hips).
    for name, x, y in (("LegFL", -0.85, -0.85), ("LegFR", 0.85, -0.85), ("LegBL", -0.88, 1.3), ("LegBR", 0.88, 1.3)):
        b.ball(name, (x, y, 1.2), (0.42, 0.46, 0.6))
        b.ball(name, (x, y, 0.55), (0.32, 0.35, 0.5))
        b.ball(name, (x, y - 0.08, 0.13), (0.38, 0.42, 0.14))
        for dx in (-0.16, 0.0, 0.16):
            b.ball(name, (x + dx, y - 0.42, 0.11), (0.1, 0.12, 0.09))


PLANS = {"theropod": theropod, "ceratopsian": ceratopsian}


def build(species):
    s = SPECIES[species]
    b = Builder(species)
    b.eyewhite_budget = s.get("eyewhite", BUDGET["EyeWhite"])
    PLANS[s["plan"]](b, s)
    objs = b.finish()
    cols = {"Body": s["body"], "Belly": s["belly"], "Accent": s["accent"], "EyeWhite": "F7F3E8", "Pupil": "141218"}
    for region, o in objs.items():
        rgb = _hex(cols.get(region, s["body"]))
        mat = bpy.data.materials.get(f"DV2_{species}_{region}") or bpy.data.materials.new(f"DV2_{species}_{region}")
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes["Principled BSDF"]
        lin = tuple(c ** 2.2 for c in rgb)
        bsdf.inputs["Base Color"].default_value = (*lin, 1)
        bsdf.inputs["Roughness"].default_value = 0.55
        if "Emission Color" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = (*lin, 1)
            bsdf.inputs["Emission Strength"].default_value = 0.0
        o.data.materials.clear()
        o.data.materials.append(mat)
    return objs


def triangle_count(species):
    return {o.name: _tris(o) for o in bpy.data.collections[species].objects}


def render_portrait(species, out_dir, size=512):
    """Toon portrait (outline + punchy colours) like the icon set, 3/4 front view."""
    coll = bpy.data.collections[species]
    scene = bpy.context.scene
    hidden = []
    for c in bpy.data.collections:
        if c != coll and not c.hide_render:
            c.hide_render = True
            hidden.append(c)
    ink = bpy.data.materials.get("DV2_Ink") or bpy.data.materials.new("DV2_Ink")
    ink.use_nodes = True
    ink.use_backface_culling = True
    ink.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.008, 0.006, 0.012, 1)
    added = []
    for o in coll.objects:
        if o.type != "MESH":
            continue
        for slot_mat in o.data.materials:
            bsdf = slot_mat.node_tree.nodes["Principled BSDF"]
            if "Emission Strength" in bsdf.inputs:
                bsdf.inputs["Emission Strength"].default_value = 0.75
        o.data.materials.append(ink)
        sol = o.modifiers.new("Outline", "SOLIDIFY")
        sol.thickness = 0.06
        sol.offset = 1.0
        sol.use_flip_normals = True
        sol.use_rim = False
        sol.material_offset = len(o.data.materials) - 1
        added.append(o)
    pts = [o.matrix_world @ Vector(c) for o in coll.objects for c in o.bound_box]
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    centre = (mn + mx) / 2
    span = max((mx - mn).length, 0.5)
    cam = bpy.data.objects["Camera"]
    cam.location = centre + Vector((-0.85, -1.0, 0.32)).normalized() * span * 1.25
    cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
    bg = next((n for n in scene.world.node_tree.nodes if n.type == "BACKGROUND"), None) if scene.world and scene.world.use_nodes else None
    sun = next((o for o in scene.objects if o.type == "LIGHT" and o.data.type == "SUN"), None)
    saved = (bg.inputs[1].default_value if bg else None, sun.data.energy if sun else None)
    if bg: bg.inputs[1].default_value = 0.08
    if sun: sun.data.energy = 1.1
    scene.render.film_transparent = True
    scene.render.resolution_x = size
    scene.render.resolution_y = size
    scene.render.filepath = os.path.join(out_dir, f"{species}.png")
    bpy.ops.render.render(write_still=True)
    if bg: bg.inputs[1].default_value = saved[0]
    if sun: sun.data.energy = saved[1]
    # Undo the portrait-only outline and emission so the export stays clean.
    for o in added:
        o.modifiers.remove(o.modifiers["Outline"])
        o.data.materials.pop(index=len(o.data.materials) - 1)
        for slot_mat in o.data.materials:
            bsdf = slot_mat.node_tree.nodes["Principled BSDF"]
            if "Emission Strength" in bsdf.inputs:
                bsdf.inputs["Emission Strength"].default_value = 0.0
    for c in hidden:
        c.hide_render = False
    return scene.render.filepath


def export(species, out_dir):
    coll = bpy.data.collections[species]
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, f"Dino_{species}.fbx")
    # Object names are global in Blender, so building several species renames the earlier ones
    # ("Body_old"). The game colours parts by exact region name: restore them from the mesh name.
    for o in coll.objects:
        if o.type == "MESH" and o.data.name.startswith(species + "_"):
            want = o.data.name[len(species) + 1:]
            other = bpy.data.objects.get(want)
            if other and other != o:
                other.name = f"{want}_tmp"
            o.name = want
    bpy.ops.object.select_all(action="DESELECT")
    for o in coll.objects:
        if o.type == "MESH":
            o.select_set(True)
    bpy.ops.export_scene.fbx(
        filepath=path, use_selection=True, object_types={"MESH"},
        apply_unit_scale=True, apply_scale_options="FBX_SCALE_ALL",
        axis_forward="-Z", axis_up="Y", mesh_smooth_type="FACE",
        add_leaf_bones=False, bake_anim=False,
    )
    return path
