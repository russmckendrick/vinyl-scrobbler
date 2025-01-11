import SwiftUI

@main
struct VinylScrobblerApp: App {
    @StateObject private var appState = AppState()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 500, minHeight: 700)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Vinyl Scrobbler") {
                    appState.showAbout = true
                }
            }
            
            CommandGroup(replacing: .newItem) {
                Button("Load Album") {
                    appState.showDiscogsSearch = true
                }
                .keyboardShortcut("l", modifiers: .command)
            }
            
            CommandMenu("Playback") {
                Button("Play/Pause") {
                    appState.togglePlayPause()
                }
                .keyboardShortcut("p", modifiers: .command)
                
                Button("Previous Track") {
                    appState.previousTrack()
                }
                .keyboardShortcut(.leftArrow, modifiers: .command)
                
                Button("Next Track") {
                    appState.nextTrack()
                }
                .keyboardShortcut(.rightArrow, modifiers: .command)
            }
        }
    }
}

// MARK: - NSWindow Extension
extension NSWindow {
    static func createStandardWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.setFrameAutosaveName("Main Window")
        window.isReleasedWhenClosed = false
        window.title = "Vinyl Scrobbler"
        return window
    }
} 