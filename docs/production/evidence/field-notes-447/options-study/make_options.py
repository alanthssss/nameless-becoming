"""Draw the settings cabinet and the binding register for the independent menu study."""
import argparse
import base64
import json
import re
import subprocess
from functools import lru_cache
from html import escape
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[4]
HOME = HERE.parent
WAX_REV = '3d44647'
INK, MUTED, JADE, LIGHT = '#403126', '#685642', '#315850', '#fff4dc'
SERIF = 'Songti SC, STSong, serif'
SANS = 'PingFang SC, Heiti SC, sans-serif'

def txt(x,y,s,n=18,fill=INK,anchor='start',serif=False,weight=450):
    return f'<text x="{x}" y="{y}" text-anchor="{anchor}" font-family="{SERIF if serif else SANS}" font-size="{n}" font-weight="{weight}" fill="{fill}">{escape(s)}</text>'

def shape(d, fill='none', edge='none', sw=1, attr=''):
    return f'<path d="{d}" fill="{fill}" stroke="{edge}" stroke-width="{sw}" stroke-linejoin="round" stroke-linecap="round" {attr}/>'

def box(x,y,w,h,r,fill,edge='none',sw=1):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{fill}" stroke="{edge}" stroke-width="{sw}"/>'

def grp(x,y,body,scale=1):
    return f'<g transform="translate({x} {y}) scale({scale})">{body}</g>'

def dot(x,y,r,fill,edge='none'):
    return f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}" stroke="{edge}"/>'

def bolt(x,y):
    return dot(x,y+1,3.2,'#a58752')+dot(x,y,3.2,'url(#brass)','#b29a6c')+shape(f'M{x-1.4} {y+0.8}l2.8 -1.8','none','#916f40',.9)

def colors(name,*stops):
    return f'<linearGradient id="{name}" x2="0%" y2="100%">'+''.join(f'<stop offset="{i/(len(stops)-1):.3f}" stop-color="{c}"/>' for i,c in enumerate(stops))+'</linearGradient>'

def source(name):
    return subprocess.check_output(['git','-C',str(REPO),'show',f'{WAX_REV}:prototypes/swarm-flight/region_game/{name}'])

@lru_cache(maxsize=None)
def encoded(name):
    data = source(name+'.png') if name.startswith('controls_wax_') else (HERE/(name+'.webp')).read_bytes()
    kind = 'png' if name.startswith('controls_wax_') else 'webp'
    return 'data:image/'+kind+';base64,'+base64.b64encode(data).decode()

def picture(name,x,y,w,h):
    return f'<image x="{x}" y="{y}" width="{w}" height="{h}" xlink:href="{encoded(name)}"/>'

def use(name,x,y,w,h):
    return f'<svg x="{x}" y="{y}" width="{w}" height="{h}" viewBox="0 0 32 32" preserveAspectRatio="none"><use xlink:href="#{name}"/></svg>'

def definitions():
    shared=(HOME/'shared-menu.svg').read_text()
    gradients=shared[shared.index('<defs>')+6:shared.index('<filter')]
    return gradients+colors('rail','#eee0bd','#e5d1a6','#ddc393')+colors('edge','#f9e6bd','#b8945e','#c7a772')+colors('jade','#57786a','#35594e','#29483e')+colors('pocket','#d5bd91','#eddab7','#f4e6c9')+colors('waxlight','#ffedb0','#e4ac4a','#aa6926')+''.join(f'<image id="{n}" width="32" height="32" xlink:href="{encoded(n)}"/>' for n in ['controls_wax_keycap','controls_wax_q'])

def svg(body,title):
    return f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="960" height="600" viewBox="0 0 960 600"><title>{escape(title)}</title><defs>{definitions()}</defs>{body}</svg>'

def frame():
    d='M69 25 Q226 12 343 20 Q482 28 653 19 Q783 13 898 25 Q929 29 930 59 L933 538 Q933 566 906 572 Q718 586 543 580 Q425 575 283 581 Q155 586 57 573 Q29 570 29 544 L32 63 Q33 33 69 25 Z'
    b=grp(0,6,shape(d,'#ab8756','#926e48',2))+shape(d,'url(#ceramic)','#bb9a67',2)
    b+=shape('M49 61 Q52 42 70 38 Q224 24 336 33 M631 32 Q785 23 898 37 Q915 40 916 60','none','#fff8e4',2)
    b+=shape('M52 547 Q51 560 69 562 Q210 575 332 566 M643 566 Q774 570 898 558','none','#d4b782',1.2)
    for x,y in [(51,54),(908,54),(50,549),(910,548)]: b+=bolt(x,y)
    return b

def rail():
    d='M88 111 Q149 93 213 99 Q253 103 279 119 L280 475 Q280 492 264 497 Q176 511 90 495 Q74 491 74 474 L74 134 Q74 118 88 111 Z'
    return shape(d,'url(#rail)','#c0a372',1.4)+shape('M82 456 V136 Q82 124 93 120 M272 454 V131','none','#f7eccc',1.3)

def nav_button(x,y,w,label,primary=False):
    d=f'M10 2 Q{w/2} -2 {w-9} 2 Q{w+1} 4 {w} 14 L{w-2} 26 Q{w-3} 33 {w-12} 34 Q{w/2} 37 12 34 Q4 34 2 26 L0 15 Q-1 5 10 2 Z'
    b=grp(0,2,shape(d,'#b29568'))+shape(d,'url(#jade)' if primary else 'url(#raised)','#71836a' if primary else '#b99a69')
    return grp(x,y,b+txt(w/2,24,label,17,LIGHT if primary else INK,'middle',True,650))

def cap(x,y,label,w=None,h=31):
    if not label:
        outline=shape(f'M{x-30} {y+h-4} h60','none','#b9a687',1,'stroke-dasharray="2 3"')
        return outline+txt(x,y+h*.67,'未绑定',15,MUTED,'middle')
    if w is None: w=max(32,12+sum(10 if ord(c)<128 else 15 for c in label))
    art='controls_wax_q' if label=='Q' else 'controls_wax_keycap'
    return use(art,x-w/2,y,w,h)+(txt(x,y+h*.66,label,16,'#583011','middle',False,650) if label!='Q' else '')

def switch(x,y,state):
    b=box(0,3,98,36,18,'#b49a70')+box(0,0,98,36,18,'url(#jade)' if state else 'url(#pocket)','#b29b73')
    cx=77 if state else 21
    b+=dot(cx,19,13.5,'#8f7146')+dot(cx,17,13,'url(#raised)','#b29562')+dot(cx,17,8,'none','#dec8a1')
    b+=txt(29 if state else 68,24,'开' if state else '关',17,LIGHT if state else MUTED,'middle',False,650)
    return grp(x,y,b)

def dance(x,y,title,chosen,focus,side):
    d='M10 2 Q71 -2 149 2 Q160 3 161 14 V62 Q161 71 151 73 Q77 80 11 73 Q0 71 0 59 V15 Q0 5 10 2 Z'
    b=grp(0,2,shape(d,'#bb9a69'))+shape(d,'url(#jade)' if chosen else 'url(#raised)','#9c8961')
    if focus: b+=shape('M8 -3 Q83 -9 152 -3 Q168 -1 167 14 V62 Q167 78 153 80 Q76 87 7 79 Q-6 77 -6 59 V14 Q-6 1 8 -3 Z','none',JADE,2.6)
    line='#ffe1a2' if chosen else '#976a37'
    ribbon='M47 24 C20 4 21 45 48 27 S81 7 82 20 S67 39 48 26' if not side else 'M35 20 Q47 9 54 20 T73 20 T93 19 M35 30 Q46 19 53 29 T73 29 T94 28'
    b+=shape(ribbon,'none',line,2.4,'stroke-dasharray="3.3 3"')+dot(95 if side else 82,20,3.3,line)
    b+=txt(80,59,title,18,LIGHT if chosen else INK,'middle',True,650)
    if chosen:b+=shape('M135 13 l4 4 l8 -9','none','#ffde94',2.3)
    return grp(x,y,b)

def option_page(about=False,reduced=False):
    b=frame()+rail()+txt(77,78,'设置',38,INK,'start',True,700)
    if not about:
        b+='<ellipse cx="174" cy="341" rx="67" ry="7" fill="#96764d" opacity=".18"/>'+picture('music-box',79,182,197,166)+txt(175,386,'Honey',32,'#71583a','middle',True,700)+txt(175,418,'Demo 0.32.7',16,MUTED,'middle')
        b+=shape('M119 435 Q170 441 230 435','none','#ad8f61')+dot(175,440,2,'#ac8a57')
    b+=txt(328,151,'声音',25,INK,'start',True,650)+switch(751,120,True)+shape('M325 173 Q560 175 872 173','none','#cbb48d')
    b+=txt(328,216,'简化动画',25,INK,'start',True,650)+switch(751,186,reduced)+shape('M325 238 H872','none','#cbb48d')
    b+=txt(328,292,'蜂舞',25,INK,'start',True,650)
    group=dance(485,254,'摆尾回环',True,False,False)+dance(684,254,'侧步摆肩',False,not reduced and not about,True)
    b+=f'<g opacity="{.52 if reduced else 1}">{group}</g>'
    if reduced:b+=txt(486,353,'简化动画已开启',15,MUTED)
    if reduced:b+=box(746,181,108,46,22,'none',JADE,2.6)
    b+=shape('M325 365 H872','none','#cbb48d')+txt(328,412,'键位设置',25,INK,'start',True,650)+nav_button(696,384,158,'查看或改键　›')
    b+=shape('M325 440 H872','none','#cbb48d')+txt(328,481,'关于',25,INK,'start',True,650)+nav_button(758,453,95,'收起　⌃' if about else '查看　›')
    b+=shape('M83 510 Q503 513 868 510','none','#bea277')+nav_button(82,524,114,'‹　返回')
    if about:
        b+=box(753,448,105,46,16,'none',JADE,2.6)
        plate=shape('M9 2 Q134 -3 226 2 Q236 3 236 14 V322 Q236 333 224 334 Q111 340 10 334 Q0 333 0 323 V13 Q0 4 9 2 Z','url(#raised)','#b29465')
        plate+=txt(20,38,'Honey',32,INK,'start',True,700)+txt(20,67,'Demo 0.32.7',17,MUTED)
        lines=['制作　Alan × Codex','Godot Engine（MIT）','画面含 AI 辅助生成的预制','美术，运行时不调用生成式 AI。','蜂舞取意于蜜蜂通信，','侧步摆肩为原创动作。','设计研究参考 Shelldiver，','未使用其图像、音乐或代码。']
        for i,line in enumerate(lines):plate+=txt(15,104+i*27,line,15,INK)
        b+=grp(59,124,plate)
    return svg(b,'设置与关于' if about else '设置')

ACTIONS=['向上飞','向下飞','向左飞','向右飞','互动 / 采集','振翅','蓄力冲刺','暂停','静音']
KEYS=[['W','↑'],['S','↓'],['A','←'],['D','→'],['E'],['Q'],['空格'],['Esc'],['M']]
MOUSE=['','','','','鼠标左键','鼠标右键','','','']
PAD=['十字键↑','十字键↓','十字键←','十字键→','A（下）','X（左）','RB','Start','']
SECTIONS=['飞行','菜单','成长树','花湾']
SHORTCUTS=json.loads(re.sub(r',\s*([}\]])',r'\1',source('controls_page.gd').decode().split('const SHORTCUTS := ',1)[1].split('\nconst REBIND_HINT',1)[0].strip()))
def context_tab(x,y,label,selected):
    d='M8 1 Q79 -2 155 1 L171 16 L155 32 Q80 35 8 33 Q1 32 1 26 V8 Q1 2 8 1 Z'
    b=shape(d,'url(#jade)' if selected else 'url(#raised)','#8c8664' if selected else '#c4a979')
    if selected:b+=dot(15,17,3.2,'#f2c373')
    return grp(x,y,b+txt(82,24,label,19,LIGHT if selected else INK,'middle',True,650))

def caps(left,y,items,h=31,note=''):
    if not any(items):
        underline=shape(f'M{left} {y+h-4} h54','none','#b9a687',1,'stroke-dasharray="2 3"')
        return underline+txt(left,y+h*.67,'未绑定',15,MUTED)

    gap=24
    x=left
    result=''
    for i,name in enumerate(items):
        if i:
            result+=txt(x+gap/2,y+h*.67,'或',13,MUTED,'middle')
            x+=gap
        width=max(32,12+sum(9 if ord(c)<128 else 15 for c in name))
        result+=cap(x+width/2,y,name,width,h)
        x+=width
    if note:
        result+=txt(x+14,y+h*.67,note,14,MUTED)
    return result

def bindings_page(section='飞行',pad=False,state='normal'):
    b=frame()+rail()+txt(77,78,'键位设置',38,INK,'start',True,700)
    b+='<ellipse cx="177" cy="249" rx="74" ry="5" fill="#987549" opacity=".21"/>'+picture('key-machine',80,121,195,133)
    for i,s in enumerate(SECTIONS):b+=context_tab(91,278+i*48,s,s==section)
    b+=nav_button(472,49,173,'键盘和鼠标',not pad)+nav_button(662,49,169,'游戏手柄',pad)
    b+=shape('M318 107 Q580 103 879 108','none','#ac905e',1.5)
    flight=section=='飞行'
    action_left,keys_left,mouse_left=330,500,714
    b+=txt(action_left,139,'动作',16,MUTED)
    key_heading=('手柄按钮' if pad else '键盘') if flight else '固定按键'
    b+=txt(keys_left,139,key_heading,16,MUTED)
    if flight and not pad:
        b+=txt(mouse_left,139,'鼠标',16,MUTED)
    b+=shape('M321 151 H873','none','#d0b68a')
    if flight:
        for i,action in enumerate(ACTIONS):
            y=153+i*37
            if i==5 and state!='reset':
                b+=box(317,y+1,559,35,8,'#e4dec2')+shape(f'M317 {y+7}q-9 10 0 22 l7 -11 z',JADE)
            b+=txt(action_left,y+25,action,18,INK,weight=600 if i==5 else 450)
            if i==5 and state!='reset':
                edge='#995336' if state=='conflict' else JADE
                b+=box(keys_left-8,y+1,152,34,9,'#f4e1b9' if state=='waiting' else '#f3d3b4' if state=='conflict' else 'none',edge,2.7)
            if i==5 and state in ['waiting','conflict']:
                b+=txt(keys_left,y+25,'等待输入…' if state=='waiting' else '请换一个键',17,INK,weight=650)
            elif pad: b+=caps(keys_left,y+3,[PAD[i]])
            else:b+=caps(keys_left,y+3,['J'] if i==5 and state=='saved' else KEYS[i])
            if not pad:b+=caps(mouse_left,y+3,[MOUSE[i]])
            b+=shape(f'M325 {y+36} H873','none','#d5c098',.8)
    else:
        listed=[row for row in SHORTCUTS[section] if row[2 if pad else 1]]
        step=min(49,330//len(listed))
        for i,row in enumerate(listed):
            y=154+i*step
            b+=txt(action_left,y+23,row[0],17)
            names=row[2 if pad else 1].split(' / ')
            note=row[4 if pad else 3] if len(row)>(4 if pad else 3) else ''
            b+=caps(keys_left,y+2,names,min(31,step-3),note)
            b+=shape(f'M325 {y+step-1} H873','none','#d5c098',.8)
    notes={'normal':'朝蜂头振翅，按住连发','waiting':'为「振翅」按下新的键。Esc 或手柄 B 取消。','conflict':'此键已用于「静音」。请换一个键，或按 Esc 取消。','reset':'已恢复键鼠和手柄的默认按键。','saved':'已保存 · 振翅　J','cancel':'已取消，原按键保留。'}
    if flight:b+=txt(326,513,notes[state],16,'#8f452f' if state=='conflict' else MUTED)
    b+=shape('M78 525 Q452 529 871 524','none','#bfa77e')
    b+=nav_button(80,534,133,'‹　返回设置')
    if flight:b+=nav_button(710,534,154,'恢复默认按键')
    if state=='reset':b+=box(705,529,164,45,15,'none',JADE,2.6)
    return svg(b,'键位设置 · '+section+' · '+('游戏手柄' if pad else '键鼠'))

def build(out):
    out.mkdir(parents=True,exist_ok=True)
    pages={'settings':option_page(),'settings-about':option_page(about=True),'settings-motion':option_page(reduced=True),'controls':bindings_page()}
    for i,section in enumerate(SECTIONS):
        for pad in [False,True]:
            if i==0 and not pad:continue
            pages[f'controls-{i}-'+('pad' if pad else 'kbm')]=bindings_page(section,pad)
    for state in ['waiting','conflict','saved','cancel','reset']:pages['controls-'+state]=bindings_page(state=state)
    for name,page in pages.items():(out/(name+'.svg')).write_text(page)
if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('out',type=Path)
    build(parser.parse_args().out)
