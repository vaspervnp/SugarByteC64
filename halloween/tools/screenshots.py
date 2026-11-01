#!/usr/bin/env python3
"""halloween/docs/*.png from a headless VICE (make screenshots, in halloween/):
the menu, a few levels, every candy and cell on one board, the beams, the
Sugar Crush. SUGAR_BUILD (the Makefile sets it) says which build to run."""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tests"))
from game import Game, board_from, moves, J_FIRE, J_ESC  # noqa: E402

OUT = os.path.join(HERE, "..", "docs")


def save(g, name):
    g.vm.screenshot(os.path.join(OUT, name))
    print("screenshots", name)


def level(g, n):
    g.press(J_ESC)
    g.wait_state(9)
    g.vm.poke("menu_sel", 0)
    g.vm.poke("cur_level", n)
    g.press(J_FIRE)
    g.wait_state(0)
    g.vm.run_frames(30)


def main():
    os.makedirs(OUT, exist_ok=True)
    g = Game(level=0)
    g.press(J_ESC)
    g.wait_state(9)
    g.vm.run_frames(20)
    save(g, "menu.png")
    for n in (16, 19, 55):                  # jelly + skulls, tombstones, cobwebs
        level(g, n)
        save(g, f"level-{n + 1:02d}.png")
    # every candy and every cell: the six, striped, wrapped, the cauldron, the
    # skull and the spider; slime, cobwebs, a tombstone, the spiral, a hole
    level(g, 0)
    cells = [0] * 64
    for i, c in ((48, 0x20), (56, 0x40), (49, 0x40), (57, 0x20), (58, 0x0A), (59, 0x12), (60, 0x1A),
                 (61, 3), (62, 4), (63, 1)):
        cells[i] = c
    b = board_from("012345** ABCDEFab cdefuvwx yz@%0123 45012345 01234501 23453450 23450123")
    for i in (58, 59, 60, 61, 62, 63):
        b[i] = 7
    g.set_board(b, cells)
    g.vm.run_frames(20)
    save(g, "candies.png")
    # two striped candies: the beams
    level(g, 23)
    g.set_board(board_from("01234501 23450123 45012345 01Ab4501 23450123 45012345 01034501 A0450123"))
    g.swap(26, 27)
    for _ in range(12):
        g.vm.run_frames(1)
        if g.state() == 6 and g.vm.peek8("anim_k") == 3:
            break
    save(g, "beams.png")
    g.wait_state(0)
    level(g, 0)                             # Sugar Crush: the goal met
    g.vm.poke("lv_star1", b"\0\0")
    a, c = moves(g.board())[0]
    g.swap(a, c)
    g.wait_state(11, 6000)
    g.vm.run_frames(50)
    save(g, "sugar-crush.png")
    g.close()


if __name__ == "__main__":
    main()
