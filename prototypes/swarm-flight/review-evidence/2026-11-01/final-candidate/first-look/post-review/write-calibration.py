import json,hashlib
from pathlib import Path
from datetime import datetime,timezone
base=Path('/private/tmp/pond-first-look-9611660/post-review'); src=Path('/private/tmp/pond-review-calibration-a')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
r={
 'created_at_utc':datetime.now(timezone.utc).isoformat(),'reviewer':'first_look AI explorer, independent post-review calibration','source_design_exposure_before_judgment':False,'scope':'Only supplied 3 raw stills, sparse video frames and derived sample facts. No game window operated. Sealed first-look evidence unchanged.',
 'verdict':'insufficient_to_prove_consequential_rain_route_choice','can_prove_requested_claim':False,
 'conclusion':'片段证明了上方飞越与棚下穿行均出现，也证明棚下恢复和露珠带来资源差异；但不足以证明一次在可比较雨中暴露下、具有实际取舍的低棚/护雨路线选择。上方轨迹一直在云雨带上方，无护雨消耗、无雨击损失；低路线只走到中途，且两段没有相同终点对照。不能把这份不足扩展为游戏绝不存在有效选择。',
 'observations':[
  {'basis':'frame-1.png, frame-2.png; video 2–14s; facts samples 0–476','finding':'蜂在云带上方飞行。weather虽进入rain，雨段y约100.00–123.21；shield始终0，shelter=-1，recoveries=0。体力逐样本只下降0.0666667（30个样本/秒，约2/秒），与干燥段一致，没有额外雨击跳降。到after后体力约68.2。'},
  {'basis':'frame-3.png; video 18–26s; facts samples 477–792','finding':'第二段由起点重新开始，走棚下，两个shelter区出现，体力在棚下回100；画面有露珠收集1/2，facts最大正跃升约10.0667。该段结束仍在rain、x2168.75，未展示和上方段x4003.32/after相同终点。'},
  {'basis':'facts tick954→956 and video14→16s','finding':'位置由约[4003,101]跳回[181,421]，体力68.2回99.93，weather after回dry；这是两段测试轨迹的边界，不能当作同一自然连续飞行。'},
  {'basis':'all793 facts samples','finding':'shield全为0；无recoveries；体力不存在超过正常每样本0.0667的下降。这段没有展示护雨开关或雨中受击与免受击的差异。'}
 ],
 'supported_narrow_claims':['存在不同高度的实际行进轨迹','棚下可恢复体力，露珠可增加资源','上方轨迹在这份材料中绕过了可见云雨带'],
 'insufficient_or_unknown':['未展示相同分岔点到共同终点的两路对照','没有护雨路线激活/到期及与雨暴露相互作用的证据','没有雨击造成的损失、失败或等待压力','不能仅以weather=rain标签认定角色真正受到雨威胁','不能凭两段不等长度体力差推导路线的净成本或速度优势','没有证据可推断真人偏好、整体产品接受或所有可能路线'],
 'reviewed_media_scope':{'raw_stills':['frame-1.png','frame-2.png','frame-3.png'],'video_duration_seconds':26.57,'video_review':'14 extracted frames at 0,2,4,...,26 seconds, examined as contact sheet; original three full-size stills separately viewed. Not full-speed playback; unsampled moments not claimed as visually observed.','facts':'All793 records programmatically aggregated; targeted transitions examined.','audio':'Not listened to; no audio claims.','tools':'System ffprobe failed missing libx265; AVFoundation extraction compilation interrupted; existing standalone ffmpeg supplied by root used. No environment repair.'},
 'inputs':[{'path':str(src/n),'sha256':sha(src/n)} for n in ['frame-1.png','frame-2.png','frame-3.png','continuous.mp4','sample-facts.json']],
 'derived_frames':[{'path':str(p.relative_to(base)),'sha256':sha(p),'raw':False,'extracted_video_time_seconds':i*2} for i,p in enumerate(sorted((base/'calibration-frames').glob('exact-*.png')))]
}
p=base/'calibration.json';p.write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n');print(p,sha(p))
