import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

struct AlbumArtworkView: View {
    @EnvironmentObject private var appState: AppState
    @State private var artworkImage: Image?
    @State private var dominantColor: Color = .black
    @State private var secondaryColor: Color = .black
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient based on artwork
                if let artwork = artworkImage {
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
                                    .black.opacity(0.3),
                                    .black.opacity(0.6),
                                    .black
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }
                }
                
                // Main artwork
                VStack {
                    if let track = appState.currentTrack {
                        AsyncImage(url: track.artworkURL) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: min(geometry.size.width - 80, geometry.size.height - 85))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                                    )
                                    .padding(.top, 40)
                                    .onAppear {
                                        extractColors(from: image)
                                        withAnimation(.easeInOut(duration: 0.5)) {
                                            artworkImage = image
                                        }
                                    }
                            case .failure(_):
                                EmptyArtworkView()
                                    .padding(.top, 40)
                                    .onAppear {
                                        resetColors()
                                        withAnimation(.easeInOut(duration: 0.5)) {
                                            artworkImage = nil
                                        }
                                    }
                            case .empty:
                                ProgressView()
                                    .controlSize(.large)
                                    .padding(.top, 40)
                            @unknown default:
                                EmptyArtworkView()
                                    .padding(.top, 40)
                                    .onAppear {
                                        resetColors()
                                        withAnimation(.easeInOut(duration: 0.5)) {
                                            artworkImage = nil
                                        }
                                    }
                            }
                        }
                    } else {
                        EmptyArtworkView()
                            .padding(.top, 40)
                            .onAppear {
                                resetColors()
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    artworkImage = nil
                                }
                            }
                    }
                    
                    Spacer()
                }
            }
        }
        .onChange(of: appState.currentTrack) { oldTrack, newTrack in
            if oldTrack?.artworkURL != newTrack?.artworkURL {
                withAnimation(.easeInOut(duration: 0.3)) {
                    resetColors()
                    artworkImage = nil
                }
            }
        }
    }
    
    private func resetColors() {
        withAnimation(.easeInOut(duration: 0.5)) {
            dominantColor = .black
            secondaryColor = .black
        }
    }
    
    private func extractColors(from image: Image) {
        guard let cgImage = NSImage(data: Data())?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            resetColors()
            return
        }
        
        let inputImage = CIImage(cgImage: cgImage)
        let extractor = CIFilter.areaAverage()
        extractor.inputImage = inputImage
        extractor.extent = inputImage.extent
        
        guard let outputImage = extractor.outputImage,
              let cgOutputImage = CIContext().createCGImage(outputImage, from: outputImage.extent) else {
            resetColors()
            return
        }
        
        let bitmap = NSBitmapImageRep(cgImage: cgOutputImage)
        guard let color = bitmap.colorAt(x: 0, y: 0) else {
            resetColors()
            return
        }
        
        withAnimation(.easeInOut(duration: 0.5)) {
            dominantColor = Color(nsColor: color)
            // Create a darker variant for the secondary color
            secondaryColor = Color(
                red: color.redComponent * 0.7,
                green: color.greenComponent * 0.7,
                blue: color.blueComponent * 0.7
            )
        }
    }
}

struct EmptyArtworkView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .black))
                .opacity(0.3)
                .frame(width: 300, height: 300)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                )
            
            Image(systemName: "opticaldisc")
                .font(.system(size: 80))
                .foregroundStyle(.secondary)
        }
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
}

#Preview {
    AlbumArtworkView()
        .environmentObject(AppState())
        .frame(width: 500, height: 500)
        .background(.black)
} 