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

BUDGET.update({"Pupil": 900, "EyeWhite": 300, "Blush": 600, "Body": 2600, "Belly": 500, "Leg": 380})


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
    # Long-necked species (Gallimimus, Therizinosaurus) lift the head on a soft neck.
    lift = 0.55 * max(0.0, s.get("neck", 1.0) - 1.15) + 0.45 * s.get("neck_up", 0.0)
    H = Vector((0, -0.28 - 0.2 * lift, 3.05 + lift))
    if lift > 0:
        b.chain("Body", [(0, -0.1, 2.3), (0, -0.2 - 0.1 * lift, 2.5 + lift * 0.6)], [0.48 * w, 0.4 * w])
        b.chain("Belly", [(0, -0.38, 2.2), (0, -0.45 - 0.1 * lift, 2.45 + lift * 0.55)], [0.3 * w, 0.24 * w])
    cs = (1.02 * hs, 0.95 * hs, 0.9 * hs)
    hl = s.get("head_len", 1.0) * s.get("snout", 1.0) ** 0.45
    b.joint("Head", (0, -0.15 - 0.15 * lift, 2.45 + lift * 0.8))
    b.joint("Jaw", H + Vector((0, -0.1 * hs, -0.45 * hs)))
    b.group = "Head"
    b.ball("Body", tuple(H), cs)
    muz = H + Vector((0, -(0.78 + 0.35 * (hl - 1)) * hs, -0.22 * hs))
    ms = (0.76 * hs / max(1.0, hl) ** 0.4, 0.72 * hs * hl, 0.52 * hs)
    b.ball("Body", tuple(muz), ms)
    if s.get("bill"):                     # hadrosaur duck bill: broad, flat, belly-coloured
        bill = muz + Vector((0, -0.42 * hs, -0.08 * hs))
        b.ball("Belly", tuple(bill), (0.66 * hs, 0.5 * hs, 0.22 * hs))
    elif s.get("beak"):                   # Gallimimus: short pointed beak
        b.cone("Accent", tuple(_surf(muz, ms, (0, -1, -0.1), 0.85)), (0, -1, -0.2), 0.24 * hs, 0.42 * hs, verts=16)
    else:
        for side in (-1, 1):              # little nostrils
            b.sphere("Pupil", tuple(_surf(muz, ms, (side * 0.3, -1, 0.45))), 0.035 * hs)
    if s.get("teeth") and not s.get("bill"):   # two tiny cute fangs at the front of the smile
        for side in (-1, 1):
            b.cone("EyeWhite", tuple(_surf(muz, ms, (side * 0.2, -1, -0.5), 0.93)), (0, -0.3, -1), 0.045 * hs, 0.11 * hs, verts=8)
    _face(b, H, cs, hs, eye=0.13 * min(1.15, max(0.9, s.get("eyes", 1.0))))

    def top(d, k=0.86):
        return _surf(H, cs, d, k)

    # ---- soft head ornaments (sized to read at game distance, ~1.4x the first pass) ----
    if s.get("head_tuft"):                # raptor feather tuft
        for a in (-0.35, 0.0, 0.35):
            b.cone("Accent", tuple(top((a, 0.2, 1))), (a * 0.8, 0.7, 0.8), 0.17 * hs, 0.8 * hs, verts=12)
    if s.get("double_crest"):             # Dilophosaurus: two rounded crests
        for side in (-1, 1):
            b.plate("Accent", tuple(top((side * 0.3, -0.25, 1), 0.92) + Vector((0, 0, 0.3 * hs))), (0.11 * hs, 0.66 * hs, 0.46 * hs), rot=(-12, side * 8, 0))
    if s.get("neck_frill"):               # Dilophosaurus umbrella frill
        b.plate("Accent", tuple(H + Vector((0, 0.55 * hs, -0.2 * hs))), (1.45 * hs, 0.1 * hs, 1.12 * hs), rot=(-10, 0, 0))
        for i in range(9):
            a = math.radians(-120 + i * 30)
            b.sphere("Accent", tuple(H + Vector((1.4 * hs * math.sin(a), 0.6 * hs, -0.2 * hs + 1.07 * hs * math.cos(a)))), 0.19 * hs, scale=(1, 0.6, 1))
    if s.get("fan_crest"):                # Cryolophosaurus: tall wavy crest across the head
        for i in range(5):
            x = (i - 2) * 0.22
            ht = (0.55 - abs(i - 2) * 0.12) * hs
            b.plate("Accent", tuple(top((x, -0.1, 1), 0.9) + Vector((0, 0, ht * 0.85))), (0.1 * hs, 0.15 * hs, ht))
    if s.get("bull_horns"):               # Carnotaurus: two big soft horns
        for side in (-1, 1):
            b.cone("Accent", tuple(top((side * 0.45, -0.1, 0.9))), (side * 0.75, -0.1, 0.65), 0.2 * hs, 0.7 * hs, verts=14)
    if s.get("brow_horns"):               # Allosaurus: horn over each eye
        for side in (-1, 1):
            b.cone("Accent", tuple(top((side * 0.38, -0.55, 0.75))), (side * 0.2, -0.2, 1), 0.15 * hs, 0.45 * hs, verts=12)
    if s.get("tube_crest"):               # Parasaurolophus: long backswept tube
        t0 = top((0, 0.1, 1), 0.85)
        b.chain("Accent", [tuple(t0), tuple(t0 + Vector((0, 0.85 * hs, 0.35 * hs))), tuple(t0 + Vector((0, 1.7 * hs, 0.5 * hs)))], [0.22 * hs, 0.21 * hs, 0.19 * hs])
    if s.get("dome"):                     # Pachycephalosaurus: thick round dome with a ring of bumps
        b.ball("Accent", tuple(H + Vector((0, 0.05 * hs, 0.5 * hs))), (0.92 * hs, 0.86 * hs, 0.7 * hs))
        for i in range(10):
            a = math.radians(i * 36)
            b.sphere("Accent", tuple(top((math.cos(a), math.sin(a) * 0.9 + 0.05, 0.25), 0.95)), 0.13 * hs)
    if s.get("helmet"):                   # Corythosaurus: tall rounded helmet crest
        b.plate("Accent", tuple(top((0, 0.05, 1), 0.72) + Vector((0, 0, 0.05 * hs))), (0.17 * hs, 0.75 * hs, 0.75 * hs))   # half sunk into the skull
    spiky = (s.get("stripes", 0) or s.get("back_spikes")) and not s.get("sail")
    if spiky:                             # soft dino spikes from the crown down the back of the head
        for i, d in enumerate(((0, 0.15, 1), (0, 0.6, 0.8), (0, 0.95, 0.35))):
            p = top(d, 0.8)
            n = (Vector(d).normalized() + Vector((0, 0.3, 0.4))).normalized()
            b.cone("Accent", tuple(p), tuple(n), (0.17 - 0.02 * i) * hs, (0.42 - 0.05 * i) * hs, verts=12)
    b.group = "Jaw"
    jaw_c = H + Vector((0, -(0.66 + 0.3 * (hl - 1)) * hs, -0.56 * hs))
    b.ball("Belly" if s.get("bill") else "Body", tuple(jaw_c), (0.66 * hs / max(1.0, hl) ** 0.4, 0.6 * hs * hl, 0.26 * hs))
    b.group = None
    # ---- body features ----
    body_c, body_s = (0, 0.05, 1.45), (0.95 * w, 0.85, 1.12)
    if s.get("sail"):                     # Spinosaurus / Ouranosaurus: big rounded back sail
        # A thick soft fan (reads from the front too) with a beaded top edge, like a stitched plush fin.
        big = 1.25 if s.get("snout", 1.0) > 1.2 else 1.0
        # One wide fan rising from the back, tilted back a little, with soft beads round its rim.
        fan_c = Vector((0, 0.95, 2.35 + 0.55 * big))
        fan_s = (0.15, 0.95 * big, 0.95 * big)
        b.plate("Accent", tuple(fan_c), fan_s, rot=(-18, 0, 0))
        tilt = math.radians(-18)
        for i in range(7):
            a = math.radians(-75 + i * 25)
            ly, lz = 0.93 * fan_s[1] * math.sin(a), 0.93 * fan_s[2] * math.cos(a)
            p = fan_c + Vector((0, ly * math.cos(tilt) - lz * math.sin(tilt), ly * math.sin(tilt) + lz * math.cos(tilt)))
            b.sphere("Accent", tuple(p), 0.17 * big, scale=(1.1, 1, 1))
    elif s.get("stripes", 0) or s.get("back_spikes"):
        # Soft dino spikes down the spine onto the tail (the classic plush-dino read).
        for i, z in enumerate((2.45, 2.05, 1.65, 1.25)):
            d = Vector((0, 1, (z - 1.45) * 1.1))
            p = _surf(body_c, body_s, d, 0.92)
            n = (d.normalized() + Vector((0, 0, 0.55))).normalized()
            k = 1.0 + (0.25 if s.get("back_spikes") else 0.0)
            b.cone("Accent", tuple(p), tuple(n), 0.2 * k, (0.48 - 0.04 * i) * k, verts=12)
    if s.get("osteoderms"):               # Carnotaurus: soft armour bumps on the flanks
        for side in (-1, 1):
            for (y, z) in ((0.1, 2.0), (0.35, 1.6), (0.0, 1.35), (0.4, 2.2)):
                b.sphere("Accent", tuple(_surf(body_c, body_s, (side * 1.0, y, z - 1.45), 0.92)), 0.14, scale=(0.8, 1, 1))
    arms = s.get("arms", "normal")
    if s.get("wings"):                    # Microraptor: little feathered wings on the arms
        for side in (-1, 1):
            sh = Vector((side * 0.8 * w, -0.2, 1.95))
            b.chain("Body", [tuple(sh), tuple(sh + Vector((side * 1.1, 0.05, 0.35)))], [0.2, 0.12])
            for k in range(4):
                b.plate("Accent", tuple(sh + Vector((side * (0.4 + 0.25 * k), 0.25, 0.1 - 0.15 * k))), (0.1, 0.4, 0.6 - 0.05 * k), rot=(25, side * (15 + 12 * k), 0))
    else:
        sc = {"tiny": 0.75, "normal": 1.0, "long": 1.35}.get(arms, 1.0)
        _arms(b, w, sc)
        for side in (-1, 1):
            # raised paw: the upper-front end of the stubby arm ball (tilted 28 deg, 22 deg out)
            hand = Vector((side * (0.84 * w + 0.12 * sc), -0.32 - 0.24 * sc, 1.78 + 0.33 * sc))
            if s.get("scythe_claws"):     # Therizinosaurus: three long soft claws
                for j in (-1, 0, 1):
                    b.cone("EyeWhite", tuple(hand + Vector((j * 0.07, 0, 0))), (side * 0.1 + j * 0.2, -1, 0.15), 0.05, 0.5, verts=10)
            if s.get("thumb_claw"):       # Baryonyx: one hooked claw
                b.cone("EyeWhite", tuple(hand), (side * 0.1, -1, 0.1), 0.06, 0.3, verts=10)
            if s.get("thumb_spike"):      # Iguanodon: thumb spike pointing up
                b.cone("EyeWhite", tuple(hand), (side * 0.2, -0.3, 1), 0.07, 0.28, verts=10)
    _legs(b, w)
    if s.get("sickle"):                   # Velociraptor: raised toe claw
        for side, name in ((-1, "LegL"), (1, "LegR")):
            b.cone(name, (side * 0.5 * w - side * 0.18, -0.45, 0.25), (0, -0.4, 0.9), 0.07, 0.3, verts=10)
    tl = s.get("tail", 1.0) * (1.15 if s.get("wings") else 1.0)
    _tail(b, tl)
    if (s.get("stripes", 0) or s.get("back_spikes")) and not s.get("sail") and not s.get("wings"):
        b.group = "Tail"
        for k in range(3):                # spikes carry on down the tail, shrinking
            t = 0.2 + 0.28 * k
            y = 0.55 + 1.5 * tl * t
            zc = 1.0 - 0.62 * t
            r = 0.5 - 0.35 * t
            b.cone("Accent", (0, y, zc + r * 0.75), (0, 0.5, 1), 0.15 - 0.04 * k, 0.38 - 0.08 * k, verts=12)
        b.group = None
    if s.get("wings"):                    # tail feather fan
        b.group = "Tail"
        for k in (-1, 0, 1):
            b.plate("Accent", (k * 0.15, 0.55 + 1.5 * tl, 0.4), (0.1, 0.4, 0.04), rot=(0, 0, k * 20))
        b.group = None


def plush_flyer(b, s):
    """Pterosaurs: plush body, long beak and crest, soft wings held out to the sides."""
    span = s.get("span", 1.0)
    _body(b, 0.95)
    lift = 0.5 * max(0.0, s.get("neck", 0.0) - 1.0)      # Quetzalcoatlus: long neck
    H = Vector((0, -0.3 - 0.2 * lift, 3.0 + lift))
    if lift > 0:
        b.chain("Body", [(0, -0.15, 2.3), (0, -0.25 - 0.1 * lift, 2.5 + lift * 0.6)], [0.42, 0.34])
    hs = 0.92
    cs = (0.95 * hs, 0.95 * hs, 0.88 * hs)
    b.joint("Head", (0, -0.15 - 0.15 * lift, 2.45 + lift * 0.8))
    b.group = "Head"
    b.ball("Body", tuple(H), cs)
    beak_root = _surf(H, cs, (0, -1, -0.15), 0.8)
    b.cone("Accent", tuple(beak_root), (0, -1, -0.12), 0.32 * hs, 1.0 * hs * (1.15 if lift else 1.0), verts=18)
    crest = s.get("crest", 0.0)
    if crest:
        b.cone("Accent", tuple(_surf(H, cs, (0, 0.45, 0.9), 0.85)), (0, 0.85, 0.45), 0.2 * hs, 0.9 * hs * crest, verts=16)
    _face(b, H, cs, hs)
    b.group = None
    for side in (-1, 1):
        sh = Vector((side * 0.75, -0.1, 2.15))
        tip = sh + Vector((side * 1.7 * span, 0.15, 0.35))
        b.chain("Body", [tuple(sh), tuple(sh.lerp(tip, 0.55)), tuple(tip)], [0.2, 0.14, 0.09])
        mid = sh.lerp(tip, 0.5) + Vector((0, 0.12, -0.45))
        b.plate("Accent", tuple(mid), (0.95 * span, 0.07, 0.55), rot=(0, side * -10, 0))
    _legs(b, 0.95)
    b.joint("Tail", (0, 0.6, 1.05))   # no real tail: a short nub
    b.group = "Tail"
    b.ball("Body", (0, 0.75, 0.95), (0.25, 0.3, 0.22))
    b.group = None


def plush_bird(b, s):
    """Archaeopteryx: plush body, small beak, feather crest, feathered wings and a long feather tail."""
    _body(b, 0.95)
    hs = 0.95
    H = Vector((0, -0.3, 3.0))
    cs = (0.98 * hs, 0.95 * hs, 0.9 * hs)
    b.joint("Head", (0, -0.15, 2.45))
    b.group = "Head"
    b.ball("Body", tuple(H), cs)
    b.cone("Belly", tuple(_surf(H, cs, (0, -1, -0.2), 0.82)), (0, -1, -0.15), 0.26 * hs, 0.45 * hs, verts=16)
    for k in range(3):
        b.cone("Accent", tuple(_surf(H, cs, (0, 0.2 + 0.3 * k, 1), 0.85)), (0, 0.8, 0.6 - 0.15 * k), 0.09 * hs, 0.5 * hs - 0.06 * k, verts=12)
    _face(b, H, cs, hs)
    b.group = None
    for side in (-1, 1):
        sh = Vector((side * 0.8, -0.15, 2.05))
        tip = sh + Vector((side * 1.3, 0.2, 0.55))
        b.chain("Body", [tuple(sh), tuple(tip)], [0.2, 0.12])
        for k in range(5):
            t = 0.3 + 0.17 * k
            p = sh.lerp(tip, t) + Vector((0, 0.18, -0.3))
            b.plate("Accent", tuple(p), (0.12, 0.08, 0.45 + 0.05 * k), rot=(10, side * (25 + 6 * k), 0))
    _legs(b, 0.95)
    _tail(b, 1.1, 0.9)
    b.group = "Tail"
    for k in (-2, -1, 0, 1, 2):
        b.plate("Accent", (k * 0.16, 0.55 + 1.5 * 1.1, 0.42 + 0.06 * (2 - abs(k))), (0.11, 0.45, 0.04), rot=(-10, 0, k * 16))
    b.group = None


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
                b.cone("Accent", tuple(Vector(p) + Vector((side * 0.14, 0.2, 0.25))), (side * 0.25, 0.45, 1), 0.1, 1.0, verts=12)
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
        z = 2.85 - 1.8 * t                               # behind the head down to the hips
        d = Vector((0, 0.75 + 0.25 * t, (z - 1.45) * 1.1))
        n = (d.normalized() + Vector((0, 0, 0.9))).normalized()   # plates stand up, not out
        size = 0.7 + 0.35 * math.sin(math.pi * min(1.0, t * 1.4))   # tall enough to show over the shoulders
        side = 1 if i % 2 == 0 else -1
        root = _surf(body_c, body_s, d, 0.85) + Vector((side * 0.1, 0, 0))
        if kentro and t > 0.5:
            b.cone("Accent", tuple(root), tuple(n + Vector((side * 0.25, 0, 0))), 0.11, size * 1.5, verts=10)
        else:
            b.plate("Accent", tuple(root + n * size * 0.62), (0.15, size * 0.42, size), rot=(-math.degrees(math.atan2(n.y, n.z)), 0, side * 16))
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
    b.group = "Jaw"
    b.ball("Body", tuple(H + Vector((0, -0.58 * hs, -0.52 * hs))), (0.6 * hs, 0.48 * hs, 0.22 * hs))
    b.group = None
    # Armour: a domed shell over the back with soft studs, and a row of cream spikes down each side.
    shell_c, shell_s = Vector((0, 0.42, 1.5)), (1.18, 0.62, 1.02)
    b.ball("Accent", tuple(shell_c), shell_s)
    for (x, z) in ((-0.45, 0.45), (0.45, 0.45), (0.0, 0.6), (-0.75, 0.0), (0.75, 0.0), (-0.35, 0.05), (0.35, 0.05), (0.0, -0.45), (-0.6, -0.45), (0.6, -0.45)):
        b.sphere("Accent", tuple(_surf(shell_c, shell_s, (x, 0.7, z), 0.9)), 0.13, scale=(1, 0.8, 1))
    for side in (-1, 1):
        for z in (0.95, 1.4, 1.85, 2.25):
            p = _surf((0, 0.05, 1.33), (1.14, 0.85, 1.03), (side, 0.25, (z - 1.33) * 0.9), 0.95)
            b.cone("EyeWhite", tuple(p), (side, 0.35, 0.1), 0.13, 0.38, verts=12)
    _arms(b, 1.2)
    _legs(b, 1.2)
    _tail(b, 1.0, 1.0, club=True)


PLUSH_PLANS = {"flyer": plush_flyer, "bird": plush_bird, "theropod": plush_theropod, "ceratopsian": plush_ceratopsian, "sauropod": plush_sauropod,
               "stegosaur": plush_stegosaur, "ankylosaur": plush_ankylosaur}


def _pastel(hexs, k=0.18):
    r, g, bl = _hex(hexs)
    return "%02X%02X%02X" % tuple(int(255 * (c + (1 - c) * k)) for c in (r, g, bl))


def build_plush(species):
    s = SPECIES[species]
    b = Builder(species)
    b.smooth_pass = True
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


def _ink_material():
    """Outline shader for an inverted hull that works in Cycles: transparent where the hull faces
    the camera, dark ink only around the silhouette."""
    m = bpy.data.materials.get("PL_Ink2")
    if m:
        return m
    m = bpy.data.materials.new("PL_Ink2")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    mix = nt.nodes.new("ShaderNodeMixShader")
    geo = nt.nodes.new("ShaderNodeNewGeometry")
    emit = nt.nodes.new("ShaderNodeEmission")
    emit.inputs["Color"].default_value = (0.03, 0.025, 0.04, 1)
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    # Ink only for camera rays (so the shell never shadows the dino), and only where it faces away.
    lp = nt.nodes.new("ShaderNodeLightPath")
    inv = nt.nodes.new("ShaderNodeMath")
    inv.operation = "SUBTRACT"
    inv.inputs[0].default_value = 1.0
    nt.links.new(lp.outputs["Is Camera Ray"], inv.inputs[1])
    mx = nt.nodes.new("ShaderNodeMath")
    mx.operation = "MAXIMUM"
    nt.links.new(geo.outputs["Backfacing"], mx.inputs[0])
    nt.links.new(inv.outputs[0], mx.inputs[1])
    nt.links.new(mx.outputs[0], mix.inputs[0])
    nt.links.new(emit.outputs[0], mix.inputs[1])
    nt.links.new(tr.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    return m


def render_plush_portrait(species, out_dir, size=512, samples=48):
    """Index-card portrait: Cycles, soft three-light studio, fuzzy sheen, contact shadow, thin ink line."""
    coll = bpy.data.collections[species]
    scene = bpy.context.scene
    saved = {"engine": scene.render.engine, "lights": {}}
    for c in bpy.data.collections:
        c.hide_render = c != coll
    for o in scene.objects:
        if o.type == "LIGHT":
            saved["lights"][o.name] = o.hide_render
            o.hide_render = True
    pts = [o.matrix_world @ Vector(cn) for o in coll.objects for cn in o.bound_box]
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    centre = (mn + mx) / 2
    span = (mx - mn).length
    made = []

    def light(name, kind, loc, energy, colour, size_):
        data = bpy.data.lights.new(name, kind)
        data.energy = energy
        data.color = colour
        if kind == "AREA":
            data.size = size_
        o = bpy.data.objects.new(name, data)
        scene.collection.objects.link(o)
        o.location = loc
        o.rotation_euler = (centre - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        made.append(o)

    k = span * span
    light("PL_Key", "AREA", centre + Vector((-1.2, -1.6, 1.4)) * span * 0.9, 260 * k, (1.0, 0.95, 0.88), span * 0.9)
    light("PL_Fill", "AREA", centre + Vector((1.6, -1.0, 0.3)) * span * 0.9, 85 * k, (0.85, 0.92, 1.0), span * 1.2)
    light("PL_Rim", "AREA", centre + Vector((0.6, 1.6, 1.3)) * span * 0.9, 170 * k, (1.0, 1.0, 1.0), span * 0.6)
    # Soft white ambient from the world (restored afterwards).
    bg = next((n for n in scene.world.node_tree.nodes if n.type == "BACKGROUND"), None) if scene.world and scene.world.use_nodes else None
    if bg:
        saved["bg"] = (tuple(bg.inputs[0].default_value), bg.inputs[1].default_value)
        bg.inputs[0].default_value = (1, 1, 1, 1)
        bg.inputs[1].default_value = 0.22
    # Soft contact shadow on an invisible floor.
    bpy.ops.mesh.primitive_plane_add(size=span * 4, location=(centre.x, centre.y, mn.z))
    floor = bpy.context.active_object
    floor.is_shadow_catcher = True
    made.append(floor)
    # Thin ink outline (inverted hull).
    ink = _ink_material()
    hulls = []
    for o in coll.objects:
        if o.type != "MESH" or o.name.startswith("Joint"):
            continue
        o.data.materials.append(ink)
        sol = o.modifiers.new("PL_Outline", "SOLIDIFY")
        sol.thickness = span * 0.006
        sol.offset = 1.0
        sol.use_flip_normals = True
        sol.use_rim = False
        sol.material_offset = len(o.data.materials) - 1
        hulls.append(o)
    cam = bpy.data.objects["Camera"]
    look = centre + Vector((0, 0, (mx.z - mn.z) * 0.08))
    cam.location = look + Vector((-0.62, -1.0, 0.3)).normalized() * span * 1.2
    cam.rotation_euler = (look - cam.location).to_track_quat("-Z", "Y").to_euler()
    saved["view"] = (scene.view_settings.view_transform, scene.view_settings.look)
    scene.view_settings.view_transform = "AgX"        # AgX keeps highlights soft; Punchy keeps pastels saturated
    scene.view_settings.look = "AgX - Punchy"
    scene.render.engine = "CYCLES"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    scene.render.film_transparent = True
    scene.render.resolution_x = scene.render.resolution_y = size
    scene.render.filepath = os.path.join(out_dir, f"{species}.png")
    bpy.ops.render.render(write_still=True)
    # Restore the scene.
    for o in hulls:
        o.modifiers.remove(o.modifiers["PL_Outline"])
        o.data.materials.pop(index=len(o.data.materials) - 1)
    for o in made:
        data = o.data
        bpy.data.objects.remove(o, do_unlink=True)
        if isinstance(data, bpy.types.Light):
            bpy.data.lights.remove(data)
        elif data is not None and data.users == 0:
            bpy.data.meshes.remove(data)
    for name, hidden in saved["lights"].items():
        if name in bpy.data.objects:
            bpy.data.objects[name].hide_render = hidden
    for c in bpy.data.collections:
        c.hide_render = False
    if bg and "bg" in saved:
        bg.inputs[0].default_value, bg.inputs[1].default_value = saved["bg"]
    scene.view_settings.view_transform, scene.view_settings.look = saved["view"]
    scene.render.engine = saved["engine"]
    return scene.render.filepath
