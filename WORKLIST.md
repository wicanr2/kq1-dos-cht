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

- ⚠️ **下面這條 2026-08-07 已被推翻，保留供對照**（結論見本檔最後的 v1.7 段）。
  當初的理由「強制 upscale 會讓常駐狀態列破圖」在今天的樹上**重驗不成立**：中文、英文
  都乾淨。原診斷停在「懷疑是 `putFontPixel` 或底色 fillRect」，沒查到底，而那之後狀態列
  繪製整段重寫過。**現在 SCI 軌就是走強制 640×400**，中文以原生 16×15 直接畫進 display
  buffer（script 座標 8×8 = 英文字格），所有 UI 尺寸不必為中文加高。

- **SCI 軌放棄 hi-res 24×24，改用原生 16×15 倚天字**（2026-07-30，使用者決定；**已推翻**）。
  原因：ZH_TWN 強制 640×400 upscale 會讓 KQ1 的常駐狀態列破圖（左半黑底、文字被裁），
  且**餵英文字串一樣壞**，證明是「強制 upscale × KQ1 狀態列繪製」不相容，與中文無關。
  改走低解析後狀態列恢復正常，畫面風格也與 AGI 軌一致。`screen.cpp` 的強制 upscale 已移除。
  `fontchinese.cpp` 的 hi-res 路徑起初保留但恆不觸發（`getDisplayWidth() == getWidth()`，
  upscale 只在 Macintosh 分支設定），**2026-07-31 連同 `kq1_big5_hi.fnt`、`bake_hires_font.py`
  一併移除**——死碼會讓後續判斷失準，而且那顆 24×24 字型仍跟著每個平台的包出貨、
  build 流程又不重烘它，改譯文後會靜默過期。

## 已知限制

（原本這裡有兩條：SCI 狀態列維持英文、AGI 選單中英混雜。2026-08-04 兩條都做完了，
紀錄移到下面的「兩軌 UI 完整度」。）

## 兩軌 UI 完整度（2026-08-04 補完）

- **SCI 狀態列已中文化**：`得分：0 / 158` + `國王密令 I`。
  當初寫的「中文放不下」是錯的。（**後續**：那時把 `_menuBarRect` 在 ZH_TWN 下加高到
  15 列，2026-08-07 發現這會被房間圖蓋掉下半 —— 現已改走 640×400 + 原生字模，
  `_menuBarRect` 回到原生 9 列，見 v1.7 段。）
  文字本身是 script 用 kFormat 組的模板 `" Score: %d of %d%13s%s%1s"`，
  用 `SCI_CHT_DEBUG=1` 從 `kFormat` 印出來才拿得到（`SCI_DUMP_RES` 的 script dump 裡
  **找不到** "Score" 這個字串）。譯文 `" 得分：%d／%d%13s%s%1s"`，規格序列與英文完全一致
  所以 `sciChtMapFormatSpecs` 對得上；右側遊戲名由 `%s` 帶入，另外補了
  `King's Quest I → 國王密令 I`（kFormat 的 `%s` 參數翻譯只在模板已翻時啟用）。
  - **[雷] 順手清掉了 compact 文字路徑**（`kBig5WidthCompact`／`drawCompact`／
    `_compactTextActive`）。它讓 `getCharWidth` 在狀態列回 8px advance，但 `draw()` 的
    compact 分支要求 `getDisplayWidth() > getWidth()`（只有 upscale 時成立）—— KQ1 不
    upscale，於是量測 8px、實際畫 16px，狀態列中文**整排疊在一起**。兩邊 gate 不一致
    的老問題，而整條路徑對 KQ1 是死碼，直接移除。

- **AGI 選單已全中文**：選單列 `資訊 檔案 遊戲 動作 特殊 速度`、下拉項與反白項都正確。
  兩個修正缺一不可：
  1. **查表前做空白正規化**（`chtNormKey`，與 SCI 的 `sciChtNormKey` 同一套）。
     選單標題在 LOGIC 裡帶 padding（`" File "`），抽字時原樣進了表，引擎交來查表的字串
     卻未必帶同樣空白 → 對不上就退回英文，於是沒 padding 的 `Game`／`Special` 命中、
     其餘露出英文，成了中英混雜。
  2. **選單期間中文字格要填底**（`TextMgr::setMenuTextActive`）。
     `_textAttrib.background == 0` 有兩種語意：平常是「透明、疊在既有畫面上」（道具欄、
     標題名單靠它），在選單裡卻是「黑底」。反白項 `charAttrib_Set(15, 0)` 畫白字，
     而 `drawMenu` 先用 `drawBox` 鋪了白底 → 不填底就白字白底、整片消失（只剩 ASCII
     快捷鍵可見）。ASCII 沒事是因為 `drawCharacter` 連字格背景一起畫。
     - **[雷] 別用「一律填底」了事**：那樣道具欄（`fg=0 bg=0`）會變黑底黑字，三行字
       全部消失。踩過，靠英文版對照才確認是迴歸。旗標只在 `GfxMenu` 繪製期間為真。

     > **2026-08-04 v1.4 更新:上面第 2 點的旗標做法已被取代。** 「一律填底」本身沒錯,
     > 錯在**取色的欄位**:`calculateTextBackground()` 在非 `gfxMode`(道具欄、說明頁等
     > 整頁文字畫面)一律回 0,真正的顏色在 `combined*` 裡,拿 `background` 去填才會
     > 變黑底黑字。現在 `displayBig5Character()` 依 `_game.gfxMode` 取對的欄位、
     > `drawBig5CharacterOnDisplay()` 無條件填底,`_menuTextActive` 已移除。
     > 旗標版只補得到選單,**補不到同樣是反白(前景 15/背景 0)的道具欄選取項**——
     > 實測三件道具裡被選取的那件整個隱形(見下方 v1.4 段)。

## 已知待辦雷

- 字型設定：低解析 advance 16／glyph 16×15（倚天），兩軌與狀態列全部走這一組。
  compact advance 8 那條路徑已於 2026-08-04 移除（見上方「兩軌 UI 完整度」）。

## v1.4(2026-08-04):把 KQ2 issue #1 的兩條同血統修正補完

KQ2 的 GitHub issue #1 修完後回頭比對 KQ1,發現兩件事:一件是**旗標版補不到的死角**,
一件是**還沒發作的定時炸彈**。兩條都在 AGI 軌(SCI 軌不受影響)。

- [x] **道具欄的選取項整個隱形**(旗標版的死角)。
  `_menuTextActive` 只在 `GfxMenu` 繪製期間為真,而道具欄是**文字模式**畫面,選取項
  一樣是 `charAttrib_Set(15, 0)`(白字/黑底),照樣不填底 → 白字落在白底上消失。
  實測(除錯主控台 `setobj` 塞三件道具 + `setflag 13 1`):選中「短刀」時短刀不見、
  按 ↓ 換選「胡蘿蔔」時胡蘿蔔不見。**修前修後各截一張圖比對過。**
  修法:`displayBig5Character()` 依 `_game.gfxMode` 取色——圖形模式用
  `foreground/background`、文字模式用 `combinedForeground/combinedBackground`;
  `drawBig5CharacterOnDisplay()` 改成無條件填底,`forceFill` 參數與 `_menuTextActive`
  旗標一併移除(一個機制取代兩個)。
- [x] **選單版面改用顯示欄寬計算**(定時炸彈拆除)。
  `addMenu()`/`addMenuItem()` 的 `textLen`／`maxItemTextLen`／`column` 原本照**英文
  byte 長度**算,中文是繪製時才換。KQ1 目前最大溢出是「離開 `<Alt Z>`」19 欄→20 欄,
  只多 1 欄,剛好被選單盒 `maxItemTextLen * 4 + 8` 的 `+8`(＝2 欄)餘裕吃掉,所以
  **畫面上還看不出來**(開關檔案選單前後逐像素比對過,乾淨)。但只要譯文再多一個字
  就會像 KQ2 那樣(溢出 3 欄)在畫面上留殘影。改成加入選單時就換中譯、長度算顯示欄寬,
  選單列截斷也以欄為單位(原本逐 byte 刪會把 Big5 字砍成半個)。
- 未動的部分:`ChtGuiFont` 的擁有權(KQ1 用 `isWrapper()` + `isBuiltinFont()` 已擋掉
  重複包裝與刪內建字型,與 KQ2 的「單一擁有者」做法涵蓋同樣的路徑,不重複改);
  macOS 啟動器(KQ1 的「路徑對不上也重寫 + 留 .bak」比 KQ2 版更細,保留);
  issue #2 的 `gui_saveload_chooser=list` 迴避設定(SCI 存檔崩潰成因未定,**不動**)。

- [x] **Release v1.4 上線**:三平台 patch 四檔;dist-all/ 三平台 full 同步重打包。
  驗收:新增 `tools/verify_packages.sh`(移植自 KQ2/KQ3,含正對照 selfcheck)六包 12/12 PASS
  ——**移植時第一版把 macOS full 的遊戲路徑照抄成 `game/` 而誤報缺件,KQ1 用的是 `kq1-game/`**
  (檢查腳本自己抓出來的,正是它該擋的東西)。另跑:出貨 AppImage 實跑(選單正確、乾淨離開)、
  Windows patch 包 wine 實跑、macOS artifact 的 headSha 與本地 HEAD 比對一致。

- **[已修 2026-08-05] SCI 視窗標題被裁 → 追下去挖到「按 F1 會當掉」**。
  當初把它記成待辦時寫的理由「加高標題列會把內容區往下擠、可能裁掉最後一行」**是錯的**：
  `addWindow()` 收到的 rect 是內容區，標題列是引擎自己往上長的（`r.top -= 10`），
  `restoreRect` 沒指定時等於 dims、會跟著長 —— 內容區根本不會被動到。
  教訓：**推翻一個「不能改」的結論之前，先去讀那個數字是誰算的、往哪個方向長**。
  真正嚴重的是順帶驗出來的 F1 崩潰（`Size()` 沒做翻譯替換、`Box()` 有 → 行數照英文算、
  行高照中文算 → 視窗量成 210px 超出畫面 → 文字畫到負座標 → assert）。詳見 commit。

## v1.7(2026-08-07):issue #1 追加回報的三件事(全部 SCI 軌)

回報者在 v1.6 之後帶著 v1.5 的存檔跑了一輪,提了三件。三件都用他附上的存檔
(`kq1sci.001-004`,第 4 格身上有四件道具)在 headless 環境重現後才動手。

- [x] **換場景後狀態列中文被切掉下半**(最嚴重的一件)。
  中文選單列 15 列(`ports.cpp`,v1.3 加高的),但**遊戲的畫面視窗從第 10 列開始**
  (`GfxPorts::init` 的 `offTop = 10`),每張房間圖都會畫滿 10..199 列 —— 兩者重疊 5 列,
  誰後畫誰贏。換場景時後畫的是房間圖,狀態列就少了下面三分之一。
  **量化重現**:走過 17 個畫面逐張量白底列數,換場景那一格從 16 掉到 10。

  **修法:整個 SCI 顯示改成 640×400,中文字改用原生 16×15 直接畫進 display buffer**
  (`GfxFontChinese::drawHiRes`)。兩個 display 像素等於一個 script 像素,所以中文在
  script 座標裡只佔 **8×8** —— 正好是遊戲原本那顆 8px 英文字型的格子。於是**遊戲照英文
  排好的每一個尺寸都自動容得下中文**:9 列的狀態列、10 列的視窗標題列、對白框、下拉項。
  `_menuBarRect` 與 `titleBarHeight()` 的加高全部撤掉,不再需要在畫完圖之後補畫狀態列,
  **房間圖一列都沒有犧牲**(與英文版逐點比對,狀態列以下相符 99%,差的是游標與主角動畫格)。

  這條路 7/30 走過並放棄,理由記在 `screen.cpp` 的 CHT note:「強制 upscale 會讓常駐狀態列
  破圖(左半黑底、文字被裁),連英文都壞」。**2026-08-07 重驗:不成立了。** 現在開強制
  upscale,中文與英文的狀態列都乾淨。當年的診斷停在「懷疑是 `putFontPixel` 或底色 fillRect」,
  從來沒查到底,而那之後狀態列繪製整段重寫過(DrawStatus 雙位元組合併、選單列 rect、
  ASCII 底線對齊)。**教訓:記著「已否決」的路,理由若停在『懷疑』,就不算結案。**

  順帶一併解決的:視窗標題列裁切(標題列 10 列 = 20 display 列,放得下 15 列字模)、
  中英字級不一致(中文 8 script 列 = 英文字高,`draw()` 裡的底線補償自動歸零)、
  每行塞得下的字數變兩倍(對白框不再擠)。

  **選單反白要另外處理**:hi-res 字只存在 display buffer,而 SCI 的 invert 是讀 visual、
  寫 visual+display —— 直接套用會把被反白那一項的字整個抹掉(只剩一條黑槓)。
  改成 `GfxScreen::chtInvertRect()`:兩個 buffer 各自獨立交換兩種顏色,字跟著背景一起反相,
  visual 也維持正確供 bitsSave/bitsRestore。實測選單列標題與下拉項反白都正常。

- [x] **道具欄的品項左緣參差不齊**。
  v1.2 為了標題四個按鈕加的 `chtControlOffset()`(把控制項平移 `(英文寬-中文寬)/2`,
  讓中文落回背景圖畫好的藍色底板中央)**沒有限定畫面**,而「rect 剛好貼合文字」這個
  條件一點都不罕見:道具欄每一項都是 script 用 `kTextSize` 量完中文再開的控制項,
  於是四項各自平移不同距離。
  `SCI_CHT_DEBUG` 印出的 rect 把它釘死:`短刀 left=4 / 胡蘿蔔 left=-5 / 幸運草 left=17 /
  金蛋 left=6`,扣掉各自的位移全部回到 `left=0`(＝英文版看到的齊頭)。
  修法:`chtControlOffset()` 加 `_paint16->_chtTitleActive` 這道閘 —— 只有標題畫面的
  項目坐在背景圖畫好的底板上,也只有它們有固定的目標要對準。
  驗收:道具欄四項齊頭;標題四顆按鈕仍在底板中央(重截確認)。

- [x] **選單的「音量。..」半形全形混雜**。
  引擎沒問題,是 `tools/build_cht.py` 的 `fullwidthize()`:它把「中文後面的句點」轉成
  全形句號,逐字看的時候,`變更...` 只有第一個點的前一字是中文 → 只有它被轉,
  剩下兩個維持半形。掃全表只有 ` Change...` 與 ` Volume...` 兩則中招。
  修法:連續同一個半形標點(`...`、`!!`)整串不轉。重跑 `build_translation.sh`
  確認只有那兩行變動、字型 byte-identical。

- **回報者另外提到的音效差異不是 bug**:MT-32 有鳥叫、AdLib 有流水聲。
  SCI0 的 sound resource **每個聲道各帶一個 play mask**,哪台音效卡放哪幾軌是 1990 年
  原版資料就決定好的(`resource_audio.cpp getChannelFilterMask`;SCI0 late 的
  AdLib = bit 0x04、MT-32 = bit 0x01)。實際 dump KQ1 的 sound 1:
  聲道 2~6 是 `0x01`(**只有 MT-32 放**)、聲道 10/11 是 `0x06`(**只有 AdLib 放**)。
  兩台聽到不同東西是原版的設計,不是中文化造成的。
