"""
SlingshotForDinosaurs: plush biome critters (non-dino wildlife that roams the canyon floor).

Same soft-toy language as plush.py (bead eyes, blush, rounded everything) but on four legs:
    Mammoth     Ice Age     shaggy fur, curling trunk, big curved tusks
    SabreTooth  Tar Pits    stocky cat, two long sabre fangs, bob tail
    SeaTurtle   Coral Coast domed shell with soft plates, paddle flippers
    Dragonfly   Swamp       giant Meganeura: long body, huge eyes, four clear wings

Regions as the dinos (Body / Belly / Accent / EyeWhite / Pupil / Blush / Leg*), head and tail split
with Joint_* markers so the game can graze, look around and swish. Dragonfly wings are WingL / WingR
(the game flaps them). Coloured in game from Config/CritterConfig.luau.

Usage (Blender MCP, after dino_v2.py and plush.py):
    exec(open(r"<repo>/Assets/Blender/scripts/critters.py").read())
    build_critter("Mammoth"); export("Mammoth", out_dir)
"""

import math

from mathutils import Vector


def _quad_legs(b, xs, yf, yb, h, r, foot=True):
    """Four soft pillar legs: LegFL / LegFR at y = yf, LegBL / LegBR at y = yb."""
    for name, x, y in (("LegFL", -xs, yf), ("LegFR", xs, yf), ("LegBL", -xs, yb), ("LegBR", xs, yb)):
        b.ball(name, (x, y, h * 0.55), (r, r, h * 0.55))
        if foot:
            b.ball(name, (x, y - r * 0.15, r * 0.45), (r * 1.12, r * 1.2, r * 0.45))
            for dx in (-0.45, 0.0, 0.45):      # toe pads
                b.ball(name, (x + dx * r, y - r * 1.05, r * 0.28), (r * 0.26, r * 0.22, r * 0.22))


def critter_mammoth(b):
    body_c, body_s = Vector((0, 0.2, 2.0)), (1.25, 1.75, 1.2)
    b.ball("Body", tuple(body_c), body_s)
    b.ball("Body", (0, -0.7, 2.45), (1.05, 0.9, 1.0))            # high shoulder hump
    # Shaggy fur: one dark woolly coat capping the back and hump, with a shaggy skirt down each flank
    # (separate tufts read as discs; one fused coat reads as fur).
    b.ball("Accent", (0, 0.25, 2.45), (1.28, 1.72, 0.95))
    b.ball("Accent", (0, -0.7, 2.75), (1.08, 0.88, 0.85))
    for x in (-1, 1):
        b.ball("Accent", (x * 0.95, 0.15, 1.55), (0.42, 1.65, 0.62))
        for k in range(6):                                        # wavy hem of tufts under the skirt
            b.ball("Accent", (x * 1.0, -1.0 + 0.45 * k, 1.0), (0.3, 0.26, 0.34))
    _quad_legs(b, 0.72, -0.85, 1.1, 1.25, 0.46)
    # Head: round, with a fur topknot, little ears, trunk and tusks.
    b.joint("Head", (0, -1.1, 2.55))
    b.group = "Head"
    H = Vector((0, -1.75, 2.55))
    cs = (0.95, 0.85, 0.95)
    b.ball("Body", tuple(H), cs)
    b.ball("Accent", tuple(H + Vector((0, 0.15, 0.85))), (0.55, 0.5, 0.42))   # woolly topknot
    for side in (-1, 1):                                          # round floppy ears
        b.plate("Body", tuple(H + Vector((side * 0.9, 0.3, 0.0))), (0.14, 0.6, 0.66), rot=(0, side * -12, side * 22))
        b.plate("Blush", tuple(H + Vector((side * 0.84, 0.18, 0.0))), (0.06, 0.4, 0.45), rot=(0, side * -12, side * 22))
    # Trunk: down from the face, then a cheerful J-curl forward and up at the tip.
    t0 = _surf(H, cs, (0, -1, -0.35), 0.8)
    b.chain("Body", [tuple(t0 + Vector(d)) for d in ((0, 0, 0), (0, -0.3, -0.65), (0, -0.5, -1.2), (0, -0.85, -1.4), (0, -1.15, -1.15))],
            [0.34, 0.28, 0.23, 0.2, 0.18])
    # Tusks: thick cream curves sweeping down, forward and up.
    for side in (-1, 1):
        p0 = _surf(H, cs, (side * 0.42, -0.85, -0.55), 0.85)
        pts = [p0, p0 + Vector((side * 0.2, -0.45, -0.55)), p0 + Vector((side * 0.32, -1.05, -0.65)), p0 + Vector((side * 0.3, -1.5, -0.25))]
        b.chain("EyeWhite", [tuple(p) for p in pts], [0.17, 0.15, 0.12, 0.08])
    _face(b, H, cs, 1.0, eye=0.12)
    b.group = None
    # Short tail with a fur tuft.
    b.joint("Tail", (0, 1.85, 2.2))
    b.group = "Tail"
    b.chain("Body", [(0, 1.85, 2.2), (0, 2.15, 1.75), (0, 2.25, 1.35)], [0.17, 0.13, 0.1])
    b.ball("Accent", (0, 2.28, 1.15), (0.2, 0.2, 0.26))
    b.group = None


def critter_sabretooth(b):
    body_c, body_s = Vector((0, 0.15, 1.45)), (0.82, 1.35, 0.75)
    b.ball("Body", tuple(body_c), body_s)
    b.ball("Body", (0, -0.65, 1.7), (0.85, 0.75, 0.8))              # strong shoulders
    b.ball("Belly", (0, -0.55, 1.25), (0.6, 0.7, 0.55))             # pale chest
    for (x, y, z) in ((-0.75, -0.1, 0.35), (0.75, 0.2, 0.3), (-0.65, 0.7, 0.2), (0.6, -0.55, 0.45), (0.0, 0.3, 1.0), (-0.3, 0.9, 0.9)):
        _patch(b, "Accent", tuple(body_c), body_s, (x, y, z), 0.17)  # soft spots
    _quad_legs(b, 0.55, -0.7, 0.85, 1.05, 0.33)
    b.joint("Head", (0, -1.0, 1.95))
    b.joint("Jaw", (0, -1.55, 1.75))
    b.group = "Head"
    H = Vector((0, -1.45, 2.15))
    cs = (0.8, 0.72, 0.7)
    b.ball("Body", tuple(H), cs)
    muz = H + Vector((0, -0.62, -0.22))
    ms = (0.48, 0.36, 0.3)
    b.ball("Belly", tuple(muz), ms)
    b.sphere("Pupil", tuple(_surf(muz, ms, (0, -0.8, 0.6), 0.95)), 0.1, scale=(1.3, 1, 0.8))    # nose
    for side in (-1, 1):
        b.cone("Body", tuple(_surf(H, cs, (side * 0.55, 0.1, 0.85), 0.85)), (side * 0.35, 0.1, 1), 0.2, 0.42, verts=10)     # ears
        b.sphere("Blush", tuple(_surf(H, cs, (side * 0.55, 0.05, 0.85), 0.93) + Vector((0, -0.05, 0.12))), 0.1, scale=(1, 0.5, 1.2))
        # The sabres: long soft fangs hanging well below the chin.
        b.cone("EyeWhite", tuple(_surf(muz, ms, (side * 0.4, -0.85, -0.4), 0.9)), (side * 0.05, -0.25, -1), 0.085, 0.72, verts=10)
    _face(b, H, cs, 0.95, eye=0.13)
    b.group = "Jaw"
    b.ball("Belly", tuple(H + Vector((0, -0.48, -0.5))), (0.36, 0.3, 0.16))
    b.group = None
    b.joint("Tail", (0, 1.45, 1.75))
    b.group = "Tail"
    b.chain("Body", [(0, 1.45, 1.75), (0, 1.75, 1.85)], [0.16, 0.13])   # bob tail
    b.ball("Accent", (0, 1.88, 1.9), (0.15, 0.15, 0.15))
    b.group = None


def critter_seaturtle(b):
    shell_c, shell_s = Vector((0, 0.1, 0.95)), (1.3, 1.6, 0.68)
    b.ball("Body", (0, 0.1, 0.62), (1.15, 1.45, 0.42))              # soft underbody
    b.ball("Accent", tuple(shell_c), shell_s)                        # domed shell
    # Soft plates on the shell (a ring round a centre row), in the belly colour.
    for (x, y) in ((0, -0.75), (0, 0.0), (0, 0.75), (-0.8, -0.4), (0.8, -0.4), (-0.85, 0.4), (0.85, 0.4)):
        _patch(b, "Body", tuple(shell_c), shell_s, (x, y, 0.55), 0.24)
    b.ball("Belly", (0, 0.1, 0.5), (1.05, 1.35, 0.2))                # pale plastron rim
    # Flippers: big front paddles, small back ones (legs, so the game paddles them).
    for name, x, y, sz, ang in (("LegFL", -1.15, -0.75, (1.0, 0.42, 0.14), 28), ("LegFR", 1.15, -0.75, (1.0, 0.42, 0.14), -28),
                                ("LegBL", -0.9, 1.2, (0.55, 0.32, 0.12), -25), ("LegBR", 0.9, 1.2, (0.55, 0.32, 0.12), 25)):
        b.ball(name, (x, y, 0.45), sz, rot=(0, 0, ang))
    b.joint("Head", (0, -1.4, 0.85))
    b.group = "Head"
    b.chain("Body", [(0, -1.35, 0.8), (0, -1.75, 0.95)], [0.36, 0.34])
    H = Vector((0, -2.05, 1.1))
    cs = (0.52, 0.58, 0.48)
    b.ball("Body", tuple(H), cs)
    _face(b, H, cs, 0.62, eye=0.15)
    b.group = None
    b.joint("Tail", (0, 1.6, 0.7))
    b.group = "Tail"
    b.cone("Body", (0, 1.55, 0.7), (0, 1, -0.2), 0.18, 0.45, verts=10)
    b.group = None


def critter_dragonfly(b):
    # Long and thin, so it reads from far away: thorax, a long segmented abdomen, a head of eyes.
    b.ball("Body", (0, 0.0, 1.0), (0.32, 0.45, 0.3))                 # thorax
    b.chain("Body", [(0, 0.35, 1.0), (0, 1.4, 0.98), (0, 2.6, 0.92)], [0.17, 0.13, 0.09])
    for k in range(5):                                               # accent bands down the abdomen
        b.ball("Accent", (0, 0.65 + 0.42 * k, 0.99 - 0.015 * k), (0.15 - 0.012 * k, 0.07, 0.15 - 0.012 * k))
    b.joint("Head", (0, -0.35, 1.0))
    b.group = "Head"
    H = Vector((0, -0.6, 1.05))
    b.ball("Body", tuple(H), (0.3, 0.25, 0.26))
    for side in (-1, 1):                                             # huge compound eyes
        b.sphere("Pupil", tuple(H + Vector((side * 0.22, -0.06, 0.08))), 0.17)
        b.sphere("EyeWhite", tuple(H + Vector((side * 0.27, -0.17, 0.17))), 0.05)
        b.sphere("Blush", tuple(H + Vector((side * 0.17, -0.25, -0.1))), 0.05, scale=(1, 0.6, 0.8))
    b.group = None
    # Four clear wings, pivoting where they meet the thorax (the game flaps WingL / WingR).
    for side, name in ((-1, "WingL"), (1, "WingR")):
        for k, (y, length) in enumerate(((-0.12, 1.55), (0.18, 1.4))):
            b.plate(name, (side * (0.25 + length / 2), y, 1.22), (length / 2, 0.24, 0.025), rot=(0, 0, side * (8 if k == 0 else -8)))
    b.joint("Wings", (0, 0, 1.22))
    # Six little legs tucked under.
    for side in (-1, 1):
        for y in (-0.15, 0.05, 0.25):
            b.cone("Body", (side * 0.15, y, 0.8), (side * 0.6, -0.2, -1), 0.03, 0.35, verts=6)


CRITTERS = {
    "Mammoth": dict(plan=critter_mammoth, body="9A6A44", belly="E8D3B8", accent="5A3A24"),
    "SabreTooth": dict(plan=critter_sabretooth, body="E2A55A", belly="FFF0D8", accent="9A5A2A"),
    "SeaTurtle": dict(plan=critter_seaturtle, body="7FCF8A", belly="F6E8B0", accent="3E9A6A"),
    "Dragonfly": dict(plan=critter_dragonfly, body="3FA9E8", belly="E8F6FF", accent="1E5FA8"),
}


def build_critter(name):
    s = CRITTERS[name]
    b = Builder(name)
    b.smooth_pass = True
    b.eyewhite_budget = 400
    b.accent_budget = 1400
    s["plan"](b)
    objs = b.finish()
    cols = {"Body": _pastel(s["body"]), "Belly": _pastel(s["belly"], 0.1), "Accent": _pastel(s["accent"], 0.12),
            "EyeWhite": "FFF8E8", "Pupil": "17131C", "Blush": "FF9DB4", "Wing": "D8F4FF"}
    for region, o in objs.items():
        base = region.partition("_")[0]
        key = "Wing" if base.startswith("Wing") else ("Body" if base.startswith("Leg") else base)
        rgb = _hex(cols.get(key, cols["Body"]))
        mat = bpy.data.materials.get(f"CR_{name}_{key}") or bpy.data.materials.new(f"CR_{name}_{key}")
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = (*(c ** 2.2 for c in rgb), 1)
        bsdf.inputs["Roughness"].default_value = 0.15 if key in ("Pupil", "EyeWhite", "Wing") else 0.9
        if key == "Wing":
            bsdf.inputs["Alpha"].default_value = 0.45
        o.data.materials.clear()
        o.data.materials.append(mat)
    return objs
