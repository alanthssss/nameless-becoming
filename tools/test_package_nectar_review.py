"""Package gate tests. ALL positive evidence and app binaries are synthetic.

Passing fixtures exercise declarations/integrity only; they are not actual
native game runs, independent reviews, exports or player acceptance evidence.
"""
from __future__ import annotations
import copy
import configparser
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import stat
import subprocess
import tempfile
import unittest
import zipfile

if __package__:
    from . import package_nectar_review as tool
else:
    import package_nectar_review as tool

REVISION = 'a'*40
APP = '采蜜测试 · Fixture.app'
EXE = '采蜜测试 Fixture'

class PackageTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='synthetic-nectar-package-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.export = self.root/'synthetic-export.zip'
        self.output = self.root/'candidate.zip'
        self.entries = [
            (APP+'/Contents/Info.plist',plistlib.dumps({'CFBundleShortVersionString':'0.0.0','CFBundleExecutable':EXE}),0o100644),
            (APP+'/Contents/MacOS/'+EXE,b'#!/bin/sh\nprintf "%s\\n" "$@" > "$NECTAR_TEST_ARGS"\n',0o100755),
            (APP+'/Contents/Resources/synthetic.pck',b'SYNTHETIC; not a game export',0o100640)
        ]
        self.write_zip()
        launcher_hash = hashlib.sha256(tool.launcher_text(APP,EXE).encode()).hexdigest()
        self.export_record = {'revision':REVISION,'sha256':tool.digest(self.export),'engine':'4.6.2',
            'custom_features':['nectar_mvp'],'entry':'nectar-harvest','save_filename':tool.SAVE_NAME,'launcher_sha256':launcher_hash}
        self.receipt = {'schema':1,'goal':'nectar-harvest-mvp','claim':'candidate','revision':REVISION,
            'human_acceptance_claim':False,'blockers':[],'warnings':[],'evidence':[]}
        for row in tool.read(tool.CONTRACT)['criteria']:
            artifacts = []
            for role in row['roles']:
                suffix = '.mp4' if role == 'continuous_video' else '.png' if role == 'native_frame' else '.log' if role == 'rules_log' else '.json'
                path = self.root/(row['id']+'-'+role+suffix)
                content = (json.dumps({'synthetic_fixture':True,'id':'nectar-harvest-v1','version':3}).encode()
                           if role in {'save_before','save_after'} else b'SYNTHETIC TEST DATA; not actual game evidence\n')
                path.write_bytes(content)
                artifact = {'role':role,'path':path.name,'sha256':tool.digest(path),'revision':REVISION}
                if role in {'legacy_save_before','legacy_save_after'}: artifact['save_name'] = 'old-journey.json'
                artifacts.append(artifact)
            record = {'synthetic_fixture':True,'revision':REVISION,'status':'passed','method':row['methods'][0],
                'summary':'Synthetic verification declaration for tooling tests only.','blockers':[],'warnings':[],'artifacts':artifacts}
            if row['id'] == 'NH-C03': record.update(checks=3,failures=0)
            if row['id'] == 'NH-C05': record['viewport_sizes'] = [[960,600],[1280,800]]
            if row['id'] == 'NH-C06': record.update(author='fixture-author',reviewer='fixture-reviewer',reviewer_kind='AI')
            if row['id'] == 'NH-C07':
                record.update(checks={key:'passed' for key in tool.ENTRY_CHECKS},export_sha256=self.export_record['sha256'],
                    launcher_sha256=launcher_hash,entry='nectar-harvest',save_filename=tool.SAVE_NAME,
                    legacy_save_hashes_before={'old-journey.json':tool.digest(self.root/'NH-C07-legacy_save_before.json')},
                    legacy_save_hashes_after={'old-journey.json':tool.digest(self.root/'NH-C07-legacy_save_after.json')})
            if row['id'] == 'NH-C08':
                record.update(cost={'observed_start':'synthetic start','observed_end':'synthetic end','coverage':'synthetic fixture',
                    'active':None,'billed':None,'cumulative':None,'remaining':None,'new_purchases':0},
                    tracking='synthetic readback',ci='synthetic pending',integration='synthetic draft',human_acceptance_claim=False)
            path = self.root/(row['id']+'.json')
            path.write_text(json.dumps(record))
            self.receipt['evidence'].append({'criterion':row['id'],'kind':row['kind'],'status':'passed','revision':REVISION,'path':path.name,'sha256':tool.digest(path)})

    def write_zip(self):
        with zipfile.ZipFile(self.export,'w') as archive:
            for name,data,mode in self.entries:
                item = zipfile.ZipInfo(name); item.create_system = 3; item.external_attr = mode << 16
                archive.writestr(item,data)

    def rewrite_export(self):
        self.write_zip()
        self.export_record['sha256'] = tool.digest(self.export)
        self.mutate('NH-C07',lambda record: record.update(export_sha256=self.export_record['sha256']))

    def mutate(self,criterion,fn):
        item = next(item for item in self.receipt['evidence'] if item['criterion'] == criterion)
        path = self.root/item['path']; record = tool.read(path); fn(record)
        path.write_text(json.dumps(record)); item['sha256'] = tool.digest(path)

    def pack(self):
        return tool.package(self.export,self.export_record,self.receipt,self.root,REVISION,self.output)

    def blocked(self,pattern):
        with self.assertRaisesRegex(ValueError,pattern): self.pack()
        self.assertFalse(self.output.exists())

    def test_synthetic_candidate_layout_permissions_and_boundaries(self):
        result = self.pack()
        self.assertEqual(result['sha256'],tool.digest(self.output))
        with zipfile.ZipFile(self.output) as archive:
            names = archive.namelist()
            self.assertTrue(all(name.startswith('采蜜与蜂舞-Demo/') for name in names))
            commands = [name for name in names if name.endswith('.command')]
            self.assertEqual(commands,['采蜜与蜂舞-Demo/开始采蜜小店.command'])
            self.assertEqual(archive.read(commands[0]).decode(),tool.launcher_text(APP,EXE))
            self.assertTrue(archive.getinfo(commands[0]).external_attr >> 16 & 0o111)
            self.assertEqual(archive.getinfo('采蜜与蜂舞-Demo/'+APP+'/Contents/Resources/synthetic.pck').external_attr >> 16 & 0o777,0o640)
            self.assertFalse(any('/存档/' in name or '/日志/' in name or 'NH-C' in name for name in names))
            notes = archive.read('采蜜与蜂舞-Demo/先读我.txt').decode()
            self.assertIn('不代表 Alan、外部玩家、美术专家或 Steam 已经接受',notes)
            metadata = json.loads(archive.read('采蜜与蜂舞-Demo/版本信息.json'))
            self.assertIs(metadata['human_accepted'],False)
            self.assertIs(metadata['full_game_completed'],False)
            self.assertEqual(metadata['launcher_sha256'],self.export_record['launcher_sha256'])

    @unittest.skipUnless(shutil.which('zsh'),'zsh required for actual launcher execution')
    def test_default_launcher_profile_matches_godot_custom_user_directory(self):
        project = configparser.ConfigParser(interpolation=None)
        project.read_string('[godot_file]\n'+(tool.ROOT/'prototypes/swarm-flight/project.godot').read_text())
        application = project['application']
        self.assertTrue(application.getboolean('config/use_custom_user_dir'))
        profile = json.loads(application['config/custom_user_dir_name'])
        expected = Path.home()/'Library/Application Support'/profile/tool.SAVE_NAME
        main = (tool.ROOT/'prototypes/swarm-flight/nectar_harvest_main.gd').read_text()
        self.assertIn('const SAVE_PATH := "user://'+tool.SAVE_NAME+'"',main)
        stage = self.root/'default launch fixture'; stage.mkdir()
        tool.extract_export(self.export,stage)
        command = stage/'开始采蜜小店.command'; command.write_text(tool.launcher_text(APP,EXE)); command.chmod(0o755)
        # Exercise the actual command with no override, but prevent its mkdir
        # from touching any real user profile. The synthetic binary only records args.
        helpers = self.root/'test helpers'; helpers.mkdir()
        mkdir = helpers/'mkdir'; mkdir.write_text('#!/bin/sh\nexit 0\n'); mkdir.chmod(0o755)
        args_file = self.root/'default-args.txt'
        env = dict(os.environ,NECTAR_TEST_ARGS=str(args_file),PATH=str(helpers)+os.pathsep+os.environ['PATH'])
        subprocess.run([str(command)],env=env,check=True)
        args = args_file.read_text().splitlines()
        self.assertIn('--nectar-harvest',args)
        self.assertEqual([arg for arg in args if arg.startswith('--progress-file=')],['--progress-file='+str(expected)])
        self.assertNotIn(str(stage/'存档'),args_file.read_text())

    @unittest.skipUnless(shutil.which('zsh'),'zsh required for actual launcher execution')
    def test_exact_launcher_runs_expected_binary_and_only_explicit_isolated_override(self):
        stage = self.root/'launch fixture'; stage.mkdir()
        tool.extract_export(self.export,stage)
        command = stage/'开始采蜜小店.command'; command.write_text(tool.launcher_text(APP,EXE)); command.chmod(0o755)
        args_file = self.root/'observed-args.txt'; env = dict(os.environ,NECTAR_TEST_ARGS=str(args_file))
        save = self.root/'test isolated'/tool.SAVE_NAME
        subprocess.run([str(command),'--progress-file='+str(save)],env=env,check=True)
        args = args_file.read_text().splitlines()
        self.assertIn('--nectar-harvest',args)
        self.assertIn('--progress-file='+str(save),args)
        self.assertNotIn('--spring-journey',args)
        self.assertTrue(save.parent.is_dir())
        for bad in ['--spring-journey','--progress-file=relative/'+tool.SAVE_NAME,'--progress-file=/tmp/pond_journey_rebuild_v3.json','--progress-file']:
            with self.subTest(bad=bad):
                args_file.unlink()
                completed = subprocess.run([str(command),bad],env=env,capture_output=True)
                self.assertNotEqual(completed.returncode,0)
                self.assertFalse(args_file.exists())
                args_file.write_text('restore marker')

    def test_missing_criterion(self):
        self.receipt['evidence'].pop(); self.blocked('missing criteria')
    def test_contract_cannot_remove_a_gdd_criterion_to_pass(self):
        contract = tool.read(tool.CONTRACT); contract['criteria'].pop()
        errors = tool.preflight(contract,self.receipt,self.root,REVISION,self.export_record,self.export)
        self.assertIn('contract must retain exactly NH-C01..08',errors)
    def test_duplicate_criterion(self):
        self.receipt['evidence'].append(copy.deepcopy(self.receipt['evidence'][0])); self.blocked('duplicated criterion')
    def test_wrong_criterion_kind(self):
        self.receipt['evidence'][5]['kind'] = 'technical'; self.blocked('evidence kind')
    def test_maintenance_cannot_package(self):
        self.receipt['claim'] = 'maintenance'; self.blocked('claim')
    def test_acceptance_cannot_be_implied(self):
        self.receipt['human_acceptance_claim'] = True; self.blocked('human_acceptance_claim')
    def test_boolean_schema_rejected(self):
        self.receipt['schema'] = True; self.blocked('integer')
    def test_stale_receipt(self):
        self.receipt['revision'] = 'b'*40; self.blocked('revision')
    def test_short_revision(self):
        with self.assertRaisesRegex(ValueError,'full 40-character'):
            tool.package(self.export,self.export_record,self.receipt,self.root,'a'*8,self.output)
    def test_missing_receipt_warning_account(self):
        self.receipt.pop('warnings'); self.blocked('warnings')
    def test_unresolved_warning(self):
        self.mutate('NH-C05',lambda r:r.update(warnings=[{'message':'overlapping HUD','disposition':'unresolved','reason':'later'}])); self.blocked('unresolved')
    def test_missing_record_warning_account(self):
        self.mutate('NH-C05',lambda r:r.pop('warnings')); self.blocked('warnings')
    def test_explicit_nonblocking_limit_allowed(self):
        self.mutate('NH-C08',lambda r:r.update(warnings=[{'message':'Historical total effort unknown','disposition':'nonblocking','reason':'Recorded as unknown; no claim of budget remaining.'}]))
        self.pack()
    def test_basic_blocker_rejected(self):
        self.mutate('NH-C06',lambda r:r.update(blockers=['unreadable goal'])); self.blocked('blockers')
    def test_stale_nested_artifact(self):
        self.mutate('NH-C01',lambda r:r['artifacts'][0].update(revision='c'*40)); self.blocked('stale artifact')
    def test_tampered_nested_evidence(self):
        (self.root/'NH-C01-input_trace.json').write_bytes(b'changed'); self.blocked('hash mismatch')
    def test_tampered_record(self):
        (self.root/'NH-C01.json').write_bytes(b'changed'); self.blocked('hash mismatch')
    def test_missing_native_video(self):
        self.mutate('NH-C06',lambda r:r.update(artifacts=r['artifacts'][:1])); self.blocked('continuous_video')
    def test_image_cannot_replace_continuous_video(self):
        (self.root/'video.png').write_bytes(b'synthetic')
        self.mutate('NH-C06',lambda r:r['artifacts'][1].update(path='video.png',sha256=tool.digest(self.root/'video.png')))
        self.blocked('video file')
    def test_author_cannot_review_self(self):
        self.mutate('NH-C06',lambda r:r.update(reviewer=' FIXTURE-AUTHOR ')); self.blocked('independent reviewer')
    def test_actual_rules_counts_required(self):
        self.mutate('NH-C03',lambda r:r.update(checks=0)); self.blocked('rules-test counts')
    def test_failed_rules_rejected(self):
        self.mutate('NH-C03',lambda r:r.update(failures=1)); self.blocked('rules-test counts')
    def test_both_resolutions_required(self):
        self.mutate('NH-C05',lambda r:r.update(viewport_sizes=[[1280,800]])); self.blocked('both native viewport')
    def test_every_export_operation_required(self):
        original = tool.read(self.root/'NH-C07.json')
        for key in tool.ENTRY_CHECKS:
            with self.subTest(check=key):
                self.mutate('NH-C07',lambda r:r.update(original))
                self.mutate('NH-C07',lambda r:r['checks'].pop(key))
                self.blocked('exported entry')
    def test_legacy_hashes_required(self):
        self.mutate('NH-C07',lambda r:r.update(legacy_save_hashes_before={},legacy_save_hashes_after={})); self.blocked('legacy-save hashes')
    def test_legacy_changes_rejected(self):
        self.mutate('NH-C07',lambda r:r.update(legacy_save_hashes_after={'old-journey.json':'c'*64})); self.blocked('legacy-save hashes')
    def test_fabricated_legacy_hashes_without_matching_bytes_rejected(self):
        self.mutate('NH-C07',lambda r:r.update(legacy_save_hashes_before={'old-journey.json':'c'*64},legacy_save_hashes_after={'old-journey.json':'c'*64}))
        self.blocked('retained snapshot bytes')
    def test_missing_legacy_snapshot_rejected(self):
        self.mutate('NH-C07',lambda r:r.update(artifacts=[a for a in r['artifacts'] if a['role'] != 'legacy_save_after']))
        self.blocked('legacy_save_after')
    def test_new_save_cannot_be_old_journey_payload(self):
        path = self.root/'NH-C07-save_before.json'; path.write_text(json.dumps({'id':'pond-journey-rebuild-v3','version':1}))
        self.mutate('NH-C07',lambda r:next(a for a in r['artifacts'] if a['role'] == 'save_before').update(sha256=tool.digest(path)))
        self.blocked('independent identity')
    def test_unmigrated_save_rejected_for_new_candidate(self):
        path = self.root/'NH-C07-save_before.json'
        path.write_text(json.dumps({'id':'nectar-harvest-v1','version':1}))
        self.mutate('NH-C07',lambda r:next(a for a in r['artifacts'] if a['role'] == 'save_before').update(sha256=tool.digest(path)))
        self.blocked('independent identity')
    def test_negative_cost_is_not_unknown(self):
        self.mutate('NH-C08',lambda r:r['cost'].update(cumulative=-1)); self.blocked('finite and nonnegative')
    def test_export_entry_wrong(self):
        self.export_record['entry'] = 'spring-journey'; self.blocked('entry')
    def test_independent_save_name_required(self):
        self.export_record['save_filename'] = 'pond_journey_rebuild_v3.json'; self.blocked('save_filename')
    def test_direct_app_feature_required(self):
        self.export_record['custom_features'] = []; self.blocked('nectar_mvp')
    def test_changed_export_rejected(self):
        with self.export.open('ab') as stream: stream.write(b'changed')
        self.blocked('differs from the tested export')
    def test_changed_launcher_rejected(self):
        self.export_record['launcher_sha256'] = 'c'*64
        self.mutate('NH-C07',lambda r:r.update(launcher_sha256='c'*64)); self.blocked('differs from the tested launcher')
    def test_missing_cost_account_rejected(self):
        self.mutate('NH-C08',lambda r:r['cost'].pop('cumulative')); self.blocked('unknown costs')
    def test_traversal_and_absolute_evidence_paths(self):
        for path in ['../outside','/outside','C:/outside','sub\\outside']:
            with self.subTest(path=path):
                self.mutate('NH-C01',lambda r:r['artifacts'][0].update(path=path)); self.blocked('artifact path')
    def test_evidence_symlink_rejected(self):
        (self.root/'linked').symlink_to(self.root/'NH-C01-input_trace.json')
        self.mutate('NH-C01',lambda r:r['artifacts'][0].update(path='linked')); self.blocked('symlinks')
    def test_zip_path_escape_rejected(self):
        original = list(self.entries)
        for path in ['../outside','/outside','C:/outside','bad\\outside','.']:
            with self.subTest(path=path):
                self.entries = original+[(path,b'bad',0o100644)]; self.rewrite_export(); self.blocked('Unsafe path')
    def test_zip_symlink_rejected(self):
        self.entries.append((APP+'/Contents/link',b'/tmp/other',0o120777)); self.rewrite_export(); self.blocked('symlink')
    def test_zip_special_file_rejected(self):
        self.entries.append((APP+'/Contents/pipe',b'fake',stat.S_IFIFO|0o600)); self.rewrite_export(); self.blocked('special file')
    def test_zip_case_collision_rejected(self):
        self.entries.append((APP+'/Contents/Resources/SYNTHETIC.PCK',b'collision',0o100644)); self.rewrite_export(); self.blocked('Duplicate export path')
    def test_extra_export_contents_rejected(self):
        self.entries.append(('unexpected.txt',b'not app',0o100644)); self.rewrite_export(); self.blocked('exactly one top-level app')
    def test_missing_export_executable_rejected(self):
        self.entries.pop(1); self.rewrite_export(); self.blocked('executable is missing')
    def test_shell_names_rejected(self):
        for bad in ['../evil','$(touch evil)','bad"name','`evil`','bad\\name','bad\nname']:
            with self.subTest(name=bad):
                with self.assertRaises(ValueError): tool.launcher_text(APP,bad)
    def test_existing_output_preserved(self):
        self.output.write_bytes(b'keep')
        with self.assertRaisesRegex(ValueError,'overwrite'): self.pack()
        self.assertEqual(self.output.read_bytes(),b'keep')
    def test_broken_output_symlink_preserved(self):
        self.output.symlink_to(self.root/'missing')
        with self.assertRaisesRegex(ValueError,'overwrite'): self.pack()
        self.assertTrue(self.output.is_symlink())

if __name__ == '__main__': unittest.main()
