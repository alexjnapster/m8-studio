#!/usr/bin/env python3
"""Wrap a verified candidate in a drag-to-Applications DMG; never install or launch."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import subprocess
import tempfile
from ds_store import DSStore
from mac_alias import Alias

HERE = Path(__file__).resolve().parent

def run(*args):
    return subprocess.check_output([str(a) for a in args])

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def require(ok, message):
    if not ok:
        raise RuntimeError(message)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--candidate', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    candidate, output = args.candidate.resolve(), args.output.resolve()
    require(not output.exists(), 'Refusing to replace an existing image')
    manifest = json.loads((candidate/'manifest.json').read_text())
    archive = candidate/'M8-Studio-arm64.zip'
    require(digest(archive) == manifest['files'][archive.name], 'Candidate checksum mismatch')
    require(manifest['bundleIdentifier'] == 'local.M8Studio', 'Unexpected candidate identity')
    require(output.suffix == '.dmg' and output.parent.exists(), 'Output must be a DMG in an existing directory')
    volume = 'M8 Studio Install'
    with tempfile.TemporaryDirectory(prefix='M8DMG-') as temp:
        temp = Path(temp)
        stage = temp/'contents'
        stage.mkdir()
        run('ditto', '-x', '-k', archive, stage)
        app = stage/'M8 Studio.app'
        run('codesign', '--verify', '--deep', '--strict', app)
        require(digest(app/'Contents/MacOS/M8Studio') == manifest['executableSHA256'], 'App hash mismatch')
        info = plistlib.loads((app/'Contents/Info.plist').read_bytes())
        require(info['CFBundleIdentifier'] == 'local.M8Studio', 'Wrong app identity')
        os.symlink('/Applications', stage/'Applications')
        (stage/'Інструкція — Read me.html').write_bytes((HERE/'DMG/Install.html').read_bytes())
        (stage/'.background').mkdir()
        run('xcrun', 'swift', HERE/'DMG/DrawBackground.swift', stage/'.background/install.png')
        writable = temp/'layout.dmg'
        run('hdiutil', 'create', '-quiet', '-srcfolder', stage, '-volname', volume,
            '-fs', 'HFS+', '-format', 'UDRW', writable)
        mounted = plistlib.loads(run('hdiutil', 'attach', '-plist', '-nobrowse', '-noautoopen', writable))
        entity = next(e for e in mounted['system-entities'] if 'mount-point' in e)
        mount, device = Path(entity['mount-point']), entity['dev-entry']
        try:
            alias = Alias.for_file(str(mount/'.background/install.png')).to_bytes()
            with DSStore.open(str(mount/'.DS_Store'), 'w+') as store:
                store['.']['vSrn'] = ('long', 1)
                store['.']['bwsp'] = {'WindowBounds':'{{160, 100}, {720, 620}}',
                    'ShowToolbar':False, 'ShowSidebar':False, 'ContainerShowSidebar':False,
                    'ShowStatusBar':False, 'ShowPathbar':False, 'ShowTabView':False}
                store['.']['icvp'] = {'viewOptionsVersion':1, 'backgroundType':2,
                    'backgroundImageAlias':alias, 'backgroundColorRed':1.0,
                    'backgroundColorGreen':1.0, 'backgroundColorBlue':1.0, 'iconSize':96.0, 'textSize':14.0,
                    'labelOnBottom':True, 'showItemInfo':False, 'showIconPreview':False,
                    'arrangeBy':'none', 'gridSpacing':100.0,
                    'gridOffsetX':0.0, 'gridOffsetY':0.0, 'scrollPositionX':0.0, 'scrollPositionY':0.0}
                store['.']['icvl'] = ('type', b'icnv')
                store['M8 Studio.app']['Iloc'] = (180, 230)
                store['Applications']['Iloc'] = (540, 230)
                store['Інструкція — Read me.html']['Iloc'] = (360, 350)
            run('codesign', '--verify', '--deep', '--strict', mount/'M8 Studio.app')
        finally:
            run('hdiutil', 'detach', '-quiet', device)
        run('hdiutil', 'convert', '-quiet', writable, '-format', 'UDZO', '-imagekey', 'zlib-level=9', '-o', output)
    run('hdiutil', 'verify', output)
    check = plistlib.loads(run('hdiutil', 'attach', '-plist', '-readonly', '-nobrowse', '-noautoopen', output))
    entity = next(e for e in check['system-entities'] if 'mount-point' in e)
    mount = Path(entity['mount-point'])
    try:
        require(os.readlink(mount/'Applications') == '/Applications', 'Wrong Applications shortcut')
        run('codesign', '--verify', '--deep', '--strict', mount/'M8 Studio.app')
        require(digest(mount/'M8 Studio.app/Contents/MacOS/M8Studio') == manifest['executableSHA256'], 'Mounted executable differs')
        # Rehearse copying into a disposable folder, never the real Applications.
        with tempfile.TemporaryDirectory(prefix='M8DMG-copy-') as copy:
            copied = Path(copy)/'M8 Studio.app'
            run('ditto', '--noextattr', '--norsrc', mount/'M8 Studio.app', copied)
            run('codesign', '--verify', '--deep', '--strict', copied)
            require(digest(copied/'Contents/MacOS/M8Studio') == manifest['executableSHA256'], 'Copied executable differs')
    finally:
        run('hdiutil', 'detach', '-quiet', entity['dev-entry'])
    checksum = digest(output)
    output.with_suffix('.dmg.sha256').write_text(checksum+'  '+output.name+'\n')
    output.with_suffix('.dmg.json').write_text(json.dumps({
        'appVersion':info['CFBundleShortVersionString'], 'build':info['CFBundleVersion'],
        'candidateCommit':manifest['sourceCommit'], 'candidateArchiveSHA256':digest(archive),
        'executableSHA256':manifest['executableSHA256'], 'dmgSHA256':checksum,
        'signing':'ad-hoc app; no Apple notarization', 'installed':False,
        'checks':['candidate hash', 'image integrity', 'read-only mount',
                  'Applications shortcut', 'mounted nested app signature',
                  'disposable copy signature and executable parity'],
    },indent=2)+'\n')
    print('Verified DMG: '+str(output))
    print('SHA256: '+checksum)

if __name__ == '__main__':
    main()
