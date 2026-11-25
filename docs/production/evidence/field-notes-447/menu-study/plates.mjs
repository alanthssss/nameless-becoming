/* Editable artwork for #447. Run with node plates.mjs OUTPUT to produce individual SVG menu layers. */
import fs from 'node:fs'
import path from 'node:path'
import { execFileSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'

const here = path.dirname(fileURLToPath(import.meta.url))
const art = path.resolve(here, '../../../../../prototypes/swarm-flight/art')
const shared = fs.readFileSync(path.resolve(here,'../shared-menu.svg'),'utf8')
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
function back(x,y){return t(x,y,'‹  返回',17,muted,sans,500,'end')}
function svg(title,body,width=960,height=600){
  return `<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}"><title>${title}</title>${defs}${body}</svg>`
}
function filePage(name,title,body){fs.writeFileSync(path.join(out,name+'.svg'),svg(title,body))}
function oval(x,y,rx,ry,fill,stroke='none',line=1){
  return `<ellipse cx="${x}" cy="${y}" rx="${rx}" ry="${ry}" fill="${fill}" stroke="${stroke}" stroke-width="${line}"/>`
}
function face(outline,fill='url(#ceramic)',edge='#b29359',depth=4){
  return g(0,depth,1,p(outline,'url(#thick)','#956f40',1.4))+p(outline,fill,edge,1.6)
}
function thread(d,ink='#b98548',w=3){
  return p(d,'none','#8e693d',w+1.4)+p(d,'none',ink,w)
}
function rivet(x,y,n=4){
  return oval(x,y+1,n+1,n+1,'#967343')+oval(x,y,n,n,'url(#brass)','#a47f48')+
    p(`M${x-n*.55} ${y+n*.25} l${n} ${-n*.6}`,'none','#8d6a37',1)
}
function actionPlate(x,y,w,label,focus=false,quiet=false){
  const d=`M17 4 Q${w*.49} -2 ${w-18} 4 Q${w+3} 7 ${w-1} 23 Q${w-1} 41 ${w-21} 42 Q${w*.5} 48 19 42 Q0 41 0 24 Q-1 8 17 4Z`
  return g(x,y,1,face(d,quiet?'#efdfbb':'url(#raised)','#b1925f',quiet?2:3)+
    (focus?p(d,'none',teal,3):'')+center(w/2,30,label,quiet?18:21,dark,serif,650))
}
function washMap(id,outline,file,x,y,w,h){
  return `<clipPath id="${id}">${p(outline,'white')}</clipPath><g clip-path="url(#${id})">${img(file,x,y,w,h,'xMidYMid slice',720)}</g>`
}
function slots(){
  // The three numbered tags hang from one copper rail. One ribbon stays on the current save.
  const panel='M125 118 Q120 53 193 49 L348 42 Q398 33 432 55 Q451 67 484 67 H799 Q844 67 846 105 L853 462 Q852 509 804 525 L199 541 Q132 544 124 504 Q119 480 125 449Z'
  let b=face(panel)+p('M152 104 Q354 79 451 96','none','#fff7df',2)
  b+=head(177,111,'选择存档',37)+back(807,105)
  b+=oval(281,412,107,12,'#c2a375', 'none')+symbol('files',146,175,260,248)
  const slotTag=(y,id,title,detail,state)=>{
    const damaged=state==='blocked', current=state==='current', focus=state==='focus'
    const d='M1 31 L34 4 Q40 0 50 0 H345 Q359 0 360 13 L357 65 Q356 76 343 77 H46 Q39 77 32 71 L2 46 Q-4 39 1 31Z'
    let s=face(d,damaged?'#e5d8b7':current?'#eee1b9':'url(#raised)',damaged?'#b1a389':'#b59960',3)
    if(focus)s+=p(d,'none',teal,3.5)
    s+=oval(21,39,5,5,'#ad955f','#856d48',1.3)+oval(21,39,2.4,2.4,'#685338')
    s+=thread('M21 39 Q-14 39 -13 15 C-13 5 -3 2 1 7','#e2c38c',3)
    s+=t(45,29,'存档 '+id,20,damaged?'#6c6657':dark,serif,700)
    if(current) s+=p('M232 1 H303 V33 L268 26 232 33Z',teal)+center(267,19,'当前',14,'#fff4cd')
    s+=t(46,56,title,17,damaged?'#706959':dark)
    if(detail)s+=t(122,28,detail,15,muted)
    if(damaged)s+=p('M333 4 l-7 16 6 5 -6 11 7 4 -8 14','none','#ad9c7b',1.8)
    return g(436,y,1,s)
  }
  b+=thread('M423 149 Q419 284 423 413','#d9b77a',5)+rivet(423,149,7)+rivet(423,416,7)
  b+=slotTag(151,1,'8 金币　·　已出行 2 趟','蜂巢庭院','current')
  b+=slotTag(248,2,'空档　·　开始新游戏','','focus')
  b+=slotTag(345,3,'无法读取','','blocked')
  b+=t(438,493,'Enter  选择档位',16,muted)+t(796,493,'Esc  返回',16,muted,sans,400,'end')
  return b
}
function envelope(failed){
  // A winder holds the old thread while a second end can begin the next outing.
  const tab='M153 145 Q165 127 193 132 L381 127 Q399 125 412 111 Q423 98 446 98 H767 Q800 98 813 126 L830 177 Q832 188 822 201 Q808 217 810 239 L821 356 Q826 383 808 399 L775 428 Q765 439 747 439 H210 Q165 438 153 409 L137 366 Q133 355 146 341 Q159 325 157 306 L147 167 Q145 155 153 145Z'
  let b=face(tab)
  b+=p('M169 151 Q299 143 373 143 Q400 143 420 121 Q430 110 448 110 H761','none','#fff9e7',2)
  b+=thread('M178 302 C194 333 224 339 250 325 C291 302 312 305 335 324 C350 337 361 330 365 318','#d1a266',3)
  b+=oval(247,309,71,8,'#cfb18a')+symbol('reel',158,177,182,135)
  b+=rivet(192,146)+rivet(786,141)+rivet(783,404)
  b+=head(367,200,'在存档 1 重新开始？',32)
  b+=t(370,246,failed?'当前存档无法读取。':'先备份当前进度，',21)
  b+=t(370,279,failed?'先备份原文件，再开始新的一轮。':'再开始新的一轮。',20)
  b+=actionPlate(371,344,130,'取消',true)+actionPlate(527,344,219,'备份并重新开始',false,true)
  return b
}
function compass(x,y){
  return g(x,y,1,oval(0,0,20,20,'#f2dfb2','#b1925f')+oval(0,0,15,15,'none','#baa176')+
    p('M-5 7L2 -12L6 5L-2 12Z','#a87742','#8b673e')+p('M2 -12L1 1L-5 7Z','#795e3e')+rivet(0,0,2.4))
}
function routes(locked){
  const panel='M65 104 L307 72 504 95 668 68 892 85 892 483 670 502 501 481 312 508 63 484Z'
  let b=face(panel,'url(#raised)','#b49865',3)
  // Folded linen paper. Each landscape has its own shoreline; routes meet at the same home pin.
  b+=p('M307 73L314 506 506 481 505 95Z','#ddc18c','none').replace('fill="#ddc18c"','fill="#ddc18c" opacity=".27"')
  b+=p('M668 68L672 500 892 483 892 85Z','#e8cd9d','none').replace('fill="#e8cd9d"','fill="#e8cd9d" opacity=".23"')
  for(const fold of ['M307 74 L314 506','M504 97 L501 479','M668 70 L671 500'])b+=p(fold,'none','#c4aa7a',1.1)
  b+=head(99,137,'选择花路',36)+compass(841,122)
  b+=t(802,127,'蜜囊 0 / 6　·　续航 36',16,muted,sans,450,'end')
  const regions=[
    {x:112,y:179,name:'池岸花丛',file:'collection-pond.webp',path:'M5 78 Q16 48 51 45 Q67 43 78 27 Q101 -4 146 12 Q176 24 212 9 Q255 -8 288 21 Q312 39 303 65 Q297 91 319 105 Q342 126 310 144 Q286 158 246 153 Q216 149 191 159 Q155 174 132 157 Q108 142 83 148 Q53 158 25 135 Q3 119 5 78Z',focus:locked},
    {x:526,y:177,name:'紫花地',file:'collection-meadow.webp',path:'M2 72 Q18 46 53 43 Q76 41 96 23 Q124 -4 156 6 Q189 22 211 13 Q239 4 262 18 Q293 37 296 58 Q299 83 312 96 Q341 123 309 140 Q283 155 254 148 Q239 144 205 159 Q175 173 146 158 Q129 148 103 151 Q61 162 42 142 Q26 125 10 114 Q-7 100 2 72Z',focus:!locked}]
  for(let i=0;i<2;i++){
    const a=regions[i],id=i?'violet-map':'pond-map'
    let map=p(a.path,'#c5ab72','#af925c',5)+washMap(id,a.path,a.file,-7,-2,340,177)
    if(i&&locked)map+=p(a.path,'#efdfba').replace('fill="#efdfba"','fill="#efdfba" opacity=".26"')
    if(a.focus)map+=p(a.path,'none','#fff1c7',5)+p(a.path,'none',teal,2.8)
    b+=g(a.x,a.y,1,map)
    const labelX=a.x+16
    b+=head(labelX,385,a.name,28)
    if(i&&locked)b+=t(labelX+121,382,'尚未开放',16,'#795d34',sans,600)
    b+=t(labelX,419,i?'紫花蜜　·　每份 3 金币':'蓝花蜜　·　每份 1 金币',19)
    b+=t(labelX,449,i?(locked?'在成长手册解锁这条花路。':'掀开树皮，贴近后收集树脂。'):'振松种穗，飞近收纤维。',17,muted)
  }
  b+=p('M465 324 C441 346 416 337 400 311 M476 326 C504 354 548 332 563 306','none','#936638',2.1).replace('stroke-width="2.1"','stroke-width="2.1" stroke-dasharray="4 5"')
  b+=oval(469,330,9,9,'url(#brass)','#947033',1.5)+oval(469,329,3,3,'#665035')+center(469,366,'庭院',15,muted)
  for(const x of [112,235])b+=p(`M${x} 483 v24`,'none','#9a794d',4)+p(`M${x} 484 v22`,'none','#ebcf91',1.5)
  b+=actionPlate(84,498,178,'‹  先留在这里',false,true)
  return b
}
function journal(meadow,expanded){
  const left='M82 116 Q150 59 259 64 Q355 60 398 108 Q416 128 453 134 L461 401 Q433 414 416 441 Q360 500 243 503 Q128 498 77 448 Q44 401 47 288 Q44 178 82 116Z'
  const right='M448 106 L496 84 736 85 Q754 84 767 73 L788 57 842 58 Q856 58 864 69 L885 99 898 450 Q896 465 886 474 L855 507 484 504 447 480Z'
  let b=face(left,'url(#ceramic)','#a78a59',4)+face(right,'url(#raised)','#ac8c58',4)
  // Two brass hinges tie the field view to the facing specimen leaf.
  for(const y of [147,403]){
    b+=r(430,y-9,46,19,8,'url(#brass)','#a38655')+rivet(437,y,3)+rivet(469,y,3)+r(450,y-10,6,21,3,'#9e8055')
  }
  b+=p('M68 263 Q76 190 108 164','none','#f9e6b5',3)+rivet(866,112,4)+rivet(868,470,4)
  b+=head(95,145,'花路手册',34)+back(849,120)
  const tabs=['池岸花丛','紫花地']
  tabs.forEach((name,i)=>{
    const selected=Number(meadow)===i, x=92+i*137, d='M9 2 H104 L120 15 104 31 H7 Q0 31 0 23V10Q0 2 9 2Z'
    b+=g(x,164,1,p(d,selected?teal:'#eddbb3',selected?'#2c5047':'#b2996a')+center(57,22,name,16,selected?paper:dark,serif,650))
  })
  // Field lens with a small handle; the visible cut is an actual region painting.
  b+=p('M302 360 L366 399 Q376 406 368 417 Q362 426 350 420 L288 378Z','url(#brass)','#937344',2)
  b+=oval(244,301,112,91,'url(#brass)','#a38355',2)+oval(244,301,104,83,'#f6e5be','#947442',1)
  b+='<clipPath id="lens-window">'+oval(244,301,99,78,'white')+'</clipPath><g clip-path="url(#lens-window)">'+img(meadow?'collection-meadow.webp':'collection-pond.webp',145,222,198,158,'xMidYMid slice',620)+'</g>'
  b+=p('M154 283 Q166 247 204 235','none','#fff1cf',1.9)
  b+=head(148,437,meadow?'紫花地已记录':'池岸已备好',23)+t(150,464,meadow?'已交付紫蜜 1 份':'紫花地待探索',17,muted)
  const x=622
  b+=p('M508 125 Q585 118 601 144 M504 347 Q527 368 562 368','none','#c9ad7c',1)
  b+=img(meadow?'collection-violet-bloom.webp':'collection-blue-bloom.webp',492,128,114,110,'xMidYMid meet',250)
  b+=thread('M585 207 Q611 211 619 190','#b49a63',1.1)+rivet(616,192,2.4)
  b+=head(x,173,meadow?'紫花蜜':'蓝花蜜',26)+t(x,203,meadow?'靠近紫花，按住 E。':'花心发亮时，按住 E。',17)+t(x,229,meadow?'每份 3 金币':'每份 1 金币',17,'#795b31')
  b+=img(meadow?'collection-resin-source.webp':'collection-fiber-source.webp',494,251,111,116,'xMidYMid meet',250)
  b+=p('M525 318 l26 8 -3 8 -26 -9Z','#d4bc87','#bfa270',.7)
  b+=thread('M576 327 Q607 336 619 317','#b49a63',1.1)+rivet(617,319,2.4)
  b+=head(x,289,meadow?'树脂':'纤维',26)+t(x,319,meadow?'Q 掀开树皮，':'Q 振松种穗，',17)+t(x,345,meadow?'贴近后按住 E 收树脂。':'飞近飘绒收纤维。',17)
  const leaf='M11 2 Q113 0 203 3 L215 17 204 33 10 35 Q1 35 1 24 V10 Q1 4 11 2Z'
  b+=g(499,374,1,face(leaf,'#eddbb2','#b39968',2)+p(leaf,'none',teal,2.8)+t(15,24,expanded?'归途须知　−':'归途须知　＋',18,dark,serif,650))
  if(expanded)b+=t(503,444,'从入口木牌返程。续航耗尽会损失一半花蜜，',16,muted)+t(503,470,'材料、金币与成长保留。',16,muted)
  return b
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
  const ribbon='M211 209 L261 169 Q274 161 301 161 H652 Q677 161 691 174 L751 220 752 408 Q751 425 741 432 L753 450 Q763 463 759 487 L746 521 Q742 535 723 538 Q483 565 242 538 Q224 535 216 518 L204 490 Q195 469 206 451 L220 430 Q209 424 208 409Z'
  let b=face(ribbon)
  // The seal and folded ribbons crown the jar. The three familiar menu objects sit on the shelf below.
  b+=p('M379 139 Q365 186 328 211 L369 214 374 244 Q404 218 426 173Z','#c28f4b','#9e753f',1.3)
  b+=p('M483 151 Q510 192 532 204 L502 213 500 237 Q462 213 449 169Z','#d6ab68','#a88148',1.3)
  b+=oval(428,148,80,82,'url(#brass)','#a6864f',2.3)+oval(428,146,70,71,'#f7e6bc','#fff2d3',2)
  b+=oval(428,196,44,6,'#d8be8d')+img('nectar-honey-jar.png',346,67,164,150,'xMidYMid meet',370)
  b+=img('honey-menu-seal.webp',458,169,49,50,'xMidYMid meet',130)
  b+=head(524,204,'蜂巢储粮',24)+t(525,235,'已花费 60 金币',16,muted)
  b+=center(480,297,'花蜜，备好了',39,dark,serif,700)
  b+=center(480,335,'蜂舞广场的同伴正在等你。',19,muted)
  b+=actionPlate(339,364,282,'再去花园转转',true)
  b+=p('M230 428 Q480 440 731 428','none','#c5a574',1.15)+rivet(227,467)+rivet(737,467)
  b+=g(314,444,.84,menuAction(0,0,'dial','设置'))
  b+=g(480,444,.84,menuAction(0,0,'reel','新的一轮'))
  b+=g(646,444,.84,menuAction(0,0,'gate','保存并退出'))
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
for(const mode of ['title','new','blocked'])fs.writeFileSync(path.join(out,mode+'.svg'),titleState(mode))
