import Cocoa
import Foundation
import OSLog
import UserNotifications
import SwiftUI

// MARK: - Array Extension
// Adds safe array access to prevent index out of bounds errors
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

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
    private let appState = AppState()
    
    // Notification preferences
    var showNotifications: Bool = true
    
    // MARK: - Services
    // Service instances for Discogs and Last.fm
    private let discogsService = DiscogsService.shared
    private var lastFMService: LastFMService {
        LastFMService.shared
    }
    
    // MARK: - App Lifecycle
    
    @MainActor
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)
        
        // Create the main window
        mainWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        mainWindow?.title = "Vinyl Scrobbler"
        mainWindow?.center()
        mainWindow?.setFrameAutosaveName("Main Window")
        mainWindow?.isReleasedWhenClosed = false
        
        // Set the SwiftUI view as the window's content view
        let contentView = ContentView()
            .environmentObject(appState)
        mainWindow?.contentView = NSHostingView(rootView: contentView)
        
        // Setup menu bar
        createStatusItem()
        
        // Start with everything disabled
        enableMenuItems(false)
        
        // Request notification permissions
        requestNotificationPermissions()
        
        // Check for Last.fm authentication
        Task {
            if let sessionKey = LastFMService.shared.getStoredSessionKey() {
                LastFMService.shared.setSessionKey(sessionKey)
                logger.info("✅ Loaded stored Last.fm session key")
                updateLastFmMenuItems()
                enableMenuItems(true)
            } else {
                updateLastFmMenuItems()
                enableMenuItems(false)
            }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // No need for cleanup since AppState handles timers
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
        if let lastFmMenu = mainMenu.items.first(where: { $0.title == "Last.fm Account" })?.submenu {
            lastFmMenu.removeAllItems()
            
            if LastFMService.shared.getStoredSessionKey() != nil {
                lastFmMenu.addItem(withTitle: "Sign Out", action: #selector(signOutLastFM), keyEquivalent: "")
            } else {
                lastFmMenu.addItem(withTitle: "Sign In", action: #selector(showLastFMAuth), keyEquivalent: "")
            }
        }
    }
    
    @objc private func showLastFMAuth() {
        appState.showLastFMAuth = true
    }
    
    @objc private func signOutLastFM() {
        LastFMService.shared.clearSession()
        updateLastFmMenuItems()
        enableMenuItems(false)
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
            
            switch response {
            case .alertFirstButtonReturn:
                appState.showDiscogsSearch = true
            case .alertSecondButtonReturn:
                showManualAlbumEntry()
            default:
                break
            }
        }
    }
    
    private func showManualAlbumEntry() {
        let alert = NSAlert()
        alert.messageText = "Enter Discogs Release URL or ID"
        alert.addButton(withTitle: "Load")
        alert.addButton(withTitle: "Cancel")
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        alert.accessoryView = textField
        
        if alert.runModal() == .alertFirstButtonReturn {
            let input = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !input.isEmpty else { return }
            
            Task {
                await loadDiscogsRelease(from: input)
            }
        }
    }
    
    // MARK: - Menu Actions
    
    @objc func searchAlbumAction(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = "Enter Discogs Release URL or ID"
        alert.addButton(withTitle: "Load")
        alert.addButton(withTitle: "Cancel")
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        alert.accessoryView = textField
        
        if alert.runModal() == .alertFirstButtonReturn {
            let input = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !input.isEmpty else { return }
            
            Task {
                await loadDiscogsRelease(from: input)
            }
        }
    }
    
    @objc func previousTrackMenuAction(_ sender: Any?) {
        if checkLastFMAuthAndShowAlert() {
            appState.previousTrack()
        }
    }
    
    @objc func playPauseMenuAction(_ sender: Any?) {
        if checkLastFMAuthAndShowAlert() {
            appState.togglePlayPause()
            updateStatusIcon()
        }
    }
    
    @objc func nextTrackMenuAction(_ sender: Any?) {
        if checkLastFMAuthAndShowAlert() {
            appState.nextTrack()
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
        guard !appState.tracks.isEmpty else {
            showAlert(title: "Error", message: "Please load an album first.")
            return
        }
        appState.togglePlayPause()
        updateStatusIcon()
    }
    
    @objc func togglePlayerWindow(_ sender: Any?) {
        if let window = mainWindow {
            if window.isVisible {
                window.orderOut(nil)
            } else {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        updateMenuItemsForWindowState()
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
        appState.currentTrackIndex = sender.tag
        appState.currentTrack = appState.tracks[sender.tag]
        if appState.isPlaying {
            appState.togglePlayPause()
        }
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
                
                if !appState.tracks.isEmpty {
                    appState.currentTrackIndex = 0
                    appState.currentTrack = appState.tracks.first
                    appState.isPlaying = false
                    
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
        self.appState.tracks.removeAll()
        
        // Process tracks
        for track in release.tracklist {
            let initialDuration = track.duration?.isEmpty ?? true ? "3:00" : track.duration
            let newTrack = Track(
                position: track.position,
                title: track.title,
                duration: initialDuration,
                artist: release.artists.first?.name ?? "",
                album: release.title
            )
            self.appState.tracks.append(newTrack)
            
            let isDefaultDuration = initialDuration == "3:00"
            logger.debug("""
                Added track:
                - Position: \(newTrack.position)
                - Title: \(newTrack.title)
                - Duration: \(newTrack.duration ?? "3:00")\(isDefaultDuration ? " (default)" : "")
                - Artist: \(newTrack.artist)
                """)
        }
        
        logger.info("✅ Processed \(self.appState.tracks.count) tracks from release")
        
        // Update tracks menu
        updateTracksMenu()
        
        // Try to get Last.fm info
        if let artist = release.artists.first?.name {
            Task { [weak self] in
                guard let self = self else { return }
                do {
                    let albumInfo = try await self.lastFMService.getAlbumInfo(
                        artist: artist,
                        album: release.title
                    )
                    
                    await MainActor.run { [weak self] in
                        guard let self = self else { return }
                        // Update track durations from Last.fm if available
                        for (index, track) in albumInfo.tracks.enumerated() where index < self.appState.tracks.count {
                            // Only update if we're using the default duration
                            if self.appState.tracks[index].duration == "3:00" {
                                self.appState.tracks[index].duration = track.duration
                                self.logger.debug("Updated duration for track '\(self.appState.tracks[index].title)' to \(self.appState.tracks[index].duration ?? "nil")")
                            }
                        }
                    }
                } catch {
                    self.logger.error("Failed to get Last.fm info: \(error.localizedDescription)")
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
        statusItem.button?.title = appState.isPlaying ? "▶" : "♪"
    }
    
    func updateNotificationMenuItem() {
        if let notifItem = mainMenu.item(withTitle: "Toggle Notifications (On)") {
            notifItem.title = showNotifications ? "Toggle Notifications (On)" : "Toggle Notifications (Off)"
        }
    }
    
    func updateMenuItemsForWindowState() {
        if let item = mainMenu.items.first(where: { $0.action == #selector(togglePlayerWindow(_:)) }) {
            item.title = mainWindow?.isVisible == true ? "Hide Player" : "Show Player"
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
    
    func loadAlbumArtwork() async {
        if let firstTrack = appState.tracks.first {
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
                    
                    // Update all tracks with artwork URL
                    for i in 0..<appState.tracks.count {
                        appState.tracks[i].artworkURL = artworkURL
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
        for (index, track) in appState.tracks.enumerated() {
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
        tracksItem.isEnabled = !appState.tracks.isEmpty
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
        // Show main window when clicking dock icon
        if let window = mainWindow {
            window.makeKeyAndOrderFront(nil)
        }
        return true
    }
    
    @MainActor
    private func checkLastFMAuth() async {
        if let sessionKey = lastFMService.getStoredSessionKey() {
            lastFMService.setSessionKey(sessionKey)
            logger.info("✅ Loaded stored Last.fm session key")
            updateLastFmMenuItems()
            enableMenuItems(true)
        } else {
            updateLastFmMenuItems()
            enableMenuItems(false)
        }
    }
    
    private func showLastFMLogin() async {
        await MainActor.run {
            // Show the Last.fm auth sheet
            appState.showLastFMAuth = true
        }
    }
    
    private func cleanup() {
        Task { @MainActor in
            // Clean up main window
            mainWindow = nil
        }
    }
    
    deinit {
        // Since we can't make deinit async, we'll use a synchronous approach
        if Thread.isMainThread {
            mainWindow = nil
        } else {
            DispatchQueue.main.sync {
                self.mainWindow = nil
            }
        }
    }
    
    func enableMenuItems(_ enabled: Bool) {
        // Update menu items based on authentication state
        mainMenu.items.forEach { item in
            switch item.title {
            case "Load Album", "About", "Quit":
                item.isEnabled = true // These are always enabled
            case "Toggle Notifications (On)", "Toggle Notifications (Off)":
                item.isEnabled = true // Notifications toggle always enabled
            default:
                item.isEnabled = enabled
            }
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
}
