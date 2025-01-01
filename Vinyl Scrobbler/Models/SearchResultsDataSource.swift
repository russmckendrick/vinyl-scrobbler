import Cocoa

class SearchResultsDataSource: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    private var results: [DiscogsSearchResponse.SearchResult]
    let selectionCallback: (DiscogsSearchResponse.SearchResult) -> Void
    
    init(results: [DiscogsSearchResponse.SearchResult], 
         selectionCallback: @escaping (DiscogsSearchResponse.SearchResult) -> Void) {
        self.results = results
        self.selectionCallback = selectionCallback
        super.init()
    }
    
    func update(results: [DiscogsSearchResponse.SearchResult]) {
        self.results = results
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return results.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let result = results[row]
        
        switch tableColumn?.identifier.rawValue {
        case "action":
            let cell = NSTableCellView()
            let button = NSButton(image: NSImage(systemSymbolName: "plus.circle.fill", accessibilityDescription: "Add")!, 
                                target: self, 
                                action: #selector(addButtonClicked(_:)))
            button.identifier = NSUserInterfaceItemIdentifier(String(result.id))
            button.tag = row
            button.bezelStyle = .circular
            button.isBordered = false
            button.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(button)
            
            NSLayoutConstraint.activate([
                button.centerXAnchor.constraint(equalTo: cell.centerXAnchor),
                button.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                button.widthAnchor.constraint(equalToConstant: 20),
                button.heightAnchor.constraint(equalToConstant: 20)
            ])
            
            return cell
            
        case "title":
            let cell = NSTableCellView()
            let text = NSTextField(labelWithString: result.title)
            text.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(text)
            
            NSLayoutConstraint.activate([
                text.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                text.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                text.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
            
            return cell
            
        case "year":
            let cell = NSTableCellView()
            let text = NSTextField(labelWithString: result.year ?? "N/A")
            text.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(text)
            
            NSLayoutConstraint.activate([
                text.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                text.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                text.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
            
            return cell
            
        case "format":
            let cell = NSTableCellView()
            let text = NSTextField(labelWithString: result.format?.joined(separator: ", ") ?? "N/A")
            text.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(text)
            
            NSLayoutConstraint.activate([
                text.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                text.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                text.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
            
            return cell
            
        default:
            return nil
        }
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return false
    }
    
    @MainActor
    @objc private func addButtonClicked(_ sender: NSButton) {
        Task { @MainActor in
            let row = sender.tag
            guard row < results.count else { return }
            selectionCallback(results[row])
        }
    }
} 