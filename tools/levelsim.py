#!/usr/bin/env python3
"""Monte-Carlo δοκιμαστής πιστών: πόσο δύσκολη είναι κάθε πίστα (plan.md §11).

Παίζει κάθε πίστα του levels/levels.txt N φορές με ένα «μέτριο ανθρώπινο»
ρομπότ και τυπώνει ανά πίστα: ποσοστό νίκης, κινήσεις των νικών, πόντους στο
τέλος (p25/p50/p75, μαζί με το Sugar Crush), πόσα παιχνίδια πιάνουν τα 1/2/3
αστέρια του αρχείου, και μια ΠΡΟΤΑΣΗ για τη γραμμή stars.

Οι κανόνες είναι αυτοί του src/: board.asm (τριάδες 60/120/200 επί chain,
βαρύτητα με τμήματα, τρύπες και εμπόδια, διαγώνιο γλίστρημα αριστερά πρώτα),
special.asm (ριγέ από 4, περιτύλιγμα από Γ/Τ, βόμβα από 5, πού γεννιούνται,
οι συνδυασμοί, χτύπημα 60 ανά κελί), cells.asm (ζελέ 100, γλάσο 1-3,
σοκολάτα που απλώνεται αν δεν έσπασε καμία, γλυκόριζα), ingred.asm (υλικά
1 στα 8 γεμίσματα, ένα τη φορά, 1.000 στη βάση ή πάνω από τρύπα), game.asm
(αλυσίδες, αδιέξοδο -> καινούργιο ταμπλό, Sugar Crush) και level.asm.

Το ρομπότ: κοιτάει όλες τις έγκυρες ανταλλαγές και βαθμολογεί την καθεμία
μόνο με το ΠΡΩΤΟ βήμα (ό,τι σκάει αμέσως, χωρίς πτώση και αλυσίδες — αυτές
είναι τύχη και κοστίζουν): πόντοι, ζελέ, ζημιά σε εμπόδια, ειδικά που
γεννιούνται, πόσο κατεβαίνει το υλικό. Διαλέγει από τις 3 καλύτερες με βάρη
60/25/15, ώστε να μην είναι υπεράνθρωπο. Το --player random διαλέγει στην
τύχη, για σύγκριση· το --player best παίρνει πάντα την καλύτερη.

Τι ΔΕΝ είναι ακριβές:
  * το τυχαίο είναι το random της Python, όχι το xorshift του 6510· τα
    νούμερα είναι στατιστικά, όχι το ίδιο παιχνίδι
  * η βαρύτητα εφαρμόζεται ώς το τέλος σε κάθε κολόνα πριν ψάξει διαγώνιο
    γλίστρημα, όχι ένα κελί τη φορά· το τελικό ταμπλό είναι το ίδιο, αλλά το
    υλικό μπορεί να γεννηθεί σε λίγο άλλη στιγμή (ίδια πιθανότητα ανά candy)
  * το όριο MAX_RUNS 24 / MAX_SPAWN 16 και το BCD των 6 ψηφίων αγνοούνται
  * το ρομπότ δεν είναι άνθρωπος: δεν βλέπει αλυσίδες, δεν σχεδιάζει
    συνδυασμούς ειδικών μπροστά
  * αστέρια: σε νίκη τουλάχιστον 1 (όπως το draw_win_stars), σε ήττα κανένα
  * η πρόταση για το 1ο αστέρι των πιστών "score" υποθέτει ότι το ρομπότ
    παίζει το ίδιο ό,τι κι αν είναι ο στόχος· με άλλο στόχο αλλάζει και το
    πότε αρχίζει το Sugar Crush, άρα και τα 2/3 αστέρια λίγο

  levelsim.py levels/levels.txt [--runs N] [--only 3,7] [--seed S]
                                [--player greedy|best|random] [--jobs J]
"""
import argparse
import os
import random
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from levels import parse, check, STAR_UNIT  # noqa: E402

EMPTY, BOMB, INGR = 7, 6, 0x20
F_SH, F_SV, F_WR = 1 << 3, 2 << 3, 3 << 3
M_BLOCK = 0x10
C_NORMAL, C_HOLE, C_ICING, C_CHOC, C_LIC = range(5)
G_SCORE, G_JELLY, G_INGR, G_BOTH = range(4)
GOAL_NAMES = ['score', 'jelly', 'ingr', 'jelly+ingr']
# γράμμα του levels.txt -> (τύπος, γλάσο, ζελέ)
CELL_DEF = {'.': (0, 0, 0), 'j': (0, 0, 1), 'J': (0, 0, 2), '1': (C_ICING, 1, 0),
            '2': (C_ICING, 2, 0), '3': (C_ICING, 3, 0), 'c': (C_CHOC, 0, 0),
            'l': (C_LIC, 0, 0), 'o': (C_HOLE, 0, 0)}

# mcol: χρώμα που ταιριάζει, ή -1 (κενό, βόμβα, υλικό)
MC = [-1 if (v & INGR or (v & 7) >= 6) else v & 7 for v in range(64)]
# special_kind: 1 ριγέ-οριζ., 2 ριγέ-κάθ., 3 περιτύλιγμα, 4 βόμβα, 0 τίποτα
SK = [0 if v & INGR else 4 if v == BOMB else (v >> 3) & 3 for v in range(64)]
SK[EMPTY] = 0
# οι 16 γραμμές του find_matches: (κελιά, bit, βήμα)
LINES = [(tuple(y * 8 + x for x in range(8)), 1, 1) for y in range(8)] + \
        [(tuple(y * 8 + x for y in range(8)), 2, 8) for x in range(8)]
# γείτονες με τη σειρά του neighbours: πάνω, κάτω, αριστερά, δεξιά
NEIGH = [tuple(n for n in (c - 8 if c >= 8 else None, c + 8 if c < 56 else None,
                           c - 1 if c & 7 else None, c + 1 if c & 7 != 7 else None)
               if n is not None) for c in range(64)]
PAIRS = [(c, c + 1) for c in range(64) if c & 7 != 7] + [(c, c + 8) for c in range(56)]
RUN_PTS = {3: 60, 4: 120}


class Game:
    """Η κατάσταση μιας παρτίδας: board[] με τις τιμές του 6510, και cell[] σπασμένο σε τρία."""

    def __init__(self, lv, rng):
        self.rng = rng
        self.goal = lv['goal']
        self.ncol = lv['colours']
        self.moves = lv['moves']
        self.stars = lv['stars']
        self.ctype, self.icing, self.jelly = [], [], []
        for row in lv['cells']:
            for ch in row:
                t, i, j = CELL_DEF[ch]
                self.ctype.append(t)
                self.icing.append(i)
                self.jelly.append(j)
        # οι τρύπες δεν αλλάζουν ποτέ: holes_above μία φορά
        self.holes_above = [all(self.ctype[r * 8 + (c & 7)] == C_HOLE for r in range(c >> 3, -1, -1))
                            for c in range(64)]
        self.ingr_left = self.ingr_spawn = lv['ingredients']
        self.ingr_board = 0
        self.score = 0
        self.chain = 1
        self.choc_broken = 0
        self.sa = self.sb = 0
        self.board = [0] * 64
        self.fill_board()

    def clone(self):
        g = Game.__new__(Game)
        g.__dict__.update(self.__dict__)
        g.board, g.ctype, g.icing, g.jelly = self.board[:], self.ctype[:], self.icing[:], self.jelly[:]
        return g

    # --- ταμπλό -------------------------------------------------------------
    def fill_board(self):
        b, ct, rnd, n = self.board, self.ctype, self.rng.randrange, self.ncol
        while True:
            for c in range(64):
                v = b[c]
                if v != EMPTY and v & INGR:
                    continue        # τα υλικά μένουν στη θέση τους
                if ct[c]:
                    b[c] = EMPTY
                    continue
                while True:
                    col = rnd(n)
                    if (c & 7) >= 2 and b[c - 1] == col and b[c - 2] == col:
                        continue
                    if c >= 16 and b[c - 8] == col and b[c - 16] == col:
                        continue
                    break
                b[c] = col
            if self.has_move():
                return

    def line_at(self, c):
        b = self.board
        col = MC[b[c]]
        if col < 0:
            return False
        n, x = 1, c
        while x & 7 and MC[b[x - 1]] == col:
            x -= 1
            n += 1
        x = c
        while x & 7 != 7 and MC[b[x + 1]] == col:
            x += 1
            n += 1
        if n >= 3:
            return True
        n, x = 1, c
        while x >= 8 and MC[b[x - 8]] == col:
            x -= 8
            n += 1
        x = c
        while x < 56 and MC[b[x + 8]] == col:
            x += 8
            n += 1
        return n >= 3

    def try_swap(self, e, d):
        b = self.board
        x, y = b[e], b[d]
        if x == EMPTY or y == EMPTY:
            return False
        if x == BOMB:
            return not y & INGR
        if y == BOMB:
            return not x & INGR
        b[e], b[d] = y, x
        ok = self.line_at(e) or self.line_at(d)
        b[e], b[d] = x, y
        return ok

    def has_move(self):
        return any(self.try_swap(e, d) for e, d in PAIRS)

    def candidates(self):
        """Ό,τι δέχεται το st_swap: τριάδα, βόμβα, ή δύο ριγέ/περιτυλίγματα."""
        b, out = self.board, []
        for e, d in PAIRS:
            if self.try_swap(e, d) or (0 < SK[b[e]] < 4 and 0 < SK[b[d]] < 4):
                out.append((e, d))
        return out

    # --- τριάδες και ειδικά (find_matches, combo_swap) ----------------------
    def find_matches(self, b):
        """-> (matched, spawns, πόντοι) ή None. Δεν πειράζει το score."""
        matched = [0] * 64
        runs = []
        pts = 0
        chain = self.chain
        for cells, bit, step in LINES:
            colour, n = MC[b[cells[0]]], 1
            for i in range(1, 9):
                cc = MC[b[cells[i]]] if i < 8 else -1
                if cc >= 0 and cc == colour:
                    n += 1
                    continue
                if n >= 3:
                    run = cells[i - n:i]
                    for k in run:
                        matched[k] |= bit
                    runs.append((run, step))
                    pts += RUN_PTS.get(n, 200) * chain
                colour, n = cc, 1
        if not runs:
            return None
        spawns = []
        # plan_specials: 5 -> βόμβα, διασταύρωση -> περιτύλιγμα, 4 -> ριγέ
        for run, step in runs:
            if len(run) >= 5:
                for k in run:
                    matched[k] |= 4
                spawns.append((self.run_pick(run), BOMB))
        for c in range(64):
            if matched[c] & 7 == 3:
                matched[c] |= 4
                spawns.append((c, MC[b[c]] | F_WR))
        for run, step in runs:
            if len(run) == 4 and not any(matched[k] & 4 or matched[k] & 3 == 3 for k in run):
                spawns.append((self.run_pick(run), MC[b[run[0]]] | (F_SH if step == 1 else F_SV)))
        pts += self.expand(b, matched)
        self.blocker_damage(matched)
        return matched, spawns, pts

    def run_pick(self, run):
        if self.chain == 1:
            for k in run:
                if k == self.sb or k == self.sa:
                    return k
        return run[len(run) >> 1]

    def hit(self, b, matched, c):
        v = b[c]
        if v == EMPTY:
            if self.ctype[c] >= C_ICING:
                matched[c] |= M_BLOCK
            return 0
        if v & INGR or matched[c]:
            return 0
        matched[c] = 8
        return 60 * self.chain

    def hit_area(self, b, matched, c, r):
        pts, cx, cy = 0, c & 7, c >> 3
        for y in range(max(0, cy - r), min(7, cy + r) + 1):
            for x in range(max(0, cx - r), min(7, cx + r) + 1):
                pts += self.hit(b, matched, y * 8 + x)
        return pts

    def hit_row(self, b, matched, y):
        if not 0 <= y < 8:
            return 0
        return sum(self.hit(b, matched, y * 8 + x) for x in range(8))

    def hit_col(self, b, matched, x):
        if not 0 <= x < 8:
            return 0
        return sum(self.hit(b, matched, y * 8 + x) for y in range(8))

    def mark_colour(self, b, matched, col):
        return sum(self.hit(b, matched, c) for c in range(64) if MC[b[c]] == col)

    def expand(self, b, matched):
        """expand_specials: όσα ειδικά σκάνε πυροδοτούνται, ώσπου να μη μείνει κανένα."""
        pts, changed = 0, True
        while changed:
            changed = False
            for c in range(64):
                m = matched[c]
                if not m or m & 0x80:
                    continue
                k = SK[b[c]]
                if not k:
                    continue
                matched[c] = m | 0x80
                changed = True
                if k == 1:
                    pts += self.hit_row(b, matched, c >> 3)
                elif k == 2:
                    pts += self.hit_col(b, matched, c & 7)
                elif k == 3:
                    pts += self.hit_area(b, matched, c, 1)
                else:               # βόμβα που τη χτύπησε άλλο: τυχαίο χρώμα
                    pts += self.mark_colour(b, matched, self.rng.randrange(self.ncol))
        return pts

    def blocker_damage(self, matched):
        ct = self.ctype
        for c in range(64):
            if matched[c] & ~M_BLOCK:
                for n in NEIGH[c]:
                    if ct[n] >= C_ICING:
                        matched[n] |= M_BLOCK

    def combo(self, b):
        """combo_swap, με τα δύο κελιά ήδη ανταλλαγμένα. -> όπως find_matches ή None."""
        sa, sb = self.sa, self.sb
        x, y = b[sa], b[sb]
        matched = [0] * 64
        if x == BOMB or y == BOMB:
            e, d = (sa, y) if x == BOMB else (sb, x)
            if d != BOMB and MC[d] < 0:
                return None         # βόμβα με υλικό: τίποτα
            matched[e] = 0x81
            if d == BOMB:
                pts = sum(self.hit(b, matched, c) for c in range(64))
            else:
                k, col = SK[d], MC[d]
                if k:               # convert_colour
                    for c in range(64):
                        if MC[b[c]] == col:
                            f = 3 if k == 3 else self.rng.randrange(2) + 1
                            b[c] = f << 3 | col
                pts = self.mark_colour(b, matched, col)
        else:
            kd, ke = SK[x], SK[y]
            if not kd or not ke:
                return None
            matched[sa] = matched[sb] = 0x81
            cy, cx = sb >> 3, sb & 7
            if kd == 3 and ke == 3:
                pts = self.hit_area(b, matched, sb, 2)
            elif kd == 3 or ke == 3:
                pts = sum(self.hit_row(b, matched, cy + i) + self.hit_col(b, matched, cx + i)
                          for i in (-1, 0, 1))
            else:
                pts = self.hit_row(b, matched, cy) + self.hit_col(b, matched, cx)
        pts += self.expand(b, matched)
        self.blocker_damage(matched)
        return matched, [], pts

    # --- σκάσιμο, πτώση -----------------------------------------------------
    def clear(self, matched, spawns):
        b, ct, ic, je = self.board, self.ctype, self.icing, self.jelly
        for c in range(64):
            m = matched[c]
            if not m:
                continue
            b[c] = EMPTY
            if m & M_BLOCK:         # apply_damage: εμπόδιο
                if ct[c] == C_ICING:
                    ic[c] -= 1
                    if ic[c]:
                        continue
                elif ct[c] == C_CHOC:
                    self.choc_broken = 1
                ct[c], ic[c] = C_NORMAL, 0
            elif je[c]:             # ζελέ κάτω από candy που έσκασε
                je[c] -= 1
                self.score += 100 * self.chain
        for c, v in spawns:
            b[c] = v

    def new_candy(self):
        """nextc: candy, ή υλικό (try_ingredient) με πιθανότητα 1/8."""
        rng = self.rng
        if self.ingr_spawn and not self.ingr_board and rng.random() < 0.125:
            self.ingr_spawn -= 1
            self.ingr_board = 1
            return INGR | rng.randrange(2)
        return rng.randrange(self.ncol)

    def gravity(self):
        """Η βαρύτητα ώς το τέλος: κάθε τμήμα ανάμεσα σε εμπόδια μαζεύεται κάτω·
        αν από πάνω του είναι η κορυφή ή μόνο τρύπες, γεμίζει με καινούργια."""
        b, ct, moved = self.board, self.ctype, False
        for x in range(8):
            y = 7
            while y >= 0:
                if ct[y * 8 + x]:
                    y -= 1
                    continue
                bot = y
                while y >= 0 and not ct[y * 8 + x]:
                    y -= 1
                cells = range((y + 1) * 8 + x, bot * 8 + x + 1, 8)
                items = [b[c] for c in cells if b[c] != EMPTY]
                ne = len(cells) - len(items)
                if not ne:
                    continue
                if y < 0 or self.holes_above[y * 8 + x]:
                    top = [self.new_candy() for _ in range(ne)][::-1]   # το πρώτο πάει πιο κάτω
                    moved = True
                else:
                    top = [EMPTY] * ne
                new = top + items
                for c, v in zip(cells, new):
                    if b[c] != v:
                        b[c] = v
                        moved = True
        return moved

    def diag(self):
        """diag_scan + slide_commit: ένα γλίστρημα, από πάνω-αριστερά πρώτα."""
        b, ct = self.board, self.ctype
        for t in range(63, 7, -1):
            if b[t] != EMPTY or ct[t]:
                continue
            x = t & 7
            for s, ok in ((t - 9, x > 0), (t - 7, x < 7)):
                if ok and not ct[s] and b[s] != EMPTY:
                    b[t], b[s] = b[s], EMPTY
                    return True
        return False

    def collect(self):
        b, ct = self.board, self.ctype
        for c in range(64):
            v = b[c]
            if v != EMPTY and v & INGR and (c >= 56 or ct[c + 8] == C_HOLE):
                b[c] = EMPTY
                self.ingr_board -= 1
                self.ingr_left -= 1
                self.score += 1000 * self.chain

    def settle(self):
        while True:
            self.collect()
            if self.gravity() or self.diag():
                continue
            return

    def resolve(self, res):
        """CLEAR -> FALL -> RESOLVE_FALL ώσπου να μη βρεθεί τίποτα."""
        while res:
            matched, spawns, pts = res
            self.score += pts
            self.clear(matched, spawns)
            self.settle()
            self.chain += 1
            res = self.find_matches(self.board)

    # --- η κίνηση ------------------------------------------------------------
    def swap(self, a, b):
        """st_swap. False αν η ανταλλαγή δεν κάνει τίποτα (πάει πίσω)."""
        bd = self.board
        bd[a], bd[b] = bd[b], bd[a]
        self.sa, self.sb, self.chain, self.choc_broken = a, b, 1, 0
        res = self.combo(bd) or self.find_matches(bd)
        if not res:
            bd[a], bd[b] = bd[b], bd[a]
            return False
        self.moves -= 1
        self.resolve(res)
        return True

    def goal_met(self):
        g = self.goal
        if g == G_SCORE:
            return self.score >= self.stars[0]
        if g in (G_JELLY, G_BOTH) and any(self.jelly):
            return False
        return g == G_JELLY or self.ingr_left <= 0

    def after_move(self):
        """Το τέλος του resolve_fall: σοκολάτα και αδιέξοδο."""
        if not self.choc_broken:
            self.spread_chocolate()
        if not self.has_move():
            self.fill_board()

    def spread_chocolate(self):
        b, ct, start = self.board, self.ctype, self.rng.randrange(64)
        for k in range(64):
            c = (start + k) & 63
            if ct[c] != C_CHOC:
                continue
            for n in NEIGH[c]:
                v = b[n]
                if v == EMPTY or v & INGR or ct[n]:
                    continue
                b[n] = EMPTY
                ct[n], self.icing[n] = C_CHOC, 0
                return

    def sugar_crush(self):
        """Κάθε κίνηση που περίσσεψε: ένα τυχαίο απλό candy γίνεται ριγέ· μετά
        σκάνε όλα τα ειδικά μαζί και οι αλυσίδες μετράνε."""
        b, rng = self.board, self.rng
        while True:
            while self.moves:
                self.moves -= 1
                start = rng.randrange(64)
                for k in range(64):
                    c = (start + k) & 63
                    if b[c] < 6:
                        b[c] |= F_SV if rng.randrange(2) else F_SH
                        break
                else:
                    break           # κανένα απλό: σκάνε τώρα
            matched = [0] * 64
            for c in range(64):
                if SK[b[c]]:
                    matched[c] = 1
            self.chain = 1
            if any(matched):
                pts = self.expand(b, matched)
                self.blocker_damage(matched)
                self.resolve((matched, [], pts))
            else:
                self.chain += 1
            if not self.moves:
                return


# --- το ρομπότ ----------------------------------------------------------------
SPECIAL_BONUS = {BOMB: 700}


def evaluate(g, a, b):
    """Η αξία μιας ανταλλαγής: μόνο το πρώτο βήμα, σε αντίγραφο του ταμπλό."""
    bd = g.board[:]
    bd[a], bd[b] = bd[b], bd[a]
    g.sa, g.sb, g.chain = a, b, 1
    res = g.combo(bd) or g.find_matches(bd)
    if not res:
        return None
    matched, spawns, u = res
    goal, ct, je, ic = g.goal, g.ctype, g.jelly, g.icing
    for c in range(64):
        m = matched[c]
        if not m:
            continue
        if m & M_BLOCK:
            t = ct[c]
            u += 400 if t == C_CHOC else 250 if (t != C_ICING or ic[c] == 1) else 120
        elif je[c]:
            u += 100 + (350 if goal in (G_JELLY, G_BOTH) else 0)
    for c, v in spawns:
        u += SPECIAL_BONUS.get(v, 450 if v & 0x18 == F_WR else 300)
    if goal >= G_INGR:
        for c in range(64):
            if bd[c] != EMPTY and bd[c] & INGR:
                down = sum(1 for k in range(c + 8, 64, 8) if matched[k] and not matched[k] & M_BLOCK)
                u += 400 * down
                # ήδη στη βάση ή λίγο πάνω της: αξίζει πιο πολύ
                if down and (c >> 3) + down >= 7:
                    u += 1500
                # ό,τι σκάει πιο κάτω από το υλικό ανακατεύει τη βάση: εκεί
                # θα βρεθεί η επόμενη κίνηση που το κατεβάζει
                u += 60 * sum(1 for k in range((c | 7) + 1, 64) if matched[k])
    return u


def choose(g, cands, player):
    rng = g.rng
    if player == 'random':
        return rng.choice(cands)
    scored = []
    for a, b in cands:
        u = evaluate(g, a, b)
        if u is not None:
            scored.append((u + rng.random(), a, b))
    if not scored:
        return rng.choice(cands)
    scored.sort(reverse=True)
    if player == 'best':
        return scored[0][1:]
    top = scored[:3]
    w = [0.60, 0.25, 0.15][:len(top)]
    _, a, b = rng.choices(top, weights=w)[0]
    return a, b


def play(lv, seed, player):
    """Μία παρτίδα -> (νίκη, κινήσεις, τελικοί πόντοι, πόντοι χωρίς Sugar Crush
    με όλες τις κινήσεις — μόνο για τις πίστες score)."""
    rng = random.Random(seed)
    g = Game(lv, rng)
    total = g.moves
    result = None
    while g.moves:
        cands = g.candidates()
        if not cands:
            g.fill_board()
            continue
        a, b = choose(g, cands, player)
        if not g.swap(a, b):
            continue
        if result is None and g.goal_met():
            used = total - g.moves
            if g.moves:
                w = g.clone()
                w.sugar_crush()
                final = w.score
            else:
                final = g.score
            result = (True, used, final)
            if g.goal != G_SCORE:
                return result + (None,)
        if g.moves:
            g.after_move()
    if result is None:
        result = (False, total, g.score)
    return result + (g.score if g.goal == G_SCORE else None,)


def _job(args):
    lv, seeds, player = args
    return [play(lv, s, player) for s in seeds]


# --- η αναφορά --------------------------------------------------------------
def pct(xs, p):
    if not xs:
        return 0
    xs = sorted(xs)
    k = (len(xs) - 1) * p
    i = int(k)
    j = min(i + 1, len(xs) - 1)
    return xs[i] + (xs[j] - xs[i]) * (k - i)


def r500(x):
    return max(STAR_UNIT, min(255 * STAR_UNIT, int(round(x / STAR_UNIT)) * STAR_UNIT))


def suggest(lv, res):
    """1 = ό,τι πιάνει το ~85% των νικών, 2 = p50, 3 = p85, ανά 500.

    Στις πίστες score το 1ο αστέρι είναι και ο στόχος: αν άλλαζε, θα άλλαζε
    και το πότε τελειώνει η πίστα. Γι' αυτό εκεί μετράνε οι πόντοι με ΟΛΕΣ
    τις κινήσεις παιγμένες (χωρίς Sugar Crush): 1 = p22 (νίκη ~78%)· με
    στόχο εκεί κοντά σχεδόν όλες οι κινήσεις παίζονται, άρα και τα 2, 3 από
    τους ίδιους πόντους."""
    if lv['goal'] == G_SCORE:
        xs, q = [r[3] for r in res], (0.22, 0.50, 0.85)
    else:
        xs, q = [r[2] for r in res if r[0]], (0.15, 0.50, 0.85)
        if len(xs) < 5:
            return None
    s1 = r500(pct(xs, q[0]))
    s2 = max(r500(pct(xs, q[1])), s1 + STAR_UNIT)
    s3 = max(r500(pct(xs, q[2])), s2 + STAR_UNIT)
    return s1, s2, min(s3, 255 * STAR_UNIT)


def report(lv, res):
    n = len(res)
    wins = [r for r in res if r[0]]
    finals = [r[2] for r in res]
    mv = pct([r[1] for r in wins], 0.5) if wins else 0
    st = [0, 0, 0]
    for won, _, sc, _ in res:
        if won:
            k = sum(sc >= t for t in lv['stars'])
            for i in range(max(1, k)):
                st[i] += 1
    line = (f"{lv['name']:>3} {GOAL_NAMES[lv['goal']]:<10} {lv['moves']:>3} {lv['colours']:>2} "
            f"{100 * len(wins) / n:5.1f} {mv:5.1f}  "
            f"{pct(finals, .25):6.0f} {pct(finals, .5):6.0f} {pct(finals, .75):6.0f}  "
            + ' '.join(f"{100 * s / n:3.0f}" for s in st)
            + f"   {' '.join(str(s) for s in lv['stars'])}")
    s = suggest(lv, res)
    sug = f"      SUGGESTED stars {s[0]} {s[1]} {s[2]}" if s else "      SUGGESTED stars —  (λίγες νίκες)"
    return line + '\n' + sug


def main():
    ap = argparse.ArgumentParser(description='Monte-Carlo δοκιμή των πιστών του Sugar Byte')
    ap.add_argument('levels')
    ap.add_argument('--runs', type=int, default=200)
    ap.add_argument('--only', default='')
    ap.add_argument('--seed', type=int, default=1)
    ap.add_argument('--player', choices=('greedy', 'best', 'random'), default='greedy')
    ap.add_argument('--jobs', type=int, default=os.cpu_count() or 1)
    o = ap.parse_args()

    levels = parse(o.levels)
    for lv in levels:
        check(lv)
    only = {s.strip() for s in o.only.split(',') if s.strip()}
    todo = [lv for lv in levels if not only or lv['name'] in only]

    # κάθε παρτίδα έχει δικό της σπόρο: ίδιο αποτέλεσμα με όσες δουλειές κι αν τρέξουν
    jobs = []
    for li, lv in enumerate(todo):
        seeds = [f"{o.seed}:{lv['name']}:{i}" for i in range(o.runs)]
        chunk = max(1, o.runs // max(1, o.jobs))
        for k in range(0, o.runs, chunk):
            jobs.append((li, (lv, seeds[k:k + chunk], o.player)))

    t0 = time.time()
    if o.jobs > 1:
        import multiprocessing as mp
        with mp.get_context('fork').Pool(o.jobs) as pool:
            outs = pool.map(_job, [j for _, j in jobs])
    else:
        outs = [_job(j) for _, j in jobs]
    results = [[] for _ in todo]
    for (li, _), out in zip(jobs, outs):
        results[li].extend(out)

    print(f"{o.runs} παρτίδες ανά πίστα, παίκτης {o.player}, σπόρος {o.seed}")
    print("lvl goal        mv col  win%  mvW     p25    p50    p75   *1  *2  *3   stars (αρχείο)")
    for lv, res in zip(todo, results):
        print(report(lv, res))
    print(f"({time.time() - t0:.1f} s)")


if __name__ == '__main__':
    main()
