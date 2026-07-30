#!/usr/bin/env python3
"""從 SCI_DUMP_RES dump 的 script.997 抽選單字串。

SCI0 的 kSetMenu 把整個下拉選單塞成一條組合字串:
    ` Save Game`#5: Restore Game`#7: --!: Restart Game`#9: Quit`^q `
    backtick = accelerator 分隔、`#N` = Fn、`^x` = Ctrl-x、`:` = 分項、`--!` = 分隔線。
選單「標題」則是獨立短字串,且帶 padding 空格(如 ` File `)——padding 要逐字保留,
否則 runtime 內容比對 MISS。

引擎端(GfxText16)拿到的是「拆開後的單項文字」,所以 translation.tsv 的 key 要是
拆出來的 item(含前導空格),不是整條組合字串。

用法:extract_menu.py <script.997> <out.tsv>
"""
import re
import sys


def extract(path):
    data = open(path, "rb").read()
    titles, items = [], []
    for m in re.finditer(rb"[ -~]{4,}", data):
        s = m.group().decode("latin1")
        if "`" not in s and "--!" not in s:
            # 標題:兩側帶空格的單純詞(` File `/` Speed `/` Sound `)
            if re.fullmatch(r" [A-Z][A-Za-z ]*[a-z] ", s):
                titles.append(s)
            continue
        for part in s.split(":"):
            item = part.split("`")[0]
            if not item.strip() or item.strip() == "--!":
                continue
            items.append(item)
    return titles, items


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    titles, items = extract(sys.argv[1])
    seen, out = set(), []
    for s in titles + items:
        if s not in seen:
            seen.add(s)
            out.append(s)
    with open(sys.argv[2], "w", encoding="utf-8") as f:
        for s in out:
            f.write(f"{s}\t{s}\n")
    print(f"選單字串 {len(out)} 則(標題 {len(titles)}、項目 {len(items)}) → {sys.argv[2]}")


if __name__ == "__main__":
    main()
