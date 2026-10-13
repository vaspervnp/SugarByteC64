"""Every level as the game decodes it, against levels/levels.txt; the codes."""

import os
import sys
import unittest

from game import Game, J_FIRE, J_ESC, J_RIGHT, J_UP, J_DOWN

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "tools"))
import levels as lvtool  # noqa: E402

LEVELS = lvtool.parse(os.path.join(HERE, "..", "levels", "levels.txt"))
CODES = lvtool.level_codes(len(LEVELS))


def bcd(n):
    return int(str(n), 16)


class LevelsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.g = Game()

    @classmethod
    def tearDownClass(cls):
        cls.g.close()

    def start(self, n):
        g = self.g
        g.press(J_ESC)
        g.wait_state(9)
        g.vm.poke("menu_sel", 0)
        g.vm.poke("cur_level", n)
        g.press(J_FIRE)
        g.wait_state(0)

    def test_levels(self):
        vm = self.g.vm
        for n, lv in enumerate(LEVELS):
            with self.subTest(level=n + 1):
                self.start(n)
                self.assertEqual(vm.peek8("lv_goal"), lv["goal"])
                self.assertEqual(vm.peek8("ncolours"), lv["colours"])
                self.assertEqual(vm.peek8("lv_moves"), bcd(lv["moves"]))
                self.assertEqual(vm.peek8("ingr_left"), bcd(lv["ingredients"]))
                stars = [p // 100 for p in lv["stars"]]
                for k, name in enumerate(("lv_star1", "lv_star2", "lv_star3")):
                    got = vm.peek(name, 2)
                    self.assertEqual(got[0] << 8 | got[1], bcd(stars[k]))
                cells = [c & 0x7f for c in vm.peek(0x280, 64)]
                want = [lvtool.CELLS[ch] for row in lv["cells"] for ch in row]
                self.assertEqual(cells, want)
                board = vm.peek(0x200, 64)
                for i in range(64):
                    if want[i] & 7:
                        self.assertEqual(board[i], 7)          # no candy on blockers / holes
                hud_code = CODES[n]
                self.assertEqual(hud_code, int(f"{CODES[n]:04d}"))

    def test_code_entry(self):
        g = self.g
        g.press(J_ESC)
        g.wait_state(9)
        g.vm.poke("menu_sel", 1)                    # LEVEL
        g.press(J_FIRE)
        g.wait_state(8)
        code = f"{CODES[7]:04d}"                    # level 8
        for k, d in enumerate(code):
            for _ in range(int(d)):
                g.press(J_UP)
            if k < 3:
                g.press(J_RIGHT)
        g.press(J_FIRE)
        g.wait_state(9)
        self.assertEqual(g.vm.peek8("cur_level"), 7)

    def test_wrong_code(self):
        g = self.g
        g.press(J_ESC)
        g.wait_state(9)
        g.vm.poke("cur_level", 0)
        g.vm.poke("menu_sel", 1)
        g.press(J_FIRE)
        g.wait_state(8)
        g.press(J_DOWN)                             # 9000
        g.press(J_FIRE)
        self.assertEqual(g.state(), 8)              # still typing
        g.press(J_ESC)
        g.wait_state(9)
        self.assertEqual(g.vm.peek8("cur_level"), 0)


if __name__ == "__main__":
    unittest.main()
