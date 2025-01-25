import Foundation

/// A model representing a single track from a vinyl record or album
/// Conforms to Identifiable for unique identification in collections and Equatable for comparison
/// This struct contains all essential metadata about a track, including its position on the record,
/// title, duration, artist, album information, and associated artwork
public struct Track: Identifiable, Equatable {
    // MARK: - Properties
    /// Unique identifier for the track instance
    public let id = UUID()
    
    /// The track's position or number on the album
    /// For vinyl records, this could be side-specific (e.g., "A1", "B2")
    /// For other formats, it might be a simple number (e.g., "1", "2")
    public let position: String
    
    /// The title of the track
    /// This is the main display name of the song or composition
    public let title: String
    
    /// The duration of the track in MM:SS format
    /// Optional as some track listings might not include duration information
    /// Example: "3:45" represents 3 minutes and 45 seconds
    public var duration: String?
    
    /// The name of the artist or band who performed the track
    /// This might differ from the album artist in compilation albums
    public let artist: String
    
    /// The title of the album that contains this track
    /// Used for grouping tracks and displaying album context
    public let album: String
    
    /// URL to the album artwork image
    /// Optional as artwork might not always be available
    /// When present, can be used to fetch and display album cover art
    public var artworkURL: URL?
    
    // MARK: - Computed Properties
    /// Converts the MM:SS duration string into total seconds
    /// Useful for playback timing and duration calculations
    /// - Returns: Total number of seconds for the track duration, or nil if duration is missing or invalid
    /// - Example: "3:45" returns 225 (3 minutes * 60 + 45 seconds)
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
    /// Creates a new Track instance with the specified metadata
    /// - Parameters:
    ///   - position: The track's position on the album (e.g., "A1", "1", "B2")
    ///   - title: The title of the track
    ///   - duration: Optional duration string in MM:SS format
    ///   - artist: The name of the performing artist
    ///   - album: The title of the album
    ///   - artworkURL: Optional URL to the album artwork image
    public init(position: String, title: String, duration: String?, artist: String, album: String, artworkURL: URL? = nil) {
        self.position = position
        self.title = title
        self.duration = duration
        self.artist = artist
        self.album = album
        self.artworkURL = artworkURL
    }
}