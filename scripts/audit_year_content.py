#!/usr/bin/env python3
"""Check the runtime calendar and render its review matrix; no second authoring source."""
import argparse, json, re
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
CALENDAR = ROOT / 'godot/playtest/year/year_calendar.json'
OUT = ROOT / 'docs/design/year-play-matrix.md'
ACTIONS = {
'visit':('认路','接近各地标','访问留下记录'), 'convoy':('带队认路','五伙伴实际聚齐各落脚处','全队返回'),
'escort':('接伙伴','靠近路边等待者，慢飞接回','五伙伴回巢'),
'pollen':('采粉','停靠花源、卸在储粉处','花粉入巢'), 'nectar':('采蜜','停靠花源、卸在接蜜处','待处理花蜜入巢'),
'wind':('多花采蜜','分别抵达各花源、抵抗侧风','各花访问后交蜜'), 'dual':('两类交接','分别采粉采蜜、辨别交接位置','两类都交齐'),
'pollinate':('传粉','先沾体表粉，再触碰目标花','保存首次传粉日，延后青果与成熟'),
'wake':('请小虫让路','靠近小虫互动','小虫移到草茎'),
'haul':('搬叶','取叶、重载慢飞、对位放下','叶堆留在原处'),
'repair':('修叶棚','取件、对位放下','真实遮蔽范围扩大'),
'sign':('立花牌','取件、辨形状、对位放下','路牌保留'),
'catch':('接风中物件','追上移动物件、对位放下','移动物件固定成路牌'),
'water':('取水','湿石取水、回巢交给扇风处','交水短回应，记录成果'),
'fan':('扇风','停稳并朝箭头持续按住空格','进度弧填满、气流打通'),
'wax':('补巢脾','停在裂缝旁持续按住空格','暗裂缝变为金色补痕'),
'clean':('清碎屑','拾起碎屑，搬到巢门收拢处','碎屑清走'),
'warm':('暖伙伴','逐只靠近并持续互动、一起回家','五只从原地等候转为随行'),
'seed':('留种','接起种子、到土缝放下','种子留下记录'),
'fruit':('推果','绕到果后、按移动方向轻推','果子真正滚入草窝'),
'share':('递储蜜','蜜房取蜜、回巢递给伙伴','递蜜回应，记录成果'),
'scout':('雨路认路','抵达规定路点','支路记入地图'),
'leaf_delivery':('雨路带粉','经过叶下路带粉回家','首份粉送到'),
'build':('撑叶台','巢门取叶、选择支点撑起','真实新遮蔽保留'),
'drips':('穿滴水线','等停水穿过或绕下方叶下','带粉回家'),
'gutter':('清叶沟','种壳搬到右下黄地','干地露出'),
'rack':('熟路运输','自选路线带两份粉回家，叶台可选歇脚','真实交付完成'),
'beetle':('护送甲虫','接篷慢行、一起抵达叶下','甲虫转身回应并留下'),
'moving':('跟随叶影','带粉在移动影内稳定，自选返程与歇脚','带粉返巢'),
'delivery':('轻重载选择','一趟带满或分趟运输','交三份粉'),
'rescue':('接新蜂','逐只接起等待者','五伙伴一起回巢'),
'mastery':('熟路带粉','带大家取粉回家，掉粉可接','完整返回'),
'final':('雨路合流','五伙伴实际到过花田，两份粉与全队回家','共同往返与十五日成果保留')}
VARIATIONS={'steady':'熟悉动作；按场所与天气复现','sway':'一动花两份／两稳花各一份，选择停靠', 'novice':'一只新蜂实际到花采集，其他四位留巢', 'wide':'携叶额外降速，宽叶外形', 'drift':'种子持续漂移，追接实际坐标', 'crosswind':'交替箭头朝向，转身后才能扇风', 'spread':'五伙伴散开，需要逐只靠近', 'rain_authored':'专属雨路状态机'}

def render():
 data=json.loads(CALENDAR.read_text());chapters=data['chapters']
 assert len(chapters)==24
 spring=json.loads((ROOT/'godot/playtest/spring/spring_calendar.json').read_text())['chapters']
 for t in [0,2,3,4,5]:
  for n,row in enumerate(spring[t]['days']):
   for key,value in row.items():
    assert chapters[t]['days'][n][key]==value, f'Spring/year drift: {t}:{n+1}:{key}'
 rain_text=(ROOT/'godot/playtest/rain_route/route_calendar.gd').read_text()
 rain_modes=re.findall(r'\{"mode": "([^"]+)"',rain_text)
 assert len(rain_modes)==15
 lines=['# 四季逐日玩法比较矩阵','', '本表由 `scripts/audit_year_content.py` 从实际运行日历生成。修改关卡后运行该脚本，`--check` 用于 CI；不另维护一套关卡定义。','',
 '性质：作者编排的 360 天，共用动作规则与可见变奏。相同劳动可以复现；“日常复现”不是独创机制。位置／数量变化单独列出，不计作新动作。自动遍历是开发者规则自测，长期乐趣、真人时长与商业完成度仍需实玩评审。','',
 '科学边界：虚构地方的压缩日历；搬叶、推果、留种、暖伙伴均含拟人化。冬季在巢内，不把每日出巢采花作为越冬事实。过场每候完成时触发，可跳过／回看，不增加奖励。','']
 seen={};ids=set();count=0
 for t,c in enumerate(chapters):
  assert len(c['days'])==15
  lines += [f"## {t+1:02d} · {c['name']} · {c['theme']}",'', '| 日 / 标题 | 劳动与操作 | 地点 / 天气 | 可见差异与对照 | 完成回应 |','| --- | --- | --- | --- | --- |']
  for n,d in enumerate(c['days'],1):
   mode=d['mode'];v=d['variation'];assert mode in ACTIONS and v in VARIATIONS
   assert d['id'] not in ids;ids.add(d['id']);assert d['places']
   assert d['source_ids'] and d['claim_scope'] and d['regional_scope']
   assert d.get('quota',1) in range(1,4)
   if t==1: assert mode==rain_modes[n-1]
   if t>=18: assert mode in ['visit','convoy','share','wax','clean','warm','fan'] and d['weather']=='indoors'
   if t in [5,11,17,23] and n>=11: assert d['setpiece_phase']==n-10
   action,operation,result=ACTIONS[mode]
   if t==1 and mode=="wind": action,operation,result="换风接应","先到叶台接伙伴，再去花田取粉回家","五位伙伴与花粉到家"
   key=(mode,v if v in ['sway','novice'] or mode in ['fan','warm','seed','haul'] else 'steady')
   previous=seen.get(key)
   compare=f"复现 {previous} 的动作" if previous else '首次引入此组合'
   seen[key]=f"{c['name']} {n} 日"
   detail=VARIATIONS[v]
   if v=='drift' and mode!='seed': detail='移动物件由接牌规则提供；不另算漂移变奏'
   if v=='crosswind' and mode!='fan': detail='风向由当日天气控制；不另算箭头变奏'
   lines.append(f"| {n:02d} · {d['title']} | {action}：{operation} | {'、'.join(d['places'])} / {d['weather']} | {detail}；{compare} | {result} |")
   count+=1
  lines += ['',f"三候镜头：{' / '.join(c['hou_captions'])}。季节节点：{c['ending']}。",'']
 assert count==360
 return '\n'.join(lines).rstrip()+'\n'

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');args=p.parse_args()
 result=render()
 if args.check:
  assert OUT.exists() and OUT.read_text()==result,'Matrix is stale; run python3 scripts/audit_year_content.py'
 else: OUT.write_text(result)
 print('YEAR CONTENT PASSED: 24 terms, 360 days, rain alignment, winter constraints, matrix synchronized')
