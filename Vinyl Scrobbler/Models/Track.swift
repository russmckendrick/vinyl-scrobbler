import Foundation

public struct Track {
    public let position: String
    public let title: String
    public let duration: String?
    public let artist: String
    public let album: String
    
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
    
    public init(position: String, title: String, duration: String?, artist: String, album: String) {
        self.position = position
        self.title = title
        self.duration = duration
        self.artist = artist
        self.album = album
    }
} 