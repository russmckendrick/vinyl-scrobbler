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
        // Create and show settings window
        let settingsView = SettingsView()
            .environmentObject(appState)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.contentView = NSHostingView(rootView: settingsView)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func showAbout() {
        appState.showAbout = true
        showWindow()
    }
    
    private func updateStatusIcon() {
        statusItem.button?.title = appState.isPlaying ? "▶" : "♪"
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
