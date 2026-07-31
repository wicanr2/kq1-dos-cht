#!/usr/bin/env bash
# 把 mingw 交叉編譯出的 scummvm.exe 打包成 Windows x86_64 版(patch 或 full)。
# 同 package_appimage.sh 的理由:KQ1 有 AGI(1984)/SCI(1990)兩個可玩版本,不能用
# --auto-detect 打死一款——包內放 scummvm.ini 預先定義 kq1agi/kq1sci 兩個 target,
# .bat 啟動 `scummvm.exe --config=scummvm.ini`(不帶 target)開 Launcher 讓玩家選版本。
#
# 用法: tools/package_windows.sh <patch|full>
#   patch — 只含引擎 + 中文資料(dist-cht),不含遊戲、不附 MT-32 ROM → 給 GitHub Release
#   full  — 引擎 + 中文資料 + 整個 game/(含 MT-32 ROM 如果本機有) → 只進本機 dist-all/
#
# 前置:先跑 mingw build 產出 build/mingw-tree/scummvm.exe。
# Windows 解壓後的資料夾本身可寫、位置不像 AppImage 掛載點每次會變,所以 scummvm.ini
# 只在「不存在時」產生一次即可(玩家後續在 ScummVM 裡調的設定會留著);若玩家把整個
# 資料夾搬動,舊 ini 路徑會失效,需要手動砍掉 scummvm.ini 重開——這點寫進 README。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"          # /home/anr2/scummvm/king_quest1/workplace
REPO_ROOT="$(cd "$ROOT/.." && pwd)"                # /home/anr2/scummvm/king_quest1
source "$ROOT/tools/pkg_common.sh"                 # stage_mt32_rom

MODE="${1:-}"
case "$MODE" in
  patch|full) ;;
  *) echo "用法: $0 <patch|full>" >&2; exit 1 ;;
esac

MINGW_IMG="${MINGW_IMG:-kq1-mingw}"
EXE="$ROOT/build/mingw-tree/scummvm.exe"
STAGE="$ROOT/build/win64-$MODE"

if [ "$MODE" = "full" ]; then
  DIST="$REPO_ROOT/dist-all"
  OUT="$DIST/KQ1-CHT-full-win64.zip"
else
  DIST="$REPO_ROOT/dist"
  OUT="$DIST/KQ1-CHT-patch-win64.zip"
fi

[ -f "$EXE" ] || { echo "!! 找不到 $EXE（先跑 mingw build：docker run --rm -v \$(pwd)/build/mingw-tree:/src -w /src $MINGW_IMG make -j\$(nproc)）"; exit 1; }

mkdir -p "$DIST"
rm -rf "$STAGE"; mkdir -p "$STAGE/extra"

echo ">> [$MODE] 複製 scummvm.exe + strip"
cp "$EXE" "$STAGE/scummvm.exe"
docker run --rm --name kq1-winpkg-strip -v "$STAGE:/s" "$MINGW_IMG" x86_64-w64-mingw32-strip /s/scummvm.exe

echo ">> [$MODE] 收集 mingw runtime DLL(只需 SDL2.dll + libwinpthread-1.dll,其餘系統內建)"
docker run --rm --name kq1-winpkg-sdl2dll "$MINGW_IMG" cat /usr/x86_64-w64-mingw32/bin/SDL2.dll > "$STAGE/SDL2.dll"
docker run --rm --name kq1-winpkg-pthreaddll "$MINGW_IMG" cat /usr/x86_64-w64-mingw32/lib/libwinpthread-1.dll > "$STAGE/libwinpthread-1.dll"

echo ">> [$MODE] 放入中文資料(translation.tsv + Big5 字型 + 標題疊圖)"
cp -r "$ROOT/dist-cht/." "$STAGE/extra/"

if [ "$MODE" = "full" ]; then
  stage_mt32_rom "$STAGE/extra" || true
  echo ">> [full] 放入整個 game/(AGI 1984 + SCI 1990 兩版)"
  mkdir -p "$STAGE/game"
  cp -r "$ROOT/game/." "$STAGE/game/"
fi

# .bat 啟動器:第一次執行(scummvm.ini 不存在)才產生 ini;之後沿用既有設定。
cat > "$STAGE/玩-國王密令-繁中.bat" <<'BAT'
@echo off
chcp 950 >nul
cd /d "%~dp0"

if exist scummvm.ini goto :launch

> scummvm.ini echo [scummvm]
rem GUI 的中文字型(kq1_gui.fnt)在遊戲啟動前就要載入,game section 的 extrapath 那時
rem 還沒生效 —— 少了這行,啟動器清單裡的中文遊戲名會變成一排方塊。
>>scummvm.ini echo extrapath=%~dp0extra
>>scummvm.ini echo.
>>scummvm.ini echo [kq1agi]
>>scummvm.ini echo description=國王密令 I（1984 AGI 原版）
>>scummvm.ini echo engineid=agi
>>scummvm.ini echo gameid=kq1
>>scummvm.ini echo extrapath=%~dp0extra
if exist "game\agi_1984\KQ1\OBJECT" >>scummvm.ini echo path=%~dp0game\agi_1984\KQ1
if exist "extra\MT32_CONTROL.ROM" >>scummvm.ini echo music_driver=mt32
>>scummvm.ini echo.
>>scummvm.ini echo [kq1sci]
>>scummvm.ini echo description=國王密令 I（1990 SCI 重製版）
>>scummvm.ini echo engineid=sci
>>scummvm.ini echo gameid=kq1sci
>>scummvm.ini echo language=tw
>>scummvm.ini echo extrapath=%~dp0extra
if exist "game\sci_1990\KQ1NEW\RESOURCE.MAP" >>scummvm.ini echo path=%~dp0game\sci_1990\KQ1NEW
if exist "extra\MT32_CONTROL.ROM" >>scummvm.ini echo music_driver=mt32

:launch
scummvm.exe --config=scummvm.ini
BAT

# README 內容依 patch/full 組字串,避免巢狀 heredoc(易讀錯 delimiter)。
if [ "$MODE" = "full" ]; then
  README_TITLE="完整包"
  README_EXTRA_LINE="中文資料（translation.tsv、Big5 字型、標題疊圖、MT-32 ROM（若隨附））"
  README_GAME_LINE=$'  game\\                           遊戲本體（AGI 1984 + SCI 1990 兩版，已內嵌）\n'
  README_HOWTO=""
  README_MT32="  已內附 ROM 時 scummvm.ini 會自動帶 music_driver=mt32；若想改用其他驅動，在 ScummVM 音效設定裡改。"
else
  README_TITLE="patch 包（不含遊戲本體）"
  README_EXTRA_LINE="中文資料（translation.tsv、Big5 字型、標題疊圖）"
  README_GAME_LINE=""
  README_HOWTO="本包不含遊戲資源。第一次執行後，ScummVM 清單裡 kq1agi / kq1sci 兩個項目會顯示「找不到遊戲資料」，
請在清單裡點選該項目 →「編輯遊戲」→ 把「遊戲路徑」指到你自備的 KQ1 資料夾
（AGI 版指到含 OBJECT/WORDS.TOK/VOL.0 等檔案的資料夾；SCI 版指到含 RESOURCE.MAP/RESOURCE.001 的資料夾）即可。
語言（SCI 版 language=tw）、中文資料路徑（extrapath）都已預先設定好，不需要另外調整。
"
  README_MT32="  本包未附 ROM（版權因素不隨 patch 散布）。自備 MT-32_CONTROL.ROM + MT32_PCM.ROM 放進 extra\\ 資料夾後刪掉 scummvm.ini 重開一次即可自動偵測。"
fi

cat > "$STAGE/README.txt" <<TXT
國王密令 I（King's Quest I: Quest for the Crown）繁體中文化 — Windows x86_64 $README_TITLE

雙擊「玩-國王密令-繁中.bat」開啟 ScummVM，清單裡有兩個項目：
  kq1agi  — 1984 AGI 原版
  kq1sci  — 1990 SCI 重製版

內容物：
  scummvm.exe                    patched ScummVM（AGI+SCI 雙軌 Big5 中文繪字 + MT-32 音源模擬）
  SDL2.dll / libwinpthread-1.dll  執行所需 runtime（其餘為 Windows 系統內建 DLL）
  extra\\                         $README_EXTRA_LINE
$README_GAME_LINE
$README_HOWTO
若要用 Roland MT-32 音源（推薦，音色遠優於 AdLib）：
$README_MT32

若把整個資料夾搬到別的路徑：請先刪除 scummvm.ini 再重新執行一次 .bat，讓它依新路徑重新產生設定檔
（先前手動加入的遊戲路徑需要重新指定一次）。

repo（patch-only，不含遊戲資源/ROM）：https://github.com/wicanr2/kq1-dos-cht
TXT

OUT_TMP="$OUT"
rm -f "$OUT_TMP"
echo ">> [$MODE] zip 打包"
( cd "$STAGE" && zip -qr "$OUT_TMP" . )
echo ">> [$MODE] 完成: $OUT_TMP ($(du -h "$OUT_TMP" | cut -f1))"
