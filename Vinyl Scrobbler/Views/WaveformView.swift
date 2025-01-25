/// WaveformView: A SwiftUI Shape that renders a smooth, animated waveform visualization
/// based on a series of points. The waveform is drawn as a continuous curve using quadratic
/// Bézier curves for smooth transitions between points. The shape is filled from the curve
/// to the bottom of its frame, creating a solid waveform effect that can be animated
/// and styled with different fills and gradients.
import SwiftUI

/// A shape that renders a smooth waveform visualization from an array of points
struct WaveformView: Shape {
    /// Array of normalized points (0-1 range) defining the waveform shape
    var points: [CGPoint]
    
    /// Creates a path that represents the waveform within the given rectangle
    /// - Parameter rect: The rectangle in which to draw the waveform
    /// - Returns: A Path representing the filled waveform shape
    func path(in rect: CGRect) -> Path {
        // Return empty path if no points are provided
        guard !points.isEmpty else { return Path() }
        
        let path = Path { p in
            // Convert normalized points to view coordinates
            let scaledPoints = points.map { point in
                CGPoint(
                    x: point.x * rect.width,
                    y: point.y * rect.height
                )
            }
            
            // Start path at the middle-left of the view
            p.move(to: CGPoint(x: 0, y: rect.height / 2))
            
            // Create smooth curve through all points using quadratic Bézier curves
            // This creates a more natural, flowing waveform appearance
            for i in 0..<scaledPoints.count - 1 {
                let current = scaledPoints[i]
                let next = scaledPoints[i + 1]
                // Calculate control point as midpoint between current and next points
                // This ensures smooth transitions between segments
                let control = CGPoint(
                    x: (current.x + next.x) / 2,
                    y: (current.y + next.y) / 2
                )
                p.addQuadCurve(to: next, control: control)
            }
            
            // Complete the shape by drawing lines to create a filled area
            // This creates the solid waveform effect
            p.addLine(to: CGPoint(x: rect.width, y: rect.height))
            p.addLine(to: CGPoint(x: 0, y: rect.height))
            p.closeSubpath()
        }
        return path
    }
}

/// Preview provider for WaveformView
/// Demonstrates the waveform with sample points and themed styling
#Preview {
    let previewState = AppState()
    return WaveformView(points: [
        CGPoint(x: 0, y: 0.5),   // Start at middle
        CGPoint(x: 0.2, y: 0.3), // First peak
        CGPoint(x: 0.4, y: 0.7), // Valley
        CGPoint(x: 0.6, y: 0.4), // Second peak
        CGPoint(x: 0.8, y: 0.6), // Small peak
        CGPoint(x: 1.0, y: 0.5)  // End at middle
    ])
    .fill(previewState.currentTheme.foreground.primary)
    .frame(width: 400, height: 24)
    .background(previewState.currentTheme.background.primary)
}