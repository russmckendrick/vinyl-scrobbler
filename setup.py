"""
Setup script for building Vinyl Scrobbler
"""
from setuptools import setup

APP = ['vinyl_scrobbler.py']
DATA_FILES = [] 

OPTIONS = dict(
    argv_emulation=False,
    iconfile='icon.icns',
    plist=dict(
        LSUIElement=True,
        LSBackgroundOnly=True,
        CFBundleName='Vinyl Scrobbler',
        CFBundleDisplayName='Vinyl Scrobbler',
        CFBundleIdentifier='com.vinylscrobbler.app',
        CFBundleVersion='1.0.0',
        CFBundleShortVersionString='1.0.0',
        NSHighResolutionCapable=True,
    ),
    includes=[
        'rumps',
        'pylast',
        'discogs_client',
        'requests',
        'urllib3',
        'certifi',
        'chardet',
        'idna',
        'dateutil',
        'six',
    ],
    packages=[
        'dateutil',
        'rumps',
        'pylast',
        'discogs_client',
        'requests',
    ],
)

setup(
    name='Vinyl Scrobbler',
    app=APP,
    data_files=DATA_FILES,
    options={'py2app': OPTIONS},
    setup_requires=['py2app'],
    install_requires=[
        'rumps',
        'pylast',
        'discogs-client',
        'requests',
        'python-dateutil',
    ],
    python_requires='>=3.9',
)