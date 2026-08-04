# 建置說明

全程 docker，不污染系統環境。

## 1. 準備 ScummVM 原始樹

本 repo 不含 ScummVM 原始碼，只放 patch。

```bash
git clone https://github.com/scummvm/scummvm.git scummvm-src
cd scummvm-src
git checkout "$(cat ../patches/UPSTREAM_COMMIT.txt)"
patch -p1 < ../patches/0001-sci-cht-kq1.patch     # SCI 軌（1990 重製版）
patch -p1 < ../patches/0002-agi-cht-kq1.patch     # AGI 軌（1984/1987 原版）
patch -p1 < ../patches/0003-gui-cht-kq1.patch     # ScummVM 啟動器清單的中文遊戲名
cp ../patches/fontchinese.h ../patches/fontchinese.cpp engines/sci/graphics/
cp ../patches/chtfont.h ../patches/chtfont.cpp gui/
```

`fontchinese.{h,cpp}`（SCI 遊戲內繪字）與 `chtfont.{h,cpp}`（GUI 字型）是新增檔案，
patch 裡沒有，要整檔複製。三份 patch 都套完可以用 `tools/apply_patches.sh` 代勞。

## 2. 建 docker 映像

```bash
docker build -t kq1-build  -f docker/Dockerfile.build  docker/    # Linux
docker build -t kq1-mingw  -f docker/Dockerfile.mingw  docker/    # Windows 交叉編譯
docker build -t kq1-capture -f docker/Dockerfile.capture docker/  # headless 截圖驗證
docker build -t kq1-promo  -f docker/Dockerfile.promo  docker/    # 推廣片合成 / 抽影格
```

## 3. 編譯

```bash
docker run --rm --name kq1-build-run -v "$PWD/scummvm-src:/src" -w /src kq1-build bash -c \
  './configure --disable-all-engines --enable-engine=sci,agi --disable-detection-full && make -j"$(nproc)"'
```

**不要加 `--disable-mt32emu`**：MT-32 音樂要靠編進去的 Munt。編完確認：

```bash
grep USE_MT32EMU scummvm-src/config.h    # 應為 #define USE_MT32EMU
```

## 4. 產出中文資料

```bash
bash tools/build_translation.sh
```

會做四件事：逐批驗證並合併譯文（key byte-identical、控制序列數量、Big5 可編碼）→
套譯名收斂表 → 產 Big5 runtime `translation.tsv` → 用倚天點陣字烘 `kq1_big5.fnt`
（遊戲內）與 `kq1_gui.fnt`（ScummVM 啟動器清單，索引是 Unicode 碼位不是 Big5）。
產物都在 `dist-cht/`。

**[雷] 要改譯文請改 `translation/done/*.done`，不是 `translation/translation_sci.tsv`。**
`build_translation.sh` 第一步的 `merge_check.py` 會用 `done/` 重新產生
`translation_sci.tsv`，手改那份會被無聲蓋掉（改完跑 build 看起來成功，實機卻沒變）。

不烘 24×24 hi-res 字型：那條路徑需要強制 640×400 upscale，KQ1 的常駐狀態列撐不住
（連英文都破圖），引擎端已整條移除，見 `scummvm-src/engines/sci/graphics/screen.cpp`
的 CHT note。

倚天字型原始檔（`STDFONT.15`、`SPCFONT.15` 等）放在 `tools/assets/eten/`，未入庫。

## 5. 打包

```bash
bash tools/package_appimage.sh patch    # → dist/
bash tools/package_appimage.sh full     # → dist-all/（含遊戲與 MT-32 ROM，僅本機）
bash tools/package_windows.sh patch
bash tools/package_windows.sh full
```

macOS 只能在 macOS host build，走 GitHub Actions（`.github/workflows/build-macos.yml`）：

```bash
git ls-remote origin main                # 先確認 remote HEAD 已是要編的 commit
gh workflow run build-macos.yml --ref main
gh run watch <run-id> --exit-status      # 指令尾別接 echo/pipe，exit code 會被蓋掉
gh run download <run-id> -D /tmp/ci-mac  # 產出的是 patch 版
bash tools/package_macos_full.sh /tmp/ci-mac/*/KQ1-CHT-patch-macos-universal.tar.gz
```

full 版一律「下載 CI 的 patch artifact → 本機注入 game/ 與 ROM」，因為 CI runner
拿不到那些檔案（都 gitignore）。

### Windows 包的三個必守項（玩家端最容易炸）

- `.bat` 換行 **CRLF**、內容 **純 ASCII**、檔名 **純 ASCII**。中文一律放進 UTF-8 的
  `extra/scummvm.ini.default`，`.bat` 只負責 `copy` 它。理由與症狀見共用模板
  「Windows 包常見雷」。
- zip 用 `zip -UN=UTF8`（設 UTF-8 檔名旗標）。
- 設定檔（`kq1-cht.ini`，刻意不叫 `scummvm.ini`，免得沿用舊包留下的舊設定）鎖 `gui_language=en`。不鎖的話 ScummVM 依系統地區挑 GUI 翻譯，而 theme
  對非英文語言強制要 TTF 字型（mingw 沒有 FreeType）→ theme 整個載入失敗；抓到的翻譯
  往往還是簡體。**別為了這個去交叉編 FreeType**：ScummVM 一偵測到它就會把 37MB 的
  `fonts-cjk.dat` 嵌進 exe，包從 11M 變 54M（實測過）。詳見共用模板該節第 6 條。

沒有 Windows 機器也能端對端驗：

```bash
export WINEPREFIX=/tmp/wp WINEDEBUG=-all DISPLAY=:91
Xvfb :91 -screen 0 800x600x24 & sleep 3
cd <解開的包> && wine cmd /c PLAY-KQ1-CHT.bat &
sleep 25 && xwd -root -silent > /tmp/s.xwd     # capture image 沒有 import 就用 xwd
```

**驗收**：patch 版解開後不得出現 `RESOURCE.*`、`VOL.*`、`*.DRV`、`SCIV.EXE`、`OBJECT`、
`WORDS.TOK`、`LOGDIR`、`PICDIR`——出現任何一個就是把遊戲資源打進去了，不能發布。

## 6. headless 驗證

```bash
docker run --rm --name kq1-cap -v "$PWD:/w" -w /w kq1-capture bash -c '
  Xvfb :99 -screen 0 1024x768x24 & sleep 2; export DISPLAY=:99 HOME=/tmp
  /w/scummvm-src/scummvm --path=/w/game/sci_1990/KQ1NEW --extrapath=/w/dist-cht kq1sci &
  sleep 10; import -window root /w/out/shot.png'
```

SCI 軌要 config 帶 `language=tw` 才會啟用中文（命令列 `--language=tw` 在偵測期會被擋掉）。
**AGI 軌相反：絕對不能設 language**，AGI 的 detector 遇非英文語言會直接啟動失敗——
它靠「遊戲目錄或 extrapath 找得到 `kq1_big5.fnt`」來決定要不要中文化。

除錯用的環境變數（都是本專案加的）：

| 變數 | 作用 |
|---|---|
| `SCI_DUMP_RES=<dir>` | dump text/message/script/view/pic 資源後結束 |
| `SCI_DUMP_PIC=<dir>` | 每張畫出來的 pic 存成 PPM |
| `SCI_LOG_GFX=1` | 印每次 drawPicture / view 繪製與標題疊圖 blit |
| `SCI_CHT_DEBUG=1` | 印 `Box()` 收到的 rect 與文字、`DrawStatus` 的字串 hex |

**這些 hook 跑完不會自己結束，`docker run` 一律用 `timeout` 包住。**
