"""Split the approved art into unlettered live surfaces. Run with Pillow, Node, cwebp and librsvg."""
from copy import deepcopy
from io import BytesIO
from pathlib import Path
import subprocess
import make_field as field
import tempfile
import xml.etree.ElementTree as ET

from PIL import Image, ImageChops

HERE = Path(__file__).resolve().parent
OUT = HERE.parents[4] / "prototypes/swarm-flight/art/honey-pages"
SVG = "{http://www.w3.org/2000/svg}"
LINK = "{http://www.w3.org/1999/xlink}href"
ET.register_namespace("", SVG[1:-1])
ET.register_namespace("xlink", LINK[1:LINK.index("}")])

def remove(root, predicate):
    for child in list(root):
        if child.tag == SVG + "defs": continue
        if predicate(child): root.remove(child)
        else: remove(child, predicate)

def raster(root, bounds=None):
    root = deepcopy(root)
    if bounds:
        x, y, w, h = bounds
        root.set("viewBox", f"{x} {y} {w} {h}")
        root.set("width", str(w))
        root.set("height", str(h))
    data = subprocess.check_output(["rsvg-convert", "-z", "1.5"], input=ET.tostring(root))
    return Image.open(BytesIO(data)).convert("RGBA")

def render(root, name, bounds=None):
    raster(root,bounds).save(OUT / (name + ".webp"), quality=94, method=4)
def outline(name, bounds, transform, contour, width=2.5):
    root = ET.Element(SVG+"svg")
    group = ET.SubElement(root,SVG+"g",{"transform":transform})
    ET.SubElement(group,SVG+"path",{"d":contour,"stroke":"#315850","stroke-width":str(width),"fill":"none","stroke-linejoin":"round"})
    render(root,name+"-focus",bounds)

def shared_menu():
    root = ET.parse(HERE.parent / "shared-menu.svg").getroot()
    page = root.find(SVG + "g")
    buttons = [n for n in page.findall(SVG + "g") if n.get("transform","").endswith(") scale(1)") and n.get("transform","").split()[0] in ("translate(123","translate(327")]
    assert len(buttons) == 6
    for n in buttons: page.remove(n)
    remove(page, lambda n: n.tag == SVG+"text" or n.tag == SVG+"image")
    render(root, "shared")
    for i, (name, x, y) in enumerate([("fly",123,136),("map",327,136),("dial",123,252),("files",327,252),("reel",123,368),("gate",327,368)]):
        item = deepcopy(buttons[i if name != "dial" else 4])
        if name == "dial":
            item.set("transform",buttons[i].get("transform"))
            item.find(".//"+SVG+"use").set(LINK,"#dial")
        remove(item, lambda n: n.tag == SVG+"text")
        shell = deepcopy(root)
        group = shell.find(SVG+"g")
        group.append(item)
        bounds=(x-85,y-8,170,115)
        # The illustrations use multiply blending against this exact part of the plate.
        image=raster(shell,bounds)
        clean=raster(root,bounds)
        diff=ImageChops.difference(image.convert("RGB"),clean.convert("RGB"))
        red,green,blue=diff.split()
        mask=ImageChops.lighter(ImageChops.lighter(red,green),blue).point(lambda v: 255 if v else 0)
        image.putalpha(mask)
        image.save(OUT/(name+".webp"),quality=94,method=4)
        focus = next(n for n in root.iter(SVG+"path") if n.get("stroke")=="#315850")
        contour=focus.get("d")
        if name=="fly":
            contour="M-72 66 Q-62 61 -44 59 Q-43 33 -32 23 Q-34 5 -17 1 Q-9 -4 1 0 Q14 -8 29 -5 Q54 -8 46 8 Q45 20 41 29 Q43 45 28 58 Q65 60 72 66 Q81 75 78 85 Q75 99 57 100 H-58 Q-81 99 -79 80 Q-79 70 -72 66Z"
        elif name!="dial":
            contour="M-71 65 Q-62 60 -48 59 L-48 7 Q-47 -3 -35 -3 H36 Q48 -3 49 8 V58 Q76 60 79 76 Q84 99 59 101 H-56 Q-81 99 -79 80 Q-79 70 -71 65Z"
        outline(name,bounds,f"translate({x} {y+3})",contour)

def pages(work):
    def read(name): return ET.parse(work / (name + ".svg")).getroot()
    # Keep only permanent artwork. Every interactive selection and save figure is drawn live.
    slots = read("slots")
    tags = [e for e in slots if e.get("transform","").startswith("translate(436")]
    assert len(tags)==3
    for e in tags: slots.remove(e)
    remove(slots,lambda e: e.tag == SVG+"text" and e.text != "选择存档")
    render(slots,"slots")
    for i, (name, y) in enumerate([("current",151),("available",248),("blocked",345)]):
        shell=read("slots")
        for n in list(shell):
            if n.tag not in [SVG+"defs",SVG+"title"]: shell.remove(n)
        shell.append(tags[i])
        remove(tags[i],lambda n: n.tag==SVG+"text" and n.text!="当前" or n.get("stroke")=="#315850")
        bounds=(416,y-5,390,91)
        render(shell,"slot-"+name,bounds)
        contour=tags[i].find(SVG+"path").get("d")
        outline("slot-"+name,bounds,f"translate(436 {y})",contour,3.5)
    for name in ["restart","complete","guide","guide-violet","routes","routes-open"]:
        root=read(name)
        keep = {"complete":["蜂巢储粮","花蜜，备好了","蜂舞广场的同伴正在等你。"],
                "guide":["花路手册","蓝花蜜","纤维","紫花蜜","树脂","每份 1 金币","每份 3 金币"],
                "routes":["庭院"]}.get(name.split("-")[0],[])
        if name in ["routes","routes-open"]:
            left = name=="routes"
            pos=(112,179) if left else (526,177)
            map_layer=next(n for n in root if n.get("transform","").startswith("translate(%d %d)" % pos))
            contour=next(n.get("d") for n in map_layer if n.get("stroke")=="#315850")
            outline("pond" if left else "meadow",(107 if left else 519,174,328,223),"translate(%d %d)" % pos,contour,3.4)
        remove(root, lambda n: n.tag==SVG+"text" and n.text not in keep or n.get("stroke") in ["#315850","#fff1c7"])
        render(root,name)

if __name__ == "__main__":
    OUT.mkdir(parents=True,exist_ok=True)
    shared_menu()
    # The ink, portrait and energy arc come from the live model.
    sample = dict.fromkeys(["energy","maximum","coins","fiber","resin","honey","capacity"],1)
    hud = ET.fromstring(field.ui.svg(field.hud(sample,False),""))
    remove(hud,lambda e: e.get("d","").startswith("M45 7 A34") or e.get("transform","").startswith("translate(20 12)") or (e.tag==SVG+"text" and e.text not in ["花蜜","金币","纤维","树脂"]))
    render(hud,"field-hud",(16,497,332,87))
    render(ET.fromstring(field.ui.svg(field.pause(),"")),"field-pause",(893,528,46,48))
    full = field.pill(156,448,234,"蜜囊已满 · 仍可取材",pointer=False)
    render(ET.fromstring(field.ui.svg(full,"")),"full-bag",(36,446,240,46))
    for kind in ["花蜜","纤维","树脂"]:
        slug = {"花蜜":"honey","纤维":"fiber","树脂":"resin"}[kind]
        receipt = ET.fromstring(field.ui.svg(field.receipt(kind, 1),""))
        remove(receipt,lambda n: n.tag==SVG+"text")
        render(receipt,"pickup-"+slug,(31,445,126,52))
    with tempfile.TemporaryDirectory() as folder:
        subprocess.run(["node",str(HERE/"plates.cjs"),folder],check=True)
        pages(Path(folder))
