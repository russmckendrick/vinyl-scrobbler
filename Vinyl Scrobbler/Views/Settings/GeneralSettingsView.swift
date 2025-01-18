import SwiftUI

struct GeneralSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var useSystemTheme: Bool = true
    
    var body: some View {
        Form {
            Section("Notifications") {
                Toggle(isOn: $appState.showNotifications) {
                    VStack(alignment: .leading) {
                        Text("Show Notifications")
                        Text("Display notifications when tracks are scrobbled")
                            .font(.caption)
                            .foregroundStyle(appState.currentTheme.foreground.secondary)
                    }
                }
            }
            
            Section("Appearance") {
                Toggle(isOn: $useSystemTheme) {
                    VStack(alignment: .leading) {
                        Text("Match System Appearance")
                        Text("Automatically switch between light and dark themes")
                            .font(.caption)
                            .foregroundStyle(appState.currentTheme.foreground.secondary)
                    }
                }
                .onChange(of: useSystemTheme) { oldValue, newValue in
                    if newValue {
                        appState.themeMode = .system
                    } else {
                        // Default to the current system theme when disabling system theme
                        let isDarkMode = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                        appState.themeMode = isDarkMode ? .dark : .light
                    }
                }
                
                if !useSystemTheme {
                    Picker("Theme", selection: $appState.themeMode) {
                        Text("Light").tag(AppState.ThemeMode.light)
                        Text("Dark").tag(AppState.ThemeMode.dark)
                    }
                    .pickerStyle(.segmented)
                    .disabled(useSystemTheme)
                }
                
                Toggle(isOn: $appState.blurArtwork) {
                    VStack(alignment: .leading) {
                        Text("Blur Artwork")
                        Text("Apply a blur effect to album artwork")
                            .font(.caption)
                            .foregroundStyle(appState.currentTheme.foreground.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .tint(appState.currentTheme.accent.primary)
        .onAppear {
            // Initialize useSystemTheme based on current theme mode
            useSystemTheme = appState.themeMode == .system
        }
    }
}

#Preview {
    GeneralSettingsView()
        .environmentObject(AppState())
} 