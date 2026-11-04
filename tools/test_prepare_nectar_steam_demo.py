"""Synthetic packaging fixtures only; never Steam accounts or distributable builds."""
import json
from pathlib import Path
import plistlib
import tempfile
import unittest

if __package__:
    from . import prepare_nectar_steam_demo as tool
else:
    import prepare_nectar_steam_demo as tool


class PrepareSteamDemoTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='synthetic-steam-demo-')
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.build = self.root/'build'
        self.app = self.build/'Nectar Demo.app'
        (self.app/'Contents/MacOS').mkdir(parents=True)
        (self.app/'Contents/Resources').mkdir()
        self.binary = self.app/'Contents/MacOS/Nectar'
        self.binary.write_bytes(b'\xcf\xfa\xed\xfeSYNTHETIC_NOT_EXECUTABLE')
        self.binary.chmod(0o755)
        (self.app/'Contents/Resources/game.pck').write_bytes(b'SYNTHETIC_NOT_A_GAME')
        with (self.app/'Contents/Info.plist').open('wb') as f:
            plistlib.dump({'CFBundleExecutable': 'Nectar', 'CFBundleIdentifier': 'test.synthetic.nectar',
                          'CFBundleShortVersionString': '0.22.0'}, f)
        self.out = self.root/'prepared'

    def prepare(self, **kwargs):
        options = {'output': self.out, 'build_dir': self.build, 'expected_version': '0.22.0'}
        options.update(kwargs)
        return tool.prepare(**options)

    def identified(self, **kwargs):
        # Deliberately synthetic IDs exercise validation; no generated fixture is retained.
        return self.prepare(app_id='123456', depot_id='123457', ids_confirmed=True, **kwargs)

    def test_no_ids_produces_no_vdf_and_explicit_blocker(self):
        report = self.prepare()
        self.assertFalse(report['steam_release_ready'])
        self.assertTrue((self.out/'NOT_UPLOADABLE.txt').exists())
        self.assertEqual(list(self.out.rglob('*.vdf')), [])
        self.assertEqual(tool.verify(self.out)['local_integrity'], 'passed')

    def test_draft_without_build_does_not_invent_ids(self):
        report = tool.prepare(self.out)
        self.assertIsNone(report['app_id'])
        self.assertEqual(report['files'], [])
        self.assertEqual(tool.verify(self.out)['files'], 0)

    def test_preview_is_default_and_has_no_wildcard_or_setlive(self):
        report = self.identified()
        text = (self.out/'scripts/app_preview.vdf').read_text()
        depot = (self.out/'scripts/depot_macos.vdf').read_text()
        self.assertIn('"Preview" "1"', text)
        self.assertNotIn('SetLive', text)
        self.assertNotIn('*', depot)
        self.assertIn('"DepotPath" "Nectar Demo.app/Contents/MacOS/"', depot)
        self.assertFalse((self.out/'scripts/app_upload.vdf').exists())
        self.assertEqual(len(report['files']), 3)
        self.assertEqual(tool.verify(self.out)['files'], 3)

    def test_upload_vdf_requires_explicit_flag_and_still_never_uploads(self):
        report = self.identified(emit_upload_vdf=True)
        self.assertIn('"Preview" "0"', (self.out/'scripts/app_upload.vdf').read_text())
        self.assertFalse(report['uploaded'])
        self.assertFalse(tool.verify(self.out)['steam_release_ready'])

    def test_missing_or_unconfirmed_ids_fail(self):
        for options in ({'app_id':'123456'}, {'app_id':'123456','depot_id':'123457'},
                        {'emit_upload_vdf':True}, {'ids_confirmed':True}):
            with self.subTest(options=options), self.assertRaises(ValueError):
                self.prepare(**options)
        self.assertFalse(self.out.exists())

    def test_invalid_ids_fail_before_output(self):
        for value in ('0', '-1', '1.2', 'abc', '001', '4294967296', '1\n2', True):
            with self.subTest(value=value), self.assertRaises(ValueError):
                self.prepare(app_id=value, depot_id='123457', ids_confirmed=True)
        self.assertFalse(self.out.exists())

    def test_extra_old_app_and_internal_directory_rejected(self):
        for extra in ('Old.app', 'outputs', 'review-evidence'):
            path = self.build/extra
            path.mkdir()
            with self.subTest(extra=extra), self.assertRaises(ValueError):
                self.prepare()
            path.rmdir()

    def test_internal_and_sensitive_files_in_bundle_rejected(self):
        for name in ('evidence', 'config.vdf', '.env.local', 'private.pem', 'old.zip'):
            path = self.app/'Contents/Resources'/name
            path.write_text('synthetic')
            with self.subTest(name=name), self.assertRaises(ValueError):
                self.prepare()
            path.unlink()

    def test_symlink_cannot_escape_bundle(self):
        outside = self.root/'outside'
        outside.write_text('synthetic')
        (self.app/'Contents/Resources/link').symlink_to(outside)
        with self.assertRaises(ValueError):
            self.prepare()

    def test_wrong_version_and_missing_executable_permission_fail(self):
        with self.assertRaises(ValueError):
            self.prepare(expected_version='0.21.0')
        self.binary.chmod(0o644)
        with self.assertRaises(ValueError):
            self.prepare()

    def test_missing_directory_and_invalid_executable_fail(self):
        with self.assertRaises(OSError):
            self.prepare(build_dir=self.root/'missing')
        self.binary.write_bytes(b'not a mach-o')
        with self.assertRaises(ValueError):
            self.prepare()

    def test_output_cannot_be_inside_source_or_overwrite(self):
        with self.assertRaises(ValueError):
            self.prepare(output=self.build/'prepared')
        self.out.mkdir()
        with self.assertRaises(ValueError):
            self.prepare()

    def test_snapshot_is_independent_from_source_and_detects_changes(self):
        self.identified()
        self.binary.write_bytes(b'changed source')
        self.assertEqual(tool.verify(self.out)['local_integrity'], 'passed')
        (self.out/'content'/self.app.name/'Contents/Resources/new.txt').write_text('new')
        with self.assertRaises(ValueError):
            tool.verify(self.out)

    def test_modified_mapping_or_preview_rejected(self):
        self.identified()
        path = self.out/'scripts/app_preview.vdf'
        path.write_text(path.read_text().replace('"Preview" "1"', '"Preview" "0"'))
        with self.assertRaises(ValueError):
            tool.verify(self.out)

    def test_vdf_injection_paths_rejected(self):
        for name in ('bad"name', 'bad\nname', 'wild*card'):
            with self.subTest(name=name), self.assertRaises(ValueError):
                self.prepare(output=self.root/name)

    def test_preview_cannot_silently_gain_an_upload_script(self):
        self.identified()
        (self.out/'scripts/app_upload.vdf').write_text('unexpected')
        with self.assertRaises(ValueError):
            tool.verify(self.out)


if __name__ == '__main__':
    unittest.main()
