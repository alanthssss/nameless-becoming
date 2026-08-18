# 03 · 玩法与设计 / Gameplay & Design

> 核心张力：发现稀有花 → 停留采集 → 危险靠近、体力下降 → 决定继续贪、战斗或撤退 → 带着资源亲自飞回蜂巢
> Core tension: discover rare flowers → linger and harvest → danger closes in, stamina drops → decide to keep going, fight, or retreat → fly back to the hive with your resources

---

## 1. 核心游戏循环 / Core Loop

```
搜 Search ──► 采 Harvest ──► 险 Danger ──► 择 Decide ──► 撤 Extract
  │                                                          │
  └──────────── 蜂巢三选一成长 Hive upgrade ──► 下一节令 Next term ──┘
```

**中文 / CN**：关键情绪不是"击败所有敌人"，而是"已经收获很多，但远处还有一朵更好的花"。

**English / EN**: The key emotion is not "defeat all enemies" but "I've gathered a lot, yet there is still a better flower farther away."

---

## 2. 三大设计支柱 / Three Design Pillars

### 2.1 贪与撤 / Greed vs. Retreat

| 中文 / CN | English / EN |
|-----------|--------------|
| 稀有花位于更远或更危险的位置 | Rare flowers sit farther away or in more dangerous positions |
| 采蜜需要持续停留，不能碰触后瞬间获得 | Harvesting requires sustained presence; nectar is not instant |
| 携带资源只有回到蜂巢才安全 | Carried resources are only safe back at the hive |
| 体力、敌人和路线共同制造撤离压力 | Stamina, enemies, and routes together create extraction pressure |
| 失败损失本次携带资源，但不立即清空整局进度 | Failure loses the current carry, not the whole run |

**资源守恒 / Resource Conservation**：花蜜总量守恒——失败或蚊虫撞击把携蜜散回花田形成"返蜜花"；掠蜜蚁携带赃蜜，受惊后掉落。失败仍损失蜂巢呼吸与时间，但不能令关卡永久无解。

### 2.2 蜂群而非孤胆英雄 / The Colony, Not a Lone Hero

- 玩家带回的蜜进入蜂群公共储备 / Nectar enters the colony's public reserve
- 节令间只能从三种蜂群成长中选择一种 / One of three colony upgrades per term
- 成长体现分工：飞行、采集、守卫 / Upgrades embody division of labor: flight, gathering, guarding
- 结局评价蜂群是否熬过循环，而不只计算击杀数 / Ending judges whether the colony survived, not kill count

### 2.3 节气与阴阳消长 / Solar Terms & Yin-Yang Flux

- 四个 MVP 关卡分别代表春分、夏至、秋分、冬至
- 色彩、花量、敌人、能耗与音乐密度连续变化（非硬切主题皮肤）
- 每关使用同一套操作，不制作互不相关的小游戏
- 顶部保留二十四节气路线，为后续每季六关扩展

---

## 3. 操作与技能 / Controls & Skills

| 动作 / Action | 输入 / Input | 作用 / Effect | 成本与限制 / Cost & Limits |
|---------------|--------------|---------------|----------------------------|
| 飞行 / Fly | WASD / 方向键 | 移动；持续飞自动振翅加速 / Move; sustained flight auto-dashes | 持续缓慢消耗体力 / Slow stamina drain |
| 采蜜 / Harvest | 空格（近花）/ Space near flower | 从附近花朵逐滴采集 / Collect drop by drop | 停留、额外消耗体力 / Must linger |
| 震翼惊退 / Repel | 空格（近敌）/ Space near enemy | 推开敌人并使其持续远离 | 8 点体力 + 冷却；非麻痹非蜂针 |
| 触角寻迹 / Sense | 空格（静止）/ Space while still | 显示蜜量、警戒区、归巢方向、推荐花 | 3 秒持续，7 秒冷却 |
| 投蜜诱饵 / Decoy | 松开后长按空格 / Long-press after release | 投 1 滴蜜吸引蚊虫 5 秒 | 诱饵结束后蜜回归花田 |
| 急转闪避 / Evade | 双击方向 / Double-tap direction | 快速侧掠并短暂无伤 | 12 点体力，1.6 秒冷却 |
| 归巢 / Return | Q | 自动飞回蜂巢 / Auto-return to hive | 需亲自回巢蜜才入储备 |
| 暂停 / Pause | Esc | 暂停并显示操作 | — |

> 注：蜂针不是普通攻击。工蜂刺器是巢群防御器官并带不可逆的生命意味；若未来加入蜂针，只能用于明确、稀少且改变角色命运的抉择。

---

## 4. 四季大关与色彩体系 / Season Stages & Color System

### 4.1 关卡结构 / Stage Structure

**中文 / CN**：关卡结构为**四季大关 × 6 小关**（24 个节气节点），每大关内 6 个小关对应六个节气节点，色调沿该季阴阳方向逐阶渐变；**四正色（春分/夏至/秋分/冬至）为守关 Boss 节点**——正色即阴阳消长的关键转折，失律者盘踞之处。

**English / EN**: The stage structure is **4 season stages × 6 sub-stages** (24 solar-term nodes). Each stage's 6 sub-stages follow six solar terms with gradual hue shifts along the season's yin-yang direction; the **four zhengse nodes (Spring Equinox / Summer Solstice / Autumn Equinox / Winter Solstice) host the gate bosses** — the key turning points of yin-yang flux, where the Unregulated dwell.

| 大关 / Stage | 色系 / Palette | 6 小关 / 6 Sub-stages | 守关 Boss 节点 / Gate Boss |
|-------------|----------------|----------------------|---------------------------|
| 春 / Spring | 玄→青 | 冬至、小寒、大寒、立春、雨水、惊蛰 | 春分 · 正青 |
| 夏 / Summer | 青→朱 | 清明、谷雨、立夏、小满、芒种 | 夏至 · 正朱 |
| 秋 / Autumn | 朱→白 | 小暑、大暑、立秋、处暑、白露 | 秋分 · 正白 |
| 冬 / Winter | 白→玄 | 寒露、霜降、立冬、小雪、大雪 | 冬至 · 正玄 |

### 4.2 四正色 / The Four Zhengse

| 正色 / Zhengse | HEX | 角色 / Role |
|----------------|-----|-------------|
| 玄 Xuan | `#101420` | 背景深渊、未探索区域、失败归宿 |
| 青 Qing | `#008080` | 生机、蜂群、可采集花蜜提示 |
| 朱 Zhu | `#DC3C3C` | 危险、失律者、Boss、受击 |
| 白 Bai | `#F5F5F5` | 蜂巢、安全区、结算、澄澈的匮乏 |

**材质原则 / Material Principles**：低饱和低对比，叠加宣纸/岩彩纹理，避免纯色塑料感。完整色谱见 `docs/COLOR_SYSTEM.md`。

### 4.3 四季招牌机制 / Seasonal Signature Mechanics

**中文 / CN**：2026-08-18 全量实现四季差异化玩法（数据驱动，`seasons.json` mechanics 槽位 + `season_mechanics.gd` 调度层）：

**English / EN**: All four seasonal signature mechanics were fully implemented on 2026-08-18 (data-driven: `mechanics` slots in `seasons.json` + dispatcher `season_mechanics.gd`):

| 季 / Season | 机制 / Mechanic | 玩法 / Gameplay | 生态依据 / Ecology |
|------------|----------------|-----------------|-------------------|
| 春 / Spring | 授粉 Pollination | 花田是活的：久不采则休眠（蜜保留）；低蜜量触发授粉长新花 | 授粉是生态的一部分 |
| 夏 / Summer | 征召 Conscription | 巢口/花区告急交替，响应哪边都是贡献；不响应不惩罚 | 被需要的方式在变化 |
| 秋 / Autumn | 储备 Reserve | 季末分配：储备冬蜜 vs 哺育幼虫（两种集体投资） | 无私有财产；为来年投资 |
| 冬 / Winter | 抱团 Huddle | 体温系统、带蜜归巢耗储备恢复、储备≥5 解锁侦察+摇摆舞 | 共御严寒；风险留给老兵 |

---

## 5. 敌人系统 / Enemy System

### 普通敌人 / Regular Enemies

1. **蚊虫 / Mosquito**：在巢外警戒范围内追击，接触后损失体力和少量携蜜；无法越过蜂巢安全边界，震翼会令其实际向外惊退。
2. **掠蜜蚁 / Honey-Thief Ant**：移动较慢，优先追逐掉落或携带的蜜；被击退后会绕路再次靠近。

### 失律者 / The Unregulated (Boss)

- **主题 / Theme**：只索取、不流转 / Takes without giving back
- **玩法 / Gameplay**：玩家通过震翼打断吸取、引导其撞入花粉团并完成三次共振"调律"。胜利条件是调律或驱离，而非削空传统生命条。
- **落位 / Placement**：四正色节点（春分/夏至/秋分/冬至）各设守关 Boss；原型对应分配（蚊/油葫芦/画眉/熊）待定。
- **参数 / Parameters**：速度 78，碰撞范围 39，调律半径 82，需 3 次调律

---

## 6. 蜂巢成长与身份 / Hive Upgrades & Identity

每个节令结束后展示三选一，只在本局有效，同类可叠加两次：

| 选项 / Option | 符号 / Symbol | 效果 / Effect |
|---------------|--------------|---------------|
| 长翼蜂 Long-Winged | 疾 | 飞行速度 +10%，振翅耗能 -15% |
| 采蜜蜂 Forager | 蜜 | 采蜜间隔 -15%，每朵花额外保留 1 滴 |
| 守卫蜂 Guard | 守 | 惊退范围 +18%，震翼冷却 -15% |

**身份系统方向 / Identity Direction**（设计已定案，未实现）：三选一升级将**去职业化**为纯属性节点（不承担身份语义）；明确身份 = **成就徽章系统**——基于实际行为 + 完成程度事后授予，徽章集合构成身份画像，结算时组合生成一句身份描述。侦察 = 采集徽章达阶解锁。详见 `docs/PROJECT_LOG.md` 十三节。

---

## 7. 反馈与可读性 / Feedback & Readability

- 采蜜：花朵收缩、花粉粒子、音高递增
- 受击：短暂闪白、屏幕震动、蜜滴飞散
- 危险：敌人靠近时环境声与边缘暗角增强
- 归巢：携蜜飞向蜂房、储备数字滚动增加
- 节令变化：调色连续过渡，而非硬切主题皮肤
- 所有关键状态同时使用颜色与形状表达，不能只依赖色觉
