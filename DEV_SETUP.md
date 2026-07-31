# 跨機接續包（dev-setup）

`tools/package_dev_setup.sh` 產出的 `kq1-cht-dev-setup-YYYYMMDD.tar.zst`，
用途是「換一台機器把這個專案完整接下去」——不只是原始碼，而是連可重建的環境、
遊戲檔、MT-32 ROM、以及接手時該知道的現況一起帶走。

**這包只放本機 `dist-all/`，不上 GitHub、不外流**：裡面有遊戲本體與 MT-32 ROM，兩者都有版權。

## 包內有什麼

| 項目 | 說明 |
|---|---|
| `repo.bundle` | 完整 git 歷史（`git clone repo.bundle kq1-dos-cht` 就還原整個 repo） |
| `docker/` | 四個 Dockerfile：build／mingw／capture／promo |
| `game/` | AGI 1984 與 SCI 1990 兩版遊戲本體 |
| `mt32-rom/` | MT-32 ROM（1987 v1.07，合 KQ1 年代） |
| `promo/` | `make_promo.sh` 與影格素材（promo/ 在 repo 是 gitignore，不隨 bundle 走） |
| `SETUP.md` | 本檔 |
| `previous-work.md` | 打包當下的專案現況、待辦、鐵則 |

**不含**：`scummvm-src/`（1.1G，`git clone` upstream 再 checkout `patches/UPSTREAM_COMMIT.txt`
記的 pinned commit 即可）、`build/`（1G，重編就有）、`dist/`／`dist-all/` 的成品。

## 換機後怎麼接下去

```bash
tar -I zstd -xf kq1-cht-dev-setup-YYYYMMDD.tar.zst
cd kq1-cht-dev-setup-YYYYMMDD

git clone repo.bundle workplace          # 還原 repo（含完整歷史）
cd workplace
cp -r ../docker .                        # bundle 裡已有，這步只在你想覆蓋時做
cp -r ../game ../promo .
mkdir -p ~/cht/mt32 && cp ../mt32-rom/* ~/cht/mt32/

# 之後照 BUILD.md 走：clone scummvm-src → apply_patches.sh → 建 image → 編譯 → 打包
bash tools/apply_patches.sh scummvm-src
```

`tools/pkg_common.sh` 預設從 `/home/anr2/cht/mt32` 找 ROM，換機後用
`MT32_ROM_SRC=<你的路徑>` 覆蓋，或把 ROM 放到同樣位置。

## 接手前務必知道的三條

1. **[HARD] 交付只放 patch。** 上 GitHub 的包不得含 `RESOURCE.*`／`VOL.*`／`*.DRV`／
   `SCIV.EXE`／`LOGDIR`／`PICDIR`／`WORDS.TOK`／`*.ROM`。full 版（含遊戲與 ROM）
   只進本機 `dist-all/`。打包腳本自己會驗，但發布前再掃一次。
2. **[HARD] docker 清理只碰自己建的。** 這台機器同時放著多個專案的 image 與 volume。
   `docker run` 一律 `--name kq1-<用途>`，收工只 `docker rm -f` 自己那幾個。
   **絕不** `docker image prune`／`system prune`／`volume prune`／`rmi`／
   `docker kill $(docker ps -q --filter ancestor=...)`。
3. **AGI 與 SCI 的中文啟用方式相反。** SCI 走 config `language=tw`；
   AGI **不能設語言**（detector 遇非英文會讓遊戲開不起來），它靠「找得到 `kq1_big5.fnt`」
   來決定要不要中文化。混用是最容易踩的坑。

## 相關文件

- `BUILD.md` — 從零建置到打包的完整步驟（含 macOS CI 流程與除錯用環境變數）
- `CONTEXT.md` — 譯名 glossary（兩軌共用同一套）
- `WORKLIST.md` — 工作項目、決策紀錄、已知限制
- `../CLAUDE.md` — 專案規範（工作模式、引擎軌差異、打包政策、驗證紀律）
