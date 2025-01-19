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
                            .foregroundStyle(appState.currentTheme.foreground.primary)
                        Text("Display notifications when tracks are scrobbled")
                            .font(.caption)
                            .foregroundStyle(appState.currentTheme.foreground.secondary)
                    }
                }
            }
            .foregroundStyle(appState.currentTheme.foreground.primary)
            
            Section("Appearance") {
                Toggle(isOn: $useSystemTheme) {
                    VStack(alignment: .leading) {
                        Text("Match System Appearance")
                            .foregroundStyle(appState.currentTheme.foreground.primary)
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
                        Text("Light")
                            .foregroundStyle(appState.currentTheme.foreground.primary)
                            .tag(AppState.ThemeMode.light)
                        Text("Dark")
                            .foregroundStyle(appState.currentTheme.foreground.primary)
                            .tag(AppState.ThemeMode.dark)
                    }
                    .pickerStyle(.segmented)
                    .disabled(useSystemTheme)
                }
                
                Toggle(isOn: $appState.blurArtwork) {
                    VStack(alignment: .leading) {
                        Text("Blur Artwork")
                            .foregroundStyle(appState.currentTheme.foreground.primary)
                        Text("Apply a blur effect to album artwork")
                            .font(.caption)
                            .foregroundStyle(appState.currentTheme.foreground.secondary)
                    }
                }
            }
            .foregroundStyle(appState.currentTheme.foreground.primary)
        }
        .formStyle(.grouped)
        .padding()
        .tint(appState.currentTheme.accent.primary)
        .background(appState.currentTheme.background.primary)
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