/// GeneralSettingsView: A SwiftUI view that provides user-configurable settings
/// for the application's general behavior and appearance. This includes notification
/// preferences, theme selection, and visual effect options.
import SwiftUI

/// Custom modifier for segmented picker styling that applies theme-aware colors
struct CustomSegmentedPickerStyle: ViewModifier {
    /// Access to the global app state for theming
    @EnvironmentObject private var appState: AppState
    
    func body(content: Content) -> some View {
        content
            .pickerStyle(.segmented)
            .colorMultiply(appState.currentTheme.foreground.primary)
    }
}

/// Main view for general application settings
struct GeneralSettingsView: View {
    /// Access to the global app state for preferences and theming
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        Form {
            // MARK: - Notifications Section
            Section {
                VStack(spacing: 0) {
                    // Notification toggle with description
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
            
            // MARK: - Appearance Section
            Section {
                VStack(spacing: 16) {
                    // Theme selection picker
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Theme")
                            .foregroundStyle(appState.currentTheme.foreground.primary)
                        // Themed segmented picker for light/dark mode
                        Picker("Theme", selection: Binding(
                            get: { appState.themeMode },
                            set: { appState.setThemeMode($0) }
                        )) {
                            Text("Light").tag(AppState.ThemeMode.light)
                            Text("Dark").tag(AppState.ThemeMode.dark)
                        }
                        .modifier(CustomSegmentedPickerStyle())
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(appState.currentTheme.background.tertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    // Artwork blur effect toggle
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
        // Form styling and theme application
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(appState.currentTheme.background.primary)
        .tint(appState.currentTheme.accent.primary)
    }
}

/// Preview provider for GeneralSettingsView
#Preview {
    GeneralSettingsView()
        .environmentObject(AppState())
}