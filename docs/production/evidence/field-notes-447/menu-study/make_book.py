"""Compose the #447 review book from editable menu layers and frozen Mac references."""
import argparse
from io import BytesIO
from pathlib import Path
from subprocess import run
import sys
import shutil
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
parser.add_argument('field_screens', type=Path, nargs='?', help='Earlier field references, retained for older invocations')
parser.add_argument('--font', default='/System/Library/Fonts/Supplemental/Arial Unicode.ttf')
args = parser.parse_args()
here = Path(__file__).resolve().parent
study = here.parent
work = args.work
work.mkdir(parents=True, exist_ok=True)
run(['node', str(here/'plates.cjs'), str(work)], check=True)
run([sys.executable, '-B', str(study/'options-study'/'make_options.py'), str(work)], check=True)
run([sys.executable, '-B', str(here/'make_field.py'), str(here/'field-plates'), str(work)], check=True)
shutil.copyfile(study/'shared-menu.svg', work/'shared-menu.svg')
for src in sorted(work.glob('*.svg')):
    run(['rsvg-convert','-z','1.5',str(src),'-o',str(work/(src.stem+'.png'))],check=True)
pdfmetrics.registerFont(TTFont('ReviewSans',args.font))
page_w,page_h=960,656
pdf=canvas.Canvas(str(args.output),pagesize=(page_w,page_h),pageCompression=1)
pdf.setTitle('Honey · 通用界面设计审阅')
pdf.setAuthor('Alan')
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

begin('menu','共用菜单','Honey　·　通用界面设计')
plate('shared-menu',25,78,478,506)
text(528,127,'启动与暂停',26)
text(529,167,'有档可继续，出行时可从这里回到现场。',16)
line(525,191,919,191)
for x,y,label,dest in [
    (528,230,'设置与蜂舞','settings'),(708,230,'键位设置','controls'),
    (528,278,'选择存档','slots'),(708,278,'备份与重开','restart'),
    (528,326,'选择花路','routes'),(708,326,'花路手册','guide'),
    (528,374,'储粮完成','complete'),(708,374,'野外操作','field-flower'),
    (528,422,'拾取与满囊','field-pickup'),(708,422,'低体力返程','field-tired')]:
    nav(x,y,label,dest)
text(529,531,'左图为暂停时聚焦「设置」的样子。',15,muted)
finish('共用菜单保留小蜂原画，左上翼后的柔影落在底板上。')
one('settings','设置','settings','摇柄音乐盒配开关。两种蜂舞各有舞迹，勾表示已选，外圈表示当前浏览位置。')
one('controls','键位设置 · 飞行','controls','按设备分栏，按场景换左签。可单独修改鼠标、键盘或手柄的绑定，焦点环包住整格。')
begin('states','振翅改键','设计状态　／　#452')
for i,(name,title,detail) in enumerate([('controls-waiting','等待输入','输入目标还在原格。'),
                                        ('controls-conflict','输入已占用','提示哪个操作占用了键。'),
                                        ('controls-saved','已保存','新键显示在振翅这一行。'),
                                        ('controls-cancel','已取消','原来的 Q 键仍在。')]):
    y=92+i*122
    text(42,y+23,title,20)
    text(42,y+51,detail,14,muted)
    im=load(name)
    plate(excerpt(im,960,(311,333,879,377)),260,y,637,51)
    plate(excerpt(im,960,(320,487,880,519)),261,y+53,630,36)
    line(40,y+98,918,y+98)
finish('所有样例均对应同一格。恢复默认同时还原键鼠和手柄绑定。')
one('pad','游戏手柄 · 飞行','controls-0-pad','手柄只列手柄按钮，九个动作维持相同顺序。')
one('reference','键盘与鼠标 · 成长树速查','controls-2-kbm','固定操作给出所有备选输入。菜单、成长树、花湾各自有键鼠和手柄两种视图。')
one('about','设置 · 关于','settings-about','关于在本页展开，显示游戏版本、制作人和引擎许可。')
one('slots','选择存档','slots','挂牌上列档号和进度。「当前」织带与输入焦点分别标出正在使用和正在浏览的档。')
one('restart','备份与重开','restart','重开页的线轴来自同一个菜单入口。标题指明当前档，默认焦点落在取消。')
begin('title-states','同一菜单随存档变化')
for n,(key,title) in enumerate([('title','已有进度'),('new','首次出发'),('blocked','无法读取')]):
    y=83+n*160
    text(50,y+69,title,20)
    plate(excerpt(load(key),451,(29,80,419,240)),218,y,702,155)
    if n<2:line(50,y+155,908,y+155)
finish('首次可直接出发。有档时继续；读档失败时由备份确认承接。')
one('routes','选择花路','routes','两地从同一张折地图上出发。紫花地尚未开放时，保留地貌、蜜价与解锁说明。')
one('routes-open','选择花路 · 紫花地已开放','routes-open','开放后可选紫花地出发，原位置给出掀皮与采树脂的办法。')
one('guide','花路手册 · 池岸','guide','放大镜标出当前地点。右页在蓝花和种穗旁直接给出对应操作。')
one('guide-open','花路手册 · 紫花地','guide-violet','换地区同时换地图与标本，归途须知在原页展开。')
one('complete','储粮完成','complete','封好的蜜罐标记储备完成。可以再去花园、打开设置、开始新的一轮或保存并退出。')
one('feedback','菜单入口的操作反馈','feedback','常态、悬停、键盘焦点和按下共用物件与文字基线。')
one('field-flower','池岸 · 靠近蓝花','field-flower','按住提示贴近花心。四种资源及续航集中在左下，暂停保持在右下。','原生场景底图上的设计稿')
one('field-resin','紫花地 · 振翅掀皮','field-resin','当前设备为手柄。X 振翅，裂口打开且靠近后，按住 A 收树脂。','原生场景底图上的设计稿')
one('field-pickup','池岸 · 纤维入囊','field-pickup','短签贴着背包显示本次所得及现有数量，给花和蜜蜂留出空间。','原生场景底图上的设计稿')
one('field-tired','紫花地 · 低体力返程','field-tired','箭头按蜂到入口的方向绘制；低体力还可从左下的弧长、蜂姿与 6 / 36 读出。','原生场景底图上的设计稿')
begin('field-states','采集、容量与庭院入口','设计局部　／　原生机位')
for i,(key,label,crop) in enumerate([
        ('field-gathering','采蜜进行中',(196,161,501,336)),
        ('field-full','蜜囊已满',(0,422,353,598)),
        ('field-open','树皮已掀开',(353,184,675,362)),
        ('field-return','从木牌回庭院',(0,173,303,351))]):
    x=38+(i%2)*453;y=78+(i//2)*250
    text(x+10,y+23,label,18)
    plate(excerpt(load(key),960,crop),x+4,y+34,424,198)
finish('动作、拾取与容量各有固定位置；键帽对应当前设备和绑定。')
one('native-controls','键位操作参照 · Mac 实机',Image.open(args.key_screens/'flight-kbm-960x600.png'),
    '主线 #452 的实际窗口，用于核对两类设备、四个场景、九行飞行绑定和蜂蜡键帽。','既有版本　／　实机原图')
pdf.save()
