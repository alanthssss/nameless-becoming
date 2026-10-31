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

矩阵与依赖结果语义按 [GitHub matrix 文档](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/run-job-variations)和 [needs 上下文文档](https://docs.github.com/en/actions/reference/workflows-and-actions/contexts#needs-context)核对。分支保护 API 返回 403，不能声称远端强制保护已配置；保留旧检查名用于兼容现有检查消费者。

预估工作流约 3 分钟，须由本次远端完整 CI 实测确认。多两份初始化及汇总 job 会增加 runner 总秒数；这是反馈速度与执行资源的取舍，不声称降低账单。若排队抵消并行收益、耗时失衡或费用明显增加，按实际数据重新调整分组。回退本次 workflow 提交即可恢复串行。

## 验证与成本记录

本地验证覆盖 YAML/Actions 语法、原步骤内容等价与每项恰好执行一次、汇总门禁拒绝非成功状态、既有 CI 分类和差异格式；独立只读复核及 PR/main 的完整执行链接与实际时长回写 [#239](https://github.com/alanthssss/nameless-becoming/issues/239)。完整引擎测试以真实 CI 为准，不以静态检查替代。

调查 Issue 于 2026-11-01 01:25:38 开工，实施 Issue 于 01:26:06 开工（北京时间），此前定位阶段的主动时长覆盖不完整；收口时间与外部 CI 等待按 GitHub 事件记录。此维护只缩短工程反馈，不改变玩法、玩家证据或产品 G 门禁；新采购 0，Actions 实际费用、历史累计和可靠剩余工时未知，200＋40 小时控制不变。自动接续保持暂停。
