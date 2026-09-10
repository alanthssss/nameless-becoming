# 《一会儿巢里见》商业候选美术来源登记

状态：**发行资产审计工作表，不是授权完成证明**

更新日期：2026-08-28

主要范围：`godot/assets/art/commercial/` 下 21 张进入当前商业运行包的源 PNG；补充范围：`marketing/key-art/see-you-at-the-hive-key-art-base-v1.png` 与其仓库外 ImageGen 原始源。被否决的旧角色候选不在仓库或导出物中。Godot 自动生成的 `.import` 与 `.godot/imported/` 缓存不算独立源资产。

## 1. 证据边界

- `[实现事实]` 游戏内 `godot/data/credits_and_licenses.json` 把 **OpenAI ImageGen** 记录为“当前商业候选美术生成工具”；本目录 21 张 PNG 均被当前商业标题或 Journey 场景实际引用。`guyu_result_hero_v1.png`、`dashu_result_hero_v1.png`、`shuangjiang_result_hero_v1.png`、`dahan_result_hero_v1.png` 分别只在谷雨、大暑、霜降、大寒首次完成后的巢内 Campaign 结果阶段出现，不作为通用背景或商店图；它们是四张视觉结果候选，不证明四场独占大型事件玩法、商业“哇塞”质量或发行门禁已经完成。旧油葫芦与旧画眉候选因造型不符合当前美术约束，已从代码、仓库和导出物完全移除。
- `[实现事实]` 仓库内没有找到早期 13 张图逐文件对应的生成任务／job ID、完整提示、生成日期、输入参考图清单、模型／版本、原始下载回执、条款快照或分层可编辑源文件；2026-08-27 至 2026-08-28 新增的 8 张运行图已补本会话产物路径、哈希、提示语义、参考关系和机械后处理记录，但仍缺服务端任务回执、模型／版本和条款快照。
- `[开发者自测]` PNG 可被 Godot 导入，图集能按当前代码切片，最新共享工作树的 Godot 回归通过。它只证明文件可加载与状态逻辑可运行，不证明画风、生态准确性、商业授权或玩家可读性。
- `[专家启发式]` 没有逐图生成记录、参考来源审计、人工清稿链和可编辑源时，不能把工具信用或一张 PNG 等同为完整发行授权链。
- `[需 Alan 确认]` 21 张运行图目前都没有仓库内可追溯的最终美术批准记录，也没有“可用于商店／预告／付费投放”的批准记录。
- `[需独立玩家验证]` 运行尺寸下的角色、状态、主巢／小蜂房、路线与交互物可读性尚无有效独立样本。

本表只登记仓库可证明的来源类别和技术使用方式，不提供法律意见，也不推断未记录的生成过程。正式发行前必须由项目负责人完成当时适用条款、输入权利、第三方相似性与地区要求审计。

## 2. 状态代码

| 代码 | 含义 |
| --- | --- |
| `IG-CAND` | 依据项目信用表归类为 OpenAI ImageGen 商业候选位图；缺少逐图任务证据，所以不是“来源链完整” |
| `PP-UNK` | 仓库没有记录导出 PNG 前是否做过去背、修边、重绘、扩图、调色、缩放或拼版；表内只写代码可证明的运行时缩放／切片 |
| `AUTH-PENDING` | 有工具类别信用，但逐图任务、输入参考、条款快照、原始回执和第三方权利审计不全；未获发行授权清单签字 |
| `INT-DEV` | 已接入当前运行路径并由开发者回归加载；不是美术定稿 |
| `ALAN-PENDING` | Alan 最终画风／资产批准未记录 |
| `PLAYER-PENDING` | 独立玩家运行尺寸可读性未验证 |
| `MKT-NO` | 在来源、授权、Alan 审批和候选构建一致性完成前，不批准用于胶囊、商店图、预告或付费营销 |

## 3. 逐文件登记

所有哈希均为源 PNG 的 SHA-256。`运行处理` 记录的是 Godot 代码当前如何使用文件，不得反推为文件生成前的人工后处理。

| 文件／SHA-256 | 来源类别 | 运行用途 | 后处理／切片 | 授权状态 | 审批状态 |
| --- | --- | --- | --- | --- | --- |
| `autumn_world_ground_v1.png`<br>`bb521b73af3031d6ba99bae9da9cf4ccd0fca4a0019ea0ca39b4bfe6106ae73d` | `IG-CAND` | 秋季 2320 × 1220 大地图底图 | 源 PNG 为 2140 × 1180 RGB；`PP-UNK`；运行时整张缩放铺入秋季 world bounds，不切片；Godot 导入使用 `compress/mode=1`、`lossy_quality=0.85` 控制 Web 包体 | `AUTH-PENDING` | `INT-DEV` · `ALAN-PENDING` · `PLAYER-PENDING` · `MKT-NO` |
| `bear_helper_states_v1.png`<br>`647ddc7209311fdae979d44430c9d5f923d5f3d3c8d1f89b0defc8706cf16ad0` | `IG-CAND` | 冬季大熊待机／搬重木／完成后状态 | 768 × 256 RGBA；`PP-UNK`；运行时横向切为 3 个 256 × 256 帧并缩放显示 | `AUTH-PENDING` | `INT-DEV` · `ALAN-PENDING` · `PLAYER-PENDING` · `MKT-NO` |
| `dahan_result_hero_v1.png`<br>`9c7b11d88f3be38bedff9b3f89584b7bbae112f28ae3f4e1f768b9b6d224a58a` | `IG-CAND` | 大寒高潮首次完成后的一次全屏运行结果图；只在 `winter_dahan` 首通结果阶段出现 | 1672 × 941 RGB；ImageGen 原始产物原样复制，源与仓库文件字节哈希一致，无裁切、调色、扩图、重绘或缩放；Godot 以 cover 方式放入结果层，代码叠加冬季字幕和深色半透明衬底 | `AUTH-PENDING` | `INT-DEV` · `ALAN-PENDING` · `PLAYER-PENDING` · `MKT-NO` |
| `dashu_result_hero_v1.png`<br>`f9d1ecbbc330b359276c72ac8f7e64b83bdae5963103752592d76b51e3403395` | `IG-CAND` | 大暑高潮首次完成后的一次全屏运行结果图；只在 `summer_dashu` 首通结果阶段出现 | 1672 × 941 RGB；ImageGen 原始产物原样复制，源与仓库文件字节哈希一致，无裁切、调色、扩图、重绘或缩放；Godot 以 cover 方式放入结果层，代码叠加夏季字幕和深色半透明衬底 | `AUTH-PENDING` | `INT-DEV` · `ALAN-PENDING` · `PLAYER-PENDING` · `MKT-NO` |
| `flower_states_topdown_v1.png`<br>`854624a7c25a503d04ff6d2a100aac76bb8570c2a335fade6726e59ba8b1d2e5` | `IG-CAND` | 春野同形授粉花态 | 768 × 512 RGBA；`PP-UNK`；运行时按 3 × 2 切为 6 个 256 × 256 状态帧并按花型缩放 | `AUTH-PENDING` | `INT-DEV` · `ALAN-PENDING` · `PLAYER-PENDING` · `MKT-NO` |
| `guyu_result_hero_v1.png`<br>`f9c04eb93287488e4b7a96d9c45c1fef9cbd36a8ef79cde6cc441381e08aeaa9` | `IG-CAND` | 谷雨大型事件完成后的一次全屏运行结果图；只在 `spring_guyu` 返巢结果阶段出现 | 1672 × 941 RGB；ImageGen 原始产物原样复制，源与仓库文件字节哈希一致，无裁切、调色、扩图、重绘或缩放；Godot 以 cover 方式放入 1280 × 720 结果层，代码另叠精确字幕 | `AUTH-PENDING` | `INT-DEV` · `ALAN-PENDING` · `PLAYER-PENDING` · `MKT-NO` |
| `hive_threshold_interior_v1.png`<br>`fea212f5126c708cd0df53ba6b8cbc0d9b0deaa8344f0022238e0e38dd598239` | `IG-CAND` | 1280 × 720 主巢浅层门槛／接货场景背景 | 1280 × 720 RGB；`PP-UNK`；运行时整张绘制，不切片，叠加程序化工蜂与交接动作 | `AUTH-PENDING` | `INT-DEV` · `ALAN-PENDING` · `PLAYER-PENDING` · `MKT-NO` |
| `listening_seed_shell_states_v1.png`<br>`e9192701b38735e986fd087ab9bdcbacc8f012cb47f7809ea0eb9840bfe5cf49` | `IG-CAND` | 秋季三只独立听声种壳的左倾／右倾／坐稳状态 | 1086 × 362 RGBA；从 2172 × 724 ImageGen 原始产物用 Sharp Lanczos3 等比缩小 50%；运行时横向等分为 3 个 362 × 362 帧并绘入约 112 × 100；无鸟、羽毛、弦、木牌或身体连接 | `AUTH-PENDING` | `INT-DEV` · `ALAN-PENDING` · `PLAYER-PENDING` · `MKT-NO` |
| `main_hive_exterior_v1.png`<br>`473db3250be87cb1e8034b00bb9557a5da8368b4ca79af7103c31a7979f43d83` | `IG-CAND` | 商业标题、春野、花牌事故及后续季节的主蜂巢外观 | 1122 × 1402 RGBA；`PP-UNK`；不切片，按标题／地图构图缩放到不同矩形 | `AUTH-PENDING` | `INT-DEV` · `ALAN-PENDING` · `PLAYER-PENDING` · `MKT-NO` |
| `mentor_bee_topdown_v1.png`<br>`fc1aa879447f17ddc90800003a6349c947dd21c369a579828e85ba2858e35a6a` | `IG-CAND` | 标题老师傅、摘花瓣／示范／跟飞／交棒与巢内位置 | 256 × 256 RGBA；`PP-UNK`；单帧不切片，运行时缩放、旋转与位移 | `AUTH-PENDING` | `INT-DEV` · `ALAN-PENDING` · `PLAYER-PENDING` · `MKT-NO` |
| `mosquito_keeper_states_v1.png`<br>`42f23656d8b907cca1aaf83294720a8059df4586da4f9a2cfa1e7d670a3b9d48` | `IG-CAND` | 春季花牌事故中蚊庄主常态／失蜜后／背牌结尾 | 768 × 192 RGBA；`PP-UNK`；运行时横向切为 3 个 256 × 192 帧，再缩放为约 152 × 114 显示 | `AUTH-PENDING` | `INT-DEV` · `ALAN-PENDING` · `PLAYER-PENDING` · `MKT-NO` |
| `oil_cricket_repairer_states_v2.png`<br>`4a356e314f6fc6773ca7d9caa771178176040cbff8deeb26b39f3b3739e00fe1` | `IG-CAND` | 夏季油葫芦检查叶蜡工具卷／横雨护工具／修小蜂房三状态 | 1024 × 384 RGBA；从 2048 × 768 ImageGen 原始产物用 Sharp Lanczos3 等比缩小 50%；运行时横向等分为 3 帧并绘入约 244 × 244；无参考图 | `AUTH-PENDING` | `INT-DEV` · `ALAN-PENDING` · `PLAYER-PENDING` · `MKT-NO` |
| `player_bee_topdown_states_v1.png`<br>`e8bf3091a22bbcda709fe7340a2c28bba55d16d3d690c5486b969c56573d1905` | `IG-CAND` | 商业标题与当前 Journey 玩家蜜蜂的基础／加速／负重／急转帧 | 1024 × 256 RGBA；`PP-UNK`；运行时横向切为 4 个 256 × 256 帧，结合程序化旋转、拖影、带粉与负重反馈 | `AUTH-PENDING` | `INT-DEV` · `ALAN-PENDING` · `PLAYER-PENDING` · `MKT-NO` |
| `rest_hive_exterior_v1.png`<br>`bbe1ce86ce0ffd0d644a2ba2a964890d06ba5ead9a55d0405ea4a2093b9f9b21` | `IG-CAND` | 春野有限休息小蜂房与夏季受损／修好小蜂房 | 512 × 384 RGBA；`PP-UNK`；不切片，运行时缩放；损坏横梁和修复反馈由代码叠绘 | `AUTH-PENDING` | `INT-DEV` · `ALAN-PENDING` · `PLAYER-PENDING` · `MKT-NO` |
| `seasonal_work_props_v1.png`<br>`e4622fa17d5d8038c3d256cecac9de6ccc1f9a93e72e7140d932faea6fd0a27a` | `IG-CAND` | 叶棚、蜡灯续暖点、编枝挡风墙与种头记忆花园；用于冬季路径和最终交棒痕迹 | 1086 × 362 RGBA；从 2172 × 724 ImageGen 原始产物用 Sharp Lanczos3 等比缩小 50%；运行时用四个显式透明窗取完整轮廓并按用途缩放；无参考图 | `AUTH-PENDING` | `INT-DEV` · `ALAN-PENDING` · `PLAYER-PENDING` · `MKT-NO` |
| `shuangjiang_result_hero_v1.png`<br>`345d78dfb077ca07ed91f508d6d03ae2e24e9039cb0c861c3024253436982a4f` | `IG-CAND` | 霜降高潮首次完成后的一次全屏运行结果图；只在 `autumn_shuangjiang` 首通结果阶段出现 | 1672 × 941 RGB；ImageGen 原始产物原样复制，源与仓库文件字节哈希一致，无裁切、调色、扩图、重绘或缩放；Godot 以 cover 方式放入结果层，代码叠加秋季字幕和深色半透明衬底 | `AUTH-PENDING` | `INT-DEV` · `ALAN-PENDING` · `PLAYER-PENDING` · `MKT-NO` |
| `spring_world_ground_v1.png`<br>`910cfda8895d8c421ac39eed3b7f2791e8fc87c14b8f3e7ce206a1716726e544` | `IG-CAND` | 商业标题背景、春野、花牌事故与结局交棒底图 | 2140 × 1180 RGB；`PP-UNK`；大地图整张绘制，标题页以 cover 方式裁切显示，不切图集帧；Godot 导入使用 `compress/mode=1`、`lossy_quality=0.85` 控制 Web 包体 | `AUTH-PENDING` | `INT-DEV` · `ALAN-PENDING` · `PLAYER-PENDING` · `MKT-NO` |
| `summer_world_ground_v1.png`<br>`409cc61bec1fb188e48eadd94879f543da33804b3bd76939044e317dfe561ce3` | `IG-CAND` | 夏季 2240 × 1260 大地图底图 | 2140 × 1180 RGB；`PP-UNK`；运行时整张缩放铺入夏季 world bounds，不切片；Godot 导入使用 `compress/mode=1`、`lossy_quality=0.85` 控制 Web 包体 | `AUTH-PENDING` | `INT-DEV` · `ALAN-PENDING` · `PLAYER-PENDING` · `MKT-NO` |
| `thrush_neighbor_states_v3.png`<br>`218cbb86a0738e31ec020dfd9dfd6e91ffc7336366b25f1db1f778be95fbd618` | `IG-CAND` | 秋季画眉侧头听风／低头观察／自然鸣叫三状态；普通完整胸腹与自然多羽短尾扇，角色图不含种壳、蜜蜂、羽束或连接线 | 1086 × 362 RGBA；从 2172 × 724 最终纠正稿机械去除烘焙棋盘底、清理小连通噪点、去白边后用 Sharp Lanczos3 等比缩小 50%；运行时横向等分为 3 个 362 × 362 帧并绘入约 276 × 260 | `AUTH-PENDING` | `INT-DEV` · `ALAN-PENDING` · `PLAYER-PENDING` · `MKT-NO` |
| `winter_world_ground_v1.png`<br>`c42f3775b5652bdb7e6c8c90671584e5c83658ca5ad80db24233ee61d8de4cb7` | `IG-CAND` | 冬季 2220 × 1280 大地图底图 | 2140 × 1180 RGB；`PP-UNK`；运行时整张缩放铺入冬季 world bounds，不切片；Godot 导入使用 `compress/mode=1`、`lossy_quality=0.85` 控制 Web 包体 | `AUTH-PENDING` | `INT-DEV` · `ALAN-PENDING` · `PLAYER-PENDING` · `MKT-NO` |
| `worker_bee_topdown_v1.png`<br>`353737c9f79d6b3c8df65b7f823e29a795e9826a6ad7a5bba8e58683ed0b8c35` | `IG-CAND` | 主巢接货队、春野工蜂、花牌返巢、季节主巢与冬季修补蜂 | 256 × 256 RGBA；`PP-UNK`；单帧不切片，运行时缩放、往返位移与数量复制 | `AUTH-PENDING` | `INT-DEV` · `ALAN-PENDING` · `PLAYER-PENDING` · `MKT-NO` |

### 3.1 2026-08-27 至 2026-08-28 新运行图生成与后处理记录

- `oil_cricket_repairer_states_v2.png`：ImageGen 新图产物 `exec-69b6f111-50ca-4d7b-bb47-12d45231867d.png`，原始路径 `/Users/alanthssss/.codex/generated_images/01a03d3d-a397-7cc2-8011-76bfb6e0dc44/`；原始 2048 × 768 RGBA SHA-256 为 `16a5c709e2399866990d3cc3ee87cc2af63c94d6984d6ca05f93fd69160333ec`。无输入图；提示要求同一油葫芦的检查工具、横雨护工具、修蜂房三状态，禁止衣帽、人手、文字和神秘效果。仓库运行图只做 Sharp 0.34.5 Lanczos3 50% 等比缩小，输出 SHA-256 为 `4a356e314f6fc6773ca7d9caa771178176040cbff8deeb26b39f3b3739e00fe1`。
- `seasonal_work_props_v1.png`：ImageGen 新图产物 `exec-c58ed5fe-50bf-4590-adb4-2b404a888738.png`，同一生成目录；原始 2172 × 724 RGBA SHA-256 为 `9520a1f5b9bfe31c577ba6949016998dc19357a9e78689b03ec5702ecff9498c`。无输入图；提示要求叶棚、蜡灯、挡风墙、种头花园四个独立自然工作物，透明底，无文字和现代工具。仓库运行图只做同一 Sharp/Lanczos3 50% 等比缩小，输出 SHA-256 为 `e4622fa17d5d8038c3d256cecac9de6ccc1f9a93e72e7140d932faea6fd0a27a`。
- `listening_seed_shell_states_v1.png`：ImageGen 新图产物 `exec-e4010da4-404b-44b1-aaaa-fbead7385702.png`，同一生成目录；原始 2172 × 724 RGBA SHA-256 为 `445d0a54d9c25682e785d438c0e16af2ef62ecf1153301f3cedbc367ce00608d`。无输入图；提示要求三只天然空种荚的左倾、右倾、坐稳状态，明确禁止鸟、蜜蜂、羽毛、弦、乐器、木牌、身体连接、文字与符号。仓库运行图只做 Sharp 0.34.5/Lanczos3 50% 等比缩小，输出 SHA-256 为 `e9192701b38735e986fd087ab9bdcbacc8f012cb47f7809ea0eb9840bfe5cf49`。
- `thrush_neighbor_states_v3.png`：最终纠正稿 ImageGen 产物 `exec-61e54809-52c1-4d29-8114-9071a77a70bc.png`，同一生成目录；参考输入为前一轮普通鸟草稿 `exec-8b28ec81-5e77-4e21-ba8c-63f26a624ddf.png`，仅用于保持角色与三态布局。最终提示要求角色图只含普通画眉、完整胸腹、自然多羽短尾扇和侧头／低头／鸣叫三姿态，删除所有蜜蜂、种壳、羽束、弦、连接线、身体装置与符号。原始 2172 × 724 RGB SHA-256 为 `ae85580defa18ef10c0de311073c9595543dd43e2cddcc0398cdd44762444457`；因工具把透明棋盘烘焙进 RGB，先以 `alpha = clamp(max((247 - minRGB) × 25, (maxRGB - minRGB - 3) × 10), 0, 255)` 建立透明通道，再用 Sharp 0.34.5/Lanczos3 缩小 50%；缩小后把 `alpha ≤ 12` 置零、移除 alpha 连通像素少于 1000 的孤立背景噪点，最后按 `channel = clamp((channel - (1 - alpha) × 255) / alpha, 0, 255)` 去除白底污染。仓库输出 SHA-256 为 `218cbb86a0738e31ec020dfd9dfd6e91ffc7336366b25f1db1f778be95fbd618`。先前会被读成腹部插羽的草稿、夸张三尾羽稿和带脚边残线稿均未进入提交或导出。
- `guyu_result_hero_v1.png`：2026-08-28 使用 Codex 内置 OpenAI ImageGen **新图生成**模式，工具产物为 `/Users/alanthssss/.codex/generated_images/01a03d3d-a397-7cc2-8011-76bfb6e0dc44/exec-61629a28-e8c7-4d57-be25-dd3e9abff334.png`。五张项目内输入参考依次是：`spring_world_ground_v1.png`（环境与色板）、`player_bee_topdown_states_v1.png`（玩家蜂身份与身体结构）、`worker_bee_topdown_v1.png`（普通工蜂）、`mosquito_keeper_states_v1.png`（蚊庄主；花牌必须改为独立落地物）、`main_hive_exterior_v1.png`（主蜂巢轮廓与材质）。归档提示语义为：`Create a 16:9 2048×1152 in-game Grain Rain result hero. After rain, player bee banks through the confirmed route and leads a broad line of ordinary worker bees; friendly mosquito keeper uses natural legs to turn the final separate freestanding sign; sunlight and droplets form one subtle natural rainbow; petals settle, flowers respond, main hive in middle distance. Image1 environment/palette ref; Image2 player bee identity/anatomy; Image3 worker bee; Image4 mosquito keeper but sign must be separate; Image5 hive silhouette/material. Premium hand-painted 2D game illustration, unified flat sewn-fabric appliqué shapes + restrained gouache, clean silhouettes, dark brown/green outlines, wide three-quarter overhead, calm dark bottom strip for code caption, no text. Ordinary complete insect anatomy, natural attachments. Avoid body piercing/inserts, body instruments, attached boards/luggage, abdomen honey drip, three conspicuous feathers, torso holes, magic trails/halos, prophecy, binary conflict, weapons, horror, hands, hats, costumes, hex wallpaper, UI/debug.` 这是会话归档提示语义，不冒充服务端原始提示回执；工具未返回可登记的具体模型版本或服务端 generation ID。产物是 1672 × 941 RGB，原始源与仓库输出 SHA-256 均为 `f9c04eb93287488e4b7a96d9c45c1fef9cbd36a8ef79cde6cc441381e08aeaa9`；原图原样复制入仓库，没有任何生成后处理。

- `dashu_result_hero_v1.png`：ImageGen 编辑产物为同一生成目录下 `exec-074acdc0-063d-4514-99bb-f9f6f2142999.png`，输入参考为 `guyu_result_hero_v1.png`，仅用于保持项目构图、角色比例与克制的手绘质感。归档提示语义要求盛夏骤雨中玩家蜂与油葫芦固定叶棚、工蜂顺利穿过，画面正常、温暖而有行动感，禁止神秘主义、暴力、身体插入物和异常身体装置。产物为 1672 × 941 RGB；原始源与仓库输出 SHA-256 均为 `f9d1ecbbc330b359276c72ac8f7e64b83bdae5963103752592d76b51e3403395`，原图原样复制入仓库，没有生成后处理。

- `shuangjiang_result_hero_v1.png`：ImageGen 编辑产物为同一生成目录下 `exec-273aa4cb-1f7f-4e2e-ad08-6a0186459924.png`，输入参考为 `guyu_result_hero_v1.png`，仅用于统一结果图语言。归档提示语义要求初霜后的玩家蜂、工蜂与友善画眉共同整理独立种壳路标；画眉保持普通完整身体和自然羽毛，禁止脱落羽毛、腹部插羽、神秘主义、暴力与身体装置。产物为 1672 × 941 RGB；原始源与仓库输出 SHA-256 均为 `345d78dfb077ca07ed91f508d6d03ae2e24e9039cb0c861c3024253436982a4f`，原图原样复制入仓库，没有生成后处理。

- `dahan_result_hero_v1.png`：ImageGen 编辑产物为同一生成目录下 `exec-ca5c304f-4e5c-495f-bde1-00f3e2ac00e1.png`，输入参考为 `guyu_result_hero_v1.png`，仅用于统一结果图语言。归档提示语义要求大寒时玩家蜂、大熊和工蜂完成主巢休息站外的天然挡风结构，突出温暖交接和共同收工，禁止神秘主义、暴力、身体插入物与异常装置。产物为 1672 × 941 RGB；原始源与仓库输出 SHA-256 均为 `9c7b11d88f3be38bedff9b3f89584b7bbae112f28ae3f4e1f768b9b6d224a58a`，原图原样复制入仓库，没有生成后处理。

以上八图仍缺服务端 generation ID／原始提示回执、具体模型版本、当日条款快照、分层源和人工最终批准；本记录只提高可追溯性，不把候选升级为发行资产。

## 4. 概念主视觉候选登记

这张图不在 `godot/assets/art/commercial/`，也没有作为玩法场景运行；单独登记是为了防止其被当成真实截图或已批准的商店资产。

| 输出文件／SHA-256 | ImageGen 原始源 | 规格与用途 | 后处理 | 授权状态 | 审批状态 |
| --- | --- | --- | --- | --- | --- |
| `marketing/key-art/see-you-at-the-hive-key-art-base-v1.png`<br>`65f065e4caf5af8d4ca128faa37b82362c74bf1ad4c140b3dab9d9fae594ce65` | `/Users/alanthssss/.codex/generated_images/01a03d3d-a397-7cc2-8011-76bfb6e0dc44/exec-3f9ed813-9dd5-41c8-b85d-c5883219edb4.png`<br>同一 SHA-256；2026-08-27 ImageGen 新图生成模式 | `IG-CAND`；1672 × 941 RGB，约 16:9、无文字；以右侧主蜂巢为关系中心，在同一宽画面组合春夏秋冬环境、蜜蜂工作和蚊／油葫芦／画眉／熊邻居。只作为构图、色彩和品牌方向候选，不是 Godot 玩法截图 | 原始源与仓库输出字节哈希相同，能证明这一步是原样复制；没有输入／参考图片，生成后未修改底图字节；胶囊排字是另一个可重复生成步骤 | `AUTH-PENDING`；本节已补生成模式、任务产物路径、会话归档提示语义、无参考图声明和同一性哈希，但仍缺服务端原始提示回执、工具具体模型／版本和当日条款快照 | `INT-DEV`（营销目录候选） · `ALAN-PENDING` · `PLAYER-PENDING` · `MKT-NO`；`[需 Alan 确认]` 未获终稿、胶囊或投放批准 |

### 4.1 概念主视觉生成记录

- 生成工具：OpenAI ImageGen；模式：新图生成，不是编辑；日期：2026-08-27。
- 输入图片／参考图片：无。
- 归档生成提示（依据当前会话摘要与成图内容重建语义，不冒充服务端原始回执）：`Create a wide 16:9 commercial key-art illustration with no text and no UI. Show one warm, lively hive and a four-season flower-field neighborhood where small bees are doing different concrete chores: pollinating, observing routes, repairing, carrying, leaving seeds and keeping a winter path warm. Include a friendly mosquito gardener/keeper, an oil cricket repairer, an ordinary thrush neighbor listening to the breeze and a sleepy bear helping with heavy wood. Keep the scene normal, cute, warm and playful, with no mysticism, prophecy, evil-versus-good framing, weapons, human faces, hats or cheap costume shorthand. Leave useful negative space on the left for later exact typography; keep the hive and relationships readable on the right. Do not generate any words, logos or interface elements.`
- 工具产物：`exec-3f9ed813-9dd5-41c8-b85d-c5883219edb4.png`；原始路径与仓库文件 SHA-256 均为 `65f065e4caf5af8d4ca128faa37b82362c74bf1ad4c140b3dab9d9fae594ce65`。
- 后处理：概念底图原样复制进仓库，无裁切、调色、扩图或重绘；`store-candidates/` 由仓库内 Godot 生成器另行裁切与精确排字，并记录派生文件哈希。
- 尚缺：服务端原始提示与任务回执、ImageGen 具体模型／版本、生成当日适用条款快照、第三方相似性人工审计与 Alan 营销批准。因此本记录提高可追溯性，但不改变 `AUTH-PENDING`／`MKT-NO`。

`marketing/store-candidates/` 中的尺寸化胶囊、`marketing/brand/` 文字标与 `marketing/screenshots/` 开发者实机采集另有 [`../../marketing/README.md`](../../marketing/README.md) 说明。它们没有让本 key art 变成真实玩法画面，也没有改变本表的 `AUTH-PENDING`／`ALAN-PENDING`／`MKT-NO` 状态。

## 5. 发行前必须补齐

每张保留为正式资产的 PNG 必须逐项补齐，不能只在目录层写一句“由 AI 生成”：

1. 生成平台、模型／版本、任务或 generation ID、UTC／本地时间、账号／项目归属与原始文件哈希；
2. 完整提示、负面提示、种子或可用复现参数，以及所有输入／参考图及其权利来源；
3. 生成当日适用的服务条款／商业使用条款快照、项目内部使用授权决定与必要法律审查；
4. 从原始下载到当前 PNG 的每步处理：选择、去背、扩图、修边、重绘、调色、缩放、拼版、切片与导出工具／操作者；
5. 可再编辑源文件或明确的可复建流程；`.import` 和压缩纹理缓存不是源文件；
6. 第三方角色、商标、艺术家风格、照片或受保护作品的输入与相似性检查；
7. 1280 × 720、目标桌面分辨率、目标 Web 浏览器和商店截图尺寸的实机可读性／一致性截图；
8. Alan 对“游戏内候选”“正式发行”“营销使用”三个范围分别签字，独立玩家对关键状态可读性完成记录；
9. 通过后把 `AUTH-PENDING`、`ALAN-PENDING`、`PLAYER-PENDING`、`MKT-NO` 分别改为带日期、构建／资产哈希和审批人的完成状态。

在上述项目完成前，当前 21 张运行图只能称为**已接入的商业美术候选**；四张首通结果图也只是**视觉结果候选**，不等于四场大型事件玩法、商业“哇塞”质量或发行门禁已完成。概念主视觉只能称为**未批准的 ImageGen 构图候选**。被否决的旧角色图不留在仓库或导出物中。这些现有资产都不能称为最终商业美术、授权完备资产或已批准商店素材。


## 6. 2026-09-09 雨水独立场景完成资产

Alan 要求本段美术达到交付级，授权新资产制作和实际接入。下列四图使用内置 OpenAI ImageGen 的新图模式，无参考输入；原始输出字节原样复制到 `godot/playtest/rain_route/art/`，未裁切、去底、改色或缩放文件。叶棚、花丛和材料具有原始透明通道；运行时只做尺寸、色调及遮挡透明度处理。背景完整铺入视口；交互实体、角色、雨、粒子和 UI 均由引擎独立控制，不烘焙在背景里。

完整原始提示见 [generation-prompts.json](../../godot/playtest/rain_route/art/generation-prompts.json)，逐文件原始路径和哈希见 [manifest.json](../../godot/playtest/rain_route/art/manifest.json)。该记录保存可获得的工具产物身份，不冒充服务端 generation ID 或具体模型版本。

| 文件 | 用途 | 原始 SHA-256 |
| --- | --- | --- |
| `rain_garden_v1.png` | 雨后花田完整底图 | `b2c2d2a4d58090710e67b566f8ad208eceb1825550b3395589988b6ce8283a55` |
| `leaf_canopy_v1.png` | 可运动、可透视的真实叶棚 | `5d509e31958dbe8483b2cae0a227ecf319d7c62bd784d86df32fee96350d07e0` |
| `pollen_flowers_v1.png` | 可取粉的完整花丛 | `ac0d4b7f6b165e037921ce9cbfbcf6c902b23a7d9d2c1529bbe1f83467f31968` |
| `shelter_materials_v1.png` | 叶棚建成前的卷叶／树枝材料 | `4c6d94a4587d9067698e44bd5a05dab9a36e9ed93d5cc998947aec6d07b805f0` |

本段素材制作与引擎整合已完成，Codex 用实际运行画面检查；Alan 的整段审美评价和独立玩家可读性验证尚未取得。当前仅用于雨水独立入口，不自动加入正式 Campaign 的 21 图白名单、不宣称营销批准或完整商业授权审查已完成。既有玩家蜂、工蜂、主巢图及音乐来源仍按各自原登记。


### 2026-09-09 雨水线条地图

雨水场景现使用 `godot/playtest/rain_route/route_landscape.gd` 原生绘制的植物、地图、蜂巢、蜜蜂和雨水，配色与线条由代码定义；未新增外部素材或 ImageGen 资产。此前四张生成 PNG 保留来源记录，但此场景已不再加载。字体与音频继续复用项目已有资源；这是 Alan 授权尝试的单段风格，尚未获得最终审美验收或全项目替换决定。


### 2026-09-10 春季文案字体补字

沿用 Noto Sans CJK SC 与仓库 `godot/fonts/OFL-NotoSansCJK.txt` 许可，使用既有 `scripts/build_cjk_font_subset.py` 从全部运行文本重建 `godot/fonts/NotoSansCJKsc-ProjectSubset.otf`。源文件来自 Noto 官方仓库 `https://raw.githubusercontent.com/notofonts/noto-cjk/main/Sans/OTF/SimplifiedChinese/NotoSansCJKsc-Regular.otf`；下载的完整文件 SHA-256 为 `2c76254f6fc379fddfce0a7e84fb5385bb135d3e399294f6eeb6680d0365b74b`，以哈希标识本次字源而非把 main URL 当固定版本。该改动覆盖春季新增汉字，不引入新的生成式美术资源；原许可和字体用途不变。
