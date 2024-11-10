import rumps
import pylast
import discogs_client
import time
import json
import logging
import os
import sys
from datetime import datetime, timedelta
import threading
from typing import List, Dict, Optional
from dataclasses import dataclass

@dataclass
class Track:
    position: str
    title: str
    duration: str
    duration_seconds: int
    artist: str = ""
    album: str = ""

class VinylScrobbler(rumps.App):
    def __init__(self):
        # Initialize logger first
        self.logger = self._setup_logging()
        
        # Initialize class variables
        self.current_album = None
        self.tracks = []
        self.current_track_index = 0
        self.is_playing = False
        self.scrobble_timer = None
        self.lastfm_config = None
        self.discogs_config = None
        self.timer_thread = None
        self.stop_timer = False
        self.show_notifications = True  # Default to True
        
        # Load about configuration
        self.about_config = self.load_about_config()
        
        # Initialize the app with the icon
        super(VinylScrobbler, self).__init__("♫   ", quit_button=None)
        
        try:
            # Load configuration
            self.logger.info("Loading configuration...")
            self.load_config()
            
            # Initialize services
            self.logger.info("Initializing services...")
            self.initialize_services()
            
            # Setup menu items
            self.logger.info("Setting up menu...")
            self.setup_menu()
            
        except Exception as e:
            self.logger.error(f"Initialization error: {str(e)}")
            rumps.alert("Initialization Error", str(e))
            sys.exit(1)

    def clean_artist_name(self, artist_name: str) -> str:
        """Clean artist name from Discogs format to match LastFM format."""
        import re
        cleaned_name = re.sub(r'\s*\(\d+\)\s*$', '', artist_name)
        return cleaned_name.strip()

    def update_title_with_timer(self, duration_seconds: int):
        """Update the status bar title with remaining time"""
        start_time = time.time()
        self.stop_timer = False
        
        def timer_loop():
            while not self.stop_timer:
                try:
                    elapsed_seconds = int(time.time() - start_time)
                    remaining_seconds = max(0, duration_seconds - elapsed_seconds)
                    
                    if remaining_seconds == 0:
                        break
                    
                    # Format remaining time as MM:SS
                    minutes = remaining_seconds // 60
                    seconds = remaining_seconds % 60
                    time_str = f"{minutes:02d}:{seconds:02d}"
                    
                    current_track = self.tracks[self.current_track_index]
                    self.title = f"▷  {current_track.title}"
                    
                    time.sleep(5)
                except Exception as e:
                    self.logger.error(f"Error in timer loop: {str(e)}")
                    break
        
        # Start timer in a new thread
        self.timer_thread = threading.Thread(target=timer_loop)
        self.timer_thread.daemon = True
        self.timer_thread.start()
            
    def _setup_logging(self) -> logging.Logger:
        """Setup logging configuration"""
        try:
            # Create logs directory in user's home if it doesn't exist
            log_dir = os.path.expanduser('~/.vinyl-scrobbler')
            if not os.path.exists(log_dir):
                os.makedirs(log_dir)
            
            log_file = os.path.join(log_dir, 'vinyl_scrobbler.log')
            
            # Set up logging configuration
            logging.basicConfig(
                level=logging.INFO,
                format='%(asctime)s - %(levelname)s - %(message)s',
                handlers=[
                    logging.FileHandler(log_file),
                    logging.StreamHandler()
                ]
            )
            
            return logging.getLogger(__name__)
            
        except Exception as e:
            print(f"Failed to setup logging: {str(e)}")
            sys.exit(1)

    def load_about_config(self):
        try:
            # Get the directory of the current executable
            if getattr(sys, 'frozen', False):
                # If the application is run as a bundle, use the sys.executable path
                application_path = os.path.dirname(sys.executable)
                # Move up to the Contents directory and then into Resources
                config_path = os.path.join(os.path.dirname(application_path), 'Resources', 'about_config.json')
            else:
                # If run from a Python interpreter, use the script's directory
                application_path = os.path.dirname(os.path.abspath(__file__))
                config_path = os.path.join(application_path, 'about_config.json')
            
            self.logger.info(f"Attempting to load about_config.json from: {config_path}")
            
            # Try UTF-8 encoding first
            try:
                with open(config_path, 'r', encoding='utf-8') as f:
                    config = json.load(f)
                self.logger.info("Successfully loaded about_config.json with UTF-8 encoding")
                return config
            except UnicodeDecodeError:
                # If UTF-8 fails, try with ISO-8859-1 encoding
                with open(config_path, 'r', encoding='iso-8859-1') as f:
                    config = json.load(f)
                self.logger.info("Successfully loaded about_config.json with ISO-8859-1 encoding")
                return config
        except json.JSONDecodeError as json_err:
            self.logger.error(f"JSON decoding error: {str(json_err)}")
            # Log the content of the file for debugging
            with open(config_path, 'rb') as f:
                content = f.read()
            self.logger.error(f"File content (hex): {content.hex()}")
            return {}
        except Exception as e:
            self.logger.error(f"Failed to load about config: {str(e)}")
            return {}
    def load_config(self):
        """Load configuration from JSON file in user's home directory"""
        config_file = os.path.expanduser('~/.vinyl-scrobbler-config.json')
        try:
            # Check if config file exists
            if not os.path.exists(config_file):
                # Create default config file
                default_config = {
                    'lastfm_api_key': '',
                    'lastfm_api_secret': '',
                    'lastfm_username': '',
                    'lastfm_password_hash': '',
                    'discogs_token': '',
                    'discogs_username': '',
                    'show_notifications': True  # Add default show_notifications setting
                }
                
                # Write default config
                with open(config_file, 'w') as f:
                    json.dump(default_config, f, indent=4)
                    
                # Show first-run message
                self.logger.info("Creating default configuration file")
                rumps.alert(
                    "Welcome to Vinyl Scrobbler!",
                    f"A configuration file has been created at: {config_file}\n\n"
                    "Please edit this file to add your Last.FM and Discogs credentials."
                )
                sys.exit(0)
                
            # Load existing config
            with open(config_file, 'r') as f:
                config = json.load(f)
                
            # Validate required fields
            required_fields = [
                'lastfm_api_key', 'lastfm_api_secret',
                'lastfm_username', 'lastfm_password_hash',
                'discogs_token', 'discogs_username'
            ]
            
            missing_fields = [field for field in required_fields if not config.get(field)]
            
            if missing_fields:
                self.logger.error(f"Missing configuration fields: {missing_fields}")
                rumps.alert(
                    "Configuration Error",
                    f"Missing required configuration fields: {', '.join(missing_fields)}\n\n"
                    f"Please edit the configuration file at: {config_file}"
                )
                sys.exit(1)
                
            self.lastfm_config = {
                'api_key': config['lastfm_api_key'],
                'api_secret': config['lastfm_api_secret'],
                'username': config['lastfm_username'],
                'password_hash': config['lastfm_password_hash']
            }
            self.discogs_config = {
                'token': config['discogs_token'],
                'user_name': config['discogs_username']
            }
            
            # Load show_notifications setting
            self.show_notifications = config.get('show_notifications', True)
            
            self.logger.info("Successfully loaded configuration")
            
        except Exception as e:
            self.logger.error(f"Error loading configuration: {str(e)}")
            raise Exception(f"Failed to load configuration: {str(e)}")

    def get_track_duration_from_lastfm(self, artist: str, title: str) -> tuple[str, int]:
        """
        Fetch track duration from Last.fm.
        Returns a tuple of (duration_string, duration_seconds)
        """
        try:
            self.logger.info(f"Fetching duration from Last.fm for: {artist} - {title}")
            track = self.network.get_track(artist, title)
            
            # Get track duration using the proper Track method
            duration_seconds = track.get_duration()
            if duration_seconds and duration_seconds > 0:
                duration_seconds = duration_seconds // 1000  # Convert from ms to seconds
                minutes = duration_seconds // 60
                seconds = duration_seconds % 60
                duration_string = f"{minutes}:{seconds:02d}"
                
                self.logger.info(f"Found duration on Last.fm: {duration_string}")
                return duration_string, duration_seconds
                    
            raise ValueError("No valid duration found on Last.fm")
            
        except Exception as e:
            self.logger.warning(f"Failed to get duration from Last.fm: {str(e)}")
            raise

    def get_track_duration(self, track, artist_name: str) -> tuple[str, int]:
        """
        Get track duration, trying Discogs first then falling back to Last.fm
        Returns a tuple of (duration_string, duration_seconds)
        """
        # First try Discogs duration
        if track.duration and track.duration.strip() != '':
            duration = track.duration
            duration_parts = duration.split(':')
            duration_seconds = sum(int(x) * 60**i 
                                for i, x in enumerate(reversed(duration_parts)))
            return duration, duration_seconds
            
        # If no Discogs duration, try Last.fm
        try:
            self.logger.info(f"No Discogs duration for {track.title}, trying Last.fm...")
            return self.get_track_duration_from_lastfm(artist_name, track.title)
        except Exception as e:
            self.logger.warning(f"Could not get duration from Last.fm: {str(e)}")
            # Fall back to default duration
            self.logger.warning(f"Using default duration for track {track.position}")
            return '3:30', 210

    def setup_logging(self):
        """Setup logging configuration"""
        try:
            # Create logs directory in user's home if it doesn't exist
            log_dir = os.path.expanduser('~/.vinyl-scrobbler')
            if not os.path.exists(log_dir):
                os.makedirs(log_dir)
            
            log_file = os.path.join(log_dir, 'vinyl_scrobbler.log')
            
            logging.basicConfig(
                level=logging.INFO,
                format='%(asctime)s - %(levelname)s - %(message)s',
                handlers=[
                    logging.FileHandler(log_file),
                    logging.StreamHandler()
                ]
            )
            self.logger = logging.getLogger(__name__)
            self.logger.info("Logging initialized")
        except Exception as e:
            print(f"Failed to setup logging: {str(e)}")
            sys.exit(1)

    def initialize_services(self):
        """Initialize Last.FM and Discogs connections"""
        try:
            # Initialize Last.FM
            self.network = pylast.LastFMNetwork(
                api_key=self.lastfm_config['api_key'],
                api_secret=self.lastfm_config['api_secret'],
                username=self.lastfm_config['username'],
                password_hash=self.lastfm_config['password_hash']
            )
            
            # Initialize Discogs
            self.discogs = discogs_client.Client(
                'VinylScrobbler/1.0',
                user_token=self.discogs_config['token']
            )
            
            self.logger.info("Successfully initialized Last.FM and Discogs services")
        except Exception as e:
            self.logger.error(f"Failed to initialize services: {str(e)}")
            raise

    @rumps.clicked('Search Album')
    def search_album(self, _):
        """Load album from Discogs ID"""
        try:
            # Create a window for Discogs ID input
            response = rumps.Window(
                message='Enter Discogs Release ID:',
                title='Load Album',
                default_text='',
                ok='Load',
                cancel='Cancel'
            ).run()
            
            if response.clicked:
                try:
                    # Handle both full URLs and just IDs
                    text = response.text.strip()
                    release_id = None
                    
                    # Check if it's a URL
                    if 'discogs.com' in text:
                        # Extract ID from URL
                        parts = text.split('/')
                        release_id = parts[-1] if parts else None
                        # Clean up any query parameters
                        release_id = release_id.split('-')[0] if release_id else None
                    else:
                        # Assume it's just an ID
                        release_id = text
                    
                    # Clean up the ID
                    release_id = ''.join(filter(str.isdigit, release_id)) if release_id else None
                    
                    if release_id:
                        self.logger.info(f"Loading Discogs release ID: {release_id}")
                        release = self.discogs.release(release_id)
                        self.load_album(release)
                    else:
                        rumps.alert(
                            "Invalid Input", 
                            "Please enter either a Discogs Release ID (e.g., 8844291) or "
                            "a Discogs URL (e.g., https://www.discogs.com/release/8844291-...)"
                        )
                except Exception as e:
                    self.logger.error(f"Error loading release: {str(e)}")
                    rumps.alert("Error", f"Failed to load release: {str(e)}")
        except Exception as e:
            self.logger.error(f"Error in search_album: {str(e)}")
            rumps.alert("Error", f"Failed to search album: {str(e)}")

    def setup_menu(self):
        """Setup menu items"""
        try:
            self.logger.info("Setting up default menu...")
            
            # Create menu items
            self.search_button = rumps.MenuItem("Search Album", callback=self.search_album)
            self.play_pause_button = rumps.MenuItem("Start Playing", callback=self.toggle_playback)
            self.next_track_button = rumps.MenuItem("Next Track", callback=self.next_track)
            self.tracks_menu = rumps.MenuItem("Tracks")
            self.about_button = rumps.MenuItem("About", callback=self.show_about)
            
            # Set the menu
            self.menu = [
                self.search_button,
                self.play_pause_button,
                self.next_track_button,
                None,  # Separator
                self.tracks_menu,
                None,  # Separator
                self.about_button,
                None,  # Separator
                rumps.MenuItem("Quit", callback=self.clean_quit)  # Custom quit button
            ]
            
            self.logger.info("Default menu setup complete")
            
        except Exception as e:
            self.logger.error(f"Error setting up menu: {str(e)}")
            raise Exception(f"Failed to setup menu: {str(e)}")

    def load_album(self, release):
        """Load album tracks from Discogs release"""
        try:
            self.logger.info("Starting to load album...")
            self.current_album = release
            self.tracks = []
            
            # Stop any current playback
            if self.is_playing:
                self.stop_playback()
                self.play_pause_button.title = "Start Playing"
            
            try:
                self.logger.info("Resetting menu...")
                
                # Create fresh instances of all menu items
                search_button = rumps.MenuItem("Search Album", callback=self.search_album)
                play_pause_button = rumps.MenuItem("Start Playing", callback=self.toggle_playback)
                next_track_button = rumps.MenuItem("Next Track", callback=self.next_track)
                tracks_menu = rumps.MenuItem("Tracks")
                about_button = rumps.MenuItem("About", callback=self.show_about)
                
                # Clear the menu and add fresh items
                self.menu.clear()
                self.menu = [
                    search_button,
                    play_pause_button,
                    next_track_button,
                    None,  # Separator
                    tracks_menu,
                    None,  # Separator
                    about_button,
                    None,  # Separator
                    rumps.MenuItem("Quit", callback=self.clean_quit)
                ]
                
                # Update our references
                self.search_button = search_button
                self.play_pause_button = play_pause_button
                self.next_track_button = next_track_button
                self.tracks_menu = tracks_menu
                self.about_button = about_button
                
                # Add album info header
                raw_artist_name = release.artists[0].name if release.artists else "Various Artists"
                artist_name = self.clean_artist_name(raw_artist_name)
                album_title = release.title
                
                # Create header menu item
                header = rumps.MenuItem(f"{artist_name} - {album_title}")
                header.set_callback(None)  # Make it non-clickable
                self.tracks_menu.add(header)
                
                # Add separator
                self.tracks_menu.add(rumps.MenuItem(None))
                
                for track in release.tracklist:
                    try:
                        # Get duration using the new method
                        duration, duration_seconds = self.get_track_duration(track, artist_name)
                        
                        track_obj = Track(
                            position=track.position,
                            title=track.title,
                            duration=duration,
                            duration_seconds=duration_seconds,
                            artist=artist_name,
                            album=album_title
                        )
                        self.tracks.append(track_obj)
                        
                        # Add track to menu
                        track_menu_item = rumps.MenuItem(
                            f"{track.position}. {track_obj.title} ({track_obj.duration})",
                            callback=self.track_selected
                        )
                        self.tracks_menu.add(track_menu_item)
                        
                    except Exception as e:
                        self.logger.error(f"Error processing track {track.position}: {str(e)}")
                        continue
                
                self.logger.info("Menu updated successfully")
                
            except Exception as e:
                self.logger.error(f"Error updating menu: {str(e)}")
                raise Exception(f"Failed to update menu: {str(e)}")
            
            if not self.tracks:
                raise Exception("No valid tracks found in the release")
                
            self.current_track_index = 0
            self.title = f"♫   {self.tracks[0].title}"
            
            # Show success message with album details
            if self.show_notifications:
                rumps.alert(
                    "Album Loaded", 
                    f"Successfully loaded: {release.title}\n"
                    f"Artist: {artist_name}\n"
                    f"Tracks: {len(self.tracks)}"
                )
            
            self.logger.info(f"Loaded album: {release.title}")
        
        except Exception as e:
            self.logger.error(f"Error loading album: {str(e)}")
            if self.show_notifications:
                rumps.alert("Error", f"Failed to load album: {str(e)}")
            # Reset menu to default state
            self.setup_menu()
            
    def track_selected(self, sender):
        """Handle track selection from menu"""
        try:
            # Extract track position from menu item title
            position = sender.title.split('.')[0].strip()
            
            # Find the track index by matching position
            track_index = None
            for i, track in enumerate(self.tracks):
                if track.position == position:
                    track_index = i
                    break
            
            if track_index is not None:
                # Stop current playback if playing
                if self.is_playing:
                    self.stop_playback()
                    self.play_pause_button.title = "Start Playing"
                
                # Set new track
                self.current_track_index = track_index
                
                # Update the title with current track (without timer since not playing)
                self.title = f"♫   {self.tracks[self.current_track_index].title}"
                
                self.logger.info(f"Selected track: {position} - {self.tracks[track_index].title}")
            else:
                raise Exception(f"Could not find track with position: {position}")
                
        except Exception as e:
            self.logger.error(f"Error selecting track: {str(e)}")
            if self.show_notifications:
                rumps.alert("Error", f"Failed to select track: {str(e)}")

    @rumps.clicked('Start Playing')
    def toggle_playback(self, sender):
        """Toggle vinyl playback"""
        try:
            if not self.tracks:
                if self.show_notifications:
                    rumps.alert("Error", "Please search and select an album first")
                return

            if self.is_playing:
                sender.title = "Start Playing"
                self.stop_playback()
            else:
                sender.title = "Stop Playing"
                self.start_playback()
        except Exception as e:
            self.logger.error(f"Error toggling playback: {str(e)}")
            if self.show_notifications:
                rumps.alert("Error", f"Failed to toggle playback: {str(e)}")

    def start_playback(self):
        """Start playing current track"""
        try:
            if not self.tracks:
                return
                
            self.is_playing = True
            current_track = self.tracks[self.current_track_index]

            # Show notification for track change if enabled
            if self.show_notifications:
                rumps.notification(
                    title="Now Playing",
                    subtitle=current_track.artist,
                    message=current_track.title,
                    sound=False
                )
            
            # Update now playing
            self.update_now_playing(current_track)
            
            # Schedule scrobble
            self.scrobble_timer = threading.Timer(
                current_track.duration_seconds,
                self.handle_track_end
            )
            self.scrobble_timer.start()
            
            # Start the timer display
            self.update_title_with_timer(current_track.duration_seconds)
            
        except Exception as e:
            self.logger.error(f"Error starting playback: {str(e)}")
            self.is_playing = False
            raise

    def stop_playback(self):
        """Stop current playback"""
        try:
            self.is_playing = False
            if self.scrobble_timer:
                self.scrobble_timer.cancel()
            
            # Stop the timer
            self.stop_timer = True
            if self.timer_thread and self.timer_thread.is_alive():
                self.timer_thread.join(timeout=1)
            
            self.title = "♫"
        except Exception as e:
            self.logger.error(f"Error stopping playback: {str(e)}")
            raise

    @rumps.clicked('Next Track')
    def next_track(self, _):
        """Skip to next track"""
        try:
            if not self.tracks:
                return
                
            self.handle_track_end()
        except Exception as e:
            self.logger.error(f"Error skipping track: {str(e)}")
            if self.show_notifications:
                rumps.alert("Error", f"Failed to skip track: {str(e)}")

    def handle_track_end(self):
        """Handle end of track, scrobble, and move to next"""
        try:
            if not self.is_playing:
                return
                
            # Scrobble current track
            current_track = self.tracks[self.current_track_index]
            self.scrobble_track(current_track)
            
            # Move to next track
            self.current_track_index += 1
            if self.current_track_index >= len(self.tracks):
                self.current_track_index = 0
                self.stop_playback()
                self.play_pause_button.title = "Start Playing"
                if self.show_notifications:
                    rumps.alert("Playback finished", "End of album reached")
            else:
                self.start_playback()
        except Exception as e:
            self.logger.error(f"Error handling track end: {str(e)}")
            self.stop_playback()

    def update_now_playing(self, track: Track):
        """Update now playing status on Last.FM"""
        try:
            self.network.update_now_playing(
                artist=track.artist,
                title=track.title,
                album=track.album
            )
            self.logger.info(f"Updated now playing: {track.artist} - {track.title}")
        except Exception as e:
            self.logger.error(f"Failed to update now playing: {str(e)}")

    def scrobble_track(self, track: Track):
        """Scrobble track to Last.FM"""
        try:
            timestamp = int(time.time())
            self.network.scrobble(
                artist=track.artist,
                title=track.title,
                timestamp=timestamp,
                album=track.album,
                duration=track.duration_seconds
            )
            self.logger.info(f"Scrobbled: {track.artist} - {track.title}")
        except Exception as e:
            self.logger.error(f"Failed to scrobble track: {str(e)}")

    def show_about(self, _):
        """Display information about the application"""
        about_text = (
            f"{self.about_config.get('app_name', 'Vinyl Scrobbler')}\n\n"
            f"Version: {self.about_config.get('version', '1.0')}\n"
            f"{self.about_config.get('description', '')}\n\n"
            f"Created by: {self.about_config.get('author', '')}\n"
            f"GitHub: {self.about_config.get('github_url', '')}\n\n"
            f"{self.about_config.get('copyright', '')}"
        )
        if self.show_notifications:
            rumps.alert(title=f"About {self.about_config.get('app_name', 'Vinyl Scrobbler')}", message=about_text)

    def clean_quit(self, _):
        """Clean up and quit the application"""
        try:
            self.logger.info("Starting clean quit process...")
            
            # Stop any current playback
            if self.is_playing:
                self.stop_playback()
            
            # Cancel any pending timers
            if self.scrobble_timer:
                self.scrobble_timer.cancel()
            
            # Ensure timer thread is stopped
            self.stop_timer = True
            if self.timer_thread and self.timer_thread.is_alive():
                self.timer_thread.join(timeout=1)
            
            # Log the quit
            self.logger.info("Application shutting down cleanly")
            
            # Quit the application
            rumps.quit_application()
            
        except Exception as e:
            self.logger.error(f"Error during cleanup: {str(e)}")
            # Force quit even if cleanup fails
            rumps.quit_application()

def main():
    """Run the application"""
    try:
        VinylScrobbler().run()
    except Exception as e:
        print(f"Application error: {str(e)}")
        raise

if __name__ == "__main__":
    main()
