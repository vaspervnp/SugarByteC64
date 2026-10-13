#!/usr/bin/env python3
"""The CPC's graphics (assets/cpc/*_sheet.png, Mode 0, 16 pens) -> the C64's
multicolour bitmap (src/data/gfx.asm, src/data/gfx.inc).

The CPC's Mode 0 pixel is as wide as the C64's multicolour pixel (160 across),
so nothing is scaled: a 12x24 candy is 3x3 characters of the bitmap. What
changes is the colour: the C64 has 4 colours in every 4x8 character —
$d021 (the same for the whole screen) and three of its own (the screen RAM's
two nibbles, the colour RAM). Every character of every frame is reduced here
to at most three colours besides the background, and the colours that do not
fit are merged into the nearest.

Formats (one record per character, frames row by row):

  opaque (cells, glyphs, icons, menu tiles)   10 bytes: bitmap[8], screen, colour
  masked (candies, overlays)                  11 bytes: bitmap[8], screen,
          keep, colour — pixel pair 00 is transparent; keep = the nibbles of
          the screen byte under it that stay (the ones this frame does not
          use); colour = $ff when the frame does not use the colour RAM.

The game screen's $d021 is blue (the board and the HUD): blue pixels are
pair 00. The menu's is black.

Also: the candies as sprites (the swap, the hint, the diagonal slide: one
multicolour sprite + one hires sprite behind it for the shade), the cursor
and the selection (hires, Y-expanded), the menu's frame (a whole screen, RLE)
and a mockup of both screens (build/mockup_*.png).
"""

import json
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import c64palette as pal  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
CPC = os.path.join(ROOT, "assets", "cpc")
OUT_DIR = os.path.join(ROOT, "src", "data")
BUILD = os.path.join(ROOT, "build")

T = -1                          # transparent
BLUE, BLACK = 6, 0

# CPC pen -> C64 colour, for everything ...
PENS = {0: 0, 1: 1, 2: 12, 3: 6, 4: 3, 5: 2, 6: 9, 7: 8, 8: 9, 9: 7,
        10: 13, 11: 5, 12: 14, 13: 6, 14: 4, 15: 6}
# ... and by candy colour (red, orange, yellow, green, blue, purple): the base
# and the shade must stand out from the blue board.
CANDY_PENS = [
    {5: 10, 6: 2},              # red: light red, red
    {7: 8, 8: 2},               # orange: orange, red
    {9: 7, 8: 8},               # yellow: yellow, orange
    {10: 13, 11: 5},            # green: light green, green
    {12: 3, 13: 14},            # blue: cyan, light blue
    {14: 4, 15: 0},             # purple: purple, black
]
CELL_PENS = {6: 2, 8: 9, 2: 12}     # chocolate: red with brown, icing: grey
TITLE_PENS = {5: 10, 6: 2, 7: 8, 8: 9, 9: 7, 10: 13, 11: 5, 12: 3, 13: 14, 14: 4, 15: 11}
# the title's letters by hue: their CPC pens (base, shade) and the C64's
HUE_PENS = [(5, 6), (7, 8), (9, 8), (10, 11), (12, 13), (14, 15)]
HUE_C64 = [(10, 2), (8, 9), (7, 8), (13, 5), (3, 14), (4, 11)]
BORDER_PENS = {**TITLE_PENS, 5: 2}


def sheet(name):
    with open(os.path.join(CPC, f"{name}_cpc_mode0_sheet.json"), encoding="utf-8") as f:
        info = json.load(f)
    im = Image.open(os.path.join(CPC, f"{name}_cpc_mode0_sheet.png"))
    return info, im


def frame_pens(info, im, index):
    """frame -> rows of CPC pens"""
    fr = info["frames"][index]
    w, h = info["cell"]["w"], info["cell"]["h"]
    px = im.load()
    return [[px[fr["x"] + x, fr["y"] + y] for x in range(w)] for y in range(h)]


def to_c64(rows, masked, override=None):
    m = dict(PENS)
    if override:
        m.update(override)
    return [[T if (masked and p == 0) else m[p] for p in r] for r in rows]


def dist(a, b):
    ra, rb = pal.RGB[a], pal.RGB[b]
    # weighted towards the luminance: the C64's colours are told apart by it
    return 2 * (ra[0] - rb[0]) ** 2 + 4 * (ra[1] - rb[1]) ** 2 + 3 * (ra[2] - rb[2]) ** 2


def quantize(block, bg, prefer11=None, spare11=False):
    """block: 8 rows of 4 C64 colours (or T). bg: the colour of pair 00 (None:
    no colour is free). -> (bitmap 8 bytes, {slot: colour}, block as shown)

    prefer11: a colour to put in the colour RAM if it is there.
    spare11: leave the colour RAM unused when two colours are enough (a candy
    over a cell keeps the cell's grid / jelly colour)."""
    counts = {}
    for r in block:
        for c in r:
            if c != T and c != bg:
                counts[c] = counts.get(c, 0) + 1
    mapping = {c: c for c in counts}
    while len(counts) > 3:
        weakest = min(counts, key=lambda c: (counts[c], c))
        del counts[weakest]
        targets = list(counts) + ([bg] if bg is not None else [])
        to = min(targets, key=lambda c: dist(c, weakest))
        for k, v in mapping.items():
            if v == weakest:
                mapping[k] = to
        if to in counts:
            counts[to] += 1
    colours = sorted(counts, key=lambda c: (-counts[c], c))
    slots = {}
    if prefer11 in colours:
        slots[3] = prefer11
        colours.remove(prefer11)
    order = [1, 2, 3] if not (spare11 and len(colours) + len(slots) <= 2) else [1, 2]
    for c in colours:
        for s in order:
            if s not in slots:
                slots[s] = c
                break
    rev = {c: s for s, c in slots.items()}
    out, shown = [], []
    for r in block:
        byte, srow = 0, []
        for c in r:
            if c == T:
                s = 0
            else:
                c = mapping.get(c, c)
                s = 0 if c == bg else rev[c]
            byte = byte << 2 | s
            srow.append(T if c == T else (bg if s == 0 else slots[s]))
        out.append(byte)
        shown.append(srow)
    return out, slots, shown


def blocks(rows):
    """rows (h x w, h % 8 == 0, w % 4 == 0) -> characters row by row"""
    h, w = len(rows), len(rows[0])
    for cy in range(h // 8):
        for cx in range(w // 4):
            yield cx, cy, [r[cx * 4:cx * 4 + 4] for r in rows[cy * 8:cy * 8 + 8]]


def opaque_record(bm, slots):
    scr = slots.get(1, 0) << 4 | slots.get(2, 0)
    return bm + [scr, slots.get(3, 0)]


def masked_record(bm, slots):
    scr = slots.get(1, 0) << 4 | slots.get(2, 0)
    keep = (0 if 1 in slots else 0xF0) | (0 if 2 in slots else 0x0F)
    return bm + [scr, keep, slots[3] if 3 in slots else 0xFF]


def convert(rows, bg, masked, prefer11=None, spare11=False):
    """-> (bytes, picture as shown on the C64)"""
    data = []
    h, w = len(rows), len(rows[0])
    shown = [[T] * w for _ in range(h)]
    for cx, cy, b in blocks(rows):
        bm, slots, s = quantize(b, bg, prefer11, spare11)
        data += masked_record(bm, slots) if masked else opaque_record(bm, slots)
        for y in range(8):
            for x in range(4):
                shown[cy * 8 + y][cx * 4 + x] = s[y][x]
    return data, shown


# ---------------------------------------------------------------------------
# sprites
def sprite_bytes(rows_bits):
    """21 rows of 24 bits -> 63 bytes"""
    out = []
    for r in rows_bits:
        v = 0
        for b in r:
            v = v << 1 | b
        out += [v >> 16 & 255, v >> 8 & 255, v & 255]
    return out


def candy_sprites(rows):
    """a candy (24 rows of 12 C64 colours / T) -> (main sprite, shade sprite,
    main colour, shade colour). The main one is multicolour: 01 white ($d025),
    10 its own colour, 11 grey ($d026); the shade is hires, behind it."""
    counts = {}
    for r in rows:
        for c in r:
            if c not in (T, BLUE, 1, 12):
                counts[c] = counts.get(c, 0) + 1
    order = sorted(counts, key=lambda c: (-counts[c], c))
    main = order[0] if order else 1
    shade = order[1] if len(order) > 1 else main
    choices = {1: "w", 12: "g", main: "m", shade: "s"}
    mc, hr = [], []
    for y in range(1, 22):                       # 21 lines: the candy is in 2..21
        r = rows[y]
        mrow, hrow = [], []
        for c in r:
            if c in (T, BLUE):
                k = None
            elif c in choices:
                k = choices[c]
            else:
                k = choices[min(choices, key=lambda q: dist(q, c))]
            mrow += {None: [0, 0], "w": [0, 1], "m": [1, 0], "g": [1, 1], "s": [0, 0]}[k]
            hrow += [1, 1] if k == "s" else [0, 0]
        mc.append(mrow)
        hr.append(hrow)
    return sprite_bytes(mc), sprite_bytes(hr), main, shade


def cursor_sprite(rows):
    """overlay cursor (24 lines of 12) -> hires, Y-expanded: line pairs ORed"""
    out = []
    for y in range(12):
        row = []
        for x in range(12):
            on = rows[2 * y][x] != 0 or rows[2 * y + 1][x] != 0
            row += [1, 1] if on else [0, 0]
        out.append(row)
    out += [[0] * 24] * 9
    return sprite_bytes(out)


# ---------------------------------------------------------------------------
def rle(data):
    """runs: (n, byte) with n 1-255, 0 = end. A run of n < 3 is still a run."""
    out, i = [], 0
    while i < len(data):
        j = i
        while j < len(data) and data[j] == data[i] and j - i < 255:
            j += 1
        out += [j - i, data[i]]
        i = j
    return out + [0]


def asm_bytes(label, data, per=16):
    lines = [label] if label else []
    for i in range(0, len(data), per):
        lines.append("        .byte " + ",".join(f"${b:02x}" for b in data[i:i + per]))
    return lines


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(BUILD, exist_ok=True)
    asm = ["; GENERATED by tools/mkgfx64.py from assets/cpc — do not edit.", ""]
    inc = ["; GENERATED by tools/mkgfx64.py — do not edit.", ""]
    shown = {}

    # --- candies: masked, over the blue board ---------------------------------
    info, im = sheet("candy")
    frames = []
    spr_main, spr_shade, spr_col_m, spr_col_s = [], [], [], []
    for i in range(len(info["frames"])):
        pens = frame_pens(info, im, i)
        override = CANDY_PENS[i % 6] if i < 24 else ({12: 6, 3: 0} if i == 24 else {6: 2, 7: 8})
        rows = to_c64(pens, True, override)
        data, s = convert(rows, BLUE, True, spare11=True)
        frames.append(data)
        shown[("candy", i)] = s
        a, b, cm, cs = candy_sprites(rows)
        spr_main.append(a)
        spr_shade.append(b)
        spr_col_m.append(cm)
        spr_col_s.append(cs)
    asm += [f"candy_gfx"]
    for i, d in enumerate(frames):
        asm += asm_bytes(None, d)
    asm += ["candy_z"]               # by frame, character: 1 = an empty bitmap
    for d in frames:
        asm += asm_bytes(None, [int(not any(d[k * 11:k * 11 + 8])) for k in range(9)])
    asm += ["candy_lo .byte " + ",".join(f"<(candy_gfx+{i * 99})" for i in range(len(frames))),
            "candy_hi .byte " + ",".join(f">(candy_gfx+{i * 99})" for i in range(len(frames)))]
    asm += ["candy_spr_main .byte " + ",".join(str(c) for c in spr_col_m),
            "candy_spr_shade .byte " + ",".join(str(c) for c in spr_col_s)]
    asm += ["candy_spr"]
    for a, b in zip(spr_main, spr_shade):
        asm += asm_bytes(None, a + [0] + b + [0])
    inc += [f"CANDY_N = {len(frames)}", "CANDY_BOMB = 24", "CANDY_INGREDIENT = 25"]

    # --- overlays: pops, beams, stars (masked); the cursor as sprites ----------
    info, im = sheet("overlay")
    idx = list(range(4, 14))                # pop1-4, beam_h1-2, beam_v1-2, star1-2
    asm += ["overlay_gfx"]
    for k, i in enumerate(idx):
        rows = to_c64(frame_pens(info, im, i), True)
        data, s = convert(rows, BLUE, True)
        shown[("overlay", k)] = s
        asm += asm_bytes(None, data)
    asm += ["overlay_lo .byte " + ",".join(f"<(overlay_gfx+{k * 99})" for k in range(len(idx))),
            "overlay_hi .byte " + ",".join(f">(overlay_gfx+{k * 99})" for k in range(len(idx)))]
    inc += ["OV_POP = 0", "OV_BEAM_H = 4", "OV_BEAM_V = 6", "OV_STAR = 8"]
    cur = [cursor_sprite(frame_pens(info, im, i)) for i in (0, 1)]
    asm += asm_bytes("cursor_spr", cur[0] + [0] + cur[1] + [0])

    # --- the cells under the candies: opaque ----------------------------------
    info, im = sheet("cells")
    asm += ["cells_gfx"]
    cells_z = []
    for i in range(len(info["frames"])):
        rows = to_c64(frame_pens(info, im, i), False, CELL_PENS)
        # the grid lines and the jelly in the colour RAM, the candies keep theirs
        data, s = convert(rows, BLUE, False, prefer11=3 if i in (3, 4) else 0)
        shown[("cells", i)] = s
        asm += asm_bytes(None, data)
        cells_z += [int(not any(data[k * 10:k * 10 + 8])) for k in range(9)]
    asm += ["cells_lo .byte " + ",".join(f"<(cells_gfx+{i * 90})" for i in range(len(info["frames"]))),
            "cells_hi .byte " + ",".join(f">(cells_gfx+{i * 90})" for i in range(len(info["frames"])))]
    asm += asm_bytes("cells_z", cells_z)
    inc += ["CELLS_BOARD = 0", "CELLS_JELLY = 3", "CELLS_ICING = 5", "CELLS_BLOCKER = 8"]

    # --- glyphs: digits and symbols (hud), letters (text), one character each --
    glyphs = []
    info, im = sheet("hud")
    for i in range(19):                     # digits, symbols, small icons
        glyphs.append(to_c64(frame_pens(info, im, i), False))
    info, im = sheet("text")
    for i in range(len(info["frames"])):
        glyphs.append(to_c64(frame_pens(info, im, i), False))
    dash = [[0] * 4 for _ in range(8)]
    dash[4] = [1, 1, 1, 0]
    glyphs.append(dash)
    asm += ["glyph_gfx"]
    for g in glyphs:
        data, _ = convert(g, BLUE, False)
        asm += asm_bytes(None, data)
    inc += ["GL_DIGIT = 0", "GL_COLON = 10", "GL_SLASH = 11", "GL_TIMES = 12", "GL_PLUS = 13",
            "GL_ICONS = 14", "GL_STAR_ON = 15", "GL_STAR_OFF = 16", "GL_LETTER = 19",
            "GL_RULE = 45", "GL_BAR = 46", "GL_DASH = 50", f"GLYPHS = {len(glyphs)}"]
    shown["glyphs"] = glyphs

    # --- icons 8x16 (2x2 characters) ------------------------------------------
    info, im = sheet("icons")
    asm += ["icon_gfx"]
    icons = []
    for i in range(len(info["frames"])):
        rows = to_c64(frame_pens(info, im, i), False)
        data, s = convert(rows, BLUE, False)
        icons.append(s)
        asm += asm_bytes(None, data)
    shown["icons"] = icons
    inc += ["ICON_SCORE = 0", "ICON_MOVES = 1", "ICON_TIME = 2", "ICON_GOAL = 3", "ICON_JELLY = 4",
            "ICON_STAR_ON = 5", "ICON_STAR_OFF = 6", "ICON_LOCK = 7"]

    # --- menu tiles 16x24 (4x3 characters), over black ------------------------
    info, im = sheet("menu")
    asm += ["menu_gfx"]
    for i in range(len(info["frames"])):
        rows = to_c64(frame_pens(info, im, i), False, TITLE_PENS)
        data, s = convert(rows, BLACK, False)
        shown[("menu", i)] = s
        asm += asm_bytes(None, data)
    inc += ["MT_PLATE_M = 0", "MT_PLATE_L = 1", "MT_PLATE_R = 2", "MT_POINTER = 3"]

    # --- the menu's frame: title, the candy canes, the foot -------------------
    frame = menu_frame()
    fdata, fshown = convert(frame, BLACK, False)
    bm, scr, col = [], [], []
    for i in range(1000):
        rec = fdata[i * 10:i * 10 + 10]
        bm += rec[:8]
        scr.append(rec[8])
        col.append(rec[9])
    packed = rle(bm) + rle(scr) + rle(col)
    asm += asm_bytes("frame_bm", rle(bm))
    asm += asm_bytes("frame_scr", rle(scr))
    asm += asm_bytes("frame_col", rle(col))
    shown["frame"] = fshown
    asm += asm_bytes("title_cycle", title_cycle())

    # --- the game screen's foot: candy cane, 4 phases of one character ---------
    asm += ["foot_gfx"]
    foot_rows = foot_pattern()
    for ph in range(4):
        rows = [r[ph:ph + 4] for r in foot_rows]
        data, _ = convert(rows, BLUE, False)
        asm += asm_bytes(None, data)

    with open(os.path.join(OUT_DIR, "gfx.asm"), "w") as f:
        f.write("\n".join(asm) + "\n")
    with open(os.path.join(OUT_DIR, "gfx.inc"), "w") as f:
        f.write("\n".join(inc) + "\n")
    mockups(shown)
    print(f"gfx: frame rle {len(packed)} bytes")


def foot_pattern():
    """8 lines of the candy cane, 8 pixels wide (twice the 4-pixel period)"""
    rows = [[6] * 8]
    for y in range(6):
        rows.append([1 if (x + y) % 4 < 2 else 2 for x in range(8)])
    rows.append([9] * 8)
    return rows


def title_pens():
    """the title cropped to 160 pixels: rows of CPC pens, and every column's
    letter hue (None between the letters)"""
    info, im = sheet("title")
    pens = frame_pens(info, im, 0)
    xs = [x for x in range(192) for y in range(32) if pens[y][x] == 3]
    left = min(max(0, min(xs) - 1), 32) & ~3
    pens = [r[left:left + 160] for r in pens]
    hue = [None] * 160
    x = 0
    while x < 160:                      # a letter: a run of columns with outline
        if any(pens[y][x] == 3 for y in range(32)):
            x0 = x
            while x < 160 and any(pens[y][x] == 3 for y in range(32)):
                x += 1
            letter = [pens[y][k] for y in range(32) for k in range(x0, x)]
            h = max(range(6), key=lambda i: letter.count(HUE_PENS[i][0]))
            for k in range(x0, x):
                hue[k] = h
        else:
            x += 1
    return pens, hue


def title_rows(rot):
    """the title in C64 colours, every letter's hue turned on by rot"""
    pens, hue = title_pens()
    out = []
    for r in pens:
        row = []
        for x, p in enumerate(r):
            h = hue[x]
            if h is not None and p in HUE_PENS[h]:
                base, shade = HUE_C64[(h + rot) % 6]
                row.append(base if p == HUE_PENS[h][0] else shade)
            else:
                row.append(TITLE_PENS.get(p, PENS[p]))
        out.append(row)
    return out


def title_cycle():
    """6 sets of the title's colours (160 screen + 160 colour RAM bytes each):
    the same bitmap, every letter in the next hue"""
    base = title_rows(0)
    _, hue = title_pens()
    out = []
    for rot in range(6):
        scr, col = [], []
        for cy in range(4):
            for cx in range(40):
                block = [r[cx * 4:cx * 4 + 4] for r in base[cy * 8:cy * 8 + 8]]
                _, slots, _ = quantize(block, BLACK)
                hs = [hue[cx * 4 + k] for k in range(4) if hue[cx * 4 + k] is not None]
                h = max(set(hs), key=hs.count) if hs else None

                def turn(c):
                    if h is None:
                        return c
                    b0, s0 = HUE_C64[h]
                    b1, s1 = HUE_C64[(h + rot) % 6]
                    return b1 if c == b0 else s1 if c == s0 else c
                scr.append(turn(slots.get(1, 0)) << 4 | turn(slots.get(2, 0)))
                col.append(turn(slots.get(3, 0)))
        out += scr + col
    return out


def menu_frame():
    """160x200 (C64 colours): the title, the candy canes down the sides, the foot"""
    img = [[BLACK] * 160 for _ in range(200)]
    title = title_rows(0)
    for y in range(32):
        img[y] = list(title[y])
    info, im = sheet("border")
    edge_l = to_c64(frame_pens(info, im, 0), False, BORDER_PENS)
    edge_r = to_c64(frame_pens(info, im, 1), False, BORDER_PENS)
    bottom = to_c64(frame_pens(info, im, 2), False, BORDER_PENS)
    corner = to_c64(frame_pens(info, im, 3), False, TITLE_PENS)
    for y in range(32, 176):                     # the canes: 8 pixels of the 16
        for x in range(8):
            img[y][x] = edge_l[(y - 32) % 24][x + 4]
            img[y][152 + x] = edge_r[(y - 32) % 24][x + 4]
    for y in range(176, 200):
        for x in range(160):
            if x < 16:
                img[y][x] = corner[y - 176][x]
            elif x >= 144:
                img[y][x] = corner[y - 176][x - 144]
            else:
                img[y][x] = bottom[y - 176][(x - 16) % 16]
    return img


def mockups(shown):
    """build/mockup_game.png, build/mockup_menu.png: as the C64 would show them (2x)"""
    def put(img, x0, y0, rows, bg=None):
        for y, r in enumerate(rows):
            for x, c in enumerate(r):
                if c != T:
                    img.putpixel((x0 + x, y0 + y), pal.RGB[c])
                elif bg is not None:
                    img.putpixel((x0 + x, y0 + y), pal.RGB[bg])

    img = Image.new("RGB", (160, 200), pal.RGB[BLUE])
    import random
    rnd = random.Random(3)
    layout = [0] * 64
    layout[9] = 3
    layout[10] = 4
    layout[20] = 5
    layout[35] = 9
    for i in range(64):
        cx, cy = i % 8, i // 8
        cf = 2 if i == 63 else (layout[i] if layout[i] else (cx ^ cy) & 1)
        put(img, cx * 12, cy * 24, shown[("cells", cf)])
        if cf in (0, 1, 3, 4):
            put(img, cx * 12, cy * 24, shown[("candy", rnd.randrange(27))])
    put(img, 12 * 2, 24 * 4, shown[("overlay", 8)])
    for i, ic in enumerate(range(8)):
        put(img, 100 + (i % 4) * 12, 8 + (i // 4) * 20, shown["icons"][ic])
    for i in range(16):
        put(img, 96 + i * 4, 60, shown["glyphs"][19 + i])
        put(img, 96 + i * 4, 70, shown["glyphs"][i])
    img.resize((640, 400), Image.NEAREST).save(os.path.join(BUILD, "mockup_game.png"))
    m = Image.new("RGB", (160, 200), (0, 0, 0))
    put(m, 0, 0, shown["frame"])
    for p in range(4):
        y = 40 + p * 24
        put(m, 32, y, shown[("menu", 1)])
        for k in range(4):
            put(m, 48 + k * 16, y, shown[("menu", 0)])
        put(m, 112, y, shown[("menu", 2)])
    put(m, 12, 40, shown[("menu", 3)])
    for c in range(6):
        put(m, 24 + c * 20, 144, shown[("candy", c)])
    m.resize((640, 400), Image.NEAREST).save(os.path.join(BUILD, "mockup_menu.png"))


if __name__ == "__main__":
    main()
