/// A collection of views for managing application settings and Last.fm authentication.
/// This file contains multiple view structures that work together to provide a
/// complete settings interface with tabbed navigation and account management.
import SwiftUI
import ScrobbleKit

/// Custom tab style view for settings navigation
/// Provides a themed interface for switching between Account and General settings
struct CustomSettingsTabStyle: View {
    /// Access to global app state for theming
    @EnvironmentObject private var appState: AppState
    /// Currently selected tab
    @Binding var selection: String
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Account tab button with dynamic styling
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
                
                // General settings tab button with dynamic styling
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

/// Main settings view that manages tab selection and content display
struct SettingsView: View {
    /// Access to global app state
    @EnvironmentObject private var appState: AppState
    /// Currently selected settings tab
    @State private var selectedTab = "Account"
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom tab navigation
            CustomSettingsTabStyle(selection: $selectedTab)
            
            // Visual separator between tabs and content
            Divider()
                .background(appState.currentTheme.border.primary)
            
            // Dynamic content based on selected tab
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
    
    /// Initializes the settings view with an optional default selected tab
    /// - Parameter selectedTab: The initial tab to display
    init(selectedTab: String = "Account") {
        _selectedTab = State(initialValue: selectedTab)
    }
}

/// Account management view for Last.fm authentication and user profile display
private struct AccountView: View {
    /// Access to global app state
    @EnvironmentObject private var appState: AppState
    /// Username input field value
    @State private var username = ""
    /// Password input field value
    @State private var password = ""
    /// Authentication state tracker
    @State private var isAuthenticating = false
    /// Error message for authentication failures
    @State private var errorMessage: String?
    /// User's Last.fm registration date
    @State private var registrationDate: Date?
    
    /// Shared Last.fm service instance for authentication
    private let lastFMService = LastFMService.shared
    
    var body: some View {
        VStack(spacing: 20) {
            // Section title
            Text("Last.fm Account")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(appState.currentTheme.foreground.primary)
            
            if appState.isAuthenticated {
                if let user = appState.lastFMUser {
                    VStack(spacing: 16) {
                        // User profile image with fallback
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
                        
                        // User profile information display
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
                        
                        // Registration date with async loading
                        Text("Member since \((registrationDate ?? user.memberSince).formatted(.dateTime.day().month().year().locale(Locale(identifier: "en_US"))))")
                            .font(.caption)
                            .foregroundStyle(appState.currentTheme.foreground.secondary)
                            .task {
                                do {
                                    let timestamp = try await lastFMService.getRegistrationTimestamp(username: user.username)
                                    registrationDate = Date(timeIntervalSince1970: TimeInterval(timestamp))
                                } catch {
                                    print("Failed to get registration date: \(error)")
                                }
                            }
                        
                        // Sign out button
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
                // Login form for unauthenticated users
                if let error = errorMessage {
                    Text(error)
                        .foregroundStyle(appState.currentTheme.status.error)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                // Authentication input fields
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
                
                // Sign in button
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
                
                // Sign up link
                Link("Don't have an account? Sign up at Last.fm", destination: URL(string: "https://www.last.fm")!)
                    .font(.caption)
                    .foregroundStyle(appState.currentTheme.foreground.secondary)
                    .padding(.top, 8)
            }
        }
        .padding(24)
        .onAppear {
            // Fetch user info on view appearance if authenticated
            if appState.isAuthenticated {
                Task {
                    await appState.fetchUserInfo()
                }
            }
        }
    }
    
    /// Authenticates the user with Last.fm using provided credentials
    /// Handles the authentication process and updates the app state accordingly
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

/// Preview provider for SettingsView
#Preview {
    SettingsView()
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}