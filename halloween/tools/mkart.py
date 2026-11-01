#!/usr/bin/env python3
"""The Halloween edition's own pictures, drawn here in C64 colours:
halloween/assets/candy_sheet.png/.json and cells_sheet.png/.json, in the
layout of the CPC's sheets (tools/mkgfx64.py reads them through theme.py).

A pixel is a C64 colour (0-15) or 16, transparent. The C64's multicolour pixel
is twice as wide as it is tall, so a 12x24 cell shows as a square: a round
thing is 10 pixels across and 20 lines high.

A candy's characters along the edges of its cell (all but the middle one)
keep to two colours: a third goes in the colour RAM, and the slime of the
jelly under it would turn that colour.

Candies, in the game's colour order:
  red     a crystal ball (cyan:   orange  a jack-o'-lantern
          the C64's red and orange are too close for two candies)
  yellow  a candy corn            green   a witch's potion
  blue    a ghost                 purple  a bat
  striped (across, down): the same with stripes of white
  wrapped: in a twist of paper (the candy squashed between two bows)
  the colour bomb: a cauldron with bubbles of every colour
  ingredients: a skull (the cherry), a spider (the nut)

Cells: the board (black), its other square (with a few purple stars), a
hole (fog), slime for the jelly (one and two layers), a cobweb for the
icing (three layers, thinner each time), a tombstone for the chocolate, a
witch's spiral for the licorice.

  mkart.py [out dir]      (default: halloween/assets; also a preview, 4x)
"""
import json
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "tools"))
import c64palette as pal  # noqa: E402

T = 16
KEY = {'.': T, 'K': 0, 'W': 1, 'R': 2, 'C': 3, 'P': 4, 'G': 5, 'B': 6, 'Y': 7, 'O': 8,
       'N': 9, 'L': 10, 'D': 11, 'M': 12, 'g': 13, 'b': 14, 'l': 15}
W, H = 12, 24

CRYSTAL = """
............
............
............
...bbbbbb...
..bCCCCCCb..
.bCCCCCCCCb.
.bCCCCCCCCb.
bCCCCCCCCCCb
bCCCCWWCCCCb
bCCCCWCCCCbb
bCCCCWCCCCbb
bCCCCCCCCbbb
.bCCCCCCCbb.
.bbCCCCCbbb.
..bbbbbbbb..
...bbbbbb...
..NNNNNNNN..
.NYNNNNNNYN.
.NNNNNNNNNN.
............
............
............
............
............
"""

PUMPKIN = """
............
............
.....GG.....
......GG....
..OOONOOOO..
.OOOONOOOON.
OOOOONOOOONN
OOOOONOOOONN
OOYOONOOYONN
OYYYONOYYYNN
OOOOONOOOONN
OOOOOYOOOONN
OOOOONOOOONN
OYOOONOOOYNN
OYYYYYYYYYNN
OOYYKYYKYNNN
OOOOONOOOONN
OOOONOOONNNN
.OOONOOONNN.
..ONNONNNN..
...NNNNNN...
............
............
............
"""

CORN = """
............
............
.....WW.....
....WWWW....
....WWWW....
...WWWWWW...
...WWWWWW...
...OOOOOO...
..OOOOOOOO..
..OOOOOOOO..
..OOOOOOOO..
.YYYYYYYYYY.
.WYYYYYYYYY.
.WYYYYYYYYY.
YWYYYYYYYYYY
YYYYYYYYYYYY
YYYYYYYYYYYY
YYYYYYYYYYYY
YYYYYYYYYYYY
.YYYYYYYYYY.
..YYYYYYYY..
............
............
............
"""

POTION = """
............
............
....NNNN....
....NNNN....
.....ll.....
.....gl.....
....lggl....
...lgggl....
..lggggggl..
.lgWgggggGl.
lgWggggggGGl
lgWgggggGGGl
lgggggggGGGl
lggggggGGGGl
lggggggGGGGl
lgggggGGGGGl
.lggGGGGGGl.
..llGGGGll..
...llllll...
............
............
............
............
............
"""

GHOST = """
............
............
....WWWW....
...WWWWWWb..
..WWWWWWWWb.
.WWWWWWWWWb.
.WWKKWWKKWbb
.WWKKWWKKWbb
.WWKKWWKKWbb
.WWWWWWWWWbb
.WWWWKKWWWbb
WWWWKKKKWWbb
WWWWKKKKWWbb
WWWWWKKWWWbb
WWWWWWWWWbbb
WWWWWWWWWbbb
WWWWWWWWbbbb
WWWWWWWWbbbb
WWbWWWbWWbbb
Wb.bWb.bWbb.
b...b...b.b.
............
............
............
"""

BAT = """
............
............
............
............
...P....P...
...PP..PP...
...PPPPPP...
P..PYPPYP..P
PP.PPPPPP.PP
PPPPPWPWPPPP
PPPPPPPPPPPP
PPPPPPPPPPPP
PPPPPPPPPPPP
PDPPPPPPPPDP
PDDPPPPPPDDP
D.DDPPPPDD.D
...D.PP.D...
.....PP.....
............
............
............
............
............
............
"""

CAULDRON = """
............
............
..O...P..Y..
.....g...g..
..g.ggg.g...
..gggggggg..
.MMMMMMMMMM.
MllllllllllM
.MMMMMMMMMM.
.DMDDDDDDDD.
DMMDDDDDDDDD
DMDDDDDDDDDD
DMDDDDDDDDDD
DMDDDDDDDDDD
DDDDDDDDDDDD
DDDDDDDDDDDD
.DDDDDDDDDD.
..DDDDDDDD..
..D......D..
.DD......DD.
............
............
............
............
"""

SKULL = """
............
............
...WWWWWW...
..WWWWWWWWl.
.WWWWWWWWWll
.WWWWWWWWWll
.WWWWWWWWWll
.WKKKWWKKKll
.WKKKWWKKKll
.WKKKWWKKKll
.WWWWWWWWWll
.WWWWKKWWWll
..WWWKKWWll.
...WWWWWWl..
...WKWKWKl..
...WKWKWKl..
...WWWWWWl..
....llll....
............
............
............
............
............
............
"""

SPIDER = """
......M.....
......M.....
......M.....
......M.....
.....DDD....
....DDDDD...
.M..DRDRD..M
M.M.DDDDD.M.
...MDDDDDM..
MMM.MDDDM.MM
...MDDDDDM..
..MDDMMDDDM.
.M.DDDDDDD.M
M..DDDDDDD..
..MDDMMDDDM.
.M.DDDDDDD.M
M...DDDDD...
.....DDD....
............
............
............
............
............
............
"""


def grid(text):
    rows = [r for r in text.strip("\n").split("\n")]
    assert len(rows) == H and all(len(r) == W for r in rows), text
    return [[KEY[c] for c in r] for r in rows]


def striped(g, across, ink):
    """stripes of ink, two lines high (or a pixel wide) every four (three);
    over the shade a grey one"""
    out = [list(r) for r in g]
    for y in range(H):
        for x in range(W):
            c = g[y][x]
            if c in (T, 0):
                continue
            if (y // 2 % 2 if across else x % 3) == 1:
                out[y][x] = ink if c not in (2, 9, 5, 14, 11, 8) or ink != 1 else 12
    return out


def wrapped(g, base, shade):
    """the candy squashed to the middle lines, a twist of paper above and below"""
    rows = [r for r in g if any(c != T for c in r)]
    body = rows[::2]                                # half the height
    out = [[T] * W for _ in range(H)]
    top = (H - len(body)) // 2
    for k, r in enumerate(body):
        out[top + k] = list(r)
    bow = [(2, 9), (3, 8), (4, 7)]                  # widths from the outside in
    for k, (x0, x1) in enumerate(bow):
        for x in range(x0, x1 + 1):
            c = shade if x > (x0 + x1) // 2 else base
            if x == x0:
                c = 1
            out[top - 4 + k][x] = c
            out[top + len(body) + 3 - k][x] = c
    for x in (5, 6):
        out[top - 1][x] = base
        out[top + len(body)][x] = base
    return out


CANDIES = [(CRYSTAL, 3, 14), (PUMPKIN, 8, 9), (CORN, 7, 8), (POTION, 13, 5), (GHOST, 1, 14), (BAT, 4, 11)]
STRIPES = [1, 1, 1, 1, 11, 1]           # white, but dark grey on the ghost


def candy_frames():
    plain = [grid(t) for t, _, _ in CANDIES]
    frames = list(plain)
    frames += [striped(g, True, k) for g, k in zip(plain, STRIPES)]
    frames += [striped(g, False, k) for g, k in zip(plain, STRIPES)]
    frames += [wrapped(g, b, s) for g, (_, b, s) in zip(plain, CANDIES)]
    frames += [grid(CAULDRON), grid(SKULL), grid(SPIDER)]
    names = ["crystal", "pumpkin", "corn", "potion", "ghost", "bat"]
    return frames, [n for k in ("", "_striped_h", "_striped_v", "_wrapped") for n in
                    (f"{c}{k}" for c in names)] + ["cauldron", "skull", "spider"]


# --- the cells ---------------------------------------------------------------
def blank(c=0):
    return [[c] * W for _ in range(H)]


def board(stars=False):
    """no grid: a candy with three colours in a character takes the colour
    RAM, and a grid there would turn its colour; the squares are told apart
    by the stars of every other one"""
    g = blank()
    if stars:
        for x, y in ((2, 4), (8, 2), (9, 14), (3, 19), (6, 10), (10, 21)):
            g[y][x] = 4
    return g


def hole():
    return [[11 if (x + y // 2) % 2 == 0 and y % 2 == 0 else 0 for x in range(W)] for y in range(H)]


def slime(layers):
    g = board()
    c = 5 if layers == 1 else 13
    t = layers
    for y in range(H):
        for x in range(W):
            if x < t or x >= W - t or y < 2 * t or y >= H - 2 * t:
                g[y][x] = c
    for x, d in ((3, 3), (7, 5), (10, 2)):          # it drips
        for y in range(2 * t, 2 * t + d * layers):
            g[y][x] = c
    return g


def cobweb(strength):
    """radial threads and rings round the middle; fewer the weaker it is"""
    import math
    c = {3: 15, 2: 12, 1: 11}[strength]
    g = blank()
    cx, cy = 5.5, 11.5
    for y in range(H):
        for x in range(W):
            dx, dy = (x - cx) * 2, y - cy
            r = math.hypot(dx, dy)
            a = math.atan2(dy, dx)
            spoke = min(abs(((a * 8 / math.pi) % 2) - 1), 1) < 0.25 * max(1, 6 / max(r, 1))
            ring = abs(r % 6 - 3) < 0.6 and r < 13
            on = spoke or ring
            if strength == 2 and ring and (x + y) % 3 == 0:
                on = spoke
            if strength == 1 and (ring and y > cy or spoke and (x > cx and y > cy)):
                on = False
            if on:
                g[y][x] = c
    return g


def tombstone():
    g = blank()
    art = grid("""
............
............
...MMMMMM...
..MlMMMMMD..
.MlMMMMMMMD.
.MlMMMMMMMD.
.MlMMMMMMMD.
.MlMDMDDMMD.
.MlMDMDMMMD.
.MlMDDMDDMD.
.MlMDMDDMMD.
.MlMMMMMMMD.
.MlMMMMDMMD.
.MlMMMMMDMD.
.MlMMMMMMMD.
.MlMMMMMMMD.
.MlMMMMMMMD.
.MlMMMMMMMD.
NNNNNNNNNNNN
NNNNNNNNNNNN
NgNNNNNNgNNN
NNNNNgNNNNNN
NNNNNNNNNNNN
NNNNNNNNNNNN
""")
    for y in range(H):
        for x in range(W):
            if art[y][x] != T:
                g[y][x] = art[y][x]
    return g


def spiral():
    import math
    g = blank()
    cx, cy = 5.5, 11.5
    for y in range(H):
        for x in range(W):
            dx, dy = (x - cx) * 2, y - cy
            r = math.hypot(dx, dy)
            a = math.atan2(dy, dx)
            if r < 11.5:
                k = (r - a * 3 / math.pi) % 6
                g[y][x] = 4 if k < 3 else 11
            if r < 2:
                g[y][x] = 7
    return g


def cell_frames():
    frames = [board(), board(True), hole(), slime(1), slime(2),
              cobweb(3), cobweb(2), cobweb(1), tombstone(), spiral()]
    names = ["plain", "plain_alt", "hole", "jelly1", "jelly2", "icing3", "icing2", "icing1",
             "chocolate", "licorice"]
    return frames, names


def save(out_dir, name, frames, names, cols=7):
    rows = (len(frames) + cols - 1) // cols
    im = Image.new("P", (cols * W, rows * H), T)
    im.putpalette(pal.flat_palette())
    info = {"name": name, "note": "C64 colours, 16 = transparent (halloween/tools/mkart.py)",
            "cell": {"w": W, "h": H}, "sheet": {"cols": cols, "rows": rows}, "frames": []}
    for i, (f, n) in enumerate(zip(frames, names)):
        x0, y0 = (i % cols) * W, (i // cols) * H
        for y in range(H):
            for x in range(W):
                im.putpixel((x0 + x, y0 + y), f[y][x])
        info["frames"].append({"index": i, "name": n, "x": x0, "y": y0})
    im.save(os.path.join(out_dir, f"{name}_sheet.png"))
    with open(os.path.join(out_dir, f"{name}_sheet.json"), "w", encoding="utf-8") as fh:
        json.dump(info, fh, indent=1)
    pv = Image.new("RGB", im.size, (40, 0, 40))       # transparent shows as dark purple
    for y in range(im.height):
        for x in range(im.width):
            c = im.getpixel((x, y))
            if c != T:
                pv.putpixel((x, y), pal.RGB[c])
    pv.resize((im.width * 8, im.height * 4), Image.NEAREST).save(
        os.path.join(out_dir, "..", "build", f"preview_{name}.png"))


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "..", "assets")
    os.makedirs(out, exist_ok=True)
    os.makedirs(os.path.join(out, "..", "build"), exist_ok=True)
    save(out, "candy", *candy_frames())
    save(out, "cells", *cell_frames())
    print(f"mkart: {out}/candy_sheet.png, cells_sheet.png")


if __name__ == "__main__":
    main()
