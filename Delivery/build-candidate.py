#!/usr/bin/env python3
"""Build an auditable candidate from committed files; never install or publish."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile
import zipfile

REPO = Path(__file__).resolve().parents[1]

def git(*args):
    return subprocess.check_output(['git', '-C', str(REPO), *args])

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def require(condition, message):
    if not condition:
        raise RuntimeError(message)

def source_inventory(archive, expected):
    with zipfile.ZipFile(archive) as source:
        require(source.testzip() is None, 'Source ZIP integrity failed')
        files = set()
        for entry in source.infolist():
            name = entry.filename
            require(name.startswith('M8Studio/'), 'Unexpected source prefix')
            relative = Path(name[len('M8Studio/'):])
            require(not relative.is_absolute() and '..' not in relative.parts, 'Unsafe source path')
            require((entry.external_attr >> 16) & 0o170000 != 0o120000, 'Source symlinks require review')
            if entry.is_dir():
                continue
            require(not set(relative.parts) & {'Research', 'Diagnostics', '.git'}, 'Private source directory')
            require(relative.suffix.lower() not in {'.edid', '.icc', '.icm', '.heic'}, 'Private/vendor resource requires review')
            require(not relative.name.startswith('.env'), 'Environment file requires review')
            files.add(relative.as_posix())
        require(files == expected, 'Source ZIP does not exactly match committed file inventory')

def audit_bundle(app, source_root):
    info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    require(info['CFBundleIdentifier'] == 'local.M8Studio', 'Wrong production bundle identity')
    require(info['NSAudioCaptureUsageDescription'], 'Missing capture explanation')
    extensions = list((app / 'Contents').glob('PlugIns/*.appex'))
    require(len(extensions) == 1 and extensions[0].name == 'M8StudioWidget.appex', 'Unexpected widget inventory')
    widget = extensions[0]
    widget_info = plistlib.loads((widget/'Contents/Info.plist').read_bytes())
    require(widget_info['CFBundleIdentifier'] == 'local.M8Studio.Widget', 'Wrong production widget identity')
    require(widget_info['NSExtension']['NSExtensionPointIdentifier'] == 'com.apple.widgetkit-extension', 'Wrong extension point')
    for key in ('CFBundleShortVersionString', 'CFBundleVersion', 'LSMinimumSystemVersion'):
        require(widget_info[key] == info[key], 'Widget/host version mismatch')
    widget_files = {p.relative_to(widget).as_posix() for p in widget.rglob('*') if p.is_file()}
    require(widget_files == {'Contents/Info.plist', 'Contents/MacOS/M8StudioWidget', 'Contents/_CodeSignature/CodeResources'}, 'Unexpected widget resources')
    entitlements = subprocess.check_output(['codesign', '-d', '--entitlements', ':-', str(widget)], stderr=subprocess.DEVNULL)
    require(plistlib.loads(entitlements) == {'com.apple.security.app-sandbox': True}, 'Unexpected widget entitlements')
    subprocess.run(['codesign', '--verify', '--strict', str(widget)], check=True)
    # Only committed public resources plus explicit build products may be packaged.
    allowed = {p.relative_to(source_root/'Resources').as_posix()
               for p in (source_root/'Resources').rglob('*') if p.is_file()}
    allowed |= {'m1ddc', 'ModeGuard', 'User Guide.html', 'm1ddc-LICENSE.txt',
                'CoreAudioTapKit-LICENSE', 'CoreAudioTapKit-PROVENANCE.md',
                'VirtualCanvas', 'VirtualCanvas-LICENSE', 'VirtualCanvas-PROVENANCE.md'}
    if (source_root/'AppIcon.icns').exists():
        allowed.add('AppIcon.icns')
    actual = {p.relative_to(app/'Contents/Resources').as_posix()
              for p in (app/'Contents/Resources').rglob('*') if p.is_file()}
    require(actual == allowed, 'Unexpected or missing app resources')
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
    return info

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, help='New output directory (must not exist)')
    args = parser.parse_args()
    require(not git('status', '--porcelain').strip(), 'Commit/review workspace changes before candidate build')
    commit = git('rev-parse', 'HEAD').decode().strip()
    destination = (args.output or REPO.parent/('M8Studio-candidate-'+commit[:12])).expanduser().resolve()
    require(not destination.exists(), 'Output already exists; choose a new directory')
    require(REPO not in destination.parents, 'Keep candidate output outside the source checkout')
    expected = set(git('ls-tree', '-rz', '--name-only', commit).decode().split('\0')) - {''}
    checks = [
        ['zsh', 'Tests/test-keyboard.sh'], ['zsh', 'Tests/test-carbon.sh'],
        ['python3', 'Tests/test-sound.py'], ['zsh', 'Tests/test-audio-buffers.sh'],
        ['zsh', 'Tests/test-sound-lifecycle.sh'], ['zsh', 'Tests/test-sound-model.sh'],
        ['zsh', 'Tests/test-studio-routes.sh'], ['zsh', 'Tests/test-mode-favorites.sh'],
        ['zsh', 'Tests/test-display-assistance.sh'], ['zsh', 'Tests/test-virtual-canvas.sh'],
        ['zsh', 'build-widget-preview.sh'],
    ]
    # Build/sign/extract outside the synced workspace. Nothing is launched.
    with tempfile.TemporaryDirectory(prefix='M8CleanCandidate-') as temporary:
        stage = Path(temporary)
        source_zip = stage/'M8-Studio-source.zip'
        subprocess.run(['git', '-C', str(REPO), 'archive', '--format=zip', '--prefix=M8Studio/',
                        '--output='+str(source_zip), commit], check=True)
        source_inventory(source_zip, expected)
        with zipfile.ZipFile(source_zip) as archive:
            archive.extractall(stage)
        source_root = stage/'M8Studio'
        scratch = stage/'scratch'; scratch.mkdir()
        environment = dict(os.environ, TMPDIR=str(scratch)+'/')
        with (stage/'checks.log').open('w') as log:
            for command in checks + [['zsh', 'build.sh']]:
                print('Checking ' + ' '.join(command), flush=True)
                log.write('\nRUN ' + ' '.join(command) + '\n'); log.flush()
                result = subprocess.run(command, cwd=source_root, env=environment, stdout=log, stderr=subprocess.STDOUT)
                if result.returncode:
                    log.flush()
                    print((stage/'checks.log').read_text()[-12000:], flush=True)
                    raise subprocess.CalledProcessError(result.returncode,command)
        app_zip = stage/'M8 Studio.zip'
        extracted = stage/'archive-check'
        subprocess.run(['ditto', '-x', '-k', str(app_zip), str(extracted)], check=True)
        app = extracted/'M8 Studio.app'
        info = audit_bundle(app, source_root)
        manifest = {
            'status': 'development-candidate-not-e2e-accepted', 'sourceCommit': commit,
            'sourceFileCount': len(expected), 'appVersion': info['CFBundleShortVersionString'],
            'buildNumber': info['CFBundleVersion'], 'minimumMacOS': info['LSMinimumSystemVersion'],
            'bundleIdentifier': info['CFBundleIdentifier'],
            'executableSHA256': sha(app/'Contents/MacOS/M8Studio'),
            'reproducibility': 'Committed source and build recipe; binary determinism not tested',
            'signing': 'ad-hoc; not notarized', 'installed': False, 'published': False,
            'widgetEmbedded': True, 'productionWidgetGalleryAccepted': False,
            'checks': [' '.join(c) for c in checks],
            'scope': 'Offline/synthetic checks and clean build. No physical monitor, HAL capture, permissions, gallery, update or calibration acceptance.',
            'files': {'M8-Studio-source.zip':sha(source_zip), 'M8-Studio-arm64.zip':sha(app_zip)},
        }
        destination.mkdir(parents=True, exist_ok=False)
        shutil.copyfile(source_zip, destination/'M8-Studio-source.zip')
        shutil.copyfile(app_zip, destination/'M8-Studio-arm64.zip')
        shutil.copyfile(stage/'checks.log', destination/'checks.log')
        (destination/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
        (destination/'SHA256SUMS').write_text(''.join(value+'  '+name+'\n' for name,value in manifest['files'].items()))
        for name, digest in manifest['files'].items():
            require(sha(destination/name) == digest, 'Copied archive checksum mismatch')
    print('Verified local development candidate: ' + str(destination))
    print('Not installed, published, notarized or accepted as completed v5.')

if __name__ == '__main__':
    main()
