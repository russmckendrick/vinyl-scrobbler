import Cocoa

// MARK: - Search Window Controller
// Manages the window that displays Discogs search results and pagination
class SearchWindowController: NSWindowController, NSWindowDelegate {
    // MARK: - Properties
    // Data source for the search results table
    private var dataSource: SearchResultsDataSource?
    // Callback when window is closed
    private var onClose: (() -> Void)?
    // Label showing current page information
    private var pageLabel: NSTextField?
    // Current search and pagination state
    private(set) var currentState: SearchState?
    
    // MARK: - Initialization
    // Initialize with search results and callbacks
    init(results: [DiscogsSearchResponse.SearchResult], 
         pagination: DiscogsSearchResponse.Pagination, 
         query: String,
         onSelect: @escaping (DiscogsSearchResponse.SearchResult) -> Void,
         onClose: @escaping () -> Void) {
        
        // Create the main window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 450),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        super.init(window: window)
        
        self.onClose = onClose
        window.delegate = self
        window.title = "Search Results"
        
        // Initialize search state
        self.currentState = SearchState(
            query: query,
            currentPage: pagination.page,
            totalPages: pagination.pages
        )
        
        setupWindowContent(results: results, 
                          pagination: pagination, 
                          query: query, 
                          onSelect: onSelect)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Window Delegate
    // Clean up when window is closed
    func windowWillClose(_ notification: Notification) {
        dataSource = nil
        onClose?()
    }
    
    // MARK: - Public Methods
    // Update search results and pagination
    func updateResults(_ results: [DiscogsSearchResponse.SearchResult], 
                      pagination: DiscogsSearchResponse.Pagination,
                      query: String) {
        dataSource?.update(results: results)
        pageLabel?.stringValue = "Page \(pagination.page) of \(pagination.pages)"
        
        // Update current state with new search results
        currentState = SearchState(
            query: query,
            currentPage: pagination.page,
            totalPages: pagination.pages
        )
    }
    
    // MARK: - Private Methods
    // Set up the window's content and layout
    private func setupWindowContent(results: [DiscogsSearchResponse.SearchResult],
                                  pagination: DiscogsSearchResponse.Pagination,
                                  query: String,
                                  onSelect: @escaping (DiscogsSearchResponse.SearchResult) -> Void) {
        guard let window = self.window else { return }
        
        // Create main container view
        let containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        window.contentView?.addSubview(containerView)
        
        // Set up scroll view for results table
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        containerView.addSubview(scrollView)
        
        // Configure table view
        let tableView = NSTableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add table columns
        // Title column
        let titleColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("title"))
        titleColumn.title = "Title"
        titleColumn.width = 300
        tableView.addTableColumn(titleColumn)
        
        // Year column
        let yearColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("year"))
        yearColumn.title = "Year"
        yearColumn.width = 60
        tableView.addTableColumn(yearColumn)
        
        // Format column
        let formatColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("format"))
        formatColumn.title = "Format"
        formatColumn.width = 100
        tableView.addTableColumn(formatColumn)
        
        // Action column (for add buttons)
        let actionColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("action"))
        actionColumn.title = ""
        actionColumn.width = 40
        actionColumn.maxWidth = 40
        actionColumn.minWidth = 40
        tableView.addTableColumn(actionColumn)
        
        // Set up pagination controls
        let paginationView = NSView()
        paginationView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(paginationView)
        
        // Previous page button
        let previousButton = NSButton(title: "Previous", target: self, action: #selector(previousPage))
        previousButton.translatesAutoresizingMaskIntoConstraints = false
        paginationView.addSubview(previousButton)
        
        // Page indicator label
        pageLabel = NSTextField(labelWithString: "Page \(pagination.page) of \(pagination.pages)")
        pageLabel?.translatesAutoresizingMaskIntoConstraints = false
        pageLabel?.alignment = .center
        pageLabel?.isEditable = false
        pageLabel?.isBordered = false
        pageLabel?.backgroundColor = .clear
        if let pageLabel = pageLabel {
            paginationView.addSubview(pageLabel)
        }
        
        // Next page button
        let nextButton = NSButton(title: "Next", target: self, action: #selector(nextPage))
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        paginationView.addSubview(nextButton)
        
        // Initialize data source and connect to table view
        dataSource = SearchResultsDataSource(results: results, selectionCallback: onSelect)
        tableView.dataSource = dataSource
        tableView.delegate = dataSource
        
        scrollView.documentView = tableView
        
        // Configure pagination button states
        previousButton.isEnabled = pagination.page > 1
        nextButton.isEnabled = pagination.page < pagination.pages
        
        // Set up layout constraints
        NSLayoutConstraint.activate([
            // Container view fills window
            containerView.topAnchor.constraint(equalTo: window.contentView!.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor),
            
            // Scroll view fills container except for pagination area
            scrollView.topAnchor.constraint(equalTo: containerView.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: paginationView.topAnchor),
            
            // Pagination view layout
            paginationView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            paginationView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            paginationView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            paginationView.heightAnchor.constraint(equalToConstant: 50),
            
            // Pagination controls layout
            previousButton.leadingAnchor.constraint(equalTo: paginationView.leadingAnchor, constant: 20),
            previousButton.centerYAnchor.constraint(equalTo: paginationView.centerYAnchor),
            
            pageLabel!.centerXAnchor.constraint(equalTo: paginationView.centerXAnchor),
            pageLabel!.centerYAnchor.constraint(equalTo: paginationView.centerYAnchor),
            
            nextButton.trailingAnchor.constraint(equalTo: paginationView.trailingAnchor, constant: -20),
            nextButton.centerYAnchor.constraint(equalTo: paginationView.centerYAnchor)
        ])
    }
    
    // MARK: - Pagination Actions
    // Handle previous page button click
    @objc private func previousPage() {
        NotificationCenter.default.post(name: NSNotification.Name("LoadPreviousPage"), object: nil)
    }
    
    // Handle next page button click
    @objc private func nextPage() {
        NotificationCenter.default.post(name: NSNotification.Name("LoadNextPage"), object: nil)
    }
    
    // MARK: - Search State
    // Structure to track current search state
    struct SearchState {
        let query: String
        let currentPage: Int
        let totalPages: Int
    }
} 