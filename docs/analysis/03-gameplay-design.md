# 03 · 玩法与设计 / Gameplay & Design

> 核心张力：发现花源 → 停留采集 → 危险与体力改变局面 → 决定继续、处理威胁或撤离 → 把资源带回蜂巢。
> Core tension: find nectar → linger to harvest → danger and stamina reshape the situation → continue, respond, or retreat → bring resources home.

当前源码候选与固定桌面 artifact / Current source candidate and fixed desktop artifact：`0.9.5-rc.2` / `de78f2c`，包含 PR #76 秋季双轨。

---

## 1. 核心循环 / Core Loop

```text
搜 Search → 采 Harvest → 险 Danger → 择 Decide → 撤 Extract
     ↑                                           ↓
下一节点 / 失律者 ← 蜂群成长 ← 归巢交付 ← 主巢站稳
```

关键情绪不是“击败所有敌人”，而是“已经带着收获，但远处还有一朵”。
The key emotion is not “defeat every enemy,” but “I already carry a harvest, yet another flower remains farther away.”

普通节点目标为 10～15，基础携带上限为 8，至少需要两次归巢。总时长只记录，不用固定 15～25 或 32～42 分钟判断通过。

## 2. 三个设计支柱 / Three Design Pillars

### 2.1 贪与撤 / Risk and Return

- 采蜜需要持续停留；携蜜只有实际卸入主巢才安全。
  Harvesting requires sustained presence; carried nectar becomes safe only after a real deposit at the main hive.
- 体力、普通敌害、当组机制和路线共同制造撤离压力。
  Stamina, field enemies, the active seasonal mechanic, and route shape extraction pressure.
- 失败、盗蜜和诱饵遵守花蜜守恒，避免永久软锁。
  Failure, theft, and decoys conserve nectar to prevent permanent soft locks.
- 若延长节点只增加重复采集，就不算增加内容。
  Extending a node through repetition alone does not count as more content.

### 2.2 蜂群而非孤胆英雄 / Colony, Not Lone Hero

- 归巢蜜进入公共储备；节点间成长改善飞行、采集或守卫倾向。
  Deposited nectar enters a shared reserve; between-node upgrades improve flight, gathering, or guarding.
- 蜂针不是普通攻击；震翼、诱饵、急转和调律承担对抗。
  The sting is not a regular attack; repel, decoy, evade, and tuning handle threats.
- 主蜂巢是唯一交付点；中继巢只能有限恢复。
  The main hive is the only delivery point; the relay hive only offers capped recovery.

### 2.3 可感知因果 / Perceptible Causality

- 会阻止结算的条件必须从开局常驻显示；
  Every blocking completion condition must remain visible from the start.
- 按键本身不能证明学会，真实世界结果才推进教学；
  A button press does not prove learning; only a real world result advances the tutorial.
- 节气、季节和机制首先通过实体、运动、状态变化与声音表达；
  Solar terms and mechanics are expressed first through entities, movement, state change, and sound.
- 自动测试和截图只证明实现，不能证明玩家读懂。
  Automation and screenshots prove implementation, not player comprehension.

## 3. 操作与老师傅教学 / Controls and Mentor Teaching

| 动作 / Action | 键盘 / Keyboard | 当前因果 / Current causal rule |
| --- | --- | --- |
| 飞行 / Fly | WASD / 方向键 | 持续移动自动振翅加速并额外耗体力 |
| 情境动作 / Context action | 空格 / 回车 | 近花采蜜、近敌惊退、静止寻迹或机制交互 |
| 诱饵 / Decoy | 松开后长按情境键 | 消耗 1 滴携蜜，结束后回到花田 |
| 急转 / Evade | 锁线后同方向 0.34 秒内连按两次 | 从锁定位置附近离开真实危险通道；敌害穿过旧位置且蜂在线外才成功 |
| 饮蜜 / Drink | E | 每节点最多 2 次；规则允许时 HUD 显示饮蜜按钮，鼠标／触摸松手确认；Boss 阶段不提供 |
| 归巢 / Return | Q | 自动飞回唯一主巢，站稳后卸蜜 |

老师傅统一采用“示范 → 模仿 → 无提示实践”：

- 示范冻结真实模拟，不修改蜜、体力、敌害或储备；
- 寻迹必须找到并采到被气味揭示的花；
- 惊退必须让敌害离开资源区；
- 急转不能用锁线前抢跑、空地双击或无敌帧硬穿代替；
- 首次失败安全重演，急转必须真实完成 `1/2 → 2/2`；
- 当前正常路线在老师傅连续两次急转练习后，没有固定的延迟同语法复测机会；未遇到机会不能记为迁移失败。若要验证约 3 分钟后的保持，先提供固定复测切片。

## 4. 24 节点推进 / 24-Node Progression

`godot/data/seasons.json` 有 24 个节点。春分、夏至、秋分是显式 Boss 节点；大雪后的循环终点进入冬至失律之熊。当前结构不是早期“四个压缩节令”，也不是已废止的“每季 3 阶段”。

普通节点按 `flower_set`／`mechanics` 分成四组，资产和行为不应只按 `season` 标题判断：

| 组 / Group | 节点 / Nodes | 完成条件 / Completion condition |
| --- | --- | --- |
| 春／授粉 | 冬至～惊蛰 | 归巢蜜 + 传粉 `2/2`；首节点另需完成老师傅要求 |
| 夏／袭扰 | 清明～芒种 | 归巢蜜 + 首次真实卸蜜已触发袭扰 + 全部袭扰者已被惊退 |
| 秋／留种 | 小暑～白露 | 归巢蜜 + 至少一次成熟留种，或花田已经被明确采尽 |
| 冬／暖点 | 寒露～大雪 | 归巢蜜 + 暖点 `3/3` |

最后一项已列条件完成时立即结算；不得保留不显示却会阻止推进的门禁。

## 5. 四组季节行为 / Seasonal Behavior Groups

### 5.1 春：开放花授粉 / Spring: Open-Flower Pollination

```text
同一可见花型的开放花药
→ 蜂身松散可见花粉
→ 同型开放柱头
→ 柱头受粉并进入结籽
```

授粉不使闭合花苞瞬间开放，不生成、恢复或搬运花蜜。给粉花和受粉花从开局可见，兼容性由同一花型表达，角色由器官形状与状态区分。

### 5.2 夏：实体袭扰 / Summer: Physical Raid

第一次真实卸蜜后，有翅劫掠者从边缘进入，移动到富蜜花，逐滴偷走真实花蜜；偷满后仍持赃停留，等待不会自动解决。玩家必须逐只惊退，被夺蜜才落回花田，航线清空后才能完成。

### 5.3 秋：野外留种 / Autumn: Field Seed Choice

花剩最后一滴时自动暂停当前采集，玩家必须松手。再次按下可采尽并显示破裂种荚；若停手并带其他蜜真实归巢，种核成熟、该滴不再可采并增加公共储备。段末的“公共储备／哺育幼虫”分配仍存在，但它是跨季附加层，不是秋季主行为。

### 5.4 冬：热源接力 / Winter: Warmth Relay

野外寒冷持续降低体温并渐进减速。玩家用携蜜按顺序点亮 3 个蜂蜡暖点；每个暖点既提供恢复区，也开放下一段远花路线。完整暖链才允许结算。

## 6. 普通敌害 / Field Threats

普通敌害包括追击蚊虫、偷蜜蚁、节奏冲刺的油葫芦、制造假花／歌声干扰的画眉和压平花区的熊。它们分别攻击体力、资源、节奏、信息和空间，不等同于四位 Boss。

震翼只惊退可惊退目标；资源敌害的被夺花蜜必须以可见路径回到花田。普通蚊虫当前仍以持续跟随为主，没有普遍复用教学／熊的锁线急转语法。

## 7. 四位失律者 / Four Unregulated Bosses

| Boss | 独立暴露条件 / Unique exposure | 成功读取 / Success read |
| --- | --- | --- |
| 蚊 / Mosquito | 完成真实吸取 / completes a real feed | 饱食短窗 |
| 油葫芦 / Field cricket | 跳跃后真实落地 / actually lands | 落点停顿短窗 |
| 画眉 / Thrush | 寻迹揭出真声 / sense reveals truth | 真身显露，假回声移除 |
| 熊 / Bear | 玩家闪过冲锋且熊撞暖息花 / evade, then bear hits warm bloom | 暖花碰撞与眩晕短窗 |

暴露后仍需在共鸣实体附近用震翼登记一次调律。共 3 次，每阶段加快、缩短窗口；画眉假回声随阶段增加。Boss 巢口照料最多 2 次。

## 8. 音乐与反馈 / Music and Feedback

- 8 个独立 WAV：春／夏／秋／冬各 1 首探索和 1 首 Boss 变奏；
- 普通节点按机制组路由探索曲，Boss 使用对应变奏，归巢柔化当前探索曲；
- 旧单一程序背景循环、统一低频 pad 和 Boss 全局降调已移除；
- 动作发动、攻击锁线和真正闪开使用不同 cue；
- 文件差异、循环与路由已由开发者自测，听感仍待盲听和实机 A/B。

## 9. 蜂巢成长与身份 / Hive Growth and Identity

当前三选一成长只改变能力：

| 倾向 / Track | 当前效果 / Current effect |
| --- | --- |
| 长翼 / Long wing | 速度与振翅效率 |
| 采蜜 / Forager | 采集间隔与单花产量；不增加携带上限 |
| 守卫 / Guard | 惊退范围与冷却 |

身份徽章、侦察前置链、变态发育职业成长和蜂巢建设仍是候选方向，未进入当前规格。

## 10. 当前验证边界 / Current Validation Boundary

- PR #63 的玩法／资产、PR #64 的匿名盲听工具和 PR #65 的 HUD／输入形成 `f57ea02c`，PR #69 形成历史 artifact `4b57d856`，PR #76 合并后形成当前固定 artifact `de78f2c`；PR #67、#68、#75 只增加证据工具／文档；
- Alan 的“可以”是方向门禁，不是逐项可用性通过；
- 9 组 Godot 回归、视觉快照和构建哈希属于开发者证据；
- 外部玩家证据为 0；
- 时长、难度、四季辨识、Boss 规则复述、音乐品质和重玩意愿都仍需真实记录。
