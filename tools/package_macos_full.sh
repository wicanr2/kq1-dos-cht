#!/usr/bin/env bash
# 把 macOS CI 產出的 patch 版 .app（引擎 + 中文資料）在本機注入整個 game/ 與 MT-32 ROM，
# 組成「開箱即玩」的 full 包 → 只進本機 dist-all/，絕不上 GitHub。
#
# 用法: tools/package_macos_full.sh <KQ1-CHT-patch-macos-universal.tar.gz 或 .app 路徑>
#
# 為什麼要一支獨立腳本：macOS 的 .app/.dmg 只能在 macOS host build，但 CI runner 拿不到
# 遊戲資源與 ROM（都 gitignore），所以 CI 只出 patch 版，full 版一律「下載 CI artifact →
# 本機注入」。
#
# KQ1 有 AGI(1984) / SCI(1990) 兩個可玩版本，不能用 --auto-detect 打死一款，所以跟
# AppImage 的 AppRun 同一套做法：wrapper 在使用者可寫的 ~/Library 下寫一份預先定義
# kq1agi / kq1sci 兩個 target 的 scummvm.ini，再開 ScummVM 自帶的 Launcher 讓玩家挑。
#
# [HARD] 產出只留 dist-all/。ROM 與遊戲資源有版權，不入版控、不上 Release。
# [注意] Linux 沒有 codesign，這裡只能把舊簽章拿掉；使用者第一次在 Mac 上要跑一次
#        包內的「修復-macOS.command」做去隔離 + ad-hoc 重簽，再開 .app。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT/.." && pwd)"
source "$ROOT/tools/pkg_common.sh"                 # stage_mt32_rom

SRC="${1:?用法: package_macos_full.sh <patch tar.gz|.app 路徑>}"
DIST="$REPO_ROOT/dist-all"
OUT="$DIST/KQ1-CHT-full-macos-universal.tar.gz"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo ">> 展開來源"
if [ -d "$SRC" ] && [[ "$SRC" == *.app ]]; then
  cp -R "$SRC" "$WORK/ScummVM.app"
else
  tar xzf "$SRC" -C "$WORK"
fi
APP="$(find "$WORK" -maxdepth 2 -iname '*.app' -type d | head -1)"
[ -n "$APP" ] || { echo "!! 在 $SRC 裡找不到 .app" >&2; exit 1; }

CHT_DIR="$APP/Contents/Resources/cht-data"
[ -f "$CHT_DIR/translation.tsv" ] || { echo "!! 來源 .app 缺中文資料（$CHT_DIR）" >&2; exit 1; }

echo ">> 注入整個 game/（AGI 1984 + SCI 1990 兩版）"
GAME_DST="$APP/Contents/Resources/game"
rm -rf "$GAME_DST"; mkdir -p "$GAME_DST"
cp -R "$ROOT/game/." "$GAME_DST/"
[ -f "$GAME_DST/agi_1984/KQ1/OBJECT" ] || echo "!! 警告：AGI 版遊戲檔看起來不完整" >&2
[ -f "$GAME_DST/sci_1990/KQ1NEW/RESOURCE.MAP" ] || echo "!! 警告：SCI 版遊戲檔看起來不完整" >&2

echo ">> MT-32 ROM（完整包專用，本機無 IP 顧慮）"
stage_mt32_rom "$CHT_DIR" || true

echo ">> 換上 wrapper 當 CFBundleExecutable（直指包內 game，玩家免輸路徑）"
REAL_BIN="$(ls "$APP/Contents/MacOS" | head -1)"
[ -n "$REAL_BIN" ] || { echo "!! Contents/MacOS 是空的" >&2; exit 1; }
if [ "$REAL_BIN" = "kq1-launcher" ]; then
  echo "!! 來源已經是 full 包（wrapper 已就位），請用原始的 patch 包當來源" >&2; exit 1
fi
mv "$APP/Contents/MacOS/$REAL_BIN" "$APP/Contents/MacOS/scummvm-real"

cat > "$APP/Contents/MacOS/kq1-launcher" <<'LAUNCH'
#!/bin/bash
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
RES="$(cd "$HERE/../Resources" && pwd)"
BIN="$HERE/scummvm-real"
EXTRA="$RES/cht-data"
GAMEROOT="$RES/game"

# .app 內部唯讀，設定檔一律寫使用者家目錄
CFG="$HOME/Library/Application Support/kq1-cht/scummvm.ini"
mkdir -p "$(dirname "$CFG")"

MT32LINE=""
[ -f "$EXTRA/MT32_CONTROL.ROM" ] && MT32LINE="music_driver=mt32"

cat > "$CFG" <<EOF
[scummvm]
# GUI 的中文字型（kq1_gui.fnt）在遊戲啟動前就要載入，game section 的 extrapath 那時還
# 沒生效 —— 少了這行，啟動器清單裡的中文遊戲名會變成一排方塊。
extrapath=$EXTRA

[kq1agi]
description=國王密令 I（1984 AGI 原版）
engineid=agi
gameid=kq1
path=$GAMEROOT/agi_1984/KQ1
extrapath=$EXTRA
$MT32LINE

[kq1sci]
description=國王密令 I（1990 SCI 重製版）
engineid=sci
gameid=kq1sci
language=tw
path=$GAMEROOT/sci_1990/KQ1NEW
extrapath=$EXTRA
$MT32LINE
EOF

exec "$BIN" --config="$CFG"
LAUNCH
chmod +x "$APP/Contents/MacOS/kq1-launcher"

PLIST="$APP/Contents/Info.plist"
if grep -q "<key>CFBundleExecutable</key>" "$PLIST"; then
  # plist 是 XML：把 CFBundleExecutable 的下一行 <string> 換成 wrapper
  perl -0pi -e 's|(<key>CFBundleExecutable</key>\s*<string>)[^<]*(</string>)|${1}kq1-launcher${2}|s' "$PLIST"
  echo ">>    CFBundleExecutable → kq1-launcher"
else
  echo "!! Info.plist 沒有 CFBundleExecutable，wrapper 不會生效" >&2; exit 1
fi

echo ">> 移除舊簽章（內容已改，舊 _CodeSignature 一定失效）"
rm -rf "$APP/Contents/_CodeSignature"

WRAP="$WORK/out"; mkdir -p "$WRAP"
mv "$APP" "$WRAP/ScummVM.app"
cat > "$WRAP/修復-macOS.command" <<'FIX'
#!/bin/bash
cd "$(dirname "$0")"; echo "處理中…"
xattr -cr ScummVM.app 2>/dev/null
codesign --force --deep --sign - ScummVM.app 2>/dev/null && echo "已重簽。" || echo "（codesign 略過）"
echo "完成！雙擊 ScummVM.app，在清單裡挑 1984 AGI 原版或 1990 SCI 重製版。"
read -n1 -p "按任意鍵關閉…"
FIX
chmod +x "$WRAP/修復-macOS.command"

cat > "$WRAP/ScummVM.app/Contents/Resources/README-cht.txt" <<'RM'
國王密令（King's Quest I）繁體中文化 — macOS 完整包，開箱即玩

內含中文化過的 ScummVM 引擎、中文資料、兩個版本的遊戲本體，以及 MT-32 ROM。

【第一次使用】
  先雙擊「修復-macOS.command」（去隔離 + ad-hoc 重簽），再雙擊 ScummVM.app。
  未簽署的 app 若直接開會被 Gatekeeper 擋下。

【玩哪一版】
  開起來是 ScummVM 的遊戲清單，裡面已經放好兩個項目：
    國王密令 I（1984 AGI 原版）
    國王密令 I（1990 SCI 重製版）
  路徑與中文設定都預先填好了，直接雙擊就能玩。

【音樂】
  已預設 Roland MT-32（包內附 ROM）。想換成 AdLib 可到遊戲選項改。

譯名依第三波資訊文化事業《國王密令》PC22 中文說明書。
RM

mkdir -p "$DIST"
echo ">> 打包 → $OUT"
tar czf "$OUT" -C "$WRAP" "ScummVM.app" "修復-macOS.command"
ls -lh "$OUT"

echo ">> 驗收：full 包必須含遊戲資源（與 patch 包相反）"
# [雷] 先把清單收進變數再比對，別 `tar tzf ... | grep -q`：grep -q 一命中就關掉管線，
# tar 吃到 SIGPIPE 回非 0，在 set -o pipefail 下整條判成失敗 —— 包是好的卻報「缺資源」。
LIST="$(tar tzf "$OUT")"
if printf '%s\n' "$LIST" | grep -q "RESOURCE\.MAP" && printf '%s\n' "$LIST" | grep -q "LOGDIR"; then
  echo ">> OK：AGI 與 SCI 兩版資源都在包內"
else
  echo "### full 包缺遊戲資源 ###"; exit 1
fi
