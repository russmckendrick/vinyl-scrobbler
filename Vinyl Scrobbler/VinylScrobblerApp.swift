import SwiftUI
import UserNotifications

@main
struct VinylScrobblerApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 500, minHeight: 700)
        }
        .defaultSize(width: 500, height: 700)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandMenu("Window") {
                Button("Show Player") {
                    NSApp.activate(ignoringOtherApps: true)
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            }
            
            CommandMenu("Playback") {
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
            }
        }
        
        MenuBarExtra {
            Button("Load Album") {
                appState.showDiscogsSearch = true
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
                appState.showSettings = true
            }
            .keyboardShortcut(",", modifiers: [.command])
            
            Divider()
            
            Button("About") {
                appState.showAbout = true
            }
            
            Divider()
            
            Button("Show Player") { }
            .keyboardShortcut("p", modifiers: [.command, .shift])
            
            Divider()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: [.command])
        } label: {
            Image(systemName: "opticaldisc")
                .symbolRenderingMode(.hierarchical)
                .help("Vinyl Scrobbler")
        }
    }
} 