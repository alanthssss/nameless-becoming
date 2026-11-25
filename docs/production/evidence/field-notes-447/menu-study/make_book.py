"""Compose the #447 review book from editable menu layers and frozen Mac references."""
import argparse
from io import BytesIO
from pathlib import Path
from subprocess import run
from PIL import Image
from reportlab import rl_config
from reportlab.lib.colors import HexColor
from reportlab.lib.utils import ImageReader
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas

rl_config.useA85 = False
parser = argparse.ArgumentParser()
parser.add_argument('output', type=Path)
parser.add_argument('work', type=Path)
parser.add_argument('key_screens', type=Path, help='Original #452 Mac screenshots directory')
parser.add_argument('field_screens', type=Path, help='Original #451 Mac screenshots directory')
parser.add_argument('--font', default='/System/Library/Fonts/Supplemental/Arial Unicode.ttf')
args = parser.parse_args()
here = Path(__file__).resolve().parent
study = here.parent
work = args.work
work.mkdir(parents=True, exist_ok=True)
run(['node', str(here/'plates.cjs'), str(work)], check=True)
for src in [*work.glob('*.svg'), study/'shared-menu.svg', study/'options-study'/'settings.svg',study/'options-study'/'controls.svg']:
    run(['rsvg-convert','-z','1.5',str(src),'-o',str(work/(src.stem+'.png'))],check=True)
pdfmetrics.registerFont(TTFont('ReviewSans',args.font))
page_w,page_h=960,656
pdf=canvas.Canvas(str(args.output),pagesize=(page_w,page_h),pageCompression=1)
pdf.setTitle('Honey · 通用界面设计审阅')
pdf.setAuthor('Codex · Honey')
pdf.setSubject('通用界面独立菜单层、交互状态及 #452 实机参照')
pdf.setCreator('Honey UI art review')
ink='#333b33'; muted='#626a5f'; ring='#bebcac'
def text(x,y,words,size=15,color=ink,align='left'):
    pdf.setFont('ReviewSans',size);pdf.setFillColor(HexColor(color))
    fn=pdf.drawRightString if align=='right' else pdf.drawString
    fn(x,page_h-y,words)
def line(x,y,xx,yy,c=ring):
    pdf.setStrokeColor(HexColor(c)); pdf.setLineWidth(.65);pdf.line(x,page_h-y,xx,page_h-yy)
def begin(key,title,kind='菜单层设计稿'):
    pdf.bookmarkPage(key);pdf.addOutlineEntry(title,key,level=0,closed=False)
    pdf.setFillColor(HexColor('#efeee7'));pdf.rect(0,0,page_w,page_h,stroke=0,fill=1)
    text(36,45,title,26)
    text(924,43,kind,15,muted,'right');line(36,63,924,63)
def finish(caption):
    line(36,602,924,602)
    text(37,631,caption,14,muted)
    text(923,632,str(pdf.getPageNumber()),13,muted,'right')
    pdf.showPage()
def load(name):
    return Image.open(work/(name+'.png')).convert('RGBA')
def plate(image,x=31,y=73,w=898,h=518):
    if isinstance(image,str):
        image=load(image)
        bounds=image.getchannel('A').getbbox()
        if bounds:image=image.crop(bounds)
    scale=min(w/image.width,h/image.height)
    iw,ih=image.width*scale,image.height*scale
    ox=x+(w-iw)/2;oy=y+(h-ih)/2
    if isinstance(image,Image.Image) and getattr(image,'filename','') and image.filename.endswith('.png'):
        encoded=ImageReader(image)
    else:
        flat=Image.new('RGB',image.size,'#efeee7')
        if image.mode=='RGBA':flat.paste(image,mask=image.getchannel('A'))
        else:flat.paste(image)
        data=BytesIO()
        flat.save(data,format='JPEG',quality=94,subsampling=0,optimize=True)
        data.seek(0)
        encoded=ImageReader(data)
    pdf.drawImage(encoded,ox,page_h-oy-ih,iw,ih,mask='auto')
    return ox,oy,iw,ih
def one(key,title,image,caption,kind='菜单层设计稿'):
    begin(key,title,kind);plate(image);finish(caption)
def excerpt(image,logical_size,box):
    factor=image.width/logical_size
    return image.crop(tuple(round(v*factor) for v in box))
def nav(x,y,title,dest):
    text(x,y,title,16,'#315850')
    pdf.linkRect(title,dest,(x,page_h-y-4,x+pdfmetrics.stringWidth(title,'ReviewSans',16),page_h-y+17),relative=0,thickness=0)

begin('menu','共用菜单','Honey　·　通用界面美术审阅　·　2026.11.26')
plate('shared-menu',34,73,445,519)
text(522,116,'启动和暂停用同一张菜单',23)
text(522,155,'有档时「继续采蜜」读取当前档，暂停时接着飞。',15)
text(522,183,'首次出发显示「从蜂巢出发」。',15)
text(522,211,'存档无法读取时，先进入备份确认。',15)
line(521,238,901,238)
text(522,278,'这一册',19)
for x,y,label,dest in [
    (522,318,'选档','slots'),(704,318,'备份与重开','restart'),
    (522,360,'选择花路','routes'),(704,360,'花路手册','guide'),
    (522,402,'设置','settings'),(704,402,'键位设置 · #452','controls'),
    (522,444,'储粮完成','complete'),(704,444,'焦点与返回','feedback'),
    (522,486,'野外提示 · #448','field')]:
    nav(x,y,label,dest)
text(522,558,'当前认可项：飞行蜂原画及左上背景柔影。',15,muted)
finish('左侧为暂停示例，输入焦点停在「设置」。点右侧目录可直接跳页。')
one('controls','键位设置',excerpt(load('controls'),960,(0,0,960,600)),
    '键鼠飞行九行同屏。每个备选键各有一枚蜡帽，外圈标出正在浏览的单元格。','设计稿　／　同步主线 #452')
begin('control-states','改键时的反馈','设计稿　／　同步主线 #452')
plate(excerpt(load('controls'),960,(0,608,960,951)),35,125,890,370)
text(56,115,'等待、冲突和恢复结果沿用同一反馈位置。',18)
text(58,548,'飞行绑定可修改。菜单、成长树和花湾按当前设备显示固定速查。',18)
finish('相同操作的其他键用「或」分开。冲突时给出占用动作，取消后回到原单元格。')
one('native-controls','新版键位设置 · Mac 实机',Image.open(args.key_screens/'flight-kbm-960x600.png'),
    '2026-11-26 的 #452 实包原图，960 × 600。用于对照上两页的键帽、分栏及底部按钮。','原始实机截图　／　#452')
one('settings','设置与关于','settings',
    '声音与简化动画直接写开或关。摆尾回环已选，浏览外圈在侧步摆肩。关于就在本页展开。')
one('slots','选择存档','slots',
    '存档 1 有「当前」标记。浏览外圈在空的存档 2，存档 3 写明无法读取。示例资源为排版样本。')
one('restart','备份与重开','restart',
    '标题指明影响存档 1。默认焦点在取消，确认项写全「备份并重新开始」。取消后回到打开确认的入口。')
begin('title-states','主菜单随存档变化','同一菜单的局部状态')
for n,(key,title) in enumerate([('title','已有进度'),('new','首次出发'),('blocked','进度无法读取')]):
    y=88+n*155
    text(51,y+61,title,19)
    plate(excerpt(load(key),451,(36,78,415,239)),218,y,684,147)
    if n<2:line(50,y+149,908,y+149)
finish('三个局部取自同一布局。进度无法读取时先进入确认，先备份原文件，再开始新的一轮。')
one('routes','选择花路','routes',
    '两张卡按地貌、地名、蜜价与材料顺序阅读。锁定地点保留地貌，说明要在哪里解锁。')
one('routes-open','花路解锁后','routes-open',
    '开放后紫花地在原位写出树脂采法，焦点可以移到整张卡。')
one('guide','花路手册 · 池岸','guide',
    '地区标签、地图在左，标本、采法与售价在右。可翻到紫花地或展开归途须知。')
one('guide-open','花路手册 · 紫花地','guide-violet',
    '归途须知在右页就地展开，保留当前地区和浏览焦点。')
one('complete','储粮完成','complete',
    '先读「花蜜，备好了」，再决定是否重返花园。设置、重开、退出复用菜单里的整枚入口。')
begin('feedback','操作状态与返回')
plate('feedback',15,62,930,428)
for y,line_text in [(481,'选择存档 → 返回 → 原菜单的「选择存档」'),
                    (512,'花路手册 → 返回 → 暂停菜单的「花路手册」'),
                    (543,'键位设置 → 返回设置 →「查看或改键」'),
                    (574,'新的一轮 → 取消 → 原菜单的「新的一轮」')]:
    text(125,y,line_text,16)
finish('浅底悬停，连续外圈表示键盘或手柄焦点，压下时座沿缩短。这里展示设计行为。')
one('field','池岸与紫花地的提示','field',
    '采集动作贴资源，拾取只报本次数量，低体力同时给方向和文字。按键文字随设备和绑定更新。','野外独立叠层色样　／　#448')
begin('native-field','野外提示的现场参照','旧审阅包实机　／　#448')
for y,filename,label in [(81,'14-pond.png','池岸花丛'),(337,'14-meadow.png','紫花地')]:
    plate(Image.open(args.field_screens/filename),70,y,544,244)
    text(636,y+96,label,23)
    if 'pond' in filename:text(636,y+132,'蓝花、种穗与庭院入口',15,muted)
    else:text(636,y+132,'紫花、树皮裂口与庭院入口',15,muted)
finish('两张完整窗口均直接取自 #451 的 960 × 600 取样，用来核对复杂底色，不代表新稿已经实装。')
pdf.save()
