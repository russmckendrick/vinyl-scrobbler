import Cocoa
import Foundation
import OSLog
import UserNotifications

// MARK: - Array Extension
// Adds safe array access to prevent index out of bounds errors
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

@main
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    
    // MARK: - Properties
    // Logger instance for app-wide logging
    private let logger = Logger(subsystem: "com.vinyl.scrobbler", category: "AppDelegate")
    
    // Menu bar status item and main menu
    var statusItem: NSStatusItem!
    var mainMenu: NSMenu!
    
    // MARK: - Window Management
    // References to main window and view controllers
    private var mainWindow: NSWindow?
    private var _mainViewController: ViewController?
    private var _authViewController: AuthViewController?
    private var authWindow: NSWindow? {
        willSet {
            // Clean up old window delegate when setting new window
            if let oldWindow = authWindow {
                oldWindow.delegate = nil
            }
        }
    }
    
    // Lazy loading of main view controller
    private var mainViewController: ViewController? {
        if _mainViewController == nil {
            _mainViewController = NSApp.windows.first?.contentViewController as? ViewController
        }
        return _mainViewController
    }
    
    // MARK: - Track Model
    // Represents a single track in the album
    struct Track {
        let position: String
        let title: String
        var duration: String?
        let artist: String
        let album: String
        
        // Computed property to convert MM:SS duration to seconds
        var durationSeconds: Int? {
            guard let duration = duration else { return nil }
            let components = duration.split(separator: ":")
            if components.count == 2,
               let minutes = Int(components[0]),
               let seconds = Int(components[1]) {
                return minutes * 60 + seconds
            }
            return nil
        }
    }
    
    // MARK: - Playback State
    // Current album and playback tracking
    var tracks: [Track] = []
    var currentTrackIndex: Int = 0
    var isPlaying: Bool = false
    var currentTrackScrobbled: Bool = false
    var currentTrackStartTime: Date? = nil
    
    // Timers for playback progress
    private var playbackTimer: Timer?
    private var dispatchTimer: DispatchSourceTimer?
    var currentPlaybackSeconds: Int = 0
    
    // Notification preferences
    var showNotifications: Bool = true
    
    // MARK: - Services
    // Service instances for Discogs and Last.fm
    private let discogsService = DiscogsService.shared
    private var lastFMService: LastFMService {
        LastFMService.shared
    }
    
    // MARK: - Search Management
    private var currentSearchDataSource: SearchResultsDataSource?
    private var searchWindowController: SearchWindowController?
    
    // MARK: - App Lifecycle
    
    @MainActor
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)
        
        // Setup menu bar with everything disabled initially
        createStatusItem()
        
        // Start with everything disabled
        enableMenuItems(false)
        
        // Request notification permissions
        requestNotificationPermissions()
        
        // Check for Last.fm authentication first - don't show login window automatically
        Task {
            // Check if we have a valid session key
            if let sessionKey = LastFMService.shared.getStoredSessionKey() {
                // We have a stored session key, use it
                LastFMService.shared.setSessionKey(sessionKey)
                logger.info("✅ Loaded stored Last.fm session key")
                updateLastFmMenuItems()
                enableMenuItems(true)  // Enable menu items since we're logged in
            } else {
                // No stored session - keep everything disabled except essential items
                updateLastFmMenuItems()
                enableMenuItems(false)
            }
        }
        
        // Initialize window but keep it hidden
        if let windowController = NSStoryboard.main?.instantiateInitialController() as? NSWindowController {
            mainWindow = windowController.window
            mainWindow?.orderOut(nil)  // Make sure window is hidden
        }
        
        NotificationCenter.default.addObserver(self, 
                                         selector: #selector(handlePreviousPage), 
                                         name: NSNotification.Name("LoadPreviousPage"), 
                                         object: nil)
        NotificationCenter.default.addObserver(self, 
                                         selector: #selector(handleNextPage), 
                                         name: NSNotification.Name("LoadNextPage"), 
                                         object: nil)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Clean up if needed
        if let timer = playbackTimer {
            timer.invalidate()
        }
        dispatchTimer?.cancel()
    }
    
    // MARK: - Status Bar
    
    func createStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "♪"
        
        mainMenu = NSMenu()
        
        // Load Album
        mainMenu.addItem(withTitle: "Load Album", action: #selector(loadAlbumClicked(_:)), keyEquivalent: "")
        mainMenu.addItem(NSMenuItem.separator())
        
        // Playback Controls
        mainMenu.addItem(withTitle: "Previous Track", action: #selector(previousTrackMenuAction(_:)), keyEquivalent: "")
        mainMenu.addItem(withTitle: "Play/Pause", action: #selector(togglePlayback(_:)), keyEquivalent: "")
        mainMenu.addItem(withTitle: "Next Track", action: #selector(nextTrackMenuAction(_:)), keyEquivalent: "")
        mainMenu.addItem(NSMenuItem.separator())
        
        // Add Tracks submenu
        let tracksMenu = NSMenu()
        let tracksItem = NSMenuItem(title: "Tracks", action: nil, keyEquivalent: "")
        tracksItem.submenu = tracksMenu
        mainMenu.addItem(tracksItem)
        
        mainMenu.addItem(NSMenuItem.separator())
        
        // Window and Notification controls
        let playerMenuItem = NSMenuItem(title: "Open Player", action: #selector(togglePlayerWindow(_:)), keyEquivalent: "")
        mainMenu.addItem(playerMenuItem)
        mainMenu.addItem(withTitle: "Toggle Notifications (On)", action: #selector(toggleNotifications(_:)), keyEquivalent: "")
        
        mainMenu.addItem(NSMenuItem.separator())
        
        // Last.fm Account section
        let lastFmMenuItem = NSMenuItem(title: "Last.fm Account", action: nil, keyEquivalent: "")
        let lastFmSubmenu = NSMenu()
        
        // We'll update this in updateLastFmMenuItems
        lastFmMenuItem.submenu = lastFmSubmenu
        mainMenu.addItem(lastFmMenuItem)
        
        mainMenu.addItem(NSMenuItem.separator())
        
        // About and Quit
        mainMenu.addItem(withTitle: "About", action: #selector(showAbout(_:)), keyEquivalent: "")
        mainMenu.addItem(NSMenuItem.separator())
        mainMenu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        
        statusItem.menu = mainMenu
        updateMenuItemsForWindowState()
        updateLastFmMenuItems()
    }
    
    internal func updateLastFmMenuItems() {
        guard let lastFmMenu = mainMenu.item(withTitle: "Last.fm Account")?.submenu else { return }
        lastFmMenu.removeAllItems()
        
        if lastFMService.getStoredSessionKey() != nil {
            // User is logged in
            lastFmMenu.addItem(withTitle: "Sign Out", action: #selector(signOutLastFm(_:)), keyEquivalent: "")
        } else {
            // User is logged out
            lastFmMenu.addItem(withTitle: "Sign In", action: #selector(signInLastFm(_:)), keyEquivalent: "")
        }
    }
    
    @objc private func signOutLastFm(_ sender: Any) {
        Task { @MainActor in
            // Disable menu items FIRST before clearing session
            enableMenuItems(false)
            
            // Clear session
            LastFMService.shared.clearSession()
            
            // Remove from keychain
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: "lastfm_session_key"
            ]
            SecItemDelete(query as CFDictionary)
            
            // Update Last.fm menu last
            updateLastFmMenuItems()
            
            logger.info("Successfully signed out from Last.fm")
        }
    }
    
    @objc private func signInLastFm(_ sender: Any) {
        // Create and show auth window
        let authVC = AuthViewController(lastFMService: lastFMService) { [weak self] in
            // Success callback
            self?.updateLastFmMenuItems()
            self?.enableMenuItems(true)
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        window.contentViewController = authVC
        window.title = "Last.fm Login"
        window.center()
        
        // Store window reference
        self.authWindow = window
        
        // Show window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func loadAlbumClicked(_ sender: Any) {
        if checkLastFMAuthAndShowAlert() {
            let alert = NSAlert()
            alert.messageText = "Load Album"
            alert.informativeText = "Choose how to load an album"
            alert.addButton(withTitle: "Search Discogs")
            alert.addButton(withTitle: "Enter URL/ID")
            alert.addButton(withTitle: "Cancel")
            
            let response = alert.runModal()
            
            Task {
                switch response {
                case .alertFirstButtonReturn:
                    await showDiscogsSearch()
                case .alertSecondButtonReturn:
                    await searchAlbumAction(sender)
                default:
                    break
                }
            }
        }
    }
    
    // MARK: - Menu Actions
    
    @objc func searchAlbumAction(_ sender: Any?) async {
        // Create a new window for the alert if main window is not visible
        let alert = NSAlert()
        alert.messageText = "Enter Discogs Release URL or ID"
        alert.addButton(withTitle: "Load")
        alert.addButton(withTitle: "Cancel")
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        alert.accessoryView = textField
        
        await withCheckedContinuation { [weak self] continuation in
            if let window = NSApp.mainWindow, self?.mainViewController?.isPlayerWindowVisible == true {
                // Use sheet if player window is visible
                alert.beginSheetModal(for: window) { response in
                    if response == .alertFirstButtonReturn {
                        let input = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !input.isEmpty else {
                            continuation.resume()
                            return
                        }
                        
                        Task { [weak self] in
                            await self?.loadDiscogsRelease(from: input)
                            continuation.resume()
                        }
                    } else {
                        continuation.resume()
                    }
                }
            } else {
                // Run as modal if no player window
                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    let input = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !input.isEmpty else {
                        continuation.resume()
                        return
                    }
                    
                    Task { [weak self] in
                        await self?.loadDiscogsRelease(from: input)
                        continuation.resume()
                    }
                } else {
                    continuation.resume()
                }
            }
        }
    }
    
    @objc func previousTrackMenuAction(_ sender: Any?) {
        if checkLastFMAuthAndShowAlert() {
            previousTrack(sender)
        }
    }
    
    @objc func playPauseMenuAction(_ sender: Any?) {
        if checkLastFMAuthAndShowAlert() {
            togglePlayPause(sender)
        }
    }
    
    @objc func nextTrackMenuAction(_ sender: Any?) {
        if checkLastFMAuthAndShowAlert() {
            nextTrack(sender)
        }
    }
    
    @objc func toggleNotifications(_ sender: Any?) {
        showNotifications.toggle()
        updateNotificationMenuItem()
        
        if showNotifications {
            // Possibly show a notification to confirm
            showNotification(title: "Notifications Enabled", body: "You will now receive notifications when tracks change.")
        }
    }
    
    @objc func togglePlayback(_ sender: Any?) {
        guard !tracks.isEmpty else {
            showAlert(title: "Error", message: "Please load an album first.")
            return
        }
        isPlaying.toggle()
        if isPlaying {
            playCurrentTrack()
        } else {
            stopPlayback()
        }
        updateStatusIcon()
    }
    
    @objc func togglePlayerWindow(_ sender: Any?) {
        logger.info("🪟 togglePlayerWindow called")
        
        guard let mainViewController = self.mainViewController else {
            logger.error("❌ mainViewController is nil")
            return
        }
        
        let isVisible = mainViewController.isPlayerWindowVisible
        logger.info("🪟 Current window visibility: \(isVisible)")
        
        if isVisible {
            logger.info("🪟 Hiding window")
            mainViewController.hidePlayerWindow()
        } else {
            logger.info("🪟 Showing window")
            // Ensure window exists and has proper delegate
            if let window = mainWindow {
                window.delegate = mainViewController
                mainViewController.showPlayerWindow()
            }
        }
        
        updateMenuItemsForWindowState()
        logger.info("🪟 Window toggle completed")
    }
    
    @objc func showAbout(_ sender: Any?) {
        let alert = NSAlert()
        
        // Create custom view for about content
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 160))
        
        // App name and version
        let titleLabel = NSTextField(labelWithString: "\(AppConfig.name)")
        titleLabel.frame = NSRect(x: 0, y: 130, width: 300, height: 20)
        titleLabel.alignment = .center
        titleLabel.font = NSFont.boldSystemFont(ofSize: 16)
        container.addSubview(titleLabel)
        
        let versionLabel = NSTextField(labelWithString: "Version \(AppConfig.version)")
        versionLabel.frame = NSRect(x: 0, y: 100, width: 300, height: 20)
        versionLabel.alignment = .center
        versionLabel.textColor = .secondaryLabelColor
        container.addSubview(versionLabel)
        
        // Description
        let descLabel = NSTextField(labelWithString: AppConfig.description)
        descLabel.frame = NSRect(x: 20, y: 70, width: 260, height: 20)
        descLabel.alignment = .center
        descLabel.textColor = .secondaryLabelColor
        container.addSubview(descLabel)
        
        // GitHub link
        let linkButton = NSButton(frame: NSRect(x: 0, y: 40, width: 300, height: 20))
        linkButton.title = "www.vinyl-scrobbler.app"
        linkButton.bezelStyle = .inline
        linkButton.isBordered = false
        linkButton.alignment = .center
        linkButton.contentTintColor = .linkColor
        linkButton.target = self
        linkButton.action = #selector(openGitHub)
        container.addSubview(linkButton)
        
        // Copyright
        let copyrightLabel = NSTextField(labelWithString: "\(AppConfig.year) \(AppConfig.author)")
        copyrightLabel.frame = NSRect(x: 0, y: 10, width: 300, height: 20)
        copyrightLabel.alignment = .center
        copyrightLabel.textColor = .secondaryLabelColor
        container.addSubview(copyrightLabel)
        
        alert.accessoryView = container
        alert.addButton(withTitle: "OK")
        
        // Keep the alert icon but remove the text
        alert.messageText = ""
        alert.informativeText = ""
        
        alert.runModal()
    }
    
    @objc private func openGitHub() {
        if let url = URL(string: AppConfig.githubURL) {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc func quitApp(_ sender: Any?) {
        NSApplication.shared.terminate(nil)
    }
    
    @objc func trackSelected(_ sender: NSMenuItem) {
        currentTrackIndex = sender.tag
        updateTrackDisplay()
        playCurrentTrack()
        updateControlState()
    }
    
    // MARK: - Playback Logic
    
    @MainActor
    private func playCurrentTrack(showNotificationOnStart: Bool = true) {
        guard currentTrackIndex < tracks.count else { return }
        isPlaying = true
        
        let track = tracks[currentTrackIndex]
        updateTrackDisplay()
        
        // Reset playback state
        currentPlaybackSeconds = 0
        updatePlaybackDisplay()
        
        // Start timer
        startPlayback()
        
        // Handle Last.fm updates
        Task {
            do {
                // First update now playing status
                try await lastFMService.updateNowPlaying(track: track)
                logger.info("✅ Updated Now Playing: \(track.title)")
                
                // Then wait and scrobble if conditions are met
                if let duration = track.durationSeconds {
                    if duration <= 30 {
                        logger.info("⏭️ Track '\(track.title)' is too short (\(duration) seconds) to scrobble. Minimum duration is 30 seconds.")
                        return
                    }
                    
                    let scrobbleTime = duration / 2  // Scrobble at 50% of track duration
                    logger.info("⏳ Will scrobble '\(track.title)' after \(scrobbleTime) seconds (50% of \(duration)s)")
                    
                    try await Task.sleep(nanoseconds: UInt64(scrobbleTime) * 1_000_000_000)
                    
                    // Only scrobble if we're still playing the same track
                    if self.isPlaying && self.currentTrackIndex == self.tracks.firstIndex(where: { $0.title == track.title }) {
                        try await self.lastFMService.scrobbleTrack(track: track)
                        logger.info("✅ Successfully scrobbled: \(track.title)")
                        
                        // Wait for the remaining duration
                        let remainingTime = duration - scrobbleTime
                        try await Task.sleep(nanoseconds: UInt64(remainingTime) * 1_000_000_000)
                        
                        // If we're still playing and this was the track that completed
                        if self.isPlaying && self.currentTrackIndex == self.tracks.firstIndex(where: { $0.title == track.title }) {
                            await MainActor.run {
                                // Only proceed if we're not at the last track
                                if self.currentTrackIndex < self.tracks.count - 1 {
                                    self.currentTrackIndex += 1
                                    self.playCurrentTrack()
                                } else {
                                    // Stop playback at the end of the last track
                                    self.stopPlayback()
                                }
                            }
                        }
                    }
                } else {
                    logger.warning("⚠️ No duration available for '\(track.title)' - Cannot determine scrobble timing")
                }
            } catch {
                logger.error("❌ Failed to update Last.fm: \(error.localizedDescription)")
            }
        }
        
        updateControlState()
        
        // Show notification if enabled and requested
        if showNotifications && showNotificationOnStart {
            showNotification(for: track, with: mainViewController?.albumArtworkView.image)
        }
    }
    
    @IBAction public func togglePlayPause(_ sender: Any?) {
        Task { @MainActor in
            isPlaying.toggle()
            mainViewController?.isPlaying = isPlaying
            mainViewController?.updatePlayPauseButton()
            mainViewController?.reloadTrackList()
            
            if isPlaying {
                playCurrentTrack()
            } else {
                stopPlayback()
            }
        }
    }
    
    @MainActor
    private func stopPlayback() {
        isPlaying = false
        playbackTimer?.invalidate()
        dispatchTimer?.cancel()
        dispatchTimer = nil
        currentPlaybackSeconds = 0
        updateProgressDisplay()
    }
    
    @objc public func updatePlaybackProgress() {
        guard currentTrackIndex < tracks.count && isPlaying else { return }
        
        currentPlaybackSeconds += 1
        let track = tracks[safe: currentTrackIndex]
        let total = track?.durationSeconds ?? 1
        let percent = Double(currentPlaybackSeconds) / Double(total) * 100.0
        mainViewController?.progressBar.doubleValue = percent
        
        let mm = currentPlaybackSeconds / 60
        let ss = currentPlaybackSeconds % 60
        mainViewController?.currentTimeLabel.stringValue = String(format: "%02d:%02d", mm, ss)
        
        if currentPlaybackSeconds >= total {
            // Track finished, advance to next track
            Task { @MainActor in
                nextTrack(nil)
            }
        }
    }
    
    private func startPlayback() {
        isPlaying = true
        
        // Stop any existing timers
        playbackTimer?.invalidate()
        dispatchTimer?.cancel()
        
        let startDate = Date()
        
        // Create a dispatch timer that runs every second
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        dispatchTimer = timer
        
        timer.schedule(deadline: .now(), repeating: .seconds(1))
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                // Calculate elapsed time based on actual time passed
                let elapsed = Int(Date().timeIntervalSince(startDate))
                self.currentPlaybackSeconds = elapsed
                self.updateProgressDisplay()
                
                // Check if we've reached the end of the track
                if let track = self.tracks[safe: self.currentTrackIndex],
                   let duration = track.durationSeconds,
                   elapsed >= duration {
                    
                    Task {
                        // Move to next track
                        if self.currentTrackIndex < self.tracks.count - 1 {
                            self.currentTrackIndex += 1
                            self.playCurrentTrack(showNotificationOnStart: false)
                        } else {
                            self.stopPlayback()
                        }
                    }
                }
            }
        }
        
        timer.resume()
    }
    
    @MainActor
    private func updateProgressDisplay() {
        guard currentTrackIndex < tracks.count,
              let track = tracks[safe: currentTrackIndex] else { return }
        
        // Get duration, defaulting to current time if not available
        let duration = track.durationSeconds ?? currentPlaybackSeconds
        
        // Update progress bar
        let progress = Double(currentPlaybackSeconds) / Double(duration) * 100
        mainViewController?.progressBar.doubleValue = progress
        
        // Update time labels
        let currentMM = currentPlaybackSeconds / 60
        let currentSS = currentPlaybackSeconds % 60
        mainViewController?.currentTimeLabel.stringValue = String(format: "%d:%02d", currentMM, currentSS)
        
        let totalMM = duration / 60
        let totalSS = duration % 60
        mainViewController?.totalTimeLabel.stringValue = String(format: "%d:%02d", totalMM, totalSS)
        
        // Force window update
        mainViewController?.view.window?.viewsNeedDisplay = true
        mainViewController?.view.window?.displayIfNeeded()
    }
    
    // MARK: - Discogs / Last.fm Stubs
    
    func loadDiscogsRelease(from infoURL: String) async {
        logger.info("🔍 Starting Discogs release load from input: \(infoURL)")
        updateStatusBar("Loading release...")
        
        do {
            let releaseId = try await discogsService.extractReleaseId(from: infoURL)
            logger.info("📝 Extracted release ID: \(releaseId)")
            
            let release = try await discogsService.loadRelease(releaseId)
            logger.info("✅ Successfully loaded release from Discogs")
            
            await MainActor.run {
                processDiscogsRelease(release)
                updateStatusBar("♪")
                
                if !tracks.isEmpty {
                    currentTrackIndex = 0
                    isPlaying = false
                    stopPlayback()
                    
                    // Update UI if window is visible
                    if mainViewController?.isPlayerWindowVisible == true {
                        mainViewController?.refreshUI()
                    }
                    
                    // Load artwork
                    Task {
                        await loadAlbumArtwork()
                    }
                    
                    // Update tracks menu
                    updateTracksMenu()
                }
            }
        } catch {
            logger.error("❌ Failed to load album: \(error.localizedDescription)")
            updateStatusBar("Error loading album")
            showAlert(title: "Error", message: error.localizedDescription)
        }
    }
    
    private func processDiscogsRelease(_ release: DiscogsRelease) {
        logger.info("🎼 Processing Discogs release: \(release.title)")
        
        // Clear existing tracks
        self.tracks.removeAll()
        
        // Process tracks
        for track in release.tracklist {
            // Set initial duration from Discogs, or use "3:00" as default
            let initialDuration = track.duration?.isEmpty ?? true ? "3:00" : track.duration
            let newTrack = Track(
                position: track.position,
                title: track.title,
                duration: initialDuration,
                artist: release.artists.first?.name ?? "",
                album: release.title
            )
            self.tracks.append(newTrack)
            
            let isDefaultDuration = initialDuration == "3:00"
            logger.debug("""
                Added track:
                - Position: \(newTrack.position)
                - Title: \(newTrack.title)
                - Duration: \(newTrack.duration ?? "3:00")\(isDefaultDuration ? " (default)" : "")
                - Artist: \(newTrack.artist)
                """)
        }
        
        logger.info("✅ Processed \(self.tracks.count) tracks from release")
        
        // Update tracks menu
        updateTracksMenu()
        mainViewController?.reloadTrackList()
        
        // Try to get Last.fm info
        if let artist = release.artists.first?.name {
            Task { [weak self] in
                do {
                    guard let self = self else { return }
                    let albumInfo = try await self.lastFMService.getAlbumInfo(
                        artist: artist,
                        album: release.title
                    )
                    
                    await MainActor.run { [weak self] in
                        guard let self = self else { return }
                        // Update track durations from Last.fm if available
                        for (index, track) in albumInfo.tracks.enumerated() where index < self.tracks.count {
                            // Only update if we're using the default duration
                            if self.tracks[index].duration == "3:00" {
                                self.tracks[index].duration = track.duration
                                logger.debug("Updated duration for track '\(self.tracks[index].title)' to \(self.tracks[index].duration ?? "nil")")
                            }
                        }
                        self.updateTrackDisplay()
                    }
                } catch {
                    self?.logger.error("Failed to get Last.fm info: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Notifications
    
    private func showNotification(for track: Track, with image: NSImage?) {
        let content = UNMutableNotificationContent()
        content.title = track.title
        content.subtitle = "\(track.artist) - \(track.album)"
        
        Task.detached {
            // Process image in background
            if let image = image,
               let tiffData = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("png")
                
                do {
                    try pngData.write(to: tempURL)
                    if let attachment = try? UNNotificationAttachment(identifier: "albumArt",
                                                                    url: tempURL,
                                                                    options: nil) {
                        await MainActor.run {
                            content.attachments = [attachment]
                        }
                    }
                } catch {
                    self.logger.error("Failed to save notification image: \(error.localizedDescription)")
                }
            }
            
            // Show notification on main thread
            await MainActor.run {
                let request = UNNotificationRequest(identifier: UUID().uuidString,
                                                  content: content,
                                                  trigger: nil)
                
                UNUserNotificationCenter.current().add(request) { error in
                    if let error = error {
                        self.logger.error("Failed to show notification: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    func showNotification(title: String, body: String) {
        guard showNotifications else { return }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = nil
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error = error {
                self?.logger.error("Failed to show notification: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - UI Helpers
    
    func makeLabel(frame: NSRect, fontSize: CGFloat, isBold: Bool = false) -> NSTextField {
        let label = NSTextField(frame: frame)
        label.isBezeled = false
        label.isEditable = false
        label.isSelectable = false
        label.drawsBackground = false
        label.font = isBold ? NSFont.boldSystemFont(ofSize: fontSize) : NSFont.systemFont(ofSize: fontSize)
        return label
    }
    
    func updateStatusIcon() {
        statusItem.button?.title = isPlaying ? "▶" : "♪"
    }
    
    func updateNotificationMenuItem() {
        if let notifItem = mainMenu.item(withTitle: "Toggle Notifications (On)") {
            notifItem.title = showNotifications ? "Toggle Notifications (On)" : "Toggle Notifications (Off)"
        }
    }
    
    func updateMenuItemsForWindowState() {
        logger.info("🔄 Updating menu items")
        if let playerMenuItem = mainMenu.items.first(where: { $0.action == #selector(togglePlayerWindow(_:)) }) {
            playerMenuItem.title = mainViewController?.isPlayerWindowVisible == true ? "Hide Player" : "Open Player"
        }
    }
    
    func updateStatusBar(_ text: String) {
        statusItem.button?.title = text
    }
    
    func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, error in
            guard let self = self else { return }
            if granted {
                self.logger.info("Notification permissions granted")
                self.showNotifications = true
            } else {
                self.logger.warning("Notification permissions denied")
                self.showNotifications = false
            }
            
            if let error = error {
                self.logger.error("Error requesting notification permissions: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Playback Controls
    
    @IBAction public func previousTrack(_ sender: Any?) {
        Task { @MainActor in
            guard currentTrackIndex > 0 else { return }
            currentTrackIndex -= 1
            playCurrentTrack()
            updateControlState()
        }
    }
    
    @IBAction public func nextTrack(_ sender: Any?) {
        Task { @MainActor in
            guard currentTrackIndex < tracks.count - 1 else { return }
            currentTrackIndex += 1
            playCurrentTrack()
            updateControlState()
        }
    }
    
    @MainActor
    public func updateControlState() {
        Task { @MainActor in
            updatePlaybackDisplay()
            updateTrackDisplay()
        }
    }
    
    @MainActor
    private func updatePlaybackDisplay() {
        guard currentTrackIndex < tracks.count,
              let track = tracks[safe: currentTrackIndex] else { return }
        
        // Update time labels
        let currentMM = currentPlaybackSeconds / 60
        let currentSS = currentPlaybackSeconds % 60
        mainViewController?.currentTimeLabel.stringValue = String(format: "%d:%02d", currentMM, currentSS)
        
        if let duration = track.durationSeconds {
            let totalMM = duration / 60
            let totalSS = duration % 60
            mainViewController?.totalTimeLabel.stringValue = String(format: "%d:%02d", totalMM, totalSS)
            
            // Update progress bar
            let progress = Double(currentPlaybackSeconds) / Double(duration) * 100
            mainViewController?.progressBar.doubleValue = progress
        } else {
            mainViewController?.totalTimeLabel.stringValue = "--:--"
            mainViewController?.progressBar.doubleValue = 0
        }
    }
    
    @MainActor
    private func updateTrackDisplay() {
        guard currentTrackIndex < tracks.count else { return }
        let track = tracks[currentTrackIndex]
        
        // Update view controller
        mainViewController?.trackTitleLabel.stringValue = track.title
        mainViewController?.albumTitleLabel.stringValue = track.album
        mainViewController?.artistLabel.stringValue = track.artist
        
        // Update window title
        mainViewController?.view.window?.title = "\(track.title) - \(track.artist)"
        
        // Reset progress display
        currentPlaybackSeconds = 0
        updatePlaybackDisplay()
        
        // Reload table to update current track indicator
        mainViewController?.reloadTrackList()
    }
    
    @MainActor
    private func nextTrack() {
        guard !tracks.isEmpty else { return }
        currentTrackIndex += 1
        if currentTrackIndex >= tracks.count {
            currentTrackIndex = tracks.count - 1
        }
        if isPlaying {
            playCurrentTrack()
        } else {
            updateTrackDisplay()
        }
    }
    
    @MainActor
    private func previousTrack() {
        guard !tracks.isEmpty else { return }
        currentTrackIndex -= 1
        if currentTrackIndex < 0 {
            currentTrackIndex = 0
        }
        if isPlaying {
            playCurrentTrack()
        } else {
            updateTrackDisplay()
        }
    }
    
    func loadAlbumArtwork() async {
        if let firstTrack = tracks.first {
            do {
                logger.info("🖼 Loading album artwork for '\(firstTrack.album)' by \(firstTrack.artist)")
                let albumInfo = try await lastFMService.getAlbumInfo(
                    artist: firstTrack.artist,
                    album: firstTrack.album
                )
                
                // Try to get artwork from the album info
                if let images = albumInfo.images,
                   let artworkURL = images.first(where: { $0.size == "extralarge" })?.url.isEmpty == false ?
                        URL(string: images.first(where: { $0.size == "extralarge" })!.url) :
                        images.first(where: { $0.size == "large" })?.url.isEmpty == false ?
                        URL(string: images.first(where: { $0.size == "large" })!.url) :
                        URL(string: images.first(where: { $0.size == "medium" })!.url) {
                    
                    logger.debug("Found artwork URL: \(artworkURL)")
                    
                    do {
                        let (imageData, _) = try await URLSession.shared.data(from: artworkURL)
                        if let image = NSImage(data: imageData) {
                            await MainActor.run {
                                self.mainViewController?.albumArtworkView.image = image
                                logger.info("✅ Successfully loaded album artwork")
                            }
                        }
                    } catch {
                        logger.error("❌ Failed to load artwork image: \(error.localizedDescription)")
                    }
                } else {
                    logger.warning("⚠️ No artwork found for album")
                }
            } catch {
                logger.error("❌ Failed to load album artwork: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Menu Updates
    
    private func updateTracksMenu() {
        guard let tracksItem = mainMenu.item(withTitle: "Tracks"),
              let tracksMenu = tracksItem.submenu else {
            return
        }
        
        // Clear existing items
        tracksMenu.removeAllItems()
        
        // Add new track items
        for (index, track) in tracks.enumerated() {
            let title = "\(track.position). \(track.title)"
            let item = NSMenuItem(
                title: title,
                action: #selector(trackSelected(_:)),
                keyEquivalent: ""
            )
            item.tag = index  // Store track index in tag
            tracksMenu.addItem(item)
        }
        
        // Update enabled state
        tracksItem.isEnabled = !tracks.isEmpty
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
    
    private func shouldScrobble(track: Track, playedDuration: Int) -> Bool {
        guard let totalDuration = track.durationSeconds else { return false }
        
        // Rule 1: Track must be longer than 30 seconds
        if totalDuration <= 30 {
            logger.info("⏭️ Track '\(track.title)' is too short (\(totalDuration) seconds) to scrobble")
            return false
        }
        
        // Rule 2: Must play either half the track OR 4 minutes (240 seconds), whichever comes first
        let minimumRequiredDuration = min(totalDuration / 2, 240)
        
        return playedDuration >= minimumRequiredDuration
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Show window when clicking dock icon (if it somehow appears)
        mainViewController?.showPlayerWindow()
        return true
    }
    
    @MainActor
    private func checkLastFMAuth() async {
        if let sessionKey = lastFMService.getStoredSessionKey() {
            // We have a stored session key, use it
            lastFMService.setSessionKey(sessionKey)
            logger.info("✅ Loaded stored Last.fm session key")
            updateLastFmMenuItems()
            enableMenuItems(true)  // Enable menu items since we're logged in
        } else {
            // No stored session - just update menu items, don't show login
            updateLastFmMenuItems()
            enableMenuItems(false)
        }
    }
    
    private func showLastFMLogin() async {
        await MainActor.run {
            // If there's an existing window, just show it
            if let existingWindow = self.authWindow {
                existingWindow.makeKeyAndOrderFront(nil)
                return
            }
            
            // Create the auth window
            let authVC = AuthViewController(lastFMService: self.lastFMService) { [weak self] in
                // Success callback
                self?.updateLastFmMenuItems()
                self?.enableMenuItems(true)
            }
            
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            
            // Configure window
            window.contentViewController = authVC
            window.title = "Last.fm Login"
            window.center()
            
            // Store strong references
            self.authWindow = window
            
            // Show window
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    private func cleanup() {
        Task { @MainActor in
            // Clean up auth window
            authWindow = nil
            _authViewController = nil
            
            // Clean up main window
            mainWindow = nil
            _mainViewController = nil
        }
    }
    
    deinit {
        // Since we can't make deinit async, we'll use a synchronous approach
        if Thread.isMainThread {
            authWindow = nil
            _authViewController = nil
            mainWindow = nil
            _mainViewController = nil
        } else {
            DispatchQueue.main.sync {
                self.authWindow = nil
                self._authViewController = nil
                self.mainWindow = nil
                self._mainViewController = nil
            }
        }
    }
    
    func enableMenuItems(_ enabled: Bool) {
        for item in mainMenu.items {
            switch item.title {
            case "Last.fm Account", "About", "Quit", "Open Player":
                item.isEnabled = true  // These are always enabled
            case "Tracks":
                // Disable tracks submenu and all its items
                item.isEnabled = enabled
                if let submenu = item.submenu {
                    submenu.items.forEach { $0.isEnabled = enabled }
                }
            default:
                item.isEnabled = enabled
                
                // Also disable their submenus if they have any
                if let submenu = item.submenu {
                    submenu.items.forEach { subItem in
                        if !["Last.fm Account", "About", "Quit", "Open Player"].contains(subItem.title) {
                            subItem.isEnabled = enabled
                        }
                    }
                }
            }
        }
        
        // Specifically handle the status menu items
        if let loadAlbumItem = mainMenu.item(withTitle: "Load Album") {
            loadAlbumItem.isEnabled = enabled
        }
        if let previousTrackItem = mainMenu.item(withTitle: "Previous Track") {
            previousTrackItem.isEnabled = enabled
        }
        if let playPauseItem = mainMenu.item(withTitle: "Play/Pause") {
            playPauseItem.isEnabled = enabled
        }
        if let nextTrackItem = mainMenu.item(withTitle: "Next Track") {
            nextTrackItem.isEnabled = enabled
        }
        if let playerItem = mainMenu.item(withTitle: "Open Player") {
            playerItem.isEnabled = enabled
        }
        if let notificationsItem = mainMenu.item(withTitle: "Toggle Notifications (On)") {
            notificationsItem.isEnabled = enabled
        }
    }
    
    private func checkLastFMAuthAndShowAlert() -> Bool {
        if LastFMService.shared.getStoredSessionKey() == nil {
            let alert = NSAlert()
            alert.messageText = "Last.fm Authentication Required"
            alert.informativeText = "Please sign in to Last.fm to use this feature."
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return false
        }
        return true
    }
    
    @MainActor
    private func showDiscogsSearch() async {
        let alert = NSAlert()
        alert.messageText = "Search Discogs"
        alert.informativeText = "Enter an artist, album or both to search"
        alert.addButton(withTitle: "Search")
        alert.addButton(withTitle: "Cancel")
        
        let searchField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        alert.accessoryView = searchField
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return }
            
            await performSearch(query, page: 1)
        }
    }
    
    @MainActor
    private func showSearchResults(_ results: [DiscogsSearchResponse.SearchResult], 
                                 pagination: DiscogsSearchResponse.Pagination, 
                                 query: String) {
        if let existingController = searchWindowController {
            // Update existing window
            existingController.updateResults(results, pagination: pagination, query: query)
        } else {
            // Create new window controller
            let controller = SearchWindowController(
                results: results,
                pagination: pagination,
                query: query,
                onSelect: { [weak self] selectedResult in
                    Task { @MainActor in
                        if let self = self {
                            await self.loadDiscogsRelease(from: String(selectedResult.id))
                        }
                    }
                },
                onClose: { [weak self] in
                    self?.searchWindowController = nil
                }
            )
            
            searchWindowController = controller
            controller.window?.center()
            controller.showWindow(nil)
        }
    }
    
    private class SearchResultsDataSource: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        let results: [DiscogsSearchResponse.SearchResult]
        let selectionCallback: (DiscogsSearchResponse.SearchResult) -> Void
        
        // Store a reference to the table view
        private weak var tableView: NSTableView?
        
        init(results: [DiscogsSearchResponse.SearchResult], 
             selectionCallback: @escaping (DiscogsSearchResponse.SearchResult) -> Void) {
            self.results = results
            self.selectionCallback = selectionCallback
            super.init()
        }
        
        func numberOfRows(in tableView: NSTableView) -> Int {
            return results.count
        }
        
        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            // Store reference to table view
            self.tableView = tableView
            
            let result = results[row]
            
            switch tableColumn?.identifier.rawValue {
            case "action":
                let cell = NSTableCellView()
                
                // Create button with a more explicit tag
                let button = NSButton(image: NSImage(systemSymbolName: "plus.circle.fill", accessibilityDescription: "Add")!, 
                                    target: self, 
                                    action: #selector(addButtonClicked(_:)))
                
                // Store the release ID directly in the button's identifier
                button.identifier = NSUserInterfaceItemIdentifier(String(result.id))
                button.tag = row  // Keep row for reference
                
                button.bezelStyle = .circular
                button.isBordered = false
                button.translatesAutoresizingMaskIntoConstraints = false
                cell.addSubview(button)
                
                NSLayoutConstraint.activate([
                    button.centerXAnchor.constraint(equalTo: cell.centerXAnchor),
                    button.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                    button.widthAnchor.constraint(equalToConstant: 20),
                    button.heightAnchor.constraint(equalToConstant: 20)
                ])
                
                return cell
                
            case "title":
                let cell = NSTableCellView()
                let text = NSTextField(labelWithString: result.title)
                text.translatesAutoresizingMaskIntoConstraints = false
                cell.addSubview(text)
                
                NSLayoutConstraint.activate([
                    text.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                    text.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                    text.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
                ])
                
                return cell
                
            case "year":
                let cell = NSTableCellView()
                let text = NSTextField(labelWithString: result.year ?? "N/A")
                text.translatesAutoresizingMaskIntoConstraints = false
                cell.addSubview(text)
                
                NSLayoutConstraint.activate([
                    text.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                    text.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                    text.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
                ])
                
                return cell
                
            case "format":
                let cell = NSTableCellView()
                let text = NSTextField(labelWithString: result.format?.joined(separator: ", ") ?? "N/A")
                text.translatesAutoresizingMaskIntoConstraints = false
                cell.addSubview(text)
                
                NSLayoutConstraint.activate([
                    text.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                    text.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                    text.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
                ])
                
                return cell
                
            default:
                return nil
            }
        }
        
        // Instead of using a gesture recognizer, use the built-in double click support
        func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
            return false  // Disable row selection
        }
        
        func tableViewSelectionDidChange(_ notification: Notification) {
            // Do nothing on single click
        }
        
        // Handle double click using the standard method
        @MainActor
        func tableView(_ tableView: NSTableView, rowActionsForRow row: Int, edge: NSTableView.RowActionEdge) -> [NSTableViewRowAction] {
            return []
        }
        
        @MainActor
        func tableView(_ tableView: NSTableView, didClick tableColumn: NSTableColumn) {
            // Handle single click if needed
        }
        
        @MainActor
        func tableView(_ tableView: NSTableView, mouseDownInHeaderOf tableColumn: NSTableColumn) {
            // Handle header click if needed
        }
        
        @MainActor
        func tableView(_ tableView: NSTableView, didDoubleClickRow row: Int) {
            guard row < results.count else { return }
            let selectedResult = results[row]
            selectionCallback(selectedResult)
        }
        
        @MainActor
        @objc private func addButtonClicked(_ sender: NSButton) {
            Task { @MainActor in
                // Use the stored release ID instead of calculating from row
                if let releaseId = sender.identifier?.rawValue {
                    selectionCallback(results[sender.tag])
                    
                    // Log for debugging
                    print("Selected release ID: \(releaseId) from row \(sender.tag)")
                    print("Result details: \(results[sender.tag])")
                }
            }
        }
    }
    
    private struct AssociatedKeys {
        static var paginationState: UInt8 = 0
        static var dataSource: UInt8 = 1
    }
    
    private class PaginationState {
        let currentPage: Int
        let totalPages: Int
        let query: String
        weak var window: NSWindow?
        weak var pageLabel: NSTextField?
        
        init(currentPage: Int, totalPages: Int, query: String, window: NSWindow, pageLabel: NSTextField) {
            self.currentPage = currentPage
            self.totalPages = totalPages
            self.query = query
            self.window = window
            self.pageLabel = pageLabel
        }
    }
    
    @objc private func previousPage(_ sender: NSButton) {
        guard let window = sender.window,
              let state = objc_getAssociatedObject(window, &AssociatedKeys.paginationState) as? PaginationState,
              state.currentPage > 1 else { return }
        
        Task {
            await performSearch(state.query, page: state.currentPage - 1)
        }
    }
    
    @objc private func nextPage(_ sender: NSButton) {
        guard let window = sender.window,
              let state = objc_getAssociatedObject(window, &AssociatedKeys.paginationState) as? PaginationState,
              state.currentPage < state.totalPages else { return }
        
        Task {
            await performSearch(state.query, page: state.currentPage + 1)
        }
    }
    
    private func performSearch(_ query: String, page: Int) async {
        do {
            updateStatusBar("Searching...")
            let searchResults = try await discogsService.searchReleases(query, page: page)
            
            if searchResults.results.isEmpty {
                showAlert(title: "No Results", message: "No releases found matching your search.")
                updateStatusBar("♪")
                return
            }
            
            // Update existing window or create new one
            if let existingWindow = NSApp.windows.first(where: { 
                objc_getAssociatedObject($0, &AssociatedKeys.paginationState) != nil 
            }) {
                updateSearchResults(existingWindow, results: searchResults.results, 
                                  pagination: searchResults.pagination, query: query)
            } else {
                showSearchResults(searchResults.results, pagination: searchResults.pagination, query: query)
            }
            
        } catch {
            showAlert(title: "Search Failed", message: error.localizedDescription)
            updateStatusBar("♪")
        }
    }
    
    @MainActor
    private func updateSearchResults(_ window: NSWindow, results: [DiscogsSearchResponse.SearchResult], 
                                   pagination: DiscogsSearchResponse.Pagination, query: String) {
        // Update table view - Fix view hierarchy access
        if let containerView = window.contentView?.subviews.first,
           let scrollView = containerView.subviews.first(where: { $0 is NSScrollView }) as? NSScrollView,
           let tableView = scrollView.documentView as? NSTableView {
            
            // Update data source
            let dataSource = SearchResultsDataSource(results: results) { [weak self] selectedResult in
                Task { @MainActor in
                    if let self = self {
                        await self.loadDiscogsRelease(from: String(selectedResult.id))
                    }
                }
            }
            
            // Store strong reference to data source
            self.currentSearchDataSource = dataSource
            
            tableView.dataSource = dataSource
            tableView.delegate = dataSource
            tableView.reloadData()
        }
        
        // Update pagination controls - Fix view hierarchy access
        if let containerView = window.contentView?.subviews.first,
           let paginationView = containerView.subviews.last,
           let state = objc_getAssociatedObject(window, &AssociatedKeys.paginationState) as? PaginationState,
           let pageLabel = state.pageLabel {
            
            pageLabel.stringValue = "Page \(pagination.page) of \(pagination.pages)"
            
            // Update pagination buttons
            let buttons = paginationView.subviews.compactMap { $0 as? NSButton }
            let previousButton = buttons.first { $0.title == "Previous" }
            let nextButton = buttons.first { $0.title == "Next" }
            
            previousButton?.isEnabled = pagination.page > 1
            nextButton?.isEnabled = pagination.page < pagination.pages
            
            // Store updated pagination state
            let newState = PaginationState(
                currentPage: pagination.page,
                totalPages: pagination.pages,
                query: query,
                window: window,
                pageLabel: pageLabel
            )
            objc_setAssociatedObject(window, &AssociatedKeys.paginationState, newState, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    // Add handlers
    @objc private func handlePreviousPage() {
        if let state = searchWindowController?.currentState,
           state.currentPage > 1 {  // Only proceed if we're not on the first page
            Task {
                await performSearch(state.query, page: state.currentPage - 1)
            }
        }
    }
    
    @objc private func handleNextPage() {
        if let state = searchWindowController?.currentState,
           state.currentPage < state.totalPages {  // Only proceed if we're not on the last page
            Task {
                await performSearch(state.query, page: state.currentPage + 1)
            }
        }
    }
}
