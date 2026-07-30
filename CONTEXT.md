# CONTEXT — 國王密令（King's Quest I）繁中化共用語彙

兩軌（AGI 1984/1987 原版、SCI 1990 重製版）**共用同一套譯名**。權威來源：第三波資訊 PC22
《國王密令》官方中文說明書（掃描件在 `manual_cht/`，14 頁全數判讀完畢）。
KQ4 的智冠版譯名（國王密使／羅塞拉）**不適用本作**，別沿用。

## 一、遊戲名與品牌

| 英文 | 中文 | 出處 |
|---|---|---|
| King's Quest | 國王密令 | 手冊封面／磁片標籤 |
| King's Quest I | 國王密令 I | 同上（副標「國王密使」僅見於坊間別稱） |
| Sierra On-Line | 系統名稱保留原文 | — |
| 第三波資訊文化事業 | 第三波 | 台灣代理商（1990 年代） |

## 二、專有名詞（手冊權威譯名）

| 英文 | 中文 | 備註 |
|---|---|---|
| Daventry | 戴凡確王國 | 手冊背面／故事背景，**全書統一** |
| King Edward | 愛德華國王 | |
| Sir Graham | 格拉漢爵士 | 主角；行文可簡稱「格拉漢」 |
| Cumberland | 肯伯倫王國 | 愛德華國王所救公主的故國 |
| Leprechaun | 地穴人 | 手冊：「SCEPTER 為 Leprechaun 一族（地穴人）的王杖」 |
| the King of the Leprechauns | 地穴人國王 | |
| fairy godmother | 教母 | 手冊：「守護格拉漢爵士的仙女」；行文可作「仙女教母」 |
| witch | 巫婆 | |
| sorcerer / wizard | 巫師 | |
| dwarf | 矮人 | |
| gnome | 矮人 | 手冊同樣譯「矮人」；若同場景並存，gnome 用「侏儒矮人」區隔 |
| troll | 矮精靈 | 手冊譯法（非「巨魔」） |
| elf | 小精靈 | |
| ogre | 鬼怪 | |
| giant | 巨人 | |
| dragon | 巨龍 | 手冊未列，沿用通用譯法 |

## 三、三件寶物（劇情核心）

| 英文 | 中文 | 備註 |
|---|---|---|
| magic mirror | 魔鏡 | 可預知未來 |
| magic shield | 靈盾 | 手冊正文用「靈盾」，物品表寫「MAGIC SHIELD 靈盾」 |
| magic chest | 金盒子 | 手冊：聚寶盆，永遠裝滿金幣 |
| the three lost treasures of Daventry | 戴凡確王國失落的三件寶物 | |

## 四、道具／場景名詞（手冊物品表逐條）

| 英文 | 中文 | | 英文 | 中文 |
|---|---|---|---|---|
| bowl | 碗 | | rock | 石頭 |
| four-leaf clover | 幸運草 | | carrot | 胡蘿蔔 |
| mushroom | 蘑菇 | | well | 井 |
| axe | 斧頭 | | pump | 幫浦 |
| cheese | 乳酪 | | cupboard | 櫥櫃 |
| note | 提示（紙條） | | puma | 豹 |
| gold egg | 金蛋 | | dagger | 短刀 |
| rope | 繩索 | | bucket | 水桶 |
| (magic) beans | 魔豆 | | lake | 湖泊 |
| walnut | 胡桃 | | tree | 樹木 |
| door | 門 | | bed | 床 |
| floor | 地板 | | mountain | 山 |
| garden | 菜園／花園 | | castle | 城堡 |
| lamp | 燈 | | armor | 盔甲 |
| throne | 王座 | | king | 國王 |
| room | 房間 | | river | 河流 |
| pebble | 鵝卵石 | | magic ring | 魔戒 |
| hole | 洞穴 | | bridge | 橋樑 |
| fence | 欄杆 | | gate | 閘門 |
| goat | 山羊 | | stump | 樹樁 |
| bird | 鳥 | | key | 鑰匙 |
| sling / slingshot | 投石器 | | rat | 大老鼠 |
| fiddle | 小提琴 | | beanstalk | 豆莖 |
| scepter / sceptre | 王杖 | | flower | 花朵 |
| water | 水 | | ground | 地面 |
| house | 房屋 | | table | 桌子 |
| pouch | 皮袋 | | stew | 燉肉 |

道具欄顯示名（SCI script 內嵌，**key 帶前後 padding 空格，逐字保留**）：
` Dagger ` → ` 短刀 `、` Chest ` → ` 金盒子 `、` Magic Ring ` → ` 魔戒 ` 依此類推。

## 五、Parser 指令 — [HARD] 一律不翻

玩家要**打英文**才能過關，遊戲提示裡出現的指令原文保留 ASCII。手冊的中文對照只寫進
README／中文手冊，不寫進遊戲文字：

GET 拿取、THROW 投擲、SHOW 展示、OFFER 給予、GIVE 給、FEED 餵、CUT 切割、PUSH 推／按、
MOVE 移動、PLAY 演奏、OPEN 打開、CLOSE 關閉、CLIMB 爬、PLANT 種植、UNLOCK 開鎖、EAT 吃、
USE 使用、RUB 摩擦、WEAR 穿戴、LOOK 觀看、SWIM 游泳、JUMP 跳躍、DUCK 蹲下、
TALK TO 與…交談、BOW 鞠躬、ENTER 進入。

遊戲內若出現 `Just type "USE THE SLINGSHOT".` 這類句子，譯為
`只要輸入 "USE THE SLINGSHOT" 即可。`——**引號內原文一字不改**。

## 六、風格準則

- 童話奇幻語感：典雅但不文言，句子短、好唸。旁白像說故事的人，不是說明書。
- 死亡訊息保留原作的黑色幽默，但不加現代網路梗（本作非成人喜劇，別套 LSL1 那套台式黃腔）。
- 第二人稱一律「你」，格拉漢對國王等尊長用敬語。
- 標點用全形；`%s`／`%d`／`%v` 等控制序列位置與數量原樣保留。
- 譯文長度控制在原文 ±30%，選單／道具名求短（SCI0 選單列高度有限）。

## 七、雙軌共用注意

- AGI（1984/1987）與 SCI（1990）**同劇情但文字重寫**：正規化後精確重疊僅 260 則
  （AGI 1278 則中 20.3%）。翻完 SCI 後 cross-apply 只能自動填這批，其餘要靠相似度比對
  產生草稿再人工調——**別假設兩版對白一致**。
- 兩軌譯名、風格、標點規則完全共用本檔。
