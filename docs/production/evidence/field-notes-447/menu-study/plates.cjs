/* Editable artwork for #447. Run with node plates.cjs OUTPUT to produce individual SVG menu layers. */
const fs = require('node:fs')
const path = require('node:path')
const { execFileSync } = require('node:child_process')
const art = path.resolve(__dirname, '../../../../../prototypes/swarm-flight/art')
const shared = fs.readFileSync(path.resolve(__dirname,'../shared-menu.svg'),'utf8')
const out = process.argv[2]
const cache = new Map()
const paper = '#fcf1d5', dark = '#3c3128', muted = '#695940', teal = '#315850'
const serif='Songti SC, STSong, serif', sans='PingFang SC, Heiti SC, sans-serif'
function t(x,y,words,size=18,fill=dark,font=sans,weight=400,align='start'){
  return `<text x="${x}" y="${y}" font-family="${font}" font-weight="${weight}" font-size="${size}" fill="${fill}" text-anchor="${align}">${words}</text>`
}
const head=(x,y,words,size=36)=>t(x,y,words,size,dark,serif,700)
const center=(x,y,words,size=18,fill=dark,font=sans,bold=500)=>t(x,y,words,size,fill,font,bold,'middle')
const p=(d,fill,stroke='none',w=1)=>`<path d="${d}" fill="${fill}" stroke="${stroke}" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round"/>`
const r=(x,y,w,h,rad,fill,stroke='none',sw=1)=>`<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${rad}" fill="${fill}" stroke="${stroke}" stroke-width="${sw}"/>`
const rule=(x,y,xx,color='#caaf86')=>p(`M${x} ${y} H${xx}`,'none',color)
const g=(x,y,s,body)=>`<g transform="translate(${x} ${y}) scale(${s})">${body}</g>`
const defs=shared.slice(shared.indexOf('<defs>'),shared.indexOf('<g transform="translate(0 3)'))
function embedded(file,width=0){
  const key=file+width
  if(!cache.has(key)){
    const original=path.join(art,file)
    const data=width?execFileSync('cwebp',['-quiet','-q','90','-resize',String(width),'0',original,'-o','-'],{maxBuffer:10_000_000}):fs.readFileSync(original)
    cache.set(key,'data:image/webp;base64,'+data.toString('base64'))
  }
  return cache.get(key)
}
function img(file,x,y,w,h,fit='xMidYMid meet',limit=0){
  return `<image x="${x}" y="${y}" width="${w}" height="${h}" preserveAspectRatio="${fit}" xlink:href="${embedded(file,limit)}"/>`
}
const symbol=(id,x,y,w,h)=>`<use xlink:href="#${id}" x="${x}" y="${y}" width="${w}" height="${h}" style="mix-blend-mode:multiply"/>`
function bolt(x,y){return `<circle cx="${x}" cy="${y}" r="3.3" fill="url(#brass)" stroke="#b0915c" stroke-width=".75"/>`+p(`M${x-1.5} ${y+1} l3 -2`,'none','#86693e',.7)}
function plaque(x,y,w,h){
  const contour=`M20 8 Q${w*.5} -2 ${w-21} 8 Q${w-3} 10 ${w-4} 32 L${w-2} ${h-34} Q${w-2} ${h-12} ${w-24} ${h-10} Q${w*.52} ${h+2} 23 ${h-9} Q2 ${h-11} 3 ${h-31} L4 31 Q4 11 20 8 Z`
  return g(x,y,1,g(0,4,1,p(contour,'#aa8754','#8e704a'))+p(contour,'url(#ceramic)','#c3a575',1.5)+bolt(16,29)+bolt(w-17,29)+bolt(16,h-31)+bolt(w-17,h-31))
}
function button(x,y,w,text,focus=false,small=false){
  const height=small?35:44
  return r(x,y+2,w,height,12,'#c6a478')+r(x,y,w,height,12,'url(#raised)','#b79b70')+(focus?r(x-4,y-4,w+8,height+8,15,'none',teal,2.7):'')+center(x+w/2,y+height*.69,text,small?16:20,dark,serif,650)
}
function back(x,y){return t(x,y,'‹  返回',17,muted,sans,500,'end')}
function svg(title,body,width=960,height=600){
  return `<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}"><title>${title}</title>${defs}${body}</svg>`
}
function filePage(name,title,body){fs.writeFileSync(path.join(out,name+'.svg'),svg(title,body))}
function slots(){
  let b=plaque(158,44,644,512)+symbol('files',185,74,64,61)+head(268,111,'选择存档')+back(756,108)
  const drawer=(y,n,detail,state)=>{
    const focus=state==='focus', current=state==='current', faded=state==='blocked'
    const edge=faded?'#beaf91':'#bba179'
    let face=p('M11 7 Q18 4 30 4 H117 L128 0 H511 Q526 0 527 13 L527 73 Q527 83 513 84 H13 Q0 84 0 72 V20 Q0 12 11 7 Z',faded?'#e6dcc2':current?'#e7e8ce':'#fff6df',edge,1.2)
    face+=r(20,21,71,39,7,faded?'#c6baa0':'#e7d0a2','#b49970')+center(56,47,'存档 '+n,17,dark,serif,650)
    face+=t(110,48,detail,17,faded?'#716955':dark)
    if(current)face+=r(440,25,65,27,13,teal)+center(472,44,'当前',15,'#fff5d9')
    if(focus)face+=r(-4,-4,535,92,12,'none',teal,2.75)
    return g(217,y,1,face)
  }
  b+=rule(213,144,749)+drawer(172,1,'蜂巢庭院  ·  8 金币  ·  已出行 2 趟','current')+drawer(272,2,'空档  ·  开始新游戏','focus')+drawer(372,3,'无法读取','blocked')
  b+=rule(213,475,749)+t(215,514,'Enter  选择档位',16,muted)+t(747,514,'Esc  返回',16,muted,sans,400,'end')
  return b
}
function envelope(failed){
  let b=img('honey-menu-letter.webp',152,108,657,371,'none',800)
  b+=head(220,249,'在存档 1 重新开始？',33)
  b+=t(221,296,failed?'当前存档无法读取。先备份原文件，':'先备份当前进度，再开始新的一轮。',19)
  if(failed)b+=t(221,324,'再开始新的一轮。',19)
  b+=button(225,359,120,'取消',true)+r(389,361,205,41,10,'#f0dfb9','#b69a6d',1)+center(491,388,'备份并重新开始',18,dark,serif,550)
  return b
}
function card(x,meadow,locked,focus){
  const name=meadow?'紫花地':'池岸花丛'
  let b=r(x,154,344,302,17,'#d8bb8a')+r(x,150,344,302,17,'#fcf2d9','#bca175',1.15)
  if(focus)b+=r(x-5,145,354,313,21,'none',teal,3)
  const id='plate-'+(meadow?'v':'p')
  b+=`<clipPath id="${id}">${r(x+12,163,320,146,9,'white')}</clipPath><g clip-path="url(#${id})">${img(meadow?'collection-meadow.webp':'collection-pond.webp',x+12,163,320,146,'xMidYMid slice',700)}</g>`
  b+=head(x+22,350,name,26)
  if(locked)b+=r(x+211,327,111,27,12,'#e3d1ab')+center(x+267,346,'尚未开放',15,'#66563b')
  else b+=t(x+316,351,'›',26,teal,serif,650,'end')
  b+=t(x+22,384,meadow?'紫花蜜  ·  每份 3 金币':'蓝花蜜  ·  每份 1 金币',18)
  b+=t(x+22,421,locked?'在成长手册解锁这条花路。':meadow?'掀开树皮，贴近后收集树脂。':'振松种穗，飞近收集纤维。',17,muted)
  return b
}
function routes(locked){
  let b=plaque(62,32,836,530)+symbol('guide',98,61,74,59)+head(186,108,'选择花路')+t(838,102,'蜜囊 0 / 6   ·   续航 36',18,muted,sans,400,'end')
  b+=rule(102,130,854)+card(112,false,false,locked)+card(504,true,locked,!locked)+rule(105,485,854)
  return b+t(111,521,'‹  先留在这里',18,muted)+t(843,521,'Enter  出发',16,muted,sans,400,'end')
}
function journal(meadow,expanded){
  const book=img('honey-menu-book.webp',22,24,916,548,'none',1120)
  let b=''
  b+=head(105,132,'花路手册',31)+back(837,123)
  for(const [i,place] of ['池岸花丛','紫花地'].entries()){
    const x=106+i*142,sel=Number(meadow)===i
    b+=r(x,156,130,36,13,sel?teal:'#f5e5c0','#ab9466')+center(x+65,181,place,18,sel?paper:dark,serif,650)
  }
  const region=meadow?'collection-meadow.webp':'collection-pond.webp'
  b+='<clipPath id="landscape">'+r(106,212,304,138,9,'white')+'</clipPath><g clip-path="url(#landscape)">'+img(region,106,212,304,138,'xMidYMid slice',640)+'</g>'
  b+=t(107,388,meadow?'紫花地已记录':'池岸已备好',21,dark,serif,650)+t(108,419,meadow?'已交付紫蜜 1 份':'紫花地待探索',17,muted)
  const x=521,xx=618
  b+=img(meadow?'collection-violet-bloom.webp':'collection-blue-bloom.webp',x,145,77,79,'xMidYMid meet',180)
  b+=head(xx,167,meadow?'紫花蜜':'蓝花蜜',25)+t(xx,197,meadow?'靠近紫花，按住 E。':'花心发亮时，按住 E。',17)+t(xx,224,meadow?'每份 3 金币':'每份 1 金币',17,'#77572c')
  b+=rule(x,246,831)+img(meadow?'collection-resin-source.webp':'collection-fiber-source.webp',x+3,263,73,93,'xMidYMid meet',180)
  b+=head(xx,284,meadow?'树脂':'纤维',25)+t(xx,315,meadow?'Q 掀开树皮，':'Q 振松种穗，',17)+t(xx,340,meadow?'贴近后按住 E 收树脂。':'飞近飘绒收纤维。',17)
  b+=rule(x,357,831)+r(x-3,369,311,36,9,'#ead8af')+r(x-6,366,317,42,11,'none',teal,2.5)+t(x+10,394,expanded?'归途须知  −':'归途须知  ＋',18,dark,serif,650)
  if(expanded)b+=t(x,431,'从入口木牌返程。续航耗尽会损失',15,muted)+t(x,453,'一半花蜜，材料、金币与成长保留。',15,muted)
  return book+g(0,-25,1,b)
}
function menuAction(x,y,id,words,state='rest'){
  const a=shared.indexOf('<g transform="translate(123 368) scale(1)">')
  const b=shared.indexOf('<g transform="translate(327 368) scale(1)">',a)
  if(a<0||b<0)throw Error('Missing canonical menu action')
  let item=shared.slice(a,b).replace('translate(123 368)', 'translate('+x+' '+y+')').replace('xlink:href="#reel"','xlink:href="#'+id+'"').replace('>新的一轮<','>'+words+'<')
  if(state==='focus')return g(x,y,1,'<use xlink:href="#settings-focused"/>')
  if(state==='hover')item=item.replace('url(#raised)','url(#hover)')
  if(state==='pressed')item=item.replace('url(#raised)','url(#down)').replaceAll('translate(0 0) scale(1)','translate(0 3) scale(1)')
  return item
}
function feedback(){
  const palette=plaque(44,108,872,366)+head(88,177,'设置',35)+t(191,172,'同一入口的四种状态',18,muted)+rule(87,200,871)
  const states=[['常态','rest'],['悬停','hover'],['焦点','focus'],['按下','pressed']]
  let ui=''
  states.forEach(([label,state],n)=>{const x=166+n*208;ui+=menuAction(x,230,'dial','设置',state)+center(x,374,label,18,muted)})
  return palette+ui+rule(87,396,872)+t(92,435,'从设置返回，焦点回到原菜单的调节轮。',18,muted)
}
function completed(){
  let b=plaque(176,45,606,504)
  b+=img('honey-menu-seal.webp',216,96,116,116,'xMidYMid meet',260)+head(352,146,'花蜜，备好了',35)
  b+=t(354,185,'花蜜已经封好。回花园，下一趟随你。',18,muted)
  b+=rule(224,238,728)+button(271,274,417,'再去花园转转',true)
  b+=menuAction(291,340,'dial','设置')+menuAction(480,340,'reel','新的一轮')+menuAction(666,340,'gate','保存并退出')
  b+=rule(222,470,734)+t(225,506,'Demo 0.32.7',15,muted)+t(734,506,'Enter  确认',16,muted,sans,400,'end')
  return b
}
function titleState(mode){
  const loaded=mode==='title', fresh=mode==='new', blocked=mode==='blocked'
  let s=shared
  const guideStart='<g transform="translate(327 136) scale(1)">'
  const guideEnd='<g transform="translate(123 252) scale(1)">'
  const i=s.indexOf(guideStart),j=s.indexOf(guideEnd,i)
  if(i<0||j<0)throw Error('Shared menu actions were moved')
  s=s.slice(0,i)+s.slice(j)
  if(fresh){
    const start=s.indexOf('<g transform="translate(123 368) scale(1)">'),end=s.indexOf('<g transform="translate(327 368) scale(1)">',start)
    s=s.slice(0,start)+s.slice(end)
  }
  const status=blocked?'这份进度无法读取。可先备份原文件。':fresh?'飞进花地采蜜，带着收获回庭院。':'飞进花地采蜜，带着收获回庭院。'
  s=s.replace('带回第一囊花蜜，换一项成长',status).replace('保存并退出','退出游戏').replace('Esc  返回','Enter  确认')
  s=s.replace('>继续采蜜<','>'+(fresh?'从蜂巢出发':blocked?'备份并重新开始':'继续采蜜')+'<')
  // In the title state this is read-only save information in the place reserved for the pause-only guide.
  const note=t(264,170,blocked?'存档状态':fresh?'新存档':'当前进度',15,muted)+t(264,199,blocked?'无法读取':fresh?'尚未出行':'蜂巢庭院',20,dark,serif,650)
  s=s.replace(guideEnd,note+guideEnd)
  if(!loaded){
    s=s.replace('<use xlink:href="#settings-focused"/>',menuAction(0,0,'dial','设置'))
    const ring=p('M-72 66 Q-62 61 -44 59 Q-43 33 -32 23 Q-34 5 -17 1 Q-9 -4 1 0 Q14 -8 29 -5 Q54 -8 46 8 Q45 20 41 29 Q43 45 28 58 Q65 60 72 66 Q81 75 78 85 Q75 99 57 100 H-58 Q-81 99 -79 80 Q-79 70 -72 66 Z','none',teal,2.5)
    s=s.replace(note+guideEnd,g(123,136,1,ring)+note+guideEnd)
  }
  return s
}
function field(){
  let b=plaque(45,47,870,504)+head(89,110,'野外提示',32)+t(872,104,'池岸花丛　／　紫花地',17,muted,sans,400,'end')+rule(86,132,873)
  const badge=(x,y,w,text,alert=false)=>r(x,y,w,43,11,alert?'#754d35':'#39483e')+center(x+w/2,y+29,text,18,'#fff2d4')
  b+=img('collection-blue-bloom.webp',118,163,114,120,'xMidYMid meet',200)+badge(259,185,188,'按住 E　采蜜')+badge(259,240,134,'采蜜中')
  b+=img('collection-fiber-source.webp',123,307,97,117,'xMidYMid meet',180)+badge(259,337,197,'Q　朝种穗振翅取绒')
  b+=img('collection-resin-source.webp',494,162,116,126,'xMidYMid meet',180)+badge(634,185,203,'Q　朝裂口振翅掀皮')+badge(634,240,178,'贴近裂口收树脂')
  b+=p('M550 340 l-24 20 24 20 v-13 h43 v-14 h-43 z','#ac6f3e')+badge(631,337,215,'体力低 · 回庭院',true)
  b+=rule(86,448,873)+t(91,483,'拾取',16,muted)+t(155,485,'纤维 +1（现有 1）',19)+t(529,485,'蜜囊已满 · 仍可取材',19)
  return b
}
if(!out)throw Error('Supply an output directory')
fs.mkdirSync(out,{recursive:true})
filePage('feedback','操作状态',feedback())
filePage('slots','选择存档',slots())
filePage('restart','重开确认',envelope(false))
filePage('restart-blocked','无法读取的存档',envelope(true))
filePage('routes','选择花路 · 尚未开放',routes(true))
filePage('routes-open','选择花路 · 已开放',routes(false))
filePage('guide','花路手册 · 池岸',journal(false,false))
filePage('guide-violet','花路手册 · 紫花地',journal(true,true))
filePage('complete','储粮完成',completed())
filePage('field','两地野外提示色样',field())
for(const mode of ['title','new','blocked'])fs.writeFileSync(path.join(out,mode+'.svg'),titleState(mode))
