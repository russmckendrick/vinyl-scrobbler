import json
import os
import sys
from setuptools import setup

def get_version():
    with open('about_config.json', 'r') as f:
        about_config = json.load(f)
    return about_config.get('version', '0.0.1')  # Default to '0.0.1' if version is not found

VERSION = get_version()

APP = ['vinyl_scrobbler.py']
DATA_FILES = ['about_config.json']

OPTIONS = {
    'argv_emulation': False,
    'iconfile': 'icon.icns',
    'plist': {
        'LSUIElement': True,
        'LSBackgroundOnly': True,
        'CFBundleName': 'Vinyl Scrobbler',
        'CFBundleDisplayName': 'Vinyl Scrobbler',
        'CFBundleIdentifier': 'com.vinylscrobbler.app',
        'CFBundleVersion': VERSION,
        'CFBundleShortVersionString': VERSION,
        'NSHighResolutionCapable': True,
    },
    'packages': [
        'rumps',
        'objc',
        'Foundation',
        'AppKit',
        'pylast',
        'discogs_client',
        'requests',
        'urllib3',
        'certifi',
        'charset_normalizer',
        'idna',
        'dateutil',
        'six',
        'oauthlib',
        'httpx',
        'httpcore',
        'anyio',
        'sniffio',
        'h11',
    ],
    'includes': [
        'pkg_resources',
        'packaging',
        'packaging.version',
        'packaging.specifiers',
        'packaging.requirements',
        'decimal',
        'numbers',
        'logging',
        'threading',
        'json',
        'os',
        'sys',
        'time',
        'datetime',
        'getpass',
    ],
    'resources': ['config.json'] if os.path.exists('config.json') else [],
    'excludes': [
        'tkinter',
        'test',
        'distutils',
        'setuptools',
        'pip',
        '_pytest',
        'unittest',
    ],
    'strip': False,
}

setup(
    name='Vinyl Scrobbler',
    version=VERSION,
    app=APP,
    data_files=DATA_FILES,
    options={'py2app': OPTIONS},
    setup_requires=['py2app'],
    install_requires=[
        'rumps==0.4.0',
        'pyobjc==10.3.1',
        'pylast==5.1.0',
        'discogs-client==2.3.0',
        'requests==2.31.0',
        'python-dateutil==2.8.2',
        'urllib3>=1.21.1',
        'certifi>=2017.4.17',
        'charset-normalizer>=2.0',
        'idna>=2.5',
        'six>=1.5',
    ],
    package_data={
        '': ['about_config.json'],
    },
    python_requires='>=3.9',
)