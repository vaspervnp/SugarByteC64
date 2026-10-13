"""The specials and their combinations, on boards set up for them."""

import unittest

from game import Game, board_from, J_FIRE

ROWS = "01234501 23450123 45012345 01234501 23450123 45012345".split()


def b(*last):
    return board_from(" ".join(list(ROWS[:8 - len(last)]) + list(last)))


class SpecialsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.g = Game()

    @classmethod
    def tearDownClass(cls):
        cls.g.close()

    def play(self, board, a, c, rows=None):
        g = self.g
        g.wait_state(0)
        if rows is not None:
            board = board_from(rows)
        g.set_board(board)
        g.swap(a, c)

    def until(self, state, limit=400):
        for _ in range(limit):
            if self.g.state() == state:
                return
            self.g.vm.run_frames(1)
        self.fail(f"no state {state}")

    def test_four_makes_striped(self):
        self.play(None, 50, 58, "01234501 23450123 45012345 01234501 23450123 45012345 01034501 00405123")
        self.until(3)
        self.assertEqual(self.g.vm.peek8("nspawn"), 1)
        self.assertEqual(list(self.g.vm.peek("spawns", 2)), [58, 0x08])
        self.g.wait_state(0)

    def test_striped_beam(self):
        self.play(None, 50, 58, "01234501 23450123 45012345 01234501 23450123 45012345 01034501 A0450123")
        self.until(6)
        self.assertEqual(self.g.vm.peek8("nbeams"), 1)
        self.assertEqual(self.g.vm.peek8("beams"), 7)
        matched = self.g.vm.peek(0x240, 64)
        self.assertTrue(all(matched[56:64]))
        self.g.shot("test_beam.png")
        self.g.wait_state(0)

    def test_bomb(self):
        rows = "01234501 23450123 45012345 012*4501 23450123 45012345 01234501 23450123"
        fours = rows.replace(" ", "").count("4")
        self.play(None, 27, 28, rows)
        self.until(3)
        self.assertEqual(self.g.vm.peek8("clear_n"), fours + 1)
        self.g.wait_state(0)

    def test_striped_striped(self):
        self.play(None, 27, 28, "01234501 23450123 45012345 012Ab501 23450123 45012345 01234501 23450123")
        self.until(6)
        self.assertEqual(self.g.vm.peek8("nbeams"), 2)
        self.g.wait_state(0)

    def test_wrapped_wrapped(self):
        self.play(None, 27, 28, "01234501 23450123 45012345 012uv501 23450123 45012345 01234501 23450123")
        self.until(3)
        self.assertEqual(self.g.vm.peek8("clear_n"), 25)
        self.g.wait_state(0)

    def test_invalid_swap_comes_back(self):
        g = self.g
        g.wait_state(0)
        g.set_board(board_from("01234501 23450123 45012345 01234501 23450123 45012345 01234501 23450123"))
        before = g.board()
        moves = g.vm.peek8("moves")
        g.swap(0, 1)
        self.until(2)
        g.wait_state(0)
        self.assertEqual(g.board(), before)
        self.assertEqual(g.vm.peek8("moves"), moves)


if __name__ == "__main__":
    unittest.main()
