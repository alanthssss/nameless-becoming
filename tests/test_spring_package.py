"""Packaging failure controls; all positive media and exports are synthetic."""
import hashlib
import json
from pathlib import Path
import plistlib
import unittest
import zipfile

from tools import package_spring_review as tool
import test_spring_review_gate as fixtures
REVISION = fixtures.REVISION

class PackageTests(unittest.TestCase):
    setUp = fixtures.ReviewGateTests.setUp
    chapter = fixtures.ReviewGateTests.chapter

    def prepare(self):
        self.export = self.root / 'synthetic-export.zip'
        with zipfile.ZipFile(self.export, 'w') as archive:
            archive.writestr('Synthetic.app/Contents/Info.plist', plistlib.dumps({
                'CFBundleShortVersionString': '0.0.0', 'CFBundleExecutable': 'Synthetic'}))
            archive.writestr('Synthetic.app/Contents/MacOS/Synthetic', b'synthetic fixture; not runnable Godot')
        self.export_record = {'revision': REVISION, 'sha256': tool.digest(self.export),
            'entries': {'spring-03-05': 'passed', 'comparison-07-09': 'passed'}, 'isolated_saves': True}
        self.output = self.root / 'candidate.zip'
        self.receipt = {'schema': 1, 'goal': 'spring-03-05-review', 'claim': 'candidate',
            'revision': REVISION, 'evidence': []}
        for row in tool.read(tool.CONTRACT)['criteria']:
            path = self.root / (row['id'] + '.json')
            path.write_text(json.dumps(self.record if row['id'] == 'experience' else {'synthetic': True}))
            self.receipt['evidence'].append({'criterion': row['id'], 'kind': row['kind'],
                'status': 'passed', 'revision': REVISION, 'path': path.name, 'sha256': tool.digest(path)})

    def refresh_review(self):
        path = self.root / 'experience.json'; path.write_text(json.dumps(self.record))
        next(e for e in self.receipt['evidence'] if e['criterion'] == 'experience')['sha256'] = tool.digest(path)

    def pack(self):
        return tool.package(self.export, self.export_record, self.receipt, self.root, REVISION, self.output)

    def blocked(self, message):
        with self.assertRaisesRegex(ValueError, message): self.pack()
        self.assertFalse(self.output.exists(), 'failed review must not create player package')

    def test_synthetic_candidate_contains_controls_and_two_isolated_entries(self):
        self.prepare(); result = self.pack()
        self.assertEqual(tool.digest(self.output), result['sha256'])
        with zipfile.ZipFile(self.output) as archive:
            names = archive.namelist()
            self.assertTrue(all(n.startswith('雨来之前-0.0.0-池岸归途-aaaaaaaa/') for n in names))
            commands = [n for n in names if n.endswith('.command')]
            self.assertEqual(len(commands), 2)
            expected = {
                '开始池岸归途.command': ('--spring-journey', 'pond_journey_rebuild_v3.json'),
                '风路对照.command': ('--long-journey', 'summer_long_07_09_r8.json'),
            }
            self.assertEqual({Path(n).name for n in commands}, set(expected))
            for name in commands:
                body = archive.read(name).decode()
                flag, save = expected[Path(name).name]
                self.assertIn(flag, body)
                self.assertIn(save, body)
                self.assertIn('--entry-chapter=0', body)
                self.assertIn('extra+=(--chapter=0)', body)
                self.assertTrue(archive.getinfo(name).external_attr >> 16 & 0o111)
            notes = archive.read(next(n for n in names if n.endswith('先读我.txt'))).decode()
            self.assertEqual(notes, tool.README.read_text().replace('{version}', '0.0.0'))
            self.assertFalse(any('/存档/' in n or '/日志/' in n or '/raw/' in n for n in names))
            metadata = json.loads(archive.read(next(n for n in names if n.endswith('版本信息.json'))))
            self.assertIs(metadata['human_accepted'], False)
            self.assertIs(metadata['full_game_completed'], False)

    def rename_executable(self, executable):
        with zipfile.ZipFile(self.export, 'w') as archive:
            archive.writestr('Synthetic.app/Contents/Info.plist', plistlib.dumps({
                'CFBundleShortVersionString': '0.0.0', 'CFBundleExecutable': executable}))
            archive.writestr('Synthetic.app/Contents/MacOS/' + executable, b'synthetic fixture')
        self.export_record['sha256'] = tool.digest(self.export)

    def test_localized_executable_keeps_a_quoted_relative_launch_path(self):
        self.prepare()
        executable = '雨来之前 · 池岸归途 0.17.0'
        self.rename_executable(executable)
        self.pack()
        with zipfile.ZipFile(self.output) as archive:
            for name in archive.namelist():
                if name.endswith('.command'):
                    body = archive.read(name).decode()
                    self.assertIn('/Contents/MacOS/' + executable + '" ', body)

    def test_executable_cannot_escape_app_or_inject_shell_syntax(self):
        for executable in ['../outside', '..', 'bad"name', '$(touch bad)', '`touch bad`', 'bad\\name', 'bad\nname']:
            with self.subTest(executable=repr(executable)):
                self.prepare()
                self.rename_executable(executable)
                with self.assertRaises(ValueError):
                    self.pack()
                self.assertFalse(self.output.exists())

    def test_maintenance_cannot_generate_player_package(self):
        self.prepare(); self.receipt['claim'] = 'maintenance'
        self.blocked('claim does not match')

    def test_known_answer_review_cannot_generate_player_package(self):
        self.prepare(); self.record['chapters'][1]['method'] = 'known_answer_route'; self.refresh_review()
        self.blocked('known_answer_route')

    def test_unresolved_basic_blocker_blocks_even_with_complete_technical_receipt(self):
        self.prepare(); self.record['blockers'] = ['route can bypass the central decision']; self.refresh_review()
        self.blocked('blockers')

    def test_changed_export_cannot_reuse_previous_launch_results(self):
        self.prepare(); self.export.write_bytes(self.export.read_bytes() + b'changed')
        self.blocked('differs from the tested archive')

    def test_missing_comparison_launch_blocks(self):
        self.prepare(); self.export_record['entries'].pop('comparison-07-09')
        self.blocked('both exported entries')

    def test_changed_evidence_blocks(self):
        self.prepare(); (self.root / 'raw/04.png').write_bytes(b'tampered')
        self.blocked('does not match the raw evidence')

    def test_existing_package_is_preserved(self):
        self.prepare(); self.output.write_bytes(b'old package')
        with self.assertRaisesRegex(ValueError, 'overwrite'): self.pack()
        self.assertEqual(self.output.read_bytes(), b'old package')

if __name__ == '__main__': unittest.main()
