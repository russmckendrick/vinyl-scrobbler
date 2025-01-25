import AppKit

/// A data source and delegate implementation for displaying Discogs search results in a table view.
/// This class manages the presentation and interaction of search results, including:
/// - Displaying album titles and metadata
/// - Handling row selection
/// - Formatting and layout of result cells
class SearchResultsDataSource: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    // MARK: - Properties
    /// Storage for the current search results
    private var results: [DiscogsSearchResponse.SearchResult] = []
    /// Callback closure executed when a search result is selected
    private var selectionCallback: ((DiscogsSearchResponse.SearchResult) -> Void)?
    
    // MARK: - Initialization
    /// Initializes the data source with a selection callback
    /// - Parameter selectionCallback: A closure that will be called when a user selects a search result
    init(selectionCallback: @escaping (DiscogsSearchResponse.SearchResult) -> Void) {
        self.selectionCallback = selectionCallback
    }
    
    // MARK: - Public Methods
    /// Updates the data source with new search results
    /// - Parameter results: An array of Discogs search results to display
    func update(with results: [DiscogsSearchResponse.SearchResult]) {
        self.results = results
    }
    
    // MARK: - NSTableViewDataSource
    /// Provides the number of rows to display in the table view
    /// - Parameter tableView: The table view requesting this information
    /// - Returns: The total number of search results
    func numberOfRows(in tableView: NSTableView) -> Int {
        return results.count
    }
    
    // MARK: - NSTableViewDelegate
    /// Creates and configures a view for each cell in the table
    /// - Parameters:
    ///   - tableView: The table view requesting the cell view
    ///   - tableColumn: The table column where the cell will be displayed
    ///   - row: The row index of the cell
    /// - Returns: A configured NSView containing the search result information
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("ResultCell"), owner: nil) as? NSTableCellView else {
            return nil
        }
        
        let result = results[row]
        
        // Configure the main title of the cell
        cell.textField?.stringValue = result.title
        
        // Compile additional metadata details
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
        
        // Configure the subtitle field with metadata
        if let subtitleField = cell.viewWithTag(2) as? NSTextField {
            subtitleField.stringValue = details.joined(separator: " • ")
        }
        
        return cell
    }
    
    /// Handles selection changes in the table view
    /// - Parameter notification: The notification containing information about the selection change
    /// When a row is selected, this method triggers the selection callback with the corresponding search result
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tableView = notification.object as? NSTableView else { return }
        let selectedRow = tableView.selectedRow
        
        if selectedRow >= 0 && selectedRow < results.count {
            selectionCallback?(results[selectedRow])
        }
    }
}