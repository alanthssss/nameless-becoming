# Windows 正式客户端的技能树

本地只读样本来自用户的 `shelldiver` Windows 安装。以下结果对应该二进制，旧录像覆盖是否同一发行构建未知。数据包 `data.win` 的 SHA-256 为 `4b4f08b6c85fd3852a08bccdbb0d6621cc614225f9f804df6afe79258e8c0506`，程序 `Shelldiver.exe` 为 `62599f01a4ce4b8946fcc38827e6364539e31abbed99b0828112e670b0c3925e`。没有执行或修改客户端。

## 实例和箭头

ROOM 块内的 `rm_skill_tree` 起始偏移为十六进制 0x9367C，实例表有 512 项。OBJT 父对象字段显示 241 个 `par_skill` 子对象、270 个 `par_skill_arrow` 子对象。另有一个 `o_skills_setup`。两个表列出了各实例的资源名、稳定实例 ID 和实例起始偏移。另一个房间 `rm_skill_tree_demo` 单独存放。241 个坐标各对应录像图谱中的一个位置，没有额外或重复位置。吊床中心在 (1536,1536)，网格宽高各 64。该中心为 R13C15，行序向下、列序向右。内部资源写明五个外端分别是 flask / scrap / mushroom / obsidian / crystal 的 final，游戏给玩家的标题都显示为 `???`。[房间格式](https://github.com/UnderminersTeam/UndertaleModTool/blob/master/UndertaleModLib/Models/UndertaleRoom.cs) · [对象父类字段](https://github.com/UnderminersTeam/UndertaleModTool/blob/master/UndertaleModLib/Models/UndertaleGameObject.cs)

270 个箭头实例包括 158 个 `o_skill_arrow_any` 和 112 个 `o_skill_arrow_max`。其中 269 个从一个技能实例落入另一个技能实例的碰撞框，另外一个实例 100488 从 R09C04 朝空格 R08C03。269 条有效箭头互不重复，由 264 条局部箭头和 5 条指向吊床的箭头组成；按放置对象为 157 个 any、112 个 max。与公开画面中辨出的 267 对几何线段相比，有 253 对端点一致、16 对只在客户端有效边中出现、14 对只在画面登记中出现。在直线经过中间图标或多条线重叠的地方，两种计数会产生差异。[全景原图](https://steamcommunity.com/sharedfiles/filedetails/?id=3621739580)

## 默认前置如何判断

- 原生程序保留了例程名 `gml_GlobalScript_scr_debug`。其在 0x140045770 得到 `arrow_max_equals_arrow_any`，在 0x1400459c2–0x1400459d8 将其设为布尔真。全程序对该变量索引的静态 RIP 引用仅两处，即这次初始化和房间 setup 中的读取。
- `gml_Object_o_skills_setup_Step_1` 在 0x14030470e–0x140304760 判定该变量。默认使用包含两类箭头的 `par_skill_arrow`，有效前置写入 `skills_needed_at_any_level`。0x140305665–0x140305677 同样检查该变量并直接跳过独立 `skills_needed_at_max_level` 的构造。运行时的 any 表示每个来源节点的等级阈值。
- 同一例程使用箭头原点作为来源测试点，目标测试点为 (x+(sprite_width−3)×cosθ, y−(sprite_width−3)×sinθ)，θ 是实例角度，两个箭头精灵的宽均为 12 像素。0x140304817–0x1403048bb 读取缩放后宽度并减3，后续读取 image_angle 并运算。0x140304fd2、0x140305097 两次对 `par_skill` 调用 `instance_position`。0x1403050d6–0x1403050f8 跳过任一端无命中的记录，0x1403052de 更新成功记录的 any 前置表。源、目标都是碰撞点查询。269 条有效记录的每端均只命中一个技能，剩余实例的原生目标点 (769.775,1217.775) 到最近技能中心约 62.25 像素，未命中任何框。[GameMaker 的精灵宽度](https://manual.gamemaker.io/lts/en/GameMaker_Language/GML_Reference/Asset_Management/Sprites/Sprite_Instance_Variables/sprite_width.htm) · [点位碰撞](https://manual.gamemaker.io/lts/en/GameMaker_Language/GML_Reference/Asset_Management/Instances/instance_position.htm)
- `par_skill` 对象元数据的基础掩模为 534。其原生 Create 的 0x1404948b4–0x1404948e4 将运行时 `mask_index` 设置为 SPRT 799。该精灵保存的边框从 (0,0) 至 (29,29)，原点 (10,11)，使用轴对齐矩形。ROOM 内全部 241 项技能未缩放、未旋转。对这 241 个实际矩形重算，得到 269 次双端各一命中和 1 次目标零命中。[掩模字段](https://github.com/UnderminersTeam/UndertaleModTool/blob/master/UndertaleModLib/Models/UndertaleSprite.cs)
- `gml_Script_is_skill_unlocked` 中，0x14009eb2b、0x14009eb82 取得当前技能的两组前置；0x14009ee55–0x14009eef1 逐个检查 any 表，任一前置 level ≤ 0 则返回 false。max 表的逻辑从 0x14009eff3 起，若启用则逐项检查 level ≥ level_max。两组都通过后在 0x14009f217–0x14009f22b 返回 true。默认构建仅填第一组。所以 25 个有两条入边的节点都要两项分别至少 1 档，中央吊床要五项分别至少 1 档。每个外端本身只有 1 档。
- 购买回调 `gml_Script_anon@11235@gml_Object_o_upgrade_area_Create_0` 在 0x14038b386 重算上述谓词，随后回写 `is_unlocked`，总购买档数在 0x14038f7cb–0x14038f7d2 自增。吊床的原生构造、行为回调和上述通用解锁函数中没有读取 Prestige 的数值或总档数。其行为回调更新 `hammock_available`、`has_revealed_hammock` 并安排演出和存档。此链条未发现 799/800 比较。另需满足 10Q 价格；经济上最早可获得金额/各币材的时间仍依赖实际路线和生产。原片 799/800 的到达顺序独立保留。[原片](https://www.youtube.com/watch?v=S7EaREatF4w&t=11467s)

## 文件核验

`windows-placed-nodes.csv` 有 241 个互异坐标及 241 个互异技能对象。`windows-prereqs.csv` 有 270 行，保留 1 个原生碰撞未命中的箭头。计算前置图时选择非空 `to_atlas_id`。269 条有向边构成无环图；唯一入度零节点为 R14C15 潜艇，214 格入度为 1，25 格为 2，1 格为 5。全图 86 格出度零。以潜艇深度 0 计，最长路径到吊床有 13 条边。无环图与同坐标截图分别独立核对，图形和默认逻辑均有明确版本范围。
