import Cocoa
import Foundation
import OSLog
import UserNotifications
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: "com.vinyl.scrobbler", category: "AppDelegate")
    var statusItem: NSStatusItem!
    var mainMenu: NSMenu!
    let appState = AppState()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("Application launching...")
        
        // Setup menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "♪"
        
        mainMenu = NSMenu()
        
        // Load Album
        mainMenu.addItem(withTitle: "Load Album", action: #selector(loadAlbumClicked), keyEquivalent: "")
        mainMenu.addItem(NSMenuItem.separator())
        
        // Playback Controls
        mainMenu.addItem(withTitle: "Previous Track", action: #selector(previousTrack), keyEquivalent: "")
        mainMenu.addItem(withTitle: "Play/Pause", action: #selector(togglePlayPause), keyEquivalent: "")
        mainMenu.addItem(withTitle: "Next Track", action: #selector(nextTrack), keyEquivalent: "")
        mainMenu.addItem(NSMenuItem.separator())
        
        // Window controls
        mainMenu.addItem(withTitle: "Show Window", action: #selector(showWindow), keyEquivalent: "")
        mainMenu.addItem(withTitle: "Settings", action: #selector(showSettings), keyEquivalent: ",")
        mainMenu.addItem(NSMenuItem.separator())
        
        // Last.fm controls
        let lastFMMenuItem = NSMenuItem(title: "Last.fm", action: nil, keyEquivalent: "")
        let lastFMSubmenu = NSMenu()
        lastFMSubmenu.addItem(withTitle: "Sign In", action: #selector(showLastFMAuth), keyEquivalent: "")
        lastFMSubmenu.addItem(withTitle: "Sign Out", action: #selector(signOutLastFM), keyEquivalent: "")
        lastFMMenuItem.submenu = lastFMSubmenu
        mainMenu.addItem(lastFMMenuItem)
        mainMenu.addItem(NSMenuItem.separator())
        
        // About and Quit
        mainMenu.addItem(withTitle: "About", action: #selector(showAbout), keyEquivalent: "")
        mainMenu.addItem(NSMenuItem.separator())
        mainMenu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        
        statusItem.menu = mainMenu
        
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                self.logger.error("Notification permission error: \(error.localizedDescription)")
            }
        }
        
        logger.info("Application launched successfully")
    }
    
    @objc func showWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        if let window = NSApplication.shared.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    @objc func loadAlbumClicked() {
        appState.showDiscogsSearch = true
        showWindow()
    }
    
    @objc func previousTrack() {
        appState.previousTrack()
    }
    
    @objc func togglePlayPause() {
        appState.togglePlayPause()
        updateStatusIcon()
    }
    
    @objc func nextTrack() {
        appState.nextTrack()
    }
    
    @objc func showSettings() {
        appState.showSettings = true
        showWindow()
    }
    
    @objc func showAbout() {
        appState.showAbout = true
        showWindow()
    }
    
    @objc func showLastFMAuth() {
        appState.showLastFMAuth = true
        showWindow()
    }
    
    @objc func signOutLastFM() {
        LastFMService.shared.clearSession()
        appState.isAuthenticated = false
        appState.showLastFMAuth = true
    }
    
    private func updateStatusIcon() {
        statusItem.button?.title = appState.isPlaying ? "▶" : "♪"
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    private func updateStatusBar(_ text: String) {
        statusItem.button?.title = text
    }
    
    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
    
    func loadDiscogsRelease(from infoURL: String) async {
        logger.info("🔍 Starting Discogs release load from input: \(infoURL)")
        updateStatusBar("Loading release...")
        
        do {
            let releaseId = try await DiscogsService.shared.extractReleaseId(from: infoURL)
            logger.info("📝 Extracted release ID: \(releaseId)")
            
            let release = try await DiscogsService.shared.loadRelease(releaseId)
            logger.info("✅ Successfully loaded release from Discogs")
            
            // Update app state with the new release
            await MainActor.run {
                appState.loadRelease(release)
                updateStatusBar("♪")
                
                // Close the search dialog
                appState.showDiscogsSearch = false
                
                // Show the main window if it's not visible
                showWindow()
            }
        } catch {
            logger.error("❌ Failed to load album: \(error.localizedDescription)")
            updateStatusBar("Error loading album")
            showAlert(title: "Error", message: error.localizedDescription)
        }
    }
}
