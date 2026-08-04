# WORKLIST — 國王密令（King's Quest I）雙軌繁中化

> 狀態以 code 為準，不以本檔為準（rulebook 63）。斷言「做完了」前先查檔案。

## 0. 勘查結論（已驗證）

- **[已修正 CLAUDE.md 的假設] `kq1sci` 是 SCI0，不是 SCI1**：ScummVM 偵測條目寫
  `SCI interpreter version 0.000.999`、`S.old.010`、`VERSION` 檔 `1.000.051`，
  `RESOURCE.CFG` 用 `EGA320.DRV`（EGA 16 色 320×200，`GUIO_STD16_UNDITHER`）。
  → KQ4／QFG1／LSL2 那套 **SCI0 EGA** 技法直接適用；view 是 SCI0 格式（`sci0_view.py`），
  不是 `.v56`。
- AGI 軌偵測為 `agi:kq1`（2.0F 1987-05-05），不是 1984 首版；資源結構標準。
- **無防拷**：script/text dump 內找不到 copy-protection 問答字串 → 不必做 bypass。
- 選單字串在 `script.997`（與 KQ4 同），存讀檔提示在 `script.990`，
  道具名／系統訊息內嵌在 `script.000`。
- **雙軌複用率遠低於預期**：正規化後 AGI 1278 則只有 260 則（20.3%）與 SCI 完全相同。
  1990 重製版把文字重寫過 → AGI 軌不能靠 cross-apply 收工。

## 1. 環境／工具（完成）

- [x] `workplace/` 骨架、遊戲檔解壓（`game/agi_1984/KQ1`、`game/sci_1990/KQ1NEW`）
- [x] `scummvm-src` 從本機 pristine（upstream `3d408ec3`）clone，分支 `kq1-cht`
- [x] docker build image `kq1-build`（`USE_MT32EMU` 已確認 `#define`）
- [x] 套用 KQ4 SCI 中文化 patch 當基底 + `fontchinese.{h,cpp}`，資源檔名改 `kq1_*`
- [x] 工具鏈複製（KQ4 tools + AGI 抽字 + 倚天烘字 `build_eten_font.py`/`etunpack.py`）
- [x] 倚天素材 `tools/assets/eten/`（STDFONT.15 / SPCFONT.15 / stdfont.24 / SPCFONT.24）

## 2. 手冊（完成）

- [x] 第三波 PC22 手冊 14 頁全部判讀
- [x] `CONTEXT.md` glossary（戴凡確王國／格拉漢爵士／靈盾／地穴人…；parser 動詞表）
- [x] 中文說明書轉 markdown（`manual_cht/README.md`，含故事背景、控制鍵、物品／動作對照表）

## 3. SCI 軌（1990 重製版）— 進行中

- [x] `SCI_DUMP_RES` dump（text 108／script 146／pic 86／view 211）
- [x] 抽字：text/message 1588 + script 385 + 選單 22 → master skeleton **1979 則**
- [x] 翻譯批次切分（16 批 × 130 則）、`TRANSLATE_INSTRUCTIONS.md`
- [x] batch_01 試作核准（格式驗證 KEY-OK，選單 padding 保留）
- [x] batch_02–16 fan-out（sonnet subagent），SCI 軌覆蓋 99%
- [x] 合併 master + 逐批驗證（key/控制序列/Big5）+ 譯名收斂表 `translation/converge.tsv`
- [x] 烘倚天字型 → `dist-cht/`（16×15，1960 字；hi-res 24×24 已移除，見下方決策）
- [x] 中文標題疊圖（`kq1_title.ovl`，標題 pic = **777**，已實機驗證）
- [x] playtest：標題、標題選單、場景、parser 對白、開場旁白、狀態列、道具欄（Ctrl+I，
      「你身上什麼也沒帶！」）、F8 雙向切換都實機驗過
- [ ] **遊戲內存讀檔對話框沒實機驗到**：F5/F7 被 ScummVM 的全域快捷鍵攔走（開的是 ScummVM
      自己的存檔 GUI），滑鼠拉 SCI0 選單在 Xvfb 下也叫不出來。譯文本身在表裡
      （`Save a Game`→儲存進度、`Restore a Game`→讀取進度、`Type the description…`→請輸入
      這個存檔的說明文字。），且與已驗證的道具欄走同一條 `GfxText16` 路徑，但**沒截到畫面
      就不算驗過**——留給實機玩的時候確認。
- [x] crawl 型長字串（開場旁白、片尾字幕這類「單一字串內含硬換行」的段落）改用**靜態核對**
      涵蓋：掃 `script.*`／`text.*` 裡所有含硬換行的長字串共 15 則，逐則用正規化 key 比對譯文表，
      只有 1 則不在表內——`Free Heap: %u Bytes ...`，是除錯用的記憶體統計，玩家看不到。
      這比逐一 playtest 涵蓋得更完整（SQ3 那種「逐行工具把 crawl 拆裂導致整段漏譯」在這裡沒發生）。
- [ ] 片尾字幕的**實機**畫面仍未走到（要通關），但其字串已在譯文表內且經上面的靜態核對涵蓋

## 4. AGI 軌（1984/1987 原版）

- [x] 抽字：LOGIC 訊息 1282 + OBJECT 道具名 27 = 1305 則
- [x] cross-apply SCI 譯文（精確命中 266 則），另產 177 則相似句草稿 `agi_hints.tsv`
- [x] 8 批翻完，AGI 軌覆蓋 97%
- [x] AGI 引擎 patch（沿用 PQ1 的 `0001-agi-cht-zh_twn.patch`，資源檔名改 kq1_*）
- [x] 實機驗證：狀態列「得分：0 / 158」「聲音：開」、對白框中文都正常
- [x] AGI 標題疊圖（`tools/build_title_overlay_agi.py` 烘倚天 16×15 金字+黑描邊，
      display 座標 (286,3)，疊在 KING'S QUEST 橫幅上方，已實機驗證）
- [x] F8 中英切換：AGI 端原本就有（PQ1 patch 帶來的），這次補上 SCI 端
      （`event.cpp` 事件入口攔截並消費 F8 + `_chtLangOn` 旗標，標題疊圖也跟著切）。
      雙軌都實機驗過：AGI 當前訊息框就地變英文、SCI 下一句生效，再按一次都切得回來。
      **小限制**：AGI 的狀態列（得分／聲音）是 `systemui.cpp` 在建構子裡按語言寫死的字串，
      不走內容查表，所以 F8 切英文時它仍是中文。要修得把那幾個字串改成每次繪製時決定，
      為了對照原文這點小殘留不值得動，先記著。

## 5. 打包／交付

- [x] Linux AppImage + Windows mingw，各出 patch 版 + full 版（一包含 AGI/SCI 兩個 target）
- [x] README.md（引言、雙軌說明、截圖、安裝、技術說明、已知限制）
- [x] macOS CI（GitHub Actions macos-14，universal arm64+x86_64，run 30547816668 success）
- [x] GitHub repo `wicanr2/kq1-dos-cht`（public，patch-only）
- [x] Release v1.0：三平台 patch 包 + 宣傳影片
- [x] 宣傳影片 `promo/kq1-cht-promo.mp4`（47s／1280×960，三格對照，MT-32 側錄原版配樂）
- [x] MT-32 ROM 僅進本機 full 包（`dist-all/`），`.gitignore` 排除 `*.ROM`，三個 patch 包解開後 `*.ROM` 零命中
- [x] README 圖文並茂 + 中文手冊整理 + 第三波資料引言

## 決策紀錄

- **SCI 軌放棄 hi-res 24×24，改用原生 16×15 倚天字**（2026-07-30，使用者決定）。
  原因：ZH_TWN 強制 640×400 upscale 會讓 KQ1 的常駐狀態列破圖（左半黑底、文字被裁），
  且**餵英文字串一樣壞**，證明是「強制 upscale × KQ1 狀態列繪製」不相容，與中文無關。
  改走低解析後狀態列恢復正常，畫面風格也與 AGI 軌一致。`screen.cpp` 的強制 upscale 已移除。
  `fontchinese.cpp` 的 hi-res 路徑起初保留但恆不觸發（`getDisplayWidth() == getWidth()`，
  upscale 只在 Macintosh 分支設定），**2026-07-31 連同 `kq1_big5_hi.fnt`、`bake_hires_font.py`
  一併移除**——死碼會讓後續判斷失準，而且那顆 24×24 字型仍跟著每個平台的包出貨、
  build 流程又不重烘它，改譯文後會靜默過期。

## 已知限制

- **[SCI 軌] 狀態列文字仍是英文（`Score: 0 of 158` / `King's Quest I`）**。
  **注意：舊版這裡寫的理由「中文放不下、加高會破圖」已經不成立**（2026-08-04 實測推翻）——
  當初的破圖來自「ZH_TWN 強制 640×400 upscale × 狀態列繪製」的互動，而那條 hi-res 路徑
  已於 2026-07-31 整條移除。選單列／狀態列共用的 `_menuBarRect`（`ports.cpp`）現在在
  ZH_TWN 下加高到 15 列，實測狀態列白底完整、選單列中文完整、關閉選單無殘影。
  剩下的真正原因單純是**翻譯缺口**：狀態列字串是 script 用 kFormat 組出來的模板，
  `translation.tsv` 裡沒有對應 key（`grep -a Score dist-cht/translation.tsv` → 無）。
  要中文化得先 dump script 找出模板（形如 `Score: %d of %d`）再走 kFormat hook 那條路。
  AGI 軌的狀態列早就是中文（`得分：0 / 158`），兩軌在這點上不一致。

  以下是 hi-res 時代的完整診斷紀錄，保留備查（**結論已被上面推翻，別再照著做**）——
  原症狀：中文版狀態列文字上半被裁、左半段變成白字黑底（英文對照版正常）。
  排除過：① 不是譯文太長；② 不是 `DrawStatus` 沒合併雙位元組；③ 不是 `_menuBarRect` 高度；
  ④ 不是 `getHeight()` 回 12。**根因**：`KQ1_PROBE_NO_UPSCALE=1` 關掉強制 upscale 後狀態列
  完全正常 → 是「強制 upscale × 狀態列繪製」的互動。兩個 probe 開關已於出包前清掉。

## 已知待辦雷

- 字型設定：低解析 advance 16／glyph 16×15（倚天）。狀態列另有 compact advance 8，
  但 SCI 狀態列目前未中文化，那條路徑等狀態列真的要上中文時再驗。

- **[AGI 軌] 選單中英混雜**（`檔案` 未翻→顯示 `File`、`動作`→`Action`、`速度`→`Speed`，
  而 `遊戲`／`特殊` 正常）。**譯文其實都在表裡**，問題是 key 帶 padding 空白（`" File "`），
  AGI 端查表沒有做 SCI 那套空白正規化（`sciChtNormKey`）。
  2026-08-04 試過在 `GfxMgr::getChtTranslation` 與建表兩處加上同樣的正規化：選單列確實
  全中文了，但**下拉選單的反白項中文變成看不見**（只剩 ASCII 快捷鍵可見），因此已回退。
  已查明的部分：反白項走 `charAttrib_Set(15, 0)`（白字、bg=0），中文格因此不填底；
  glyph 有畫（`drawBig5Char` 回 true、字型內含該字），把前景色改成 14 就看得到字，
  改回 15 就消失 —— 也就是那塊底色與前景色同為 15（白）。**尚未查清是誰把中文格的底
  畫成白色**（ASCII 格由 `drawCharacter` 填黑，中文格不走那條）。
  修這條要連同「反白項中文格的底色」一起處理，不能只加正規化。
