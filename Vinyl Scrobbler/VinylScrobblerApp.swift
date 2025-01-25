/// VinylScrobblerApp: The main application entry point for Vinyl Scrobbler
/// This file defines the core application structure, including the main window,
/// menu bar integration, and global state management. It handles window visibility,
/// appearance settings, and provides a menu bar extra for quick access to key features.
import SwiftUI
import UserNotifications
import os.log
import AppKit

/// Main application structure implementing the App protocol
@main
struct VinylScrobblerApp: App {
    /// Global application state shared across views
    @StateObject private var appState = AppState()
    
    /// Initializes the application and configures logging
    init() {
        // Configure logging to suppress ViewBridge warnings
        let viewBridgeLogCategory = "com.apple.ViewBridge"
        let subsystem = Bundle.main.bundleIdentifier ?? "com.vinyl.scrobbler"
        let logger = Logger(subsystem: subsystem, category: viewBridgeLogCategory)
        logger.critical("Suppressing ViewBridge warnings")
        setbuf(stdout, nil)
    }
    
    var body: some Scene {
        // Main application window configuration
        WindowGroup(id: "main") {
            MainView()
                .environmentObject(appState)
                .frame(minWidth: 500, minHeight: 800)
                .background(.clear)
                .preferredColorScheme(.dark)
                .onAppear {
                    // Force dark mode appearance for consistency
                    if let darkAqua = NSAppearance(named: .darkAqua) {
                        NSApp.appearance = darkAqua
                    }
                }
        }
        .defaultSize(width: 500, height: 800)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .windowToolbarStyle(.unifiedCompact)
        
        // Menu bar extra configuration for quick access
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
        } label: {
            Image(systemName: "opticaldisc")
                .symbolRenderingMode(.hierarchical)
                .help("Vinyl Scrobbler")
        }
    }
}

/// Menu bar view providing quick access to key application features
struct MenuBarView: View {
    /// Access to global app state
    @EnvironmentObject private var appState: AppState
    /// Environment action for opening windows
    @Environment(\.openWindow) private var openWindow
    /// Environment action for dismissing windows
    @Environment(\.dismissWindow) private var dismissWindow
    
    var body: some View {
        // Album loading functionality
        Button("Load Album") {
            print("🔍 Load Album clicked - Window visible: \(appState.windowVisible)")
            if !appState.windowVisible {
                print("📱 Opening main window for Load Album")
                openWindow(id: "main")
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                print("🎵 Showing Discogs search sheet")
                appState.showDiscogsSearch = true
            }
        }
        
        // Music recognition feature
        Button("Listen") {
            print("🎧 Listen clicked - Window visible: \(appState.windowVisible)")
            if !appState.windowVisible {
                print("📱 Opening main window for Listen")
                openWindow(id: "main")
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                print("🎵 Showing Listen sheet")
                appState.showListen = true
            }
        }

        // Settings access
        Button("Settings") {
            print("⚙️ Settings clicked - Window visible: \(appState.windowVisible)")
            if !appState.windowVisible {
                print("📱 Opening main window for Settings")
                openWindow(id: "main")
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                print("⚙️ Showing Settings sheet")
                appState.showSettings = true
            }
        }

        // Player visibility toggle
         Button(appState.windowVisible ? "Hide Player" : "Show Player") {
            print("🎵 \(appState.windowVisible ? "Hide" : "Show") Player clicked")
            if appState.windowVisible {
                dismissWindow(id: "main")
            } else {
                openWindow(id: "main")
            }
        }

        Divider()
        
        // About dialog access
        Button("About") {
            print("ℹ️ About clicked - Window visible: \(appState.windowVisible)")
            if !appState.windowVisible {
                print("📱 Opening main window for About")
                openWindow(id: "main")
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                print("ℹ️ Showing About sheet")
                appState.showAbout = true
            }
        }
        
        Divider()
        
        // Application termination
        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
    }
}

/// Main window content view managing window visibility and notifications
struct MainView: View {
    /// Access to global app state
    @EnvironmentObject private var appState: AppState
    /// Current scene phase for window state management
    @Environment(\.scenePhase) private var scenePhase
    /// Environment action for dismissing windows
    @Environment(\.dismissWindow) private var dismissWindow
    
    var body: some View {
        ContentView()
            .frame(minWidth: 500, minHeight: 700)
            .onAppear {
                // Initialize window state and request notifications
                print("🟢 MainView appeared - Setting window visible")
                appState.windowVisible = true
                // Request notification permissions on first launch
                Task {
                    try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                // Handle window visibility based on scene phase changes
                print("🔄 Scene phase changed: \(oldPhase) -> \(newPhase)")
                switch newPhase {
                case .background:
                    print("⬇️ Window went to background - Setting not visible")
                    appState.windowVisible = false
                case .active:
                    print("⬆️ Window became active - Setting visible")
                    appState.windowVisible = true
                default:
                    print("➡️ Other scene phase: \(newPhase)")
                    break
                }
            }
            .onDisappear {
                // Update visibility state when window is closed
                print("🔴 MainView disappeared - Setting window not visible")
                appState.windowVisible = false
            }
    }
}
