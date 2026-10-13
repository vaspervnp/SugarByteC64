"""Helpers for the tests: a game running, the board, moves."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from vice import Vice, BUILD  # noqa: E402,F401

J_UP, J_DOWN, J_LEFT, J_RIGHT, J_FIRE, J_MUSIC, J_ESC = 1, 2, 4, 8, 16, 32, 64
EMPTY, BOMB = 7, 6
STATES = {0: "IDLE", 1: "SWAP", 2: "UNSWAP", 3: "CLEAR", 4: "FALL", 5: "OVER", 6: "BEAM", 7: "WIN",
          8: "CODE", 9: "MENU", 10: "SCORES", 11: "CRUSH", 12: "SLIDE"}


def mcol(v):
    return 0xFF if v & 0x20 else v & 7


def line_at(b, i):
    c = mcol(b[i])
    if c >= 6:
        return False
    x, y = i % 8, i // 8
    n = 1
    k = x - 1
    while k >= 0 and mcol(b[y * 8 + k]) == c:
        n, k = n + 1, k - 1
    k = x + 1
    while k < 8 and mcol(b[y * 8 + k]) == c:
        n, k = n + 1, k + 1
    if n >= 3:
        return True
    n = 1
    k = y - 1
    while k >= 0 and mcol(b[k * 8 + x]) == c:
        n, k = n + 1, k - 1
    k = y + 1
    while k < 8 and mcol(b[k * 8 + x]) == c:
        n, k = n + 1, k + 1
    return n >= 3


def moves(b):
    """every swap that makes a match (as has_move sees it)"""
    out = []
    for e in range(64):
        for d in ([e + 1] if e % 8 != 7 else []) + ([e + 8] if e < 56 else []):
            p, q = b[e], b[d]
            if p == EMPTY or q == EMPTY:
                continue
            if p == BOMB or q == BOMB:
                if not ((p | q) & 0x20 and not (p == BOMB and q == BOMB)):
                    out.append((e, d))
                continue
            b2 = list(b)
            b2[e], b2[d] = q, p
            if line_at(b2, e) or line_at(b2, d):
                out.append((e, d))
    return out


class Game:
    def __init__(self, level=0, vm=None):
        self.vm = vm or Vice()
        vm = self.vm
        vm.run_to("frame_done")
        vm.poke("test_mode", 1)
        vm.poke("cur_level", level)
        self.press(J_FIRE)                      # PLAY
        self.wait_state(0)

    def close(self):
        self.vm.close()

    def press(self, keys, frames=1):
        self.vm.poke("test_keys", keys)
        self.vm.run_frames(frames)
        self.vm.poke("test_keys", 0)
        self.vm.run_frames(1)

    def state(self):
        return self.vm.peek8("state")

    def board(self):
        return list(self.vm.peek("BOARD" if "BOARD" in self.vm.labels else 0x200, 64))

    def wait_state(self, s, limit=3000):
        for _ in range(limit):
            if self.state() == s:
                return True
            self.vm.run_frames(1)
        raise AssertionError(f"state {STATES.get(self.state())} instead of {STATES[s]}")

    def swap(self, a, b):
        """cursor to a, fire, cursor to b, fire"""
        self.vm.poke("cursor", a)
        self.press(J_FIRE)
        self.vm.poke("cursor", b)
        self.press(J_FIRE)

    def set_board(self, values, cells=None):
        self.vm.poke(0x200, bytes(values))
        if cells is not None:
            self.vm.poke(0x280, bytes(cells))
        self.vm.poke("lv_goal", 0xFF)
        self.vm.poke("ingr_spawn", 0)
        # every cell redrawn through the dirty list
        self.vm.poke(0x2C0, bytes(range(64)))
        cells_now = list(self.vm.peek(0x280, 64))
        self.vm.poke(0x280, bytes(c | 0x80 for c in cells_now))
        self.vm.poke("dq_head", 0)
        self.vm.poke("dq_tail", 0)
        self.vm.poke("dq_n", 64)
        self.vm.run_frames(20)

    def shot(self, name):
        return self.vm.screenshot(os.path.join(BUILD, name))


CHARS = {"*": BOMB, "@": 0x20, "%": 0x21, ".": EMPTY}


def board_from(rows):
    """'0'-'5' plain, 'A'-'F' striped across, 'a'-'f' striped down, 'u'-'z'
    wrapped, '*' bomb, '@' cherry, '%' nut, '.' empty"""
    out = []
    for r in rows.split():
        for ch in r:
            if ch in CHARS:
                out.append(CHARS[ch])
            elif ch.isdigit():
                out.append(int(ch))
            elif "A" <= ch <= "F":
                out.append(0x08 | (ord(ch) - 65))
            elif "a" <= ch <= "f":
                out.append(0x10 | (ord(ch) - 97))
            else:
                out.append(0x18 | (ord(ch) - ord("u")))
    assert len(out) == 64
    return out


BASE = "01234501 23450123 45012345 01234501 23450123 45012345 01234501 23450123"
