import SwiftUI
import ScrobbleKit

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
        .frame(width: 400, height: 400)
    }
}

private struct AccountView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Last.fm Account")
                .font(.headline)
            
            if appState.isAuthenticated {
                if let user = appState.lastFMUser {
                    VStack(spacing: 12) {
                        // User avatar
                        if let imageUrl = user.image?.large {
                            AsyncImage(url: imageUrl) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 80, height: 80)
                                    .clipShape(Circle())
                            } placeholder: {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 80, height: 80)
                                    .foregroundColor(.gray)
                            }
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 80, height: 80)
                                .foregroundColor(.gray)
                        }
                        
                        // User info
                        Text(user.username)
                            .font(.title3)
                            .fontWeight(.medium)
                        
                        if let realName = user.realName, !realName.isEmpty {
                            Text(realName)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("\(user.playcount) scrobbles")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Member since \(user.memberSince.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button("Sign Out") {
                            appState.signOut()
                        }
                        .padding(.top, 8)
                    }
                } else {
                    ProgressView()
                        .padding()
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
    @AppStorage("enableNotifications") private var enableNotifications = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("General Settings")
                .font(.headline)
                .padding(.bottom)
            
            Toggle(isOn: $enableNotifications) {
                VStack(alignment: .leading) {
                    Text("Show Notifications")
                        .font(.body)
                    Text("Display notifications when tracks are scrobbled")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
} 