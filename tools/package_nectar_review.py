#!/usr/bin/env python3
"""Package the independent nectar MVP after NH-C01..08 evidence checks.

This validates declared coverage and hashes, not testimony, media truth or fun.
It never generates review evidence, exports Godot, uploads or touches old saves.
launcher_text(app_name, executable) is public so the exact command can be tested
before a candidate is assembled; its digest must match the export launch record.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
from pathlib import Path, PurePosixPath
import plistlib
import re
import shutil
import stat
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = ROOT / 'prototypes/swarm-flight/nectar-review-contract.json'
README = ROOT / 'prototypes/swarm-flight/nectar-review-readme.txt'
SAVE_NAME = 'nectar_harvest_v1.json'
ENTRY_CHECKS = {'direct_app', 'command_entry', 'ordinary_input', 'save', 'exit', 'cold_resume', 'continued_input'}
VIDEO_SUFFIXES = {'.mp4', '.mov', '.webm', '.m4v'}

def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8'))

def digest(path):
    result = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            result.update(block)
    return result.hexdigest()

def text(value):
    return isinstance(value, str) and bool(value.strip())

def hash_string(value, length=64):
    return isinstance(value, str) and re.fullmatch('[0-9a-f]{%d}' % length, value) is not None

def warnings_errors(value, label):
    if not isinstance(value, list):
        return [label + ': warnings must be explicitly recorded']
    errors = []
    for item in value:
        if (not isinstance(item, dict) or not text(item.get('message'))
                or item.get('disposition') not in ('resolved', 'nonblocking')
                or not text(item.get('reason'))):
            errors.append(label + ': unresolved or unexplained warning')
    return errors

def relative_file(root, value):
    if not text(value) or '\\' in value or '\x00' in value:
        raise ValueError('artifact path must be a relative POSIX path')
    name = PurePosixPath(value)
    if name.is_absolute() or '..' in name.parts or ':' in name.parts[0]:
        raise ValueError('artifact path escapes evidence root')
    target = root.joinpath(*name.parts)
    if any(root.joinpath(*name.parts[:i]).is_symlink() for i in range(1, len(name.parts)+1)):
        raise ValueError('artifact symlinks are not evidence files')
    if not target.resolve().is_relative_to(root.resolve()) or not target.is_file() or target.stat().st_size == 0:
        raise ValueError('missing, empty or escaped artifact: ' + value)
    return target

def verify_artifact(item, root, revision, label):
    errors = []
    if not isinstance(item, dict):
        return [label + ': artifact must be an object'], None
    if item.get('revision') != revision:
        errors.append(label + ': stale artifact revision')
    if not hash_string(item.get('sha256')):
        errors.append(label + ': missing full artifact hash')
    try:
        target = relative_file(root, item.get('path'))
        if digest(target) != item.get('sha256'):
            errors.append(label + ': artifact hash mismatch')
    except (OSError, ValueError, IndexError) as exc:
        errors.append(label + ': ' + str(exc)); target = None
    return errors, target

def validate_record(record, row, root, revision, export_record):
    label = row['id']; errors = []
    if not isinstance(record, dict):
        return [label + ': evidence record must be an object']
    for ok, message in [
        (record.get('revision') == revision, 'stale record revision'),
        (record.get('status') == 'passed', 'record did not pass'),
        (record.get('method') in row['methods'], 'incorrect verification method'),
        (text(record.get('summary')), 'missing observed result summary'),
        (record.get('blockers') == [], 'blockers must be explicitly empty')]:
        if not ok: errors.append(label + ': ' + message)
    errors += warnings_errors(record.get('warnings'), label)
    artifacts = record.get('artifacts')
    roles = set(); verified = []
    if not isinstance(artifacts, list) or not artifacts:
        errors.append(label + ': referenced raw evidence is required')
    else:
        for i, item in enumerate(artifacts):
            found, target = verify_artifact(item, root, revision, f'{label}.artifacts[{i}]')
            errors += found
            if isinstance(item,dict) and target is not None:
                verified.append((item,target))
            if isinstance(item, dict) and text(item.get('role')):
                roles.add(item['role'])
                if item['role'] == 'continuous_video' and target and target.suffix.lower() not in VIDEO_SUFFIXES:
                    errors.append(label + ': continuous native media must be a video file')
                if item['role'] == 'native_frame' and target and target.suffix.lower() not in {'.png','.jpg','.jpeg','.webp'}:
                    errors.append(label + ': native frame must reference an image')
    if not set(row['roles']).issubset(roles):
        errors.append(label + ': missing required evidence roles: ' + ', '.join(sorted(set(row['roles'])-roles)))
    if label == 'NH-C03':
        if (type(record.get('checks')) is not int or record['checks'] <= 0
                or type(record.get('failures')) is not int or record['failures'] != 0):
            errors.append(label + ': actual rules-test counts with zero failures required')
    elif label == 'NH-C05':
        sizes = record.get('viewport_sizes')
        if not isinstance(sizes, list) or [960,600] not in sizes or [1280,800] not in sizes:
            errors.append(label + ': both native viewport sizes must be reviewed')
    elif label == 'NH-C06':
        if (not text(record.get('author')) or not text(record.get('reviewer'))
                or record['author'].strip().casefold() == record['reviewer'].strip().casefold()):
            errors.append(label + ': independent reviewer identity is required')
        if record.get('reviewer_kind') not in {'AI','developer','external_player'}:
            errors.append(label + ': identify the reviewer evidence boundary')
    elif label == 'NH-C07':
        checks = record.get('checks')
        if not isinstance(checks, dict) or any(checks.get(key) != 'passed' for key in ENTRY_CHECKS):
            errors.append(label + ': actual exported entry, input, save, exit and cold-resume checks required')
        for key, expected in [('export_sha256',export_record.get('sha256')),
                              ('launcher_sha256',export_record.get('launcher_sha256')),
                              ('entry','nectar-harvest'),('save_filename',SAVE_NAME)]:
            if record.get(key) != expected:
                errors.append(label + ': wrong ' + key)
        before = record.get('legacy_save_hashes_before')
        after = record.get('legacy_save_hashes_after')
        if (not isinstance(before, dict) or not before or before != after
                or any(not text(name) or not hash_string(value) for name, value in before.items())):
            errors.append(label + ': real unchanged legacy-save hashes before/after are required')
        observed = {'legacy_save_before':{},'legacy_save_after':{}}
        for item, target in verified:
            role = item.get('role')
            if role in observed:
                name = item.get('save_name')
                if not text(name) or name == SAVE_NAME or name in observed[role]:
                    errors.append(label + ': legacy snapshot requires a unique old save_name')
                else:
                    observed[role][name] = digest(target)
            elif role in ('save_before','save_after'):
                try:
                    saved = read(target)
                    if (not isinstance(saved,dict) or saved.get('id') != 'nectar-harvest-v1'
                            or type(saved.get('version')) is not int or saved['version'] != 1):
                        errors.append(label + ': new-save snapshot has wrong independent identity')
                except (ValueError,OSError) as exc:
                    errors.append(label + ': cannot read new-save snapshot: ' + str(exc))
        if observed['legacy_save_before'] != before or observed['legacy_save_after'] != after:
            errors.append(label + ': legacy-save declarations do not match retained snapshot bytes')
    elif label == 'NH-C08':
        cost = record.get('cost')
        if (not isinstance(cost, dict) or not text(cost.get('observed_start'))
                or not text(cost.get('observed_end')) or not text(cost.get('coverage'))
                or any(key not in cost for key in ['active','billed','cumulative','remaining','new_purchases'])):
            errors.append(label + ': effort coverage and unknown costs must be explicit')
        elif any(cost[key] is not None and (type(cost[key]) not in (int,float) or not math.isfinite(cost[key]) or cost[key] < 0)
                 for key in ['active','billed','cumulative','remaining','new_purchases']):
            errors.append(label + ': numeric effort/cash values must be finite and nonnegative or unknown')
        for field in ['tracking','ci','integration']:
            if not text(record.get(field)): errors.append(label + ': missing ' + field + ' state')
        if record.get('human_acceptance_claim') is not False:
            errors.append(label + ': candidate cannot claim player acceptance')
    return errors

def preflight(contract, receipt, evidence_root, revision, export_record, export_zip):
    errors = []
    if not hash_string(revision,40): errors.append('revision must be a frozen full 40-character Git SHA')
    if not isinstance(receipt, dict) or not isinstance(export_record, dict):
        return errors + ['receipt and export record must be objects']
    if (not isinstance(contract, dict) or contract.get('schema') != 1
            or contract.get('goal') != 'nectar-harvest-mvp'):
        return errors + ['wrong nectar review contract']
    criteria = contract.get('criteria')
    expected = {'NH-C%02d' % i for i in range(1,9)}
    if (not isinstance(criteria,list) or len(criteria) != 8
            or any(not isinstance(row,dict) or not isinstance(row.get('id'),str) for row in criteria)
            or {row['id'] for row in criteria} != expected):
        return errors + ['contract must retain exactly NH-C01..08']
    for row in criteria:
        if any(not isinstance(row.get(key),list) or not row[key] or not all(text(value) for value in row[key]) for key in ['methods','roles']):
            return errors + ['contract verification methods and evidence roles must be explicit']
    for key, expected in [('schema',1),('goal','nectar-harvest-mvp'),('claim','candidate'),('revision',revision),('human_acceptance_claim',False),('blockers',[])]:
        if receipt.get(key) != expected or (key == 'human_acceptance_claim' and receipt.get(key) is not False):
            errors.append('receipt has wrong or missing ' + key)
    errors += warnings_errors(receipt.get('warnings'), 'receipt')
    if type(receipt.get('schema')) is not int:
        errors.append('receipt schema must be an integer')
    for key, expected in [('revision',revision),('engine','4.6.2'),('entry','nectar-harvest'),('save_filename',SAVE_NAME)]:
        if export_record.get(key) != expected: errors.append('export record has wrong ' + key)
    if not isinstance(export_record.get('custom_features'), list) or 'nectar_mvp' not in export_record['custom_features']:
        errors.append('export must have nectar_mvp direct-app feature')
    if not hash_string(export_record.get('launcher_sha256')):
        errors.append('export record requires the tested launcher hash')
    try:
        if digest(export_zip) != export_record.get('sha256'):
            errors.append('export archive differs from the tested export')
    except OSError as exc:
        errors.append('export archive unreadable: ' + str(exc))
    root = Path(evidence_root)
    if not root.is_dir(): return errors + ['evidence root is not a directory']
    evidence = receipt.get('evidence')
    if not isinstance(evidence, list): return errors + ['receipt evidence must cover NH-C01..08']
    rows = {row['id']:row for row in contract['criteria']}
    seen = set()
    for item in evidence:
        if not isinstance(item, dict) or not isinstance(item.get('criterion'), str):
            errors.append('invalid criterion evidence'); continue
        criterion = item['criterion']
        if criterion not in rows or criterion in seen:
            errors.append('unknown or duplicated criterion: '+criterion); continue
        seen.add(criterion)
        if item.get('status') != 'passed' or item.get('kind') != rows[criterion]['kind']:
            errors.append(criterion + ': wrong status or evidence kind')
        found, target = verify_artifact(item, root, revision, criterion)
        errors += found
        if target:
            try:
                errors += validate_record(read(target), rows[criterion], root, revision, export_record)
            except (ValueError, OSError, TypeError) as exc:
                errors.append(criterion + ': unreadable evidence record: ' + str(exc))
    if seen != set(rows): errors.append('missing criteria: ' + ', '.join(sorted(set(rows)-seen)))
    return errors

def safe_component(value):
    if (not isinstance(value,str) or value in {'.','..'}
            or not re.fullmatch(r'[\w .·()—-]+',value)):
        raise ValueError('Unsafe app or executable name')
    return value

def launcher_text(app_name, executable):
    safe_component(app_name); safe_component(executable)
    return f'''#!/bin/zsh
set -eu
cd -- "$(dirname -- "$0")"
nectar_save="$HOME/Library/Application Support/BeforeTheRain/{SAVE_NAME}"
while (( $# )); do
  case "$1" in
    --progress-file=*) nectar_save="${{1#--progress-file=}}"; shift ;;
    --progress-file)
      if (( $# < 2 )); then print -u2 '缺少独立测试存档路径'; exit 2; fi
      nectar_save="$2"; shift 2 ;;
    *) print -u2 '仅支持 --progress-file 的独立本地测试覆盖'; exit 2 ;;
  esac
done
if [[ "$nectar_save" != /*/{SAVE_NAME} ]]; then
  print -u2 '测试路径须为绝对路径，并以 {SAVE_NAME} 结尾'; exit 2
fi
mkdir -p -- "$(dirname -- "$nectar_save")" "$PWD/日志"
exec "$PWD/{app_name}/Contents/MacOS/{executable}" --log-file "$PWD/日志/采蜜小店.log" -- --nectar-harvest --progress-file="$nectar_save"
'''

def extract_export(export_zip, destination):
    seen = set(); total = 0
    with zipfile.ZipFile(export_zip) as archive:
        for info in archive.infolist():
            raw = info.filename
            name = PurePosixPath(raw)
            mode = info.external_attr >> 16
            total += info.file_size
            if (not raw or not name.parts or '\\' in raw or '\x00' in info.orig_filename or name.is_absolute()
                    or '..' in name.parts or ':' in name.parts[0]
                    or stat.S_ISLNK(mode) or stat.S_IFMT(mode) not in {0,stat.S_IFREG,stat.S_IFDIR}
                    or info.flag_bits & 1 or total > 4*1024**3):
                raise ValueError('Unsafe path, symlink, special file or unsupported export')
            normalized = str(name).casefold()
            if normalized in seen:
                raise ValueError('Duplicate export path')
            seen.add(normalized)
        for info in archive.infolist():
            target = destination.joinpath(*PurePosixPath(info.filename).parts)
            if info.is_dir():
                target.mkdir(parents=True,exist_ok=True)
                target.chmod((info.external_attr >> 16 & 0o777) or 0o755)
            else:
                target.parent.mkdir(parents=True,exist_ok=True)
                with archive.open(info) as source, target.open('xb') as output:
                    shutil.copyfileobj(source,output)
                target.chmod((info.external_attr >> 16 & 0o777) or 0o644)
    apps = list(destination.glob('*.app'))
    if len(apps) != 1 or any(item != apps[0] for item in destination.iterdir()):
        raise ValueError('Expected exactly one top-level app and no unrelated export contents')
    app = apps[0]; safe_component(app.name)
    metadata = plistlib.loads((app/'Contents/Info.plist').read_bytes())
    executable = safe_component(metadata.get('CFBundleExecutable'))
    version = metadata.get('CFBundleShortVersionString')
    if not isinstance(version,str) or not re.fullmatch(r'\d+\.\d+\.\d+',version):
        raise ValueError('Expected a semantic export version')
    binary = app/'Contents/MacOS'/executable
    if not binary.is_file() or not binary.stat().st_mode & 0o111:
        raise ValueError('Export executable is missing or not executable')
    return app, executable, version

def package(export_zip, export_record, receipt, evidence_root, revision, output):
    output = Path(output)
    if output.exists() or output.is_symlink(): raise ValueError('Refusing to overwrite existing output')
    errors = preflight(read(CONTRACT),receipt,evidence_root,revision,export_record,export_zip)
    if errors: raise ValueError('Nectar candidate blocked:\n- '+'\n- '.join(errors))
    output.parent.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='nectar-package-',dir=output.parent) as tmp:
        stage = Path(tmp)/'采蜜小店-MVP'; stage.mkdir()
        app, executable, version = extract_export(export_zip,stage)
        command_body = launcher_text(app.name,executable)
        command_hash = hashlib.sha256(command_body.encode('utf-8')).hexdigest()
        if command_hash != export_record['launcher_sha256']:
            raise ValueError('Maintained launcher differs from the tested launcher')
        command = stage/'开始采蜜小店.command'
        command.write_text(command_body,encoding='utf-8'); command.chmod(0o755)
        (stage/'先读我.txt').write_text(README.read_text(encoding='utf-8').replace('{version}',version),encoding='utf-8')
        (stage/'版本信息.json').write_text(json.dumps({
            'goal':'nectar-harvest-mvp','claim':'candidate','version':version,'revision':revision,
            'engine':'4.6.2','entry':'nectar-harvest','save_filename':SAVE_NAME,
            'human_accepted':False,'full_game_completed':False,'export_sha256':digest(export_zip),
            'launcher_sha256':command_hash,'executable_sha256':digest(app/'Contents/MacOS'/executable)
        },ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        temporary = Path(tmp)/'candidate.zip'
        with zipfile.ZipFile(temporary,'w',zipfile.ZIP_DEFLATED) as archive:
            for path in sorted(stage.rglob('*')):
                if path.is_file(): archive.write(path,Path(stage.name)/path.relative_to(stage))
        created = False
        try:
            with output.open('xb') as dest, temporary.open('rb') as source:
                created = True
                shutil.copyfileobj(source,dest)
        except BaseException:
            if created: output.unlink(missing_ok=True)
            raise
    return {'path':str(output),'sha256':digest(output),'revision':revision,'claim':'candidate'}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ['export','export-record','receipt','evidence-root','output']:
        parser.add_argument('--'+name,type=Path,required=True)
    parser.add_argument('--revision',required=True)
    args = parser.parse_args()
    try:
        result = package(args.export,read(args.export_record),read(args.receipt),args.evidence_root,args.revision,args.output)
    except (OSError,ValueError,KeyError,TypeError,zipfile.BadZipFile) as exc:
        print(str(exc)); return 1
    print(json.dumps(result,ensure_ascii=False,indent=2)); return 0

if __name__ == '__main__':
    raise SystemExit(main())
