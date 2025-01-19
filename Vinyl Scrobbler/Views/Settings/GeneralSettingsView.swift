import SwiftUI

struct CustomSegmentedPickerStyle: ViewModifier {
    @EnvironmentObject private var appState: AppState
    
    func body(content: Content) -> some View {
        content
            .pickerStyle(.segmented)
            .colorMultiply(appState.currentTheme.foreground.primary)
    }
}

struct GeneralSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var useSystemTheme: Bool = true
    
    var body: some View {
        Form {
            Section {
                VStack(spacing: 0) {
                    Toggle(isOn: $appState.showNotifications) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Show Notifications")
                                .foregroundStyle(appState.currentTheme.foreground.primary)
                            Text("Display notifications when tracks are scrobbled")
                                .font(.caption)
                                .foregroundStyle(appState.currentTheme.foreground.secondary)
                        }
                    }
                    .tint(appState.currentTheme.accent.primary)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                }
                .background(appState.currentTheme.background.tertiary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } header: {
                Text("Notifications")
                    .foregroundStyle(appState.currentTheme.foreground.primary)
                    .fontWeight(.medium)
                    .textCase(nil)
            }
            .listRowBackground(appState.currentTheme.background.primary)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            
            Section {
                VStack(spacing: 16) {
                    Toggle(isOn: $useSystemTheme) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Match System Appearance")
                                .foregroundStyle(appState.currentTheme.foreground.primary)
                            Text("Automatically switch between light and dark themes")
                                .font(.caption)
                                .foregroundStyle(appState.currentTheme.foreground.secondary)
                        }
                    }
                    .tint(appState.currentTheme.accent.primary)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(appState.currentTheme.background.tertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onChange(of: useSystemTheme) { oldValue, newValue in
                        if newValue {
                            appState.themeMode = .system
                        } else {
                            let isDarkMode = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                            appState.themeMode = isDarkMode ? .dark : .light
                        }
                    }
                    
                    if !useSystemTheme {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Theme")
                                .foregroundStyle(appState.currentTheme.foreground.primary)
                            Picker("Theme", selection: $appState.themeMode) {
                                Text("Light").tag(AppState.ThemeMode.light)
                                Text("Dark").tag(AppState.ThemeMode.dark)
                            }
                            .modifier(CustomSegmentedPickerStyle())
                            .disabled(useSystemTheme)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(appState.currentTheme.background.tertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    Toggle(isOn: $appState.blurArtwork) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Blur Artwork")
                                .foregroundStyle(appState.currentTheme.foreground.primary)
                            Text("Apply a blur effect to album artwork")
                                .font(.caption)
                                .foregroundStyle(appState.currentTheme.foreground.secondary)
                        }
                    }
                    .tint(appState.currentTheme.accent.primary)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(appState.currentTheme.background.tertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            } header: {
                Text("Appearance")
                    .foregroundStyle(appState.currentTheme.foreground.primary)
                    .fontWeight(.medium)
                    .textCase(nil)
            }
            .listRowBackground(appState.currentTheme.background.primary)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(appState.currentTheme.background.primary)
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