# Godot 单机版

该目录是《一会儿巢里见》的 Godot 4 游戏核心。普通标题页当前进入春季往返产品纵切；旧 `main.tscn` 的 24 节点循环继续作为规则回归基线。仓库根目录的 React／Vite 项目只承载同一 Godot 工程的 Web 导出。Web、macOS universal 与 Windows x86_64 三个目标同源。

## 运行

使用 Godot 4.6.2 或更高版本打开 `project.godot`，运行主场景即可。工程入口是 `bootstrap.tscn`；普通运行没有 playtest ticket 时，它会保持原行为进入 `main.tscn`。

macOS 命令行验证：

```bash
npm run test:godot
```

脚本先生成构建来源、执行无界面资源导入并生成全局类缓存，再依次执行 smoke、strict playtest ticket、bootstrap、save namespace 隔离、共享急转运行时、B01 固定切片、完整流程、Boss 节点、音乐、Boss 状态机、四季机制、中继巢、老师傅教学、HUD 响应式／饮蜜指针输入和新旅程世界共 15 组回归。新旅程组覆盖真实场景切换、大地图与 Camera2D、同形传粉、小蜂房边界和单次返巢结算；B01 组覆盖 2.8 秒示范、有界引导／无提示实践、恰好 180 秒 active 时钟、一次复测和三个互斥结果。每组除了进程退出码，还必须在独立日志中报告 `TEST PASSED`。默认查找 PATH 中的 `godot` 或 `godot4`；也可通过 `GODOT_BIN=/完整路径/Godot npm run test:godot` 指定可执行文件。CI 固定下载并校验官方 Godot 4.6.2 Linux 发行包后运行同一脚本。这是开发者自动验证，不是玩家已经理解或喜欢路线的证据。

## 当前工程内容

新产品入口已包含春季往返路线、大地图、主巢／春野场景切换、同形传粉、小蜂房有限休息和返巢接货。下列其余项目是旧 `main.tscn` 的规则回归基线；其中旧叙事术语不自动沿用到新产品。

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
- 固定 B01 急转切片使用与主流程相同的共享输入／因果规则，以独立 typed scene 完成“2.8 秒示范 → 有界引导 → 无提示实践”；只有无提示实践首次成功，才继续“180 秒 active 花间路线 → 一次无字同配置复测”，否则在有界实践后中性结束；它不实例化 Main、MentorTutorial 或 SaveManager，也不读写存档；
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

三个 export preset 都会排除仅供开发的 `res://tests/**` 与 `res://tools/**`。修改导出配置或增加内部资源后，运行：

```bash
npm run verify:godot-export
```

该门禁使用 Godot 4.6.2 对 macOS、Windows Desktop、Web 各执行一次真实资源包导出，再由隔离的 Godot 检查进程挂载 PCK 并遍历内容；它不会只读取或 grep `export_presets.cfg`。包内必须同时存在 bootstrap、原 Main、生产 `ready` 的中性 `data/playtest_slices.json` 和编译注册的 B01 typed scene，并且不能出现 tests／tools。也可用 `./scripts/verify_godot_export_contents.sh --pack <路径>` 直接检查已有 PCK、ZIP resource pack 或内嵌 PCK 的可执行文件。桌面 CI 会用后一种方式检查实际 macOS PCK 和最终 Windows EXE。

仓库也提供 GitHub Actions 手动打包：在 **Actions → Desktop client builds** 输入与 `package.json` 一致的版本 tag。macOS 与 Windows 在独立 runner 上运行测试和 release 导出；最终包完成内容检查（macOS 另含严格验签）后，流水线为包生成 SHA-256 sidecar 和同名 `.manifest.json`，再把三者作为一个 artifact 上传。manifest schema v1 直接读取最终 ZIP／EXE bytes；generator 会从 macOS ZIP 中唯一的 app PCK 或 Windows EXE 内嵌 PCK 重新读取 `res://data/build_provenance.json`，拒绝把旧包与当前工作区 provenance 拼接成错误身份。包内与工作区 provenance 必须逐字段一致，并同时匹配当前 `package.json` 与 `project.godot` 产品版本、完整 40 位 `HEAD`、`dirty: false`、干净工作区、平台固定文件名、byte 大小及 sidecar 哈希。GitHub run/ref 只从显式流水线输入写入，manifest 不猜测稍后才由上传步骤分配的 artifact ID。

本地只有在 release 包已经完成同等验证、工作区干净、可用 Godot 4.6.2 且系统提供 ZIP 读取工具（macOS 使用 `tar`，其他系统使用 `unzip`）时，才能生成同一核心 schema（没有 GitHub run/ref）：

```bash
node scripts/generate_artifact_manifest.mjs \
  --artifact builds/NamelessBecoming-macOS.zip \
  --platform macos-universal
node scripts/generate_artifact_manifest.mjs \
  --artifact builds/NamelessBecoming-Windows.exe \
  --platform windows-x86_64
```

manifest 是包身份与完整性的机器可读证据，不是启动、玩法、设备兼容、真人体验或公开发行验收。默认只生成保留期有限的 GitHub artifacts，只有主分支运行且明确选择 `publish_prerelease` 才会发布预发布版本。
