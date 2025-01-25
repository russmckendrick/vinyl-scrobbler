/// ModernArtworkView: A SwiftUI view that displays album artwork with a modern, elegant design.
/// This view provides a consistent presentation for album artwork with sophisticated styling,
/// including shadows, rounded corners, and a fallback design when no artwork is available.
import SwiftUI

/// A view component that renders album artwork or a placeholder with modern styling
struct ModernArtworkView: View {
    /// The optional album artwork image to display. If nil, a placeholder will be shown
    let artwork: Image?
    
    var body: some View {
        GeometryReader { geometry in
            Group {
                if let artwork = artwork {
                    // Artwork display with modern styling
                    artwork
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geometry.size.width - 40)  // Inset from edges
                        .clipShape(RoundedRectangle(cornerRadius: 20))  // Rounded corners
                        .shadow(
                            color: .black.opacity(0.25),  // Subtle shadow
                            radius: 30,                   // Large, soft shadow
                            x: 0,                        // Centered horizontally
                            y: 10                        // Slight downward offset
                        )
                        .overlay {
                            // Subtle white border for depth
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(.white.opacity(0.1), lineWidth: 1)
                        }
                } else {
                    // Placeholder view when no artwork is available
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.windowBackgroundColor))  // System background color
                        .frame(width: geometry.size.width - 40)
                        .aspectRatio(1, contentMode: .fit)    // Square aspect ratio
                        .overlay {
                            // Subtle white border matching artwork style
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(.white.opacity(0.1), lineWidth: 1)
                        }
                        .overlay(
                            // Centered optical disc icon as placeholder
                            Image(systemName: "opticaldisc")
                                .font(.system(size: 80))
                                .foregroundStyle(.secondary)
                        )
                        .shadow(
                            color: .black.opacity(0.25),  // Matching shadow style
                            radius: 30,
                            x: 0,
                            y: 10
                        )
                }
            }
            // Center the content within the geometry
            .position(
                x: geometry.frame(in: .local).midX,
                y: geometry.frame(in: .local).midY
            )
        }
    }
}