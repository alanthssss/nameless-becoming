# 花间一着 · 可玩短章

这是 Godot 4.6.2 独立玩法实验，包含开场、四段连续遭遇、失败撤回和结尾。没有连接旧游戏的日历、存档或商业导出。体验是否成立等待 Alan 实玩；自动通关仅证明规则与路径可达。

## 打开

macOS 双击本目录 `play.command`，或运行：

```sh
GODOT_BIN="/Applications/Godot 2.app/Contents/MacOS/Godot" ./play.command
```

也可以用 Godot 4.6.2 打开 `project.godot` 后运行。需要本机系统中文字体；本轮另提供可独立打开的本地 Mac 试玩包，未制作 Windows／Web 发行包。进度仅在这次会话中保留。

## 操作

- 方向键移动方框、选择落点，Enter 确认飞行。移动方框不消耗回合；能选择与鼠标相同的所有亮点，包括远处及斜向位置。
- 鼠标悬停预览，点击亮点也可飞行。金色／红色预览显示这一拍的结果；飞行后键盘方框回到蜂的新位置。
- 空格：在当前位置的叶片上栖停。飞到叶片不等于已经栖停。
- W：保持当前状态等一拍。悬空时仍受风影响。
- Z：撤回，次数不限；R：重开当前遭遇；Esc：暂停；故事页面按 Enter 继续。

每拍顺序：**玩家行动 → 已锁定的动物动作 → 风 → 下一拍预告**。

红区是这一拍会发生的动作；飞行预览用与执行完全相同的规则，金色表示不会受伤，红色表示会撞上危险或被风推向边界。叶荫只有栖停后能挡画眉；油葫芦会压下落点的薄叶。褐色脆枝被动物动作击中后真正消失，绿色苇丛不可穿越。抵达白花即完成该遭遇，不搬运交货。

## 验证

```sh
"$GODOT_BIN" --headless --path . --editor --import --quit
"$GODOT_BIN" --headless --path . --script res://verify.gd
"$GODOT_BIN" --headless --path . --script res://ui_verify.gd
```

这是拟人化、回合制的生态题材游戏。动物的预告、步幅、攻击面积、枝叶破坏和风的节拍是设计规则，不作为真实动物行为或自然知识教学。

玩法方案与取舍见 `../../docs/design/flower-step-game-20261019.md`。唯一制作状态仍在现有制作规格的 Now。

## 本地 Mac 打包

安装匹配的 Godot 4.6.2 export templates 后，在本目录执行（输出目录须先创建）：

```sh
"$GODOT_BIN" --headless --path . --export-release "macOS Prototype" /absolute/output/花间一着.app
codesign --force --deep --sign - /absolute/output/花间一着.app
codesign --verify --deep --strict /absolute/output/花间一着.app
```

这是本地试玩用的临时签名，不是商业发行公证。独立 bundle ID 为 `com.alanthssss.flowerstep`。导出后还应运行包内可执行文件的 `--headless --quit-after 3` 检查，拒绝日志中的 `SCRIPT ERROR`／`ERROR:`；仅看导出命令成功不足以证明脚本被正确包含。
