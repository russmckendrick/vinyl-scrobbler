import SwiftUI

struct WaveformView: Shape {
    var points: [CGPoint]
    
    func path(in rect: CGRect) -> Path {
        guard !points.isEmpty else { return Path() }
        
        let path = Path { p in
            // Scale points to the actual size
            let scaledPoints = points.map { point in
                CGPoint(
                    x: point.x * rect.width,
                    y: point.y * rect.height
                )
            }
            
            p.move(to: CGPoint(x: 0, y: rect.height / 2))
            
            // Draw the top curve through all points
            for i in 0..<scaledPoints.count - 1 {
                let current = scaledPoints[i]
                let next = scaledPoints[i + 1]
                let control = CGPoint(
                    x: (current.x + next.x) / 2,
                    y: (current.y + next.y) / 2
                )
                p.addQuadCurve(to: next, control: control)
            }
            
            // Complete the path
            p.addLine(to: CGPoint(x: rect.width, y: rect.height))
            p.addLine(to: CGPoint(x: 0, y: rect.height))
            p.closeSubpath()
        }
        return path
    }
}

#Preview {
    WaveformView(points: [
        CGPoint(x: 0, y: 0.5),
        CGPoint(x: 0.2, y: 0.3),
        CGPoint(x: 0.4, y: 0.7),
        CGPoint(x: 0.6, y: 0.4),
        CGPoint(x: 0.8, y: 0.6),
        CGPoint(x: 1.0, y: 0.5)
    ])
    .fill(.white)
    .frame(width: 400, height: 24)
    .background(.black)
} 