import AppKit

// MARK: - Search Results Data Source
// Manages the data and presentation for the Discogs search results table
class SearchResultsDataSource: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    // MARK: - Properties
    private var results: [DiscogsSearchResponse.SearchResult] = []
    private var selectionCallback: ((DiscogsSearchResponse.SearchResult) -> Void)?
    
    // MARK: - Initialization
    init(selectionCallback: @escaping (DiscogsSearchResponse.SearchResult) -> Void) {
        self.selectionCallback = selectionCallback
    }
    
    // MARK: - Public Methods
    func update(with results: [DiscogsSearchResponse.SearchResult]) {
        self.results = results
    }
    
    // MARK: - NSTableViewDataSource
    func numberOfRows(in tableView: NSTableView) -> Int {
        return results.count
    }
    
    // MARK: - NSTableViewDelegate
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("ResultCell"), owner: nil) as? NSTableCellView else {
            return nil
        }
        
        let result = results[row]
        
        // Configure the cell with the result data
        cell.textField?.stringValue = result.title
        
        // Add additional details like year, format, etc.
        var details: [String] = []
        if let year = result.year {
            details.append(year)
        }
        if let format = result.format?.joined(separator: ", ") {
            details.append(format)
        }
        if let country = result.country {
            details.append(country)
        }
        
        // Set the subtitle
        if let subtitleField = cell.viewWithTag(2) as? NSTextField {
            subtitleField.stringValue = details.joined(separator: " • ")
        }
        
        return cell
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tableView = notification.object as? NSTableView else { return }
        let selectedRow = tableView.selectedRow
        
        if selectedRow >= 0 && selectedRow < results.count {
            selectionCallback?(results[selectedRow])
        }
    }
} 