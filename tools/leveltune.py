#!/usr/bin/env python3
"""Ρυθμίζει κινήσεις και αστέρια των πιστών με το levelsim.py (plan.md §11).

Για κάθε πίστα ένας στόχος: τι ποσοστό νικών πρέπει να έχει το άπληστο ρομπότ
του levelsim — 95% στην πρώτη, ~55% στην τελευταία, και κάθε πέμπτη λίγο πιο
εύκολη για ανάσα. Το ρομπότ δεν βλέπει αλυσίδες, άρα ένας άνθρωπος κερδίζει
πιο συχνά.

  * πίστες "score": οι κινήσεις μένουν· το 1ο αστέρι (ο στόχος) γίνεται ό,τι
    πιάνει το ποσοστό-στόχος των παρτίδων με όλες τις κινήσεις παιγμένες
  * οι άλλες: δυαδική αναζήτηση στις κινήσεις (10-40)
  * μετά, με τις τελικές τιμές, 2 αστέρια = διάμεσος των νικών, 3 = p85

Γράφει τις γραμμές moves/stars του αρχείου στη θέση τους· ό,τι δεν φτάνει τον
στόχο ούτε με 40 κινήσεις το λέει, και θέλει άλλο σχέδιο.

Με --difficulty medium|hard ρυθμίζει τις γραμμές "medium"/"hard" της κάθε
πίστας, ξεκινώντας από τη δυσκολία από κάτω (easy = η ίδια η πίστα): στόχος
15 / 30 μονάδες χαμηλότερα, και ποτέ πιο εύκολη από εκείνη — τουλάχιστον μία
κίνηση λιγότερη ή 500 πόντοι παραπάνω στον στόχο, αστέρια όχι χαμηλότερα.

  leveltune.py levels/levels.txt [--runs N] [--only 21,22] [--dry]
                                 [--difficulty easy|medium|hard]
"""
import argparse
import multiprocessing as mp
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from levels import parse, check, HARDER  # noqa: E402
from levelsim import play, pct, r500, G_SCORE  # noqa: E402

MOVES_MIN, MOVES_MAX = 10, 40


DROP = {'easy': 0.0, 'medium': 0.15, 'hard': 0.30}
MOVES_LOW = {'easy': MOVES_MIN, 'medium': 8, 'hard': 6}


def target(n, total, diff='easy'):
    t = 0.95 - 0.40 * (n - 1) / max(1, total - 1) - DROP[diff]
    if n > 5 and n % 5 == 1:          # 6, 11, 16 ...: ανάσα
        t += 0.05
    return min(0.95 - DROP[diff], t)


def run(pool, lv, runs, tag):
    seeds = [f"tune:{tag}:{lv['name']}:{i}" for i in range(runs)]
    return pool.starmap(play, [(lv, s, 'greedy') for s in seeds], chunksize=max(1, runs // 32))


def winrate(res):
    return sum(r[0] for r in res) / len(res)


def tune(pool, lv, want, runs, diff='easy', prev=None):
    """prev: the difficulty below (moves, stars) - this one must be harder"""
    lv = dict(lv)
    note = ''
    if prev:
        lv['moves'], lv['stars'] = prev['moves'], list(prev['stars'])
    if lv['goal'] == G_SCORE:
        res = run(pool, lv, runs, 'full')
        full = sorted(r[3] for r in res)
        s1 = r500(pct(full, 1 - want))
        if prev:
            s1 = max(s1, prev['stars'][0] + 500)
        lv['stars'] = [s1, s1 + 500, s1 + 1000]
    elif prev:
        lo, hi = MOVES_LOW[diff], max(MOVES_LOW[diff], prev['moves'] - 1)
        lv['moves'] = lo
        if winrate(run(pool, lv, runs, 'm')) >= want:
            hi = lo
        while lo < hi:
            mid = (lo + hi) // 2
            lv['moves'] = mid
            if winrate(run(pool, lv, runs, 'm')) >= want:
                hi = mid
            else:
                lo = mid + 1
        lv['moves'] = hi
    else:
        lo, hi = MOVES_MIN, MOVES_MAX
        lv['moves'] = hi
        if winrate(run(pool, lv, runs, 'm')) < want:
            note = f'ούτε με {hi} κινήσεις'
        else:
            while lo < hi:
                mid = (lo + hi) // 2
                lv['moves'] = mid
                if winrate(run(pool, lv, runs, 'm')) >= want:
                    hi = mid
                else:
                    lo = mid + 1
            lv['moves'] = hi
    res = run(pool, lv, runs, 'final')
    wins = sorted(r[2] for r in res if r[0])
    if len(wins) >= 5:
        s1 = lv['stars'][0] if lv['goal'] == G_SCORE else r500(pct(wins, 0.15))
        s2 = max(r500(pct(wins, 0.50)), s1 + 500)
        s3 = max(r500(pct(wins, 0.85)), s2 + 500)
        lv['stars'] = [s1, s2, s3]
    if prev:
        lv['stars'] = [max(a, b) for a, b in zip(lv['stars'], prev['stars'])]
        for i in (1, 2):
            lv['stars'][i] = max(lv['stars'][i], lv['stars'][i - 1] + 500)
    return lv, winrate(res), note


def rewrite(path, tuned, diff='easy'):
    text = open(path, encoding='utf-8').read()
    for lv in tuned:
        m = re.search(rf"(?m)^level {lv['name']}\n(.*?)(?=^level |\Z)", text, re.S)
        blk = m.group(0)
        if diff == 'easy':
            blk = re.sub(r"(?m)^moves .*$", f"moves {lv['moves']}", blk)
            blk = re.sub(r"(?m)^stars .*$", 'stars ' + ' '.join(map(str, lv['stars'])), blk)
        else:
            line = f"{diff:<8}{lv['moves']} " + ' '.join(map(str, lv['stars']))
            if re.search(rf"(?m)^{diff} ", blk):
                blk = re.sub(rf"(?m)^{diff} .*$", line, blk)
            else:                       # after the stars, or after medium
                after = 'medium' if diff == 'hard' and re.search(r"(?m)^medium ", blk) else 'stars'
                blk = re.sub(rf"(?m)^({after} .*)$", lambda m: m.group(1) + '\n' + line, blk, count=1)
        text = text[:m.start()] + blk + text[m.end():]
    open(path, 'w', encoding='utf-8').write(text)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('levels')
    ap.add_argument('--runs', type=int, default=160)
    ap.add_argument('--only', default='')
    ap.add_argument('--dry', action='store_true')
    ap.add_argument('--difficulty', choices=('easy',) + HARDER, default='easy')
    o = ap.parse_args()
    levels = parse(o.levels)
    for lv in levels:
        check(lv)
    only = {s for s in o.only.split(',') if s}
    tuned = []
    with mp.get_context('fork').Pool(os.cpu_count() or 1) as pool:
        for n, lv in enumerate(levels, 1):
            if only and lv['name'] not in only:
                continue
            d = o.difficulty
            prev = None
            if d != 'easy':
                below = ('easy',) + HARDER
                prev = lv
                for b in below[1:below.index(d)]:
                    prev = lv.get(b, prev)
            want = target(n, len(levels), d)
            t, got, note = tune(pool, lv, want, o.runs, d, prev)
            tuned.append(t)
            was = (prev or lv)['moves']
            print(f"{lv['name']:>3} {d} στόχος {want:4.0%} -> {got:4.0%}  moves {was:>2} -> {t['moves']:>2}  "
                  f"stars {' '.join(map(str, t['stars']))}  {note}", flush=True)
    if not o.dry:
        rewrite(o.levels, tuned, o.difficulty)


if __name__ == '__main__':
    main()
