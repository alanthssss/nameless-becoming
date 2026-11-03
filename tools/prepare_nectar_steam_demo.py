#!/usr/bin/env python3
"""Prepare a strictly scoped macOS SteamPipe snapshot. Never invokes Steam or signs.

Without confirmed IDs, writes a non-uploadable JSON plan only. With IDs, defaults
to a Preview VDF. An upload VDF requires the separate --emit-upload-vdf flag.
This local tool cannot authenticate ownership or association of supplied IDs.
"""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import re
import shutil
import stat
import tempfile


FORBIDDEN_PARTS = {'.git', '.godot', '__pycache__', 'outputs', 'output',
                   'review-evidence', 'evidence', 'old', 'archive', 'archives',
                   'node_modules', 'config.vdf', 'steam_appid.txt', '.ds_store'}
FORBIDDEN_SUFFIXES = {'.log', '.pem', '.key', '.p12', '.pfx', '.bak', '.zip', '.dmg'}
MACHO_MAGICS = {b'\xcf\xfa\xed\xfe', b'\xfe\xed\xfa\xcf',
                b'\xca\xfe\xba\xbe', b'\xbe\xba\xfe\xca',
                b'\xca\xfe\xba\xbf', b'\xbf\xba\xfe\xca'}


def positive_id(value):
    if value is None:
        return None
    if not isinstance(value, str) or not re.fullmatch(r'[1-9][0-9]*', value):
        raise ValueError('AppID/DepotID must be positive decimal integers from Steamworks')
    if int(value) > 4294967295:
        raise ValueError('AppID/DepotID exceeds uint32 range')
    return value


def safe_text(value):
    value = str(value)
    if any(ord(c) < 32 or c in '"\\*?[]' for c in value):
        raise ValueError('Unsafe VDF path/text: control, quote, backslash or wildcard')
    return value


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def inventory(root):
    rows = []
    for path in sorted(root.rglob('*')):
        rel = path.relative_to(root)
        safe_text(rel.as_posix())
        if path.is_symlink():
            raise ValueError('Symlinks are not accepted in this Godot-only staging tool: ' + str(rel))
        if any(part.lower() in FORBIDDEN_PARTS or part.lower().startswith('.env') for part in rel.parts):
            raise ValueError('Internal/sensitive content in bundle: ' + str(rel))
        if path.suffix.lower() in FORBIDDEN_SUFFIXES:
            raise ValueError('Archive, log or credential in bundle: ' + str(rel))
        if path.is_file():
            rows.append({'path': rel.as_posix(), 'bytes': path.stat().st_size,
                         'sha256': digest(path), 'mode': stat.S_IMODE(path.stat().st_mode)})
        elif not path.is_dir():
            raise ValueError('Nonregular file in build: ' + str(rel))
    return rows


def inspect_build(build_dir, expected_version):
    raw = Path(build_dir).expanduser()
    if raw.is_symlink():
        raise ValueError('Build directory must not be a symlink')
    root = raw.resolve(strict=True)
    if not root.is_dir():
        raise ValueError('Build directory does not exist')
    if not expected_version or not re.fullmatch(r'\d+\.\d+\.\d+', expected_version):
        raise ValueError('--expected-version is required for a build (e.g. the actual export version)')
    children = list(root.iterdir())
    if len(children) != 1 or children[0].suffix != '.app' or not children[0].is_dir():
        raise ValueError('Build directory must contain exactly ONE .app and nothing else; do not use outputs/')
    app = children[0]
    rows = inventory(root)
    with (app / 'Contents/Info.plist').open('rb') as handle:
        info = plistlib.load(handle)
    if info.get('CFBundleShortVersionString') != expected_version:
        raise ValueError('Bundle version differs from --expected-version (possible old build)')
    executable = info.get('CFBundleExecutable', '')
    if not isinstance(executable, str) or not executable or '/' in executable or executable in {'.', '..'}:
        raise ValueError('Invalid CFBundleExecutable')
    binary = app / 'Contents/MacOS' / executable
    if not binary.is_file() or not (binary.stat().st_mode & 0o111):
        raise ValueError('Main executable missing or not executable')
    with binary.open('rb') as handle:
        if handle.read(4) not in MACHO_MAGICS:
            raise ValueError('Expected a 64-bit or Universal Mach-O executable')
    if not info.get('CFBundleIdentifier'):
        raise ValueError('Missing bundle identifier')
    if not any(p.is_file() and p.stat().st_size for p in (app / 'Contents/Resources').glob('*.pck')):
        raise ValueError('Missing nonempty Godot PCK in Contents/Resources')
    return root, app, rows, info


def app_vdf(app_id, depot_id, root, output, version, preview):
    return ('"AppBuild"\n{\n'
            f'  "AppID" "{app_id}"\n  "Desc" "Nectar macOS Demo {version}"\n'
            f'  "ContentRoot" "{safe_text(root)}"\n  "BuildOutput" "{safe_text(output)}"\n'
            f'  "Preview" "{1 if preview else 0}"\n'
            f'  "Depots"\n  {{\n    "{depot_id}" "depot_macos.vdf"\n  }}\n}}\n')


def depot_vdf(depot_id, rows):
    mappings = []
    for row in rows:
        rel = safe_text(row['path'])
        destination = Path(rel).parent.as_posix() + '/'
        mappings.append('  "FileMapping"\n  {\n'
                        f'    "LocalPath" "{rel}"\n    "DepotPath" "{destination}"\n'
                        '    "Recursive" "0"\n  }')
    return f'"DepotBuild"\n{{\n  "DepotID" "{depot_id}"\n' + '\n'.join(mappings) + '\n}\n'


def prepare(output, build_dir=None, expected_version=None, app_id=None, depot_id=None,
            ids_confirmed=False, emit_upload_vdf=False):
    app_id, depot_id = positive_id(app_id), positive_id(depot_id)
    if bool(app_id) != bool(depot_id):
        raise ValueError('Supply both real Demo AppID and macOS DepotID, or neither')
    if (app_id and not ids_confirmed) or (ids_confirmed and not app_id):
        raise ValueError('--ids-confirmed requires both IDs copied from your Steamworks configuration')
    if emit_upload_vdf and not (app_id and depot_id and ids_confirmed and build_dir):
        raise ValueError('Upload VDF requires confirmed IDs and a validated build directory')
    if app_id and not build_dir:
        raise ValueError('Confirmed IDs require an existing, validated build directory')
    out = Path(output).expanduser().absolute()
    if out.exists() or out.is_symlink():
        raise ValueError('Refusing to overwrite output')
    out.parent.mkdir(parents=True, exist_ok=True)
    out = out.parent.resolve() / out.name
    safe_text(out)
    checked = inspect_build(build_dir, expected_version) if build_dir else None
    if checked:
        source = checked[0]
        if out == source or out.is_relative_to(source) or source.is_relative_to(out):
            raise ValueError('Output and source build must be separate trees')
    report = {'schema_version': 1, 'app_id': app_id, 'depot_id': depot_id,
              'id_provenance': 'operator_confirmed_not_authenticated' if app_id else 'missing',
              'version': expected_version, 'upload_vdf_generated': bool(emit_upload_vdf),
              'uploaded': False, 'steam_release_ready': False,
              'signing_verified': False, 'notarization_verified': False,
              'blockers': ['Steam ownership/configuration and branch installation not checked',
                           'Signing/notarization and Valve review must be verified separately'],
              'files': []}
    if not app_id:
        report['blockers'].insert(0, 'No Demo AppID/DepotID: no executable VDF generated')
    with tempfile.TemporaryDirectory(prefix='.nectar-steam-stage-', dir=out.parent) as tmp:
        stage = Path(tmp) / 'prepared'
        stage.mkdir()
        if checked:
            content = stage / 'content'
            content.mkdir()
            shutil.copytree(checked[1], content / checked[1].name)
            rows = inventory(content)
            if rows != checked[2]:
                raise ValueError('Build changed during snapshot; regenerate from a frozen export')
            report['files'] = rows
            report['bundle'] = checked[1].name
            report['bundle_identifier'] = checked[3]['CFBundleIdentifier']
            report['launch_executable'] = f"{checked[1].name}/Contents/MacOS/{checked[3]['CFBundleExecutable']}"
            report['pck_scope_note'] = 'Opaque PCK contents require the existing export/packager evidence gate'
        if app_id:
            scripts = stage / 'scripts'
            scripts.mkdir()
            (scripts / 'depot_macos.vdf').write_text(depot_vdf(depot_id, report['files']), encoding='utf-8')
            for filename, preview in [('app_preview.vdf', True)] + ([('app_upload.vdf', False)] if emit_upload_vdf else []):
                (scripts / filename).write_text(app_vdf(app_id, depot_id, out/'content', out/'steampipe-cache', expected_version, preview), encoding='utf-8')
        else:
            (stage / 'NOT_UPLOADABLE.txt').write_text(
                'NOT UPLOADABLE / 不可上传\nNo AppBuild or fake IDs are present.\n'
                'Obtain the actual Demo AppID and its macOS DepotID; provide a clean single-app build directory.\n', encoding='utf-8')
        (stage / 'manifest.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
        if out.exists():
            raise ValueError('Output appeared during preparation; refusing overwrite')
        stage.rename(out)
    return report


def verify(prepared):
    root = Path(prepared).resolve(strict=True)
    report = json.loads((root/'manifest.json').read_text(encoding='utf-8'))
    actual = inventory(root/'content') if (root/'content').is_dir() else []
    if actual != report['files']:
        raise ValueError('Content differs from frozen manifest (added, removed, modified or permission-changed file)')
    if report['app_id']:
        expected_names = {'depot_macos.vdf', 'app_preview.vdf'}
        if report['upload_vdf_generated']:
            expected_names.add('app_upload.vdf')
        if {p.name for p in (root/'scripts').iterdir()} != expected_names:
            raise ValueError('Unexpected build script; do not add upload scripts to a preview snapshot')
        expected = depot_vdf(positive_id(report['depot_id']), actual)
        if (root/'scripts/depot_macos.vdf').read_text(encoding='utf-8') != expected:
            raise ValueError('Depot mapping differs from explicit manifest')
        for filename, preview in [('app_preview.vdf', True)] + ([('app_upload.vdf', False)] if report['upload_vdf_generated'] else []):
            expected = app_vdf(positive_id(report['app_id']), report['depot_id'], root/'content', root/'steampipe-cache', report['version'], preview)
            if (root/'scripts'/filename).read_text(encoding='utf-8') != expected:
                raise ValueError('App VDF differs from safe generated configuration')
    elif list(root.rglob('*.vdf')):
        raise ValueError('ID-less plan must not contain executable VDFs')
    return {'local_integrity': 'passed', 'files': len(actual), 'uploaded': False, 'steam_release_ready': False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--build-dir', type=Path)
    parser.add_argument('--expected-version')
    parser.add_argument('--app-id')
    parser.add_argument('--depot-id')
    parser.add_argument('--ids-confirmed', action='store_true')
    parser.add_argument('--emit-upload-vdf', action='store_true')
    parser.add_argument('--verify', type=Path)
    args = parser.parse_args()
    try:
        if args.verify:
            if args.output or args.build_dir or args.app_id or args.depot_id or args.ids_confirmed or args.emit_upload_vdf:
                parser.error('--verify cannot be combined with preparation arguments')
            result = verify(args.verify)
        else:
            if not args.output:
                parser.error('--output is required')
            result = prepare(args.output, args.build_dir, args.expected_version, args.app_id,
                             args.depot_id, args.ids_confirmed, args.emit_upload_vdf)
        print(json.dumps(result, ensure_ascii=False, indent=2))
    except (ValueError, OSError, plistlib.InvalidFileException, KeyError) as exc:
        parser.exit(2, f'Preparation blocked: {exc}\n')


if __name__ == '__main__':
    main()
