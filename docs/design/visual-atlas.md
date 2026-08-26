# 画面总览与审阅图集

状态：**2026-08-26 建立。** 本页是查看项目全部主要画面证据的单一入口。每张图必须先看标签：**实机截图、历史实机、生成式概念、宣传构图**不能互相代替。

## 1. 先回答：现在是不是总在一屏

是。当前战役只有一张固定 `Main` 花田，玩家在同一个 `1280×720` 视口里的世界矩形活动；没有 `Camera2D` 跟随。24 个节气节点是在同一屏重新布置花、敌害和机制对象，不是 24 张地图。

未来方向是局部镜头跟随 + M／Tab 发现地图；完整结构、数量与生态层见 [`world-season-ecology-framework.md`](world-season-ecology-framework.md)。这项未来方向尚未实现。

## 2. 当前仓库实机画面

![仓库实机截图总览](screenshots/engine-screen-archive-contact-sheet-2026-08-26.png)

这张拼图汇总 `docs/design/screenshots/` 在 2026-08-26 之前的 9 张引擎截图／拼图，其中包含多个历史版本；它方便快速扫视，不代表九张都是当前构建同一提交的状态。

| 画面 | 证据性质 | 用途 |
| --- | --- | --- |
| [春季当前方向审阅基线](screenshots/spring-art-direction-baseline-2026-08-26.png) | 实机开发者快照 | 检查当前固定单屏、旧 HUD、蜂巢、玩家、花和授粉状态同屏 |
| [四组季节玩法](screenshots/seasonal-gameplay-v2.png) | 实机开发者拼图 | 对比同一固定空间里的授粉、袭扰、留种、暖点与 8 种花纹理 |
| [交付／老师傅／中继巢](screenshots/delivery-hud-mentor-relay-v1.png) | 实机开发者拼图 | 检查交蜜、老师傅活动与立夏中继巢 |
| [授粉条件与生态反馈](screenshots/pollination-conditions-ecology-v1.png) | 实机开发者截图 | 检查给粉、携粉、同型柱头、成功／拒绝状态 |
| [急转教学](screenshots/evade-causal-teaching-v1.png) | 实机开发者截图 | 检查锁线和因果示范 |
| [急转成功](screenshots/evade-causal-success-v1.png) | 实机开发者截图 | 检查旧位置、侧移和敌害穿越 |
| [完成条件卡](screenshots/completion-card-no-overlap-v1.png) | 实机开发者截图 | 检查文字不重叠；不代表信息密度已通过 |
| [春季正式资产接入切片](screenshots/spring-launch-slice-v1.png) | 历史实机快照 | 追溯蜂族城邦资产接线 |
| [冬季布艺历史切片](screenshots/textile-art-slice-winter-v1.png) | 历史实机快照 | 已降级画风的实现记录，不是当前方向 |

当前缺口：标题、暂停、成长、完整胜负页、独立 B01 和未来地图页尚未进入这张一页式实机总览，因此不能称为“完整产品全部画面”。

## 3. 当前待审结构与宣传方向

### 五张地图／十三个主场景

![五张地图与四季场景总览](concepts/five-map-season-world-atlas-v1.png)

标签：**生成式世界结构实验。** 表达中央主蜂巢 + 四向野外、每区三组生态场景和四季连续变化；不是关卡文件、正式比例或实机截图。

### 主角与总海报

![满载仍回望最后一朵花](concepts/key-art-one-more-flower-v1.png)

标签：**生成式宣传构图实验。** 表达主角—家—远花、活的蜂巢共同体、四位失律者和二十四格蜂巢环；不是最终角色立绘、Steam 胶囊或实机镜头。

### 明亮局部视口

![明亮生态动画与蜂巢地标](concepts/spring-bright-hive-checkpoint-direction-v1.png)

标签：**生成式局部视口实验。** 只验证明亮低噪地表、清楚路径、蜂巢地标和最小角落 UI；它仍可能偏通用，必须与上面的蜂群共同体和角色 IP 规则合并。

## 4. 后续每轮必须补齐的画面矩阵

| 组 | 最少画面 | 当前状态 |
| --- | ---: | --- |
| 世界鸟瞰 | 1 | 有概念，未有灰盒／实机 |
| 主场景 | 13 | 只有结构概念，未逐场景生产 |
| 节气状态条 | 24 | 有数据，无统一视觉状态条 |
| 季节机制关键帧 | 4 × 3 拍 | 有部分实机，尚未按准备／发生／结果统一 |
| Boss | 4 × 3 态 | 有实机行为，无常态／失律／调律后三联立绘 |
| 主角 | 6 态 | 有概念主姿态，无统一设定表 |
| 主流程 UI | 标题、地图、暂停、成长、胜／负 | 当前未形成完整图集 |
| 宣传图 | 总海报 + 四季 + 蜂巢群像 | 有总海报概念，其余未制作 |

## 5. 重新捕捉当前 Main

`godot/tests/art_snapshot.gd` 从真实 `main.tscn` 捕捉画面，不能在 `--headless` 下运行。示例：

```bash
"/Applications/Godot 2.app/Contents/MacOS/Godot" \
  --path /Users/alanthssss/Documents/ChatGPT/nameless-becoming/godot \
  --script res://tests/art_snapshot.gd -- \
  --stage=19 \
  --state=winter_route \
  --output=/tmp/winter-route.png
```

当前显式状态包括 `completion_card`、`drink_honey`、`pollination_ecology`、`dual_carry_sense`、`transfer`、`mismatch`、`mentor_sortie`、`mentor_defense`、`mentor_evade`、`relay_hive`、`tutorial_attack`、`tutorial_success`、`summer_raid`、`autumn_seed`、`winter_route` 和 `boss_window`，另有默认 `tutorial`。它只捕捉 Main，不能冒充全产品自动截图。

## 6. 历史／否决方向

以下图片只用于记住失败原因，默认折叠，避免审阅时误把旧方案当候选：

<details>
<summary>展开历史概念图列表</summary>

- [通用手绘花田 v1](concepts/spring-commercial-gameplay-target-v1.png)：太普通，缺少项目身份；
- [蜂族城邦 v2](concepts/spring-commercial-gameplay-target-v2.png)：保留“活的共同体”，不继承过密细节；
- [蜂蜡蚀刻 A](concepts/spring-style-candidate-a-wax-etching-v1.png)、[矿物套色 B](concepts/spring-style-candidate-b-mineral-print-v1.png)、[微缩舞台 C](concepts/spring-style-candidate-c-wax-miniature-v1.png)：三路表现试验；
- [v3 推荐](concepts/spring-style-recommendation-mineral-wax-v2.png)：已因不够干净明亮、线噪与构图不符被否决；
- [冬季剪纸](concepts/winter-cut-paper-direction-v1.png)、[毛毡 v1](concepts/winter-felt-diorama-direction-v1.png)、[毛毡 v2](concepts/winter-felt-diorama-direction-v2.png)、[布艺贴花](concepts/winter-textile-applique-direction-v1.png)：历史材质路线，均非当前推荐。

</details>
