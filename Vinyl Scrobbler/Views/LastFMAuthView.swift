import SwiftUI

struct LastFMAuthView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        EmptyView()
            .onAppear {
                // Instead of showing auth dialog, open settings on Account tab
                appState.showLastFMAuth = false
                appState.showSettings = true
                dismiss()
            }
    }
}

#Preview {
    LastFMAuthView()
        .environmentObject(AppState())
} 