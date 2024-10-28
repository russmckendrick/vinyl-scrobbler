# Vinyl Scrobbler

A macOS menu bar application that lets you scrobble your vinyl records to Last.fm using Discogs metadata.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform](https://img.shields.io/badge/platform-macOS-lightgrey.svg)
![Python](https://img.shields.io/badge/python-%3E%3D3.9-green.svg)

## Features

- 🎵 Scrobble vinyl records to Last.fm
- 💿 Fetch album data from Discogs
- ⏱️ Real-time playback tracking
- 🔍 Search by Discogs Release ID or URL
- 📊 Automatic track duration detection
- 🎨 Clean macOS menu bar interface
- 📝 Detailed activity logging

## Prerequisites

- macOS
- Python 3.9 or higher
- Last.fm account
- Discogs account

## Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/vinyl-scrobbler.git
cd vinyl-scrobbler
```

2. Create a virtual environment and activate it:
```bash
python -m venv venv
source venv/bin/activate  # On macOS/Linux
```

3. Install the required packages:
```bash
pip install -r requirements.txt
```

4. Build the application:
```bash
./build-clean.sh  # Clean any previous builds
python setup.py py2app
```

5. Move the built application to your Applications folder:
```bash
cp -r dist/Vinyl\ Scrobbler.app /Applications/
```

## Configuration

1. Launch the application. On first run, it will create a configuration file at:
```
~/.vinyl-scrobbler-config.json
```

2. Edit the configuration file with your credentials:
```json
{
    "lastfm_api_key": "your_lastfm_api_key",
    "lastfm_api_secret": "your_lastfm_api_secret",
    "lastfm_username": "your_lastfm_username",
    "lastfm_password_hash": "your_lastfm_password_hash",
    "discogs_token": "your_discogs_token",
    "discogs_username": "your_discogs_username"
}
```

### Getting Your Credentials

#### Last.fm
1. Create an API account at: https://www.last.fm/api/account/create
2. Get your API key and secret
3. Generate your password hash using MD5 encryption of your Last.fm password

#### Discogs
1. Generate a personal access token at: https://www.discogs.com/settings/developers
2. Copy your token to the configuration file

## Usage

1. Launch the application
2. Click the menu bar icon (♫)
3. Select "Search Album"
4. Enter a Discogs Release ID or URL
5. Click "Start Playing" when ready
6. Use "Next Track" to manually advance tracks

The app will automatically:
- Update your "Now Playing" status on Last.fm
- Scrobble tracks after they finish playing
- Show remaining time for the current track
- Move to the next track when the current one finishes

## Logs

Application logs are stored at:
```
~/.vinyl-scrobbler/vinyl_scrobbler.log
```

## Building from Source

The application uses py2app for building. To create a fresh build:

1. Clean previous builds:
```bash
./build-clean.sh
```

2. Build the application:
```bash
python setup.py py2app
```

The built application will be available in the `dist` directory.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- [rumps](https://github.com/jaredks/rumps) for the macOS menu bar interface
- [pylast](https://github.com/pylast/pylast) for Last.fm integration
- [python-discogs-client](https://github.com/discogs/discogs_client) for Discogs integration

## Support

If you encounter any issues or have questions, please file an issue on the GitHub repository.