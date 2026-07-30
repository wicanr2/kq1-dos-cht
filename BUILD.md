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
cp ../patches/fontchinese.h ../patches/fontchinese.cpp engines/sci/graphics/
```

`fontchinese.{h,cpp}` 是新增檔案，patch 裡沒有，要整檔複製。

## 2. 建 docker 映像

```bash
docker build -t kq1-build  -f docker/Dockerfile.build  docker/    # Linux
docker build -t kq1-mingw  -f docker/Dockerfile.mingw  docker/    # Windows 交叉編譯
docker build -t kq1-capture -f docker/Dockerfile.capture docker/  # headless 截圖驗證
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
套譯名收斂表 → 產 Big5 runtime `translation.tsv` → 用倚天點陣字烘 `kq1_big5.fnt`。
產物都在 `dist-cht/`。

倚天字型原始檔（`STDFONT.15`、`SPCFONT.15` 等）放在 `tools/assets/eten/`，未入庫。

## 5. 打包

```bash
bash tools/package_appimage.sh patch    # → dist/
bash tools/package_appimage.sh full     # → dist-all/（含遊戲與 MT-32 ROM，僅本機）
bash tools/package_windows.sh patch
bash tools/package_windows.sh full
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
