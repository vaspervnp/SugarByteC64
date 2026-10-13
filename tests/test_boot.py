"""Boot: the menu, the IRQ at 50 Hz, the memory set-up."""

import unittest

from vice import Vice


class BootTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.vm = Vice()
        cls.vm.run_to("frame_done")

    @classmethod
    def tearDownClass(cls):
        cls.vm.close()

    def test_menu(self):
        self.assertEqual(self.vm.peek8("state"), 9)

    def test_memory_config(self):
        self.assertEqual(self.vm.peek8(0x01) & 0x07, 0x05)     # all ROMs out, I/O in

    def test_pal(self):
        width, height, *_ = self.vm.display()
        self.assertEqual(height, 312)

    def test_one_frame_per_irq(self):
        before = self.vm.peek16("frame_counter")
        self.vm.run_frames(50)
        self.assertEqual(self.vm.peek16("frame_counter") - before, 50)

    def test_bitmap_mode(self):
        self.assertEqual(self.vm.peek8(0xd011) & 0x20, 0x20)
        self.assertEqual(self.vm.peek8(0xd016) & 0x10, 0x10)
        self.assertEqual(self.vm.peek8(0xd018) & 0xfe, 0x08)       # (bit 0 reads 1)


if __name__ == "__main__":
    unittest.main()
