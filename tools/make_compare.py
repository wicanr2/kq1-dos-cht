#!/usr/bin/env python3
"""把「修前 / 修後」兩張實機截圖裁同一塊區域，上下疊成 issue 用的對照圖。

用法：make_compare.py <before.png> <after.png> <out.png> <x> <y> <w> <h> [--scale N]
座標是遊戲的 320x200 座標；截圖是 640x480（2x upscale + 上下各 40px letterbox）。
"""
import sys
from PIL import Image, ImageDraw

LETTERBOX = 20  # 640x400 置中於 640x480

def crop(path, x, y, w, h):
    im = Image.open(path).convert("RGB")
    return im.crop((x * 2, LETTERBOX + y * 2, (x + w) * 2, LETTERBOX + (y + h) * 2))

def main():
    a = sys.argv
    before, after, out = a[1], a[2], a[3]
    x, y, w, h = (int(v) for v in a[4:8])
    scale = int(a[9]) if len(a) > 9 and a[8] == "--scale" else 1
    ba, aa = crop(before, x, y, w, h), crop(after, x, y, w, h)
    if scale != 1:
        size = (ba.width * scale, ba.height * scale)
        ba, aa = ba.resize(size, Image.NEAREST), aa.resize(size, Image.NEAREST)

    pad, label, gap = 12, 22, 10
    W = ba.width + pad * 2
    H = label + ba.height + gap + label + aa.height + pad
    canvas = Image.new("RGB", (W, H), (26, 26, 26))
    d = ImageDraw.Draw(canvas)
    d.text((W // 2 - 22, 5), "before", fill=(230, 90, 90))
    canvas.paste(ba, (pad, label))
    d.text((W // 2 - 18, label + ba.height + gap + 2), "after", fill=(110, 200, 110))
    canvas.paste(aa, (pad, label + ba.height + gap + label))
    canvas.save(out)
    print(out, canvas.size)

main()
