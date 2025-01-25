/// SearchBar: A SwiftUI view component that provides a themed search input field
/// with a search icon, clear button, and customizable commit action. The view adapts
/// to the current app theme and provides immediate visual feedback for user interactions.
import SwiftUI

/// A reusable search bar component with themed styling and clear functionality
struct SearchBar: View {
    /// Binding to the search text value, allowing two-way updates
    @Binding var text: String
    /// Closure to execute when the search is committed (e.g., Return key pressed)
    let onCommit: () -> Void
    /// Access to the global app state for theming
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        HStack {
            // Search icon on the left
            Image(systemName: "magnifyingglass")
                .foregroundStyle(appState.currentTheme.foreground.secondary)
            
            // Search input field
            TextField("Search for albums...", text: $text)
                .textFieldStyle(.plain)
                .foregroundStyle(appState.currentTheme.foreground.primary)
                .onSubmit(onCommit)  // Trigger search on Return
            
            // Clear button, only shown when there is text
            if !text.isEmpty {
                Button {
                    text = ""  // Clear the search text
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(appState.currentTheme.foreground.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        // Container styling
        .padding(10)
        .background(appState.currentTheme.input.background)
        .cornerRadius(8)
    }
}

/// Preview provider for the SearchBar
#Preview {
    SearchBar(text: .constant(""), onCommit: {})
        .environmentObject(AppState())
        .padding()
}