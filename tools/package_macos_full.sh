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
# [HARD] 資料夾**不能**叫 "game"。ScummVM 的 macOS backend（backends/platform/sdl/macosx/
# macosx_osys_misc.mm）看到 <bundle>/Contents/Resources/game 是資料夾，就會強制
# command="auto-detect"、settings["path"]=那個資料夾，而且**不遞迴**。KQ1 兩個版本分別放在
# game/agi_1984/KQ1 與 game/sci_1990/KQ1NEW 的子目錄裡，在上層那一階當然偵測不到 →
#   WARNING: ScummVM could not find any game in .../Contents/Resources/game
#   WARNING: Game data not found!
# 然後以 kNoGameDataFoundError 結束，畫面連開都沒開（GitHub issue #1）。跟 --config、跟
# 啟動器有沒有指定 target 都無關，改名就沒事。同理也別叫 "games"（那個名字會被 backend
# 拿去自動加進啟動器清單）。
GAME_DST="$APP/Contents/Resources/kq1-game"
rm -rf "$GAME_DST"; mkdir -p "$GAME_DST"
cp -R "$ROOT/game/." "$GAME_DST/"
[ -f "$GAME_DST/agi_1984/KQ1/OBJECT" ] || echo "!! 警告：AGI 版遊戲檔看起來不完整" >&2
[ -f "$GAME_DST/sci_1990/KQ1NEW/RESOURCE.MAP" ] || echo "!! 警告：SCI 版遊戲檔看起來不完整" >&2

echo ">> MT-32 ROM（完整包專用，本機無 IP 顧慮）"
stage_mt32_rom "$CHT_DIR" || true

# [HARD] 不動 .app bundle。
#
# 舊版做法是「把原執行檔改名成 scummvm-real、塞一支 bash wrapper 進 Contents/MacOS/、
# 再改 Info.plist 的 CFBundleExecutable 指過去」。那條路每一環都可能讓玩家看到「雙擊
# 沒反應」：script 當 bundle 進入點、改過的 Info.plist、以及 codesign --deep 對這種
# 混合結構的處理，任何一個出問題都不會有錯誤訊息（Finder 啟動時沒有終端機可看）。
# GitHub issue #1 回報的就是這個症狀。
#
# 現在改成跟 Windows 的 .bat 同一套：**.app 保持 CI 產出的原樣**，另外在它旁邊放一支
# 啟動器 .command，由它寫設定檔並帶 --config 啟動。.app 的結構與簽章完全沒被碰過，
# 而且雙擊 .command 會開終端機視窗——萬一有錯誤，玩家看得到、也回報得出來。
echo ">> 產生啟動器（.app 保持原樣，不改 CFBundleExecutable）"
echo ">> 移除舊簽章（內容已改，舊 _CodeSignature 一定失效）"
rm -rf "$APP/Contents/_CodeSignature"

WRAP="$WORK/out"; mkdir -p "$WRAP"
mv "$APP" "$WRAP/ScummVM.app"
cat > "$WRAP/PLAY-KQ1-CHT.command" <<'LAUNCH'
#!/bin/bash
# 啟動器：寫一份設定檔到自己旁邊，再用它啟動未經改動的 ScummVM.app。
# 刻意不寫 ~/Library/Preferences/ScummVM Preferences —— 那是 ScummVM 的全域設定檔，
# 覆蓋掉玩家原本裝的 ScummVM 設定不禮貌。
cd "$(dirname "$0")" || exit 1
HERE="$(pwd)"
APP="$HERE/ScummVM.app"
BIN="$APP/Contents/MacOS/scummvm"
EXTRA="$APP/Contents/Resources/cht-data"
GAMEROOT="$APP/Contents/Resources/kq1-game"   # 不能叫 game，見打包腳本裡的說明
CFG="$HERE/scummvm.ini"

if [ ! -x "$BIN" ]; then
  echo "找不到 $BIN"
  echo "請確認整個資料夾都解開了，而且 ScummVM.app 與這支啟動器放在一起。"
  read -n1 -p "按任意鍵關閉…"
  exit 1
fi

MT32LINE=""
[ -f "$EXTRA/MT32_CONTROL.ROM" ] && MT32LINE="music_driver=mt32"

# 舊版的包把遊戲放在 Contents/Resources/game，設定檔裡留的是那條路徑；沿用舊 ini 會指向
# 一個已經不存在的資料夾。玩家把整個資料夾搬家時也一樣（ini 裡是絕對路徑）。所以除了
# 「檔案不存在」以外，「裡面的路徑跟現在對不上」也要重寫，舊檔留一份 .bak。
if [ ! -f "$CFG" ] || ! grep -Fq "path=$GAMEROOT/sci_1990/KQ1NEW" "$CFG"; then
[ -f "$CFG" ] && cp "$CFG" "$CFG.bak"
cat > "$CFG" <<EOF
[scummvm]
gui_language=en
extrapath=$EXTRA
# 存檔/讀檔一律用清單式介面。縮圖格狀介面（SaveLoadChooserGrid）在遊戲內開啟時崩過一次
# （GitHub issue #2），清單那條路徑不經過它。
gui_saveload_chooser=list

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
fi

"$BIN" --config="$CFG"
rc=$?
if [ $rc -ne 0 ]; then
  echo
  echo "ScummVM 結束時回報錯誤（代碼 $rc），上面的訊息可能說明了原因。"
  read -n1 -p "按任意鍵關閉…"
fi
LAUNCH
chmod +x "$WRAP/PLAY-KQ1-CHT.command"

cat > "$WRAP/修復-macOS.command" <<'FIX'
#!/bin/bash
cd "$(dirname "$0")"; echo "處理中…"
xattr -cr ScummVM.app 2>/dev/null
xattr -cr PLAY-KQ1-CHT.command 2>/dev/null
codesign --force --deep --sign - ScummVM.app 2>/dev/null && echo "已重簽。" || echo "（codesign 略過）"
echo "完成！接著雙擊 PLAY-KQ1-CHT.command 開始遊戲。"
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
tar czf "$OUT" -C "$WRAP" "ScummVM.app" "PLAY-KQ1-CHT.command" "修復-macOS.command"
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
