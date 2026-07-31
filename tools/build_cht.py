#!/usr/bin/env python3
"""英雄傳奇1 繁中化 build 工具。

輸入:UTF-8 的 translation.tsv(英文原文 <TAB> 中文譯文,每行一則)。
輸出:
  - runtime translation.tsv(英文 <TAB> Big5 bytes):ScummVM SCI 引擎讀取,做內容比對替換。
    TAB/LF 不出現在 Big5,故可安全當分隔。
  - kq1_ttf_big5.fnt:Big5 點陣字型（TTF 版中間產物）,格式對齊 ScummVM Graphics::Big5Font::loadPrefixedRaw:
    每字 = big-endian Big5 碼(高位元已設)+ height 列 × 2 bytes(16px 寬 1bpp,MSB 在左)。

用法:build_cht.py <in_utf8_tsv> <out_dir> [--size N] [--font PATH] [--face IDX]
純輸出;字型渲染用 Pillow。
"""
import sys, struct, argparse

WIDTH = 16  # Big5Font 固定字寬 kChineseTraditionalWidth

# LLM 常產出、但不在 Big5 的字元 → 正規化成 Big5 等價(安全網)。
# 注意:名字分隔號 ·(U+00B7)本身就是 Big5(a150),不要動它。
NORMALIZE = {
    # 標點
    "⋯": "…",  # ⋯(midline)→ …(Big5 a14b)
    "‘": "「", "’": "」",  # ‘’ → 「」
    "“": "『", "”": "』",  # “” → 『』
    "―": "—",  # ― → —
    "～": "∼",  # 全形波浪(非 Big5)→ ∼(a1e3)
    "‧": "·",  # 中點(U+2027 非 Big5)→ ·(a150)
    # 簡體漏字 → 繁體(haiku 偶爾漏出;非 Big5 掃描可抓全)
    "赢": "贏", "唠": "嘮", "啧": "嘖", "咔": "喀",
    "銹": "鏽", "嘚": "噠", "嚯": "哦",
    "户": "戶", "嗞": "吱", "鱝": "魟",
}

def normalize(s):
    for a, b in NORMALIZE.items():
        s = s.replace(a, b)
    return s

# 半形 → 全形(僅在 CJK 相鄰時轉,保留 %d / 數字 / 英文片段中的半形標點)
# 用明確 codepoint,避免全形值被輸入法/編輯器存成半形。
HALF2FULL = {
    ",": "，",  # ，
    "!": "！",  # ！
    "?": "？",  # ？
    ":": "：",  # ：
    ";": "；",  # ；
}

def _is_cjk(ch):
    return ch and "㐀" <= ch <= "鿿"

def fullwidthize(s):
    out = []
    n = len(s)
    for i, ch in enumerate(s):
        prev = s[i - 1] if i > 0 else ""
        nxt = s[i + 1] if i + 1 < n else ""
        if ch in HALF2FULL and (_is_cjk(prev) or _is_cjk(nxt)):
            out.append(HALF2FULL[ch])
        elif ch == "." and _is_cjk(prev) and not nxt.isdigit():
            out.append("。")  # 中文句末句號
        else:
            out.append(ch)
    return "".join(out)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("tsv")
    ap.add_argument("outdir")
    ap.add_argument("--size", type=int, default=15, help="字型高度(px)")
    # 預設古籍風明體(AR PL UMing TW);face 2 = TW
    ap.add_argument("--font", default="/usr/share/fonts/truetype/arphic/uming.ttc")
    ap.add_argument("--face", type=int, default=2)
    ap.add_argument("--corrections", default="translation/corrections.tsv",
                    help="錯誤中文\\t正確中文,子字串替換(可無)")
    ap.add_argument("--no-font", action="store_true",
                    help="只產 runtime tsv,不烘 TTF 字型(KQ1 走倚天點陣字,見 build_eten_font.py)")
    a = ap.parse_args()
    H = a.size

    corrections = []
    try:
        for line in open(a.corrections, encoding="utf-8"):
            line = line.rstrip("\n")
            if "\t" in line and not line.startswith("#"):
                wrong, right = line.split("\t", 1)
                corrections.append((wrong, right))
    except FileNotFoundError:
        pass

    # 讀來源。col1==col2(未翻譯)或 col2 空 → 跳過,只收已翻譯者。
    rows = []
    chars = set()
    total_lines = 0
    with open(a.tsv, encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if not line or "\t" not in line:
                continue
            total_lines += 1
            en, zh = line.split("\t", 1)
            if not zh or zh == en:
                continue  # 未翻譯
            zh = normalize(zh)
            zh = fullwidthize(zh)
            for wrong, right in corrections:
                zh = zh.replace(wrong, right)
            rows.append((en, zh))
            chars.update(zh)

    # 非 Big5 字元警告(會在字型/runtime 遺失)
    nonbig5 = {}
    for _, zh in rows:
        for ch in zh:
            try:
                ch.encode("big5")
            except UnicodeEncodeError:
                nonbig5[ch] = nonbig5.get(ch, 0) + 1
    if nonbig5:
        sys.stderr.write("WARN 非 Big5 字元(會遺失,請修譯文或加進 NORMALIZE):" +
                         " ".join(f"{c!r}×{n}" for c, n in nonbig5.items()) + "\n")

    # 1) runtime tsv(Big5)
    runtime = a.outdir + "/translation.tsv"
    with open(runtime, "wb") as out:
        for en, zh in rows:
            try:
                big5 = zh.encode("big5")
            except UnicodeEncodeError as e:
                sys.stderr.write(f"WARN: 無法 Big5 編碼一則:{e}\n")
                continue
            out.write(en.encode("latin1", "replace"))
            out.write(b"\t")
            out.write(big5)
            out.write(b"\n")

    # 2) 烘 Big5 字型(只含用到的字)
    # KQ1 不走這條:字型一律用倚天點陣字(build_eten_font.py),TTF 縮到 15px 筆劃比例不對。
    # 留著是為了換遊戲時手上沒有倚天字的情況,所以 PIL 延遲匯入 —— --no-font 時完全不需要它。
    if a.no_font:
        print(f"譯文 {len(rows)} 則 → {runtime}(--no-font,未烘 TTF 字型)")
        return
    from PIL import Image, ImageFont, ImageDraw
    font = ImageFont.truetype(a.font, H, index=a.face)
    glyphs = []  # (big5code, bytes)
    baked = 0
    for ch in sorted(chars):
        try:
            b5 = ch.encode("big5")
        except UnicodeEncodeError:
            continue
        if len(b5) != 2:
            continue
        code = (b5[0] << 8) | b5[1]  # 高位元組 >=0x81 → 0x8000 已設
        # 渲染到 WIDTH×H 1bpp:以字面 ink bbox 置中,避免全形標點/小字偏高。
        img = Image.new("L", (WIDTH, H), 0)
        d = ImageDraw.Draw(img)
        try:
            bbox = d.textbbox((0, 0), ch, font=font)  # (l,t,r,b) 實際墨水範圍
        except Exception:
            bbox = (0, 0, WIDTH, H)
        gw = bbox[2] - bbox[0]
        gh = bbox[3] - bbox[1]
        ox = (WIDTH - gw) // 2 - bbox[0]
        oy = (H - gh) // 2 - bbox[1]
        d.text((ox, oy), ch, fill=255, font=font)
        rows_bytes = bytearray()
        px = img.load()
        for y in range(H):
            for byte_i in range(WIDTH // 8):  # 2 bytes / 列
                bits = 0
                for bit in range(8):
                    x = byte_i * 8 + bit
                    on = 1 if px[x, y] >= 128 else 0
                    bits = (bits << 1) | on
                rows_bytes.append(bits)
        glyphs.append((code, bytes(rows_bytes)))
        baked += 1

    fnt = a.outdir + "/kq1_ttf_big5.fnt"   # 只是中間產物，build_translation.sh 產完就刪、實際字型走 build_eten_font.py
    with open(fnt, "wb") as out:
        for code, bmp in glyphs:
            out.write(struct.pack(">H", code))
            out.write(bmp)
        out.write(struct.pack(">H", 0xFFFF))  # 終結

    print(f"譯文 {len(rows)} 則 → {runtime}")
    print(f"字型 {baked} 字 (H={H}, W={WIDTH}) → {fnt}")

if __name__ == "__main__":
    main()
