"""The SID: the tunes play, the effects take voice 3, M turns the music off."""

import os
import sys
import unittest

from game import Game, J_MUSIC

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "tools"))
import mkmusic64  # noqa: E402

SONG = mkmusic64.load_all()
SFX = {e["name"]: i + 1 for i, e in enumerate(SONG.effects)}


class SoundTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.g = Game()

    @classmethod
    def tearDownClass(cls):
        cls.g.close()

    def test_game_tune(self):
        vm = self.g.vm
        self.assertEqual(vm.peek8("snd_tune"), vm.peek8("snd_want"))
        freqs = set()
        for _ in range(40):
            vm.run_frames(4)
            freqs.add(vm.peek8("sid_freq_hi"))
        self.assertGreater(len(freqs), 3)                    # the melody moves

    def test_effect_on_voice3(self):
        vm = self.g.vm
        vm.poke("sfx_request", SFX["collect"])
        vm.run_frames(2)
        self.assertEqual(vm.peek8("sfx_on"), 1)
        vm.run_frames(40)
        self.assertEqual(vm.peek8("sfx_on"), 0)

    def test_music_toggle(self):
        g = self.g
        on = g.vm.peek8("mus_on")
        g.press(J_MUSIC)
        self.assertEqual(g.vm.peek8("mus_on"), on ^ 1)
        g.press(J_MUSIC)
        self.assertEqual(g.vm.peek8("mus_on"), on)


if __name__ == "__main__":
    unittest.main()
