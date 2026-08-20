# Godot 单机版

该目录是《无名：成蜂》的正式 Godot 4 单机游戏方向。网页版本继续保留在仓库根目录，用于保存早期规则与交互验证。

## 运行

使用 Godot 4.6 或更高版本打开 `project.godot`，运行主场景即可。

macOS 命令行验证：

```bash
npm run test:godot
```

脚本先执行无界面资源导入并生成全局类缓存，再依次执行 `smoke_test.gd`、`flow_test.gd` 和 `fix_boss_term_test.gd`。默认查找 PATH 中的 `godot` 或 `godot4`；也可通过 `GODOT_BIN=/完整路径/Godot npm run test:godot` 指定可执行文件。CI 固定下载并校验官方 Godot 4.6.2 Linux 发行包后运行同一脚本。

## 当前内容

- 直接控制蜜蜂飞行；
- 按住采蜜；
- 体力与振翅冲刺；
- 蚊虫追踪、碰撞与花蜜损失；
- 震翼惊退、明确体力消耗与敌人状态条，蜂针不作为普通攻击；
- 触角寻迹显示蜜量、警戒范围、归巢方向与推荐目标；
- 花蜜总量守恒、返蜜花与可追回的蚂蚁赃蜜；
- U/I/O/J/K/L 六键技能区、WASD 独立映射与四节令旋律/低音/节奏环境音乐；
- 花朵生成保持至少 82 像素间距，体力采用不受主题最小尺寸影响的细条；
- 蜂巢安全边界与不依赖携蜜的归巢休息恢复；
- 回到蜂巢后才结算携带花蜜；
- 春分、夏至、秋分、冬至四个数据驱动关卡；
- 阴阳比例与节令色彩；
- 成功、失败及完整循环。

全部图形暂时由 Godot 原生绘制，避免在核心手感确定前制造大量不可复用美术。

界面中文使用 Noto Sans CJK SC Regular 的项目文案子集，字体文件位于 `fonts/NotoSansCJKsc-ProjectSubset.otf`，按同目录 `OFL-NotoSansCJK.txt` 中的 SIL Open Font License 1.1 分发。子集由官方完整字体和当前游戏数据、项目设置及界面源码生成；smoke 测试会扫描同一批来源中的 CJK 字符，阻止缺字字体进入 Web 构建。新增中文导致测试失败时，必须重新生成子集后再导出。

## 桌面导出

工程已配置 macOS 与 Windows Desktop 导出预设。需要安装与编辑器版本一致的 Godot 4.6.2 Export Templates，随后可执行：

```bash
godot --path godot --headless --export-debug "macOS"
godot --path godot --headless --export-debug "Windows Desktop"
```
