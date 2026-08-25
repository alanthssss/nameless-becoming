# Godot 单机版

该目录是《无名：成蜂》的 Godot 4 游戏核心。仓库根目录的 React／Vite 项目只承载这一工程的 Godot Web 导出，不保留或维护第二套早期玩法规则。Web、macOS universal 与 Windows x86_64 三个目标同源。

## 运行

使用 Godot 4.6.2 或更高版本打开 `project.godot`，运行主场景即可。

macOS 命令行验证：

```bash
npm run test:godot
```

脚本先生成构建来源、执行无界面资源导入并生成全局类缓存，再依次执行 smoke、完整流程、Boss 节点、音乐、Boss 状态机、四季机制、中继巢和老师傅教学共 8 组回归。每组除了进程退出码，还必须在独立日志中报告 `TEST PASSED`。默认查找 PATH 中的 `godot` 或 `godot4`；也可通过 `GODOT_BIN=/完整路径/Godot npm run test:godot` 指定可执行文件。CI 固定下载并校验官方 Godot 4.6.2 Linux 发行包后运行同一脚本。

## 当前内容

- 直接控制蜜蜂飞行；
- 按住采蜜；
- 体力与振翅冲刺；
- 蚊虫追踪、碰撞与花蜜损失；
- 震翼惊退、明确体力消耗与敌人状态条，蜂针不作为普通攻击；
- 触角寻迹揭示隐藏花／气味路线、归巢方向与特定 Boss 真声；
- 花蜜总量守恒、返蜜花与可追回的蚂蚁赃蜜；
- 空格／回车情境动作、同方向双击急转、长按投蜜诱饵、WASD 独立映射与四季探索／Boss 共 8 轨音乐；
- 花朵生成保持至少 82 像素间距，体力采用不受主题最小尺寸影响的细条；
- 蜂巢安全边界与不依赖携蜜的归巢休息恢复；
- 回到蜂巢后才结算携带花蜜；
- 24 个节气数据节点；春分／夏至／秋分是显式 Boss 节点，大雪后进入冬至失律之熊；
- 开放花授粉、实体袭扰、野外留种和三暖点路线四组当前机制；
- 四位 Boss 分别以吸取、落地、寻迹真声和闪避撞暖花暴露，再完成 3 次调律；
- 4 首探索 + 4 首 Boss 变奏，共 8 个独立 WAV；
- 阴阳比例与节令色彩；
- 成功、失败及完整循环。

当前混合使用 Godot 原生绘制与已接入的低噪背景、独立蜂巢、玩家蜂、8 种季节花和敌害 PNG。它们属于候选切片，不代表最终上线美术已经通过。

界面中文使用 Noto Sans CJK SC Regular 的项目文案子集，字体文件位于 `fonts/NotoSansCJKsc-ProjectSubset.otf`，按同目录 `OFL-NotoSansCJK.txt` 中的 SIL Open Font License 1.1 分发。子集由官方完整字体和当前游戏数据、场景、项目设置及界面源码生成；smoke 测试递归扫描全部运行时 `.gd/.godot/.json/.tres/.tscn`，验证每个 Label/Button 实际使用项目字体，并逐字检查当前可见文本可渲染。新增中文导致测试失败时，用仓库根目录的 `scripts/build_cjk_font_subset.py <已核验的官方完整字体>` 重生成子集后再导出；若上游完整字体本身不含某个装饰符，应改用已有字形或文字标签。

## 桌面导出

工程已配置 macOS 与 Windows Desktop 导出预设。需要安装与编辑器版本一致的 Godot 4.6.2 Export Templates，随后可执行：

```bash
node scripts/generate_build_provenance.mjs
godot --path godot --headless --export-debug "macOS"
godot --path godot --headless --export-debug "Windows Desktop"
```

构建来源脚本会从 `package.json` 读取产品版本、从当前 `HEAD` 读取提交号，生成不纳入 Git 的 `data/build_provenance.json`；标题与暂停覆盖层会显示该版本和短提交号，未提交工作区会额外标记 `+dirty`。`npm run test:godot` 和桌面构建流水线会自动执行这一步。

仓库也提供 GitHub Actions 手动打包：在 **Actions → Desktop client builds** 输入与 `package.json` 一致的版本 tag。macOS 与 Windows 在独立 runner 上运行测试和 release 导出，生成包与 SHA-256 artifact；默认不创建 Release，只有主分支运行且明确选择 `publish_prerelease` 才会发布预发布版本。
