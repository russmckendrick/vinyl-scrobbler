# Vinyl Scrobbler

> [!CAUTION]
> This is a personal project, its probably not for you and provided as is. Run at your own risk.

A simple macOS application to scrobble vinyl records to Last.fm.

## About

Vinyl Scrobbler is a menu bar application that allows you to scrobble your vinyl records to Last.fm using Discogs as the source for track information. Simply search for your album using a Discogs release ID or URL, start playing, and let the app handle the scrobbling.

See https://www.instagram.com/reel/DCzAQBuSGUt/?igsh=eTJrY2xjd2F2OWpw for why I created it.

## Features

- Menu bar application for macOS
- Search albums by Discogs release ID or URL
- Automatic track duration fetching from both Discogs and Last.fm
- Real-time "Now Playing" status
- Track-by-track scrobbling
- Visual countdown timer for each track
- Support for multi-artist releases
- Automatic handling of Discogs artist name variations (e.g., disambiguation numbers)

## Requirements

- macOS
- Python 3.11 (installed via Homebrew)
- Last.fm account
- Discogs account
- create-dmg (for building DMG)

## Installation

### From DMG

1. Download the latest release from the [releases page](https://github.com/russmckendrick/vinyl-scrobbler/releases)
2. Mount the DMG and drag Vinyl Scrobbler to your Applications folder
3. Configure your Last.fm and Discogs credentials a per the Configuration section below

### Configuration

On first run, the app will create a configuration file at `~/.vinyl-scrobbler-config.json`. You'll need to edit this file to add your credentials:

```json
{
    "lastfm_api_key": "",
    "lastfm_api_secret": "",
    "lastfm_username": "",
    "lastfm_password_hash": "",
    "discogs_token": "",
    "discogs_username": ""
}
```

#### Getting Your Credentials

1. **Last.fm API Key and Secret**:
   - Create an API account at [Last.fm API](https://www.last.fm/api/account/create)
   - Copy the API Key and Shared Secret

2. **Last.fm Password Hash**:
   - Run the included script:
     ```bash
     python generate_lastfm_password_hash.py
     ```
   - Enter your Last.fm password when prompted
   - Copy the generated hash

3. **Discogs Token**:
   - Go to your [Discogs Developer Settings](https://www.discogs.com/settings/developers)
   - Generate a new token

## Usage

1. Click the "♫" menu bar icon
2. Select "Search Album"
3. Enter a Discogs release ID or URL
4. Click "Start Playing" when you start the record
5. Use "Next Track" to manually advance tracks if needed

## Logs

Logs are stored at `~/.vinyl-scrobbler/vinyl_scrobbler.log`

## Building from Source

1. Install Python 3.11 and `create-dmg` via Homebrew:
   ```bash
   brew install python@3.11
   brew install create-dmg
   ```

2. Clone the repository:
   ```bash
   git clone https://github.com/russmckendrick/vinyl-scrobbler.git
   cd vinyl-scrobbler
   ```

3. Run the build script:
   ```bash
   ./build.sh
   ```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License

## Author

Created by Russ McKendrick

GitHub: [https://github.com/russmckendrick/vinyl-scrobbler](https://github.com/russmckendrick/vinyl-scrobbler)