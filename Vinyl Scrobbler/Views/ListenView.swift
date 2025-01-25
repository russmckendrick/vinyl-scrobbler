/// ListenView: A SwiftUI view that provides audio recognition functionality
/// to identify playing music. It displays a dynamic interface with animated status indicators,
/// matched track information, and controls for starting/stopping the listening process.
/// The view integrates with music recognition services and Discogs for track identification.
import SwiftUI

/// A view that manages the music recognition interface and user interactions
struct ListenView: View {
    /// View model that handles the business logic and state management
    @StateObject private var viewModel: ListenViewModel
    /// Binding to control the presentation state of the view
    @Binding var isPresented: Bool
    /// Access to the global app state for theming and shared functionality
    @EnvironmentObject private var appState: AppState
    
    /// Initializes the view with presentation binding and creates the view model
    /// - Parameter isPresented: Binding to control the view's presentation state
    init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
        self._viewModel = StateObject(wrappedValue: ListenViewModel(isPresented: isPresented))
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header section with title
            Text("Listen")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(appState.currentTheme.foreground.primary)
            
            Spacer()
            
            // Animated status indicator with pulsing circles
            ZStack {
                // Outer pulsing circle for visual feedback
                Circle()
                    .fill(viewModel.currentStatus.color.opacity(0.2))
                    .frame(width: 160, height: 160)
                    .scaleEffect(viewModel.animationAmount)
                
                // Middle pulsing circle for layered effect
                Circle()
                    .fill(viewModel.currentStatus.color.opacity(0.2))
                    .frame(width: 120, height: 120)
                    .scaleEffect(viewModel.animationAmount * 0.8)
                
                // Central circle containing status icon
                Circle()
                    .fill(viewModel.currentStatus.color.opacity(0.3))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: viewModel.currentStatus.systemImage)
                            .font(.system(size: 32))
                            .foregroundStyle(appState.currentTheme.foreground.primary)
                    )
            }
            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), 
                      value: viewModel.animationAmount)
            
            // Status message display area
            if let error = viewModel.errorMessage {
                // Error message display
                Text(error)
                    .font(.headline)
                    .foregroundStyle(appState.currentTheme.status.error)
                    .multilineTextAlignment(.center)
            } else {
                // Current status message
                Text(viewModel.currentStatus.message)
                    .font(.headline)
                    .foregroundStyle(viewModel.currentStatus.color)
                    .multilineTextAlignment(.center)
            }
            
            // Matched track information display
            if viewModel.currentStatus == .found {
                VStack(spacing: 8) {
                    // Track title
                    Text(viewModel.matchedTrack)
                        .font(.headline)
                        .foregroundStyle(appState.currentTheme.foreground.primary)
                        .multilineTextAlignment(.center)
                    // Artist name
                    Text(viewModel.matchedArtist)
                        .font(.subheadline)
                        .foregroundStyle(appState.currentTheme.foreground.secondary)
                        .multilineTextAlignment(.center)
                    // Optional album name
                    if !viewModel.matchedAlbum.isEmpty {
                        Text(viewModel.matchedAlbum)
                            .font(.subheadline)
                            .foregroundStyle(appState.currentTheme.foreground.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.vertical, 8)
            }
            
            Spacer()
            
            // Primary action button for controlling recognition
            Button {
                if viewModel.currentStatus == .found {
                    viewModel.searchDiscogs()
                } else if viewModel.isListening {
                    viewModel.stopListening()
                } else {
                    Task {
                        await viewModel.startListening()
                    }
                }
            } label: {
                Text(viewModel.buttonTitle)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(viewModel.buttonColor)
                    .foregroundStyle(appState.currentTheme.foreground.primary)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.currentStatus == .matching || 
                     viewModel.currentStatus == .searching)
            
            // Helper text during listening state
            if viewModel.isListening {
                Text("Make sure your music is playing and audible")
                    .font(.caption)
                    .foregroundStyle(appState.currentTheme.foreground.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .frame(width: 300, height: 400)
        .background(appState.currentTheme.background.primary)
        .onAppear {
            // Initialize view model with app state
            viewModel.setAppState(appState)
        }
    }
}

/// Preview provider for ListenView
#Preview {
    ListenView(isPresented: .constant(true))
        .environmentObject(AppState())
}