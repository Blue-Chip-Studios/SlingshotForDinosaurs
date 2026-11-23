"""
SlingshotForDinosaurs: plush-style dinos (prototype), built on dino_v2's Builder.

Style: soft toy. A big round head on a small upright pear body, stubby legs and arms, small black
bead eyes with a shine dot, pink blush cheeks, a smile crease instead of teeth, and every species
feature (horns, frills, plates, sails, crests) kept but rounded.

Usage (Blender MCP, after dino_v2.py):
    exec(open(r"<repo>/Assets/Blender/scripts/plush.py").read())
    build_plush("TRex"); render_portrait("TRex", out_dir)

Regions as dino_v2 (+ "Blush"); head / jaw / tail are split pieces with Joint_* markers.
"""

import math

from mathutils import Vector

BUDGET.update({"Pupil": 900, "EyeWhite": 300, "Blush": 600})


def _surf(c, size, d, k=1.0):
    """Point on the ellipsoid (centre c, half-extents size) in direction d. k < 1 pulls it inward:
    big fused metaball bodies sit a little inside their nominal size."""
    c, d = Vector(c), Vector(d).normalized()
    t = 1.0 / math.sqrt(sum((d[i] / size[i]) ** 2 for i in range(3)))
    return c + d * t * k


def _patch(b, region, c, size, d, r):
    """A flat round marking sunk into the surface so only a soft disc shows (spots, armour)."""
    n = Vector(d).normalized()
    b.sphere(region, tuple(_surf(c, size, d, 0.86) - n * r * 0.35), r, scale=(1, 1, 0.85))


def _face(b, H, cs, hs, blush=True, eye=0.13):
    """Bead eyes with a shine dot, blush cheeks. H/cs: head centre and half-extents."""
    for side in (-1, 1):
        n = Vector((side * 0.42, -0.9, 0.18)).normalized()      # front-facing, fairly close together
        p = _surf(H, cs, n)
        b.sphere("Pupil", tuple(p - n * eye * hs * 0.45), eye * hs, scale=(1, 1, 1.15))
        b.sphere("EyeWhite", tuple(p + n * eye * hs * 0.42 + Vector((side * 0.02, 0, 0.05)) * hs), 0.038 * hs)
        if blush:
            m = Vector((side * 0.72, -0.62, -0.3)).normalized()
            q = _surf(H, cs, m)
            b.sphere("Blush", tuple(q - m * 0.09 * hs), 0.15 * hs, scale=(1, 1, 0.75))


def _legs(b, w=1.0, x=0.5, plantigrade=True):
    for side, name in ((-1, "LegL"), (1, "LegR")):
        lx = side * x * w
        b.ball(name, (lx, 0.08, 0.55), (0.4 * w, 0.42, 0.55))
        b.ball(name, (lx, -0.12, 0.17), (0.42 * w, 0.56, 0.19))
        for dx in (-0.18, 0.0, 0.18):        # soft toe pads
            b.ball(name, (lx + dx * w, -0.6, 0.14), (0.11, 0.1, 0.1))


def _arms(b, w=1.0, sc=1.0):
    for side in (-1, 1):
        b.ball("Body", (side * 0.84 * w, -0.32, 1.78), (0.22 * sc, 0.26 * sc, 0.4 * sc), rot=(28, 0, side * 22))


def _body(b, w=1.0, belly=True, z=1.0):
    b.ball("Body", (0, 0.05, 1.45 * z), (0.95 * w, 0.85, 1.12 * z))
    b.ball("Body", (0, 0.15, 0.95 * z), (1.02 * w, 0.92, 0.72 * z))
    if belly:
        b.ball("Belly", (0, -0.4, 1.32 * z), (0.72 * w, 0.52, 0.98 * z))


def _tail(b, length=1.0, r=1.0, club=False, spikes=False):
    b.joint("Tail", (0, 0.6, 1.05))
    b.group = "Tail"
    pts = b.chain("Body", [(0, 0.55, 1.0), (0, 0.55 + 0.85 * length, 0.62), (0, 0.55 + 1.5 * length, 0.38)], [0.5 * r, 0.32 * r, 0.15 * r], squash=0.9)
    end = Vector((0, 0.55 + 1.5 * length, 0.38))
    if club:
        b.ball("Accent", tuple(end + Vector((0, 0.15, 0))), (0.36, 0.3, 0.26))
    if spikes:
        for side in (-1, 1):
            for k in (0, 1):
                b.cone("EyeWhite", tuple(end + Vector((side * 0.08, -0.25 + k * 0.25, 0.08))), (side, 0.2, 0.7), 0.09, 0.42, verts=10)
    b.group = None
    return pts


def plush_theropod(b, s):
    w, hs = s.get("w", 1.0), 1.0 + 0.25 * (s.get("head", 1.0) - 1.0)
    _body(b, w)
    H = Vector((0, -0.28, 3.05))
    cs = (1.02 * hs, 0.95 * hs, 0.9 * hs)
    b.joint("Head", (0, -0.15, 2.45))
    b.joint("Jaw", H + Vector((0, -0.1 * hs, -0.45 * hs)))
    b.group = "Head"
    b.ball("Body", tuple(H), cs)
    muz = H + Vector((0, -0.78 * hs, -0.22 * hs))
    ms = (0.76 * hs, 0.72 * hs * s.get("snout", 1.0) ** 0.5, 0.52 * hs)
    b.ball("Body", tuple(muz), ms)
    for side in (-1, 1):                  # little nostrils
        b.sphere("Pupil", tuple(_surf(muz, ms, (side * 0.3, -1, 0.45))), 0.035 * hs)
    if s.get("teeth"):                    # two tiny cute fangs at the front of the smile
        for side in (-1, 1):
            b.cone("EyeWhite", tuple(_surf(muz, ms, (side * 0.2, -1, -0.5), 0.93)), (0, -0.3, -1), 0.045 * hs, 0.11 * hs, verts=8)
    _face(b, H, cs, hs)
    # soft spikes down the back of the head
    if s.get("stripes", 0) or s.get("back_spikes"):
        for d in ((0, 0.25, 1), (0, 0.75, 0.7), (0, 1, 0.2)):
            b.ball("Accent", tuple(_surf(H, cs, d, 0.8)), (0.13, 0.15, 0.14))
    b.group = "Jaw"
    b.ball("Body", tuple(H + Vector((0, -0.66 * hs, -0.56 * hs))), (0.66 * hs, 0.6 * hs, 0.26 * hs))
    b.group = None
    if s.get("stripes", 0) or s.get("back_spikes"):
        for z in (2.35, 1.9, 1.45):
            b.ball("Accent", tuple(_surf((0, 0.05, 1.45), (0.95 * w, 0.85, 1.12), (0, 1, (z - 1.45) * 1.1), 0.9)), (0.15, 0.17, 0.16))
    _arms(b, w, 0.75 if s.get("arms") == "tiny" else 1.0)
    _legs(b, w)
    _tail(b, s.get("tail", 1.0))


def plush_ceratopsian(b, s):
    _body(b, 1.08)
    hs = 1.08
    H = Vector((0, -0.3, 3.0))
    cs = (1.05 * hs, 0.98 * hs, 0.9 * hs)
    horns = s.get("horns", "tri")
    b.joint("Head", (0, -0.15, 2.4))
    b.joint("Jaw", H + Vector((0, -0.1 * hs, -0.45 * hs)))
    b.group = "Head"
    b.ball("Body", tuple(H), cs)
    muz = H + Vector((0, -0.75 * hs, -0.25 * hs))
    ms = (0.7 * hs, 0.62 * hs, 0.5 * hs)
    b.ball("Body", tuple(muz), ms)
    for side in (-1, 1):
        b.sphere("Pupil", tuple(_surf(muz, ms, (side * 0.32, -1, 0.4))), 0.035 * hs)
    _face(b, H, cs, hs)
    # Frill: a big soft shield behind the head with a scalloped rim.
    fs = 0.7 if horns == "none" else 1.0
    fc = H + Vector((0, 0.5 * hs, 0.4 * hs))
    b.plate("Accent", tuple(fc), (1.3 * hs * fs, 0.14 * hs, 1.08 * hs * fs), rot=(-22, 0, 0))
    for i in range(11):
        a = math.radians(-100 + i * 20)
        p = fc + Vector((1.25 * hs * fs * math.sin(a), 0.05 + 0.4 * hs * fs * math.cos(a) * math.sin(math.radians(22)), 1.02 * hs * fs * math.cos(a) * math.cos(math.radians(22))))
        if horns == "styraco" and 2 <= i <= 8:
            out = Vector((math.sin(a), 0.2, math.cos(a))).normalized()
            b.cone("EyeWhite", tuple(p), tuple(out), 0.1 * hs, 0.55 * hs, verts=10)
        else:
            b.sphere("Accent", tuple(p), 0.2 * hs * fs, scale=(1, 0.7, 1))
    if horns == "tri":
        for side in (-1, 1):   # two brow horns, short and rounded
            b.cone("EyeWhite", tuple(_surf(H, cs, (side * 0.42, -0.55, 0.72)) - Vector((0, 0, 0.05))), (side * 0.15, -0.55, 0.85), 0.14 * hs, 0.5 * hs, verts=12)
    if horns in ("tri", "styraco"):
        b.cone("EyeWhite", tuple(_surf(muz, ms, (0, -0.6, 0.8)) - Vector((0, 0, 0.04))), (0, -0.3, 1), 0.13 * hs, 0.38 * hs * (1.5 if horns == "styraco" else 1.0), verts=12)
    b.group = "Jaw"
    b.ball("Body", tuple(H + Vector((0, -0.62 * hs, -0.58 * hs))), (0.6 * hs, 0.55 * hs, 0.25 * hs))
    b.group = None
    if s.get("spots"):
        for (x, z) in ((-0.55, 1.9), (0.6, 1.4), (-0.7, 1.1), (0.5, 2.1)):
            _patch(b, "Accent", (0, 0.05, 1.45), (1.03, 0.85, 1.12), (x, 0.3, z - 1.45), 0.2)
    _arms(b, 1.08)
    _legs(b, 1.08)
    _tail(b, 0.9, 1.1)


def plush_sauropod(b, s):
    _body(b, 1.12)
    style = s.get("neck", "up")
    # Long soft neck rising from the chest to a small round head.
    if style == "low":
        neck = [(0, -0.35, 2.2), (0, -0.85, 3.0), (0, -1.35, 3.55)]
        H = Vector((0, -1.75, 3.85))
    else:
        neck = [(0, -0.3, 2.2), (0, -0.48, 3.0), (0, -0.6, 3.7)]
        H = Vector((0, -0.85, 4.15))
    nr = (0.68, 0.55, 0.47)
    b.chain("Body", neck, list(nr))
    b.chain("Belly", [tuple(Vector(p) + Vector((0, -0.3, -0.12)) * r) for p, r in zip(neck, nr)], [0.5 * r for r in nr])
    if style == "spines":
        for p in neck[1:]:
            for side in (-1, 1):
                b.cone("Accent", tuple(Vector(p) + Vector((side * 0.12, 0.15, 0.3))), (side * 0.2, 0.3, 1), 0.08, 0.55, verts=10)
    hs = 0.82
    cs = (0.95 * hs, 0.95 * hs, 0.85 * hs)
    b.joint("Head", Vector(neck[-1]) + Vector((0, -0.05, 0.1)))
    b.joint("Jaw", H + Vector((0, -0.1 * hs, -0.45 * hs)))
    b.group = "Head"
    b.ball("Body", tuple(H), cs)
    muz = H + Vector((0, -0.62 * hs, -0.2 * hs))
    ms = (0.66 * hs, 0.55 * hs, 0.48 * hs)
    b.ball("Body", tuple(muz), ms)
    if style == "up":
        b.ball("Body", tuple(H + Vector((0, -0.2 * hs, 0.6 * hs))), (0.45 * hs, 0.5 * hs, 0.4 * hs))   # nasal bump
    _face(b, H, cs, hs, eye=0.15)
    b.group = "Jaw"
    b.ball("Body", tuple(H + Vector((0, -0.55 * hs, -0.52 * hs))), (0.56 * hs, 0.5 * hs, 0.22 * hs))
    b.group = None
    if style == "up":
        for (x, z) in ((-0.6, 1.9), (0.62, 1.5), (-0.72, 1.15), (0.55, 2.15), (0.0, 2.5)):
            _patch(b, "Accent", (0, 0.05, 1.45), (1.06, 0.85, 1.12), (x, 0.45, z - 1.45), 0.22)
    if style == "low":
        for z in (1.2, 1.7, 2.2):
            b.ball("Accent", (0, 0.45, z), (1.0, 0.12, 0.13))
    _arms(b, 1.12)
    _legs(b, 1.12)
    _tail(b, 1.4 if style == "low" else 1.1, 1.05)


def plush_stegosaur(b, s):
    kentro = s.get("kentro", False)
    _body(b, 1.05)
    hs = 0.95
    H = Vector((0, -0.3, 2.95))
    cs = (0.98 * hs, 0.95 * hs, 0.88 * hs)
    b.joint("Head", (0, -0.15, 2.35))
    b.joint("Jaw", H + Vector((0, -0.1 * hs, -0.45 * hs)))
    b.group = "Head"
    b.ball("Body", tuple(H), cs)
    muz = H + Vector((0, -0.7 * hs, -0.25 * hs))
    ms = (0.66 * hs, 0.6 * hs, 0.46 * hs)
    b.ball("Body", tuple(muz), ms)
    _face(b, H, cs, hs)
    b.group = "Jaw"
    b.ball("Body", tuple(H + Vector((0, -0.6 * hs, -0.55 * hs))), (0.58 * hs, 0.52 * hs, 0.24 * hs))
    b.group = None
    # Two staggered rows of rounded plates from the back of the head down to the tail.
    body_c, body_s = (0, 0.05, 1.45), (1.0, 0.85, 1.12)
    for i in range(5):
        t = i / 4
        z = 2.65 - 1.7 * t                               # shoulders down to the hips
        d = Vector((0, 0.75 + 0.25 * t, (z - 1.45) * 1.1))
        n = (d.normalized() + Vector((0, 0, 0.9))).normalized()   # plates stand up, not out
        size = 0.55 + 0.3 * math.sin(math.pi * min(1.0, t * 1.4))   # tall enough to show over the shoulders
        side = 1 if i % 2 == 0 else -1
        root = _surf(body_c, body_s, d, 0.85) + Vector((side * 0.1, 0, 0))
        if kentro and t > 0.5:
            b.cone("Accent", tuple(root), tuple(n + Vector((side * 0.25, 0, 0))), 0.11, size * 1.5, verts=10)
        else:
            b.plate("Accent", tuple(root + n * size * 0.62), (0.07, size * 0.42, size), rot=(-math.degrees(math.atan2(n.y, n.z)), 0, side * 6))
    _arms(b, 1.05)
    _legs(b, 1.05)
    _tail(b, 1.0, 1.0, spikes=True)


def plush_ankylosaur(b, s):
    _body(b, 1.2, z=0.92)
    hs = 0.95
    H = Vector((0, -0.32, 2.8))
    cs = (1.0 * hs, 0.92 * hs, 0.85 * hs)
    b.joint("Head", (0, -0.15, 2.25))
    b.joint("Jaw", H + Vector((0, -0.1 * hs, -0.45 * hs)))
    b.group = "Head"
    b.ball("Body", tuple(H), cs)
    muz = H + Vector((0, -0.66 * hs, -0.25 * hs))
    ms = (0.7 * hs, 0.55 * hs, 0.45 * hs)
    b.ball("Body", tuple(muz), ms)
    _face(b, H, cs, hs)
    for side in (-1, 1):
        b.cone("Accent", tuple(_surf(H, cs, (side * 0.8, 0.3, 0.45))), (side * 0.8, 0.4, 0.35), 0.12 * hs, 0.3 * hs, verts=10)
    b.group = "Jaw"
    b.ball("Body", tuple(H + Vector((0, -0.58 * hs, -0.52 * hs))), (0.6 * hs, 0.48 * hs, 0.22 * hs))
    b.group = None
    for (x, z) in ((-0.5, 2.2), (0.5, 2.2), (0.0, 2.35), (-0.85, 1.6), (0.85, 1.6), (-0.4, 1.75), (0.4, 1.75), (0, 1.2), (-0.85, 1.0), (0.85, 1.0)):
        _patch(b, "Accent", (0, 0.05, 1.33), (1.14, 0.85, 1.03), (x, 0.55, z - 1.33), 0.22)
    _arms(b, 1.2)
    _legs(b, 1.2)
    _tail(b, 1.0, 1.0, club=True)


PLUSH_PLANS = {"theropod": plush_theropod, "ceratopsian": plush_ceratopsian, "sauropod": plush_sauropod,
               "stegosaur": plush_stegosaur, "ankylosaur": plush_ankylosaur}


def _pastel(hexs, k=0.18):
    r, g, bl = _hex(hexs)
    return "%02X%02X%02X" % tuple(int(255 * (c + (1 - c) * k)) for c in (r, g, bl))


def build_plush(species):
    s = SPECIES[species]
    b = Builder(species)
    b.eyewhite_budget = 260
    b.accent_budget = max(1000, s.get("accent_budget", 0))
    PLUSH_PLANS[s["plan"]](b, s)
    objs = b.finish()
    cols = {"Body": _pastel(s["body"]), "Belly": _pastel(s["belly"], 0.1), "Accent": _pastel(s["accent"], 0.12),
            "EyeWhite": "FFFFFF", "Pupil": "17131C", "Blush": "FF9DB4"}
    for region, o in objs.items():
        base = region.partition("_")[0]
        rgb = _hex(cols.get(base, cols["Body"]))
        mat = bpy.data.materials.get(f"PL_{species}_{base}") or bpy.data.materials.new(f"PL_{species}_{base}")
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes["Principled BSDF"]
        lin = tuple(c ** 2.2 for c in rgb)
        bsdf.inputs["Base Color"].default_value = (*lin, 1)
        glossy = base in ("Pupil", "EyeWhite")
        bsdf.inputs["Roughness"].default_value = 0.15 if glossy else 0.9
        if "Sheen Weight" in bsdf.inputs and not glossy:   # soft fuzzy plush rim
            bsdf.inputs["Sheen Weight"].default_value = 0.8
            bsdf.inputs["Sheen Tint"].default_value = (1, 1, 1, 1)
        if "Emission Color" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = (*lin, 1)
            bsdf.inputs["Emission Strength"].default_value = 0.0
        o.data.materials.clear()
        o.data.materials.append(mat)
    return objs


def render_plush(species, out_dir, size=512):
    """Soft studio render (no ink outline) from a 3/4 front view, for judging the plush look."""
    coll = bpy.data.collections[species]
    scene = bpy.context.scene
    for c in bpy.data.collections:
        c.hide_render = c != coll
    pts = [o.matrix_world @ Vector(cn) for o in coll.objects for cn in o.bound_box]
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    centre = (mn + mx) / 2
    span = (mx - mn).length
    cam = bpy.data.objects["Camera"]
    cam.location = centre + Vector((-0.55, -1.0, 0.22)).normalized() * span * 1.15
    cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.film_transparent = True
    scene.render.resolution_x = scene.render.resolution_y = size
    scene.render.filepath = os.path.join(out_dir, f"{species}_plush.png")
    bpy.ops.render.render(write_still=True)
    for c in bpy.data.collections:
        c.hide_render = False
    return scene.render.filepath
