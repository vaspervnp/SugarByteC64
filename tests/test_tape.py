"""The tape: the KERNAL loads the boot file, the turbo the game, the menu runs."""

import os
import unittest

from vice import Vice, BUILD


class TapeTest(unittest.TestCase):
    def test_loads(self):
        with Vice(image=os.path.join(BUILD, "sugar.tap"), boot_timeout=60) as vm:
            vm.run_to("frame_done", timeout=600)
            self.assertEqual(vm.peek8("state"), 9)


if __name__ == "__main__":
    unittest.main()
