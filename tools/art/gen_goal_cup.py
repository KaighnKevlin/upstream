"""Goal cup: a riveted brass bin, open at the top: its floor pan and the
two kinds of side wall (the plain wall, and the tall backboard that catches
overshoots). The code puts a wall on each side of the floor.

    python3 tools/art/gen_goal_cup.py [preview_dir]

Writes (the node is the cup's floor centre; walls at x +-17):
- goal_cup_floor.png  44x8, the floor centre at (22, 3): the pan spans
  x -18..18 with its top face on y -1.
- goal_cup_wall.png   8x36, the wall's foot (floor corner) at (4, 33); it
  stands 30 px, x -2..2 about the wall line.
- goal_cup_board.png  10x72, the same for the backboard, 66 px tall
  (x -2..2), with a brass-bound top.
"""
import sys
from clockwork import *
from pixtools import write_png
from titan_lib import SPR, side_by_side


def floor():
    fig = Figure()
    fig.box((-18.5, -1.5, 18.5, 2), BRONZE, z=0, bevel=0.8)
    fig.capsule((-17, 1.6), (17, 1.6), 0.4, DARK, z=0.1)
    for x in (-12, -4, 4, 12):
        fig.sphere((x, 0.3), 0.6, STEEL, z=0.2)
    return fig.render(44, 8, (22, 3))


def wall(h, w):
    fig = Figure()
    fig.box((-2, -h, 2, 1.5), BRONZE, z=0, bevel=0.8)
    fig.box((-0.5, -h + 2, 0.5, -1), BRONZE[:5], z=0.05, bevel=0.3)       # a pressed rib
    for y in range(11, int(h) - 4, 11):
        fig.box((-2.4, -y - 0.9, 2.4, -y + 0.9), STEEL, z=0.2, bevel=0.4)   # bands
        fig.sphere((0, -y), 0.5, BRONZE, z=0.25)
    fig.box((-2.8, -h - 1.2, 2.8, -h + 1.5), STEEL, z=0.3, bevel=0.6)      # rolled top
    fig.box((-2.8, -1.2, 2.8, 1.8), STEEL, z=0.3, bevel=0.6)               # corner shoe
    return fig.render(w, int(h) + 6, (w // 2, int(h) + 3))


def main():
    f, s, b = floor(), wall(30, 8), wall(66, 10)
    write_png(SPR + 'goal_cup_floor.png', 44, 8, f)
    write_png(SPR + 'goal_cup_wall.png', 8, 36, s)
    write_png(SPR + 'goal_cup_board.png', 10, 72, b)
    print('wrote goal_cup_floor.png, goal_cup_wall.png, goal_cup_board.png')
    if len(sys.argv) > 1:
        big = side_by_side([f, s, b], 8)
        write_png(sys.argv[1] + '/goal_cup_preview.png', len(big[0]), len(big), big)


if __name__ == '__main__':
    main()
