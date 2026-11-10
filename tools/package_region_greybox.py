#!/usr/bin/env python3
"""Build the explicitly isolated map experiment, not a Nectar review/release package."""
import argparse, hashlib, json, pathlib, re, shutil, subprocess
ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'prototypes/swarm-flight'
p = argparse.ArgumentParser()
p.add_argument('--output', type=pathlib.Path, required=True)
p.add_argument('--godot', default='/Applications/Godot 2.app/Contents/MacOS/Godot')
p.add_argument('--stage-only', action='store_true')
a = p.parse_args()
out = a.output.expanduser().resolve()
out.mkdir(parents=True, exist_ok=True)
stage = out / 'source'
if stage.exists():
    raise SystemExit('Output source already exists; choose a fresh output path to preserve prior builds.')
stage.mkdir()
queue = ['region_greybox/greybox.tscn']
seen = set()
while queue:
    relative = queue.pop()
    if relative in seen:
        continue
    src = (SOURCE / relative).resolve()
    if not src.is_relative_to(SOURCE.resolve()) or not src.is_file():
        raise SystemExit(f'Invalid runtime dependency: {relative}')
    seen.add(relative)
    dst = stage / relative
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    content = src.read_text()
    queue += re.findall(r'(?:preload|load)\(\s*"res://([^"\n]+)"', content)
    queue += re.findall(r'extends\s+"res://([^"\n]+)"', content)
    queue += re.findall(r'path="res://([^"\n]+)"', content)
(stage / 'project.godot').write_text('''config_version=5
[application]
config/name="池岸与紫花地 · 区域灰盒"
run/main_scene="res://region_greybox/greybox.tscn"
config/features=PackedStringArray("4.6")
config/use_custom_user_dir=true
config/custom_user_dir_name="BeforeTheRain-RegionGreybox"
[display]
window/size/viewport_width=1280
window/size/viewport_height=800
window/size/window_width_override=1280
window/size/window_height_override=800
window/size/min_width=960
window/size/min_height=600
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"
[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
textures/vram_compression/import_etc2_astc=true
[audio]
driver/enable_input=false
''')
(stage / 'export_presets.cfg').write_text('''[preset.0]
name="Region Greybox macOS"
platform="macOS"
runnable=true
export_filter="all_resources"
include_filter=""
exclude_filter="*.md"
script_export_mode=2
[preset.0.options]
binary_format/architecture="universal"
application/bundle_identifier="com.alanthssss.regiongreybox"
application/short_version="0.1.0"
application/version="0.1.0"
application/signature="RegionGreybox"
codesign/codesign=0
codesign/entitlements/app_sandbox/enabled=false
notarization/notarization=0
''')
sha = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
builder_bytes = pathlib.Path(__file__).read_bytes()
frozen_builder = subprocess.check_output(['git', 'show', f'{sha}:tools/package_region_greybox.py'], cwd=ROOT)
if builder_bytes != frozen_builder:
    raise SystemExit('Packager differs from frozen commit.')
manifest = {'type': 'internal_playable_greybox', 'commit': sha, 'save_namespace': 'BeforeTheRain-RegionGreybox',
            'packager_sha256': hashlib.sha256(builder_bytes).hexdigest(),
            'generated_configs': {s: hashlib.sha256((stage / s).read_bytes()).hexdigest() for s in ['project.godot', 'export_presets.cfg']},
            'files': {s: hashlib.sha256((stage / s).read_bytes()).hexdigest() for s in sorted(seen)}}
for relative in sorted(seen):
    tracked = subprocess.check_output(['git', 'show', f'{sha}:prototypes/swarm-flight/{relative}'], cwd=ROOT)
    if hashlib.sha256(tracked).hexdigest() != manifest['files'][relative]:
        raise SystemExit(f'Runtime differs from frozen commit: {relative}')
(out / 'source-manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
(out / '使用说明.txt').write_text('池岸与紫花地 · 可玩灰盒\n\n这是地图实验，不替换采蜜Demo，也不读取正式存档。\n选择区域、晴日/细雨/支路变体和成长前/后，然后出发。\nWASD/方向键移动；靠花按住E或左键采蜜；Q或右键振翅取材料。\n空格蓄力后松开冲刺；入口按E返回；M看已探索路线；Esc暂停。\n深色是实体灌木，浅色可飞，绿色圈是叶棚。\n每趟条件固定；结算可看耗时、余量、收获、经过地标。\n区域大小与路线乐趣仍待真人判断，画面仅为灰盒。\n\n源码提交：' + sha + '\n')
launcher = out / '启动灰盒.command'
launcher.write_text('#!/bin/zsh\npackage_dir="${0:A:h}"\nopen "$package_dir/池岸与紫花地 · 区域灰盒.app"\n')
launcher.chmod(0o755)
manifest['launcher_sha256'] = hashlib.sha256(launcher.read_bytes()).hexdigest()
(out / 'source-manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
if not a.stage_only:
    for args in [ ['--editor', '--import', '--quit'], ['--export-release', 'Region Greybox macOS', str(out / '区域灰盒.zip')] ]:
        result = subprocess.run([a.godot, '--headless', '--path', str(stage), *args], capture_output=True, text=True)
        log = result.stdout + result.stderr
        (out / ('import.log' if '--editor' in args else 'export.log')).write_text(log)
        if result.returncode or 'SCRIPT ERROR' in log or 'ERROR:' in log:
            raise SystemExit(log[-4000:])
    subprocess.run(['ditto', '-x', '-k', str(out / '区域灰盒.zip'), str(out)], check=True)
    manifest['zip_sha256'] = hashlib.sha256((out / '区域灰盒.zip').read_bytes()).hexdigest()
    (out / 'source-manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({'output':str(out),'commit':sha,'runtime_files':len(seen)},ensure_ascii=False))
