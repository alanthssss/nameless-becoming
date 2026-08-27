# Godot 单机版

该目录是《一会儿巢里见》的 Godot 4 游戏核心。普通标题页当前进入春、夏、秋、冬与交棒结尾组成的产品旅程；旧 `main.tscn` 的 24 节点循环只继续作为规则回归基线。仓库根目录的 React／Vite 项目只承载同一 Godot 工程的 Web 导出。Web、macOS universal 与 Windows x86_64 三个目标同源。

## 运行

可复现验证与导出必须使用精确的 Godot 4.6.2，其他版本不属于已验证构建环境。用该版本打开 `project.godot`，运行主场景即可。玩家与正式导出的唯一入口是 `commercial_title.tscn`，从这里进入继续／新旅程、设置、许可和完整 Journey。旧 `bootstrap.tscn`、`main.tscn` 与 B01 typed scene 只保留在仓库中供开发回归或历史受控测试，不是玩家入口，也不得进入商业包。

macOS 命令行验证：

```bash
npm run test:godot
```

脚本先生成构建来源、执行无界面资源导入并生成全局类缓存，再执行 19 组回归：smoke、strict playtest ticket、商业标题／旧 bootstrap、save namespace 隔离、商业存档／设置、共享急转运行时、B01 固定切片、旧完整流程、Boss 节点、旧音乐、商业动作音效资产、Journey 音乐／环境层、二十四节气纪事、Boss 状态机、四季机制、中继巢、老师傅教学、HUD 响应式和 Journey 世界回归。当前产品组覆盖商业标题普通启动、真实场景切换、四季大地图与 Camera2D、同形传粉、修补、逐花收蜜／留种、听声种壳、续暖／挡风、小蜂房边界、单次返巢结算、节气 exact-once、存档／设置、暂停／失焦、基础手柄映射、8 轨音乐、14 条动作音效与 2 条环境循环；旧 B01 组仍只在开发测试中覆盖 2.8 秒示范、有界引导／无提示实践、180 秒 active 时钟、一次复测和互斥结果。每组除了进程退出码，还必须在独立日志中报告 `TEST PASSED`。默认查找 PATH 中的 `godot` 或 `godot4`；也可通过 `GODOT_BIN=/完整路径/Godot npm run test:godot` 指定可执行文件。CI 固定下载并校验官方 Godot 4.6.2 Linux 发行包后运行同一脚本。这是开发者自动验证，不是真实手柄、玩家理解或体验证据。

## 当前工程内容

新产品入口已包含春季首趟与花牌事故、夏季追回／修补、秋季逐花收蜜或留种／转正听声种壳、冬季续暖／挡风和最终交棒；四季均使用大于视口的真实场景，经主蜂巢完成返巢交接。当前 Journey 另有 24 条日常节气纪事、巢内回看板、exact-once 进度与存档迁移。下列其余项目是旧 `main.tscn` 的规则回归基线；其中旧叙事术语不自动沿用到新产品。

- 直接控制蜜蜂飞行；
- 按住采蜜；
- 体力与振翅冲刺；
- 蚊虫追踪、碰撞与花蜜损失；
- 震翼惊退、明确体力消耗与敌人状态条，蜂针不作为普通攻击；
- 触角寻迹揭示隐藏花／气味路线、归巢方向与特定 Boss 真声；
- 花蜜总量守恒、返蜜花与可追回的蚂蚁赃蜜；
- 空格／回车情境动作、同方向双击急转、长按投蜜诱饵、WASD 独立映射与四季探索／事故段共 8 轨音乐；旧 `enter_boss()` 只作为 Main 调用兼容别名；
- 花朵生成保持至少 82 像素间距，体力采用不受主题最小尺寸影响的细条；
- 蜂巢安全边界与不依赖携蜜的归巢休息恢复；
- 回到蜂巢后才结算携带花蜜；
- 24 个节气数据节点；春分／夏至／秋分是显式 Boss 节点，大雪后进入冬至失律之熊；
- 开放花授粉、实体袭扰、野外留种和三暖点路线四组当前机制；
- 四位 Boss 分别以吸取、落地、寻迹真声和闪避撞暖花暴露，再完成 3 次调律；
- 4 首探索 + 4 首事故段变奏，共 8 个独立 WAV，当前文件名与音频模式均使用 `incident`；
- 固定 B01 急转切片使用与主流程相同的共享输入／因果规则，以独立 typed scene 完成“2.8 秒示范 → 有界引导 → 无提示实践”；只有无提示实践首次成功，才继续“180 秒 active 花间路线 → 一次无字同配置复测”，否则在有界实践后中性结束；它不实例化 Main、MentorTutorial 或 SaveManager，也不读写存档，只供仓库开发回归／历史受控测试，商业导出明确排除；
- 阴阳比例与节令色彩；
- 成功、失败及完整循环。

当前商业路径混合使用 Godot 原生绘制与 `assets/art/commercial/` 的 17 张运行候选 PNG，覆盖四季地表、主／小蜂巢、巢内门槛、玩家／老师傅／工蜂、花、四位邻居、独立听声种壳与季节工作物。旧油葫芦和旧画眉图保留在源目录供审计，但当前代码不加载、三个导出预设均排除；新的油葫芦、普通身体画眉、种壳与工作物图集已经替换运行表现。候选资产不代表来源／授权完整、Alan 终稿批准或独立玩家可读性通过；逐文件状态见 `../docs/design/art-source-register.md`。

当前 Journey 还接入左摇杆移动、A 情境动作、Y 归巢与 Start 暂停的基础手柄映射；X 饮蜜只保留给旧规则回归基线，不是当前 Journey 的玩家承诺。键位／手柄重映射、震动与断开重连仍未完成。`assets/audio/commercial/` 包含 14 条项目自有确定性合成动作音效和 2 条 10 秒环境循环，源参数、生成器、逐文件哈希与无外部采样声明都进入仓库和游戏内 Credits；它们仍须 Alan 听感批准及耳机、扬声器和目标设备终混，不能标作发行终稿。

界面中文使用 Noto Sans CJK SC Regular 的项目文案子集，字体文件位于 `fonts/NotoSansCJKsc-ProjectSubset.otf`，按同目录 `OFL-NotoSansCJK.txt` 中的 SIL Open Font License 1.1 分发。子集由官方完整字体和当前游戏数据、场景、项目设置及界面源码生成；smoke 测试递归扫描全部运行时 `.gd/.godot/.json/.tres/.tscn`，验证每个 Label/Button 实际使用项目字体，并逐字检查当前可见文本可渲染。新增中文导致测试失败时，用仓库根目录的 `scripts/build_cjk_font_subset.py <已核验的官方完整字体>` 重生成子集后再导出；若上游完整字体本身不含某个装饰符，应改用已有字形或文字标签。

## 桌面导出

工程已配置 macOS 与 Windows Desktop 导出预设。需要安装与编辑器版本一致的 Godot 4.6.2 Export Templates，随后可执行：

```bash
node scripts/generate_build_provenance.mjs
scripts/with_commercial_godot_cache.sh \
  godot --path godot --headless --export-debug "macOS" \
  "$PWD/builds/SeeYouAtTheHive-macOS.zip"
scripts/with_commercial_godot_cache.sh \
  godot --path godot --headless --export-debug "Windows Desktop" \
  "$PWD/builds/SeeYouAtTheHive-Windows.exe"
```

构建来源脚本会从 `package.json` 读取产品版本、从当前 `HEAD` 读取提交号，生成不纳入 Git 的 `data/build_provenance.json`；标题与暂停覆盖层会显示该版本和短提交号，未提交工作区会额外标记 `+dirty`。`npm run test:godot` 和桌面构建流水线会自动执行这一步。

三个 export preset 都只列入 `commercial_title.tscn`、`journey.tscn`、7 张动态 Journey 区域场景和它们明确需要的商业资源；同时排除 `bootstrap.tscn`、`main.tscn`、B01／playtest、tests、tools、旧 launch／seasonal／textile 美术和旧玩家数据。正式导出必须经过 `with_commercial_godot_cache.sh`：它复制一个临时项目，只留下 `data/commercial_script_class_allowlist.json` 审过的运行脚本，再原子生成商业 `global_script_class_cache.cfg`；完整项目缓存和前置回归测试不受导出扫描影响。导出命令必须给出显式成品路径，临时项目无论成功或失败都会清理。修改导出配置或增加内部资源后，运行：

```bash
npm run verify:godot-export
```

该门禁使用 Godot 4.6.2 对 macOS、Windows Desktop、Web 各执行一次真实资源包导出，再由隔离的 Godot 检查进程挂载 PCK 并遍历内容；它不会只读取或 grep `export_presets.cfg`。包内必须以 `res://commercial_title.tscn` 为主场景，存在 Journey、7 张动态区域、build provenance、credits／licenses、24 节气纪事、Noto 字体／OFL 与商业候选运行资产；商业类缓存必须逐行匹配白名单，每个缓存路径也必须在 PCK 中存在对应编译脚本，包内不能出现白名单外脚本或 Nameless、Boss、B01、Playtest、旧 Main／bootstrap、production HUD 类与路径。也可用 `./scripts/verify_godot_export_contents.sh --pack <路径>` 直接检查已有 PCK、ZIP resource pack 或内嵌 PCK 的可执行文件。桌面 CI 会用后一种方式检查实际 macOS PCK 和最终 Windows EXE。

仓库也提供 GitHub Actions 手动打包：在 **Actions → Desktop client builds** 输入与 `package.json` 一致的版本 tag。macOS 与 Windows 在独立 runner 上使用 Node 22.13.0、Godot 4.6.2 及对应模板运行测试和 release 导出；最终包完成内容检查后，macOS 还会验证实际可执行文件同时包含 `arm64` 与 `x86_64`，并对已做的 ad-hoc 签名执行严格校验。流水线为包生成 SHA-256 sidecar 和同名 `.manifest.json`，再把三者作为一个名称显式包含 `InternalCandidate` 的 artifact 上传。manifest schema v1 直接读取最终 ZIP／EXE bytes；generator 会从 macOS ZIP 中唯一的 app PCK 或 Windows EXE 内嵌 PCK 重新读取 `res://data/build_provenance.json`，拒绝把旧包与当前工作区 provenance 拼接成错误身份。包内与工作区 provenance 必须逐字段一致，并同时匹配当前 `package.json` 与 `project.godot` 产品版本、完整 40 位 `HEAD`、`dirty: false`、干净工作区、平台固定文件名、byte 大小及 sidecar 哈希。GitHub run/ref 只从显式流水线输入写入，manifest 不猜测稍后才由上传步骤分配的 artifact ID。这些包只是内部候选：macOS 没有 Developer ID 签名或 Apple 公证，Windows 没有 Authenticode 签名，不得冒充商业安装包。

本地只有在 release 包已经完成同等验证、工作区干净、可用 Godot 4.6.2 且系统提供 ZIP 读取工具（macOS 使用 `tar`，其他系统使用 `unzip`）时，才能生成同一核心 schema（没有 GitHub run/ref）：

```bash
node scripts/generate_artifact_manifest.mjs \
  --artifact builds/SeeYouAtTheHive-macOS.zip \
  --platform macos-universal
node scripts/generate_artifact_manifest.mjs \
  --artifact builds/SeeYouAtTheHive-Windows.exe \
  --platform windows-x86_64
```

manifest 是包身份与完整性的机器可读证据，不是启动、玩法、设备兼容、真人体验或公开发行验收。默认只生成保留期有限的 GitHub artifacts；只有主分支运行且明确选择 `publish_prerelease` 才会发布预发布版本，该预发布仍明确标记为未做发行签名／公证的内部候选，不是可对外销售的商业安装包。
