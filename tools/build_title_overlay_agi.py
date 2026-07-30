#!/usr/bin/env python3
"""烘 AGI 軌的中文標題疊圖 `kq1_title_agi.ovl`。

AGI 與 SCI 的疊圖格式不同，兩軌各一份檔案：
  AGI（本檔）：magic "CHTO" + u8 version + u8 palType + BE u16 OX,OY,OW,OH + OW*OH bytes
               座標是 **hi-res display（640×400）**，直接寫 `_displayScreen`；0xFF = 透明。
  SCI：LE u16 w,h,x,y + w*h bytes，座標是邏輯 320×200，寫 visual plane。

字形用倚天 `STDFONT.15`（16×15），與遊戲內文同一套字模，風格一致。
顏色用 EGA 索引（AGI 的 display buffer 就是 EGA 索引）。

用法：build_title_overlay_agi.py <out.ovl> [--text 國王密令] [--x auto] [--y 3]
"""
import argparse
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from build_eten_font import EtenFont, ETEN  # noqa: E402

# EGA 16 色索引
EGA_YELLOW = 14   # 亮黃（字身）
EGA_BLACK = 0     # 黑描邊（在 AGI 標題的藍底上對比最強）
EGA_WHITE = 15    # 白（頂緣高光）
TRANSPARENT = 0xFF

GW, GH = 16, 15


def render(text, pad_x=2, pad_y=2):
    """回傳 (w, h, bytes)：字身亮黃 + 一圈棕描邊 + 頂緣白高光。"""
    font = EtenFont(os.path.join(ETEN, "STDFONT.15"), os.path.join(ETEN, "SPCFONT.15"), GW, GH)
    row_bytes = (GW + 7) // 8
    glyphs = []
    for ch in text:
        b5 = ch.encode("big5")
        raw = font.glyph(b5[0], b5[1])   # 原始點陣：每列 row_bytes 個 byte，MSB 在左
        if raw is None:
            raise SystemExit(f"倚天字型裡沒有「{ch}」")
        bits = [(raw[gy * row_bytes + gx // 8] >> (7 - gx % 8)) & 1
                for gy in range(GH) for gx in range(GW)]
        glyphs.append(bits)

    w = len(glyphs) * GW + pad_x * 2
    h = GH + pad_y * 2
    buf = bytearray([TRANSPARENT] * (w * h))

    def ink(x, y, color, only_if_transparent=False):
        if 0 <= x < w and 0 <= y < h:
            if only_if_transparent and buf[y * w + x] != TRANSPARENT:
                return
            buf[y * w + x] = color

    # 先鋪描邊（8 鄰域），再蓋字身，最後補頂緣高光
    for gi, g in enumerate(glyphs):
        ox = pad_x + gi * GW
        for gy in range(GH):
            for gx in range(GW):
                if not g[gy * GW + gx]:
                    continue
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        ink(ox + gx + dx, pad_y + gy + dy, EGA_BLACK, only_if_transparent=True)
    for gi, g in enumerate(glyphs):
        ox = pad_x + gi * GW
        for gy in range(GH):
            for gx in range(GW):
                if g[gy * GW + gx]:
                    ink(ox + gx, pad_y + gy, EGA_YELLOW)
    for gi, g in enumerate(glyphs):
        ox = pad_x + gi * GW
        for gx in range(GW):
            for gy in range(GH):
                if g[gy * GW + gx]:
                    ink(ox + gx, pad_y + gy, EGA_WHITE)
                    break
    return w, h, bytes(buf)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("--text", default="國王密令")
    ap.add_argument("--x", default="auto", help="display x（auto = 在 640 寬置中）")
    ap.add_argument("--y", type=int, default=3, help="display y")
    ap.add_argument("--screen-width", type=int, default=640)
    a = ap.parse_args()

    w, h, data = render(a.text)
    x = (a.screen_width - w) // 2 if a.x == "auto" else int(a.x)

    with open(a.out, "wb") as f:
        f.write(b"CHTO")
        f.write(struct.pack("BB", 1, 0))            # version, palType(0=EGA 索引)
        f.write(struct.pack(">HHHH", x, a.y, w, h))  # OX, OY, OW, OH（big-endian，對齊引擎）
        f.write(data)

    opaque = sum(1 for b in data if b != TRANSPARENT)
    print(f"{a.out}: {w}×{h} @ ({x},{a.y})，非透明 {opaque} px，共 {12 + len(data)} bytes")


if __name__ == "__main__":
    main()
