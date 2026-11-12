#!/usr/bin/env python3
"""Exercise installer parent resolution using fake devices and sysfs."""
import os
from pathlib import Path
import subprocess
import tempfile

script = (Path(__file__).resolve().parents[1] / 'installer/scripts/hao-installer.sh').read_text()
function = script.split('resolve_parent_disk() {', 1)[1].split('\ndetect_boot_disk() {', 1)[0]
with tempfile.TemporaryDirectory() as temp:
    root = Path(temp)
    dev = root / 'dev'
    sys = root / 'sys'
    dev.mkdir()
    for name in ('dm-0', 'dm-1', 'sda1', 'sda', 'sdb'):
        (dev / name).touch()
    slaves = sys / 'dm-0' / 'slaves'
    slaves.mkdir(parents=True)
    (slaves / 'sda1').symlink_to(dev / 'sda1')
    function = 'resolve_parent_disk() {' + function
    function = function.replace('/sys/class/block/', str(sys) + '/')
    function = function.replace('/dev/', str(dev) + '/')
    function = function.replace('[[ -b $node ]]', '[[ -e $node ]]')
    function = function.replace('-b ' + str(dev) + '/$parent', '-e ' + str(dev) + '/$parent')
    shell = '''set -euo pipefail
lsblk() {
  case "$*" in
    *TYPE*dm-0*) echo dm ;;
    *TYPE*sda1*) echo part ;;
    *TYPE*sda) echo disk ;;
    *PKNAME*sda1*) echo sda ;;
    *) return 1 ;;
  esac
}
''' + function + '\nresolve_parent_disk "$1"\n'
    result = subprocess.run(['bash', '-c', shell, 'test', str(dev / 'dm-0')], text=True, capture_output=True)
    assert result.returncode == 0 and result.stdout.strip() == str(dev / 'sda'), result.stderr
    (slaves / 'sdb').symlink_to(dev / 'sdb')
    result = subprocess.run(['bash', '-c', shell, 'test', str(dev / 'dm-0')], text=True, capture_output=True)
    assert result.returncode != 0, 'multiple parents must fail'
    (slaves / 'sdb').unlink()
    (slaves / 'sda1').unlink()
    result = subprocess.run(['bash', '-c', shell, 'test', str(dev / 'dm-0')], text=True, capture_output=True)
    assert result.returncode != 0, 'missing parent must fail'
    (slaves / 'dm-0').symlink_to(dev / 'dm-0')
    result = subprocess.run(['bash', '-c', shell, 'test', str(dev / 'dm-0')], text=True, capture_output=True)
    assert result.returncode != 0, 'cycle must fail'
print('Ventoy parent resolution passed: single, multiple, missing, cycle')
