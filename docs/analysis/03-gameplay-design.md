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
| 飞行 / Fly | WASD / 方向键 / 鼠标目标 | 在花田移动 / Move across the field | 持续缓慢消耗体力 / Slow stamina drain |
| 采蜜 / Harvest | I / 按住空格 | 从附近花朵逐滴采集 / Collect drop by drop | 停留、额外消耗体力 / Must linger |
| 振翅 / Dash | O / Shift | 快速位移、脱离包围 / Rapid reposition | 高体力消耗 / High stamina cost |
| 震翼惊退 / Repel | J | 推开敌人并使其持续远离 | 8 点体力 + 冷却；非麻痹非蜂针 |
| 触角寻迹 / Sense | U / E | 显示蜜量、警戒区、归巢方向、推荐花 | 3 秒持续，7 秒冷却 |
| 急转闪避 / Evade | K | 快速侧掠并短暂无伤 | 12 点体力，1.6 秒冷却 |
| 投蜜诱饵 / Decoy | L | 投 1 滴蜜吸引蚊虫 5 秒 | 诱饵结束后蜜回归花田 |
| 暂停 / Pause | Esc | 暂停并显示操作 | — |

> 注：蜂针不是普通攻击。工蜂刺器是巢群防御器官并带不可逆的生命意味；若未来加入蜂针，只能用于明确、稀少且改变角色命运的抉择。

---

## 4. 四季节令 / The Four Solar Terms

| 节令 / Term | 阴阳 / Yin:Yang | 花量 / Flowers | 敌人 / Enemies | 目标蜜量 / Goal | 体力消耗 / Drain | 定位 / Role |
|-------------|-----------------|----------------|----------------|-----------------|------------------|-------------|
| 春分 Spring Equinox | 50:50 | 8 | 1 | 7 | 1.45 | 学习与建立信心 / Learn & build confidence |
| 夏至 Summer Solstice | 15:85 | 8 | 4 | 11 | 1.80 | 高收益与高威胁 / High reward, high threat |
| 秋分 Autumn Equinox | 50:50 | 7 | 7 | 14 | 2.00 | 匮乏与规划 / Scarcity & planning |
| 冬至 Winter Solstice | 85:15 | 6 | 6 | 9 | 2.25 | 生存极限 / Survival limit |

**配色曲线 / Color Curve**：春季青绿米黄 → 夏季高明度金橙 → 秋季赭石 → 冬季蓝灰；蜂蜜金贯穿全年，阴影逐季加深，再从冬至孕育下一轮暖色。四季使用不同五声音阶和弦底色，保持低音量，不遮蔽提示音。

---

## 5. 敌人系统 / Enemy System

### 普通敌人 / Regular Enemies

1. **蚊虫 / Mosquito**：在巢外警戒范围内追击，接触后损失体力和少量携蜜；无法越过蜂巢安全边界，震翼会令其实际向外惊退。
2. **掠蜜蚁 / Honey-Thief Ant**：移动较慢，优先追逐掉落或携带的蜜；被击退后会绕路再次靠近。

### 失律之蚊 / The Unregulated Mosquito (Boss)

- **主题 / Theme**：只索取、不流转 / Takes without giving back
- **玩法 / Gameplay**：玩家通过震翼打断吸取、引导其撞入花粉团并完成三次共振"调律"。胜利条件是调律或驱离，而非削空传统生命条。
- **参数 / Parameters**：速度 78，碰撞范围 39，调律半径 82，需 3 次调律

---

## 6. 蜂巢成长 / Hive Upgrades

每个节令结束后展示三选一，只在本局有效，同类可叠加两次：

| 选项 / Option | 符号 / Symbol | 效果 / Effect |
|---------------|--------------|---------------|
| 长翼蜂 Long-Winged | 疾 | 飞行速度 +10%，振翅耗能 -15% |
| 采蜜蜂 Forager | 蜜 | 采蜜间隔 -15%，每朵花额外保留 1 滴 |
| 守卫蜂 Guard | 守 | 惊退范围 +18%，震翼冷却 -15% |

---

## 7. 反馈与可读性 / Feedback & Readability

- 采蜜：花朵收缩、花粉粒子、音高递增
- 受击：短暂闪白、屏幕震动、蜜滴飞散
- 危险：敌人靠近时环境声与边缘暗角增强
- 归巢：携蜜飞向蜂房、储备数字滚动增加
- 节令变化：调色连续过渡，而非硬切主题皮肤
- 所有关键状态同时使用颜色与形状表达，不能只依赖色觉
