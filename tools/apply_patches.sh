#!/bin/bash
# 把 KQ1 繁中化的引擎改動套到一棵乾淨的 ScummVM 原始碼樹（兩軌都套）。
# 用法：tools/apply_patches.sh <scummvm-src-dir>
# 目錄不存在就自己 clone + checkout 到 pinned commit（CI 用）。
set -euo pipefail
SRC="${1:?用法: apply_patches.sh <scummvm-src-dir>}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
PINNED="$(cat "$HERE/patches/UPSTREAM_COMMIT.txt")"

if [ ! -d "$SRC" ]; then
  echo ">> clone ScummVM → $SRC"
  git clone --quiet https://github.com/scummvm/scummvm.git "$SRC"
fi
echo ">> 目標樹：$SRC"
echo ">> pinned upstream：$PINNED"
git -C "$SRC" checkout --quiet "$PINNED"

# 1) 新增檔（GfxFontChinese：Big5 繪字 + hi-res loader），patch 裡沒有，整檔複製
cp "$HERE/patches/fontchinese.cpp" "$SRC/engines/sci/graphics/fontchinese.cpp"
cp "$HERE/patches/fontchinese.h"   "$SRC/engines/sci/graphics/fontchinese.h"

# 2) SCI 軌（1990 重製版）：ZH_TWN 啟用、Big5 繪字、kFormat 模板 + %s 參數 hook、
#    GetLongest 中文斷行（含 SCI0 提早斷行的修正）、DrawStatus 雙位元組、標題疊圖、SCI_DUMP_RES
patch -p1 -d "$SRC" < "$HERE/patches/0001-sci-cht-kq1.patch"

# 3) AGI 軌（1984/1987 原版）：字型檔存在即啟用（不可用 --language）、forceHires 640x400、
#    systemUI／狀態列中文、OBJECT 道具名走 displayText
patch -p1 -d "$SRC" < "$HERE/patches/0002-agi-cht-kq1.patch"

echo ">> 完成。configure（MT-32 必須編入，不可加 --disable-mt32emu）："
echo "   ./configure --disable-all-engines --enable-engine=sci,agi --disable-detection-full && make -j\$(nproc)"
