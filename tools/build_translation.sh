#!/bin/bash
# 合併譯文批次 → 驗證 → 產出部署用中文資料（dist-cht/）。可重跑。
#
# 產物（兩軌共用同一份，AGI 與 SCI 都從這裡載）:
#   dist-cht/translation.tsv   Big5 runtime 查表（引擎讀這份，不是 UTF-8 那份）
#   dist-cht/kq1_big5.fnt      倚天 16×15（AGI 全部 + SCI 選單路徑）
#   dist-cht/kq1_big5_hi.fnt   倚天 24×24（SCI hi-res 對白路徑，須對齊 fontchinese.cpp
#                              的 kHiW=24 / kHiH=24）
set -e
cd "$(dirname "$0")/.."

UTF8=translation/translation_utf8.tsv

# 1) 合併 + 逐批驗證（key byte-identical、控制序列一致、可編 Big5）
python3 tools/merge_check.py translation/batch translation/done translation/translation_sci.tsv

# 2) 兩軌合併成單一 master：SCI 為主，AGI 專有的接在後面（key 不同不會互相干擾）
python3 - <<'PY'
import re
def norm(s): return re.sub(r'\s+', ' ', s).strip()
rows, seen = [], set()
def add(path):
    try:
        f = open(path, encoding='utf-8')
    except FileNotFoundError:
        return 0
    n = 0
    with f:
        for line in f:
            line = line.rstrip('\n')
            if '\t' not in line:
                continue
            en, zh = line.split('\t', 1)
            k = norm(en)
            if k in seen:
                continue
            seen.add(k); rows.append((en, zh)); n += 1
    return n
a = add('translation/translation_sci.tsv')
b = add('translation/translation_agi.tsv')
with open('translation/translation_utf8.tsv', 'w', encoding='utf-8') as out:
    for en, zh in rows:
        out.write(f"{en}\t{zh}\n")
done = sum(1 for en, zh in rows if zh and zh != en)
print(f"master: SCI {a} + AGI {b} = {len(rows)} 則，已譯 {done} 則 ({100*done//max(len(rows),1)}%)")
PY

# 2b) 譯名收斂：各批 subagent 獨立作業一定會漂移（怒河/洶湧河、矮人/侏儒矮人…），
#     合併後對中文欄做一次全域取代收斂（表在 translation/converge.tsv）
python3 - <<'PY'
conv = []
try:
    for line in open('translation/converge.tsv', encoding='utf-8'):
        line = line.rstrip('\n')
        if line.startswith('#') or '\t' not in line:
            continue
        a, b = line.split('\t', 1)
        conv.append((a, b))
except FileNotFoundError:
    conv = []
if conv:
    path = 'translation/translation_utf8.tsv'
    out, n = [], 0
    for line in open(path, encoding='utf-8'):
        line = line.rstrip('\n')
        if '\t' in line:
            en, zh = line.split('\t', 1)
            before = zh
            for a, b in conv:
                zh = zh.replace(a, b)
            if zh != before:
                n += 1
            out.append(f"{en}\t{zh}")
        elif line:
            out.append(line)
    open(path, 'w', encoding='utf-8').write('\n'.join(out) + '\n')
    print(f"譯名收斂：{len(conv)} 條規則，改動 {n} 行")
PY

# 3) Big5 runtime tsv（build_cht.py 順手烘的 TTF 字型不用，下一步會被倚天版覆蓋）
python3 tools/build_cht.py "$UTF8" dist-cht --size 15 >/dev/null
rm -f dist-cht/kq1_ttf_big5.fnt

# 4) 倚天點陣字（1990s DOS 中文原貌，勝過 TTF rasterize）
python3 tools/build_eten_font.py "$UTF8" dist-cht --prefix kq1

ls -la dist-cht/
