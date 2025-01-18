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
            
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag("General")
        }
        .background(Color.black)
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
                .font(.title3)
                .fontWeight(.semibold)
            
            if appState.isAuthenticated {
                if let user = appState.lastFMUser {
                    VStack(spacing: 16) {
                        // User avatar
                        if let imageUrl = user.image?.large {
                            AsyncImage(url: imageUrl) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                            } placeholder: {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 100, height: 100)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 100, height: 100)
                                .foregroundStyle(.secondary)
                        }
                        
                        // User info
                        Text(user.username)
                            .font(.title3)
                            .fontWeight(.medium)
                        
                        if let realName = user.realName, !realName.isEmpty {
                            Text(realName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        Text("\(user.playcount) scrobbles")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        let correctDate = Date(timeIntervalSince1970: 1116691571)
                        Text("Member since \(correctDate.formatted(.dateTime.day().month().year().locale(Locale(identifier: "en_US"))))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Button("Sign Out") {
                            appState.signOut()
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
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
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Username", text: $username)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(Color(.darkGray).opacity(0.3))
                        .cornerRadius(8)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(Color(.darkGray).opacity(0.3))
                        .cornerRadius(8)
                }
                .frame(width: 250)
                
                Button("Sign In") {
                    authenticate()
                }
                .buttonStyle(.bordered)
                .tint(.blue)
                .keyboardShortcut(.defaultAction)
                .disabled(username.isEmpty || password.isEmpty || isAuthenticating)
                .padding(.top, 8)
                
                Link("Don't have an account? Sign up at Last.fm", destination: URL(string: "https://www.last.fm")!)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
        }
        .padding(24)
        .onAppear {
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

#Preview {
    SettingsView()
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
} 