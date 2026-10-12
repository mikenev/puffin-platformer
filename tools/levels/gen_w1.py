#!/usr/bin/env python3
"""Generates scripts/world/w1_maps.gd from the World 1 layouts below.

Run: python3 tools/levels/gen_w1.py   (then re-run tests/test_levels.gd)

Legend (one char = one 16x16 tile; maps are 14 rows = one 224px screen tall):
  #  solid ground (auto-tiled: grass on top, dirt below)   S  sand ground (auto: sand top)
  =  one-way platform     ~  water (decor, no collision)    P  player spawn
  G  goal flag (bottom tile the flag stands on is below it) C  checkpoint
  f  fish collectible
  e  enemy_spawn kind=walker    w  enemy_spawn kind=flyer   k  enemy_spawn kind=crab
  o  powerup_spawn kind=fish_power
Jump metrics (Puffin defaults, PR #1): walk jump ~4 tiles high / ~4 tiles long,
run jump ~4.8 tiles high / ~6.5 tiles long. Layouts stay within: rise <= 3 tiles,
gaps <= 3 tiles (1-1/1-2), <= 4 tiles with a run-up (1-3/1-4).
"""
import os

H = 14

class Map:
    def __init__(self, width):
        self.w = width
        self.g = [["."] * width for _ in range(H)]

    def put(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < H:
            self.g[y][x] = c

    def ground(self, x0, x1, top=12, c="#"):
        """Solid columns x0..x1 inclusive from row `top` to the bottom."""
        for x in range(x0, x1 + 1):
            for y in range(top, H):
                self.put(x, y, c)

    def block(self, x0, x1, y0, y1, c="#"):
        for x in range(x0, x1 + 1):
            for y in range(y0, y1 + 1):
                self.put(x, y, c)

    def plat(self, x0, x1, y):
        for x in range(x0, x1 + 1):
            self.put(x, y, "=")

    def fish_line(self, x0, x1, y, step=1):
        for x in range(x0, x1 + 1, step):
            self.put(x, y, "f")

    def fish_arc(self, x0, y_base, n=5):
        ys = [0, -1, -2, -1, 0] if n == 5 else [0, -1, -1, 0]
        for i in range(n):
            self.put(x0 + i, y_base + ys[i], "f")

    def water(self, x0, x1):
        for x in range(x0, x1 + 1):
            if self.g[H - 1][x] == ".":
                self.put(x, H - 1, "~")

    def rows(self):
        return ["".join(r) for r in self.g]


def level_1_1():
    # Tutorial: flat ground, low steps, 2-tile gaps, lots of fish.
    m = Map(150)
    m.ground(0, 30)
    m.put(3, 11, "P")
    m.fish_line(8, 12, 10)
    m.block(16, 17, 11, 11)               # 1-tile step
    m.block(22, 24, 10, 11)               # 2-tile step
    m.fish_arc(21, 8)
    m.put(28, 11, "e")
    m.ground(33, 60)                      # gap 31-32 (2 tiles)
    m.water(31, 32)
    m.fish_arc(30, 9)
    m.plat(38, 41, 9)
    m.fish_line(38, 41, 8)
    m.put(40, 8, "o")
    m.block(46, 47, 11, 11)
    m.block(48, 49, 10, 11)
    m.block(50, 51, 9, 11)                # staircase up 3
    m.ground(54, 60, 11)
    m.put(57, 10, "e")
    m.ground(63, 95)                      # gap 61-62
    m.water(61, 62)
    m.fish_arc(60, 9)
    m.fish_line(68, 74, 11, 2)
    m.plat(76, 79, 9)
    m.plat(82, 85, 7)
    m.fish_line(82, 85, 6)
    m.put(90, 11, "e")
    m.ground(98, 149)                     # gap 96-97
    m.water(96, 97)
    m.fish_arc(95, 9)
    m.block(104, 106, 10, 11)
    m.put(110, 11, "e")
    m.fish_line(114, 120, 11)
    m.block(126, 127, 11, 11)
    m.block(128, 129, 10, 11)
    m.block(130, 131, 9, 11)
    m.block(132, 133, 8, 11)
    m.ground(134, 149, 12)
    m.put(142, 11, "G")
    return m.rows()


def level_1_2():
    # One-way platforms, taller steps, 3-tile gaps, first flyers.
    m = Map(170)
    m.ground(0, 18)
    m.put(2, 11, "P")
    m.plat(8, 11, 9)
    m.fish_line(8, 11, 8)
    m.ground(22, 40)                      # gap 19-21 (3)
    m.water(19, 21)
    m.fish_arc(18, 9)
    m.block(27, 29, 9, 11)                # 3-tile wall
    m.put(34, 11, "e")
    m.plat(32, 35, 8)
    m.plat(36, 39, 5)
    m.fish_line(36, 39, 4)
    m.ground(44, 70, 10)                  # gap 41-43, land 2 tiles higher
    m.water(41, 43)
    m.put(50, 6, "w")
    m.fish_line(48, 56, 9, 2)
    m.put(60, 9, "o")
    m.plat(62, 65, 7)
    m.put(67, 9, "e")
    m.ground(74, 100)                     # drop down, gap 71-73
    m.water(71, 73)
    m.plat(78, 80, 9)
    m.plat(83, 85, 7)
    m.plat(88, 90, 5)
    m.fish_line(88, 90, 4)
    m.plat(93, 96, 8)
    m.put(96, 11, "k")
    m.ground(104, 125, 11)                # gap 101-103
    m.water(101, 103)
    m.fish_arc(100, 8)
    m.put(110, 7, "w")
    m.block(115, 116, 8, 10)
    m.fish_line(115, 116, 7)
    m.put(121, 10, "e")
    m.ground(129, 169)                    # gap 126-128
    m.water(126, 128)
    m.fish_arc(125, 9)
    m.put(135, 11, "e")
    m.block(140, 142, 9, 11)
    m.plat(145, 148, 7)
    m.fish_line(145, 148, 6)
    m.block(150, 152, 9, 11)
    m.put(162, 11, "G")
    return m.rows()


def level_1_3():
    # Beach: sand, sea pits that need a run (4 tiles), floating islands, checkpoint.
    m = Map(190)
    m.ground(0, 16, 12, "S")
    m.put(2, 11, "P")
    m.fish_line(6, 12, 11, 2)
    m.ground(21, 34, 12, "S")             # gap 17-20 (4)
    m.water(17, 20)
    m.fish_arc(16, 9)
    m.put(28, 11, "k")
    m.block(38, 41, 9, 9)                 # floating island over the sea
    m.fish_line(38, 41, 8)
    m.water(35, 44)
    m.ground(45, 62, 11, "S")
    m.put(50, 10, "o")
    m.put(56, 10, "k")
    m.block(66, 67, 9, 9)                 # small stepping stones
    m.block(71, 72, 8, 8)
    m.fish_line(71, 72, 7)
    m.block(76, 77, 9, 9)
    m.water(63, 80)
    m.ground(81, 105, 12, "S")
    m.put(84, 11, "C")
    m.put(92, 7, "w")
    m.plat(90, 94, 8)
    m.fish_line(90, 94, 7)
    m.put(100, 11, "k")
    m.ground(110, 120, 10)                # grassy cliff, gap 106-109
    m.water(106, 109)
    m.fish_arc(105, 7)
    m.put(116, 9, "e")
    m.block(124, 126, 10, 10)
    m.block(130, 132, 8, 8)
    m.fish_line(130, 132, 7)
    m.block(136, 138, 10, 10)
    m.water(121, 141)
    m.ground(142, 189, 12, "S")
    m.put(148, 11, "k")
    m.fish_line(152, 160, 11)
    m.put(156, 7, "w")
    m.block(166, 168, 10, 11, "S")
    m.block(169, 171, 9, 11, "S")
    m.put(182, 11, "G")
    return m.rows()


def level_1_4():
    # Cliff-top finale: long platform chains over water, staircases, two checkpoints.
    m = Map(210)
    m.ground(0, 14)
    m.put(2, 11, "P")
    m.block(10, 11, 10, 11)
    m.ground(18, 28, 10)                  # gap 15-17 (3) up 2
    m.water(15, 17)
    m.fish_arc(14, 9)
    m.put(24, 9, "e")
    m.plat(32, 34, 8)
    m.plat(38, 40, 6)
    m.fish_line(38, 40, 5)
    m.plat(44, 46, 8)
    m.put(45, 4, "w")
    m.water(29, 49)
    m.ground(50, 70, 11)
    m.put(52, 10, "C")
    m.put(60, 10, "o")
    m.block(64, 65, 8, 10)
    m.fish_line(64, 65, 7)
    m.put(68, 10, "e")
    m.block(74, 75, 9, 9)
    m.block(79, 80, 7, 7)
    m.block(84, 85, 9, 9)
    m.fish_line(79, 80, 6)
    m.block(89, 90, 7, 7)
    m.block(94, 95, 9, 9)
    m.put(87, 5, "w")
    m.water(71, 98)
    m.ground(99, 125)
    m.put(104, 11, "k")
    m.block(110, 111, 11, 11)
    m.block(112, 113, 10, 11)
    m.block(114, 115, 9, 11)
    m.block(116, 117, 8, 11)
    m.block(118, 125, 8, 11)
    m.fish_line(118, 124, 7)
    m.put(122, 7, "e")
    m.ground(130, 140, 9)                 # gap 126-129 at height
    m.water(126, 129)
    m.put(134, 8, "C")
    m.plat(144, 146, 9)
    m.plat(149, 151, 7)
    m.plat(154, 156, 9)
    m.plat(159, 161, 7)
    m.fish_line(149, 151, 6)
    m.fish_line(159, 161, 6)
    m.put(152, 4, "w")
    m.water(141, 164)
    m.ground(165, 209, 10)
    m.put(172, 9, "e")
    m.put(178, 9, "e")
    m.block(184, 186, 8, 9)
    m.block(187, 189, 6, 9)
    m.fish_line(184, 189, 5)
    m.ground(190, 209, 10)
    m.put(200, 9, "G")
    return m.rows()


LEVELS = {"1-1": level_1_1, "1-2": level_1_2, "1-3": level_1_3, "1-4": level_1_4}

def main():
    out = os.path.join(os.path.dirname(__file__), "..", "..", "scripts", "world", "w1_maps.gd")
    lines = ["class_name W1Maps", "extends RefCounted",
             "## GENERATED by tools/levels/gen_w1.py. Edit the generator, not this file.", "",
             "const MAPS := {"]
    for k, fn in LEVELS.items():
        rows = fn()
        assert len(rows) == H and all(len(r) == len(rows[0]) for r in rows)
        lines.append('\t"%s": [' % k)
        lines += ['\t\t"%s",' % r for r in rows]
        lines.append("\t],")
    lines.append("}")
    with open(out, "w") as f:
        f.write("\n".join(lines) + "\n")
    print("wrote", os.path.normpath(out))

if __name__ == "__main__":
    main()
