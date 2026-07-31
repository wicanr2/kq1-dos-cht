#!/usr/bin/env python3
"""從倚天中文系統(ETEN 3.53)原生點陣字烘 SCI 繁中化用的 Big5 字型。

為什麼不用 TTF:1990s DOS 中文的原貌就是倚天;TTF 縮到 15–24px 筆劃比例不對、
複雜字糊成一團。倚天是為該尺寸手工調的點陣字。

輸出一份(格式為 ScummVM Graphics::Big5Font::loadPrefixedRaw 的 prefixed raw:
每字 = big-endian Big5 碼 + H 列 × ceil(W/8) bytes,MSB 在左;檔尾 0xFFFF):
  <out>/kq1_big5.fnt     16×15,AGI 全部 + SCI 全部

KQ1 不烘 24×24:那份是給「強制 640×400 upscale + hi-res 直繪」用的,而 KQ1 的常駐
狀態列撐不住強制 upscale(連英文都破圖,見 scummvm-src screen.cpp 的 CHT note),
整條 hi-res 路徑已從引擎移除。要重新評估時,24×24 的來源檔仍在 assets/eten/。

來源檔(tools/assets/eten/):
  STDFONT.15   16×15 漢字 13094 字,30 B/字   裸格式
  SPCFONT.15   16×15 全形標點 408 字,30 B/字  裸格式

Big5 索引是「分區」不是線性,見 kb eten-bitmap-font。
"""
import sys, os, struct, argparse

HERE = os.path.dirname(os.path.abspath(__file__))
ETEN = os.path.join(HERE, "assets", "eten")

# --- Big5 分區索引 ---------------------------------------------------------
def raw(hi, lo):
    return (hi - 0xA1) * 157 + ((lo - 0x40) if lo < 0x7F else (lo - 0x62))

LAST_SPC    = raw(0xA3, 0xBF)   # 符號區尾 = 407
BASE_A440   = raw(0xA4, 0x40)   # 漢字常用區起點
LAST_COMMON = raw(0xC6, 0x7E)   # 常用字尾
BASE_C940   = raw(0xC9, 0x40)   # 次常用起點
N_COMMON    = 5401

def eten_slot(hi, lo):
    """回傳 ('spc'|'std', idx);不在倚天涵蓋範圍回 None。"""
    r = raw(hi, lo)
    if r < 0:
        return None
    if r <= LAST_SPC:
        return ("spc", r)
    if r < BASE_A440:
        return None          # A3C0–A3FE 控制碼區,倚天無字
    if r <= LAST_COMMON:
        return ("std", r - BASE_A440)
    if r < BASE_C940:
        return None          # C6A1–C8FE 造字區
    return ("std", N_COMMON + (r - BASE_C940))

# --- 字模讀取 --------------------------------------------------------------
class EtenFont:
    def __init__(self, std_path, spc_path, w, h):
        self.w, self.h = w, h
        self.stride = h * ((w + 7) // 8)
        self.std = open(std_path, "rb").read()
        self.spc = open(spc_path, "rb").read()
        self.n_std = len(self.std) // self.stride
        self.n_spc = len(self.spc) // self.stride

    def glyph(self, hi, lo):
        slot = eten_slot(hi, lo)
        if slot is None:
            return None
        kind, idx = slot
        blob, n = (self.spc, self.n_spc) if kind == "spc" else (self.std, self.n_std)
        if idx < 0 or idx >= n:
            return None
        return blob[idx * self.stride:(idx + 1) * self.stride]

    def to_ascii(self, hi, lo):
        """dump 成 ASCII art,給驗收 oracle 用。"""
        g = self.glyph(hi, lo)
        if g is None:
            return "<no glyph>"
        rb = (self.w + 7) // 8
        out = []
        for y in range(self.h):
            row = "".join("#" if g[y * rb + (x >> 3)] & (0x80 >> (x & 7)) else "." for x in range(self.w))
            out.append(row)
        return "\n".join(out)

# --- TTF 後備(倚天沒有的 Big5 字) ------------------------------------------
def ttf_glyph(ch, w, h, ttf_path, face):
    from PIL import Image, ImageFont, ImageDraw
    key = (ttf_path, face, h)
    if key not in ttf_glyph._cache:
        ttf_glyph._cache[key] = ImageFont.truetype(ttf_path, h, index=face)
    font = ttf_glyph._cache[key]
    img = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(img)
    try:
        bbox = d.textbbox((0, 0), ch, font=font)
    except Exception:
        bbox = (0, 0, w, h)
    ox = (w - (bbox[2] - bbox[0])) // 2 - bbox[0]
    oy = (h - (bbox[3] - bbox[1])) // 2 - bbox[1]
    d.text((ox, oy), ch, fill=255, font=font)
    px = img.load()
    rb = (w + 7) // 8
    out = bytearray(rb * h)
    for y in range(h):
        for x in range(w):
            if px[x, y] >= 128:
                out[y * rb + (x >> 3)] |= (0x80 >> (x & 7))
    return bytes(out)
ttf_glyph._cache = {}

# --- 主流程 ----------------------------------------------------------------
def bake(chars, font, out_path, w, h, ttf_path, ttf_face, label):
    glyphs, fallback, missing = [], [], []
    for ch in sorted(chars):
        try:
            b5 = ch.encode("big5")
        except UnicodeEncodeError:
            missing.append(ch)
            continue
        if len(b5) != 2:
            continue
        g = font.glyph(b5[0], b5[1])
        if g is None:
            try:
                g = ttf_glyph(ch, w, h, ttf_path, ttf_face)
                fallback.append(ch)
            except Exception as e:
                sys.stderr.write(f"WARN {label}: {ch!r} 無字模且 TTF 後備失敗:{e}\n")
                continue
        glyphs.append(((b5[0] << 8) | b5[1], g))

    with open(out_path, "wb") as f:
        for code, bmp in glyphs:
            f.write(struct.pack(">H", code))
            f.write(bmp)
        f.write(struct.pack(">H", 0xFFFF))

    exp = len(glyphs) * (2 + h * ((w + 7) // 8)) + 2
    got = os.path.getsize(out_path)
    assert exp == got, f"{label}: 檔案大小驗算不符 exp={exp} got={got}"
    print(f"{label}: {len(glyphs)} 字 ({w}×{h}) → {out_path}  [{got} bytes]"
          f"{'  倚天缺字走 TTF:' + ''.join(fallback) if fallback else ''}"
          f"{'  非 Big5(遺失):' + ''.join(missing) if missing else ''}")
    return fallback, missing

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("tsv", help="UTF-8 translation.tsv(英文<TAB>中文)")
    ap.add_argument("outdir")
    ap.add_argument("--prefix", default="sq4")
    ap.add_argument("--ttf", default="/usr/share/fonts/truetype/arphic/uming.ttc")
    ap.add_argument("--ttf-face", type=int, default=2)
    ap.add_argument("--corrections", default="translation/corrections.tsv")
    ap.add_argument("--selftest", action="store_true", help="只跑驗收 oracle")
    a = ap.parse_args()

    lo = EtenFont(os.path.join(ETEN, "STDFONT.15"), os.path.join(ETEN, "SPCFONT.15"), 16, 15)

    # 驗收 oracle(kb eten-bitmap-font):idx=0 必須是「一」,「中」「猴」須可辨識
    art = lo.to_ascii(0xA4, 0x40)             # 「一」= Big5 A440 = std idx 0
    rows_with_ink = [r for r in art.split("\n") if "#" in r]
    assert 1 <= len(rows_with_ink) <= 3, f"16×15 oracle 失敗:「一」不是單橫線\n{art}"
    for hib, lob, chn in ((0xA4, 0xA4, "中"), (0xB5, 0x55, "猴")):
        assert lo.glyph(hib, lob) is not None, f"16×15 oracle 失敗:「{chn}」無字模"
    print("oracle OK:「一」為單橫線,「中」「猴」有字模")
    if a.selftest:
        print(lo.to_ascii(0xA4, 0xA4))
        return

    sys.path.insert(0, HERE)
    from build_cht import normalize, fullwidthize

    corrections = []
    try:
        for line in open(a.corrections, encoding="utf-8"):
            line = line.rstrip("\n")
            if "\t" in line and not line.startswith("#"):
                w_, r_ = line.split("\t", 1)
                corrections.append((w_, r_))
    except FileNotFoundError:
        pass

    chars = set()
    with open(a.tsv, encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if "\t" not in line:
                continue
            en, zh = line.split("\t", 1)
            if not zh or zh == en:
                continue
            zh = fullwidthize(normalize(zh))
            for w_, r_ in corrections:
                zh = zh.replace(w_, r_)
            chars.update(zh)
    # 只留 non-ASCII(ASCII 走原版 SCI 字型)
    chars = {c for c in chars if ord(c) > 0x7F}

    os.makedirs(a.outdir, exist_ok=True)
    bake(chars, lo, f"{a.outdir}/{a.prefix}_big5.fnt", 16, 15, a.ttf, a.ttf_face, "低解析")

if __name__ == "__main__":
    main()
