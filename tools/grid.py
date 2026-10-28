#!/usr/bin/env python3
"""Tile screenshots into one contact sheet (used by move_sheet.sh / pose_sheet.sh).

    grid.py out.png [--crop x0,y0,x1,y1] [--cols N] [--labels a b c ...] -- in1.png in2.png ...
"""
import sys

from PIL import Image, ImageDraw


def main(argv):
    out, rest = argv[0], argv[1:]
    files = rest[rest.index("--") + 1:]
    opts = rest[:rest.index("--")]
    crop, cols, labels = None, 3, []
    i = 0
    while i < len(opts):
        if opts[i] == "--crop":
            crop = tuple(int(v) for v in opts[i + 1].split(","))
            i += 2
        elif opts[i] == "--cols":
            cols = int(opts[i + 1])
            i += 2
        elif opts[i] == "--labels":
            i += 1
            while i < len(opts) and not opts[i].startswith("--"):
                labels.append(opts[i])
                i += 1
        else:
            i += 1
    tiles = []
    for f in files:
        im = Image.open(f).convert("RGB")
        if crop:
            im = im.crop(crop)
        im.thumbnail((540, 420))
        tiles.append(im)
    w = max(t.width for t in tiles)
    h = max(t.height for t in tiles)
    cols = min(cols, len(tiles))
    rows = (len(tiles) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * w, rows * h), (16, 16, 16))
    draw = ImageDraw.Draw(sheet)
    for n, t in enumerate(tiles):
        x, y = (n % cols) * w, (n // cols) * h
        sheet.paste(t, (x, y))
        if n < len(labels):
            draw.rectangle((x, y, x + 9 * len(labels[n]) + 10, y + 20), fill=(0, 0, 0))
            draw.text((x + 5, y + 4), labels[n], fill=(255, 220, 0))
    sheet.save(out)


main(sys.argv[1:])
