#!/usr/bin/env python3
"""Build a review PDF from editable JSON and real native captures. No invented screenshots."""
import argparse,json
from pathlib import Path
from reportlab.pdfgen import canvas
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import Paragraph
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.colors import HexColor
from reportlab.lib.utils import ImageReader
ROOT=Path(__file__).resolve().parents[1]
def build(evidence,output,font):
    data=json.loads((ROOT/'docs/art/nectar-demo-art-review.json').read_text())
    pdfmetrics.registerFont(TTFont('CJK',str(font),subfontIndex=0))
    c=canvas.Canvas(str(output),pagesize=(960,720))
    c.setTitle(data['title']+' | '+data['subtitle']);c.setAuthor('Alan × Codex')
    ink=HexColor('#294d40'); muted=HexColor('#67765a'); gold=HexColor('#eccb7c')
    style=ParagraphStyle('body',fontName='CJK',fontSize=12.5,leading=20,textColor=ink,wordWrap='CJK')
    def text(words,x,y,w,size=12.5):
        local=ParagraphStyle('local',parent=style,fontSize=size,leading=size*1.6)
        p=Paragraph(words,local); _,h=p.wrap(w,1000)
        p.drawOn(c,x,y-h); return y-h-13
    def pic(path,x,y,w,h):
        if not path.is_file(): raise FileNotFoundError(path)
        im=ImageReader(str(path)); iw,ih=im.getSize(); scale=min(w/iw,h/ih)
        c.drawImage(im,x+(w-iw*scale)/2,y+(h-ih*scale)/2,iw*scale,ih*scale,mask='auto')
    for n,page in enumerate(data['pages'],1):
        c.setFillColor(HexColor('#f5f0df'));c.rect(0,0,960,720,fill=1,stroke=0)
        c.setFillColor(ink);c.rect(0,706,960,14,fill=1,stroke=0)
        c.setFont('CJK',10);c.setFillColor(muted);c.drawString(40,674,page['kicker'])
        c.setFillColor(ink);c.setFont('CJK',27);c.drawString(40,632,page['title'])
        c.setStrokeColor(HexColor('#c6cbae'));c.line(40,48,920,48)
        c.setFont('CJK',9);c.setFillColor(muted);c.drawString(40,29,data['subtitle']+' · '+data['date'])
        c.drawRightString(920,29,f'{n:02d} / {len(data["pages"]):02d} · 供评审，未获专家验收')
        layout=page.get('layout','image')
        if layout=='image':
            pic(evidence/page['image'],40,245,550,350)
            y=590
            for para in page['body']: y=text(para,620,y,300,12)
            if y<68: raise ValueError(f'text overflow page {n}')
            text('原生截图；展示开发者操作或明确标注的测试夹具，不代表外部玩家反馈。',40,218,540,10)
        elif layout=='assets':
            for i,name in enumerate(['nectar-dance-stage.png','nectar-honey-shop.png','nectar-field-book.png']):
                c.setFillColor(HexColor('#dbe5d4'));c.roundRect(40+i*300,325,280,270,10,fill=1,stroke=0)
                pic(ROOT/'prototypes/swarm-flight/art'/name,48+i*300,333,264,254)
                text(name,48+i*300,316,264,10)
            y=270
            for para in page['body']: y=text(para,40,y,880)
        elif layout=='palette':
            for i,(color,label) in enumerate([('#294d40','深叶绿 / 信息底'),('#f5edcf','奶油白 / 纸张'),('#eccb7c','蜂蜜金 / 主动作'),('#687957','灰绿 / 次文字'),('#a9beac','浅绿 / 辅助'),('#9073ad','紫花 / 高值资源')]):
                c.setFillColor(HexColor(color));c.roundRect(40+i*148,520,132,70,7,fill=1,stroke=0)
                text(color+'<br/>'+label,40+i*148,508,132,10)
            y=440
            for para in page['body']: y=text(para,40,y,880)
        elif layout=='map':
            c.setStrokeColor(HexColor('#a5b69a'));c.setLineWidth(4);c.line(110,526,840,526)
            for i,(label,sub) in enumerate([('蜜铺','交付与可见储备'),('成长书屋','能力选择'),('观测台','资源与风险'),('蜂舞广场','目的地与出发')]):
                x=70+i*224;c.setFillColor(gold);c.circle(x+65,526,32,fill=1,stroke=0)
                text(label,x,468,180,17);text(sub,x,435,180,11)
            y=375
            for para in page['body']: y=text(para,40,y,880)
        elif layout=='motion':
            pic(evidence/page['image'],40,315,470,290)
            y=592
            for para in page['body']: y=text(para,550,y,370,11.5)
            phases=[('起步',.18),('摆尾 / 回环',1.19),('光幕',.18),('抵达',.5)]
            x=40
            for i,(label,duration) in enumerate(phases):
                w=470*duration/2.05;c.setFillColor([gold,HexColor('#afc896'),HexColor('#d6dfbf'),HexColor('#b2cabb')][i]);c.rect(x,246,w,26,fill=1,stroke=0)
                text(label,x,235,max(w,65),9);x+=w
            text('0s                         1.37s  1.55s                       2.05s',40,200,470,10)
        elif layout=='review':
            y=594
            for para in page['body']:
                y=text(para,40,y,880,12)
                if para[0] in 'ABCDEF':
                    c.setStrokeColor(HexColor('#ccd1bd'));c.line(40,y,920,y);y-=15
        else:
            y=590
            for para in page['body']: y=text(para,40,y,880,14)
        c.showPage()
    c.save()
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--evidence-root',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--font',type=Path,default=Path('/System/Library/Fonts/STHeiti Light.ttc'));a=p.parse_args()
    a.output.parent.mkdir(parents=True,exist_ok=True);build(a.evidence_root,a.output,a.font)
