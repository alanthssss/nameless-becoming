"""Build an offline, image-based Honey review prototype.

Usage: python make_preview.py RENDERED_SVG_DIRECTORY OUTPUT.html
Requires Pillow with WebP support, node, cwebp and rsvg-convert.
"""
import argparse
import base64
import json
import subprocess
import tempfile
from concurrent.futures import ThreadPoolExecutor
from io import BytesIO
from pathlib import Path
from xml.etree import ElementTree

from PIL import Image


HERE = Path(__file__).resolve().parent
PAGES = [
    ("title", "标题", "启动与存档"), ("pause", "暂停", "继续这趟出行"),
    ("slots", "选择存档", "当前档与浏览焦点"), ("restart", "备份与重开", "确认与取消"),
    ("routes", "选择花路", "出发与解锁"), ("guide", "花路手册", "花材与归途"),
    ("settings", "设置", "声音、蜂舞与操作"), ("controls", "键位设置", "设备、情境与改键"),
    ("complete", "储粮完成", "封存与再出发"), ("field", "野外提示", "采集与返程"),
    ("feedback", "操作状态", "悬停、焦点与按下"),
]
VARIANTS = {
    "title": [("title","已有进度"),("new","首次出发"),("blocked","坏档")],
    "restart": [("restart","已有进度"),("restart-blocked","坏档")],
    "routes": [("routes","紫花地待开放"),("routes-open","两地已开放")],
    "guide": [("guide","池岸 · 标本"),("guide-violet","紫花地 · 归途须知")],
    "settings": [("settings","常态"),("settings-motion","简化动画"),("settings-about","关于")],
    "field": [("field-return","返庭木牌"),("field-flower","采蜜"),("field-fiber","纤维"),
              ("field-resin","树脂"),("field-tired","低体力"),("field-gathering","采蜜中"),
              ("field-full","蜜囊已满"),("field-pickup","拾取反馈"),("field-open","树脂已露出")],
}
DEVICES = [("kbm","键盘和鼠标"),("pad","游戏手柄")]
CONTEXTS = ["飞行","菜单","成长树","花湾"]
SAMPLES = [("normal","普通"),("waiting","等待输入"),("conflict","按 M · 冲突"),
           ("cancel","取消"),("saved","按 J · 保存"),("reset","恢复默认")]


def bitmap(entry):
    name, path = entry
    width, height = map(float, ElementTree.parse(path).getroot().get("viewBox").split()[2:])
    png = subprocess.check_output(["rsvg-convert", "-z", "1.5", str(path)])
    with Image.open(BytesIO(png)) as image:
        data = BytesIO()
        image.save(data, "WEBP", quality=92, alpha_quality=100, method=4)
    return name, [width, height, base64.b64encode(data.getvalue()).decode("ascii")]


def build(source, output):
    with tempfile.TemporaryDirectory(prefix="honey-menu-review-") as temp:
        general = Path(temp)
        subprocess.run(["node", str(HERE/"plates.cjs"), str(general)], check=True)
        paths = {p.stem: p for p in general.glob("*.svg")}
        paths["pause"] = HERE.parent/"shared-menu.svg"
        required = ["settings", "settings-about", "settings-motion", "controls"]
        required += [f"controls-{i}-{d}" for i in range(4) for d, _ in DEVICES if (i, d) != (0, "kbm")]
        required += [f"controls-{s}" for s, _ in SAMPLES if s != "normal"]
        required += [key for key, _ in VARIANTS["field"]]
        for key in required:
            paths[key] = source/(key+".svg")
        missing = [str(path) for path in paths.values() if not path.is_file()]
        if missing:
            raise FileNotFoundError("Missing artwork: " + ", ".join(missing))
        with ThreadPoolExecutor(max_workers=3) as pool:
            art = dict(pool.map(bitmap, paths.items()))
        content = {"pages":PAGES, "variants":VARIANTS, "devices":DEVICES, "contexts":CONTEXTS,
                   "samples":SAMPLES, "art":art}
        html = HTML.replace("__ARTWORK__", json.dumps(content, ensure_ascii=False, separators=(",",":")))
        output.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=output.parent, delete=False) as handle:
            handle.write(html)
            result = Path(handle.name)
        result.replace(output)
        print(f"{output} ({len(art)} images, {output.stat().st_size:,} bytes)")


HTML = r'''<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src data:; script-src 'unsafe-inline'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'">
<title>Honey｜通用界面设计审阅</title>
<style>
:root{color-scheme:light;--ink:#3e3429;--muted:#746550;--line:#d7c9ad;--jade:#315a4e;--paper:#f7f1e2;--soft:#efeadb}
*{box-sizing:border-box}html,body{margin:0;min-height:100%}body,button{font-family:"PingFang SC","Noto Sans CJK SC",sans-serif;color:var(--ink)}
body{background:var(--paper)}button{font-size:15px;cursor:pointer}button:focus-visible{outline:3px solid var(--jade);outline-offset:3px}
button[hidden],[hidden]{display:none!important}.bar{padding:15px clamp(16px,5vw,76px);display:flex;justify-content:space-between;align-items:center;border-bottom:1px solid var(--line);gap:12px}
.wordmark{display:flex;align-items:baseline;gap:16px}.wordmark strong{font:700 31px/1.1 Georgia,"Songti SC",serif}.wordmark span{font-size:14px;color:var(--muted)}
button.plain{border:1px solid var(--line);border-radius:8px;background:#faf6eb;padding:7px 12px}button.plain:hover,.choice:hover{border-color:#a88f5f;background:#f6e9cc}
main{max-width:1440px;margin:auto;padding:22px clamp(16px,5vw,76px) 32px}h1,h2{font-family:"Songti SC","Noto Serif CJK SC",serif;margin:0}h1{font-size:clamp(24px,3vw,37px)}
.sub,.note{margin:5px 0;color:var(--muted);font-size:14px;line-height:1.6}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,235px),1fr));gap:20px;margin-top:20px}
.tile{display:flex;flex-direction:column;gap:5px;text-align:left;border:1px solid var(--line);border-radius:12px;overflow:hidden;background:#fcf8ed;padding:0 0 14px}
.tile:hover{border-color:#a88f5f}.tile img{height:148px;width:100%;object-fit:contain;background:var(--soft);padding:8px}.tile strong,.tile small{padding:0 15px}.tile strong{margin-top:7px;font:650 22px/1.2 "Songti SC",serif}.tile small{font-size:13px;color:var(--muted)}
.tools,.heading,.group,.choices{display:flex;align-items:center;gap:8px;flex-wrap:wrap}.heading{justify-content:space-between;margin-bottom:12px}.heading #crumb{color:var(--muted);font-size:13px;margin-bottom:4px}
.stage{height:clamp(275px,75vh,790px);position:relative;border:1px solid var(--line);border-radius:14px;display:grid;place-items:center;background:radial-gradient(ellipse at 50% 38%,#faf5e6,#efe7d6);overflow:hidden}
#surface{position:relative;flex:none}.art{width:100%;height:100%;display:block;pointer-events:none}.hit{border:0;padding:0;border-radius:9px;position:absolute;background:transparent}
.hit:hover{box-shadow:inset 0 0 0 2px #806d3b77;background:#ffe7971b}.hit:focus-visible{outline:3px solid var(--jade);outline-offset:2px;background:#fbdc8b13}
.groups{margin:12px 0 8px;display:grid;gap:8px}.group>span{font-size:13px;color:var(--muted);min-width:62px}.choice{border:1px solid var(--line);background:#fbf7eb;border-radius:18px;padding:6px 13px;font-size:14px}.choice[aria-pressed=true]{background:var(--jade);border-color:var(--jade);color:#fff0cc}
.note{min-height:23px}.foot{border-top:1px solid var(--line);margin-top:14px;padding-top:12px;display:flex;justify-content:space-between;align-items:center;gap:8px;flex-wrap:wrap}
dialog{padding:0;border:0;width:100vw;height:100dvh;max-width:none;max-height:none;margin:0;background:#eee7d8}
dialog::backdrop{background:#3d392d99}.zoomhead{position:sticky;left:0;top:0;z-index:1;padding:12px 20px;background:#f9f3e6;display:flex;align-items:center;justify-content:space-between;border-bottom:1px solid var(--line)}
.zoomarea{min-width:100%;width:max-content;min-height:calc(100% - 65px);display:grid;place-items:center;padding:18px}.zoomarea img{display:block;width:100%;height:auto;max-width:none}#zoomSurface{position:relative}
@media(max-width:680px){.bar{padding:12px 16px}.wordmark{gap:9px}.wordmark strong{font-size:26px}.wordmark span{font-size:12px}main{padding:15px 12px}.stage{height:clamp(242px,57vh,455px)}.grid{grid-template-columns:repeat(2,minmax(0,1fr));gap:9px}.tile img{height:108px}.tile strong{font-size:18px}.tile small{font-size:12px}.heading{gap:5px}.group>span{min-width:43px}.group,.choices{gap:5px}.choice{padding:5px 9px;font-size:13px}.tools .plain{padding:6px 9px}.note{font-size:13px}}
</style></head><body>
<header class="bar"><div class="wordmark"><strong>Honey</strong><span>通用界面设计审阅</span></div><button class="plain" id="home" hidden>总览</button></header>
<main><section id="overview"><h1>界面总览</h1><p class="sub">选择画面进入离线设计原型。</p><div class="grid" id="grid"></div></section>
<section id="detail" hidden><div class="heading"><div><div id="crumb"></div><h1 id="name"></h1></div><div class="tools"><button class="plain" id="prev" aria-label="上一页">← 上一页</button><button class="plain" id="next" aria-label="下一页">下一页 →</button><button class="plain" id="zoomBtn">查看大图</button></div></div>
<div class="stage" id="stage"><div id="surface"><img class="art" id="picture" alt=""><div id="hits"></div></div></div><div class="groups" id="groups"></div>
<p class="note" id="note" aria-live="polite"></p><div class="foot"><button class="plain" id="back">‹ 返回</button><small>← → 翻页　·　Esc 返回</small></div></section></main>
<dialog id="zoom"><div class="zoomhead"><strong id="zoomName"></strong><div class="tools"><button class="plain" id="zoomPrev">← 上一页</button><button class="plain" id="zoomNext">下一页 →</button><button class="plain" id="closeZoom">关闭大图</button></div></div><div class="zoomarea"><div id="zoomSurface"><img id="zoomPicture" alt=""><div id="zoomHits"></div></div></div></dialog>
<script type="application/json" id="assets">__ARTWORK__</script><script>
"use strict";
const data=JSON.parse(document.getElementById("assets").textContent);
const $=id=>document.getElementById(id);
const pages=data.pages, names=Object.fromEntries(pages.map(p=>[p[0],p[1]]));
let state=null, activeAsset="", historyStack=[], lastOverview="";
function clean(id){return {id,variant:(data.variants[id]||[[id]])[0][0],device:"kbm",area:0,sample:"normal"};}
function artSrc(k){return "data:image/webp;base64,"+data.art[k][2];}
function artKey(){
  if(state.id!=="controls")return state.variant;
  if(state.area===0&&state.device==="kbm")return state.sample==="normal"?"controls":"controls-"+state.sample;
  return "controls-"+state.area+"-"+state.device;
}
function fit(){
  if(!state)return;
  const inn=$("stage"),[w,h]=data.art[activeAsset];
  const scale=Math.max(.01,Math.min((inn.clientWidth-12)/w,(inn.clientHeight-10)/h));
  $("surface").style.width=w*scale+"px";$("surface").style.height=h*scale+"px";
}
new ResizeObserver(fit).observe($("stage"));
function group(title,entries,selected,fn){
  const line=document.createElement("div");line.className="group";
  const label=document.createElement("span");label.textContent=title;line.append(label);
  const choices=document.createElement("div");choices.className="choices";choices.setAttribute("role","group");choices.setAttribute("aria-label",title);
  for(const [key,name] of entries){const b=document.createElement("button");b.className="choice";b.textContent=name;b.dataset.key=title+"-"+key;
    if(selected!==null)b.setAttribute("aria-pressed",String(selected===key));b.onclick=()=>fn(key);choices.append(b);}
  line.append(choices);$("groups").append(line);
}
function focusKey(key){if(!key)return;const el=[...document.querySelectorAll("[data-key]")].find(e=>e.dataset.key===key);const target=$("zoom").open?[...$("zoomHits").children].find(b=>b.dataset.zoomKey===key):el;if(target)target.focus({preventScroll:true});}
function setState(fields){const key=document.activeElement?.dataset.key||document.activeElement?.dataset.zoomKey;Object.assign(state,fields);render();focusKey(key);}
function navigate(id,variant,invoker){historyStack.push({state:{...state},focus:invoker||document.activeElement?.dataset.key});state=clean(id);if(variant)state.variant=variant;render();$("back").focus({preventScroll:true});}
function overview(){
  if($("zoom").open)$("zoom").close();
  historyStack=[];state=null;activeAsset="";$("detail").hidden=true;$("home").hidden=true;$("overview").hidden=false;
  document.body.dataset.page="overview";focusKey("open-"+lastOverview);window.scrollTo(0,0);
}
function openRoot(id){historyStack=[];lastOverview=id;state=clean(id);render();$("back").focus({preventScroll:true});}
function back(){
  if(state?.id==="controls"&&["waiting","conflict"].includes(state.sample)){setState({sample:"cancel"});return;}
  if(historyStack.length){const prev=historyStack.pop();state=prev.state;render();focusKey(prev.focus);}
  else overview();
}
function pageBy(n){const i=pages.findIndex(p=>p[0]===state.id);openRoot(pages[(i+n+pages.length)%pages.length][0]);}
function hit(key,title,x,y,w,h,act){
  const [sw,sh]=data.art[activeAsset],b=document.createElement("button");b.className="hit";b.dataset.key=key;b.title=title;b.setAttribute("aria-label",title);
  Object.assign(b.style,{left:(100*x/sw)+"%",top:(100*y/sh)+"%",width:(100*w/sw)+"%",height:(100*h/sh)+"%"});
  b.onclick=()=>act(key);$("hits").append(b);
}
function changeSample(s){setState({device:"kbm",area:0,sample:s});}
function controls(){
  group("设备",data.devices,state.device,key=>setState({device:key,sample:"normal"}));
  group("情境",data.contexts.map((name,i)=>[i,name]),state.area,key=>setState({area:key,sample:"normal"}));
  if(!state.area&&state.device==="kbm")group("改键样例",data.samples,state.sample,changeSample);
  data.devices.forEach(([id,name],i)=>hit("device-"+id,name,i?661:469,47,178,40,()=>setState({device:id,sample:"normal"})));
  data.contexts.forEach((name,i)=>hit("area-"+i,name,89,276+48*i,179,39,()=>setState({area:i,sample:"normal"})));
  hit("controls-back","返回设置",79,532,137,40,()=>{if(historyStack.length){const last=historyStack.at(-1);if(last.state.id==="settings"){state.sample="normal";back();return;}}state=clean("settings");render();focusKey("bindings");});
  if(!state.area&&state.device==="kbm"){
    hit("listen","振翅 · 键盘 · 等待输入",489,337,158,38,()=>changeSample("waiting"));
    hit("reset","恢复默认按键",707,532,161,40,()=>changeSample("reset"));
  }
}
function showArtActions(){
  const {id,variant}=state;
  if(id==="title"||id==="pause"){
    const menu=(key,label,col,row,target,v)=>hit(key,label,col?242:39,125+116*row,169,106,k=>navigate(target,v,k));
    if(id==="pause")menu("guide","花路手册",1,0,"guide");
    menu("settings","设置",0,1,"settings");menu("slots","选择存档",1,1,"slots");
    if(variant!=="new")menu("restart","新的一轮",0,2,"restart",variant==="blocked"?"restart-blocked":"restart");
    if(variant==="blocked")menu("backup","备份并重新开始",0,0,"restart","restart-blocked");
    else hit("resume","继续游戏的入口",39,125,169,106,()=>{$("note").textContent="此入口会进入或恢复游戏现场。可从总览选择野外提示画稿。";});
    if(id==="title")group("关联审阅",[["guide","另看花路手册"]],null,k=>navigate(k));
  }else if(id==="settings"){
    hit("bindings","查看或改键",687,374,177,58,k=>navigate("controls",null,k));
    hit("settings-back","返回原菜单",76,521,126,40,back);
    hit("about","关于",748,447,110,46,()=>setState({variant:variant==="settings-about"?"settings":"settings-about"}));
    hit("motion","简化动画",744,179,117,52,()=>setState({variant:variant==="settings-motion"?"settings":"settings-motion"}));
  }else if(id==="controls")controls();
  else if(id==="slots"){hit("slots-back","返回原菜单",722,66,105,59,back);hit("slot-current","存档 1 · 当前",432,151,365,79,back);}
  else if(id==="restart"){
    hit("cancel-restart","取消",366,336,145,62,back);
    hit("confirm-restart","查看首次出发示例",517,336,245,62,k=>navigate("title","new",k));
  }else if(id==="guide"){
    hit("guide-back","返回原菜单",767,83,99,52,back);
    hit("guide-pond","查看池岸标本",88,157,127,44,()=>setState({variant:"guide"}));
    hit("guide-violet","查看紫花地归途须知",224,157,134,44,()=>setState({variant:"guide-violet"}));
  }else if(id==="routes"){
    hit("stay","先留在这里",77,490,193,60,back);
    hit("pond","池岸野外提示",108,177,325,284,k=>navigate("field",data.art["field-flower"]?"field-flower":null,k));
    if(variant==="routes-open")hit("meadow","紫花地野外提示",519,177,347,284,k=>navigate("field",data.art["field-resin"]?"field-resin":null,k));
  }else if(id==="complete"){
    hit("garden","再去花园转转",332,357,300,57,()=>{$("note").textContent="此入口会返回花园的游戏现场。可用返回或总览继续审阅。";});
    hit("settings","设置",241,437,145,96,k=>navigate("settings",null,k));
    hit("restart","新的一轮",407,437,145,96,k=>navigate("restart",null,k));
  }
}
function render(){
  $("detail").hidden=false;$("home").hidden=false;$("overview").hidden=true;document.body.dataset.page=state.id;
  activeAsset=artKey();document.body.dataset.art=activeAsset;
  $("name").textContent=names[state.id];$("picture").alt=names[state.id]+"设计画面";$("picture").src=artSrc(activeAsset);
  $("crumb").textContent=["总览",...historyStack.map(s=>names[s.state.id])].join("  /  ");
  $("hits").replaceChildren();$("groups").replaceChildren();
  const variants=data.variants[state.id];
  if(variants&&variants.length>1)group("画面状态",variants,state.variant,key=>setState({variant:key}));
  showArtActions();fit();if($("zoom").open)updateZoom();window.scrollTo(0,0);
  $("note").textContent=state.id==="controls"?"飞行页用「振翅」演示改键反馈。选择样例可查看结果，示例只在本页切换画面。":state.id==="restart"?"确认可查看首次出发的样例，实际游戏存档不会改变。":"点击画面入口可查看关联设计。";
  $("back").textContent="‹ "+(historyStack.length?"返回"+names[historyStack.at(-1).state.id]:"返回总览");
}
for(const [id,label,sub] of pages){
  const b=document.createElement("button");b.className="tile";b.dataset.key="open-"+id;b.setAttribute("aria-label","打开"+label);
  const im=new Image();const key=clean(id).variant;im.src=artSrc(key);im.alt="";im.loading="lazy";
  const t=document.createElement("strong");t.textContent=label;const sm=document.createElement("small");sm.textContent=sub;b.append(im,t,sm);b.onclick=()=>openRoot(id);$("grid").append(b);
}
$("home").onclick=overview;$("back").onclick=back;$("prev").onclick=()=>pageBy(-1);$("next").onclick=()=>pageBy(1);
function updateZoom(){
  $("zoomPicture").src=$("picture").src;$("zoomPicture").alt=$("picture").alt;
  $("zoomSurface").style.width=(data.art[activeAsset][0]*1.5)+"px";$("zoomName").textContent=names[state.id];
  const controls=[...$("hits").children].map(original=>{
    const copy=original.cloneNode(true);copy.dataset.zoomKey=copy.dataset.key;delete copy.dataset.key;
    copy.onclick=original.onclick;return copy;
  });
  $("zoomHits").replaceChildren(...controls);
}
$("zoomBtn").onclick=()=>{updateZoom();$("zoom").showModal();};
$("closeZoom").onclick=()=>$("zoom").close();
$("zoomPrev").onclick=()=>pageBy(-1);$("zoomNext").onclick=()=>pageBy(1);
document.addEventListener("keydown",e=>{
  if(!state||e.ctrlKey||e.metaKey||e.altKey)return;
  if($("zoom").open&&e.key==="Escape")return;
  if(e.key==="Escape"){e.preventDefault();back();return;}
  if(e.key==="ArrowLeft"||e.key==="ArrowRight"){e.preventDefault();pageBy(e.key==="ArrowLeft"?-1:1);return;}
  if(state.id==="controls"&&["waiting","conflict"].includes(state.sample)&&["m","j"].includes(e.key.toLowerCase())){
    e.preventDefault();changeSample(e.key.toLowerCase()==="m"?"conflict":"saved");
  }
});
document.body.dataset.page="overview";
</script></body></html>'''


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="Directory containing the settings, bindings and field SVG states")
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    build(args.source, args.output)
