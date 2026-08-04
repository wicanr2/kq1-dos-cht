#!/usr/bin/env bash
# KQ1-CHT 發行包驗收腳本(移植自 KQ2/KQ3 的同名腳本,檔名與必含清單改成 KQ1 兩軌:
# AGI 1984 原版 + SCI 1990 重製版)。
#
# 三類檢查,均為 function-based、PASS/FAIL 明確輸出、任一 FAIL 即整體非零 exit code:
#   1. check_no_contraband <dir>            — patch 包裡不可出現任何遊戲資源(反查目錄樹)
#   2. check_distcht_complete <extra_dir> <distcht_dir>
#                                            — 用 dist-cht/ 的檔案清單去 extra/ 找,缺一即 FAIL
#                                              ([HARD] 方向不可顛倒:別只列 extra 裡有什麼就算過)
#   3. check_full_required <root_dir> <relpath...>
#                                            — full 包必含清單,缺一即 FAIL
#
# 用法:
#   tools/verify_packages.sh real      # 對 dist/、dist-all/ 下四個真實包各跑一次
#   tools/verify_packages.sh selfcheck # 正對照:故意塞違規內容,確認三條檢查真的會 FAIL
#   tools/verify_packages.sh           # 預設 = real
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT/.." && pwd)"
DIST_CHT="$ROOT/dist-cht"

# patch 包 0 禁品清單(find -iname pattern)
CONTRABAND_PATTERNS=(
  'VOL.*' 'LOGDIR' 'PICDIR' 'VIEWDIR' 'SNDDIR' 'OBJECT' 'WORDS.TOK'
  'RESOURCE.MAP' 'RESOURCE.00?' 'RESOURCE.0??' '*.ROM' 'Game_manual.pdf'
)

FAIL_COUNT=0
PASS_COUNT=0

pass() { echo "[PASS] $1"; PASS_COUNT=$((PASS_COUNT+1)); }
fail() { echo "[FAIL] $1"; FAIL_COUNT=$((FAIL_COUNT+1)); }

# ---------------------------------------------------------------------------
# 檢查一:patch 包 0 禁品 —— 在 <dir> 整棵樹底下搜尋 CONTRABAND_PATTERNS,
# 任何一個命中就 FAIL 並列出命中的檔案。
check_no_contraband() {
  local dir="$1" label="${2:-$1}"
  local hits=()
  local pat
  for pat in "${CONTRABAND_PATTERNS[@]}"; do
    while IFS= read -r -d '' f; do
      hits+=("$f")
    done < <(find "$dir" -iname "$pat" -print0 2>/dev/null)
  done
  if [ "${#hits[@]}" -eq 0 ]; then
    pass "patch 包 0 禁品 [$label]"
  else
    fail "patch 包 0 禁品 [$label] —— 發現 ${#hits[@]} 個違規檔案:"
    local h
    for h in "${hits[@]}"; do echo "         違規: $h"; done
  fi
}

# ---------------------------------------------------------------------------
# 檢查二:dist-cht 反查 —— 以 dist-cht/ 的檔案清單為準,逐一到 <extra_dir> 找同名檔。
# [HARD] 方向固定:用 dist-cht 去找包,不是列包裡有什麼就算過。
check_distcht_complete() {
  local extra_dir="$1" distcht_dir="$2" label="${3:-$1}"
  local missing=()
  local f base
  while IFS= read -r -d '' f; do
    base="$(basename "$f")"
    if [ ! -e "$extra_dir/$base" ]; then
      missing+=("$base")
    fi
  done < <(find "$distcht_dir" -maxdepth 1 -type f -print0)
  if [ "${#missing[@]}" -eq 0 ]; then
    pass "dist-cht 反查完整 [$label]"
  else
    fail "dist-cht 反查完整 [$label] —— 缺 ${#missing[@]} 個檔案:"
    local m
    for m in "${missing[@]}"; do echo "         缺件: $m"; done
  fi
}

# ---------------------------------------------------------------------------
# 檢查三:full 包必含 —— <root_dir> 下逐一檢查給定相對路徑是否存在。
check_full_required() {
  local root_dir="$1" label="$2"; shift 2
  local missing=()
  local rel
  for rel in "$@"; do
    [ -e "$root_dir/$rel" ] || missing+=("$rel")
  done
  if [ "${#missing[@]}" -eq 0 ]; then
    pass "full 包必含檔案 [$label]"
  else
    fail "full 包必含檔案 [$label] —— 缺 ${#missing[@]} 項:"
    local m
    for m in "${missing[@]}"; do echo "         缺件: $m"; done
  fi
}

# ---------------------------------------------------------------------------
# 解壓工具
extract_appimage() {
  local appimage="$1" out="$2"
  mkdir -p "$out"
  ( cd "$out" && "$appimage" --appimage-extract >/dev/null )
  echo "$out/squashfs-root"
}

extract_zip() {
  local zip="$1" out="$2"
  mkdir -p "$out"
  unzip -q -o "$zip" -d "$out"
  echo "$out"
}

extract_targz() {
  local tgz="$1" out="$2"
  mkdir -p "$out"
  tar xzf "$tgz" -C "$out"
  echo "$out"
}

# macOS .app 的中文資料在 Resources/cht-data,遊戲在 Resources/kq1-game
#(KQ1 的 full 包用 kq1-game/,不是 KQ2/KQ3 的 game/——第一次移植就是照抄 game/ 而誤報缺件)
FULL_REQUIRED_MACOS=(
  "ScummVM.app/Contents/Resources/kq1-game/agi_1984/KQ1/VOL.0"
  "ScummVM.app/Contents/Resources/kq1-game/agi_1984/KQ1/OBJECT"
  "ScummVM.app/Contents/Resources/kq1-game/sci_1990/KQ1NEW/RESOURCE.MAP"
  "ScummVM.app/Contents/Resources/kq1-game/sci_1990/KQ1NEW/RESOURCE.001"
)

FULL_REQUIRED=(
  "game/agi_1984/KQ1/VOL.0"
  "game/agi_1984/KQ1/OBJECT"
  "game/sci_1990/KQ1NEW/RESOURCE.MAP"
  "game/sci_1990/KQ1NEW/RESOURCE.001"
)
FULL_REQUIRED_APPIMAGE=(
  "usr/share/game/agi_1984/KQ1/VOL.0"
  "usr/share/game/agi_1984/KQ1/OBJECT"
  "usr/share/game/sci_1990/KQ1NEW/RESOURCE.MAP"
  "usr/share/game/sci_1990/KQ1NEW/RESOURCE.001"
)

run_real() {
  local TMP="/tmp/kq1-verify-$$"
  rm -rf "$TMP"; mkdir -p "$TMP"

  echo "=== [1/6] AppImage patch: $REPO_ROOT/dist/KQ1-CHT-patch-x86_64.AppImage ==="
  local d1 root1
  d1="$TMP/appimage-patch"
  root1="$(extract_appimage "$REPO_ROOT/dist/KQ1-CHT-patch-x86_64.AppImage" "$d1")"
  check_no_contraband "$root1" "AppImage patch"
  check_distcht_complete "$root1/usr/share/cht" "$DIST_CHT" "AppImage patch"
  echo

  echo "=== [2/6] AppImage full: $REPO_ROOT/dist-all/KQ1-CHT-full-x86_64.AppImage ==="
  local d2 root2
  d2="$TMP/appimage-full"
  root2="$(extract_appimage "$REPO_ROOT/dist-all/KQ1-CHT-full-x86_64.AppImage" "$d2")"
  check_distcht_complete "$root2/usr/share/cht" "$DIST_CHT" "AppImage full"
  check_full_required "$root2" "AppImage full" "${FULL_REQUIRED_APPIMAGE[@]}"
  echo

  echo "=== [3/6] Windows patch zip: $REPO_ROOT/dist/KQ1-CHT-patch-win64.zip ==="
  local d3 root3
  d3="$TMP/win-patch"
  root3="$(extract_zip "$REPO_ROOT/dist/KQ1-CHT-patch-win64.zip" "$d3")"
  check_no_contraband "$root3" "Windows patch zip"
  check_distcht_complete "$root3/extra" "$DIST_CHT" "Windows patch zip"
  echo

  echo "=== [4/6] Windows full zip: $REPO_ROOT/dist-all/KQ1-CHT-full-win64.zip ==="
  local d4 root4
  d4="$TMP/win-full"
  root4="$(extract_zip "$REPO_ROOT/dist-all/KQ1-CHT-full-win64.zip" "$d4")"
  check_distcht_complete "$root4/extra" "$DIST_CHT" "Windows full zip"
  check_full_required "$root4" "Windows full zip" "${FULL_REQUIRED[@]}"
  echo

  echo "=== [5/6] macOS patch tar.gz: $REPO_ROOT/dist/KQ1-CHT-patch-macos-universal.tar.gz ==="
  local d5 root5
  d5="$TMP/macos-patch"
  root5="$(extract_targz "$REPO_ROOT/dist/KQ1-CHT-patch-macos-universal.tar.gz" "$d5")"
  check_no_contraband "$root5" "macOS patch tar.gz"
  check_distcht_complete "$root5/ScummVM.app/Contents/Resources/cht-data" "$DIST_CHT" "macOS patch tar.gz"
  echo

  echo "=== [6/6] macOS full tar.gz: $REPO_ROOT/dist-all/KQ1-CHT-full-macos-universal.tar.gz ==="
  local d6 root6
  d6="$TMP/macos-full"
  root6="$(extract_targz "$REPO_ROOT/dist-all/KQ1-CHT-full-macos-universal.tar.gz" "$d6")"
  check_distcht_complete "$root6/ScummVM.app/Contents/Resources/cht-data" "$DIST_CHT" "macOS full tar.gz"
  check_full_required "$root6" "macOS full tar.gz" "${FULL_REQUIRED_MACOS[@]}"
  echo

  rm -rf "$TMP"
}

# ---------------------------------------------------------------------------
# 正對照(selfcheck):故意造一個違規的假 patch 目錄,確認檢查函式真的抓得到。
run_selfcheck() {
  local FAKE="/tmp/kq1-verify-selfcheck-$$"
  rm -rf "$FAKE"; mkdir -p "$FAKE/extra"

  echo "--- 正對照 A:塞一個 VOL.0 進假 patch 目錄,預期 [FAIL] ---"
  echo "fake game data" > "$FAKE/VOL.0"
  check_no_contraband "$FAKE" "SELFCHECK-造假-VOL.0"
  echo

  echo "--- 正對照 A2:先移除 VOL.0,確認乾淨目錄能 PASS(對照組) ---"
  rm -f "$FAKE/VOL.0"
  check_no_contraband "$FAKE" "SELFCHECK-移除後應PASS"
  echo

  echo "--- 正對照 B:假 extra/ 只放 3 個 dist-cht 檔案(故意漏掉其餘),預期 [FAIL] ---"
  local n=0 f
  for f in "$DIST_CHT"/*; do
    [ -f "$f" ] || continue
    cp "$f" "$FAKE/extra/"
    n=$((n+1))
    [ "$n" -ge 3 ] && break
  done
  echo "    (假 extra/ 只放了 $n 個檔案,dist-cht 實際有 $(find "$DIST_CHT" -maxdepth 1 -type f | wc -l) 個)"
  check_distcht_complete "$FAKE/extra" "$DIST_CHT" "SELFCHECK-故意缺件"
  echo

  echo "--- 正對照 B2:把 dist-cht 全部複製進去,確認能 PASS(對照組) ---"
  cp "$DIST_CHT"/* "$FAKE/extra/"
  check_distcht_complete "$FAKE/extra" "$DIST_CHT" "SELFCHECK-補齊後應PASS"
  echo

  echo "--- 正對照 C:full 包必含檔案清單,假目錄什麼都沒有,預期 [FAIL] ---"
  check_full_required "$FAKE" "SELFCHECK-造假-full缺件" "${FULL_REQUIRED[@]}"
  echo

  rm -rf "$FAKE"
}

MODE="${1:-real}"
case "$MODE" in
  real) run_real ;;
  selfcheck) run_selfcheck ;;
  *) echo "用法: $0 <real|selfcheck>" >&2; exit 1 ;;
esac

echo "=== 總結:PASS=$PASS_COUNT FAIL=$FAIL_COUNT ==="
if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi
exit 0
