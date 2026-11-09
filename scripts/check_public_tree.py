#!/usr/bin/env python3
"""在公开发布前检查工作区、暂存区和 Git 历史；仅报告路径，不打印凭据。"""
import json
from pathlib import Path
import re
import subprocess
import sys

root = Path(__file__).resolve().parent.parent
patterns = [
    re.compile(rb'\bsk-[A-Za-z0-9_-]{20,}'),
    re.compile(rb'\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})'),
    re.compile(rb'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'),
    re.compile(rb'\bAKIA[0-9A-Z]{16}\b'),
]
issues = set()

def git(*args):
    return subprocess.check_output(['git', '-C', str(root), *args])

def check(path, data, origin):
    parts = Path(path).parts
    forbidden = any(x in parts for x in ['build', '.build', '.swiftpm', 'xcuserdata'])
    forbidden |= Path(path).suffix.lower() in {'.pdf', '.docx', '.p12', '.p8', '.mobileprovision', '.pem', '.key'}
    forbidden |= Path(path).name.startswith('.env') or Path(path).name in {'.deepseek-once', 'readings-v1.json', 'verification.json', 'reload-verification.json'}
    if forbidden:
        issues.add(f'{origin}: 私人或生成文件 {path}')
    if any(pattern.search(data) for pattern in patterns):
        issues.add(f'{origin}: 疑似凭据 {path}')
    if path == 'Sources/LiuYaoCore/Resources/classics.json':
        try:
            if json.loads(data).get('passages'):
                issues.add(f'{origin}: 不得公开私人古籍正文 {path}')
        except (ValueError, UnicodeError):
            issues.add(f'{origin}: 资料占位格式无效 {path}')

paths = git('ls-files', '-z').decode().split('\0')
for path in filter(None, paths):
    local = root/path
    if local.is_file():
        check(path, local.read_bytes(), '工作区')
    check(path, git('show', ':'+path), '暂存区')

try:
    commits = git('rev-list', '--all').decode().splitlines()
except subprocess.CalledProcessError:
    commits = []
seen = set()
for commit in commits:
    for entry in git('ls-tree', '-r', '-z', commit).split(b'\0'):
        if not entry:
            continue
        metadata, path = entry.split(b'\t', 1)
        _, kind, blob = metadata.split()
        marker = (path, blob)
        if marker in seen or kind != b'blob':
            continue
        seen.add(marker)
        check(path.decode(), git('cat-file', 'blob', blob.decode()), '历史')

if issues:
    print('\n'.join(sorted(issues)))
    sys.exit(1)
print(f'公开文件检查通过：{len(list(filter(None, paths)))} 个跟踪文件，{len(commits)} 个提交；未发现匹配凭据或私人资料。')
