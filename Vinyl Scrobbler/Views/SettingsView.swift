import SwiftUI
import ScrobbleKit

struct CustomSettingsTabStyle: View {
    @EnvironmentObject private var appState: AppState
    @Binding var selection: String
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Button {
                    selection = "Account"
                } label: {
                    HStack {
                        Image(systemName: "person.circle")
                        Text("Account")
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .foregroundStyle(selection == "Account" ? appState.currentTheme.accent.primary : appState.currentTheme.foreground.primary)
                }
                .buttonStyle(.plain)
                
                Button {
                    selection = "General"
                } label: {
                    HStack {
                        Image(systemName: "gear")
                        Text("General")
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .foregroundStyle(selection == "General" ? appState.currentTheme.accent.primary : appState.currentTheme.foreground.primary)
                }
                .buttonStyle(.plain)
            }
            .background(appState.currentTheme.background.secondary)
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab = "Account"
    
    var body: some View {
        VStack(spacing: 0) {
            CustomSettingsTabStyle(selection: $selectedTab)
            
            Divider()
                .background(appState.currentTheme.border.primary)
            
            // Content
            Group {
                if selectedTab == "Account" {
                    AccountView()
                } else {
                    GeneralSettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(appState.currentTheme.background.primary)
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
                .foregroundStyle(appState.currentTheme.foreground.primary)
            
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
                                            .stroke(appState.currentTheme.border.primary, lineWidth: 1)
                                    )
                            } placeholder: {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 100, height: 100)
                                    .foregroundStyle(appState.currentTheme.foreground.secondary)
                            }
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 100, height: 100)
                                .foregroundStyle(appState.currentTheme.foreground.secondary)
                        }
                        
                        // User info
                        Text(user.username)
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundStyle(appState.currentTheme.foreground.primary)
                        
                        if let realName = user.realName, !realName.isEmpty {
                            Text(realName)
                                .font(.subheadline)
                                .foregroundStyle(appState.currentTheme.foreground.secondary)
                        }
                        
                        Text("\(user.playcount) scrobbles")
                            .font(.caption)
                            .foregroundStyle(appState.currentTheme.foreground.secondary)
                        
                        let correctDate = Date(timeIntervalSince1970: 1116691571)
                        Text("Member since \(correctDate.formatted(.dateTime.day().month().year().locale(Locale(identifier: "en_US"))))")
                            .font(.caption)
                            .foregroundStyle(appState.currentTheme.foreground.secondary)
                        
                        Button {
                            appState.signOut()
                        } label: {
                            Text("Sign Out")
                                .foregroundStyle(appState.currentTheme.foreground.primary)
                        }
                        .buttonStyle(.bordered)
                        .tint(appState.currentTheme.status.error)
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
                        .foregroundStyle(appState.currentTheme.status.error)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Username", text: $username)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(appState.currentTheme.input.background)
                        .foregroundStyle(appState.currentTheme.input.text)
                        .cornerRadius(8)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(appState.currentTheme.input.background)
                        .foregroundStyle(appState.currentTheme.input.text)
                        .cornerRadius(8)
                }
                .frame(width: 250)
                
                Button {
                    authenticate()
                } label: {
                    Text("Sign In")
                        .foregroundStyle(appState.currentTheme.foreground.primary)
                }
                .buttonStyle(.bordered)
                .tint(appState.currentTheme.accent.primary)
                .keyboardShortcut(.defaultAction)
                .disabled(username.isEmpty || password.isEmpty || isAuthenticating)
                .padding(.top, 8)
                
                Link("Don't have an account? Sign up at Last.fm", destination: URL(string: "https://www.last.fm")!)
                    .font(.caption)
                    .foregroundStyle(appState.currentTheme.foreground.secondary)
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