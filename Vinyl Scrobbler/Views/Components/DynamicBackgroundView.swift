import SwiftUI

struct DynamicBackgroundView: View {
    let artwork: Image?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(.windowBackgroundColor)
                
                if let artwork = artwork {
                    artwork
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .blur(radius: 50)
                        .overlay {
                            LinearGradient(
                                colors: [
                                    .black.opacity(0.3),
                                    .black.opacity(0.5),
                                    .black.opacity(0.7)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }
                        .clipped()
                }
            }
            .animation(.easeInOut(duration: 0.5), value: artwork)
        }
        .ignoresSafeArea()
    }
} 