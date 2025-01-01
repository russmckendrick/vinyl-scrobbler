import Foundation

// MARK: - Track Model
// Represents a single track from an album with its metadata
public struct Track {
    // MARK: - Properties
    // Position or track number on the album (e.g., "A1", "1", "B2")
    public let position: String
    
    // Track title
    public let title: String
    
    // Track duration in MM:SS format (optional)
    public let duration: String?
    
    // Artist name
    public let artist: String
    
    // Album title
    public let album: String
    
    // MARK: - Computed Properties
    // Converts MM:SS duration string to total seconds
    // Returns nil if duration is missing or invalid
    public var durationSeconds: Int? {
        guard let duration = duration else { return nil }
        let components = duration.split(separator: ":")
        guard components.count == 2,
              let minutes = Int(components[0]),
              let seconds = Int(components[1]) else {
            return nil
        }
        return minutes * 60 + seconds
    }
    
    // MARK: - Initialization
    // Creates a new track with the specified metadata
    public init(position: String, title: String, duration: String?, artist: String, album: String) {
        self.position = position
        self.title = title
        self.duration = duration
        self.artist = artist
        self.album = album
    }
} 