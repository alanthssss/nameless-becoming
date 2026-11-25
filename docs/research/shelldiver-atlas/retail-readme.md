# 正式版图鉴怎样查证

要查某一格，先在[通关坐标表](shelldiver-node-positions.csv)搜英文名或格号。R13C15 是中央吊床，向右列号增大，向下行号增大。罗马数字属于技能标题，例如 Bubble Damage I 和 V 占两格；面板内的 6/10 表示在当前格已买六档。Prestige 的 799/800 是另一层进度。五个外端各自列一格。同样写着问号的面板要用位置或时间区分。

## 时间索引和原始材料

- [Zhain Gaming 实机](https://www.youtube.com/watch?v=S7EaREatF4w)全长 3:16:07.57。按 480p、30 fps 的公开流索引读取了全部 2,816 个视频片段的首个关键帧，覆盖到片尾。用顶部 Prestige 标识的图像匹配筛出 607 帧，再连同其前后相邻片段逐一解码。894 个片段合计 1:02:30.37、112,511 帧。每 8 帧检查一次顶栏和详情框，相隔约 0.27 秒；按画面变化去掉一部分雷同裁切，保留 7,124 张候选详情。这些数字计的是检索覆盖，一次悬停可以产生很多张。若某次短暂开树跨不过首帧，且相邻段也无命中，仍可能漏掉。[全片时间与每段取样数量](retail-video-index.csv)
- OCR 用来找候选词。归档的阶段号和报价再与图中罗马数字、币材图标、面板数、等级、MAX 状态核对。读出价格只说明当时展示该价；确认实付还需要前后余额、等级或状态。图上出现 5.00B 之类的简写时，原文单位一并保留或换成对应的整数。一个档次的总值还会包含其他节点已经给过的加成。
- 历史 S11 索引另有 30 个有效窗口的 792 张原图，本次将 115 张与具名面板绑定，其中 98 张未进入上次精选。这批的引用时码按窗口估算，带文件名和 SHA-256。[76 项详细读图](verified-panels.json) · [首批 56 条报价](sampled-quotes.csv)
- [IcyShades 的 Game Pass 实机](https://www.youtube.com/watch?v=zBjgcqtnva0)来自另一位玩家。五个窗口按两秒抽出 113 张，补强新档报价、炼金、终局倍率与付款后场景动作。片中有跳剪，平台版本也可能不同。[逐窗口记录](second-run.md)
- [Seesaw 全景](https://steamcommunity.com/sharedfiles/filedetails/?id=3621739580)、[简中全景](https://steamcommunity.com/sharedfiles/filedetails/?id=3607432223)、[ENMA 中央详情](https://steamcommunity.com/sharedfiles/filedetails/?id=3650782668)的存档和语言可分辨。两张全景互补 HUD 遮挡，格位核对再使用原片中的选中图标和周边地标。线表的每一对端点只描述画面轨迹。[几何与命名复核](topology-notes.md)

本机保存公开玩家视频的取证样本供复读。新批目录为 `~/LocalGames/research/shelldiver/skill-tree-20261124/`，其中 `rap/NNNN.jpg` 是全画幅关键帧，`dense/dNNNN-FFF.jpg` 是该片段某帧的详情裁切，`dense/sNNNN.json` 给出各裁切的原片秒数。另有 `guide-frames/`、`guide-ending/` 与 `panoramas/`。旧图按 `verified-panels.json` 内的相对路径在相邻 `S11/` 目录查找。仓库提供重绘图、数值、时间和出处，原作者保留原始画面。

正式版工作表另有[241 格的逐格代表面板](retail-all-nodes.csv)、[378 条观察](retail-panel-observations.csv)及[合并 JSON](retail-all-nodes.json)。时间/哈希分别对应 `rap/` 关键帧、`dense/` 详情局部、`single/` 定向完整帧、旧版 S11 样本或标明的官方图。[格位配准证据](shelldiver-position-name-evidence.csv) 使用 `dense-full/` 内的整幅画面，和同时刻详情裁切有不同的图像哈希。304 条有价记录覆盖 277 个可唯一判定的位置与档位，所有金额与该位置 Windows 价表相容。录像提供行为及显示证明，完整 800 项逐档价格由 Windows 发行物单独给出。[正式版逐档表](windows-rank-prices.csv)
