import SwiftUI

enum ListeningStatus {
    case ready
    case listening
    case matching
    case found
    case searching
    case error
    
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