"""Place the field HUD, action prompts and receipts on unlettered native game stills."""
import argparse
import base64
from functools import lru_cache
from io import BytesIO
import json
import math
from pathlib import Path
import sys
from PIL import Image

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parent/'options-study'))
import make_options as ui

ART=ui.REPO/'prototypes/swarm-flight/art'
def image(im,x,y,w,h):
    buf=BytesIO()
    im.save(buf,'WEBP',quality=91,method=5)
    data=base64.b64encode(buf.getvalue()).decode()
    return f'<image x="{x}" y="{y}" width="{w}" height="{h}" xlink:href="data:image/webp;base64,{data}"/>'

@lru_cache(maxsize=None)
def icon(name):
    specs={'金币':('nectar-resource-icons.png',(100,120,555,585)), '纤维':('nectar-resource-icons.png',(669,108,1179,588)), '树脂':('nectar-resin-chunks.png',(190,165,1000,1055)),'花蜜':('nectar-honey-jar.png',(225,240,1025,1030))}
    fname,crop=specs[name]
    im=Image.open(ART/fname).convert('RGBA').crop(crop)
    im.thumbnail((64,64))
    return image(im,0,0,24,24)

@lru_cache(maxsize=None)
def bee(tired):
    face=Image.open(ART/'honey-energy-poses.png').convert('RGBA')
    pose=5 if tired else 0
    x,y=pose%3*256,pose//3*256
    body=face.crop((x,y,x+256,y+256))
    wing=Image.open(ART/'honey-bee.png').convert('RGBA').crop((512,0,1024,512))
    size=(264,183) if tired else (256,256)
    offset=(round((256-size[0])*.39),round((256-size[1])*.435))
    im=Image.new('RGBA',(256,256)); im.alpha_composite(wing.resize(size,Image.Resampling.LANCZOS),offset); im.alpha_composite(body)
    im.thumbnail((110,110))
    return image(im,0,0,49,49)

def plaque(d,fill='url(#ceramic)'):
    return ui.grp(0,2,ui.shape(d,'#92734b','#816a46',1.6))+ui.shape(d,fill,'#bea274',1.5)

def hud(a,low):
    b=plaque('M37 7 Q65 1 121 5 Q207 0 301 6 Q324 7 326 23 L327 61 Q327 75 309 77 Q176 82 57 78 Q25 81 11 63 C-1 44 3 21 18 13 Z')
    b+=ui.dot(45,41,39,'url(#raised)','#ae8954')+ui.dot(45,41,34,'#6c6149','#ece0bd')+ui.dot(45,41,30,'#f6e6be')
    value=a['energy']/a['maximum']
    end=-math.pi/2+2*math.pi*min(.997,value)
    b+=ui.shape(f'M45 7 A34 34 0 {int(value>.5)} 1 {45+34*math.cos(end):.2f} {41+34*math.sin(end):.2f}','none','#ac5237' if low else ui.JADE,4.7)
    b+=ui.grp(20,12,bee(low))+ui.box(15,59,60,18,8,'#ffeaca','#bea171')+ui.txt(45,72,f"{int(a['energy'])} / {int(a['maximum'])}",13,ui.INK,'middle',weight=700)
    for i,(name,value) in enumerate([('金币',str(a['coins'])),('纤维',str(a['fiber'])),('树脂',str(a['resin'])),('花蜜',f"{a['honey']} / {a['capacity']}")]):
        x=88+(i%2)*113;y=12+(i//2)*31
        b+=ui.grp(x,y,icon(name))+ui.txt(x+28,y+18,name,14,ui.MUTED)+ui.txt(x+104,y+18,value,15,ui.INK,'end',weight=650)
    b+=ui.shape('M92 42 H309','none','#d2bb93',.8)
    return ui.grp(17,498,b)

def pause():
    b=ui.dot(0,2,20,'#8e744f')+ui.dot(0,0,20,'url(#raised)','#bba072')
    b+=ui.box(-6,-7,3.8,14,1.6,ui.JADE)+ui.box(2,-7,3.8,14,1.6,ui.JADE)
    return ui.grp(916,551,b)

def pill(x,y,width,label,keys=(),alert=False,pointer=True,arrow=None,hold=False,gauge=False):
    # The tail registers the prompt to the resource. The old sign and flower remain exposed.
    title_width=sum(8 if ord(c)<128 else 16 for c in label)
    key_width=sum(max(28,9+sum(8 if ord(c)<128 else 14 for c in key))+4 for key in keys)
    prefix=46 if arrow is not None else 42 if gauge else 13
    width=max(width,prefix+35*int(hold)+key_width+19*max(0,len(keys)-1)+title_width+15)
    d=f'M11 2 Q{width*.4:.0f} -1 {width-13} 2 Q{width-2} 3 {width} 13 V28 Q{width} 36 {width-11} 38 Q{width/2+8} 40 {width/2+6} 39 '
    d+=f'L{width/2} 47 L{width/2-5} 39 ' if pointer else ''
    d+='Q44 40 9 37 Q0 35 0 25 V15 Q0 5 11 2 Z'
    b=ui.grp(0,2,ui.shape(d,'#433a2b'))+ui.shape(d,'#793e2b' if alert else 'url(#jade)','#d9bf8d',1.3)
    lead=13
    if arrow is not None:
        b+=f'<g transform="translate(25 20) rotate({arrow:.1f})">'+ui.shape('M11 -3 H-1 V-8 L-12 0 L-1 8 V3 H11 Z','#ffe5a5')+'</g>'
        lead=46
    if gauge:
        b+=ui.dot(21,20,12.5,'#f9e6b7','#c49f5b')+ui.shape('M21 11 C19 16 15 19 16 23 C18 29 27 27 26 22 Q25 17 21 11 Z','#e5a039','#986229')
        lead=42
    if hold:b+=ui.txt(lead,26,'按住',15,ui.LIGHT);lead+=35
    for i,k in enumerate(keys):
        if i:b+=ui.txt(lead+8,25,'或',13,'#efdfba','middle');lead+=19
        w=max(28,9+sum(8 if ord(c)<128 else 14 for c in k))
        b+=ui.cap(lead+w/2,4.2,k,w,29);lead+=w+4
    b+=ui.txt(lead,26,label,16,ui.LIGHT,weight=600)
    return ui.grp(max(8,min(952-width,x-width/2)),max(8,min(518,y)),b)

def receipt(kind, gain):
    d='M13 1 Q62 -2 119 2 Q133 3 132 15 L130 33 Q130 41 120 42 Q65 45 12 41 L0 24 Z'
    b=plaque(d)+ui.grp(12,9,icon(kind))+ui.txt(44,28,f'{kind} +{gain}',19,ui.INK,weight=700)
    return ui.grp(33,448,b)

def field_page(key,a,original):
    low=key=='tired'
    b=image(Image.open(original).convert('RGB'),0,0,960,600)
    x,y=a['target'];bx,by=a['bee']
    if key=='return':
        b+=pill(x-39,y-102,194,'回庭院',('E','鼠标左键'))
    elif key=='flower':
        b+=pill(x,y-82,239,'采蜜',('E','鼠标左键'),hold=True,gauge=True)
    elif key=='gathering':
        b+=pill(x,y-81,115,'采蜜中',gauge=True)
        b+=ui.shape(f'M{x-13} {y-36} a14 14 0 1 1 25 10','none','#ffe3a0',2.7)
    elif key=='fiber':
        b+=pill(x,y-87,244,'朝种穗振翅取绒',('Q','鼠标右键'))
    elif key=='resin':
        b+=pill(x,y-89,198,'朝裂口振翅掀皮',('X（左）',))
    elif key=='open':
        b+=pill(x,y-89,188,'收树脂',('A（下）',),hold=True)
    elif key=='pickup':
        b+=receipt('纤维',1)
    elif key=='full':
        b+=pill(x,y-81,118,'蜜囊已满',gauge=True)+pill(156,448,234,'蜜囊已满 · 仍可取材',pointer=False)
    elif low:
        hx,hy=a['home']
        angle=math.degrees(math.atan2(hy-by,hx-bx))-180
        b+=pill(bx,by-106,181,'体力低 · 回庭院',alert=True,pointer=False,arrow=angle)
    return ui.svg(b+hud(a,low)+pause(),'野外操作 · '+key)

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('native',type=Path)
    parser.add_argument('out',type=Path)
    args=parser.parse_args()
    for key,a in json.loads((args.native/'anchors.json').read_text()).items():
        (args.out/('field-'+key+'.svg')).write_text(field_page(key,a,next(p for p in [args.native/(key+'.webp'),args.native/(key+'.png')] if p.is_file())))
