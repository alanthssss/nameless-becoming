# 雨来之前 · 连续07→08→09风路样板 0.15.0

0.15.0接入09风路代表片段：高落点向下转，普通低路抬升穿窗；两阵反向风之间需要自己收势、换层、再次起冲。使用既有定向花节点，不宣称实现真曲线风花。07／08关卡函数和全局物理保持，08抵达后进入09；长旅程入关提示和HUD不再显示季节文字。

试玩包：`outputs/swarm-flight/2026-10-26-wind-choice/试玩包/`。`开始试玩.command`连续07→08→09，`单独试玩第09关.command`使用独立入口与进度，均支持退出后继续。新r8目录与r7隔离，旧0.14.1包和进度原样保留，不将已完成08的旧档强行解释为09中途。此09是机制关系样板，不是正式09篇幅或完整20关。

制作采用主任务整合、限定文件内容子任务、独立只读审查；状态和后续色痕／蜂舞／角色任务只在[唯一Now](../../docs/design/solar-term-campaign-production-spec.md#autonomous-gdd-workflow)。验证范围与可追溯证据见[SF-R47](../../docs/design/swarm-flight-game-20261020.md#wind-choice-slice-20261026)及本批回执；技术／原生检查不代替玩家判断。

## 0.14.1记录

0.14.1将攻击前感叹号改为更大的手绘金黄提示、移至花瓣上方，攻击节奏不变。最新版：`outputs/swarm-flight/2026-10-26-flower-warning/试玩包/开始试玩.command`。首次启动在新包没有进度时复制0.14.0对应r7进度，保留原文件；也可从标题重玩。连续07→08、独立08和原16关均保留。详细记录见[SF-R41](../../docs/design/swarm-flight-game-20261020.md#flower-warning-20261026)。

## 0.14.0记录


最新版目录：`outputs/swarm-flight/2026-10-26-seven-action-development/试玩包/`，双击`开始试玩.command`从07进入08与结尾；`单独试玩第8关.command`和`原版16关.command`各自保存。Apple Silicon／Intel Mac，无需Godot。

本轮仅重编07两个现有庭院：先用上升风的冲势开叶门，后段从低廊再次借风开门、接露抬升。下方保留普通飞行绕行；总宽、主路起冲次数、速度和体力规则不变，08内容保持。用独立r7存档，旧包和进度可继续在原包玩，不迁移旧图坐标。

方向键／WASD飞行；按住空格蓄力、松开冲刺；Esc暂停保存，正常退出保存。继续先暂停，再按Enter／Esc出发。R回最近叶亭，M静音。完整自测与局限见[SF-R40](../../docs/design/swarm-flight-game-20261020.md#seven-action-development-20261026)；新组合的整体发展感待连续试玩，不代表长关时长或整作完成。

## 0.10.0历史记录

本次默认打开新07「花篱另一边」→新08「喷嚏前后」连续样板。07五段30个空间单元、15处恢复点；08五段26个单元、13处恢复点。新前六关尚未扩容实现，原16关通过`--classic-journey`保留。

macOS独立包：`outputs/swarm-flight/2026-10-23-long-journey-sample/试玩包/`；双击其中`开始试玩.command`或`BeforeTheRain.app`。`原版16关.command`启动原玩法。包里的`存档/`和`日志/`随包存放在Synology Drive，不覆盖旧包。源码运行可用`play.command`；用`--progress-file=/绝对路径/文件.json`选择存档。

Esc暂停并保存当前位置，关闭窗口也会先保存；标题选择继续时先暂停，Enter／Esc明确继续。蓄力状态保留后，按住空格接住，再松开冲刺。叶亭经过即记住安全恢复点，不必停满；R和失败回此点。写盘失败保留窗口，修复存档目录写入权限后可重试。旧版安全点存档与新版原地挂起文件相互独立，不能把旧索引强套入新地图。

开发输入测得两关直路7分52秒、备用路8分57秒，均无恢复；并非真人首次游玩时长，也没有证明原设计的两关约40分钟目标。内容复用与长程节奏需连续体验评估。完整实现、测试、未知项与商业边界见[SF-R33](../../docs/design/swarm-flight-game-20261020.md#long-journey-sample-20261023)。

## 原版0.9.3记录


0.9.3补齐冬季13–16的共用植物适配：木质茎干、覆雪叶亭与小叶、霜色风花、枝拱、冬季树屋、底部前景，以及护雨叶、角色头花、结尾奖励花和花铃植物附属。统一按关卡region选择，15天气theme2不会漏掉。沿用已认可的画风；模型、路线、碰撞、存档、音乐和奖励数量保持。见[SF-R31](../../docs/design/swarm-flight-game-20261020.md#winter-plant-family-20261023)。

本包包含0.9.1的05／10／13补给修正和旧进度兼容，以及0.9.2的15温室台面修正。晨露14颗，历史收集保留；不把有趣飞行与基本体力补给拆成假选择。

## 打开0.9.3

Synology Drive交付目录为`outputs/swarm-flight/2026-10-23-winter-plants/`，主包「雨来之前·冬季修正.app」。「继续完整旅程.command」优先复制0.9.2包旁进度，其次旧补给／美术完整／普通旅程档，保留原档；新进度和日志在本包旁。「单独查看16关.command」从16关开始，另有「单独查看13关.command」可检查冬季风花，两者使用独立进度。

技术证据、源码与打包画面、未完成检查和成本覆盖统一见同目录`build-receipt.json`。此为已授权集中修订内的必要纠正，不代表整作或PVZ完成度已验收。旧包保留对照。使用上述独立入口可将进度留在Synology Drive；直接开发入口仍使用默认旅程档。

## 四季与素材安排

| 区域 | 关卡 | 主要判断与表现 |
|---|---|---|
| 春 · 归家 | 01–04 | 飞行、解救、连续借风、追雨与第一次归家；春季菜圃背景、同族茎干与救援荚 |
| 夏 · 花篱外 | 05–08 | 花篱两路、喷泉时机与绕行；复用已认可的夏季庭院，补齐喷嚏花和喷口 |
| 秋 · 旧果园 | 09–12 | 箱角转向、穿帘与绕箱；秋季果园背景、木箱材质与干叶帘 |
| 冬 · 暖廊与老树 | 13–16 | 持续气流、台下避风、熟悉元素组合与尾声；冬季暖廊背景、台面与风源 |

新增素材为terrain、flora、landmarks、weather四家族和保持自然比例的独立树屋，新增春／秋／冬背景并复用夏景；已有蜂体、风花、叶冠和花篱继续共用。冬季变体完整提示与来源见`art/winter-provenance.json`；原有完整提示与生成来源见`art/rollout-provenance.json`，05原资产见`art/provenance.json`；适用关卡、共有／区域／专属分类、状态映射和最终哈希见`asset-manifest.json`。方向箭头、文字、危险范围、护雨计时和粒子由引擎按模型绘制。

普通终点演出2.4秒，章节边界4.5秒。穿过花铃叶拱／树洞立即完成并保存，演出不耗体力或计时；Enter可提前继续，Esc或失焦暂停。04归家后进入夏天，16才是整作结尾。小满和画眉在安全落脚点回应，同伴不跟飞、不新增碰撞或损耗。05来向对白读取真实路线记录，无证据旧档使用中性回应。

## 操作与规则

- 方向键／WASD飞行；空格按住约0.4秒，光环亮起后松开冲刺。长按不会额外增加距离。
- 冲刺可救伙伴、借风、冲开干叶帘、击散雨滴和安抚喷嚏花；实心茎干、花篱、果箱和台面需要绕行。
- 宽叶亭依次保存并以每秒24体力恢复；不强制等满，两条分路共用落脚点。
- 飞行每秒耗2体力，冲刺耗20；晨露最多恢复12，救援最多恢复40，风花最多恢复8。界面报告实际恢复值。
- 固定的晨露是补给；向下移动的雨滴和喷嚏水珠会伤体力。雨关有后方雨幕与独立露天预算，叶下暂停；普通关显示旅程计时。
- 喷泉有停喷、提前0.8秒预告、喷发三个状态；喷发时普通接触损失12体力，可等空档、冲刺穿过或从另一侧绕行。
- 局部气流持续推动普通飞行、松键和蓄力；方向键可逆风修正，冲刺保持方向。离开风区即停止受风，叶亭和起飞／恢复后等待输入时保持安稳。实心地形挡落雨，但不提供叶亭的回血、存档或追雨暂停。
- 护雨叶保护5秒，可挡雨、喷泉与喷嚏，仍耗飞行／冲刺体力和露天时间，不能穿实心墙。
- R回到最近落脚点；Esc暂停；M开关声音。暂停同时冻结游戏与演出。

## 进度与兼容边界

0.9.1写出version 6 / content_revision 9，兼容读取revision 8。05删除第一颗晨露，保留剩余拾取物状态；已拿到的旧奖励单独保留为历史计数，结尾显示总获得数，不再用新布局的分母否定历史收集。关卡、叶亭、伙伴、道具与完成状态保留。迁移夹具以及用户旧档的只读副本均在独立路径验证，原档不用于写入测试。更早v1与chapter v4不迁移。

关中继续回到已存宽叶亭，已穿过终点则进入下一关；16关完成后可重看结尾。选章会重开当前入口的旅程，收集不锁出口，结束统计只反映这趟旅程。春天救援分布仍为4／2／1／1，后续角色只是邻居，伙伴总数仍8只。

历史0.8.0曾使用实际0.7.1打包PCK生成05起点／叶亭／抵达的10份档案，逐份恢复后以模型普通输入继续到下一叶或终点，未读写个人存档；这不是0.9.0已重复验证的声明。

## 开发验证与证据

```sh
godot --headless --path prototypes/swarm-flight --editor --import --quit
godot --headless --path prototypes/swarm-flight --script res://verify.gd
godot --path prototypes/swarm-flight --script res://ui_verify.gd -- --swarm-qa
godot --headless --path prototypes/swarm-flight --script res://audio_verify.gd
```

模型检查覆盖16关路线、安全存档点、资源与终点边界；UI检查通过Viewport分发实际方向键和空格，检查连续旅程、衔接、结尾、暂停及继续。`route_driver.gd`知道路线答案，既不是独立玩家证据，也不能用其时间推算真人首通。`--swarm-qa`隔离真实进度；截图路径由`SWARM_FLOW_CAPTURE_DIR`指定。

历史0.9.0已通过1577项模型检查、538项原生界面检查和24项明确状态夹具检查；两趟16关普通输入路线贯通、保存继续通过。导出PCK挂载到同版本编辑器运行同一原生输入套件，也通过538项；独立release应用完成启动截图。140项气流基线、2类旧缺陷反证、8项反证工具测试、11项交付检查器测试及音频PCM检查通过。导出PCK的QA结束有ObjectDB实例泄漏警告，独立release启动没有该警告。四区画面、缩放、状态提示与碰撞可读性已作开发者复核，不能代替玩家评价。1280×800逻辑画面保比例缩放，Compatibility渲染；素材与状态绘制由`world_view.gd`、`art_sprites.gd`、`art_props.gd`和`sample_landscape.gd`协作。音乐仍由`sound.gd`原创合成。

历史0.8.1有1577项模型检查、538项完整原生UI检查、最终05定向89项；这些仅说明当时版本的开发者自检，不证明0.9.0通过或整作美术获验收。Windows／手柄／Steam／独立玩家验证、自然首通2～3小时目标与可靠整作预测仍待完成。

### 回归与交付边界

```sh
python3 -B -m unittest discover -s tests -p 'test_*regressions.py'
python3 -B -m unittest discover -s tests -p test_delivery_gate.py
python3 scripts/check_swarm_regressions.py --godot /absolute/path/to/godot
python3 tools/check_delivery.py --contract prototypes/swarm-flight/delivery-contract.json \
  --receipt /absolute/path/delivery-receipt.json --evidence-root /absolute/path/evidence \
  --revision FULL_FROZEN_COMMIT --expect candidate
```

旧缺陷反证在隔离副本运行；交付工具核对同包证据，不因测试数量或文件存在就代签产品验收。当前制作沿用SF-R23、SF-R25与唯一Now：200＋40小时控制量、一次集中修订和既定日期不重置；本次明确授权解除的是仅05样板的推广限制。


### 0.15.1独立晴雨／花蜡窗样板

`Godot --path prototypes/swarm-flight res://weather_window.tscn`进入《叶下的光》。与07→08→09目录、r8保存相互隔离；Mac包的“叶下的光.command”为此入口。先认棚上／棚下，再经过有预告的局部雨；真实棚顶挡雨，雨后退出危险。两处窗景与一处倒影使用原24色值，透光位置随两个地标提交，无季节文字、全屏染色或收集门槛。

`Godot --headless --path prototypes/swarm-flight --script res://weather_window_verify.gd`验证规则；原生／无头UI入口为`weather_window_ui_verify.gd`，需设置隔离`SWARM_WEATHER_QA_DIR`并传`--progress-file=/absolute/qa/save.json`。开发夹具与自然体验分开记录，详见SF-R48及本批回执。旧三关玩法不变，新增样板不是正式10关完整篇幅。
