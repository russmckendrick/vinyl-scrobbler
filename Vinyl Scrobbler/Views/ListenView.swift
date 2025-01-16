import SwiftUI

struct ListenView: View {
    @StateObject private var viewModel: ListenViewModel
    @Binding var isPresented: Bool
    @EnvironmentObject private var appState: AppState
    
    init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
        self._viewModel = StateObject(wrappedValue: ListenViewModel(isPresented: isPresented))
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Listen")
                    .font(.headline)
                Spacer()
            }
            
            Spacer()
            
            // Status Icon with Animation
            ZStack {
                // Outer pulse circle
                Circle()
                    .fill(viewModel.currentStatus.color.opacity(0.1))
                    .frame(width: 160, height: 160)
                    .scaleEffect(viewModel.animationAmount)
                
                // Middle pulse circle
                Circle()
                    .fill(viewModel.currentStatus.color.opacity(0.2))
                    .frame(width: 120, height: 120)
                    .scaleEffect(viewModel.animationAmount)
                
                // Inner circle with icon
                Circle()
                    .fill(viewModel.currentStatus.color.opacity(0.3))
                    .frame(width: 80, height: 80)
                
                Image(systemName: viewModel.currentStatus.systemImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .foregroundStyle(viewModel.currentStatus.color)
            }
            
            // Status Message
            if viewModel.currentStatus == .found {
                VStack(spacing: 8) {
                    Text(viewModel.matchedTrack)
                        .font(.headline)
                    Text("by \(viewModel.matchedArtist)")
                        .font(.subheadline)
                    if !viewModel.matchedAlbum.isEmpty {
                        Text("from \(viewModel.matchedAlbum)")
                            .font(.subheadline)
                    }
                }
                .foregroundStyle(viewModel.currentStatus.color)
                .multilineTextAlignment(.center)
            } else {
                Text(viewModel.currentStatus.message)
                    .font(.headline)
                    .foregroundStyle(viewModel.currentStatus.color)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            // Action Button
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
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.currentStatus == .matching || 
                     viewModel.currentStatus == .searching)
            
            if viewModel.isListening {
                Text("Make sure your music is playing and audible")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(width: 300, height: 400)
        .background(Color(.windowBackgroundColor))
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred")
        }
        .onAppear {
            viewModel.setAppState(appState)
        }
    }
}

#Preview {
    ListenView(isPresented: .constant(true))
        .environmentObject(AppState())
} 