/// DynamicBackgroundView: A SwiftUI view that creates a dynamic, animated background
/// using album artwork and extracted colors. The view combines gradients and blurred
/// artwork to create an aesthetically pleasing background effect that adapts to the
/// current album artwork.
import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

/// A view that creates a dynamic background effect using album artwork and color gradients
struct DynamicBackgroundView: View {
    /// The optional album artwork image to use as the base for the background effect
    let artwork: Image?
    /// The primary color extracted from the artwork, defaults to window background color
    @State private var dominantColor: Color = Color(.windowBackgroundColor)
    /// The secondary color for gradient effects, defaults to window background color
    @State private var secondaryColor: Color = Color(.windowBackgroundColor)
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Base gradient using extracted colors
                // Creates a smooth transition from dominant to secondary colors
                LinearGradient(
                    colors: [
                        dominantColor,
                        dominantColor.opacity(0.8),
                        secondaryColor.opacity(0.6)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Blurred artwork overlay with gradient
                if let artwork = artwork {
                    artwork
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .blur(radius: 100)  // Heavy blur for abstract background effect
                        .opacity(0.5)       // Reduced opacity to prevent overwhelming visuals
                        .overlay {
                            // Gradient overlay to ensure content visibility
                            LinearGradient(
                                colors: [
                                    .clear,
                                    dominantColor.opacity(0.3),
                                    dominantColor.opacity(0.5),
                                    dominantColor.opacity(0.7)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }
                        .clipped()
                }
            }
            // Smooth animations for all visual changes
            .animation(.easeInOut(duration: 0.5), value: artwork)
            .animation(.easeInOut(duration: 0.5), value: dominantColor)
            .animation(.easeInOut(duration: 0.5), value: secondaryColor)
        }
        .ignoresSafeArea()  // Extend background to edges of screen
    }
}