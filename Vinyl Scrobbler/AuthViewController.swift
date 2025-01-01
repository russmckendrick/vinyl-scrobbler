import Cocoa
import os

// MARK: - Authentication View Controller
// Handles the Last.fm authentication UI and login process
class AuthViewController: NSViewController {
    // MARK: - Properties
    // Logger for authentication-related events
    private let logger = Logger(subsystem: "com.vinyl.scrobbler", category: "AuthViewController")
    
    // Service and callback references
    private let lastFMService: LastFMService
    private let onLoginSuccess: () -> Void
    
    // MARK: - UI Elements
    private var usernameField: NSTextField!
    private var passwordField: NSSecureTextField!
    private var loginButton: NSButton!
    private var statusLabel: NSTextField!
    private var okButton: NSButton!  // Shown after successful login
    
    // Authentication state
    private var isLoggedIn = false
    
    // MARK: - Initialization
    // Custom initializer that takes Last.fm service and success callback
    init(lastFMService: LastFMService, onLoginSuccess: @escaping () -> Void) {
        self.lastFMService = lastFMService
        self.onLoginSuccess = onLoginSuccess
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View Lifecycle
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 200))
        setupUI()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        // Username input field
        usernameField = NSTextField()
        usernameField.placeholderString = "Last.fm Username"
        usernameField.translatesAutoresizingMaskIntoConstraints = false
        usernameField.target = self
        usernameField.action = #selector(loginButtonClicked)
        view.addSubview(usernameField)
        
        // Secure password input field
        passwordField = NSSecureTextField()
        passwordField.placeholderString = "Password"
        passwordField.translatesAutoresizingMaskIntoConstraints = false
        passwordField.target = self
        passwordField.action = #selector(handlePasswordReturn)  // Handle Return key in password field
        view.addSubview(passwordField)
        
        // Login button configuration
        loginButton = NSButton(title: "Login to Last.fm", target: self, action: #selector(loginButtonClicked))
        loginButton.bezelStyle = .rounded
        loginButton.translatesAutoresizingMaskIntoConstraints = false
        loginButton.keyEquivalent = "\r"  // Make it the default button
        view.addSubview(loginButton)
        
        // Status message display
        statusLabel = NSTextField(labelWithString: "Please enter both username and password")
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)
        
        // OK button for successful login (initially hidden)
        okButton = NSButton(title: "OK", target: self, action: #selector(okButtonClicked))
        okButton.bezelStyle = .rounded
        okButton.translatesAutoresizingMaskIntoConstraints = false
        okButton.isHidden = true
        view.addSubview(okButton)
        
        // Layout constraints for UI elements
        NSLayoutConstraint.activate([
            // Username field constraints
            usernameField.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            usernameField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            usernameField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Password field constraints
            passwordField.topAnchor.constraint(equalTo: usernameField.bottomAnchor, constant: 10),
            passwordField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            passwordField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Login button constraints
            loginButton.topAnchor.constraint(equalTo: passwordField.bottomAnchor, constant: 20),
            loginButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // Status label constraints
            statusLabel.topAnchor.constraint(equalTo: loginButton.bottomAnchor, constant: 10),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // OK button constraints
            okButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            okButton.topAnchor.constraint(equalTo: loginButton.topAnchor),
            okButton.widthAnchor.constraint(equalToConstant: 100)
        ])
        
        logger.info("Setting up Last.fm login UI")
    }
    
    // MARK: - Action Handlers
    
    // Handle login button click
    @objc private func loginButtonClicked() {
        let username = usernameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = passwordField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate input
        guard !username.isEmpty, !password.isEmpty else {
            statusLabel.stringValue = "Please enter both username and password"
            return
        }
        
        // Disable UI during authentication
        loginButton.isEnabled = false
        usernameField.isEnabled = false
        passwordField.isEnabled = false
        statusLabel.stringValue = "Logging in..."
        
        // Attempt authentication
        Task { @MainActor in
            do {
                try await lastFMService.authenticate(username: username, password: password)
                
                // Update UI for successful login
                statusLabel.stringValue = "Successfully signed in!"
                usernameField.isHidden = true
                passwordField.isHidden = true
                loginButton.isHidden = true
                okButton.isHidden = false
                
                // Trigger success callback
                onLoginSuccess()
                
            } catch {
                // Handle authentication failure
                statusLabel.stringValue = "Login failed: \(error.localizedDescription)"
                loginButton.isEnabled = true
                usernameField.isEnabled = true
                passwordField.isEnabled = true
            }
        }
    }
    
    // Handle OK button after successful login
    @objc private func okButtonClicked() {
        view.window?.close()
    }
    
    // Handle Return key in password field
    @objc private func handlePasswordReturn() {
        loginButtonClicked()
    }
    
    // MARK: - Cleanup
    deinit {
        logger.info("AuthViewController being deallocated")
    }
} 