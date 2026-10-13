"""The special cells (jelly, icing, chocolate, licorice), the ingredients,
the Sugar Crush."""

import unittest

from game import Game, board_from

ROW6 = "01034501"           # cell 50 = 0: swapped with 58 makes 0 0 0 at 56-58
ROW7 = "00450123"
BASE = "01234501 23450123 45012345 01234501 23450123 45012345 "


def cells(**at):
    c = [0] * 64
    for k, v in at.items():
        c[int(k[1:])] = v
    return c


class CellsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.g = Game()

    @classmethod
    def tearDownClass(cls):
        cls.g.close()

    def move(self, board, cl):
        g = self.g
        g.wait_state(0)
        g.set_board(board, cl)
        g.swap(50, 58)
        g.wait_state(0)
        return list(g.vm.peek(0x280, 64))

    def test_jelly(self):
        b = board_from(BASE + ROW6 + " " + ROW7)
        before = self.g.vm.peek("score", 3)
        after = self.move(b, cells(c56=0x20, c57=0x40, c58=0x20))
        self.assertEqual(after[56] & 0x60, 0)
        self.assertEqual(after[57] & 0x60, 0x20)              # two layers: one left
        self.assertEqual(after[58] & 0x60, 0)

    def test_icing_and_licorice(self):
        b = board_from(BASE + ROW6 + " 000.0123")
        b[59] = 7
        after = self.move(b, cells(c59=0x12))                 # icing, 2 layers
        self.assertEqual(after[59] & 0x1f, 0x0a)              # 1 layer
        b = board_from(BASE + ROW6 + " 004.0123")
        after = self.move(b, cells(c59=0x04))                 # licorice
        self.assertEqual(after[59] & 7, 0)

    def test_chocolate_spreads(self):
        b = board_from(BASE + ROW6 + " " + ROW7)
        b[0] = 7
        after = self.move(b, cells(c0=0x03))
        self.assertEqual(sum(1 for c in after if c & 7 == 3), 2)

    def test_ingredient_collected(self):
        g = self.g
        b = board_from("01234501 23450123 45012345 01234501 23450123 45012345 @1034501 00450123")
        g.wait_state(0)
        g.set_board(b, [0] * 64)
        g.vm.poke("ingr_left", 1)
        g.vm.poke("ingr_board", 1)
        g.swap(50, 58)
        g.wait_state(0)
        self.assertEqual(g.vm.peek8("ingr_left"), 0)
        self.assertNotIn(0x20, g.board())

    def test_sugar_crush(self):
        g = self.g
        g.wait_state(0)
        g.set_board(board_from(BASE + ROW6 + " " + ROW7), [0] * 64)
        g.vm.poke("lv_goal", 0)                              # points, and 0 reach it
        g.vm.poke("lv_star1", b"\0\0")
        g.vm.poke("moves", 0x05)
        g.swap(50, 58)
        g.wait_state(11)                                     # CRUSH
        g.wait_state(7, 6000)                                # WIN
        self.assertEqual(g.vm.peek8("moves"), 0)
        g.shot("test_win.png")
        g.press(16)                                          # the next level
        g.wait_state(0)
        self.assertEqual(g.vm.peek8("cur_level"), 1)


if __name__ == "__main__":
    unittest.main()
