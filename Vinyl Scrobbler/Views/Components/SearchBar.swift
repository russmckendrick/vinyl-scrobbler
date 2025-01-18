import SwiftUI

struct SearchBar: View {
    @Binding var text: String
    let onCommit: () -> Void
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(appState.currentTheme.foreground.secondary)
            
            TextField("Search for albums...", text: $text)
                .textFieldStyle(.plain)
                .foregroundStyle(appState.currentTheme.foreground.primary)
                .onSubmit(onCommit)
            
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(appState.currentTheme.foreground.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(appState.currentTheme.input.background)
        .cornerRadius(8)
    }
}

#Preview {
    SearchBar(text: .constant(""), onCommit: {})
        .environmentObject(AppState())
        .padding()
} 