import SwiftUI

struct SearchBar: View {
    @Binding var text: String
    let onCommit: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search for albums...", text: $text)
                .textFieldStyle(.roundedBorder)
                .onSubmit(onCommit)
            
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    SearchBar(text: .constant(""), onCommit: {})
        .padding()
} 