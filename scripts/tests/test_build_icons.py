"""Unit tests for scripts/icons/build_icons.py. Run: python3 -m unittest discover -s scripts/tests -p 'test_*.py'"""
import math
import pathlib
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "icons"))
import build_icons as bi  # noqa: E402


def end(cmds):
    return cmds[-1][-2:]


class PathParsing(unittest.TestCase):
    def test_relative_and_shorthand_commands(self):
        cmds = bi.parse_path("m2 3 l4 0 h1 v2 H2 V3 z")
        self.assertEqual(cmds[0], ("M", 2.0, 3.0))
        self.assertEqual([c[0] for c in cmds], ["M", "L", "L", "L", "L", "L", "Z"])
        self.assertEqual(cmds[1][1:], (6.0, 3.0))
        self.assertEqual(cmds[3][1:], (7.0, 5.0))

    def test_implicit_lineto_after_moveto(self):
        cmds = bi.parse_path("M1 1 2 2 3 3")
        self.assertEqual([c[0] for c in cmds], ["M", "L", "L"])

    def test_smooth_cubic_reflects_previous_control(self):
        cmds = bi.parse_path("M0 0 C1 1 2 1 3 0 S5 -1 6 0")
        self.assertEqual(cmds[2][1:3], (4.0, -1.0))

    def test_quarter_arc_endpoints_and_radius(self):
        cmds = bi.parse_path("M10 0 A10 10 0 0 1 0 10")
        self.assertEqual(len(cmds), 2)
        self.assertAlmostEqual(end(cmds)[0], 0, places=6)
        self.assertAlmostEqual(end(cmds)[1], 10, places=6)
        # The curve's midpoint must lie on the circle (cubic approximation error < 0.03%).
        _, x1, y1, x2, y2, x, y = cmds[1]
        mx = 0.125 * 10 + 0.375 * x1 + 0.375 * x2 + 0.125 * x
        my = 0.125 * 0 + 0.375 * y1 + 0.375 * y2 + 0.125 * y
        self.assertAlmostEqual(math.hypot(mx, my), 10, delta=0.003)

    def test_large_arc_splits_into_quarters(self):
        cmds = bi.parse_path("M10 0 A10 10 0 1 1 -10 0.001")
        self.assertGreaterEqual(len([c for c in cmds if c[0] == "C"]), 2)

    def test_bad_path_is_rejected(self):
        with self.assertRaises(ValueError):
            bi.parse_path("10 10 L 5")


class Shapes(unittest.TestCase):
    def test_circle_and_rect_are_closed(self):
        self.assertEqual(bi.circle(12, 12, 3)[-1], ("Z",))
        self.assertEqual(bi.rounded_rect(1, 1, 10, 6, 2)[-1], ("Z",))

    def test_rect_radius_clamped(self):
        self.assertEqual(bi.rounded_rect(0, 0, 4, 4, 9)[0], ("M", 2.0, 0.0))


class Sources(unittest.TestCase):
    def test_all_icon_sources_load(self):
        swift, icons, menubar = bi.generate()
        self.assertIn("mark", icons)
        self.assertEqual(set(menubar), {"tracking", "paused", "off", "away", "needsAttention"})
        self.assertIn("public enum GlintIconName", swift)

    def test_generated_swift_is_up_to_date(self):
        self.assertEqual(bi.main(["--check"]), 0)


if __name__ == "__main__":
    unittest.main()
