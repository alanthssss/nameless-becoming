# Swarm Flight CI 耗时分析与并行验证

2026-11-01（Asia/Shanghai）；内部工程维护。关联：[GDD §12 技术规格与 §13 质量交付](design/swarm-flight-gdd.md) → [M1](https://github.com/alanthssss/nameless-becoming/milestone/1) → 调查 [#238](https://github.com/alanthssss/nameless-becoming/issues/238)、实施 [#239](https://github.com/alanthssss/nameless-becoming/issues/239)。GitHub Issue 保存执行状态，本页保存分析和验证依据，不是第二个任务队列。

## 实测瓶颈

用户要求缩短当前 CI。以下来自 GitHub Actions 的开始/完成时间；工作流墙钟包含调度，job 秒数不等于计费分钟或制作工时。

| 测量 | PR 基线 | main 基线 |
| --- | ---: | ---: |
| 运行 | [41026148069](https://github.com/alanthssss/nameless-becoming/actions/runs/41026148069) | [41027034512](https://github.com/alanthssss/nameless-becoming/actions/runs/41027034512) |
| 源版本 | `005c592a5bf4f33adb05ce081dcd4f037f6a0b35` | `801823675f5dfc0de653d3d3737a428c9991e6f1` |
| 工作流墙钟 | 437 秒 | 434 秒 |
| 单个 job | 434 秒 | 431 秒 |
| checkout / Godot 下载 / 导入 | 9 / 2 / 22 秒 | 9 / 2 / 20 秒 |
| 基础模型 | 7 秒 | 6 秒 |
| Python 门禁、风/供给 mutation 与存档 | 74 秒 | 75 秒 |
| 完整场景与恢复 | 121 秒 | 120 秒 |
| 长关与精确恢复 | 74 秒 | 74 秒 |
| 天气 / 蜂舞 / 守路者 | 16 / 25 / 20 秒 | 16 / 25 / 20 秒 |
| 春季整合及叶棚变体 | 53 秒 | 53 秒 |
| 音频 / 主场景启动 | 3 / 4 秒 | 3 / 4 秒 |

两次运行的主要耗时一致，瓶颈是串行验证。下载仅约 2 秒，不优先增加缓存维护；此次不改模拟时钟、不跳过 baseline、不缩减断言。Quality 的轻量检查约十几秒，旧 Godot/Web 项目不在本轮变更范围。

## 实施决定与边界

Codex 根据上述实测将原 workflow 分为三个独立 runner，所有现有测试步骤恰好分配一次，步骤内命令、参数、环境及成功断言原样保留：

| 组 | 原有检查 | 基线测试时间（不含准备） |
| --- | --- | ---: |
| `core` | 基础规则/完整路线、完整 UI/恢复、音频、主场景 | 约 133 秒 |
| `regressions` | Python 门禁、风/供给变异、供给存档、长关模型/UI | 约 149 秒 |
| `samples` | 天气、蜂舞、守路者、春季整合/叶棚 | 约 114 秒 |

每个 runner 独立 checkout、SHA-512 校验引擎、导入，以隔离 Godot 的 user/cache 目录、存档和变异文件。每组内部仍按原顺序执行。`fail-fast: false` 保留其它组的诊断；不使用 `continue-on-error`。原 `Swarm Flight rules and complete routes` 检查名改为汇总 job，始终评估 matrix 结果，仅 `success` 放行，失败/取消/跳过/空结果均不能放行（整次取消时汇总也可能被取消）。8 分钟超时、触发路径、主线 push 复跑及并发取消策略保持原样。

矩阵与依赖结果语义按 [GitHub matrix 文档](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/run-job-variations)和 [needs 上下文文档](https://docs.github.com/en/actions/reference/workflows-and-actions/contexts#needs-context)核对。首轮实施时分支保护 API 返回 403，当时未配置远端强制保护；保留旧检查名用于兼容现有检查消费者。后续公开仓库并启用保护的实证见[服务器保护](#server-protection)。

预估工作流约 3 分钟，须由本次远端完整 CI 实测确认。多两份初始化及汇总 job 会增加 runner 总秒数；这是反馈速度与执行资源的取舍，不声称降低账单。若排队抵消并行收益、耗时失衡或费用明显增加，按实际数据重新调整分组。回退本次 workflow 提交即可恢复串行。

## 验证与成本记录

本地验证覆盖 YAML/Actions 语法、原步骤内容等价与每项恰好执行一次、汇总门禁拒绝非成功状态、既有 CI 分类和差异格式；独立只读复核及 PR/main 的完整执行链接与实际时长回写 [#239](https://github.com/alanthssss/nameless-becoming/issues/239)。完整引擎测试以真实 CI 为准，不以静态检查替代。

调查 Issue 于 2026-11-01 01:25:38 开工，实施 Issue 于 01:26:06 开工（北京时间），此前定位阶段的主动时长覆盖不完整；收口时间与外部 CI 等待按 GitHub 事件记录。此维护只缩短工程反馈，不改变玩法、玩家证据或产品 G 门禁；新采购 0，Actions 实际费用、历史累计和可靠剩余工时未知，200＋40 小时控制不变。自动接续保持暂停。


<a id="trigger-contract"></a>
## 第二轮：触发条件、实际依赖与放行合同

用户随后要求仔细分析和优化触发条件，仍沿用 #238 / #239；首轮并行数据保持历史有效。本节记录入口与事件规则。当前文件分类和审查范围见下方[按改动选择检查](#review-scope)。Codex负责有限工程决定及验证，不改产品Now、玩法或发布范围。

<a id="review-scope"></a>
### 按改动选择检查 · 2026-11-26

PR 与 `main` push 都先校验差异、路由和工作流语法，最后由 `CI required checks` 汇总。逐文件取并集，移动文件按旧、新两处用途判断。下表用于选检查和审查改动，复核人可直接在运行的 **Change scope and lightweight CI checks** 摘要看到选择结果。图像观感、谱面与试玩结论由提交的资料支持。

| 改动 | 自动检查 | 审查重点 |
| --- | --- | --- |
| 普通 Markdown、讨论图、美术评审截图、地图草图、研究表格、归档日志和《花间慢行》简谱 PDF | 轻量检查 | 核对图像、日志或谱面与本次说明、对应游戏版本是否一致；外观改动看实际尺寸对照 |
| 文档目录的 JSON 回执、研究数据、JSONL 事件记录 | 对新增或修改的 JSON 解析，对 JSONL 逐行解析，格式错误阻止通过 | 核实内容和来源；项目内的旧档测试输入仍走原型回归 |
| README、marketing 或路由列明的素材／文案合同输入 | 两组 Node 文案与材料测试；已选 Web 时由 Web 覆盖 | 核对对外表述、素材登记 |
| 区域 GDScript、区域着色器／深度图／音乐、已核实只由区域读取的贴图及其制作源 | 仅 `region-greybox` 一组，覆盖区域模型、UI、操作、存档位、成长手册和依赖区域代码的池岸 TileMap | 按实际受影响的玩法、存档兼容或画面对照复核 |
| Swarm 共用代码、共用或尚未确定使用范围的原型素材、配置、打包契约、历史测试输入或 Swarm 工作流 | 完整六组 Swarm；与局部区域改动混合时扩大到六组 | 共用绘制和入口要看多处调用；存档变更核对旧档与冷续；打包契约由 core 的打包测试读取 |
| Flower Step 或 Garden Puzzles | 只跑改到的原型 | 核对该原型规则和完整路线 |
| 站点代码、主 Godot 或两者共用的资源 | 站点代码跑 Web；Godot 路线输入跑路线测试；主工程共享素材、脚本跑 Web 与完整 Godot | 核对受影响的入口与资源 |
| 主工程导出配置、入口、打包脚本或 npm 依赖清单 | Web、完整 Godot 及 clean Web 导出验证 | 核对导出的内容和启动页；桌面包另由手动工作流生成 |
| 总工作流、分类器、门禁及其测试、未知路径或无法确定差异，手动完整运行或合并组 | 全仓检查 | 核对路由和各组结果，尤其是缺失或意外跳过的检查 |

例：按原始文件清单重放，简谱 #418 只走轻量检查；手册 #417 选一个区域组；体力条 #420 与图标 #416 都修改了共用 `world_view.gd`，各选六组 Swarm。#414 改了 Swarm 工作流和制作规格，选六组 Swarm 加文案合同。以上是路由回放，历史运行耗时仍按原规则记录。新增跨目录读取者时，在同一 PR 更新分类与回归样例。[变更与验证 #421](https://github.com/alanthssss/nameless-becoming/issues/421)

#### 讨论图、原稿与实装素材

| 位置和用途 | 运行范围 |
| --- | --- |
| `docs/art/` 直属的讨论图、`docs/art/discussion/`、`docs/design/concepts/` 和 `docs/design/screenshots/` 的配图 | 轻量；`docs/art/` 根目录已登记为游戏原稿的文件优先走对应原型 |
| `docs/design/region-map-drafts/` 的设计图与节点 JSON、`docs/research/` 的研究图片和 CSV/JSON 数据、制作回执 | 轻量；文档 JSON/JSONL 要能解析，斜视角预览截图按归档清单核对 SHA-256 |
| `docs/art/collection-fields/` 中用于制作的原画、配准数据和生成脚本，以及 `docs/art/honey-basin-visitors-429.png` | 区域回归。生成的花田、花朵、鱼与蛙贴图及其 Godot 导入设置也走区域回归 |
| `region_game/` 的区域音乐、深度图和着色器，庭院拆图脚本及其四张运行时纹理、成长手册原生目录的设计数据 | 区域回归；共用蜂形图、原型入口、打包契约继续跑完整 Swarm |
| `marketing/` 商店图、`public/` 站点图、`godot/assets/` 主工程资产 | 分别验证文案与素材合同、Web、Web 加完整主 Godot；主工程导出入口另验 Web 导出 |

增加游戏原稿时，在同一变更里登记读取方并补分类样例。新的纯讨论图可放入 `docs/art/discussion/`。其它未分类的美术子目录、程序和配置走原来的保守规则。跨目录移动同时考虑来源和去向。#428 只有五张讨论 JPG；#430 同时含鱼蛙原稿与运行时纹理，#431 同时含截图与区域着色器。三者的回放与实际运行记录见 [#432](https://github.com/alanthssss/nameless-becoming/issues/432)。

<a id="main-sync-reuse"></a>
### 多个 PR 同步 main 后怎样复用检查

`main` 仍要求分支与主线同步，每个新提交都产生自己的 `CI required checks`。同仓 PR 单纯合并或等价变基到新主线时，轻量作业会按下表重新决定 Web、主 Godot、干净 Web 导出和三个独立原型的检查。它比较上次真正测试的合并树与本次合并树，再用同一个文件分类器判断依赖，因此同属一组的不同文件也能相互影响。

| 同步带来的实际变化 | 新提交上运行的检查 |
| --- | --- |
| 主线只增加归档截图、简谱或普通说明 | 已有成功凭证的原型组可全部复用；差异、路由和必需汇总照常执行 |
| 当前 PR 选择 Web、主 Godot 和干净 Web 导出，前后测试树相同 | 同 PR、同仓库、同工作流最近的成功 attempt 已覆盖的作业可以复用。范围检查重新生成当前提交的版本标记，必需门禁记录来源 |
| 主线改了根 README、网站页面或年历矩阵 | 根 README 由 Web 的文案合同读取；站点页面触发 Web 和候选导出；年历矩阵触发主 Godot。Godot 的完整结果覆盖路线测试，路线结果只覆盖路线测试 |
| 主线只改 Flower Step，当前 PR 同时涉及 Flower 和 Garden | 重测 Flower；以前通过的 Garden 可以复用 |
| 当前 PR 要求完整六组 Swarm，主线只改区域脚本 | 有完整六组的旧凭证时只重测 `region-greybox`，其余五组复用 |
| 两个 PR 分别改区域 UI 和区域模型 | 两者都影响区域回归，重跑区域组；涉及共用 Swarm 输入时，按 PR 原本选中的范围重跑 |
| 主线修改了路径分类、文档格式检查或它们的回归测试 | 当前提交运行新版范围检查。对照旧 attempt 的实际成功作业，复用输入相同且覆盖足够的原型组。同批带入的游戏、工作流或其它文件仍按影响范围重测 |
| 变基或合并夹带新编辑、发生冲突、目标改变，或总工作流、凭证／门禁代码、公用执行环境变化 | 按当前 PR 的正常范围验证 |
| 旧运行失败／取消／尚在运行、旧套件覆盖不足、API 或 Git 历史不可用 | 缺乏成功依据的检查照常运行。文案合同及 main push 各自执行原有规则 |

**结果如何核实。** 上次必需门禁通过后，由 GitHub Actions 在该作业中记录 PR 号、主线提交、实际测试树及各原型覆盖。新运行只读取同仓同分支、同一旧 head、同一 Quality 工作流最近一次运行的对应 attempt；同时校验两次集成树、主线历史及 CI 控制文件。结果和来源链接进入 scope 与必需检查摘要。连续同步可沿成功门禁回溯；首次运行或升级前没有凭证时正常测试。分支冲突仍由项目原有流程解决。

#438 庭院实装同步 #437 时，两棵实际测试树只差 7 个文件，涉及范围分类、文档校验、相应测试、CI 说明和根 README。旧规则使六个 Swarm 作业全部重跑，整轮用时 6 分 52 秒，六组合计占用 runner 22 分 13 秒。使用同一对 Git 树、同一份 Actions 成功记录回放，新规则复用六组。根 README 仍触发文案合同，范围检查与当前提交的两个结果汇总仍执行。主线同步涉及路由变更时，旧汇总中沿用的成功结果、缺项、跳过或失败的作业都不能作为该组的实际执行凭据。[上次成功门禁](https://github.com/alanthssss/nameless-becoming/actions/runs/45682197171/job/139448628685) · [同步后的原始运行](https://github.com/alanthssss/nameless-becoming/actions/runs/45683229209)

手账 #417 同步笛谱 #418 是实际历史例子，两次测试树只差简谱 PDF 和制作回执。新规则会对具备凭证的同类同步复用区域回归。旧运行没有这个凭证，历史实耗保留。[实施记录 #424](https://github.com/alanthssss/nameless-becoming/issues/424)

### 已证实问题与预防措施

| 原问题 | 证据/后果 | 修正 |
| --- | --- | --- |
| CI自己改了却只跑轻量检查 | `quality.yml`原被分类为全部false；修改引擎下载/测试/导出步骤时，对应job根本不执行 | 入口、分类器、总门禁及其测试改动强制全选；每次scope校验全部workflow语法 |
| Swarm独立输入误选旧游戏/Web | 供给回归脚本、两个spring工具、两个spring测试未列入豁免，实际同时触发两套系统 | 单一分类器统一Swarm依赖，无第二份workflow路径清单 |
| main复跑与README不一致 | Quality只接PR/手动；原scope只在PR分支读取diff，直接增加push仍会全部重跑 | 增加main push并解析完整 `before..sha`；PR按merge-base三点diff；异常历史保守全选 |
| Node实际输入漏选 | 音频哈希/字节、游戏文案/素材合同读取Godot资源和脚本，但原分类只跑引擎 | 共享资产/脚本/字体/世界/数据同时选Web与完整Godot，不因此自动导出 |
| Markdown被一概忽略 | 文案测试读取README、marketing和Steam文档；材料测试读取设计/素材登记 | 明确content输入，单独运行现有两组Node合同，无需npm安装或构建；已选Web时由Web内相同测试覆盖，避免重复 |
| 存在永不执行的测试 | `prepare-web-export.test.mjs`未在任何npm或workflow测试入口 | 接入现有 `npm test`；仅新增执行既有2个WASM备份/失败保留测试 |
| 恢复main差异路由时需避免跨提交取消（预防设计） | 若新入口仍沿用main ref并发，后续文档push可能取消前一代码验证；旧Quality没有push，不能列作旧版已复现故障 | 主线并发按提交SHA隔离，不取消不同提交；仅PR按编号取消被替代的版本 |
| 路径过滤与汇总缺乏统一合同 | 独立workflow的paths与分类器容易漂移；被整条跳过的workflow不产生可用required结果 | Quality作为唯一自动入口，原型使用同一revision的本地reusable调用；总门禁始终检查scope及所有选择结果 |

这些结论来自实际单路径分类复现、源码依赖读取和独立复核。required-check的Pending风险在本轮调查时为条件性问题：当时远端分支保护接口403，未声称本仓库已经被它阻塞；当前保护状态见[服务器保护](#server-protection)。[GitHub说明](https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/troubleshooting-required-status-checks)区分workflow未触发、条件跳过和上游失败；因此不能把skipped一概当作测试通过。

### 事件与分支规则

| 事件 | 检查范围 | 取消/发布行为 |
| --- | --- | --- |
| PR opened / synchronize / reopened | 完整PR差异，按merge-base分类，包含删除与重命名两端 | 同PR新运行可取消旧运行；草稿PR也验证，不隐藏失败 |
| PR edited | 重新计算完整PR差异，覆盖改目标分支 | 标题/正文编辑也保守复跑；不以跳过同名门禁来掩盖该SHA先前失败 |
| main push | 完整before→after变化；多提交push不只看最后一项 | 各SHA独立完成，后续文档push不取消代码检查 |
| Quality workflow_dispatch | 所有现有自动检查 | 独立于自动运行；不产生桌面包、不发布 |
| merge_group checks_requested | 全量检查合并组 | 已准备事件支持；未启用或声称已验证远端merge queue设置 |
| 单个原型workflow_dispatch | 该原型完整测试 | 保留诊断入口；不能代替PR所需检查的真实pull_request运行 |
| Desktop client builds手动 | 原有版本校验、双平台构建及其现有门禁 | 未改：publish默认false，仅显式选择且main才能发布；自动CI不会调用它 |

同名手动原型工作流不再另接PR/push，避免Quality调用之外再跑一遍。Swarm 按选择的范围并行运行测试组。reusable内部检查在UI中带调用方前缀，Quality顶层另保留旧 `Swarm Flight rules and complete routes` 名称；综合检查为 `CI required checks`，现已设为main的必需检查并绑定GitHub Actions来源，见[服务器保护](#server-protection)。以后修改检查名或来源时必须同步远端设置并读回，不能用分支名或本地文档代替启用。

### 2026-11-01 路径与失败边界

- 普通 `docs/*.md` 等说明：scope和两个结果门禁；README、marketing、现有材料allowlist为content例外。
- `prototypes/swarm-flight/**`及其风/供给/交付/spring工具与测试：只选Swarm；Flower/Garden各选对应原型。**不整目录排除review-evidence**：叶棚测试确实读取其中旧存档JSON。
- Godot路线输入：路线套件；共享源码/素材/字体/世界/数据：Web＋完整Godot；正式工程/导出/打包依赖：再加clean Web candidate。`package.json`也控制Godot命令和构建，因此走旧工程完整路径。
- 混合改动取检查并集，不采用首个匹配文件的结果。未知目录/脚本/工作流、无差异、无效SHA、缺失历史和无法比较的PR：全部选中。
- 变更路径用Git完整本地差异、NUL分隔和`--no-renames`，不依赖截断文件清单；换行、空格和跨目录重命名不会伪造或漏掉路径。空白错误让scope失败。
- 总门禁先要求scope成功，所有布尔输出严格为`true`/`false`、suite合法；已选检查必须success，未选检查必须skipped。缺结果、取消、失败、意外跳过/意外执行、导出前置不满足一律拒绝。content已被Web覆盖时才明确允许跳过。

2026-11-01 首轮没有进一步按函数或素材名拆 Swarm 三组：源码/保存/绘制互相依赖，当前证据不足以安全减少组数。保留main安全复跑；使用cache、缩短模拟时间、跳过mutation baseline均不是本轮提速手段。

### 验证与取舍

定向测试使用真实临时Git仓库覆盖PR分叉、多提交push、删除、跨项目重命名、350个文档加运行文件、空格/换行文件名、无共同祖先、无效/零SHA、空diff和空白错误；结果合同覆盖选择/跳过/失败/取消/缺输出/非法值/导出前置。Actionlint固定v1.7.12及官方Linux归档SHA-256；原型测试jobs与前版逐字段相等。已有content/导出测试本地16项通过。

新增轻量scope测试/语法检查和总门禁有调度成本；CI自身改动会有意运行完整旧工程和三个原型，不能将这一全量耗时当作普通Swarm改动的耗时回退。普通Swarm改动不再带起无关旧Web/导出；普通文档不会为了触发而启动引擎。完整PR/main运行、实际结果与收口时间在#239回写，未运行的路径不得写成远端通过。

本轮只是CI维护；所有测试是开发者自动检查，无新增游戏体验证据。无采购；执行区间、CI等待、累计/剩余工时及账单保持分别记录，历史不可核算项不填零。200＋40小时不变，自动接续仍暂停。出现新输入依赖、工作流/测试新增或路径改名时，同时更新此合同及分类测试；回退本轮聚焦PR可恢复上一版入口。

<a id="server-protection"></a>
## 第三轮：公开仓库与服务器保护

2026-11-01，Alan明确授权将仓库改为public，以解除私有仓库分支保护的套餐限制；Codex实施，沿用#239 / M1 / GDD§12–13。GitHub于北京时间02:19将仓库可见性更新为public；已用匿名API读回HTTP 200、`private=false`，无需升级套餐。可见性变更后首次读取main保护返回`404 Branch not protected`，确认此前确实没有保护规则，随后配置并重新GET核验：

| 设置 | 实际读回 |
| --- | --- |
| 仓库 / 主分支 | `visibility=public` / `main.protected=true` |
| 合并入口 | 必须通过PR；审批人数0，适配单人维护；不要求代码所有者或另一账号审批 |
| 必需检查 | `CI required checks`，绑定`github-actions` App ID `15368`（从真实成功检查读取） |
| 集成基线 | `strict=true`，合并前分支必须包含最新main |
| 管理员 | `enforce_admins.enabled=true`；未配置PR绕过名单 |
| 强推 / 删除main | 均禁止 |
| 评审讨论 | 合并前必须解决讨论 |

这使CI结果由GitHub服务器用于拦截不合规合并；管理员仍有修改或删除保护设置的管理能力，不能宣称设置永远不可更改。未用违规推送破坏性试验验证拒绝路径。该记录的文档PR将按正常检查与合并流程验证可用路径，运行及合并证据回写#239。公开仓库仍需保留PR审查：任何有写权限的人修改workflow也可能改变检查含义，单独的检查名称不构成对源码内容的审查。

公开前只读复核覆盖远端2分支、6标签、283提交中的2318个文本blob版本（约58.8MB），以及243条Issue/PR正文和15条Issue评论；有限凭据正则未发现明显私钥、常见Token或带密码连接URL。作者邮箱和部分本机路径属于已存在的历史信息。二进制、历史Actions日志、构建artifact及Release附件未逐一内容审计，不能据此声称全面安全认证。公开范围包括源码、Git历史、Issue/PR、Actions历史及已有预发布附件；本次未新增游戏包或发布运行，未修改代码/素材许可。

设置依据：[GitHub仓库可见性说明](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/managing-repository-settings/setting-repository-visibility)、[分支保护API](https://docs.github.com/en/rest/branches/branch-protection#update-branch-protection)。将来若恢复private，必须先重新核验当时套餐是否支持保护；回退本页文档不会回退GitHub设置。无新增采购，产品G门禁、200＋40小时控制、累计/剩余未知项及自动化暂停状态保持。
