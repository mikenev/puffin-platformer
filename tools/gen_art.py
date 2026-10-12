#!/usr/bin/env python3
"""Procedurally generates original Milestone 2 pixel art (puffin sheet, coastal tileset, preview).
Run from repo root: python3 tools/gen_art.py   (needs Pillow). All art is original."""
import random
from PIL import Image, ImageDraw

PAL = {
    "o": (22, 20, 38), "K": (46, 42, 66), "k": (84, 80, 112), "W": (244, 240, 226),
    "w": (186, 186, 204), "G": (150, 150, 176), "E": (10, 8, 18), "Y": (252, 206, 64),
    "O": (238, 112, 34), "R": (196, 44, 52), "F": (248, 124, 44), "f": (176, 70, 34),
}
# Tile palette (shares outline/whites with the puffin for cohesion)
T = {
    "gl": (128, 208, 72), "g": (72, 164, 56), "gd": (36, 108, 52), "go": (22, 64, 40),
    "dl": (176, 120, 72), "d": (138, 88, 54), "dd": (96, 58, 42), "do": (58, 34, 34),
    "st": (150, 140, 150), "sl": (196, 188, 196),
    "sa": (240, 214, 140), "sd": (206, 172, 100), "sh": (252, 238, 188),
    "wl": (130, 210, 240), "w": (52, 140, 210), "wd": (34, 92, 168), "wf": (236, 248, 252),
    "pk": (232, 112, 140), "yw": (252, 216, 72),
    "wo": (140, 96, 60), "wol": (186, 138, 86), "wod": (92, 60, 42),
}
IDLE = [
    "................",
    "................",
    "................",
    "....ooooo.......",
    "...oKKKKKo......",
    "..oKWWWWWKo.....",
    "..oKWGEWWWYOo...",
    "..oKWWGWWROOOo..",
    "..oKKWWWWRRoo...",
    "..oKKKWWWKo.....",
    ".okkKKWWWWKo....",
    ".okkKWWWWWWo....",
    ".okKKWWWWwKo....",
    "..oKKwWWwwKo....",
    "...ooKKKKoo.....",
    "....FF..FF......",
]

def grid(rows): return [list(r) for r in rows]
def body(g): return g[:15]
def with_feet(g, feet):
    g = [r[:] for r in g]; g[15] = list(feet.ljust(16, ".")); return g
def shift(g, dy, dx=0, rows=range(0, 15)):
    out = [r[:] for r in g]
    for y in rows: out[y] = ["."] * 16
    for y in rows:
        for x in range(16):
            sy, sx = y - dy, x - dx
            if sy in rows and 0 <= sx < 16: out[y][x] = g[sy][sx]
    return out
def put(g, pts):
    g = [r[:] for r in g]
    for x, y, c in pts: g[y][x] = c
    return g

base = grid(IDLE)
blink = put(base, [(6, 6, "o"), (5, 6, "W")])
idle = [base, base, shift(base, 1, rows=range(0, 15)), base, blink, base]
# run: body bob + alternating feet + wing swing
wing_up = put(base, [(1, 10, "o"), (1, 11, "k"), (0, 10, "o"), (0, 9, "o"), (1, 9, "k")])
run = [
    with_feet(shift(base, 0), "...FF....FF"),
    with_feet(shift(wing_up, 1), ".....FFF"),
    with_feet(shift(base, 0), "..FF......FF"),
    with_feet(shift(wing_up, 1), "....FFf"),
]
run[1][14] = list("...ooKKKKoo.....") if False else run[1][14]
# skid: lean back (top shifted left), feet braced forward
sk = shift(base, 0, -1, rows=range(3, 10))
sk = put(sk, [(0, 9, "o"), (0, 10, "o"), (1, 9, "k")])
skid = [with_feet(sk, "......FFFf"), with_feet(sk, ".....FFFf")]
# jump: wings raised, feet tucked
jp = put(base, [(0, 7, "o"), (1, 7, "k"), (1, 8, "k"), (0, 8, "o"), (1, 6, "o"), (1, 10, "K"), (1, 11, "K")])
jump = [with_feet(shift(jp, -1), "....FfFf"), with_feet(shift(jp, -1), "....fF.Ff")]
# fall: wings flared down/out, feet dangling
fl = put(base, [(0, 11, "o"), (0, 12, "o"), (1, 12, "k"), (1, 13, "o"), (12, 10, "o"), (12, 11, "o"), (11, 11, "k")])
fall = [with_feet(fl, "....F..F"), with_feet(fl, "...F....F")]
# death: X eyes, wings up, then tumble
dz = put(base, [(5, 5, "E"), (7, 5, "E"), (6, 6, "E"), (5, 7, "E"), (7, 7, "E"), (6, 5, "W"), (6, 7, "W"), (5, 6, "W"), (7, 6, "W")])
dz = put(dz, [(0, 7, "o"), (1, 7, "k"), (0, 8, "o"), (12, 9, "o"), (12, 8, "o")])
dz = with_feet(dz, "....F...F")
def rot90(g): return [[g[15 - x][y] for x in range(16)] for y in range(16)]
death = [dz, dz, rot90(dz), rot90(rot90(dz)), rot90(rot90(rot90(dz))), rot90(rot90(dz))]

ANIMS = [("idle", idle, 6, True), ("run", run, 10, True), ("skid", skid, 8, True),
         ("jump", jump, 8, False), ("fall", fall, 8, True), ("death", death, 8, False)]

def render(g):
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    for y in range(16):
        for x in range(16):
            c = g[y][x]
            if c != ".": im.putpixel((x, y), PAL[c] + (255,))
    return im

def puffin_sheet():
    cols = max(len(a[1]) for a in ANIMS)
    sheet = Image.new("RGBA", (cols * 16, len(ANIMS) * 16), (0, 0, 0, 0))
    for r, (_, frames, _, _) in enumerate(ANIMS):
        for c, f in enumerate(frames): sheet.paste(render(f), (c * 16, r * 16))
    return sheet

# ---------------- tiles (16x16, 8 cols x 4 rows) ----------------
TILE_NAMES = [
    ["grass_tl", "grass_t", "grass_tr", "grass_single", "plat_l", "plat_m", "plat_r", "plat_single"],
    ["dirt_l", "dirt", "dirt_r", "dirt_stones", "inner_tl", "inner_tr", "dirt_bl", "dirt_br"],
    ["dirt_b", "grass_col", "grass_col_b", "sand_t", "sand", "water_top", "water", "sand_shore"],
    ["flower", "tuft", "rock", "shell", "bush_l", "bush_r", "driftwood", "post"],
]

def tile(name, seed):
    rnd = random.Random(seed)
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0)); px = im.load()
    def P(x, y, c):
        if 0 <= x < 16 and 0 <= y < 16: px[x, y] = T[c] + (255,)
    def dirt(x0=0, x1=16, y0=0, y1=16):
        for y in range(y0, y1):
            for x in range(x0, x1):
                P(x, y, "d")
        for _ in range(10):
            x, y = rnd.randrange(x0, x1), rnd.randrange(y0, y1)
            P(x, y, "dd"); P(x + 1, y, "dd") if x + 1 < x1 else None
        for _ in range(5):
            P(rnd.randrange(x0, x1), rnd.randrange(y0, y1), "dl")
    def grass_top(left, right):
        for x in range(16):
            P(x, 0, "go"); P(x, 1, "gl"); P(x, 2, "g"); P(x, 3, "g"); P(x, 4, "gd")
            if (x * 7 + seed) % 3 == 0: P(x, 5, "gd")
            if x % 4 == 1: P(x, 1, "g")
        for x in range(0, 16, 5): P(x + 2, 2, "gl")
        if left:
            for y in range(1, 6): P(0, y, "go")
            P(1, 1, "go"); P(0, 0, "do") if False else None; px[0, 0] = (0, 0, 0, 0)
        if right:
            for y in range(1, 6): P(15, y, "go")
            P(14, 1, "go"); px[15, 0] = (0, 0, 0, 0)
    def side(left, right, y0=0, y1=16):
        for y in range(y0, y1):
            if left: P(0, y, "do"); P(1, y, "dd")
            if right: P(15, y, "do"); P(14, y, "dd")
    def bottom():
        for x in range(16): P(x, 15, "do"); P(x, 14, "dd")
    n = name
    if n.startswith("grass") and n not in ("grass_col", "grass_col_b"):
        dirt(); L = n in ("grass_tl", "grass_single"); R = n in ("grass_tr", "grass_single")
        side(L, R, 5); grass_top(L, R)
    elif n == "grass_col":
        dirt(); side(True, True, 5); grass_top(True, True)
    elif n == "grass_col_b":
        dirt(); side(True, True); bottom(); px[0, 15] = px[15, 15] = (0, 0, 0, 0)
    elif n.startswith("plat"):
        for x in range(16):
            P(x, 0, "wod"); P(x, 1, "wol"); P(x, 2, "wo"); P(x, 3, "wo"); P(x, 4, "wo"); P(x, 5, "wod")
            if x % 8 == 7: [P(x, y, "wod") for y in range(1, 5)]
        P(3, 3, "wod"); P(11, 2, "wod")
        if n in ("plat_l", "plat_single"):
            for y in range(6): P(0, y, "wod")
            P(3, 6, "wod"); P(3, 7, "wod"); P(4, 6, "wod")
        if n in ("plat_r", "plat_single"):
            for y in range(6): P(15, y, "wod")
            P(12, 6, "wod"); P(12, 7, "wod"); P(11, 6, "wod")
    elif n == "dirt": dirt()
    elif n == "dirt_stones":
        dirt()
        for cx, cy in ((4, 5), (11, 11)):
            for dx in range(-2, 2):
                for dy in range(-1, 2): P(cx + dx, cy + dy, "st")
            P(cx - 1, cy - 1, "sl"); P(cx, cy - 1, "sl"); P(cx + 1, cy + 1, "do")
    elif n in ("dirt_l", "dirt_r"): dirt(); side(n == "dirt_l", n == "dirt_r")
    elif n in ("dirt_bl", "dirt_br", "dirt_b"):
        dirt(); bottom(); side(n == "dirt_bl", n == "dirt_br")
        if n == "dirt_bl": px[0, 15] = (0, 0, 0, 0)
        if n == "dirt_br": px[15, 15] = (0, 0, 0, 0)
    elif n in ("inner_tl", "inner_tr"):
        dirt()
        for y in range(6):
            x = 15 - y if n == "inner_tl" else y
            P(x, 0, "gd")
        P(15 if n == "inner_tl" else 0, 0, "g"); P(15 if n == "inner_tl" else 0, 1, "gd")
    elif n in ("sand_t", "sand", "sand_shore"):
        for y in range(16):
            for x in range(16): P(x, y, "sa")
        for _ in range(14): P(rnd.randrange(16), rnd.randrange(16), "sd")
        for _ in range(6): P(rnd.randrange(16), rnd.randrange(16), "sh")
        if n != "sand":
            for x in range(16): P(x, 0, "sd"); P(x, 1, "sh")
        if n == "sand_shore":
            for y in range(8, 16):
                for x in range(16 - (y - 8) * 2, 16): P(x, y, "w")
            for y in range(8, 16): P(16 - (y - 8) * 2, y, "wf")
    elif n in ("water_top", "water"):
        for y in range(16):
            for x in range(16): P(x, y, "w" if y < 9 else "wd")
        for _ in range(4):
            x, y = rnd.randrange(14), rnd.randrange(4, 15); P(x, y, "wl"); P(x + 1, y, "wl")
        if n == "water_top":
            for x in range(16):
                P(x, 0, "wf" if x % 8 in (0, 1, 2) else "wl"); P(x, 1, "wl" if x % 8 in (3, 4) else "w")
            for x in range(16): px[x, 0] = px[x, 0] if x % 8 != 7 else (0, 0, 0, 0)
    elif n == "flower":
        for y in range(9, 16): P(7, y, "gd")
        P(6, 12, "g"); P(5, 11, "g"); P(8, 13, "g"); P(9, 12, "g")
        for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1)): P(7 + dx, 7 + dy, "pk")
        P(7, 7, "yw")
    elif n == "tuft":
        for x, h in ((3, 4), (5, 7), (7, 5), (9, 8), (11, 4), (12, 6)):
            for y in range(16 - h, 16): P(x, y, "g" if y > 16 - h else "gl")
            P(x, 15, "gd")
    elif n == "rock":
        for y in range(9, 16):
            w = min(y - 8, 5)
            for x in range(8 - w - 1, 8 + w): P(x, y, "st")
        for x in range(4, 10): P(x, 10, "sl")
        for y in range(10, 16): P(13, y, "o") if False else None
        for x in range(2, 14): P(x, 15, "do")
    elif n == "shell":
        for y in range(11, 16):
            for x in range(5, 11):
                if abs(x - 7.5) <= (y - 10): P(x, y, "pk" if (x + y) % 2 else "sh")
        for x in range(5, 11): P(x, 15, "sd")
    elif n in ("bush_l", "bush_r"):
        for y in range(5, 16):
            for x in range(16):
                cx = 15 if n == "bush_l" else 0
                if (x - cx) ** 2 / 196 + (y - 15) ** 2 / 100 <= 1:
                    P(x, y, "g" if (y > 8 and (x + y) % 5) else "gl")
                    if y > 12: P(x, y, "gd")
    elif n == "driftwood":
        for x in range(1, 15): P(x, 12, "wol"); P(x, 13, "wo"); P(x, 14, "wod")
        P(4, 11, "wo"); P(3, 10, "wo"); P(12, 13, "wod")
    elif n == "post":
        for y in range(2, 16):
            for x in range(6, 10): P(x, y, "wo")
            P(6, y, "wol"); P(9, y, "wod")
        for x in range(5, 11): P(x, 2, "wod")
        P(7, 6, "wod"); P(8, 10, "wod")
    return im

SOLID = {"grass_tl", "grass_t", "grass_tr", "grass_single", "dirt_l", "dirt", "dirt_r", "dirt_stones",
         "inner_tl", "inner_tr", "dirt_bl", "dirt_br", "dirt_b", "grass_col", "grass_col_b",
         "sand_t", "sand", "sand_shore"}
ONE_WAY = {"plat_l", "plat_m", "plat_r", "plat_single"}

def tilesheet():
    im = Image.new("RGBA", (128, 64), (0, 0, 0, 0))
    for r, row in enumerate(TILE_NAMES):
        for c, n in enumerate(row): im.paste(tile(n, r * 8 + c), (c * 16, r * 16))
    return im

def mock_level(ts, ps):
    W, H = 256, 224
    im = Image.new("RGBA", (W, H))
    d = ImageDraw.Draw(im)
    sky = [(108, 174, 238), (126, 188, 242), (150, 204, 246), (176, 220, 250)]
    for i, c in enumerate(sky): d.rectangle([0, i * 30, W, H], fill=c)
    for cx, cy in ((40, 30), (170, 22), (220, 50)):  # clouds
        for dx, r in ((0, 8), (10, 11), (22, 7)): d.ellipse([cx + dx - r, cy - r, cx + dx + r, cy + r // 2 + 3], fill=(250, 250, 252))
    d.polygon([(0, 150), (40, 118), (90, 140), (140, 110), (200, 138), (256, 120), (256, 176), (0, 176)], fill=(110, 160, 170))
    def t(name):
        for r, row in enumerate(TILE_NAMES):
            if name in row: c = row.index(name); return ts.crop((c * 16, r * 16, c * 16 + 16, r * 16 + 16))
    lv = [
        "................",
        "................",
        "................",
        "................",
        "................",
        "................",
        ".........<-->...",
        "................",
        "....[^]..........",
        "....(|)...f......",
        "{^^^LdJ^^^^}t.r..",
        "(dsddddddddd)TTTT",
        "(ddddddsdddd)SSS~",
        "[bbbbbbbbbbb]~~~~",
    ]
    M = {"{": "grass_tl", "^": "grass_t", "}": "grass_tr", "(": "dirt_l", ")": "dirt_r", "d": "dirt", "s": "dirt_stones",
         "[": "grass_tl", "]": "grass_tr", "|": "dirt", "L": "inner_tl", "J": "inner_tr", "b": "dirt_b",
         "<": "plat_l", "-": "plat_m", ">": "plat_r", "f": "flower", "t": "tuft", "r": "rock",
         "T": "sand_t", "S": "sand", "~": "water", "w": "water_top"}
    lv[13] = "<" and "[" + "b" * 11 + "]" + "wwww"
    lv[13] = "(" + "b" * 11 + ")" + "~~~~"
    for y, row in enumerate(lv):
        for x, ch in enumerate(row[:16]):
            if ch in M: im.alpha_composite(t(M[ch]), (x * 16, y * 16))
    # fix corners on the cliff bottom row
    im.alpha_composite(t("dirt_bl"), (0, 13 * 16)); im.alpha_composite(t("dirt_br"), (12 * 16, 13 * 16))
    for x in range(13, 16): im.alpha_composite(t("water_top"), (x * 16, 12 * 16))
    im.alpha_composite(t("sand_shore"), (15 * 16, 11 * 16))
    im.alpha_composite(t("bush_l"), (1 * 16, 9 * 16)); im.alpha_composite(t("bush_r"), (2 * 16, 9 * 16))
    im.alpha_composite(t("shell"), (14 * 16, 10 * 16)); im.alpha_composite(t("post"), (9 * 16, 9 * 16))
    fr = lambda a, i: ps.crop((i * 16, a * 16, i * 16 + 16, a * 16 + 16))
    im.alpha_composite(fr(0, 0), (40, 144)); im.alpha_composite(fr(1, 1), (120, 144))
    im.alpha_composite(fr(3, 0), (160, 80)); im.alpha_composite(fr(4, 0), (200, 96))
    im.alpha_composite(fr(2, 0), (80, 112))
    return im

def preview(ts, ps):
    W = 256
    labels_h = len(ANIMS) * 20 + 8
    out = Image.new("RGBA", (W, 224 + labels_h + 72), (30, 28, 44, 255))
    d = ImageDraw.Draw(out)
    out.alpha_composite(mock_level(ts, ps), (0, 0))
    y = 228
    for r, (name, frames, fps, loop) in enumerate(ANIMS):
        d.text((2, y + 4), f"{name} {fps}fps{'' if loop else ' once'}", fill=(240, 240, 230))
        for c in range(len(frames)):
            d.rectangle([110 + c * 20 - 1, y - 1, 110 + c * 20 + 16, y + 16], fill=(70, 120, 170))
            out.alpha_composite(ps.crop((c * 16, r * 16, c * 16 + 16, r * 16 + 16)), (110 + c * 20, y))
        y += 20
    d.text((2, y + 2), "tileset (16x16):", fill=(240, 240, 230))
    d.rectangle([110 - 1, y - 1, 110 + 128, y + 64], fill=(70, 120, 170))
    out.alpha_composite(ts, (110, y))
    return out.resize((out.width * 4, out.height * 4), Image.NEAREST)

if __name__ == "__main__":
    import os
    os.makedirs("art/puffin", exist_ok=True); os.makedirs("art/tiles", exist_ok=True); os.makedirs("docs", exist_ok=True)
    ps, ts = puffin_sheet(), tilesheet()
    ps.save("art/puffin/puffin_sheet.png"); ts.save("art/tiles/coastal_tiles.png")
    pv = preview(ts, ps); pv.save("docs/art_preview_m2.png")
    with open("art/puffin/anims.txt", "w") as f:
        for n, fr, fps, loop in ANIMS: f.write(f"{n} {len(fr)} {fps} {int(loop)}\n")
    with open("art/tiles/tiles.txt", "w") as f:
        for r, row in enumerate(TILE_NAMES):
            for c, n in enumerate(row):
                f.write(f"{c} {r} {n} {'solid' if n in SOLID else 'oneway' if n in ONE_WAY else 'none'}\n")
    print("ok", ps.size, ts.size, pv.size)
