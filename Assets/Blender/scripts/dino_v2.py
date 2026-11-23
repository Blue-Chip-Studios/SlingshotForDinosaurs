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
                 w=1.12, head=1.45, eyes=0.9, neck=0.85, tail=1.1, stripes=5, arms="tiny", teeth=True, brow=True,
                 head_deep=1.2, jaw_open=True, eye_z=0.12),
    "Triceratops": dict(plan="ceratopsian", body="6A8FBF", belly="E0E8F2", accent="F2C14E", spots=True, eyewhite=520),
    "Velociraptor": dict(plan="theropod", body="D9893B", belly="F7E2C1", accent="7A3E12",
                         w=0.82, head=0.95, eyes=1.1, neck=1.1, tail=1.35, stripes=5, teeth=True, sickle=True, head_tuft=True),
    "Dilophosaurus": dict(plan="theropod", body="A3C14A", belly="F3F0C8", accent="E64A8B",
                          w=0.9, head=1.0, eyes=1.05, neck=1.15, tail=1.2, stripes=3, double_crest=True, neck_frill=True),
    "Baryonyx": dict(plan="theropod", body="5E8C6A", belly="E6E1C5", accent="2F4A3A",
                     w=0.98, head=1.05, eyes=0.95, neck=1.05, tail=1.2, stripes=4, snout=1.6, teeth=True, thumb_claw=True),
    "Spinosaurus": dict(plan="theropod", body="4A7D8C", belly="DDE9E0", accent="E8A33D",
                        w=1.05, head=1.1, eyes=0.9, neck=1.0, tail=1.3, stripes=0, snout=1.7, teeth=True, sail=True),
    "Cryolophosaurus": dict(plan="theropod", body="E8EEF5", belly="FFFFFF", accent="3F8FD9",
                            w=0.92, head=1.05, eyes=1.0, neck=1.1, tail=1.2, stripes=5, fan_crest=1.6, teeth=True, eye_x=0.47, eye_z=0.14),
    "Therizinosaurus": dict(plan="theropod", body="D9A45F", belly="FFF0D9", accent="8C4F2B",
                            w=1.1, head=0.72, eyes=1.2, neck=1.2, neck_up=1.4, tail=1.0, stripes=0, arms="long", scythe_claws=True, fluff=True),
    "Carnotaurus": dict(plan="theropod", body="B8402E", belly="F2C9A8", accent="2A1A16",
                        w=0.94, head=1.1, eyes=0.95, neck=1.05, tail=1.25, stripes=0, arms="stub", bull_horns=True, brow=True, teeth=True,
                        head_len=0.72, head_deep=1.12, osteoderms=True, eye_z=0.12),
    "Giganotosaurus": dict(plan="theropod", body="6B5A4E", belly="E0C9AE", accent="FF6A1A",
                           w=1.12, head=1.3, eyes=0.85, neck=0.95, tail=1.3, stripes=3, arms="normal", brow=True, teeth=True,
                           head_len=1.3, head_deep=0.92, back_spikes=True, eye_z=0.12),
    "Parasaurolophus": dict(plan="theropod", body="4FB3A9", belly="E3F5EC", accent="E8542F",
                            w=1.05, head=0.85, eyes=1.1, neck=1.2, tail=1.1, stripes=4, bill=True, tube_crest=True),
    "Pachycephalosaurus": dict(plan="theropod", body="B07A4F", belly="EFD9BF", accent="5C3A22",
                               w=1.0, head=0.95, eyes=1.1, neck=1.05, tail=1.05, stripes=3, dome=True, eyewhite=360),
    "Ankylosaurus": dict(plan="ankylosaur", body="8C7A5B", belly="D9CDB0", accent="3E3426", eyewhite=420),
    # ---- New areas ----
    "Protoceratops": dict(plan="ceratopsian", body="D9A066", belly="F7E6CC", accent="8C4A2F", horns="none", spots=True, eyewhite=420),
    "Gallimimus": dict(plan="theropod", body="E8C15A", belly="FFF5D6", accent="B5651D",
                       w=0.74, head=0.62, eyes=1.35, neck=1.5, neck_up=1.0, tail=1.3, stripes=4, beak=True),
    "Stegosaurus": dict(plan="stegosaur", body="7FA35A", belly="E9F0D0", accent="E0663A", accent_budget=1100),
    "Iguanodon": dict(plan="theropod", body="5BA3C9", belly="E6F4FA", accent="F2D65E",
                      w=1.05, head=0.9, eyes=1.1, neck=1.15, tail=1.1, stripes=4, bill=True, thumb_spike=True),
    "Corythosaurus": dict(plan="theropod", body="F2856B", belly="FFE9DE", accent="3AC2B5",
                          w=1.02, head=0.88, eyes=1.1, neck=1.2, tail=1.1, stripes=3, bill=True, helmet=True),
    "Ouranosaurus": dict(plan="theropod", body="2EB8A6", belly="E2FAF5", accent="FF7AB8",
                         w=1.0, head=0.88, eyes=1.1, neck=1.15, tail=1.15, stripes=0, bill=True, sail=True),
    "Allosaurus": dict(plan="theropod", body="A0522D", belly="F2D9C4", accent="3B2414",
                       w=1.0, head=1.15, eyes=0.95, neck=1.05, tail=1.2, stripes=5, teeth=True, brow_horns=True,
                       head_len=1.12, snout_ridge=True, eye_z=0.12),
    "Styracosaurus": dict(plan="ceratopsian", body="6B8E3A", belly="E8EFD2", accent="D94A2B", horns="styraco", eyewhite=620),
    "Diplodocus": dict(plan="sauropod", body="E0A15E", belly="FBEBD3", accent="7B4FA8", neck="low", accent_budget=700),
    "Microraptor": dict(plan="theropod", body="3A3F7A", belly="B9C2FF", accent="45E0FF", accent_budget=600,
                        w=0.7, head=0.82, eyes=1.3, neck=1.2, tail=1.4, stripes=0, teeth=True, wings=True),
    "Kentrosaurus": dict(plan="stegosaur", body="7A5CC9", belly="E6DEFF", accent="FF5ED1", kentro=True, accent_budget=900),
    "Amargasaurus": dict(plan="sauropod", body="4BA6A0", belly="DDF5F2", accent="C27BFF", neck="spines"),
    "Pteranodon": dict(plan="flyer", body="F2A65A", belly="FFF1E0", accent="D94F70", crest=1.0, span=1.0, accent_budget=700),
    "Archaeopteryx": dict(plan="flyer", body="3FA0E0", belly="F4FAFF", accent="F5C542", bird=True, span=0.8, accent_budget=800),
    "Quetzalcoatlus": dict(plan="flyer", body="E8E2D0", belly="FFFFFF", accent="E0503A", crest=0.7, span=1.25, neck=2.5, accent_budget=700),
    "Brachiosaurus": dict(plan="sauropod", body="5FB0D6", belly="EAF6FB", accent="2D6A8C"),
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
        self.accent_budget = BUDGET["Accent"]
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

    def sphere(self, region, loc, r, scale=(1, 1, 1), rot=(0, 0, 0)):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=10, radius=r, location=loc, rotation=Euler([math.radians(a) for a in rot]))
        o = bpy.context.active_object
        o.scale = scale
        return self._link(o, region)

    def plate(self, region, loc, size, rot=(0, 0, 0)):
        """Thin mesh ellipsoid (half-extents size): for plates, wing skin and crests, which are too
        thin for the metaball resolution and would otherwise melt into blobs."""
        return self.sphere(region, loc, 1.0, scale=size, rot=rot)

    def membrane(self, region, leading, trailing, thickness=0.07):
        """Skin stretched between two edges (e.g. a wing: arm bones -> body), as a thin solid so it
        reads from both sides. `leading` and `trailing` are resampled to the same point count."""
        def resample(pts, n):
            pts = [Vector(p) for p in pts]
            seg = [(pts[i + 1] - pts[i]).length for i in range(len(pts) - 1)]
            total = sum(seg) or 1.0
            out = []
            for k in range(n):
                d = total * k / (n - 1)
                i = 0
                while i < len(seg) - 1 and d > seg[i]:
                    d -= seg[i]
                    i += 1
                out.append(pts[i].lerp(pts[i + 1], min(1.0, d / (seg[i] or 1.0))))
            return out
        n = 10
        a, c = resample(leading, n), resample(trailing, n)
        verts = [tuple(v) for v in a + c]
        faces = [(i, i + 1, n + i + 1, n + i) for i in range(n - 1)]
        me = bpy.data.meshes.new(f"{self.name}_{region}_skin")
        me.from_pydata(verts, [], faces)
        me.update()
        o = bpy.data.objects.new(f"{self.name}_{region}_skin", me)
        self.coll.objects.link(o)
        sol = o.modifiers.new("Thick", "SOLIDIFY")
        sol.thickness = thickness
        sol.offset = 0.0
        bpy.ops.object.select_all(action="DESELECT")
        bpy.context.view_layer.objects.active = o
        o.select_set(True)
        bpy.ops.object.modifier_apply(modifier=sol.name)
        # Mirrored (right-hand) skins come out inside-out; make every shell face outwards so
        # Roblox's backface culling never hides one wing.
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.normals_make_consistent(inside=False)
        bpy.ops.object.mode_set(mode="OBJECT")
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
            if region == "Accent":
                budget = self.accent_budget
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
    # Belly/chest patch: up and forward so it shows as a light chest, never bulging out between the legs.
    b.ball("Belly", (0, -0.55, 2.2), (0.68 * w, 0.82, 0.6 * w), rot=(-24, 0, 0))
    # Neck to head.
    nu = s.get("neck_up", 0.0)  # extra neck height (Therizinosaurus stands tall)
    neck_top = Vector((0, -1.0 - 0.25 * (nk - 1) - 0.25 * nu, 3.05 + 0.45 * (nk - 1) + nu))
    neck_mid = Vector((0, -0.75 - 0.15 * nu, 2.9 + 0.5 * nu))
    b.chain("Body", [(0, -0.55, 2.75), tuple(neck_mid), tuple(neck_top)], [0.55 * w, 0.5 * w, 0.45 * w * hs ** 0.3])
    H = neck_top + Vector((0, -0.45 * hs, 0.32 * hs))
    hl, hd = s.get("head_len", 1.0), s.get("head_deep", 1.0)   # skull length / depth (predator silhouettes)
    b.ball("Body", tuple(H), (0.6 * hs * w ** 0.5, 0.75 * hs * hl, 0.56 * hs * hd))          # cranium
    snout = H + Vector((0, -0.78 * hs * hl, -0.08 * hs))
    b.ball("Body", tuple(snout), (0.48 * hs, 0.62 * hs * hl, 0.38 * hs * hd))                # upper snout
    jaw = H + Vector((0, -0.62 * hs * hl, -0.42 * hs * hd))
    if s.get("jaw_open"):
        # Roaring: lower jaw dropped and tipped down, dark-red mouth inside, bottom teeth pointing up.
        jaw = jaw + Vector((0, 0.05 * hs, -0.2 * hs))
        b.ball("Belly", tuple(jaw), (0.44 * hs, 0.66 * hs * hl, 0.17 * hs), rot=(16, 0, 0))
        b.ball("Accent", tuple(H + Vector((0, -0.5 * hs * hl, -0.4 * hs * hd))), (0.34 * hs, 0.42 * hs * hl, 0.2 * hs))
        for side in (-1, 1):
            for i in range(3):
                base = jaw + Vector((side * 0.3 * hs, (-0.05 - 0.2 * i) * hs * hl, 0.06 * hs - 0.06 * i * hs))
                b.cone("EyeWhite", tuple(base), (0, 0, 1), 0.05 * hs, 0.15 * hs, verts=6)
    else:
        b.ball("Belly", tuple(jaw), (0.44 * hs, 0.66 * hs * hl, 0.17 * hs))                  # lower jaw (smile line)
    sn = s.get("snout", 1.0)
    if sn != 1.0:
        # Long croc snout (Spinosaurus, Baryonyx): extra narrow snout and jaw reaching forward.
        b.ball("Body", tuple(snout + Vector((0, -0.6 * hs * (sn - 1) - 0.3 * hs, -0.05 * hs))), (0.32 * hs, 0.7 * hs * sn, 0.27 * hs))
        b.ball("Belly", tuple(jaw + Vector((0, -0.6 * hs * (sn - 1) - 0.3 * hs, 0.05 * hs))), (0.3 * hs, 0.72 * hs * sn, 0.13 * hs))
    if s.get("bill"):
        # Duck bill (hadrosaurs): broad flat beak in the belly colour.
        b.ball("Belly", tuple(snout + Vector((0, -0.45 * hs, -0.12 * hs))), (0.5 * hs, 0.55 * hs, 0.2 * hs))
    er = 0.2 * hs * s.get("eyes", 1.0)
    # Eyes sit in the side of the skull: narrow skulls with big eyes pull them inward so they do
    # not stick out like googly eyes from the front.
    ex = s.get("eye_x", min(0.47, 0.6 * w ** 0.5 - 0.7 * 0.2 * s.get("eyes", 1.0)))
    for side in (-1, 1):
        _eye(b, H + Vector((side * ex * hs, -0.22 * hs * hl, s.get("eye_z", 0.14) * hs * hd)), er, side)
        if s.get("brow"):
            b.ball("Accent", tuple(H + Vector((side * 0.42 * hs, -0.3 * hs, (s.get("eye_z", 0.14) + 0.2) * hs * hd))), (0.24 * hs, 0.3 * hs, 0.09 * hs), rot=(0, side * 18, 0))
    if s.get("teeth"):
        n_teeth = 3 if sn == 1.0 else 5
        span = 0.24 if sn == 1.0 else 0.22 * sn
        for side in (-1, 1):
            for i in range(n_teeth):
                base = snout + Vector((side * (0.33 if sn == 1.0 else 0.26) * hs, (0.32 - span * i) * hs * hl, -0.3 * hs * hd))
                b.cone("EyeWhite", tuple(base), (0, 0, -1), 0.055 * hs, 0.17 * hs, verts=6)
    # ---- Head ornaments ----
    top = H + Vector((0, 0, 0.5 * hs))  # just under the skull surface, so ornaments root into it
    if s.get("head_tuft"):          # raptor feather tuft
        for i, a in enumerate((-25, 0, 25)):
            b.cone("Accent", tuple(top + Vector((math.sin(math.radians(a)) * 0.12 * hs, 0.2 * hs + i * 0.06, 0.0))), (math.sin(math.radians(a)) * 0.4, 0.8, 0.7), 0.12 * hs, 0.7 * hs, verts=6)
    if s.get("double_crest"):       # Dilophosaurus: two tall thin crests along the skull
        for side in (-1, 1):
            b.ball("Accent", tuple(top + Vector((side * 0.2 * hs, -0.25 * hs, 0.2 * hs))), (0.05 * hs, 0.6 * hs, 0.32 * hs), rot=(-10, 0, 0))
    if s.get("neck_frill"):         # Dilophosaurus umbrella frill behind the head
        b.ball("Accent", tuple(H + Vector((0, 0.55 * hs, -0.35 * hs))), (1.35 * hs, 0.11, 1.05 * hs), rot=(-15, 0, 0))
    if s.get("fan_crest"):          # Cryolophosaurus: wavy crest running side to side
        fc = s.get("fan_crest") if isinstance(s.get("fan_crest"), float) else 1.0
        for i in range(7):
            x = (i - 3) * 0.13 * hs
            b.ball("Accent", tuple(top + Vector((x, -0.15 * hs, 0.05 * hs + (0.18 - abs(i - 3) * 0.05) * fc * hs))), (0.07 * hs, 0.06, 0.24 * hs * fc))
    if s.get("bull_horns"):         # Carnotaurus
        for side in (-1, 1):
            b.cone("Accent", tuple(H + Vector((side * 0.32 * hs, -0.25 * hs, 0.55 * hs))), (side * 0.8, -0.15, 0.6), 0.13 * hs, 0.55 * hs)
    if s.get("tube_crest"):         # Parasaurolophus: long backswept tube
        b.chain("Accent", [tuple(top + Vector((0, -0.1 * hs, -0.1 * hs))), tuple(top + Vector((0, 0.8 * hs, 0.35 * hs))), tuple(top + Vector((0, 1.55 * hs, 0.5 * hs)))], [0.16 * hs, 0.15 * hs, 0.12 * hs])
    if s.get("dome"):               # Pachycephalosaurus: thick dome ringed with knobs
        b.ball("Accent", tuple(top + Vector((0, 0.05 * hs, -0.12 * hs))), (0.55 * hs, 0.6 * hs, 0.42 * hs))
        for i in range(9):
            a = math.radians(i * 40)
            b.sphere("EyeWhite", tuple(top + Vector((math.cos(a) * 0.56 * hs, 0.05 * hs + math.sin(a) * 0.62 * hs, -0.18 * hs))), 0.07 * hs)
    if s.get("beak"):               # Gallimimus: toothless pointed beak
        b.cone("Accent", tuple(snout + Vector((0, -0.35 * hs, -0.12 * hs))), (0, -1, -0.15), 0.26 * hs, 0.55 * hs, verts=10)
    if s.get("brow_horns"):         # Allosaurus: little horn above each eye
        for side in (-1, 1):
            b.cone("Accent", tuple(H + Vector((side * 0.42 * hs, -0.3 * hs, 0.5 * hs))), (side * 0.2, -0.3, 1), 0.12 * hs, 0.38 * hs, verts=6)
    if s.get("snout_ridge"):        # Allosaurus: pair of low ridges running along the top of the snout
        for side in (-1, 1):
            b.ball("Accent", tuple(snout + Vector((side * 0.16 * hs, 0.1 * hs, 0.32 * hs * hd))), (0.06 * hs, 0.55 * hs * hl, 0.1 * hs))
    if s.get("helmet"):             # Corythosaurus: tall rounded helmet crest
        # half buried in the skull so it reads as a tall fin-shaped helmet, not a ball on top
        b.plate("Accent", tuple(top + Vector((0, 0.0, -0.22 * hs))), (0.1 * hs, 0.62 * hs, 0.72 * hs))
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
    if s.get("back_spikes"):
        # Giganotosaurus: a row of short spikes down the spine, shrinking along the tail.
        spine = [Vector((0, -0.35, 3.12)), Vector((0, 0.3, 3.02)), Vector((0, 0.95, 2.86))]
        spine += [p + Vector((0, 0, r * 0.8)) for p, r in tail[1:-3:max(1, len(tail) // 7)]]
        for i, p in enumerate(spine[:9]):
            k = 1 - i / 10
            b.cone("Accent", tuple(p), (0, 0.35, 1), 0.14 * w * k, 0.42 * w * k, verts=6)
    if s.get("osteoderms"):
        # Carnotaurus: rows of knobbly armour bumps down both flanks.
        for side in (-1, 1):
            for i in range(9):
                row = i % 2   # two staggered rows, the upper one higher on the back
                b.sphere("Accent", (side * (0.62 + 0.14 * row - 0.02 * i) * w, -0.6 + 0.3 * i, 3.0 - 0.22 * row - 0.05 * i), 0.07 + 0.015 * (1 - row))
    if s.get("sail"):
        # Spinosaurus: tall curved sail from the shoulders to the hips, with spine tips along the top.
        for i in range(13):
            t = i / 12
            y = -0.75 + t * 2.2
            hgt = (0.45 + 1.75 * math.sin(math.pi * (0.1 + 0.8 * t))) * w   # big signature sail
            b.ball("Accent", (0, y, 3.0 + hgt * 0.55), (0.08, 0.3, hgt * 0.62))
            if i % 2 == 0:
                b.cone("Accent", (0, y, 3.0 + hgt * 0.98), (0, 0.15, 1), 0.07, 0.3 * w, verts=5)
    if s.get("fluff"):
        # Therizinosaurus: feather fluff on the shoulders and arms.
        # A soft mane down the front of the neck and chest (not lumps on the back).
        for (y, z) in ((-0.95, 2.75), (-1.15, 3.2), (-1.3, 3.6)):
            b.ball("Belly", (0, y, z), (0.42 * w, 0.32, 0.3))
    # Arms.
    arms = s.get("arms", "normal")
    for side in (-1, 1):
        # Arms grow from the shoulder (inside the body, above the belly) so they fuse instead of floating.
        sc = {"stub": 0.35, "tiny": 0.55, "normal": 1.0, "long": 1.9}[arms]
        if s.get("wings"):
            # Microraptor: arms spread like a glider, feathered skin back to the hips and a fringe of
            # long flight feathers along the trailing edge.
            sh = Vector((side * 0.5 * w, -0.65, 2.75))
            el = sh + Vector((side * 0.75, 0.1, 0.12))
            tip = sh + Vector((side * 1.8, 0.45, 0.3))
            b.chain("Body", [tuple(sh), tuple(el), tuple(tip)], [0.13, 0.1, 0.07])
            hip = Vector((side * 0.5 * w, 0.75, 2.25))
            sag = Vector((0, 0.3, -0.35))
            b.membrane("Accent", [sh, el, tip], [hip, hip.lerp(tip, 0.45) + sag, hip.lerp(tip, 0.8) + sag * 0.5, tip])
            for k in range(5):
                t = 0.3 + 0.15 * k
                p = hip.lerp(tip, t) + sag * (1 - abs(t - 0.55) * 1.5) + Vector((0, 0.2, -0.2))
                b.plate("Accent", tuple(p), (0.12, 0.05, 0.36), rot=(0, side * (20 + 10 * k), 0))
            continue
        hand = Vector((side * (0.95 + 0.15 * (sc - 1)) * w, -0.95 - 0.35 * sc, 2.45 - 0.45 * sc))
        b.chain("Body", [(side * 0.55 * w, -0.7, 2.7), tuple(hand)], [0.15 * sc ** 0.5, 0.1 * sc ** 0.5])
        if s.get("thumb_claw"):     # Baryonyx: one big hooked claw
            b.cone("EyeWhite", tuple(hand), (side * 0.1, -0.7, -0.7), 0.07, 0.5)
        if s.get("scythe_claws"):   # Therizinosaurus: three very long claws
            for j in (-1, 0, 1):
                b.cone("EyeWhite", tuple(hand + Vector((j * 0.07, 0, 0))), (side * 0.15 + j * 0.12, -0.8, -0.55), 0.05, 1.0)
        if s.get("thumb_spike"):    # Iguanodon: conical thumb spike pointing up
            b.cone("EyeWhite", tuple(hand), (side * 0.2, -0.3, 1), 0.08, 0.42)
    # Legs: separate regions so they can swing. Hip pivot ~ top of the thigh.
    for side, name in ((-1, "LegL"), (1, "LegR")):
        x = side * 0.62 * w
        b.ball(name, (x, 0.5, 1.45), (0.48 * w, 0.66, 0.66))
        b.ball(name, (x * 1.04, 0.62, 0.7), (0.3 * w, 0.32, 0.55), rot=(12, 0, 0))
        b.ball(name, (x * 1.04, 0.28, 0.16), (0.36 * w, 0.52, 0.17))
        for dx in (-0.15, 0.0, 0.15):
            b.ball(name, (x * 1.04 + dx * w, -0.2, 0.13), (0.11 * w, 0.18, 0.11))
        if s.get("sickle"):         # Velociraptor: raised sickle claw on the inner toe (moves with the leg)
            b.cone(name, (x * 1.04 - side * 0.17 * w, 0.0, 0.22), (0, -0.6, 0.8), 0.11, 0.62)
        if s.get("wings"):          # Microraptor: leg feathers too (it had four wings)
            b.plate(name, (x * 1.45, 0.85, 1.05), (0.05, 0.55, 0.28), rot=(-30, 0, 0))


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
    # Frill leaning back. horns: "tri" (Triceratops), "none" (Protoceratops: small frill, no horns),
    # "styraco" (Styracosaurus: long spikes round the frill and one big nose horn).
    horns = s.get("horns", "tri")
    fs = 0.75 if horns == "none" else 1.0
    fc = H + Vector((0, 0.55, 0.75 * fs))
    b.ball("Accent", tuple(fc), (1.45 * fs, 0.13, 1.08 * fs), rot=(-35, 0, 0))
    th = math.radians(-35)
    for i in range(11):
        a = math.radians(-95 + i * 19)
        x, z = 1.42 * fs * math.sin(a), 1.05 * fs * math.cos(a)
        p = fc + Vector((x, -z * math.sin(th), z * math.cos(th)))
        if horns == "styraco" and 2 <= i <= 8:
            out = Vector((math.sin(a), -math.cos(a) * math.sin(th) * 0.4, math.cos(a))).normalized()
            b.cone("EyeWhite", tuple(p), tuple(out), 0.13, 0.95)
        else:
            b.sphere("EyeWhite", tuple(p), 0.16)
    if horns == "tri":
        for side in (-1, 1):
            b.cone("EyeWhite", tuple(H + Vector((side * 0.36, -0.15, 0.55))), (side * 0.12, -0.87, 0.5), 0.13, 1.05)
        b.cone("EyeWhite", tuple(H + Vector((0, -0.85, 0.15))), (0, -0.5, 0.87), 0.11, 0.5)
    elif horns == "styraco":
        b.cone("EyeWhite", tuple(H + Vector((0, -0.85, 0.15))), (0, -0.35, 0.94), 0.17, 1.05)
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


def ankylosaur(b, s):
    # Low, wide armoured tank: spiked back, side spikes, small head, club tail, short legs.
    b.ball("Body", (0, 0.3, 1.55), (1.45, 1.95, 0.82))
    b.ball("Belly", (0, 0.25, 1.05), (1.2, 1.65, 0.45))
    H = Vector((0, -2.05, 1.35))
    b.ball("Body", tuple(H), (0.7, 0.72, 0.52))
    b.ball("Belly", tuple(H + Vector((0, -0.55, -0.25))), (0.45, 0.35, 0.18))
    for side in (-1, 1):
        _eye(b, H + Vector((side * 0.52, -0.25, 0.2)), 0.17, side)
        b.cone("Accent", tuple(H + Vector((side * 0.55, 0.25, 0.25))), (side * 0.8, 0.4, 0.3), 0.12, 0.35, verts=6)   # head horns
    # Rows of armour spikes over the back (top of the body ellipsoid) and spikes along the sides.
    for row in range(5):
        y = -1.15 + row * 0.6
        for x in (-0.75, 0.0, 0.75):
            z = 1.55 + 0.82 * 1.4 * math.sqrt(max(0.0, 1 - (x / (1.45 * 1.4)) ** 2 - ((y - 0.3) / (1.95 * 1.4)) ** 2))
            b.cone("Accent", (x, y, z - 0.5), (x * 0.25, 0, 1), 0.2, 0.34, verts=6)  # metaball surface sits ~0.4 under the nominal ellipsoid
        for side in (-1, 1):
            b.cone("EyeWhite", (side * 1.85, y, 1.45), (side, 0.15, 0.1), 0.14, 0.45, verts=6)
    # Tail and club.
    b.chain("Body", [(0, 2.2, 1.45), (0, 3.1, 1.3), (0, 3.9, 1.2)], [0.55, 0.32, 0.18], squash=0.8)
    b.ball("Accent", (0, 4.25, 1.2), (0.5, 0.42, 0.34))
    for side in (-1, 1):
        b.ball("Accent", (side * 0.38, 4.15, 1.2), (0.28, 0.3, 0.26))
    for name, x, y in (("LegFL", -1.0, -0.95), ("LegFR", 1.0, -0.95), ("LegBL", -1.05, 1.45), ("LegBR", 1.05, 1.45)):
        b.ball(name, (x, y, 0.85), (0.4, 0.42, 0.45))
        b.ball(name, (x, y, 0.38), (0.32, 0.34, 0.36))
        b.ball(name, (x, y - 0.08, 0.12), (0.36, 0.4, 0.13))
        for dx in (-0.15, 0.0, 0.15):
            b.ball(name, (x + dx, y - 0.4, 0.1), (0.09, 0.11, 0.08))


def sauropod(b, s):
    # Brachiosaurus: tall front, long upright neck, small head with nose crest, long tapered tail.
    b.ball("Body", (0, 0.4, 3.3), (1.55, 2.15, 1.4), rot=(-10, 0, 0))   # big barrel torso
    b.ball("Belly", (0, 0.3, 2.65), (1.18, 1.7, 0.62), rot=(-10, 0, 0))
    # neck: "up" (Brachiosaurus), "low" (Diplodocus: long neck held forward, whip tail),
    # "spines" (Amargasaurus: shorter neck with a double row of tall spines).
    style = s.get("neck", "up")
    if style == "low":
        # long neck sweeping forward and gently up (a dead-level neck read as a plank)
        neck = [(0, -1.4, 3.6), (0, -2.7, 4.35), (0, -3.9, 5.05), (0, -4.9, 5.45)]
        H = Vector((0, -5.45, 5.6))
    elif style == "spines":
        neck = [(0, -1.3, 3.8), (0, -2.1, 4.8), (0, -2.8, 5.6), (0, -3.3, 6.1)]
        H = Vector((0, -3.8, 6.35))
    else:
        neck = [(0, -1.3, 3.9), (0, -1.9, 5.4), (0, -2.3, 6.9), (0, -2.45, 8.2)]
        H = Vector((0, -2.85, 8.55))
    neck_pts = b.chain("Body", neck, [0.72, 0.55, 0.45, 0.4])
    if style == "spines":
        for p, r in neck_pts[1::2]:
            for side in (-1, 1):
                b.cone("Accent", tuple(p + Vector((side * 0.18, 0, r * 0.6))), (side * 0.25, 0.2, 1), 0.09, 1.0, verts=6)
    b.ball("Body", tuple(H), (0.48, 0.62, 0.42))
    b.ball("Belly", tuple(H + Vector((0, -0.35, -0.25))), (0.38, 0.42, 0.15))
    if style == "up":
        b.ball("Accent", tuple(H + Vector((0, 0.05, 0.42))), (0.3, 0.42, 0.28))      # nose crest bump
    for side in (-1, 1):
        _eye(b, H + Vector((side * 0.38, -0.1, 0.18)), 0.17, side)
    if style == "low":  # long whip tail
        tail_pts = b.chain("Body", [(0, 2.3, 3.1), (0, 3.8, 3.0), (0, 5.3, 2.7), (0, 6.8, 2.4), (0, 8.0, 2.2)], [0.75, 0.5, 0.3, 0.14, 0.05], squash=0.9)
        # Bold bands over the back and tail, and a row of little dorsal spikes down the neck and tail.
        for y in (-0.85, -0.05, 0.75, 1.55):
            b.ball("Accent", (0, y, 4.3 - 0.12 * abs(y - 0.3)), (1.2, 0.17, 0.42))
        for p, r in tail_pts[2:len(tail_pts) - 3:3]:
            b.ball("Accent", tuple(p + Vector((0, 0, r * 0.25))), (r * 1.05, 0.14, r * 0.9))
        for p, r in (neck_pts[1::2] + tail_pts[1:len(tail_pts) - 2:2]):
            b.cone("Accent", tuple(p + Vector((0, 0, r * 0.75))), (0, 0.25, 1), 0.08, 0.32, verts=5)
    else:
        b.chain("Body", [(0, 2.3, 3.0), (0, 3.6, 2.6), (0, 4.8, 2.2), (0, 5.7, 1.9)], [0.75, 0.45, 0.22, 0.08], squash=0.9)
    # Spots down the back and neck.
    spots = ((-0.6, 4.55), (0.2, 4.5), (1.0, 4.3), (-1.75, 5.0), (-2.1, 6.4)) if style == "up" else (((-0.6, 4.45), (0.2, 4.5), (1.0, 4.35)) if style == "spines" else ())
    for (y, z) in spots:
        b.ball("Accent", (0.0, y, z), (0.32, 0.3, 0.1))
    # Front legs longer than back legs (classic brachiosaur stance).
    back = 2.9 if style == "up" else 2.75  # only brachiosaurs have the tall front
    for name, x, y, top in (("LegFL", -0.95, -1.05, 2.9 if style == "up" else 2.6), ("LegFR", 0.95, -1.05, 2.9 if style == "up" else 2.6), ("LegBL", -0.95, 1.6, 2.5 if style == "up" else back), ("LegBR", 0.95, 1.6, 2.5 if style == "up" else back)):
        # Continuous tube (separate tall balls left gaps at the knees).
        b.chain(name, [(x, y, top + 0.3), (x, y, top * 0.5), (x, y, 0.3)], [0.66, 0.5, 0.44])   # sturdy, rooted in the torso
        b.ball(name, (x, y - 0.06, 0.13), (0.44, 0.46, 0.14))
        for dx in (-0.17, 0.0, 0.17):
            b.ball(name, (x + dx, y - 0.45, 0.11), (0.1, 0.12, 0.09))


def stegosaur(b, s):
    # Arched back (hips high), small low head, two rows of back plates, spiked tail.
    # kentro=True: Kentrosaurus (small plates up front, long spikes over the hips and tail, shoulder spikes).
    kentro = s.get("kentro", False)
    b.ball("Body", (0, 0.4, 2.2), (1.15, 1.9, 1.05), rot=(12, 0, 0))
    b.ball("Body", (0, 1.4, 2.45), (1.0, 0.9, 0.95))
    b.ball("Belly", (0, 0.2, 1.55), (0.95, 1.55, 0.55), rot=(12, 0, 0))
    b.chain("Body", [(0, -1.2, 1.9), (0, -2.0, 1.45)], [0.6, 0.42])
    H = Vector((0, -2.55, 1.3))
    b.ball("Body", tuple(H), (0.45, 0.6, 0.4))
    b.ball("Belly", tuple(H + Vector((0, -0.4, -0.2))), (0.36, 0.42, 0.15))
    for side in (-1, 1):
        _eye(b, H + Vector((side * 0.34, -0.15, 0.14)), 0.17, side)
    tail = b.chain("Body", [(0, 2.2, 2.4), (0, 3.2, 2.1), (0, 4.1, 1.75), (0, 4.8, 1.5)], [0.6, 0.38, 0.2, 0.09], squash=0.9)
    # Back plates: alternating rows following the arch, tallest over the hips.
    for i in range(9):
        t = i / 8
        y = -1.3 + t * 3.3
        hump = 2.2 + 1.1 * math.sin(math.pi * (0.15 + 0.7 * t))
        size = 0.35 + 0.55 * math.sin(math.pi * t)
        side = 1 if i % 2 == 0 else -1
        if kentro and t > 0.45:
            b.cone("Accent", (side * 0.18, y, hump - 0.2), (side * 0.25, 0.25, 1), 0.12, size * 1.6, verts=6)
        else:
            sc = 0.6 if kentro else 1.0
            b.plate("Accent", (side * 0.16, y, hump + size * 0.45 * sc), (0.08, size * 0.42 * sc, size * 0.85 * sc), rot=(0, side * 8, 0))
    # Tail spikes (thagomizer).
    p, r = tail[-3]
    for side in (-1, 1):
        for k in (0, 1):
            b.cone("EyeWhite", tuple(p + Vector((side * r * 0.6, k * 0.45, r * 0.4))), (side, 0.25, 0.55), 0.1, 0.8, verts=6)
    if kentro:  # shoulder spikes
        for side in (-1, 1):
            b.cone("EyeWhite", (side * 1.1, -0.6, 2.0), (side, -0.1, 0.25), 0.13, 1.0, verts=6)
    # Short front legs, longer back legs.
    for name, x, y, top in (("LegFL", -0.8, -0.95, 1.5), ("LegFR", 0.8, -0.95, 1.5), ("LegBL", -0.9, 1.45, 2.1), ("LegBR", 0.9, 1.45, 2.1)):
        b.chain(name, [(x, y, top), (x, y, top * 0.5), (x, y, 0.3)], [0.42, 0.34, 0.3])
        b.ball(name, (x, y - 0.06, 0.13), (0.36, 0.4, 0.13))
        for dx in (-0.14, 0.0, 0.14):
            b.ball(name, (x + dx, y - 0.4, 0.1), (0.09, 0.11, 0.08))


def flyer(b, s):
    # Pterosaurs and Archaeopteryx standing with wings half-spread (reads instantly as "flyer").
    # bird=True: Archaeopteryx (feathered wings and tail, toothy little beak). crest: pterosaur head crest size.
    bird = s.get("bird", False)
    span = s.get("span", 1.0)
    b.ball("Body", (0, 0.1, 2.2), (0.6, 0.85, 0.7), rot=(-25, 0, 0))
    b.ball("Belly", (0, -0.2, 2.0), (0.48, 0.6, 0.52), rot=(-25, 0, 0))
    neck_top = Vector((0, -0.7, 3.4 + 0.25 * s.get("neck", 0)))
    b.chain("Body", [(0, -0.35, 2.75), tuple(neck_top)], [0.32, 0.24])
    H = neck_top + Vector((0, -0.2, 0.25))
    b.ball("Body", tuple(H), (0.36, 0.45, 0.36))
    beak_len = 0.55 if bird else 1.25
    b.cone("Belly" if bird else "Accent", tuple(H + Vector((0, -0.25, -0.05))), (0, -1, -0.12), 0.2, beak_len, verts=10)
    if bird:
        for i in range(3):
            b.cone("EyeWhite", tuple(H + Vector((0.08 * (i - 1), -0.4 - 0.1 * i, -0.15))), (0, 0, -1), 0.03, 0.1, verts=5)
    crest = s.get("crest", 0.0)
    if crest > 0:   # long backswept head crest
        b.cone("Accent", tuple(H + Vector((0, 0.15, 0.15))), (0, 0.85, 0.5), 0.17, 1.2 * crest, verts=8)
    for side in (-1, 1):
        _eye(b, H + Vector((side * 0.27, -0.12, 0.12)), 0.15, side)
    # Wings spread and raised: arm bones (shoulder -> elbow -> wrist -> long wing finger) with skin
    # stretched from the whole arm back to the hip, sagging between, like a real pterosaur wing.
    # bird=True: the same wing shape, finished with a row of long feathers along the trailing edge.
    for side in (-1, 1):
        sh = Vector((side * 0.38, -0.3, 2.65))
        el = sh + Vector((side * 0.75, 0.22, -0.1))
        wr = sh + Vector((side * 1.5 * span, 0.1, 0.25 * span))
        tip = sh + Vector((side * 2.9 * span, 0.55, 0.55 * span))
        b.chain("Body", [tuple(sh), tuple(el), tuple(wr)], [0.16, 0.12, 0.1])
        b.chain("Body", [tuple(wr), tuple(tip)], [0.09, 0.05])
        for k in range(3):   # little hand claws at the wrist
            b.cone("Belly", tuple(wr + Vector((0, -0.05, -0.05))), (side * 0.2, -0.6 + 0.3 * k, -0.8), 0.04, 0.28, verts=5)
        hip = Vector((side * 0.32, 0.55, 1.95))
        sag = Vector((0, 0.35, -0.55 * span))
        trailing = [hip, hip.lerp(tip, 0.35) + sag, hip.lerp(tip, 0.7) + sag * 0.6, tip]
        b.membrane("Accent", [sh, el, wr, tip], trailing)
        if bird:  # long flight feathers fanning off the trailing edge
            for k in range(6):
                t = 0.25 + 0.13 * k
                p = hip.lerp(tip, t) + sag * (1 - abs(t - 0.5) * 1.4) + Vector((0, 0.15, -0.35))
                b.plate("Accent", tuple(p), (0.16, 0.05, 0.5), rot=(0, side * (15 + 8 * k), 0))
    if bird:
        b.chain("Body", [(0, 0.7, 2.0), (0, 1.5, 1.85)], [0.18, 0.1])
        for k in range(5):
            b.ball("Accent", ((k - 2) * 0.12, 1.85, 1.8), (0.08, 0.5, 0.05), rot=(0, 0, (k - 2) * 10))
    else:
        b.chain("Body", [(0, 0.75, 2.0), (0, 1.15, 1.85)], [0.18, 0.06])
    for side, name in ((-1, "LegL"), (1, "LegR")):
        x = side * 0.34
        # sturdier, bent legs (thigh forward, shin back) so it crouches instead of standing on stilts
        b.chain(name, [(x, 0.3, 1.85), (x, -0.05, 1.1), (x, 0.2, 0.25)], [0.24, 0.16, 0.12])
        b.ball(name, (x, 0.0, 0.12), (0.22, 0.32, 0.11))
        for dx in (-0.11, 0.0, 0.11):
            b.ball(name, (x + dx, -0.3, 0.1), (0.07, 0.13, 0.07))


PLANS = {"theropod": theropod, "ceratopsian": ceratopsian, "ankylosaur": ankylosaur, "sauropod": sauropod, "stegosaur": stegosaur, "flyer": flyer}


def build(species):
    s = SPECIES[species]
    b = Builder(species)
    b.eyewhite_budget = s.get("eyewhite", BUDGET["EyeWhite"])
    b.accent_budget = s.get("accent_budget", BUDGET["Accent"])
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
