#!/usr/bin/env python3
"""Reject missing/failed selected checks and unexpected skips after CI routing."""
import argparse
import json
import os
import re
import sys

FLAGS = ('web', 'godot', 'export_game', 'swarm', 'flower', 'garden', 'content')
JOBS = {'web': 'web', 'godot': 'godot', 'web-candidate': 'export_game',
        'swarm': 'swarm', 'flower': 'flower', 'garden': 'garden', 'content': 'content'}
REUSABLE = ('web', 'godot', 'web-candidate', 'swarm', 'flower', 'garden', 'swarm-except-region')


def validate(needs: dict, only: str | None = None) -> list[str]:
    if not isinstance(needs, dict):
        return ['Missing dependency results']
    scope = needs.get('scope')
    if not isinstance(scope, dict) or scope.get('result') != 'success':
        return ['Scope classification did not succeed']
    outputs = scope.get('outputs')
    if not isinstance(outputs, dict):
        return ['Missing scope outputs']
    errors = [f'Invalid or missing scope output: {key}' for key in FLAGS
              if outputs.get(key) not in ('true', 'false')]
    if outputs.get('godot_suite') not in ('routes', 'full'):
        errors.append('Invalid or missing godot_suite')
    allowed_swarm = ('full', 'region') if outputs.get('swarm') == 'true' else ('none',)
    if outputs.get('swarm_suite') not in allowed_swarm:
        errors.append('Invalid or missing swarm_suite for selected scope')
    if errors:
        return errors
    if outputs['export_game'] == 'true' and (outputs['web'] != 'true' or outputs['godot'] != 'true'):
        return ['Export requires both Web and Godot checks']
    try:
        reused = json.loads(outputs.get('reused', ''))
    except (TypeError, ValueError):
        return ['Missing or invalid check reuse decision']
    if (not isinstance(reused, list) or any(name not in REUSABLE for name in reused)
            or len(set(reused)) != len(reused)):
        return ['Invalid list of reused checks']
    if any(outputs[JOBS[name]] != 'true' for name in reused if name != 'swarm-except-region'):
        return ['Cannot reuse an unselected check']
    if 'swarm-except-region' in reused and (outputs['swarm_suite'] != 'full' or 'swarm' in reused):
        return ['Partial Swarm reuse requires the full scope and a fresh regional result']
    source = outputs.get('source_run')
    if not isinstance(source, str) or (reused and not re.fullmatch(r'[1-9][0-9]*', source)) or (not reused and source != 'none'):
        return ['Invalid source run for check reuse']
    if only is not None and only not in JOBS:
        return ['Unknown check selector']
    for job, flag in JOBS.items():
        if only is not None and job != only:
            continue
        selected = outputs[flag] == 'true'
        if job == 'content' and outputs['web'] == 'true':
            selected = False  # The Web suite already contains both content tests.
        expected = 'success' if selected and job not in reused else 'skipped'
        result = needs.get(job)
        actual = result.get('result') if isinstance(result, dict) else None
        if actual != expected:
            errors.append(f'{job}: expected {expected}, got {actual!r}')
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--only', choices=JOBS)
    args = parser.parse_args()
    try:
        needs = json.loads(os.environ['CI_NEEDS'])
        errors = validate(needs, args.only)
    except (KeyError, ValueError) as exc:
        errors = [f'Invalid dependency results: {exc}']
    summary = '\n'.join(errors) if errors else 'Selected checks passed via execution or verified reuse.'
    if not errors:
        outputs = needs['scope']['outputs']
        reused = [name for name in json.loads(outputs['reused']) if not args.only or args.only == name
                  or (args.only == 'swarm' and name == 'swarm-except-region')]
        if reused:
            repo = os.environ['GITHUB_REPOSITORY']
            summary += f" Reused {', '.join(reused)} from https://github.com/{repo}/actions/runs/{outputs['source_run']}."
    print(summary)
    if os.environ.get('GITHUB_STEP_SUMMARY'):
        with open(os.environ['GITHUB_STEP_SUMMARY'], 'a', encoding='utf-8') as stream:
            stream.write(summary + '\n')
    return 1 if errors else 0


if __name__ == '__main__':
    sys.exit(main())
