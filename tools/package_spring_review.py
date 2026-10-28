#!/usr/bin/env python3
"""Assemble the03→05 review candidate only after scoped evidence passes.

Internal Godot exports remain available for development. This is the maintained
player-package entry; it does not certify enjoyment or replace review of media.
No upload, old package overwrite, user-save access, or gameplay modification.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import re
import stat
import tempfile
import zipfile

if __package__:
    from .check_delivery import validate
    from .spring_review_gate import validate_review
else:
    from check_delivery import validate
    from spring_review_gate import validate_review

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = ROOT / 'prototypes/swarm-flight/spring-review-contract.json'
README = ROOT / 'prototypes/swarm-flight/review-readme.txt'

def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8'))

def digest(path):
    with Path(path).open('rb') as stream:
        checksum = hashlib.sha256()
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            checksum.update(chunk)
        return checksum.hexdigest()

def preflight(contract, receipt, evidence_root, revision, export_record, export_zip):
    errors = validate(contract, receipt, Path(evidence_root), revision, 'candidate')
    if errors:
        return errors
    item = next(e for e in receipt['evidence'] if e['criterion'] == 'experience')
    errors += validate_review(read(Path(evidence_root) / item['path']), revision, evidence_root)
    if not isinstance(export_record, dict):
        return errors + ['export record must be an object']
    if export_record.get('revision') != revision:
        errors.append('export belongs to another revision')
    if export_record.get('sha256') != digest(export_zip):
        errors.append('export archive differs from the tested archive')
    if export_record.get('entries') != {'spring-03-05': 'passed', 'comparison-07-09': 'passed'}:
        errors.append('both exported entries must have actual launch results')
    if export_record.get('isolated_saves') is not True:
        errors.append('export launch checks must use isolated saves')
    return errors

def package(export_zip, export_record, receipt, evidence_root, revision, output):
    output = Path(output)
    errors = preflight(read(CONTRACT), receipt, evidence_root, revision, export_record, export_zip)
    if errors:
        raise ValueError('Player package blocked:\n- ' + '\n- '.join(errors))
    if output.exists():
        raise ValueError('Refusing to overwrite an existing package')
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='spring-review-', dir=output.parent) as tmp:
        stage = Path(tmp) / '雨来之前-03至05'; stage.mkdir()
        with zipfile.ZipFile(export_zip) as archive:
            for info in archive.infolist():
                name = Path(info.filename)
                if name.is_absolute() or '..' in name.parts or stat.S_ISLNK(info.external_attr >> 16):
                    raise ValueError('Unexpected path or symlink in Godot export')
            archive.extractall(stage)
        apps = list(stage.glob('*.app'))
        if len(apps) != 1 or any(p != apps[0] for p in stage.iterdir()):
            raise ValueError('Expected one app and no unrelated export contents')
        app = apps[0]
        metadata = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
        version = metadata['CFBundleShortVersionString']; executable = metadata['CFBundleExecutable']
        if not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+', version) or not re.fullmatch(r'[A-Za-z0-9_.-]+', executable):
            raise ValueError('Unexpected export version or executable name')
        old_name = app.name
        versioned = stage.parent / f'雨来之前-{version}-03至05-{revision[:8]}'
        stage.rename(versioned); stage = versioned; app = stage / old_name
        target = stage / f'PondJourney-{version}.app'
        if app != target:
            app.rename(target)
        binary = target / 'Contents/MacOS' / executable
        if not binary.is_file():
            raise ValueError('Export has no executable')
        binary.chmod(0o755)
        for title, flag, save in [
            ('开始03至05', '--spring-journey', 'spring_03_05_v2.json'),
            ('对照07至09', '--long-journey', 'summer_long_07_09_r8.json')]:
            command = stage / (title + '.command')
            command.write_text('#!/bin/zsh\nset -e\ncd -- "$(dirname -- "$0")"\n'
                'mkdir -p -- 存档 日志\nextra=()\n'
                f'if [[ ! -e "$PWD/存档/{save}" ]]; then extra+=(--chapter=0); fi\n'
                f'exec "$PWD/{target.name}/Contents/MacOS/{executable}" '
                f'--log-file "$PWD/日志/{title}.log" -- {flag} '
                f'--progress-file="$PWD/存档/{save}" --entry-chapter=0 "${{extra[@]}}" "$@"\n', encoding='utf-8')
            command.chmod(0o755)
        (stage / '先读我.txt').write_text(README.read_text(encoding='utf-8').replace('{version}', version), encoding='utf-8')
        (stage / '版本信息.json').write_text(json.dumps({
            'version': version, 'revision': revision, 'scope': '03→05整段评审候选；07→09对照',
            'human_accepted': False, 'full_game_completed': False,
            'export_sha256': digest(export_zip)}, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        temporary_zip = Path(tmp) / 'candidate.zip'
        with zipfile.ZipFile(temporary_zip, 'w', zipfile.ZIP_DEFLATED) as archive:
            for path in sorted(stage.rglob('*')):
                if path.is_file():
                    archive.write(path, Path(stage.name) / path.relative_to(stage))
        # Exclusive creation preserves a concurrent/previous delivery.
        with output.open('xb') as dest, temporary_zip.open('rb') as source:
            for chunk in iter(lambda: source.read(1024 * 1024), b''):
                dest.write(chunk)
    return {'path': str(output), 'sha256': digest(output), 'revision': revision}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ['export', 'export-record', 'receipt', 'evidence-root', 'output']:
        parser.add_argument('--' + name, type=Path, required=True)
    parser.add_argument('--revision', required=True)
    args = parser.parse_args()
    try:
        result = package(args.export, read(args.export_record), read(args.receipt), args.evidence_root, args.revision, args.output)
    except (OSError, ValueError, KeyError, TypeError, zipfile.BadZipFile) as exc:
        print(str(exc)); return 1
    print(json.dumps(result, ensure_ascii=False, indent=2)); return 0

if __name__ == '__main__':
    raise SystemExit(main())
