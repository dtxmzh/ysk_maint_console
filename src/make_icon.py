# -*- coding: utf-8 -*-
# Generate app.ico for 维护操作台: little Yosuko fox face (orange fur, happy closed eyes,
# red flower hairpin on the left ear side), multi-size ICO. PIL-based, run with any python
# that has Pillow.
import sys

try:
    from PIL import Image, ImageDraw
except ImportError:
    sys.exit("NO_PIL")

S = 256
img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(img)

FUR   = (245, 166, 35, 255)     # warm orange
FUR_D = (222, 130, 20, 255)     # darker ear tips
CREAM = (255, 236, 208, 255)    # muzzle/inner-ear
PINK  = (250, 190, 190, 255)
EYE   = (90, 60, 30, 255)
RED   = (214, 58, 72, 255)
WHITE = (255, 255, 255, 255)

# ears (triangles)
d.polygon([(52, 96), (74, 12), (128, 66)], fill=FUR)
d.polygon([(204, 96), (182, 12), (128, 66)], fill=FUR)
d.polygon([(62, 84), (78, 30), (116, 64)], fill=PINK)
d.polygon([(194, 84), (178, 30), (140, 64)], fill=PINK)

# head
d.ellipse((40, 60, 216, 226), fill=FUR)
# cheek fluff (two cream puffs lower face)
d.ellipse((62, 140, 138, 220), fill=CREAM)
d.ellipse((118, 140, 194, 220), fill=CREAM)
d.ellipse((96, 150, 160, 224), fill=CREAM)

# happy closed eyes (arcs curving down = ^_^)
d.arc((76, 112, 118, 148), start=200, end=340, fill=EYE, width=7)
d.arc((138, 112, 180, 148), start=200, end=340, fill=EYE, width=7)

# nose + smile
d.ellipse((120, 152, 136, 166), fill=EYE)
d.arc((108, 158, 148, 190), start=20, end=160, fill=EYE, width=5)

# whisker dots
for x in (92, 164):
    d.ellipse((x, 158, x + 5, 163), fill=FUR_D)

# red flower hairpin (her signature), upper-left of head
fx, fy = 66, 82
for ang in range(0, 360, 60):
    import math
    px = fx + 12 * math.cos(math.radians(ang))
    py = fy + 12 * math.sin(math.radians(ang))
    d.ellipse((px - 7, py - 7, px + 7, py + 7), fill=RED)
d.ellipse((fx - 6, fy - 6, fx + 6, fy + 6), fill=WHITE)

out = r"F:\WorkStation\ysk_work\gh_ysk_maint_console\src\app.ico"
img.save(out, sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
print("ICO_OK", out)
