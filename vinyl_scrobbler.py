import Foundation
import AppKit
import objc
from UserNotifications import UNUserNotificationCenter, UNMutableNotificationContent, UNNotificationRequest
import pylast
import discogs_client
import time
import json
import logging
import os
import sys
import requests
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

class PlayerWindow(AppKit.NSWindow):
    def initWithContentRect_styleMask_backing_defer_(self, rect, style, backing, defer):
        # Use objc.super() for proper Objective-C super calls
        self = objc.super(PlayerWindow, self).initWithContentRect_styleMask_backing_defer_(
            rect,
            style,
            backing,
            defer
        )
        if self is None:
            return None
            
        # Set window properties
        self.setTitle_("Vinyl Scrobbler")
        self.setBackgroundColor_(AppKit.NSColor.windowBackgroundColor())
        self.setMovableByWindowBackground_(True)
        self.setTitlebarAppearsTransparent_(True)
        
        # Create the main view
        self.contentView = AppKit.NSView.alloc().initWithFrame_(rect)
        self.setContentView_(self.contentView)
        
        # Create album artwork view
        artwork_size = 300
        artwork_frame = Foundation.NSMakeRect(
            (rect.size.width - artwork_size) / 2,
            rect.size.height - artwork_size - 60,
            artwork_size,
            artwork_size
        )
        self.artwork_view = AppKit.NSImageView.alloc().initWithFrame_(artwork_frame)
        self.artwork_view.setWantsLayer_(True)
        self.artwork_view.layer().setCornerRadius_(8.0)
        self.artwork_view.layer().setMasksToBounds_(True)
        self.contentView.addSubview_(self.artwork_view)
        
        # Create track info labels
        label_width = rect.size.width - 40
        self.track_label = AppKit.NSTextField.alloc().initWithFrame_(
            Foundation.NSMakeRect(20, artwork_frame.origin.y - 60, label_width, 24)
        )
        self.track_label.setBezeled_(False)
        self.track_label.setDrawsBackground_(False)
        self.track_label.setEditable_(False)
        self.track_label.setSelectable_(False)
        self.track_label.setAlignment_(AppKit.NSTextAlignmentCenter)
        self.track_label.setFont_(AppKit.NSFont.boldSystemFontOfSize_(16))
        self.contentView.addSubview_(self.track_label)
        
        self.artist_label = AppKit.NSTextField.alloc().initWithFrame_(
            Foundation.NSMakeRect(20, artwork_frame.origin.y - 90, label_width, 24)
        )
        self.artist_label.setBezeled_(False)
        self.artist_label.setDrawsBackground_(False)
        self.artist_label.setEditable_(False)
        self.artist_label.setSelectable_(False)
        self.artist_label.setAlignment_(AppKit.NSTextAlignmentCenter)
        self.artist_label.setTextColor_(AppKit.NSColor.secondaryLabelColor())
        self.contentView.addSubview_(self.artist_label)
        
        # Create progress bar
        progress_frame = Foundation.NSMakeRect(20, artwork_frame.origin.y - 130, label_width, 2)
        self.progress_bar = AppKit.NSProgressIndicator.alloc().initWithFrame_(progress_frame)
        self.progress_bar.setStyle_(AppKit.NSProgressIndicatorStyleBar)
        self.progress_bar.setIndeterminate_(False)
        self.progress_bar.setMinValue_(0)
        self.progress_bar.setMaxValue_(100)
        self.contentView.addSubview_(self.progress_bar)
        
        # Create time labels
        time_label_width = 50
        self.current_time = AppKit.NSTextField.alloc().initWithFrame_(
            Foundation.NSMakeRect(20, artwork_frame.origin.y - 150, time_label_width, 16)
        )
        self.current_time.setBezeled_(False)
        self.current_time.setDrawsBackground_(False)
        self.current_time.setEditable_(False)
        self.current_time.setSelectable_(False)
        self.current_time.setTextColor_(AppKit.NSColor.secondaryLabelColor())
        self.current_time.setFont_(AppKit.NSFont.systemFontOfSize_(12))
        self.contentView.addSubview_(self.current_time)
        
        self.total_time = AppKit.NSTextField.alloc().initWithFrame_(
            Foundation.NSMakeRect(rect.size.width - time_label_width - 20, 
                                artwork_frame.origin.y - 150, 
                                time_label_width, 16)
        )
        self.total_time.setBezeled_(False)
        self.total_time.setDrawsBackground_(False)
        self.total_time.setEditable_(False)
        self.total_time.setSelectable_(False)
        self.total_time.setTextColor_(AppKit.NSColor.secondaryLabelColor())
        self.total_time.setAlignment_(AppKit.NSTextAlignmentRight)
        self.total_time.setFont_(AppKit.NSFont.systemFontOfSize_(12))
        self.contentView.addSubview_(self.total_time)
        
        # Create control buttons
        button_size = 32
        button_y = artwork_frame.origin.y - 200
        spacing = 20
        total_width = (button_size * 3) + (spacing * 2)
        start_x = (rect.size.width - total_width) / 2
        
        # Previous button
        self.prev_button = AppKit.NSButton.alloc().initWithFrame_(
            Foundation.NSMakeRect(start_x, button_y, button_size, button_size)
        )
        self.prev_button.setBezelStyle_(AppKit.NSBezelStyleRegularSquare)
        self.prev_button.setImage_(AppKit.NSImage.imageWithSystemSymbolName_accessibilityDescription_("backward.fill", None))
        self.prev_button.setBordered_(False)
        self.prev_button.setAction_(objc.selector(self.previousTrackClicked_, signature=b'v@:@'))
        self.contentView.addSubview_(self.prev_button)
        
        # Play/Pause button
        self.play_button = AppKit.NSButton.alloc().initWithFrame_(
            Foundation.NSMakeRect(start_x + button_size + spacing, button_y, button_size, button_size)
        )
        self.play_button.setBezelStyle_(AppKit.NSBezelStyleRegularSquare)
        self.play_button.setImage_(AppKit.NSImage.imageWithSystemSymbolName_accessibilityDescription_("play.fill", None))
        self.play_button.setBordered_(False)
        self.play_button.setAction_(objc.selector(self.playPauseClicked_, signature=b'v@:@'))
        self.contentView.addSubview_(self.play_button)
        
        # Next button
        self.next_button = AppKit.NSButton.alloc().initWithFrame_(
            Foundation.NSMakeRect(start_x + (button_size * 2) + (spacing * 2), button_y, button_size, button_size)
        )
        self.next_button.setBezelStyle_(AppKit.NSBezelStyleRegularSquare)
        self.next_button.setImage_(AppKit.NSImage.imageWithSystemSymbolName_accessibilityDescription_("forward.fill", None))
        self.next_button.setBordered_(False)
        self.next_button.setAction_(objc.selector(self.nextTrackClicked_, signature=b'v@:@'))
        self.contentView.addSubview_(self.next_button)
        
        return self
        
    def previousTrackClicked_(self, sender):
        self.delegate.previousTrack_(None)
        
    def playPauseClicked_(self, sender):
        self.delegate.togglePlayback_(None)
        
    def nextTrackClicked_(self, sender):
        self.delegate.nextTrack_(None)
        
    def updateTrackInfo_withTrack_isPlaying_(self, sender, track, is_playing):
        self.track_label.setStringValue_(track.title)
        self.artist_label.setStringValue_(f"{track.artist} - {track.album}")
        self.total_time.setStringValue_(track.duration)
        self.play_button.setImage_(
            AppKit.NSImage.imageWithSystemSymbolName_accessibilityDescription_(
                "pause.fill" if is_playing else "play.fill",
                None
            )
        )
        
    def updateProgress_withCurrentSeconds_totalSeconds_(self, sender, current_seconds, total_seconds):
        if total_seconds <= 0:
            progress = 0
        else:
            progress = (current_seconds / total_seconds) * 100
        self.progress_bar.setDoubleValue_(progress)
        
        minutes = current_seconds // 60
        seconds = current_seconds % 60
        self.current_time.setStringValue_(f"{minutes:02d}:{seconds:02d}")

    def setArtwork_(self, image_data):
        if image_data:
            image = AppKit.NSImage.alloc().initWithData_(image_data)
            if image:
                self.artwork_view.setImage_(image)
        else:
            # Set default artwork
            self.artwork_view.setImage_(
                AppKit.NSImage.imageWithSystemSymbolName_accessibilityDescription_(
                    "music.note", None
                )
            )

class VinylScrobbler(AppKit.NSObject):
    def __new__(cls):
        self = objc.super(VinylScrobbler, cls).__new__(cls)
        if self is None:
            return None
        return self
        
    def init(self):
        self = objc.super(VinylScrobbler, self).init()
        if self is None:
            return None
            
        try:
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
            self.show_notifications = True
            
            # Load about configuration
            self.about_config = self.load_about_config()
            
            # Create and setup the player window
            self.setup_player_window()
            
            # Setup UI
            self.setup_status_bar()
            
            # Load configuration
            self.logger.info("Loading configuration...")
            self.load_config()
            
            # Initialize services
            self.logger.info("Initializing services...")
            self.initialize_services()
            
            # Request notification permissions
            self.setup_notifications()
            
        except Exception as e:
            self.logger.error(f"Initialization error: {str(e)}")
            return None
            
        return self

    def setup_player_window(self):
        """Setup the player window"""
        # Create window
        window_width = 400
        window_height = 600
        screen = AppKit.NSScreen.mainScreen()
        if screen:
            screen_rect = screen.visibleFrame()
            x = screen_rect.origin.x + (screen_rect.size.width - window_width) / 2
            y = screen_rect.origin.y + (screen_rect.size.height - window_height) / 2
        else:
            x = 0
            y = 0
            
        window_rect = Foundation.NSMakeRect(x, y, window_width, window_height)
        style_mask = (
            AppKit.NSWindowStyleMaskTitled |
            AppKit.NSWindowStyleMaskClosable |
            AppKit.NSWindowStyleMaskMiniaturizable |
            AppKit.NSWindowStyleMaskFullSizeContentView
        )
        
        self.player_window = PlayerWindow.alloc().initWithContentRect_styleMask_backing_defer_(
            window_rect,
            style_mask,
            AppKit.NSBackingStoreBuffered,
            False
        )
        self.player_window.setDelegate_(self)
        self.player_window.delegate = self
        self.player_window.setLevel_(AppKit.NSFloatingWindowLevel)
        
        # Show window
        self.player_window.makeKeyAndOrderFront_(None)
        
    def windowShouldClose_(self, sender):
        """Handle window close button"""
        self.player_window.orderOut_(None)
        return True
        
    def showPlayer_(self, sender):
        """Show the player window"""
        self.player_window.makeKeyAndOrderFront_(None)

    def setup_status_bar(self):
        """Setup the status bar item and menu"""
        self.statusbar = AppKit.NSStatusBar.systemStatusBar()
        self.statusitem = self.statusbar.statusItemWithLength_(AppKit.NSVariableStatusItemLength)
        
        # Set initial title to just the vinyl icon
        self.statusitem.button().setTitle_("💿")
        
        # Create the menu
        self.menu = AppKit.NSMenu.alloc().init()
        self.statusitem.setMenu_(self.menu)
        
        # Add menu items
        self.setup_menu()

    def setup_menu(self):
        """Setup the status bar menu items"""
        # Clear existing menu items
        while self.menu.numberOfItems() > 0:
            self.menu.removeItemAtIndex_(0)
            
        # Add menu items
        search_item = AppKit.NSMenuItem.alloc().initWithTitle_action_keyEquivalent_("Search Album", "searchAlbum:", "")
        search_item.setTarget_(self)
        self.menu.addItem_(search_item)
        
        show_player = AppKit.NSMenuItem.alloc().initWithTitle_action_keyEquivalent_("Show Player", "showPlayer:", "")
        show_player.setTarget_(self)
        self.menu.addItem_(show_player)
        
        # Add play/pause item
        self.play_pause_item = AppKit.NSMenuItem.alloc().initWithTitle_action_keyEquivalent_(
            "Start Playing", "togglePlayback:", ""
        )
        self.play_pause_item.setTarget_(self)
        self.menu.addItem_(self.play_pause_item)
        
        next_item = AppKit.NSMenuItem.alloc().initWithTitle_action_keyEquivalent_("Next Track", "nextTrack:", "")
        next_item.setTarget_(self)
        self.menu.addItem_(next_item)
        
        prev_item = AppKit.NSMenuItem.alloc().initWithTitle_action_keyEquivalent_("Previous Track", "previousTrack:", "")
        prev_item.setTarget_(self)
        self.menu.addItem_(prev_item)
        
        # Add tracks submenu
        tracks_item = AppKit.NSMenuItem.alloc().initWithTitle_action_keyEquivalent_("Tracks", None, "")
        tracks_submenu = AppKit.NSMenu.alloc().init()
        tracks_item.setSubmenu_(tracks_submenu)
        
        # Populate tracks if we have an album loaded
        if hasattr(self, 'tracks') and self.tracks:
            for track in self.tracks:
                # Format track title without duration to match screenshot
                track_title = f"{track.position}. {track.title}"
                track_item = AppKit.NSMenuItem.alloc().initWithTitle_action_keyEquivalent_(
                    track_title, "trackSelected:", ""
                )
                track_item.setTarget_(self)
                track_item.setRepresentedObject_(track)
                tracks_submenu.addItem_(track_item)
        else:
            no_tracks = AppKit.NSMenuItem.alloc().initWithTitle_action_keyEquivalent_("None", None, "")
            no_tracks.setEnabled_(False)
            tracks_submenu.addItem_(no_tracks)
        
        self.menu.addItem_(tracks_item)
        
        notif_item = AppKit.NSMenuItem.alloc().initWithTitle_action_keyEquivalent_("Toggle Notifications", "toggleNotifications:", "")
        notif_item.setTarget_(self)
        self.menu.addItem_(notif_item)
        
        quit_item = AppKit.NSMenuItem.alloc().initWithTitle_action_keyEquivalent_("Quit", "quitApp:", "q")
        quit_item.setTarget_(self)
        self.menu.addItem_(quit_item)

    def searchAlbum_(self, sender):
        """Load album from Discogs ID"""
        try:
            # Stop any current playback
            if self.is_playing:
                self.stop_playback()
            
            alert = AppKit.NSAlert.alloc().init()
            alert.setMessageText_("Enter Discogs Release ID:")
            alert.addButtonWithTitle_("Load")
            alert.addButtonWithTitle_("Cancel")
            text_field = AppKit.NSTextField.alloc().initWithFrame_(Foundation.NSMakeRect(0, 0, 200, 24))
            alert.setAccessoryView_(text_field)
            
            response = alert.runModal()
            if response == AppKit.NSAlertFirstButtonReturn:
                try:
                    # Handle both full URLs and just IDs
                    text = text_field.stringValue()
                    release_id = None
                    
                    # Check if it's a URL
                    if text.startswith('http'):
                        import re
                        match = re.search(r'/release/(\d+)', text)
                        if match:
                            release_id = match.group(1)
                    else:
                        # Assume it's just an ID
                        release_id = text.strip()
                    
                    if release_id and release_id.isdigit():
                        release = self.discogs.release(release_id)
                        self.load_album(release)
                    else:
                        self.show_alert(
                            "Invalid Input", 
                            "Please enter either a Discogs Release ID (e.g., 8844291) or "
                            "a Discogs URL (e.g., https://www.discogs.com/release/8844291-...)"
                        )
                except Exception as e:
                    self.logger.error(f"Error loading release: {str(e)}")
                    self.show_alert("Error", f"Failed to load release: {str(e)}")
        except Exception as e:
            self.logger.error(f"Error in search_album: {str(e)}")
            self.show_alert("Error", f"Failed to search album: {str(e)}")

    def nextTrack_(self, sender):
        """Skip to next track"""
        try:
            if not self.tracks:
                return
                
            self.handle_track_end()
            
        except Exception as e:
            self.logger.error(f"Error skipping track: {str(e)}")
            if self.show_notifications:
                self.show_alert("Error", f"Failed to skip track: {str(e)}")

    def previousTrack_(self, sender):
        """Skip to previous track"""
        try:
            if not self.tracks:
                return
                
            self.current_track_index -= 1
            if self.current_track_index < 0:
                self.current_track_index = len(self.tracks) - 1
            
            self.update_status_bar("💿")
        except Exception as e:
            self.logger.error(f"Error skipping track: {str(e)}")
            if self.show_notifications:
                self.show_alert("Error", f"Failed to skip track: {str(e)}")

    def toggleNotifications_(self, sender):
        """Toggle notifications"""
        self.show_notifications = not self.show_notifications
        self.logger.info(f"Notifications toggled to: {self.show_notifications}")

    def quitApp_(self, sender):
        """Quit the application"""
        AppKit.NSApplication.sharedApplication().terminate_(None)

    def setup_notifications(self):
        """Request notification permissions"""
        notification_center = UNUserNotificationCenter.currentNotificationCenter()
        notification_center.requestAuthorizationWithOptions_completionHandler_(
            (1 << 0) | (1 << 1),  # UNAuthorizationOptionAlert | UNAuthorizationOptionSound
            lambda granted, error: self.logger.info(f"Notification authorization granted: {granted}")
        )

    def show_notification(self, title, body):
        """Show a macOS notification"""
        if not self.show_notifications:
            return
            
        content = UNMutableNotificationContent.alloc().init()
        content.setTitle_(title)
        content.setBody_(body)
        
        request = UNNotificationRequest.requestWithIdentifier_content_trigger_(
            str(Foundation.NSUUID.UUID().UUIDString()),
            content,
            None
        )
        
        UNUserNotificationCenter.currentNotificationCenter().addNotificationRequest_withCompletionHandler_(
            request,
            None
        )

    def show_alert(self, title, message):
        """Show a modal alert dialog"""
        alert = AppKit.NSAlert.alloc().init()
        alert.setMessageText_(title)
        alert.setInformativeText_(message)
        alert.runModal()

    def update_status_bar(self, text):
        """Update the status bar text"""
        # Always just show the vinyl icon
        self.statusitem.button().setTitle_("💿")

    def quit_app(self):
        """Quit the application"""
        AppKit.NSApplication.sharedApplication().terminate_(None)

    def clean_artist_name(self, artist_name: str) -> str:
        """Clean artist name from Discogs format to match LastFM format."""
        import re
        cleaned_name = re.sub(r'\s*\(\d+\)\s*$', '', artist_name)
        return cleaned_name.strip()

    def update_title_with_timer(self, duration_seconds):
        """Update the status bar title with a countdown timer"""
        try:
            self.stop_timer = False
            start_time = time.time()
            
            def update_timer():
                while not self.stop_timer and self.is_playing:
                    try:
                        elapsed = int(time.time() - start_time)
                        remaining = max(0, duration_seconds - elapsed)
                        
                        # Update player window progress only, not status bar
                        self.player_window.updateProgress_withCurrentSeconds_totalSeconds_(None, elapsed, duration_seconds)
                        
                        time.sleep(1)
                        
                        if remaining <= 0:
                            break
                            
                    except Exception as e:
                        self.logger.error(f"Error in timer thread: {str(e)}")
                        break
            
            self.timer_thread = threading.Thread(target=update_timer)
            self.timer_thread.daemon = True
            self.timer_thread.start()
            
        except Exception as e:
            self.logger.error(f"Error starting timer: {str(e)}")
            raise

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
                    'show_notifications': True
                }
                
                # Write default config
                with open(config_file, 'w') as f:
                    json.dump(default_config, f, indent=4)
                    
                # Show first-run message
                self.logger.info("Creating default configuration file")
                self.show_alert(
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
                self.show_alert(
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

    def search_album(self, _):
        """Load album from Discogs ID"""
        try:
            # Create a window for Discogs ID input
            alert = AppKit.NSAlert.alloc().init()
            alert.setMessageText_("Enter Discogs Release ID:")
            alert.addButtonWithTitle_("Load")
            alert.addButtonWithTitle_("Cancel")
            text_field = AppKit.NSTextField.alloc().initWithFrame_(Foundation.NSMakeRect(0, 0, 200, 24))
            alert.setAccessoryView_(text_field)
            
            response = alert.runModal()
            if response == AppKit.NSAlertFirstButtonReturn:  # 1000 is the return value for the first button (Load)
                try:
                    # Handle both full URLs and just IDs
                    text = text_field.stringValue()
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
                        self.show_alert(
                            "Invalid Input", 
                            "Please enter either a Discogs Release ID (e.g., 8844291) or "
                            "a Discogs URL (e.g., https://www.discogs.com/release/8844291-...)"
                        )
                except Exception as e:
                    self.logger.error(f"Error loading release: {str(e)}")
                    self.show_alert("Error", f"Failed to load release: {str(e)}")
        except Exception as e:
            self.logger.error(f"Error in search_album: {str(e)}")
            self.show_alert("Error", f"Failed to search album: {str(e)}")

    def load_album(self, release):
        """Load album tracks from a Discogs release"""
        try:
            if not release:
                return
            
            self.current_album = release
            self.tracks = []
            
            # Get artwork from Last.fm
            try:
                if hasattr(release, 'artists') and release.artists and hasattr(release, 'title'):
                    artist_name = release.artists[0].name
                    album_title = release.title
                    self.logger.info(f"Fetching Last.fm artwork for {artist_name} - {album_title}")
                    
                    album = self.network.get_album(artist_name, album_title)
                    if album:
                        # Try different sizes in order
                        image_url = None
                        for size in [pylast.SIZE_MEGA, pylast.SIZE_EXTRA_LARGE, pylast.SIZE_LARGE, pylast.SIZE_MEDIUM]:
                            try:
                                image_url = album.get_cover_image(size=size)
                                if image_url:
                                    self.logger.info(f"Found {size} image: {image_url}")
                                    break
                            except Exception as e:
                                self.logger.info(f"No {size} image available: {str(e)}")
                                continue
                        
                        if image_url:
                            self.logger.info(f"Loading artwork from Last.fm: {image_url}")
                            response = requests.get(image_url)
                            if response.status_code == 200:
                                image_data = Foundation.NSData.dataWithBytes_length_(
                                    response.content,
                                    len(response.content)
                                )
                                self.player_window.setArtwork_(image_data)
                                self.logger.info("Successfully loaded artwork from Last.fm")
                            else:
                                self.logger.error(f"Failed to load Last.fm artwork: HTTP {response.status_code}")
                                self.player_window.setArtwork_(None)
                        else:
                            self.logger.info("No artwork URL found in Last.fm response")
                            self.player_window.setArtwork_(None)
                    else:
                        self.logger.info("Album not found on Last.fm")
                        self.player_window.setArtwork_(None)
                else:
                    self.logger.info("Missing artist or album information")
                    self.player_window.setArtwork_(None)
            except Exception as e:
                self.logger.error(f"Error loading Last.fm artwork: {str(e)}")
                self.player_window.setArtwork_(None)
            
            # Process tracks
            for track in release.tracklist:
                # Skip non-track items (like headings)
                if hasattr(track, 'type_') and track.type_ == 'heading':
                    continue
                
                # Extract duration in seconds
                duration = getattr(track, 'duration', '') or "3:30"  # Default to 3:30 if no duration
                try:
                    if ':' in duration:
                        parts = duration.split(':')
                        if len(parts) == 2:
                            minutes, seconds = map(int, parts)
                            duration_seconds = max((minutes * 60) + seconds, 1)  # Ensure at least 1 second
                        elif len(parts) == 3:
                            hours, minutes, seconds = map(int, parts)
                            duration_seconds = max((hours * 3600) + (minutes * 60) + seconds, 1)
                        else:
                            self.logger.warning(f"Invalid duration format for track {track.position}: {duration}")
                            duration = "3:30"
                            duration_seconds = 210
                    else:
                        self.logger.warning(f"No duration for track {track.position}, using default")
                        duration = "3:30"
                        duration_seconds = 210
                except (ValueError, AttributeError) as e:
                    self.logger.warning(f"Error parsing duration for track {track.position}: {str(e)}")
                    duration = "3:30"
                    duration_seconds = 210
                
                # Create track object
                track_obj = Track(
                    position=getattr(track, 'position', ''),
                    title=getattr(track, 'title', 'Unknown Track'),
                    duration=duration,
                    duration_seconds=duration_seconds,
                    artist=release.artists[0].name if release.artists else '',
                    album=release.title
                )
                self.tracks.append(track_obj)
            
            # Reset playback state
            self.current_track_index = 0
            self.is_playing = False
            if self.scrobble_timer:
                self.scrobble_timer.cancel()
            
            # Update player window
            if self.tracks:
                first_track = self.tracks[0]
                self.player_window.updateTrackInfo_withTrack_isPlaying_(None, first_track, False)
                self.player_window.updateProgress_withCurrentSeconds_totalSeconds_(None, 0, max(1, first_track.duration_seconds))
                # Refresh the menu to show tracks
                self.setup_menu()
                self.logger.info(f"Loaded album: {release.title} with {len(self.tracks)} tracks")
        
        except Exception as e:
            self.logger.error(f"Error loading album: {str(e)}")
            raise

    def trackSelected_(self, sender):
        """Handle track selection from menu"""
        try:
            # Extract track position from menu item title
            position = sender.title().split('.')[0].strip()
            
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
                
                # Set new track
                self.current_track_index = track_index
                
                # Update the title with current track (without timer since not playing)
                self.update_status_bar("💿")
                
                self.logger.info(f"Selected track: {position} - {self.tracks[track_index].title}")
            else:
                self.logger.error(f"Could not find track with position: {position}")
                
        except Exception as e:
            self.logger.error(f"Error selecting track: {str(e)}")
            if self.show_notifications:
                self.show_alert("Error", f"Failed to select track: {str(e)}")

    def next_track(self, _):
        """Skip to next track"""
        try:
            if not self.tracks:
                return
                
            self.handle_track_end()
        except Exception as e:
            self.logger.error(f"Error skipping track: {str(e)}")
            if self.show_notifications:
                self.show_alert("Error", f"Failed to skip track: {str(e)}")

    def previous_track(self, _):
        """Skip to previous track"""
        try:
            if not self.tracks:
                return
                
            self.current_track_index -= 1
            if self.current_track_index < 0:
                self.current_track_index = len(self.tracks) - 1
            
            self.update_status_bar("💿")
        except Exception as e:
            self.logger.error(f"Error skipping track: {str(e)}")
            if self.show_notifications:
                self.show_alert("Error", f"Failed to skip track: {str(e)}")

    def toggle_notifications(self, _):
        """Toggle notifications"""
        self.show_notifications = not self.show_notifications
        self.logger.info(f"Notifications toggled to: {self.show_notifications}")

    def togglePlayback_(self, sender):
        """Toggle vinyl playback"""
        try:
            if not self.tracks:
                if self.show_notifications:
                    self.show_alert("Error", "Please search and select an album first")
                return

            if self.is_playing:
                self.play_pause_item.setTitle_("Start Playing")
                self.stop_playback()
            else:
                self.play_pause_item.setTitle_("Stop Playing")
                self.start_playback()
        except Exception as e:
            self.logger.error(f"Error toggling playback: {str(e)}")
            if self.show_notifications:
                self.show_alert("Error", f"Failed to toggle playback: {str(e)}")

    def start_playback(self):
        """Start playing current track"""
        try:
            current_track = self.tracks[self.current_track_index]
            self.logger.info(f"Starting playback of track: {current_track.title}")

            # Show notification for track change if enabled
            if self.show_notifications:
                self.show_notification(
                    "Now Playing",
                    f"{current_track.artist} - {current_track.title}"
                )
            
            # Update now playing
            self.network.update_now_playing(
                artist=current_track.artist,
                title=current_track.title,
                album=current_track.album,
                duration=current_track.duration_seconds
            )
            
            # Start scrobble timer
            self.is_playing = True
            self.scrobble_timer = threading.Timer(
                current_track.duration_seconds,
                self.handle_track_end
            )
            self.scrobble_timer.start()
            
            # Start status bar timer
            self.update_title_with_timer(current_track.duration_seconds)
            
            # Update player window
            self.player_window.updateTrackInfo_withTrack_isPlaying_(None, current_track, True)
            self.player_window.updateProgress_withCurrentSeconds_totalSeconds_(None, 0, current_track.duration_seconds)
            
        except Exception as e:
            self.logger.error(f"Error starting playback: {str(e)}")
            raise

    def stop_playback(self):
        """Stop current playback"""
        try:
            self.is_playing = False
            
            # Cancel scrobble timer
            if self.scrobble_timer:
                self.scrobble_timer.cancel()
            
            # Stop status bar timer
            self.stop_timer = True
            if self.timer_thread and self.timer_thread.is_alive():
                self.timer_thread.join(timeout=1)
            
            self.update_status_bar("💿")
            
            # Update player window
            self.player_window.updateTrackInfo_withTrack_isPlaying_(None, self.tracks[self.current_track_index], False)
            self.player_window.updateProgress_withCurrentSeconds_totalSeconds_(None, 0, self.tracks[self.current_track_index].duration_seconds)
            
        except Exception as e:
            self.logger.error(f"Error stopping playback: {str(e)}")
            raise

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
                if self.show_notifications:
                    self.show_alert("Playback finished", "End of album reached")
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
            self.show_alert(title=f"About {self.about_config.get('app_name', 'Vinyl Scrobbler')}", message=about_text)

def main():
    app = AppKit.NSApplication.sharedApplication()
    delegate = VinylScrobbler.alloc().init()
    app.setDelegate_(delegate)
    app.run()

if __name__ == "__main__":
    main()
