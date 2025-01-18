import SwiftUI

struct GeneralSettingsView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        Form {
            Section {
                Toggle(isOn: $appState.showNotifications) {
                    VStack(alignment: .leading) {
                        Text("Show Notifications")
                        Text("Display notifications when tracks are scrobbled")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section {
                Toggle(isOn: $appState.blurArtwork) {
                    VStack(alignment: .leading) {
                        Text("Blur Artwork")
                        Text("Apply a blur effect to album artwork")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

#Preview {
    GeneralSettingsView()
        .environmentObject(AppState())
} 