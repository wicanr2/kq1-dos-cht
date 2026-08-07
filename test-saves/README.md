# 測試用存檔

issue #1 的回報者 wesley316-Guybrush 提供，供重現「身上帶著道具」才出現的畫面
（道具欄視窗、道具清單排版）。四格分別停在不同進度，第 4 格身上有四件道具
（短刀／胡蘿蔔／幸運草／金蛋，得分 19）。

用法（headless）：

```bash
docker run --rm --name kq1-playtest \
  -v "$PWD/scummvm-src:/src" -v "$PWD/game/sci_1990/KQ1NEW:/game:ro" \
  -v "$PWD/dist-cht:/cht:ro" -v "$PWD/test-saves/kq1sci:/saves" \
  -v "$PWD/out:/out" -v "$PWD/tools:/tools:ro" \
  kq1-capture bash /tools/capture_soak.sh
```

`tools/capture_inv.sh`（逐格載入 → 房間與道具欄各截一張）、
`tools/capture_menu.sh`（選單列與下拉項）、
`tools/capture_soak.sh`（連續換場景 + 開關視窗的浸泡測試）都吃這批存檔。

不帶 `--language=tw` 跑一次就是英文版對照組，用來分辨「中文化的迴歸」與「原版本來就這樣」。
