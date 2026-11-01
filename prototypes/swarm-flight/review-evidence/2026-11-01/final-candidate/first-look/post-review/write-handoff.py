import json,hashlib
from pathlib import Path
from datetime import datetime,timezone
base=Path('/private/tmp/pond-first-look-9611660/post-review'); repo=Path('/private/tmp/nameless-pond-mvp-candidate')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
now=lambda:datetime.now(timezone.utc).isoformat()
def source(path,lines,scope):
 p=repo/path
 return {'path':path,'lines':lines,'sha256':sha(p),'scope':scope}
inputs=[source('docs/design/swarm-flight-gdd.md','241;681–830','06原行与13.5/13.6'),source('prototypes/swarm-flight/game_model.gd','196–307;404;481;595–656','基础飞行/破帘/遮蔽/恢复'),source('prototypes/swarm-flight/long_journey_model.gd','1–69','精确挂起与检查点骨架'),source('prototypes/swarm-flight/spring_journey_content.gd','1–70','当前三段空间与内容编排'),source('prototypes/swarm-flight/spring_journey_model.gd','195–348;384–515','分享、两次开口、邻居整理与事实恢复'),source('prototypes/swarm-flight/spring_journey_view.gd','60–78;123–177;270','棚/支撑/叶结显示入口'),source('prototypes/swarm-flight/leaf_canopy_geometry.gd','109–160','叶棚轮廓/接触/拦雨接口'),source('prototypes/swarm-flight/chapter_data.gd','57','build_source内容构造接口')]
r={
 'created_at_utc':now(),'revision':'9611660f0acfabc53ddf92c5215b37d7942cfc89',
 'author':'first_look AI explorer, post-seal independent content handoff author; not root implementation author',
 'scope':'只读差异交接；未制作06，未扩产，未改工程/封存探索材料，未操作游戏窗口。此报告接触设计后撰写，不能充当无攻略首次探索。',
 'first_source_design_access_started_at_utc':'2026-11-01T05:57:22.554745+00:00',
 'calibration_sealed_first':{'path':'calibration.json','sha256':sha(base/'calibration.json')},
 'gdd_06_original':{'line':241,'title':'06 午后长廊：我打开的空间会怎样被使用？','content':'低压棚内外互见，小满顶棚，玩家可开叶结或绕过；同伴实际通过新口。远处油葫芦留下蜡补丁后跳走，蚁队沿真实叶柄搬枝','result':'建立帮助改变空间，也为10角色铺垫；没有运输背包或必须等NPC走完','numbering_boundary':'06为现有GDD历史内容标签；24关内容/ID映射仍未完成，不能当作新24关的已落实第6关。'},
 'main_player_judgment_delta':[
 {'from_observed_pond':'出发段判断飞到哪里认识前路，停花形成可分享来源；雨段判断离开遮蔽时的路线与保护；归程先抓盘点窗口，后换层从背侧开口。','to_06':'在低压、棚内外可互见的空间，判断要不要停下来帮开叶结，以及所开空间能否被他人使用。','consequence_required':'帮助后改变的是实际通行空间与同伴行动；绕过仍能正常前行，不惩罚、不要求返回补做。'},
 {'from_observed_pond':'我破结后路能走，邻居随后整理牌；分享后同伴去蓝花。','to_06':'同伴经过由玩家刚打开的新口成为直接因果证据。角色顶棚—释放支撑—让位与通口状态需要在玩家可看见的同一局部空间关联。','consequence_required':'不是对白说感谢、状态旗标变化或同伴沿原路飞走；也不把已有听者直飞源花路径改名当作通过新口。'},
 {'from_observed_pond':'雨中存在资源/暴露压力，庄主松绳提供时机窗口。','to_06':'保留舒展和自主停留，主要信息来自支撑、连接与通行关系，不复刻雨压或再来两扇同题门。','consequence_required':'不用多加等待、伤害、运输背包或强制护送来证明新内容。'}],
 'reusable_capabilities':[
 {'capability':'方向飞行、蓄力释放、冲刺破叶结、墙体接触与滑动','source':'prototypes/swarm-flight/game_model.gd:196,241,293','reuse':'保持当前输入与基本动作；以现有 curtain/broken 和 gate_ready 承接一次开结。','boundary':'06的叶结与展开棚必须有自身可见支撑逻辑，不能直接复制05的盘点锁条件。新尺寸/方位仍需碰撞复验。'},
 {'capability':'源内容编排与稳定场景构造','source':'prototypes/swarm-flight/chapter_data.gd:57; spring_journey_content.gd:9,14','reuse':'用现有 encounter/build_source 描述低压路线、叶棚与合流；复用自然飞行出口和可绕选择。','boundary':'当前Spring仅3段，含池岸坐标/同源花/牌架专用数据，不是现成06模板；参考路线数组是已知解法验证辅助，不是独立体验证据。'},
 {'capability':'实体叶棚轮廓、拦雨与身体接触共用几何','source':'prototypes/swarm-flight/leaf_canopy_geometry.gd:109,119,132,147,160; spring_journey_view.gd:60; art_props.gd:77','reuse':'静态叶棚的源形、支撑画法、可见边界与接触查询可作为新棚的起点。','boundary':'当前静态棚证据不覆盖动态展开、转轴/支点变化或小满托棚姿态。若06不下雨也要核实身体通路与可见空间一致，不强加天气任务。'},
 {'capability':'动作到位驱动场景结果','source':'prototypes/swarm-flight/spring_journey_model.gd:438–462','reuse':'庄主先到位再查看/提牌/安置的因果组织可指导小满支撑/放手/让位状态。','boundary':'现有 TIDY_APPROACH/TIDY_CARRY 与牌的位置均属05，不能把路径或结果计时直接套用；小满与同伴必须重新走真实06空间。'},
 {'capability':'可选行为与事实/检查点/精确挂起分离','source':'prototypes/swarm-flight/long_journey_model.gd:1–69; spring_journey_model.gd:479–515,631; spring_journey_model.gd:283–348','reuse':'区分已提交帮助事实、活动角色状态、玩家离开/回落脚点和暂停精确恢复；沿用校验思路。','boundary':'本段的front_open/passage_open及source身份不可改名后默认等价；summer_canopy_help与未来18回响尚未接成24关映射。'},
 {'capability':'既有蜂体与可选同伴回应表现','source':'prototypes/swarm-flight/art_sprites.gd:14; world_view.gd:330–345','reuse':'蜂体风格与依据真实来向回应的现有表达可供小满基础形象参考。','boundary':'只查到既有蜂体/来向回应，未验证顶棚、放手、让位、跟随通过新口动作。'}],
 'scene_exclusive_work':[
 {'work':'低压棚内外可互见的几何与视线','deliverable':'行动前可看见小满支撑、卷叶结、绕行通路与新口将通向的地方；普通飞行和帮助后路径都有效。','risk':'复制静态雨棚布局可能只留下坐标分叉，展开动作也可能遮挡玩家。'},
 {'work':'小满顶棚与可选开结导致空间变化','deliverable':'叶结、叶柄/支点、展开姿态、碰撞、支撑解除同时吻合；小满由支撑到放手/让位，玩家持续可动。','risk':'动态几何和已有静态棚验证边界不同；优先验证角色动作版因果，不预先扩成自由物理系统。'},
 {'work':'同伴使用刚打开的口','deliverable':'帮助分支里同伴在口开放之后实际飞过；绕过分支里正常主路和后续会合仍成立。','risk':'现有两听者赴花是直线move_toward，不能证明可避障、穿新口或群体路由。'},
 {'work':'油葫芦蜡补丁与跳走、蚁队沿叶柄搬枝','deliverable':'在远处可辨认的蜡补丁/真落点/角色离开与蚁队接触路径；不用等待它们表演完。','risk':'本段原生实玩没有这些新行为；外观、动作、连接与后续10角色铺垫均未由池岸证据证明。'},
 {'work':'帮助事实、未帮助分支与后续18回响','deliverable':'summer_canopy_help有实际来源和恢复规则；未帮仍有完整主路。跨关ID/迁移在正式映射后设计。','risk':'24关映射缺失，不能现在许诺现成跨关复用。'}],
 'acceptance_counterexamples':[
 '开叶结只换贴图/对白，空间碰撞不变，或者同伴仍飞原路径：中心判断未成立。',
 '同伴在开口前穿过闭合棚，或完成旗标置位却没有实际通过：因果与几何不符。',
 '同伴只在屏外瞬移到终点；玩家看不到开口与使用的关系：不能以状态标签验收。',
 '绕行后主路封锁、角色责备或要求返回帮忙，或必须站住等NPC走完整段：违背可选与低压约定。',
 '棚展开时茎叶断接、支点悬空、外观已经开而碰撞仍闭，或暂停恢复把角色夹进棚：基本缺陷。',
 '把05盘点等待/背侧开门复制两次，换角色名字却没有他人使用空间的后果：差异交接失败。',
 '蚁队悬空搬枝、油葫芦跳跃没有真实落点或蜡补丁凭空出现：独占角色/生态表现未成立。',
 '帮助提交后R或冷续把口关回去，未提交状态却获得帮助回响，或重复触发多次角色结果：保存事实错误。'],
 'suggested_bounded_validation_checkpoint':{'owner':'root维护原权威GDD/Milestone/Issue；未来06内容作者执行，需原生产决策授权','acceptance':'先以一个真实小场景验证“可绕或开结→棚改变→同伴通过”；同时记录未帮助分支及活动展开/提交后恢复。通过后再补远处角色与环境组合，不能以文档批准扩产。','new_task_queue_created':False},
 'unproven':['06未实现/未运行；所有新增角色/展开棚/同伴通口的可读性、趣味和节奏均待实际证据','本文不审核全工程是否已有某个零散旧原型；只把已核读当前接口视为复用候选，不把搜索未命中视为不存在','07–09、四位大型角色、持续风、平台/手柄、全作保存迁移不由池岸复核代验','真人接受、陌生玩家时长与偏好仍未知','24关内容/ID映射仍未完成；P5/G5与整作交付条件未因此满足'],
 'cost_and_scope':{'measured_scope':'独立AI实际池岸探索+本次只读文档/源码核对；没有06制作计时样本','real_06_cost':'unknown','cumulative_cost':'unknown','reliable_remaining_cost':'unknown','budget_control':'保留200＋40小时及历史集中修订/原检查点；不推断尚有可用预算。','forecast_method':'不把一段墙钟时间乘24；新角色动作、动态几何、真实NPC路线、恢复和返工分别需后续实际取样。','cash':'未采购；本任务未产生新的已知外部现金费用','production_authorization':'仅交接，不批准06制作、24关扩产或整体完成。'},
 'source_evidence':inputs,
 'blind_observation_reference':{'path':'../continuation/review.json','sha256':sha(base.parent/'continuation/review.json'),'unchanged':True,'note':'先前实际观察只用于指出已体验能力；未用源码回填原始预测。'}
}
(base/'next-content-handoff.json').write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n')
driver='prototypes/swarm-flight/review-evidence/2026-11-01/final-candidate/source-expiry-supplement/driver.gd.txt'; trace=driver.replace('driver.gd.txt','trace.json');data=json.loads((repo/trace).read_text()); assertions=data['assertions']
a={
 'created_at_utc':now(),'revision':data['revision'],'reviewer':'first_look AI explorer after blind report seal','mode':'read_only_source_trace_audit','rerun_performed':False,'verdict':'supports_declared_narrow_model_scope_with_limits',
 'declared_claim':data['kind'],
 'counts':{'declared_checks':data['checks'],'declared_failures':data['failures'],'actual_assertions':len(assertions),'actual_false_assertions':sum(x['pass'] is False for x in assertions),'preparation_checks':87,'closure_cases':4,'closure_checks_per_case':12,'early_departure_checks':5,'interpretation':'140是包含完整已知路线准备/JSON检查在内的断言数，不是140个关闭场景或140次玩家测试。'},
 'what_driver_actually_does':[
 '继承spring_journey_verify.gd；通过fly/frames调用model.step准备03采食、04低路、05两次开口与落脾，关间通过load_stage切换。属于模型普通方向/空格意图的已知路线，不是OS输入、原生无提示连续试玩。',
 '将有效来源/开路/落脾基线save_payload后，为armed、before_commit、after_commit、foraging分别在fresh模型里restore_payload。',
 '先按/松空格并推进不同帧数，检查message_revision提交前为0、提交后为1；foraging一例另检查全部听者确实foraging。',
 '直接调用m.invalidate_source()作为受控内容事件，立即检查观察无效与share_state idle；600模型帧后检查全部听者waiting；再按/松空格180帧，检查仍idle且message_revision未新提交。',
 '每例关闭后和回到waiting后均做JSON序列化/恢复、payload相等以及下一输入比较。另单独从开放来源基线在提交前移动离脾，断言无提交、分享取消、听者waiting。'],
 'coverage':[{'case':'armed','driver_lines':'20–38','supported':'准备按住但未松开的分享，在内容关闭事件后取消，无法形成新报告，JSON往返可接受。'}, {'case':'before_commit','driver_lines':'23–38','supported':'松开后推进25帧，message_revision仍0；受控关闭取消分享，不产生新报告。'}, {'case':'after_commit','driver_lines':'24–38','supported':'推进90帧后已有一次提交；关闭取消正在进行的分享，已有消息版本保留，不会再提交，听者最终回waiting。'}, {'case':'foraging','driver_lines':'25–38','supported':'推进390帧，实际foraging前置断言成立；关闭后听者最终回waiting，失效来源不能新分享。'}, {'case':'early_departure','driver_lines':'39–47','supported':'来源仍开放时，提交前UP移动取消，无消息提交、无继续听者；JSON往返。'}],
 'restore_semantics':{'evidence':'spring_journey_verify.gd:27–36','supported':'同一进程中新模型经JSON字符串重建，精确payload相等；再比JSON恢复模型与直接payload恢复克隆的下一次RIGHT输入。','limit':'下一输入对照双方都是恢复模型，未直接与未恢复的原活模型比较；没有磁盘文件写读、进程重启、实际暂停菜单、导出包或OS输入。不能称冷启动恢复140/0。'},
 'source_implementation_alignment':{'path':'prototypes/swarm-flight/spring_journey_model.gd','lines':'195–235;249–282;283–348','findings':['invalidate_source显式注释是内容事件、不是墙钟过期；source_open false，revision加1，清feeding计时并cancel_dance；departing/foraging听者改returning。','advance_listeners将returning移回waiting落点；normalized_dance拒绝关闭来源仍departing/foraging等不一致状态。','step的分享依赖can_share和observation_valid；移动可cancel_dance。上述与driver预期一致。']},
 'not_supported':['没有自然花期/时间到期导致关闭的运行证据；这里直接调用内容事件','没有最终Mac包磁盘/冷启动/菜单暂停证明；需另用独立证据','没有关闭后重新开放源花、重新观察或再次招募的测试','没有全部关闭相位穷举：离花途中任意帧、重复关闭幂等、关闭时R回检查点等不在本补充覆盖','没有针对坏实现的突变或反例捕获证明；只读审计没有重跑trace','trace仅记录断言标签和布尔结果，缺每个关闭点原始状态快照/原生媒体；不证明玩家读图、角色表现或理解'],
 'conclusion':'140/0计数与140条true记录一致，driver确实覆盖四个指定分享/采食阶段的受控源花关闭、取消、最终撤回和JSON模型恢复，以及提交前普通移动离开。若所述范围严格维持trace自述，支持成立；若扩大为自然源花到期、全部恢复场景或玩家体验，则不成立。',
 'inputs':[source(driver,'1–52','完整driver'),source(trace,'all','140条断言与元数据'),source('prototypes/swarm-flight/spring_journey_verify.gd','1–130','继承的准备与roundtrip函数'),source('prototypes/swarm-flight/spring_journey_model.gd','195–348','关闭、听者、提交及校验实现')]
}
(base/'supplement-audit.json').write_text(json.dumps(a,ensure_ascii=False,indent=2)+'\n')
for name in ['calibration.json','next-content-handoff.json','supplement-audit.json']:
 p=base/name;json.loads(p.read_text());print(name,sha(p),p.stat().st_size)
for name in ['continuation/review.json','continuation/notes.jsonl','review/review.json']:
 p=base.parent/name;print('sealed-check',name,sha(p))
