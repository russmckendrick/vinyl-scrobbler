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
            Text("Listen")
                .font(.title3)
                .fontWeight(.semibold)
            
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
                    .scaleEffect(viewModel.animationAmount * 0.8)
                
                // Inner circle with icon
                Circle()
                    .fill(viewModel.currentStatus.color.opacity(0.3))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: viewModel.currentStatus.systemImage)
                            .font(.system(size: 32))
                            .foregroundStyle(.white)
                    )
            }
            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), 
                      value: viewModel.animationAmount)
            
            // Status Message
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.headline)
                    .foregroundStyle(.red)
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
                    .foregroundStyle(.white)
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
        .padding(24)
        .frame(width: 300, height: 400)
        .background(Color.black)
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
        .preferredColorScheme(.dark)
} 