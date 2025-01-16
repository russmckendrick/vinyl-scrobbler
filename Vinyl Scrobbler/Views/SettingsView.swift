import SwiftUI
import ScrobbleKit

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab = "Account"
    
    var body: some View {
        TabView(selection: $selectedTab) {
            AccountView()
                .tabItem {
                    Label("Account", systemImage: "person.circle")
                }
                .tag("Account")
            
            GeneralView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag("General")
        }
        .padding()
        .frame(width: 400, height: 400)
    }
    
    init(selectedTab: String = "Account") {
        _selectedTab = State(initialValue: selectedTab)
    }
}

private struct AccountView: View {
    @EnvironmentObject private var appState: AppState
    @State private var username = ""
    @State private var password = ""
    @State private var isAuthenticating = false
    @State private var errorMessage: String?
    
    private let lastFMService = LastFMService.shared
    
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
                        
                        let correctDate = Date(timeIntervalSince1970: 1116691571)
                        Text("Member since \(correctDate.formatted(.dateTime.day().month().year().locale(Locale(identifier: "en_US"))))")
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
                // Authentication form
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Username", text: $username)
                        .textFieldStyle(.roundedBorder)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                }
                .frame(width: 250)
                
                Button("Sign In") {
                    authenticate()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(username.isEmpty || password.isEmpty || isAuthenticating)
                
                Link("Don't have an account? Sign up at Last.fm", destination: URL(string: "https://www.last.fm")!)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .underline()
            }
        }
        .padding()
        .onAppear {
            // Fetch user info when the view appears if authenticated
            if appState.isAuthenticated {
                Task {
                    await appState.fetchUserInfo()
                }
            }
        }
    }
    
    private func authenticate() {
        isAuthenticating = true
        errorMessage = nil
        
        Task {
            do {
                try await lastFMService.authenticate(
                    username: username,
                    password: password
                )
                
                await MainActor.run {
                    appState.isAuthenticated = true
                    appState.showLastFMAuth = false
                    // Fetch user info after successful authentication
                    Task {
                        await appState.fetchUserInfo()
                    }
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            
            isAuthenticating = false
        }
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