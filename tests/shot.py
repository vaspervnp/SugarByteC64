"""Boots the game headless and saves pictures: python3 tests/shot.py [frames...]
A frame count prefixed with f presses fire for one frame first (f5 = fire, 5 frames)."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from vice import Vice, BUILD  # noqa: E402

with Vice() as vm:
    vm.run_to("frame_done")
    vm.poke("test_mode", 1)
    total = 0
    for a in sys.argv[1:] or ["100"]:
        keys = 0
        if a[0] == "f":
            keys, a = 16, a[1:]
        vm.poke("test_keys", keys)
        vm.run_frames(1)
        vm.poke("test_keys", 0)
        n = int(a)
        vm.run_frames(n)
        total += n + 1
        vm.screenshot(os.path.join(BUILD, f"shot_{total}.png"))
        print("frame", total, "state", vm.peek8("state"), f"shot_{total}.png")
