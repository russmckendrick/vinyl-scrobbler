import Cocoa

// MARK: - Search Results Data Source
// Manages the data and presentation for the Discogs search results table
class SearchResultsDataSource: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    // MARK: - Properties
    // Array of search results from Discogs
    private var results: [DiscogsSearchResponse.SearchResult]
    // Callback for when a result is selected
    let selectionCallback: (DiscogsSearchResponse.SearchResult) -> Void
    private weak var tableView: NSTableView?
    
    // MARK: - Initialization
    init(results: [DiscogsSearchResponse.SearchResult], 
         selectionCallback: @escaping (DiscogsSearchResponse.SearchResult) -> Void) {
        self.results = results
        self.selectionCallback = selectionCallback
        super.init()
    }
    
    // MARK: - Public Methods
    // Update the results array and trigger a table refresh
    func update(results: [DiscogsSearchResponse.SearchResult]) {
        self.results = results
        tableView?.reloadData()
    }
    
    // MARK: - TableView DataSource
    // Return the number of rows in the table
    func numberOfRows(in tableView: NSTableView) -> Int {
        return results.count
    }
    
    // Configure and return cells for the table
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        // Store reference to table view for updates
        self.tableView = tableView
        
        let result = results[row]
        
        switch tableColumn?.identifier.rawValue {
        case "action":
            // Create cell with add button
            let cell = NSTableCellView()
            let button = NSButton(image: NSImage(systemSymbolName: "plus.circle.fill", 
                                               accessibilityDescription: "Add")!, 
                                target: self, 
                                action: #selector(addButtonClicked(_:)))
            button.identifier = NSUserInterfaceItemIdentifier(String(result.id))
            button.tag = row
            button.bezelStyle = .circular
            button.isBordered = false
            button.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(button)
            
            // Layout constraints for the button
            NSLayoutConstraint.activate([
                button.centerXAnchor.constraint(equalTo: cell.centerXAnchor),
                button.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                button.widthAnchor.constraint(equalToConstant: 20),
                button.heightAnchor.constraint(equalToConstant: 20)
            ])
            
            return cell
            
        case "title":
            // Create cell with release title
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
            // Create cell with release year
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
            // Create cell with release format
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
    
    // MARK: - TableView Delegate
    // Prevent row selection
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return false
    }
    
    // MARK: - Action Handlers
    // Handle add button click
    @MainActor
    @objc private func addButtonClicked(_ sender: NSButton) {
        Task { @MainActor in
            let row = sender.tag
            guard row < results.count else { return }
            selectionCallback(results[row])
        }
    }
} 