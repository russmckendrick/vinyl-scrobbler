import Foundation
import AuthenticationServices
import SwiftUI

@MainActor
final class WebAuthenticationService {
    static let shared: WebAuthenticationService = WebAuthenticationService()
    
    private var presentationContext: WebAuthenticationPresentationContext?
    private var activeSession: ASWebAuthenticationSession?
    
    private init() {}
    
    func presentWebAuth(url: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: nil
            ) { callbackURL, error in
                Task { @MainActor in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                    self.activeSession = nil
                }
            }
            
            session.prefersEphemeralWebBrowserSession = true
            
            Task { @MainActor in
                let window = NSApplication.shared.keyWindow
                
                guard let window = window else {
                    continuation.resume(throwing: NSError(
                        domain: "WebAuthenticationService",
                        code: -2,
                        userInfo: [NSLocalizedDescriptionKey: "No key window found"]
                    ))
                    return
                }
                
                let context = WebAuthenticationPresentationContext(window: window)
                self.presentationContext = context
                session.presentationContextProvider = context
                self.activeSession = session
                
                if !session.start() {
                    self.activeSession = nil
                    continuation.resume(throwing: NSError(
                        domain: "WebAuthenticationService",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to start authentication session"]
                    ))
                }
            }
        }
    }
}

@MainActor
private final class WebAuthenticationPresentationContext: NSObject, ASWebAuthenticationPresentationContextProviding {
    private let window: NSWindow
    
    init(window: NSWindow) {
        self.window = window
        super.init()
    }
    
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return window
    }
} 