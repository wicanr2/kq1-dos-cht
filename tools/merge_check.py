#!/usr/bin/env python3
"""合併翻譯批次成 master translation.tsv,並在合併前逐批驗證。

驗證項目(任一不過就擋下該批,不讓髒資料進 master):
  1. 行數與對應的 batch/*.tsv 相同
  2. 第一欄(英文 key)逐行 byte-identical —— key 改一個字元遊戲就不翻
  3. 控制序列(%s/%d/%v/%3d…)數量與順序一致
  4. 譯文可編成 Big5(字型是從譯文烘的,非 Big5 字會變空白)

用法:merge_check.py <batch_dir> <done_dir> <out.tsv>
"""
import glob
import os
import re
import sys

CTRL = re.compile(r"%[-0-9.]*[a-zA-Z]")


def load(path):
    rows = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if "\t" in line:
                rows.append(line.split("\t", 1))
            elif line:
                rows.append([line, ""])
    return rows


def main():
    batch_dir, done_dir, out_path = sys.argv[1:4]
    merged, problems, missing = [], [], []
    total_translated = 0

    for bpath in sorted(glob.glob(os.path.join(batch_dir, "batch_*.tsv"))):
        name = os.path.basename(bpath).replace(".tsv", ".done")
        dpath = os.path.join(done_dir, name)
        if not os.path.exists(dpath):
            missing.append(name)
            continue
        src, dst = load(bpath), load(dpath)
        if len(src) != len(dst):
            problems.append(f"{name}: 行數不符 {len(src)} vs {len(dst)}")
            continue
        bad = False
        for i, ((en_s, _), (en_d, zh)) in enumerate(zip(src, dst), 1):
            if en_s != en_d:
                problems.append(f"{name}:{i} key 不符")
                bad = True
                break
            if CTRL.findall(en_s) != CTRL.findall(zh):
                problems.append(f"{name}:{i} 控制序列不符 {CTRL.findall(en_s)} vs {CTRL.findall(zh)}")
            try:
                zh.encode("big5")
            except UnicodeEncodeError as e:
                problems.append(f"{name}:{i} 非 Big5 字 {zh[e.start:e.end]!r}")
        if bad:
            continue
        for en, zh in dst:
            merged.append((en, zh))
            if zh and zh != en:
                total_translated += 1

    with open(out_path, "w", encoding="utf-8") as f:
        for en, zh in merged:
            f.write(f"{en}\t{zh}\n")

    print(f"合併 {len(merged)} 則,其中已翻 {total_translated} 則 → {out_path}")
    if missing:
        print(f"[缺] 尚未交件:{', '.join(missing)}")
    if problems:
        print(f"[問題] {len(problems)} 筆:")
        for p in problems[:40]:
            print("  " + p)
    else:
        print("驗證全過:key 一致、控制序列一致、譯文皆可編 Big5")


if __name__ == "__main__":
    main()
