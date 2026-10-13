#!/usr/bin/env python3
"""levels/levels.txt -> build/levels.asm (plan.md §11).

Οι πίστες, η μία μετά την άλλη (το load_level τις διαβάζει με τη σειρά):

    0     σημαίες: bits 0-1 στόχος (0 πόντοι, 1 ζελέ, 2 υλικά, 3 ζελέ + υλικά),
          bits 2-3 χρώματα - 4, bit 4 καθρέφτης
    1     κινήσεις, BCD
    (2)   υλικά, BCD — μόνο αν ο στόχος έχει υλικά
    +3    πόντοι για 1, 2, 3 αστέρια, σε μονάδες των 500 (1-255)
    ...   τα κελιά σε τρεξίματα, ένα byte το καθένα: είδος (CELL_KINDS) στο
          πάνω nibble, μήκος - 1 στο κάτω, ώσπου να καλυφθούν 64 κελιά — ή 32
          με τον καθρέφτη: οι 4 αριστερές κολόνες, και οι δεξιές είναι το
          είδωλό τους

Οι κωδικοί των πιστών δεν είναι πίνακας: ο πρώτος είναι CODE_FIRST και κάθε
επόμενος + CODE_STEP, σε BCD mod 10.000. Το βήμα είναι πρώτο ως προς το 10,
άρα κανένας δεν επαναλαμβάνεται· κανένας δεν είναι 0000.

  levels.py levels/levels.txt build/levels.asm
"""
import sys

GOALS = {'score': 0, 'jelly': 1, 'ingredients': 2, 'jelly+ingredients': 3}
CELLS = {'.': 0x00, 'j': 0x20, 'J': 0x40, '1': 0x0A, '2': 0x12, '3': 0x1A,
         'c': 0x03, 'l': 0x04, 'o': 0x01}
KINDS = list(CELLS)                 # η σειρά του cell_kinds
BLOCKS = 'o123cl'
CODE_FIRST, CODE_STEP = 4721, 3587
STAR_UNIT = 500


def bcd(n, digits):
    s = f"{n:0{digits}d}"
    if len(s) > digits:
        raise ValueError(f"{n} δεν χωράει σε {digits} ψηφία")
    return [int(s[i:i + 2], 16) for i in range(0, digits, 2)]


def hundreds(points):
    if points % 100:
        raise ValueError(f"{points}: οι πόντοι πάνε ανά εκατό")
    return bcd(points // 100, 4)


def parse(path):
    levels, cur, rows = [], None, None
    for n, raw in enumerate(open(path, encoding='utf-8'), 1):
        line = raw.split('#', 1)[0].rstrip()
        if not line:
            continue
        try:
            if rows is not None and len(rows) < 8:
                if len(line) != 8 or any(ch not in CELLS for ch in line):
                    raise ValueError(f"γραμμή κελιών: '{line}'")
                rows.append(line)
                continue
            key, *val = line.split()
            if key == 'level':
                cur = {'name': val[0], 'ingredients': 0}
                levels.append(cur)
                rows = None
            elif key == 'goal':
                cur['goal'] = GOALS[val[0]]
            elif key in ('moves', 'colours', 'ingredients'):
                cur[key] = int(val[0])
            elif key == 'stars':
                cur['stars'] = [int(v) for v in val]
            elif key == 'cells':
                rows = cur['cells'] = []
            else:
                raise ValueError(f"άγνωστο '{key}'")
        except (ValueError, KeyError, IndexError) as e:
            sys.exit(f"{path}:{n}: {e}")
    return levels


def check(lv):
    name = f"level {lv['name']}"
    for k in ('goal', 'moves', 'colours', 'stars', 'cells'):
        if k not in lv:
            sys.exit(f"{name}: λείπει το '{k}'")
    if len(lv['cells']) != 8:
        sys.exit(f"{name}: θέλει 8 γραμμές κελιών")
    if not 4 <= lv['colours'] <= 6:
        sys.exit(f"{name}: χρώματα 4-6")
    if len(lv['stars']) != 3 or lv['stars'] != sorted(lv['stars']):
        sys.exit(f"{name}: τρία αστέρια, σε αύξουσα σειρά")
    wants_ingr = lv['goal'] in (2, 3)
    if wants_ingr != (lv['ingredients'] > 0):
        sys.exit(f"{name}: τα υλικά και ο στόχος δεν συμφωνούν")
    g = lv['cells']
    exits = [(y, x) for y in range(8) for x in range(8)
             if g[y][x] != 'o' and (y == 7 or g[y + 1][x] == 'o')]
    if wants_ingr and not exits:
        sys.exit(f"{name}: τα υλικά δεν έχουν από πού να βγουν")
    # Ποια κελιά ξαναγεμίζουν: από την κορυφή (ή κάτω από τρύπες ώς την
    # κορυφή), από το κελί από πάνω, ή διαγώνια από πάνω-αριστερά/δεξιά. Τα
    # εμπόδια κάποτε σπάνε· μόνο οι τρύπες μένουν για πάντα.
    fed = set()
    while True:
        new = {(y, x) for y in range(8) for x in range(8) if g[y][x] != 'o' and (
               all(g[k][x] == 'o' for k in range(y)) or (y - 1, x) in fed or
               (y - 1, x - 1) in fed or (y - 1, x + 1) in fed)}
        if new == fed:
            break
        fed = new
    dead = [(y, x) for y in range(8) for x in range(8) if g[y][x] != 'o' and (y, x) not in fed]
    if dead:
        sys.exit(f"{name}: τα κελιά {dead} δεν ξαναγεμίζουν ποτέ")
    if lv['goal'] in (1, 3) and not any(ch in 'jJ' for r in lv['cells'] for ch in r):
        sys.exit(f"{name}: στόχος ζελέ χωρίς ζελέ")


def mirrored(rows):
    return all(r == r[::-1] for r in rows)


def encode(lv):
    rows = lv['cells']
    mirror = mirrored(rows)
    stars = []
    for p in lv['stars']:
        if p % STAR_UNIT or not 0 < p // STAR_UNIT < 256:
            raise ValueError(f"αστέρια: {p} — ανά {STAR_UNIT}, ώς {255 * STAR_UNIT}")
        stars.append(p // STAR_UNIT)
    head = [lv['goal'] | (lv['colours'] - 4) << 2 | mirror << 4, *bcd(lv['moves'], 2)]
    if lv['goal'] & 2:
        head += bcd(lv['ingredients'], 2)
    head += stars
    cells = [KINDS.index(ch) for r in rows for ch in (r[:4] if mirror else r)]
    runs, i = [], 0
    while i < len(cells):
        j = i
        while j < len(cells) and cells[j] == cells[i] and j - i < 16:
            j += 1
        runs.append(cells[i] << 4 | (j - i - 1))
        i = j
    return head + runs


def level_codes(n):
    codes = [(CODE_FIRST + i * CODE_STEP) % 10000 for i in range(n)]
    assert 0 not in codes and len(set(codes)) == n
    return codes


def main():
    src, dst = sys.argv[1], sys.argv[2]
    levels = parse(src)
    out = [f"; GENERATED by tools/levels.py ({src}) - do not edit.", '',
           f"NLEVELS = {len(levels)}",
           f"CODE_FIRST = ${CODE_FIRST:04d}        ; level 1's code, BCD",
           f"CODE_STEP = ${CODE_STEP:04d}         ; + this for every next one", '',
           'cell_kinds              ; cell[] by kind: ' + ' '.join(KINDS),
           '        .byte ' + ','.join(f"${CELLS[k]:02x}" for k in KINDS), '', 'levels']
    total = 0
    for i, lv in enumerate(levels):
        try:
            check(lv)
            data = encode(lv)
        except ValueError as e:
            sys.exit(f"level {lv['name']}: {e}")
        total += len(data)
        out.append(f"; level {i + 1}: {len(data)} bytes")
        for k in range(0, len(data), 16):
            out.append('        .byte ' + ','.join(f"${b:02x}" for b in data[k:k + 16]))
    out.append('')
    out.append('; codes: ' + ' '.join(f"{i + 1}={c:04d}" for i, c in enumerate(level_codes(len(levels)))))
    open(dst, 'w').write('\n'.join(out) + '\n')
    print(f"{dst}: {len(levels)} levels, {total} bytes")


if __name__ == '__main__':
    main()
