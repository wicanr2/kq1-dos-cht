#!/usr/bin/env bash
# 打「換機接續包」：repo 完整歷史 + 可重建環境 + 遊戲檔 + ROM + 現況說明。
# 用法: tools/package_dev_setup.sh [YYYYMMDD]   （日期省略則用今天）
#
# [HARD] 產物只進本機 dist-all/：內含遊戲本體與 MT-32 ROM，兩者都有版權，不上 GitHub。
#
# 刻意不收 scummvm-src/(1.1G) 與 build/(1G)：前者 clone upstream 再 checkout
# patches/UPSTREAM_COMMIT.txt 記的 commit 就有，後者重編就有。收了只是讓包大 20 倍。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT/.." && pwd)"
DATE="${1:-$(date +%Y%m%d)}"
NAME="kq1-cht-dev-setup-$DATE"
DIST="$REPO_ROOT/dist-all"
OUT="$DIST/$NAME.tar.zst"

command -v zstd >/dev/null || { echo "!! 需要 zstd（apt install zstd）" >&2; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
STAGE="$WORK/$NAME"
mkdir -p "$STAGE"

echo ">> git bundle（完整歷史，含所有分支與 tag）"
git -C "$ROOT" bundle create "$STAGE/repo.bundle" --all 2>&1 | sed 's/^/   /'

echo ">> docker 環境（四個 Dockerfile）"
cp -r "$ROOT/docker" "$STAGE/docker"
ls "$STAGE/docker" | sed 's/^/   /'

echo ">> 遊戲本體（AGI 1984 + SCI 1990）"
cp -r "$ROOT/game" "$STAGE/game"
[ -f "$STAGE/game/agi_1984/KQ1/OBJECT" ] || echo "!! 警告：AGI 版看起來不完整" >&2
[ -f "$STAGE/game/sci_1990/KQ1NEW/RESOURCE.MAP" ] || echo "!! 警告：SCI 版看起來不完整" >&2

echo ">> MT-32 ROM"
MT32_SRC="${MT32_ROM_SRC:-/home/anr2/cht/mt32}"
if [ -f "$MT32_SRC/MT32_PCM.ROM" ]; then
  mkdir -p "$STAGE/mt32-rom"
  ctrl=$(ls "$MT32_SRC"/MT32_CONTROL.1987*.ROM "$MT32_SRC"/MT32_CONTROL*.ROM 2>/dev/null | head -1)
  cp "$ctrl" "$STAGE/mt32-rom/MT32_CONTROL.ROM"
  cp "$MT32_SRC/MT32_PCM.ROM" "$STAGE/mt32-rom/MT32_PCM.ROM"
  echo "   $(basename "$ctrl") → MT32_CONTROL.ROM"
else
  echo "   (找不到 ROM @ $MT32_SRC，略過)"
fi

# promo/ 在 repo 是 gitignore，不會隨 bundle 走，但腳本與影格素材是重拍推廣片的依據
echo ">> 推廣片素材（promo/ 未入版控，靠這裡帶走）"
if [ -d "$ROOT/promo" ]; then
  mkdir -p "$STAGE/promo"
  cp "$ROOT/promo/make_promo.sh" "$STAGE/promo/" 2>/dev/null || true
  cp -r "$ROOT/promo/frames" "$STAGE/promo/frames" 2>/dev/null || true
  cp -r "$ROOT/promo/audio" "$STAGE/promo/audio" 2>/dev/null || true
  echo "   $(find "$STAGE/promo" -type f | wc -l) 個檔案（不含成品 mp4，那個重跑腳本就有）"
fi

echo ">> SETUP.md / previous-work.md"
cp "$ROOT/DEV_SETUP.md" "$STAGE/SETUP.md"

COMMIT="$(git -C "$ROOT" rev-parse --short HEAD)"
SUBJECT="$(git -C "$ROOT" log -1 --pretty=%s)"
UPSTREAM="$(cat "$ROOT/patches/UPSTREAM_COMMIT.txt")"
COVERAGE="$(python3 - "$ROOT/translation/translation_utf8.tsv" <<'PY' 2>/dev/null || echo "n/a"
import sys
n = t = 0
for line in open(sys.argv[1], encoding='utf-8'):
    if '\t' not in line:
        continue
    en, zh = line.rstrip('\n').split('\t', 1)
    n += 1
    if any('一' <= c <= '鿿' for c in zh):
        t += 1
print(f"{t}/{n} ({100*t//n}%)")
PY
)"

{
  echo "# 打包當下的現況（$DATE）"
  echo
  echo "## 版本"
  echo
  echo "- repo HEAD：\`$COMMIT\` — $SUBJECT"
  echo "- ScummVM pinned upstream：\`$UPSTREAM\`"
  echo "- 譯文覆蓋率：$COVERAGE（統計方式：譯文含漢字即計入；build_translation.sh 另有一份自己的計數，兩者可能差幾則）"
  echo "- 已發布 Release："
  gh release list 2>/dev/null | sed 's/^/  - /' || echo "  - (查不到，需要 gh 登入)"
  echo
  echo "## 引擎改動（三份 patch + 兩組新增檔）"
  echo
  echo "| patch | 內容 |"
  echo "|---|---|"
  echo "| \`0001-sci-cht-kq1.patch\` | SCI 軌：ZH_TWN 啟用、Big5 繪字、kFormat 模板與 %s 參數、GetLongest 中文斷行、DrawStatus 雙位元組、標題疊圖（pic 777） |"
  echo "| \`0002-agi-cht-kq1.patch\` | AGI 軌：字型檔存在即啟用、forceHires 640x400、systemUI／狀態列中文、OBJECT 道具名 |"
  echo "| \`0003-gui-cht-kq1.patch\` | ScummVM 啟動器清單的中文遊戲名 |"
  echo
  echo "新增檔（patch 裡沒有，整檔複製）：\`patches/fontchinese.{h,cpp}\` → \`engines/sci/graphics/\`、"
  echo "\`patches/chtfont.{h,cpp}\` → \`gui/\`。"
  echo
  echo "## 待辦"
  echo
  sed -n '/^## 已知待辦雷/,$p' "$ROOT/WORKLIST.md" 2>/dev/null | tail -n +2
  echo
  echo "## 未完成的驗證"
  echo
  grep -n "^- \[ \]" "$ROOT/WORKLIST.md" 2>/dev/null | sed 's/^[0-9]*://' || echo "（WORKLIST 沒有未打勾項目）"
  echo
  echo "## 鐵則"
  echo
  echo "見 SETUP.md「接手前務必知道的三條」：patch-only 交付、docker 只清自己建的、"
  echo "AGI 與 SCI 的中文啟用方式相反。"
} > "$STAGE/previous-work.md"

mkdir -p "$DIST"
echo ">> 壓縮（zstd -19）"
tar -C "$WORK" -cf - "$NAME" | zstd -19 -T0 -q -o "$OUT" -f
ls -lh "$OUT"

echo ">> 驗收：解開後該有的東西都在"
LIST="$(tar -I zstd -tf "$OUT")"
missing=0
for f in "$NAME/repo.bundle" "$NAME/SETUP.md" "$NAME/previous-work.md" \
         "$NAME/docker/Dockerfile.build" "$NAME/game/sci_1990/KQ1NEW/RESOURCE.MAP"; do
  printf '%s\n' "$LIST" | grep -q "^$f$" || { echo "   缺 $f"; missing=1; }
done
[ "$missing" -eq 0 ] && echo "   OK" || { echo "### 接續包不完整 ###"; exit 1; }

echo ">> bundle 可還原性檢查"
git bundle verify "$STAGE/repo.bundle" 2>&1 | tail -2 | sed 's/^/   /'
