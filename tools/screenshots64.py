#!/usr/bin/env python3
"""docs/screenshots/*.png from a headless VICE (make screenshots)."""
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.join(ROOT, "tests"))
from game import Game, board_from, J_FIRE, J_ESC  # noqa: E402

OUT = os.path.join(ROOT, "docs", "screenshots")


def save(g, name):
    g.vm.screenshot(os.path.join(OUT, name))
    print("screenshots", name)


def main():
    os.makedirs(OUT, exist_ok=True)
    g = Game(level=4)                                   # jelly
    g.vm.run_frames(30)
    save(g, "02_jelly.png")
    g.press(J_ESC)
    g.wait_state(9)
    g.vm.run_frames(20)
    save(g, "01_menu.png")
    g.vm.poke("cur_level", 23)
    g.press(J_FIRE)
    g.wait_state(0)
    g.vm.run_frames(30)
    save(g, "03_level24.png")
    g.set_board(board_from("01234501 23450123 45012345 01Ab4501 23450123 45012345 01034501 A0450123"))
    g.swap(26, 27)
    for _ in range(12):
        g.vm.run_frames(1)
        if g.state() == 6 and g.vm.peek8("anim_k") == 3:
            break
    save(g, "04_beams.png")
    g.wait_state(0)
    g.press(J_ESC)
    g.wait_state(9)
    g.vm.poke("menu_sel", 3)
    g.press(J_FIRE)
    g.wait_state(10)
    g.vm.run_frames(5)
    save(g, "05_scores.png")
    manual_shots(g)
    g.close()


def manual_shots(g):
    """the manual's pictures: docs/*.png"""
    docs = os.path.join(ROOT, "docs")

    def level(n):
        g.press(J_ESC)
        g.wait_state(9)
        g.vm.poke("menu_sel", 0)
        g.vm.poke("cur_level", n)
        g.press(J_FIRE)
        g.wait_state(0)
        g.vm.run_frames(30)

    g.vm.poke("cur_level", 0)
    g.vm.poke("menu_sel", 0)
    g.press(J_ESC)
    g.wait_state(9)
    g.vm.run_frames(20)
    g.vm.screenshot(os.path.join(docs, "menu.png"))
    for n in (0, 16, 55):
        level(n)
        g.vm.screenshot(os.path.join(docs, f"level-{n + 1:02d}.png"))
    level(0)                                            # Sugar Crush: the goal met
    g.vm.poke("lv_star1", b"\0\0")
    from game import moves
    a, c = moves(g.board())[0]
    g.swap(a, c)
    g.wait_state(11, 6000)
    g.vm.run_frames(50)
    g.vm.screenshot(os.path.join(docs, "sugar-crush.png"))
    print("screenshots docs/menu.png, level-01/17/56.png, sugar-crush.png")


if __name__ == "__main__":
    main()
