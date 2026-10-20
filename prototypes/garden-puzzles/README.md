# 合成与消除 · 试玩盒 0.1.0

两个规则独立的小样，用来和现有飞行版比较方向。Godot 4.6.2；本轮仅验证 macOS，非 Steam Demo。

- **合成 128**：4×4 棋盘，方向键／WASD／屏幕箭头滑动，同数合并；合出128胜、无法移动败。Z 或按钮撤回一步。
- **花朵三消**：6×6 棋盘，点击两格或拖动交换相邻花，横竖三个同类就消除。18次有效交换内消掉60朵；无效交换免费，无解自动重排。方向键选格、Enter选中／交换。
- Esc 先取消三消选中，再暂停；暂停层可重新开始本局或选择另一款。M 开关声音。结算可重玩。没有倒计时，没有存档或联网。

## 启动与验证

双击 `play.command` 启动源码；用户交付使用仓库 `outputs/gameplay-comparison/2026-10-20/合成与消除·试玩盒.app`。对照使用原有 `outputs/swarm-flight/2026-10-20-garden-chapter/雨来之前·花园奇遇.app`，本轮未修改飞行源文件。

```sh
godot --headless --path prototypes/garden-puzzles --editor --import --quit
godot --headless --path prototypes/garden-puzzles --script res://verify.gd
godot --headless --path prototypes/garden-puzzles --script res://ui_verify.gd
godot --headless --path prototypes/garden-puzzles --export-release "macOS Samples" /absolute/output/合成与消除·试玩盒.app
```

验证必须同时检查退出码、成功标记与没有 `SCRIPT ERROR`／`ERROR:`。规则验证命令末尾加 `-- --report=/absolute/report.json` 可输出规则样本报告；`PUZZLE_UI_CAPTURE_DIR=/absolute/existing/dir` 在原生运行 UI 验证脚本时输出截图。UI 测试以 Viewport 键盘、鼠标事件从选单走完两种种子1的完整胜局，单独标注输局边界夹具，不将夹具当真人完整失败局。

开发截图参数：`-- --mode=merge|match --seed=1 --capture=/absolute/image.png --capture-after=1`；普通启动不带参数，使用随机棋盘。QA脚本不进入导出包。

[范围、决策与证据](../../docs/design/merge-match-samples-20261020.md) · [资产来源](ASSETS.md)
