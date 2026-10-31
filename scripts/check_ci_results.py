#!/usr/bin/env python3
"""Reject missing/failed selected checks and unexpected skips after CI routing."""
import argparse
import json
import os
import sys

FLAGS = ('web', 'godot', 'export_game', 'swarm', 'flower', 'garden', 'content')
JOBS = {'web': 'web', 'godot': 'godot', 'web-candidate': 'export_game',
        'swarm': 'swarm', 'flower': 'flower', 'garden': 'garden', 'content': 'content'}


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
    if errors:
        return errors
    if outputs['export_game'] == 'true' and (outputs['web'] != 'true' or outputs['godot'] != 'true'):
        return ['Export requires both Web and Godot checks']
    if only is not None and only not in JOBS:
        return ['Unknown check selector']
    for job, flag in JOBS.items():
        if only is not None and job != only:
            continue
        selected = outputs[flag] == 'true'
        if job == 'content' and outputs['web'] == 'true':
            selected = False  # The Web suite already contains both content tests.
        expected = 'success' if selected else 'skipped'
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
        errors = validate(json.loads(os.environ['CI_NEEDS']), args.only)
    except (KeyError, ValueError) as exc:
        errors = [f'Invalid dependency results: {exc}']
    summary = '\n'.join(errors) if errors else 'All selected checks passed; unselected checks were explicitly skipped.'
    print(summary)
    if os.environ.get('GITHUB_STEP_SUMMARY'):
        with open(os.environ['GITHUB_STEP_SUMMARY'], 'a', encoding='utf-8') as stream:
            stream.write(summary + '\n')
    return 1 if errors else 0


if __name__ == '__main__':
    sys.exit(main())
