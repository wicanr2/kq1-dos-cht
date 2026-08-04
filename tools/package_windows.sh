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

# GUI theme。曾經因為 mingw 樹沒有 FreeType 而拿掉過（theme 的字型是 TTF，載入必定失敗、
# 退回內建陽春樣式），後來在 docker/Dockerfile.mingw 補上交叉編譯的 freetype，
# config.h 變成 #define USE_FREETYPE2，theme 就正常了。
# 換 mingw image 後若又看到 `Error loading localized Font in theme engine`，先確認
# `grep USE_FREETYPE2 build/mingw-tree/config.h` 是不是又變回 #undef。
cp "$ROOT/scummvm-src/gui/themes/scummremastered.zip" "$STAGE/extra/"

if [ "$MODE" = "full" ]; then
  stage_mt32_rom "$STAGE/extra" || true
  echo ">> [full] 放入整個 game/(AGI 1984 + SCI 1990 兩版)"
  mkdir -p "$STAGE/game"
  cp -r "$ROOT/game/." "$STAGE/game/"
fi

# scummvm.ini 模板：**靜態 UTF-8 檔案**，不由 .bat 的 echo 產生。
#
# [HARD] .bat 不能拿來 echo 中文寫 ini：cmd.exe 逐行以「目前 code page」解讀 .bat，
# 而 ScummVM 讀 ini 是 UTF-8。要嘛 .bat 存成 CP950 讓 cmd 讀對、寫出去的 ini 變 Big5
# 讓 ScummVM 讀錯，要嘛存成 UTF-8 讓 ScummVM 讀對、cmd 卻把中文看成亂碼而指令解析失敗
# ——兩邊不可能同時滿足。改成「模板檔用 UTF-8 預先寫好，.bat 只負責複製」就沒有這個矛盾，
# .bat 本身可以維持純 ASCII。
#
# 路徑一律用相對路徑（相對於 .bat 所做的 cd /d "%~dp0"）：省掉 %~dp0 展開與跳脫，
# 玩家把整包搬到任何位置都不用改設定。實測 ScummVM 的 extrapath/path
# 都吃相對路徑。
INI_TMPL="$STAGE/extra/scummvm.ini.default"
{
  echo "[scummvm]"
  # [HARD] GUI 語言鎖英文。不設的話 ScummVM 會依系統地區自動挑翻譯,而 theme 對非英文語言
  # 一律要求 scalable(TTF) 字型(ThemeEngine::loadFont 的 allowNonScalable =
  # TransMan.currentIsBuiltinLanguage())—— mingw 沒有 FreeType 就整個 theme 載入失敗、
  # 退回內建陽春樣式。繁中的 GUI 翻譯上游是空的(3228 條全未翻),抓到的多半是簡體,
  # 對繁中化專案更糟。鎖英文同時解決兩件事,而且不必為了 theme 去交叉編 FreeType
  # (那會讓 ScummVM 連 37MB 的 fonts-cjk.dat 一起嵌進 exe,包從 11M 變 54M)。
  # 遊戲清單裡的中文遊戲名不受影響 —— 那是 ChtGuiFont 畫的,與 GUI 語言無關。
  echo "gui_language=en"
  # GUI 的中文字型(kq1_gui.fnt)在遊戲啟動前就要載入,game section 的 extrapath 那時
  # 還沒生效 —— 少了這行,啟動器清單裡的中文遊戲名會變成一排方塊。
  echo "extrapath=extra"
  echo "themepath=extra"
  # 存檔/讀檔一律用清單式介面。縮圖格狀介面(SaveLoadChooserGrid)在遊戲內開啟時崩過一次
  # (GitHub issue #2),清單那條路徑不經過它。
  echo "gui_saveload_chooser=list"
  echo
  echo "[kq1agi]"
  echo "description=國王密令 I（1984 AGI 原版）"
  echo "engineid=agi"
  echo "gameid=kq1"
  echo "extrapath=extra"
  [ "$MODE" = "full" ] && echo "path=game/agi_1984/KQ1"
  [ -f "$STAGE/extra/MT32_CONTROL.ROM" ] && echo "music_driver=mt32"
  echo
  echo "[kq1sci]"
  echo "description=國王密令 I（1990 SCI 重製版）"
  echo "engineid=sci"
  echo "gameid=kq1sci"
  echo "language=tw"
  echo "extrapath=extra"
  [ "$MODE" = "full" ] && echo "path=game/sci_1990/KQ1NEW"
  [ -f "$STAGE/extra/MT32_CONTROL.ROM" ] && echo "music_driver=mt32"
} > "$INI_TMPL"

# .bat 啟動器：內容全 ASCII、換行 CRLF、檔名也全 ASCII。
#
# [HARD] 三件事都必須做到，少一件玩家那端就是「黑視窗閃一下就沒了」或「檔案解壓後消失」：
#   1. 換行必須 CRLF。cmd.exe 對 LF-only 的 .bat 解析不可靠（label/goto 尤其容易整支中斷）。
#   2. 內容維持純 ASCII，中文一律放在上面那份 UTF-8 的 ini 模板裡。
#   3. 檔名維持純 ASCII —— Linux 的 zip 寫 UTF-8 檔名卻不設 UTF-8 旗標時，
#      Windows 內建解壓縮會用系統 ANSI(CP950) 解讀，中文檔名變非法字元、該檔直接解不出來。
#      （下面 zip 也補上 -UN=UTF8，但檔名保持 ASCII 才是真正保險的那道。）
printf '%s\r\n' \
  '@echo off' \
  'cd /d "%~dp0"' \
  '' \
  'rem First run: seed scummvm.ini from the UTF-8 template (Chinese game names live there).' \
  'if not exist "scummvm.ini" copy /y "extra\scummvm.ini.default" "scummvm.ini" >nul' \
  '' \
  'if not exist "scummvm.exe" (' \
  '  echo scummvm.exe not found. Extract the whole ZIP first, then run this file.' \
  '  pause' \
  '  exit /b 1' \
  ')' \
  '' \
  'scummvm.exe --config=scummvm.ini' \
  'if errorlevel 1 (' \
  '  echo.' \
  '  echo ScummVM exited with an error. The message above may explain why.' \
  '  pause' \
  ')' \
  > "$STAGE/PLAY-KQ1-CHT.bat"

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

# 開頭補 UTF-8 BOM：Windows 舊版記事本看到沒有 BOM 的 UTF-8 會當成 ANSI(CP950) 解讀，
# 中文就變亂碼。BOM 只有三個位元組，換掉整份文件讀不了的風險很划算。
printf '\xEF\xBB\xBF' > "$STAGE/README.txt"
cat >> "$STAGE/README.txt" <<TXT
國王密令 I（King's Quest I: Quest for the Crown）繁體中文化 — Windows x86_64 $README_TITLE

【怎麼玩】
  1. 把整個 ZIP 解開到同一個資料夾（不要只解出 .bat 單獨執行）
  2. 雙擊 PLAY-KQ1-CHT.bat
  3. ScummVM 清單裡有兩個項目，挑一個雙擊：
       國王密令 I（1984 AGI 原版）
       國王密令 I（1990 SCI 重製版）

  .bat 只做兩件事：切到自己所在的資料夾、第一次執行時把 extra\\scummvm.ini.default
  複製成 scummvm.ini，然後啟動 scummvm.exe。若它閃一下就關掉，多半是 ZIP 沒有完整解開，
  這時 .bat 會停下來顯示訊息（按任意鍵才關閉），照著訊息處理即可。

內容物：
  PLAY-KQ1-CHT.bat               啟動器（內容為純 ASCII，避免 cmd.exe 的編碼問題）
  scummvm.exe                    patched ScummVM（AGI+SCI 雙軌 Big5 中文繪字 + MT-32 音源模擬）
  SDL2.dll / libwinpthread-1.dll  執行所需 runtime（其餘為 Windows 系統內建 DLL）
  extra\\                         $README_EXTRA_LINE
$README_GAME_LINE
$README_HOWTO
若要用 Roland MT-32 音源（推薦，音色遠優於 AdLib）：
$README_MT32

設定檔 scummvm.ini 裡的路徑全部是相對路徑，所以整個資料夾搬到任何位置都能直接用，
不需要刪掉重建。

repo（patch-only，不含遊戲資源/ROM）：https://github.com/wicanr2/kq1-dos-cht
TXT

OUT_TMP="$OUT"
rm -f "$OUT_TMP"
echo ">> [$MODE] zip 打包"
# -UN=UTF8：把檔名以 UTF-8 存並「設好 UTF-8 旗標(general purpose bit 11)」。
# 少了旗標，Windows 內建解壓縮會拿系統 ANSI(繁中是 CP950) 去解讀 UTF-8 檔名位元組，
# 非 ASCII 檔名就變成非法字元、該檔直接解不出來 —— 玩家看到的現象是「檔案消失」。
( cd "$STAGE" && zip -qr -UN=UTF8 "$OUT_TMP" . )
echo ">> [$MODE] 完成: $OUT_TMP ($(du -h "$OUT_TMP" | cut -f1))"
