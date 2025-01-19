import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

struct DynamicBackgroundView: View {
    let artwork: Image?
    @State private var dominantColor: Color = Color(.windowBackgroundColor)
    @State private var secondaryColor: Color = Color(.windowBackgroundColor)
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Base gradient using extracted colors
                LinearGradient(
                    colors: [
                        dominantColor,
                        dominantColor.opacity(0.8),
                        secondaryColor.opacity(0.6)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                if let artwork = artwork {
                    artwork
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .blur(radius: 100)
                        .opacity(0.5)
                        .overlay {
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
            .animation(.easeInOut(duration: 0.5), value: artwork)
            .animation(.easeInOut(duration: 0.5), value: dominantColor)
            .animation(.easeInOut(duration: 0.5), value: secondaryColor)
        }
        .ignoresSafeArea()
    }
} 