import SwiftUI
import UserNotifications

@main
struct VinylScrobblerApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup(id: "main") {
            MainView()
                .environmentObject(appState)
                .frame(minWidth: 500, minHeight: 700)
        }
        .defaultSize(width: 500, height: 700)
        .windowStyle(.hiddenTitleBar)
        
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
        .keyboardShortcut("l", modifiers: [.command])
        
        Divider()
        
        Button("Previous Track") {
            appState.previousTrack()
        }
        .keyboardShortcut(.leftArrow, modifiers: [.command])
        
        Button("Play/Pause") {
            appState.togglePlayPause()
        }
        .keyboardShortcut(.space, modifiers: [.command])
        
        Button("Next Track") {
            appState.nextTrack()
        }
        .keyboardShortcut(.rightArrow, modifiers: [.command])
        
        Divider()
        
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
        .keyboardShortcut(",", modifiers: [.command])
        
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
        
        Button("Show Player") {
            print("🎵 Show Player clicked - Window visible: \(appState.windowVisible)")
            if !appState.windowVisible {
                print("📱 Opening main window")
                openWindow(id: "main")
            }
        }
        .keyboardShortcut("p", modifiers: [.command, .shift])
        
        Divider()
        
        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: [.command])
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