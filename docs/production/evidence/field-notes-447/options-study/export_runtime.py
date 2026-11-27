"""Export the approved cabinet and blank binding register for the live Godot controls."""
import subprocess
from pathlib import Path
from tempfile import TemporaryDirectory
from xml.etree import ElementTree as ET

import make_options as art


OUTPUT = art.REPO / "prototypes/swarm-flight/art/field-notes-options"
SVG = "{http://www.w3.org/2000/svg}"
ET.register_namespace("", SVG[1:-1])
ET.register_namespace("xlink", "http://www.w3.org/1999/xlink")


def export(name, svg):
    with TemporaryDirectory() as temp:
        source = Path(temp) / "plate.svg"
        png = Path(temp) / "plate.png"
        source.write_text(svg)
        subprocess.run(["rsvg-convert", "-z", "2", "-o", png, source], check=True)
        subprocess.run(["cwebp", "-quiet", "-q", "94", "-alpha_q", "100", png, "-o", OUTPUT / (name + ".webp")], check=True)


def page(name, source, texts, static_groups, static_rails):
    root = ET.fromstring(source)
    for child in list(root):
        tag = child.tag.removeprefix(SVG)
        if tag in ("title", "defs"):
            continue
        if tag == "text" and child.text in texts:
            continue
        if tag == "g" and child.get("transform") in static_groups:
            continue
        if tag == "path" and (child.get("d", "").startswith(("M69 25", "M49 61", "M52 547", "M88 111", "M82 456", "M49.6", "M906.6", "M48.6", "M908.6")) or child.get("d") in static_rails):
            continue
        if tag == "circle" and child.get("r") == "3.2":
            continue
        if name == "register" and tag in ("ellipse", "image"):
            continue
        root.remove(child)
    export(name, ET.tostring(root, encoding="unicode"))


def build():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    page("cabinet", art.option_page(), {"设置", "声音", "简化动画", "蜂舞", "键位设置", "关于"},
         {"translate(0 6) scale(1)"},
         {"M325 173 Q560 175 872 173", "M325 238 H872", "M325 365 H872", "M325 440 H872", "M83 510 Q503 513 868 510"})
    page("register", art.bindings_page(), {"键位设置"}, {"translate(0 6) scale(1)"},
         {"M318 107 Q580 103 879 108", "M321 151 H873", "M78 525 Q452 529 871 524"})
    # A single transparent atlas keeps every switch position, pressed tab and dance
    # illustration tied to the source used by the approved interactive prototype.
    parts = []
    for active in (False, True):
        x = 4 + int(active) * 200
        parts += [
            art.nav_button(x + 2, 4, 170, "", active),
            art.context_tab(x + 2, 54, "", active),
            art.switch(x + 2, 104, active),
            art.dance(x + 2, 154, "摆尾回环", active, False, False),
            art.dance(x + 2, 244, "侧步摆肩", active, False, True),
        ]
    plate = art.shape("M9 2 Q134 -3 226 2 Q236 3 236 14 V144 Q236 155 224 156 Q111 162 10 156 Q0 155 0 145 V13 Q0 4 9 2 Z", "url(#raised)", "#b29465")
    parts += [art.grp(4, 340, plate), art.grp(201, 148, '<ellipse cx="174" cy="341" rx="67" ry="7" fill="#96764d" opacity=".18"/>'+art.picture("music-box",79,182,197,166))]
    parts += [art.shape("M275 145 Q326 151 386 145", "none", "#ad8f61"), art.dot(331,150,2,"#ac8a57")]
    export("hardware", art.svg("".join(parts), "活动机关与署名牌").replace('width="960" height="600" viewBox="0 0 960 600"', 'width="480" height="505" viewBox="0 0 480 505"'))


if __name__ == "__main__":
    build()
