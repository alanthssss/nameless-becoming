# Godot 单机版

该目录是《归巢之前》的正式 Godot 4 单机游戏方向。网页版本继续保留在仓库根目录，用于保存早期规则与交互验证。

## 运行

使用 Godot 4.6 或更高版本打开 `project.godot`，运行主场景即可。

macOS 命令行验证：

```bash
godot --path godot --editor --headless --quit
godot --path godot --headless --quit-after 180
godot --path godot --headless --script res://tests/smoke_test.gd
```

## 当前内容

- 直接控制蜜蜂飞行；
- 按住采蜜；
- 体力与振翅冲刺；
- 蚊虫追踪、碰撞与花蜜损失；
- 震翼范围驱离与冷却，蜂针不作为普通攻击；
- 蜂巢安全边界与不依赖携蜜的归巢休息恢复；
- 回到蜂巢后才结算携带花蜜；
- 春分、夏至、秋分、冬至四个数据驱动关卡；
- 阴阳比例与节令色彩；
- 成功、失败及完整循环。

全部图形暂时由 Godot 原生绘制，避免在核心手感确定前制造大量不可复用美术。

## 桌面导出

工程已配置 macOS 与 Windows Desktop 导出预设。需要安装与编辑器版本一致的 Godot 4.6.2 Export Templates，随后可执行：

```bash
godot --path godot --headless --export-debug "macOS"
godot --path godot --headless --export-debug "Windows Desktop"
```
