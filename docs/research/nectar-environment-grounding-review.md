# 《雨来之前》环境支撑与地貌审计

日期：2026-11-04。GDD [§8.1 结构可信](../design/swarm-flight-gdd.md#visual-production-rules) / [§13.9 Demo 深化](../design/swarm-flight-gdd.md#nectar-steam-demo) → M3 → 父 [#288](https://github.com/alanthssss/nameless-becoming/issues/288)，沿用 [#313 本作对照](https://github.com/alanthssss/nameless-becoming/issues/313)。负责人：Codex。本文是研究证据与改法，不是另一份执行队列。

**用户要求最终改善地图中“没由来的树枝撑着”的问题。本阶段仅完成审计与设计建议，未实施、未取得修后验证。按用户优先级先完成 Shelldiver 视频研究，归纳后落实本作改善；不能把保存本文视为完成改善，也不另建重复研究或实现 Issue。**

## 基线与证据边界

- 当前对照为已合并 Demo 0.24，PR #310，`ae411496ad0a280c9431d1aab5c1f98851ad6a12`。此前冻结 `378a230` 与最终 PR 头 `1efd4c5` 的 `prototypes/swarm-flight` 运行源码无变化。
- 下列截图来自本机 `/Users/alanthssss/LocalGames/nectar-demo-0.24.0/evidence/`，是开发者设定状态的原生运行证据，不是独立真人试玩。本次只看已有截图和源码，没有重新运行游戏、操作浏览器或验证新方案。
- 截图运行基线 `e210c327` 至合并版 `ae411496` 的 `nectar_harvest_view.gd`、`sample_landscape.gd`、`art_props.gd`、`art_sprites.gd` 无变化，可用于本次结构审计。截图仍在本机证据目录，未因此文自动上传。
- 以下“已见”限于图中可辨认的外观；代码解释用于定位生成方式。承重比例是视觉可信度判断，未做工程力学计算；静帧不能证明运动连接或碰撞行为正确。

| 已见证据 | 可确认的画面事实 | 不能据此宣称 |
| --- | --- | --- |
| [庭院蜜铺](</Users/alanthssss/LocalGames/nectar-demo-0.24.0/evidence/native-demo/02-hub-shop.png>) | 蜜铺与出发木台下方各有细绿茎，两侧木脚没有落在可见地面；成长树本体已有粗树干和根脚 | 所有植物都断开，或成长树本体必须重做 |
| [池岸入口](</Users/alanthssss/LocalGames/nectar-demo-0.24.0/evidence/native-regions/02-pond-entry.png>) | 仍见花园房屋远景，当前视野没有清楚的水面与岸线；多个木台复用细茎支撑 | 已检查整条池岸路线的所有镜头 |
| [紫花地](</Users/alanthssss/LocalGames/nectar-demo-0.24.0/evidence/native-ui/10-purple-meadow.png>) | 主要变化是紫花、雨线；花茎、木台支撑和避雨叶茎伸至画外，缺少可见生长地貌 | 雨叶的遮雨判定错位 |
| [避雨低路](</Users/alanthssss/LocalGames/nectar-demo-0.24.0/evidence/native-ui/11-sheltered-low-route.png>) | 避雨叶有弯曲主茎和下层叶，根部仍在画外；同类庭院远景重复出现 | 已观察全部运动状态或玩家读图理解 |

注意：`native-ui/02-first-garden.png` 实际也是庭院画面，不能因文件名将它标成池岸证据。

## 生成方式与问题定位

源码链接固定到合并基线，行号不随研究文档编辑变化。

| 位置 | 源码事实 | 审计判断 |
| --- | --- | --- |
| [`nectar_harvest_view.gd:77`](https://github.com/alanthssss/nameless-becoming/blob/ae411496ad0a280c9431d1aab5c1f98851ad6a12/prototypes/swarm-flight/nectar_harvest_view.gd#L77) | 三地都以 `region=0` 绘制背景；紫花地仅增加 0.07 透明度的紫色覆盖 | 缺少池岸/花坡自身地貌，区域名称没有充分转为画面事实 |
| [`nectar_harvest_view.gd:135`](https://github.com/alanthssss/nameless-becoming/blob/ae411496ad0a280c9431d1aab5c1f98851ad6a12/prototypes/swarm-flight/nectar_harvest_view.gd#L135) | `_stand()` 是宽 12 的茎加横叶，茎根终点固定 `y=835`；蜜铺与书台均调用 | 设施没有根据重量、尺寸和用途采用不同支撑；在 800 高画面中根端不可见 |
| [`nectar_harvest_view.gd:175`](https://github.com/alanthssss/nameless-becoming/blob/ae411496ad0a280c9431d1aab5c1f98851ad6a12/prototypes/swarm-flight/nectar_harvest_view.gd#L175) | `_stage()` 使用宽 13 的茎至 `y=835`；庭院、野外、近道台分别宽 300、230、170，复用 `nectar-dance-stage.png` | 单一细茎与木台脚的构图不匹配；注释写“rooted”不等于玩家看见了根和落地关系 |
| [`sample_landscape.gd:20`](https://github.com/alanthssss/nameless-becoming/blob/ae411496ad0a280c9431d1aab5c1f98851ad6a12/prototypes/swarm-flight/sample_landscape.gd#L20) | 底部只有装饰叶，随镜头以 0.65 倍位移；中景茎随世界镜头移动 | 装饰前景不能充当稳定连接的土层，遮住根端也没有解释生长来源 |
| [`art_props.gd:47`](https://github.com/alanthssss/nameless-becoming/blob/ae411496ad0a280c9431d1aab5c1f98851ad6a12/prototypes/swarm-flight/art_props.gd#L47) | `stalk()` 沿贝塞尔线铺统一宽度的植物纹理 | 当前实际使用的是通用绿茎，而非有主干、分叉和渐粗关系的木质承重枝 |

庭院、池岸、紫花地的 `.tscn` 均挂同一个视图脚本，仅 `area_key` 不同；目前不是三套独立地貌构图。优先在当前视图里修分区地形与设施连接，避免改共享素材后意外影响旧旅程。

## 保留已经正确的连接

- [`nectar_harvest_view.gd:219`](https://github.com/alanthssss/nameless-becoming/blob/ae411496ad0a280c9431d1aab5c1f98851ad6a12/prototypes/swarm-flight/nectar_harvest_view.gd#L219)：花的叶片从同一条贝塞尔茎的 0.42、0.70 位置取连接点；花头缩放围绕茎接点。问题重点是根部与地貌，不应重新制造花叶脱节。
- [`art_props.gd:77`](https://github.com/alanthssss/nameless-becoming/blob/ae411496ad0a280c9431d1aab5c1f98851ad6a12/prototypes/swarm-flight/art_props.gd#L77)：避雨叶已有主茎及同茎分枝，曾经的悬浮小叶已有修正。保留连接方法和 `leaf_canopy_geometry.gd` 共享遮雨轮廓，只补可信根冠/地面来源并复验运动。
- 庭院成长树已经提供可用的粗干和根脚；蜜铺整体美术也是已认可基线。优先改落地与固定方式，保留原有手绘资产、比例家族和店铺造型。

## 三地最小合理修法（尚未实施）

| 地区 | 推荐改法 | 保留与边界 |
| --- | --- | --- |
| 庭院 | 增加连续可见的土丘、粗根地坪；让蜜铺两侧脚落在同一表面。书台改为固定在成长树侧面的木架，出发舞台落在短树桩或粗根台上。移除设施下的通用细茎 | 保留蜜铺、成长树、舞台的主体素材与三点同屏；先保留现有交互锚点，不新增设施功能 |
| 池岸 | 增加明确岸坡、水面带与岸边根丛，花茎落到可追踪的岸土。普通出入口放在岸台；高处近道补出可见主干、渐粗侧枝和连接节点 | 高处位置可以保留，支撑必须在邻接镜头中有来源；水面先作为远/下层景观，不暗示尚未实现的潜水或水面碰撞 |
| 紫花地 | 增加起伏花坡与成丛根冠，使紫花来自同一片土壤；避雨叶独立长自可辨认根冠。高处木质节点由边缘主干的侧枝承托，减少重复的“茎上木台” | 保留紫花、降雨与避雨叶的既有交互；地貌差异不只靠换色，不必为区别区域新增玩法 |

实现建议先限于 `nectar_harvest_view.gd` 的分区地形、设施支撑与遮挡顺序。新地面和粗枝放在实际飞行走廊之外或明确的背景层；不能为了补支撑把一根看似可撞的粗枝穿进自由飞行路线，却不提供相符行为。是否需要改碰撞须由后续具体构图决定，不能声称“只改美术”就自动没有规则风险。避雨实体仍使用同一可见轮廓和天气判定。

## 实施后的验收（全部待执行）

1. **来源与连接：** 每个设施的脚、支点或固定点都连接到可追踪的土台、根、主干或悬点；不能只将断端藏到 HUD 后。检查近道高点与镜头边缘，允许画外来源，但至少在相邻视野能解释它从哪里生长或固定。
2. **地域差异：** 隐去地区文字，庭院仍能读出生活设施与树根地坪，池岸能读出岸水关系，紫花地能读出花坡与大叶植物。原手绘风格、光照和比例统一。
3. **运动与遮挡：** 在 1280×800 与 960×600 真实运行尺度检查左右移动、镜头边界、花朵摆动及采蜜受力；叶、茎、主枝接头不脱节，地形连接不因视差漂移，前景不挡落点和交互提示。
4. **可见规则一致：** 检查所有新增粗枝/地面是否误导碰撞；避雨叶上、下及边缘的雨线/消耗与共享遮雨轮廓一致；不因新的装饰地形暗示水面行动或新路线。
5. **回归与证据：** 完整走一遍庭院→池岸→紫花地→返程及近道，核对蜜铺、成长、转场仍可用。提交三地修前/修后同视角图和连续往返录像；如改动仅绘制，明确运行/存档规则未改且仍需上述原生复验。自动检查或漂亮静帧不能代替动态验收和用户产品判断。

## 本次结论与续接

结构问题已有截图与代码相互印证，推荐以“庭院根台、池岸岸水、紫花坡地”补足来源，而不是把所有细茎简单加粗。具体构图尚未验证，最终资产需求、遮挡和碰撞取舍仍待视频研究归纳后的实施检查点确定。

Alan 已要求最终改善；Codex 承担后续落实，当前按 Alan“先视频、Windows 稍后”的顺序继续研究。唯一权威状态留在 #288 / #313，本文不关闭产品目标、不扩大实现范围。本次只增加研究文档与索引，未提交、未合并、未交新包。新增采购和位图生成均为 0；200＋40 小时控制保持，主动/计费/累计/可靠剩余未知。审计前段未完整计时，本次归档阶段也不回填为精确工时。
