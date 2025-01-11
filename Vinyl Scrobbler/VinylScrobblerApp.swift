import SwiftUI
import AppKit

@main
struct VinylScrobblerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    
    init() {
        // Ensure the app appears in dock
        NSApplication.shared.setActivationPolicy(.regular)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appDelegate.appState)
                .frame(minWidth: 500, minHeight: 700)
                .onAppear {
                    NSWindow.allowsAutomaticWindowTabbing = false
                    if let window = NSApplication.shared.windows.first {
                        window.makeKeyAndOrderFront(nil)
                    }
                }
        }
    }
} 