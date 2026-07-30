# 國王密令（King's Quest I）翻譯指令 — 所有翻譯 subagent 先讀本檔

## 你的任務

把指定批次檔（`translation/batch/batch_NN.tsv`）的英文遊戲文字翻成**繁體中文**，
存成同名 `.done` 檔放在 `translation/done/`。

## 檔案格式（[HARD] 不可破壞）

每行：`英文原文<TAB>譯文`

- **第一欄英文原文一字不改**（含前後空格、標點、大小寫）。它是遊戲執行期查表的 key，
  改一個字元就整句不翻。
- 只改第二欄。行數、順序與輸入檔完全一致。
- 檔案 UTF-8、無 BOM、每行一筆、不要加標題列或說明文字。

## 譯名 — [HARD] 一律照 `CONTEXT.md`

動筆前先讀 `/home/anr2/scummvm/king_quest1/workplace/CONTEXT.md`。關鍵幾條：

- Daventry → 戴凡確王國｜Sir Graham → 格拉漢爵士｜King Edward → 愛德華國王
- Leprechaun → 地穴人｜troll → 矮精靈｜gnome/dwarf → 矮人｜ogre → 鬼怪｜elf → 小精靈
- magic mirror → 魔鏡｜magic shield → 靈盾｜magic chest → 金盒子
- fairy godmother → 教母（仙女教母）｜witch → 巫婆｜sorcerer → 巫師

譯名表沒有的專有名詞，用通行譯法並保持全批一致。

## 風格

- 童話奇幻旁白：典雅但不文言，句子短、好唸。這是 1984/1990 的 Sierra 冒險遊戲，
  旁白是「說故事的人」，不是說明書。
- 死亡訊息保留原作的黑色幽默，**不要加現代網路梗、不要台式黃腔**（本作是童話，
  不是 Leisure Suit Larry）。
- 第二人稱一律「你」；格拉漢對國王、教母等尊長用敬語。
- 標點用全形（，。！？「」），譯文長度原文 ±30% 以內。
- 選單、道具名求短（SCI0 選單列高度有限）。

## [HARD] 硬規則

1. **Parser 指令不翻**：句中出現玩家要輸入的英文指令（如 `Just type "USE THE SLINGSHOT".`、
   `OPEN DOOR`、`TALK TO KING`）——**引號／指令原文保持 ASCII 一字不改**，只翻它周圍的句子。
2. **控制序列原樣保留**：`%s`、`%d`、`%v`、`%m12%w1` 這類位置與數量都不能變。
   整行只由控制序列組成（如 `%m12%w1`）→ 第二欄照抄原文，不翻。
3. **前後 padding 空格逐字保留**：像 ` Dagger `、` File `、` Save Game` 這種前後帶空格的
   選單／道具 key，譯文也要帶相同數量的空格（` 短刀 `、` 檔案 `）。
4. **繁體中文且 Big5 打得出來**：字型是從譯文烘出來的，用 Big5 沒有的字（如「𨑨」「嘞」）
   會變空白。拿不準就換常用字。
5. **不確定就直譯**，不要自由發揮劇情。翻錯比翻淡傷害大。
6. 純機械字串（`Debug`、`Turn On`、`Memory fragmented.`）照常翻，但求短。

## 交件

寫到 `translation/done/batch_NN.done`（與輸入同名、副檔名改 `.done`），
回報：批次編號、行數、有疑慮的行（行號 + 原因）。不要動其他檔案，不要 commit。
