#!/usr/bin/env bash
# 把 macOS CI（.github/workflows/build-macos.yml）產出的「空引擎」ScummVM.app，
# 注入 KQ1 繁中資料（dist-cht/ 的 translation.tsv + 字型 + 標題疊圖）+ README，
# 重新打包成可交付檔。在 CI runner 內跑（bash 內建即可，不需 docker/python）。
#
# 用法：tools/package_macos_data.sh <engine.tar.gz 或 .app 路徑> <輸出目錄>
#
# 交付原則（硬）：.app 只含 patched 引擎 + 中文資料；原遊戲資源與 MT-32 ROM 絕不塞入。
# [雷] 注入清單要含 dist-cht/ 的「全部」檔案——只複製 translation.tsv + *.fnt 會漏掉
#      標題疊圖 .ovl，macOS 版就沒有中文標題（KQ4 踩過）。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${1:?用法: package_macos_data.sh <engine.tar.gz|.app> <輸出目錄>}"
OUT="${2:?需指定輸出目錄}"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if [ -d "$SRC" ] && [[ "$SRC" == *.app ]]; then
  cp -R "$SRC" "$WORK/ScummVM.app"
else
  tar xzf "$SRC" -C "$WORK"
fi
APP="$(find "$WORK" -maxdepth 2 -iname '*.app' -type d | head -1)"
[ -n "$APP" ] || { echo "!! 在 $SRC 裡找不到 .app" >&2; exit 1; }

CHT_DIR="$APP/Contents/Resources/cht-data"
echo ">> 注入中文資料 → $CHT_DIR"
rm -rf "$CHT_DIR"; mkdir -p "$CHT_DIR"
[ -f "$ROOT/dist-cht/translation.tsv" ] || { echo "!! 找不到 $ROOT/dist-cht/translation.tsv" >&2; exit 1; }
cp "$ROOT"/dist-cht/* "$CHT_DIR/"
echo ">>    staged $(ls "$CHT_DIR" | wc -l) 個中文資料檔："
ls "$CHT_DIR"

cat > "$APP/Contents/Resources/README-cht.txt" <<'EOF'
國王密令（King's Quest I）繁體中文化 — macOS 版

本 .app 只含中文化過的 ScummVM 引擎與中文資料，不含遊戲本身，請自備正版遊戲檔。

一、第一次執行
   macOS 會擋未簽署的程式。在終端機執行一次：
     xattr -dr com.apple.quarantine /Applications/ScummVM.app
   （或把 .app 放到你要的位置後對該路徑執行）

二、加入遊戲
   1. 開啟 ScummVM.app → 「加入遊戲」
   2. 1990 SCI 重製版：選含 RESOURCE.MAP / RESOURCE.001 的資料夾
      1984/1987 AGI 原版：選含 LOGDIR / VOL.0 的資料夾
   3. 加入後點該遊戲 →「遊戲選項」→「路徑」分頁 →「額外路徑」指到
      ScummVM.app/Contents/Resources/cht-data
      （在 Finder 對 .app 按右鍵「顯示套件內容」可進去）

三、中文怎麼啟用
   - SCI（1990）：遊戲選項 →「遊戲」分頁 → 語言選「繁體中文 (tw)」
   - AGI（1984/1987）：不要設語言，維持英文即可。AGI 靠「找得到 kq1_big5.fnt」
     來啟用中文；設成非英文語言反而會讓遊戲開不起來。

四、MT-32 音樂（選用）
   自備 MT32_CONTROL.ROM 與 MT32_PCM.ROM 放進遊戲資料夾，
   音效選項選 Roland MT-32。

譯名依第三波資訊文化事業《國王密令》PC22 中文說明書。
EOF

mkdir -p "$OUT"
tar czf "$OUT/KQ1-CHT-patch-macos-universal.tar.gz" -C "$WORK" "$(basename "$APP")"
if command -v hdiutil >/dev/null 2>&1; then
  hdiutil create -volname "KQ1-CHT" -srcfolder "$APP" -ov -format UDZO \
    "$OUT/KQ1-CHT-patch-macos-universal.dmg"
fi
ls -la "$OUT"

echo ">> 驗收：包內不得有任何遊戲資源"
if find "$OUT" -maxdepth 1 -type f | while read -r f; do tar tzf "$f" 2>/dev/null; done | \
   grep -iE "RESOURCE\.(MAP|00[0-9])|VOL\.[0-9]|\.DRV$|SCIV\.EXE|LOGDIR|PICDIR|WORDS\.TOK|\.ROM$"; then
  echo "### 包內含遊戲資源，不可發布 ###"; exit 1
fi
echo ">> OK：只有引擎與中文資料"
