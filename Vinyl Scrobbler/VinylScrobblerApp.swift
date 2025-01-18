import SwiftUI
import UserNotifications
import os.log
import AppKit

@main
struct VinylScrobblerApp: App {
    @StateObject private var appState = AppState()
    
    init() {
        // Suppress ViewBridge warnings
        let viewBridgeLogCategory = "com.apple.ViewBridge"
        let subsystem = Bundle.main.bundleIdentifier ?? "com.vinyl.scrobbler"
        let logger = Logger(subsystem: subsystem, category: viewBridgeLogCategory)
        logger.critical("Suppressing ViewBridge warnings")
        setbuf(stdout, nil)
    }
    
    var body: some Scene {
        WindowGroup(id: "main") {
            MainView()
                .environmentObject(appState)
                .frame(minWidth: 500, minHeight: 800)
                .background(.clear)
                .preferredColorScheme(.dark)
                .onAppear {
                    // Configure window appearance after the app is initialized
                    if let darkAqua = NSAppearance(named: .darkAqua) {
                        NSApp.appearance = darkAqua
                    }
                }
        }
        .defaultSize(width: 500, height: 800)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .windowToolbarStyle(.unifiedCompact)
        
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

struct MenuBarView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    
    var body: some View {
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

         Button(appState.windowVisible ? "Hide Player" : "Show Player") {
            print("🎵 \(appState.windowVisible ? "Hide" : "Show") Player clicked")
            if appState.windowVisible {
                dismissWindow(id: "main")
            } else {
                openWindow(id: "main")
            }
        }

        Divider()
        
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
        
        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
    }
}

struct MainView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismissWindow) private var dismissWindow
    
    var body: some View {
        ContentView()
            .frame(minWidth: 500, minHeight: 700)
            .onAppear {
                print("🟢 MainView appeared - Setting window visible")
                appState.windowVisible = true
                // Request notification permissions on first launch
                Task {
                    try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
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
                print("🔴 MainView disappeared - Setting window not visible")
                appState.windowVisible = false
            }
    }
} 
