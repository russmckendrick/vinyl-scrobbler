import Cocoa
import os

class AuthViewController: NSViewController {
    private let logger = Logger(subsystem: "com.vinyl.scrobbler", category: "AuthViewController")
    private let lastFMService: LastFMService
    private let onLoginSuccess: () -> Void
    
    // UI Elements
    private var usernameField: NSTextField!
    private var passwordField: NSSecureTextField!
    private var loginButton: NSButton!
    private var statusLabel: NSTextField!
    private var okButton: NSButton!  // New OK button for success state
    
    // Track login state
    private var isLoggedIn = false
    
    init(lastFMService: LastFMService, onLoginSuccess: @escaping () -> Void) {
        self.lastFMService = lastFMService
        self.onLoginSuccess = onLoginSuccess
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 200))
        setupUI()
    }
    
    private func setupUI() {
        // Username field
        usernameField = NSTextField()
        usernameField.placeholderString = "Last.fm Username"
        usernameField.translatesAutoresizingMaskIntoConstraints = false
        usernameField.target = self
        usernameField.action = #selector(loginButtonClicked)
        view.addSubview(usernameField)
        
        // Password field
        passwordField = NSSecureTextField()
        passwordField.placeholderString = "Password"
        passwordField.translatesAutoresizingMaskIntoConstraints = false
        // Set up password field to work with Return key
        passwordField.target = self
        passwordField.action = #selector(handlePasswordReturn)
        view.addSubview(passwordField)
        
        // Login button
        loginButton = NSButton(title: "Login to Last.fm", target: self, action: #selector(loginButtonClicked))
        loginButton.bezelStyle = .rounded
        loginButton.translatesAutoresizingMaskIntoConstraints = false
        loginButton.keyEquivalent = "\r"  // Make it the default button (respond to Return key)
        view.addSubview(loginButton)
        
        // Status label
        statusLabel = NSTextField(labelWithString: "Please enter both username and password")
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)
        
        // Add OK button (initially hidden)
        okButton = NSButton(title: "OK", target: self, action: #selector(okButtonClicked))
        okButton.bezelStyle = .rounded
        okButton.translatesAutoresizingMaskIntoConstraints = false
        okButton.isHidden = true
        view.addSubview(okButton)
        
        NSLayoutConstraint.activate([
            usernameField.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            usernameField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            usernameField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            passwordField.topAnchor.constraint(equalTo: usernameField.bottomAnchor, constant: 10),
            passwordField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            passwordField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            loginButton.topAnchor.constraint(equalTo: passwordField.bottomAnchor, constant: 20),
            loginButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            statusLabel.topAnchor.constraint(equalTo: loginButton.bottomAnchor, constant: 10),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            okButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            okButton.topAnchor.constraint(equalTo: loginButton.topAnchor),
            okButton.widthAnchor.constraint(equalToConstant: 100)
        ])
        
        logger.info("Setting up Last.fm login UI")
    }
    
    @objc private func loginButtonClicked() {
        let username = usernameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = passwordField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !username.isEmpty, !password.isEmpty else {
            statusLabel.stringValue = "Please enter both username and password"
            return
        }
        
        // Disable UI during login
        loginButton.isEnabled = false
        usernameField.isEnabled = false
        passwordField.isEnabled = false
        statusLabel.stringValue = "Logging in..."
        
        Task { @MainActor in
            do {
                try await lastFMService.authenticate(username: username, password: password)
                
                // Show success state
                statusLabel.stringValue = "Successfully signed in!"
                usernameField.isHidden = true
                passwordField.isHidden = true
                loginButton.isHidden = true
                okButton.isHidden = false
                
                // Call success handler
                onLoginSuccess()
                
            } catch {
                statusLabel.stringValue = "Login failed: \(error.localizedDescription)"
                loginButton.isEnabled = true
                usernameField.isEnabled = true
                passwordField.isEnabled = true
            }
        }
    }
    
    @objc private func okButtonClicked() {
        // Simply close the window
        view.window?.close()
    }
    
    @objc private func handlePasswordReturn() {
        loginButtonClicked()
    }
    
    deinit {
        logger.info("AuthViewController being deallocated")
    }
} 