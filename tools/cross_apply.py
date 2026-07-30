#!/usr/bin/env python3
"""把已翻好的一軌譯文 cross-apply 到另一軌的 skeleton。

KQ1 的 AGI（1984/1987）與 SCI（1990 重製）是同劇情不同文字：正規化後精確重疊僅 ~20%。
所以本工具做兩件事：
  1. 正規化 key 完全相同 → 直接填入譯文（可信）。
  2. 相似度 >= --hint-ratio 的最接近句 → 寫進 hints 檔當翻譯草稿參考（**不直接填**，
     因為措辭有差，直接填會出現「譯文講的跟原文不一樣」這種最難查的錯）。

正規化與引擎 sciChtNormKey 一致：所有空白收斂成單一空格 + trim。

用法:cross_apply.py <已翻.tsv> <目標skeleton.tsv> <輸出.tsv> [--hints hints.tsv] [--hint-ratio 0.75]
"""
import argparse
import difflib
import re


def norm(s):
    return re.sub(r"\s+", " ", s).strip()


def load(path):
    rows = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if "\t" not in line:
                continue
            en, zh = line.split("\t", 1)
            rows.append((en, zh))
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("source")
    ap.add_argument("skeleton")
    ap.add_argument("out")
    ap.add_argument("--hints")
    ap.add_argument("--hint-ratio", type=float, default=0.75)
    a = ap.parse_args()

    # 只收「真的翻過」的行（譯文 != 原文）
    src = {norm(en): zh for en, zh in load(a.source) if zh and zh != en}
    src_keys = list(src)

    hit = miss = 0
    hints = []
    with open(a.out, "w", encoding="utf-8") as out:
        for en, _ in load(a.skeleton):
            key = norm(en)
            if key in src:
                out.write(f"{en}\t{src[key]}\n")
                hit += 1
                continue
            out.write(f"{en}\t{en}\n")
            miss += 1
            if a.hints:
                near = difflib.get_close_matches(key, src_keys, n=1, cutoff=a.hint_ratio)
                if near:
                    ratio = difflib.SequenceMatcher(None, key, near[0]).ratio()
                    hints.append((en, src[near[0]], near[0], ratio))

    print(f"精確命中 {hit} 則、未命中 {miss} 則 → {a.out}")
    if a.hints:
        with open(a.hints, "w", encoding="utf-8") as f:
            f.write("# 未命中但有相似句的參考草稿：原文 <TAB> 相似句譯文 <TAB> 相似句原文 <TAB> 相似度\n")
            for en, zh, ref, ratio in hints:
                f.write(f"{en}\t{zh}\t{ref}\t{ratio:.2f}\n")
        print(f"相似草稿 {len(hints)} 則（ratio >= {a.hint_ratio}）→ {a.hints}")


if __name__ == "__main__":
    main()
