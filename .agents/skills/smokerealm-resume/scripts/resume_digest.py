"""Bounded, read-only Git delta; no network calls or repository mutations."""
import argparse
import collections
import json
import subprocess
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--repo', required=True)
    parser.add_argument('--base')
    parser.add_argument('--remote', default='origin/master')
    args = parser.parse_args()
    repo = Path(args.repo).resolve()

    def git(*command):
        result = subprocess.run(['git', '-C', str(repo), *command],
                                capture_output=True, text=True, timeout=30)
        if result.returncode:
            raise RuntimeError(result.stderr.strip()[:600])
        return result.stdout.strip()

    checkpoint = repo / '.agents' / 'resume-checkpoint.json'
    saved = json.loads(checkpoint.read_text(encoding='utf-8-sig')) if checkpoint.exists() else {}
    base = args.base or saved.get('observed_remote_sha')
    head = git('rev-parse', 'HEAD')
    remote = git('rev-parse', '--verify', args.remote + '^{commit}')
    status = git('status', '--short').splitlines()
    report = dict(head=head, remote=remote, freshness='Local remote ref; fetch explicitly first',
                  dirty_count=len(status), dirty_sample=status[:20])
    if base:
        base = git('rev-parse', '--verify', base + '^{commit}')
        span = base + '..' + remote
        paths = git('diff', '--name-only', base, remote).splitlines()
        rows = git('log', '--no-merges', '--format=%h %an: %s', span).splitlines()
        groups = collections.Counter('/'.join(p.split('/')[:2]) for p in paths)
        owned = saved.get('task_paths', [])
        overlap = [p for p in paths if any(p == x or p.startswith(x.rstrip('/') + '/') for x in owned)]
        report.update(base=base, common_ancestor=git('merge-base', base, remote),
                      commit_count=int(git('rev-list', '--count', span)),
                      substantive_sample=[r for r in rows if 'build: export Godot' not in r][:12],
                      changed_path_count=len(paths), path_groups=dict(groups.most_common(16)),
                      overlap_count=len(overlap), overlap_sample=overlap[:20])
    else:
        report['next'] = 'No checkpoint: choose a verified last observed SHA; do not guess.'
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
