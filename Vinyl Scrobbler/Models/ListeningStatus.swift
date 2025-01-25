import SwiftUI

/// Represents the current state of the vinyl listening and matching process.
/// This enum provides a comprehensive status tracking system with associated
/// user interface elements like messages, colors, and system images for each state.
enum ListeningStatus {
    /// Initial state when the app is ready to start listening
    case ready
    /// Active state when the app is listening for audio
    case listening
    /// State when the app is attempting to match the detected audio
    case matching
    /// Success state when a matching track has been identified
    case found
    /// State when the app is querying the Discogs database
    case searching
    /// Error state when something goes wrong in the process
    case error
    
    /// Provides user-friendly status messages for each state
    /// - Returns: A string describing the current status
    var message: String {
        switch self {
        case .ready:
            return "Ready to Listen"
        case .listening:
            return "Listening..."
        case .matching:
            return "Matching..."
        case .found:
            return "Track Found!"
        case .searching:
            return "Searching Discogs..."
        case .error:
            return "Error"
        }
    }
    
    /// Defines the color scheme for visual status indication
    /// - Returns: A SwiftUI Color appropriate for the current status
    var color: Color {
        switch self {
        case .ready:
            return .blue
        case .listening:
            return .green
        case .matching:
            return .orange
        case .found:
            return .green
        case .searching:
            return .purple
        case .error:
            return .red
        }
    }
    
    /// Provides SF Symbols system image names for visual status representation
    /// - Returns: A string identifier for the appropriate SF Symbol
    var systemImage: String {
        switch self {
        case .ready:
            return "waveform"
        case .listening:
            return "ear"
        case .matching:
            return "magnifyingglass"
        case .found:
            return "checkmark"
        case .searching:
            return "arrow.clockwise"
        case .error:
            return "xmark"
        }
    }
}