#!/usr/bin/env bash
# 把 patched ScummVM(AGI+SCI 雙軌)打包成 Linux x86_64 AppImage。
# KQ1 有兩個可玩版本（1984 AGI 原版 / 1990 SCI 重製版），跟只有單一版本的 KQ4 不同，
# 不能用 --auto-detect 打死一款——改用「包內 scummvm.ini 預先定義 kq1agi/kq1sci 兩個
# target」的做法：AppRun 啟動時（在使用者可寫的 $HOME 下）產生/更新這份 ini 再
# `scummvm --config=<ini>`（不帶 target 參數）開啟 ScummVM 自帶的 Launcher，玩家在裡面
# 用清單選 AGI 或 SCI 版。
#
# 用法: tools/package_appimage.sh <patch|full>
#   patch — 只含引擎 + 中文資料(dist-cht),不含遊戲、不附 MT-32 ROM → 給 GitHub Release
#   full  — 引擎 + 中文資料 + 整個 game/(含 MT-32 ROM 如果本機有) → 只進本機 dist-all/
#
# AppImage 用 --appimage-extract-and-run 執行時,每次掛載點路徑都不同(squashfs-root 每次
# 重新解壓到新的臨時目錄)——所以 AppRun 每次啟動都要重新計算 $HERE 並刷新 ini 裡的
# extrapath/engineid/gameid/music_driver;但玩家在 patch 版透過「編輯遊戲/Add Game」
# 設定的遊戲路徑(path=)要保留,所以用 awk 從舊 ini 讀回來再寫回新 ini。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"          # /home/anr2/scummvm/king_quest1/workplace
REPO_ROOT="$(cd "$ROOT/.." && pwd)"                # /home/anr2/scummvm/king_quest1
source "$ROOT/tools/pkg_common.sh"                 # stage_mt32_rom

MODE="${1:-}"
case "$MODE" in
  patch|full) ;;
  *) echo "用法: $0 <patch|full>" >&2; exit 1 ;;
esac

BUILD_IMG="kq1-build:latest"
STAGE="$ROOT/build/appimg-$MODE"
APPDIR="$STAGE/AppDir"

if [ "$MODE" = "full" ]; then
  DIST="$REPO_ROOT/dist-all"
  OUT="$DIST/KQ1-CHT-full-x86_64.AppImage"
else
  DIST="$REPO_ROOT/dist"
  OUT="$DIST/KQ1-CHT-patch-x86_64.AppImage"
fi

mkdir -p "$DIST"
rm -rf "$APPDIR"; mkdir -p "$APPDIR/usr/bin" "$APPDIR/usr/lib" "$APPDIR/usr/share/cht"

echo ">> [$MODE] 複製 scummvm + strip"
cp "$ROOT/scummvm-src/scummvm" "$APPDIR/usr/bin/scummvm"
docker run --rm --name kq1-pkg-strip -v "$APPDIR/usr/bin:/b" "$BUILD_IMG" strip /b/scummvm 2>/dev/null || true

echo ">> [$MODE] 收集共享庫(kq1-build 內 ldd,排除 glibc 核心)"
docker run --rm --name kq1-pkg-libs \
  -v "$APPDIR/usr/bin/scummvm:/collect/bin:ro" \
  -v "$APPDIR/usr/lib:/collect/out" \
  -v "$ROOT/tools/pkg_collect_libs.py:/collect/collect.py:ro" \
  -w /collect "$BUILD_IMG" python3 collect.py bin out
echo "   $(ls "$APPDIR/usr/lib" | wc -l) 個 .so"

echo ">> [$MODE] 放入中文資料(translation.tsv + Big5 字型 + 標題疊圖)"
cp -r "$ROOT/dist-cht/." "$APPDIR/usr/share/cht/"

# GUI theme：AppImage 不帶 theme 就會退回內建的陽春樣式,而內建那條路徑不經過
# ThemeEngine::loadFont —— 中文遊戲名就算有字型也畫不出來(會是一排方塊)。
# 只有 95K,順手補齊 GUI 外觀。
cp "$ROOT/scummvm-src/gui/themes/scummremastered.zip" "$APPDIR/usr/share/cht/"

# MT-32 ROM(僅 full 版才附;有 ROM 才讓 AppRun 把 music_driver 設成 mt32)
if [ "$MODE" = "full" ]; then
  stage_mt32_rom "$APPDIR/usr/share/cht" || true
fi

# 遊戲資料(僅 full 版內嵌;patch 版完全不放,靠玩家自備 + 在 ScummVM 內指路徑)
if [ "$MODE" = "full" ]; then
  echo ">> [full] 放入整個 game/(AGI 1984 + SCI 1990 兩版)"
  mkdir -p "$APPDIR/usr/share/game"
  cp -r "$ROOT/game/." "$APPDIR/usr/share/game/"
fi

# AppRun:啟動時在 $HOME 下產生/更新 scummvm.ini(kq1agi + kq1sci 兩個 target),
# 不帶 target 直接開 Launcher,玩家清單裡選 AGI 或 SCI。
# [HARD] linuxdeploy 這類工具會把 AppDir/AppRun 建成 symlink 指向真 binary,
# 這裡用 cat > 前一律先 rm -f 避免 `>` 穿透 symlink 覆寫掉 binary。
rm -f "$APPDIR/AppRun"
cat > "$APPDIR/AppRun" <<'APPRUN'
#!/bin/bash
set -e
HERE="$(dirname "$(readlink -f "$0")")"
export LD_LIBRARY_PATH="$HERE/usr/lib:${LD_LIBRARY_PATH:-}"
BIN="$HERE/usr/bin/scummvm"
EXTRA="$HERE/usr/share/cht"
GAMEROOT="$HERE/usr/share/game"

CFG="$HOME/.config/kq1-cht/__VARIANT__-scummvm.ini"
mkdir -p "$(dirname "$CFG")"

# 內嵌版(full)一律指向包內路徑;patch 版沒有內嵌遊戲,path 要從玩家上次在
# ScummVM 裡設定過的舊 ini 讀回來,不然每次重開 AppImage(掛載點路徑都不同)
# 都會把玩家設好的遊戲路徑洗掉。
AGI_PATH=""
SCI_PATH=""
if [ -f "$GAMEROOT/agi_1984/KQ1/OBJECT" ]; then
  AGI_PATH="$GAMEROOT/agi_1984/KQ1"
elif [ -f "$CFG" ]; then
  AGI_PATH=$(awk '/^\[kq1agi\]/{f=1;next}/^\[/{f=0}f&&/^path=/{sub(/^path=/,"");print;exit}' "$CFG")
fi
if [ -f "$GAMEROOT/sci_1990/KQ1NEW/RESOURCE.MAP" ]; then
  SCI_PATH="$GAMEROOT/sci_1990/KQ1NEW"
elif [ -f "$CFG" ]; then
  SCI_PATH=$(awk '/^\[kq1sci\]/{f=1;next}/^\[/{f=0}f&&/^path=/{sub(/^path=/,"");print;exit}' "$CFG")
fi

MT32LINE=""
[ -f "$EXTRA/MT32_CONTROL.ROM" ] && MT32LINE="music_driver=mt32"

cat > "$CFG" <<EOF
[scummvm]
# GUI 的中文字型(kq1_gui.fnt)在遊戲啟動前就要載入,而 game section 的 extrapath 那時
# 還沒生效 —— 少了這行,啟動器清單裡的中文遊戲名會變成一排方塊。
extrapath=$EXTRA
themepath=$EXTRA
# 存檔/讀檔一律用清單式介面。縮圖格狀介面(SaveLoadChooserGrid)在遊戲內開啟時崩過一次
# (GitHub issue #2),清單那條路徑不經過它。
gui_saveload_chooser=list

[kq1agi]
description=國王密令 I（1984 AGI 原版）
engineid=agi
gameid=kq1
extrapath=$EXTRA
$( [ -n "$AGI_PATH" ] && echo "path=$AGI_PATH" )
$MT32LINE

[kq1sci]
description=國王密令 I（1990 SCI 重製版）
engineid=sci
gameid=kq1sci
language=tw
extrapath=$EXTRA
$( [ -n "$SCI_PATH" ] && echo "path=$SCI_PATH" )
$MT32LINE
EOF

exec "$BIN" --config="$CFG" "$@"
APPRUN
sed -i "s/__VARIANT__/$MODE/" "$APPDIR/AppRun"
chmod +x "$APPDIR/AppRun"

cat > "$APPDIR/kq1-cht.desktop" <<DESK
[Desktop Entry]
Type=Application
Name=國王密令（King's Quest I，繁體中文版）
Comment=King's Quest I: Quest for the Crown 繁體中文化 — ScummVM patch（AGI 1984 + SCI 1990 雙版）
Exec=AppRun
Icon=kq1-cht
Categories=Game;
Terminal=false
DESK
cp "$ROOT/tools/assets/kq1-cht.png" "$APPDIR/kq1-cht.png"
ln -sf kq1-cht.png "$APPDIR/.DirIcon"

rm -f "$OUT"
echo ">> [$MODE] appimagetool 打包(--appimage-extract-and-run 免 FUSE)"
docker run --rm --name kq1-pkg-appimagetool -v "$STAGE:/stage" -v "$ROOT/tools/.cache:/cache:ro" -e ARCH=x86_64 -w /stage \
  "$BUILD_IMG" bash -c "apt-get update -qq >/dev/null && apt-get install -y -qq file >/dev/null && \
    /cache/appimagetool-x86_64.AppImage --appimage-extract-and-run 'AppDir' '/stage/$(basename "$OUT")' && \
    chown $(id -u):$(id -g) '/stage/$(basename "$OUT")'"
mv "$STAGE/$(basename "$OUT")" "$OUT"
chmod +x "$OUT"
echo ">> [$MODE] 完成: $OUT ($(du -h "$OUT" | cut -f1))"
