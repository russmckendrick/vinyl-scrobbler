import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        TabView {
            AccountView()
                .tabItem {
                    Label("Account", systemImage: "person.circle")
                }
            
            GeneralView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
        }
        .padding()
        .frame(width: 400, height: 300)
    }
}

private struct AccountView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack {
            Text("Last.fm Account")
                .font(.headline)
                .padding(.bottom)
            
            if appState.isAuthenticated {
                Button("Sign Out") {
                    appState.signOut()
                }
            } else {
                Button("Sign In") {
                    appState.showLastFMAuth = true
                }
            }
        }
        .padding()
    }
}

private struct GeneralView: View {
    var body: some View {
        VStack {
            Text("General Settings")
                .font(.headline)
                .padding(.bottom)
            
            // Add general settings here
        }
        .padding()
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
} 