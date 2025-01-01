import Cocoa

class SearchWindowController: NSWindowController, NSWindowDelegate {
    private var dataSource: SearchResultsDataSource?
    private var onClose: (() -> Void)?
    private var pageLabel: NSTextField?
    private(set) var currentState: SearchState?
    
    init(results: [DiscogsSearchResponse.SearchResult], 
         pagination: DiscogsSearchResponse.Pagination, 
         query: String,
         onSelect: @escaping (DiscogsSearchResponse.SearchResult) -> Void,
         onClose: @escaping () -> Void) {
        
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
        
        // Initialize current state
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
    
    func windowWillClose(_ notification: Notification) {
        dataSource = nil
        onClose?()
    }
    
    func updateResults(_ results: [DiscogsSearchResponse.SearchResult], 
                      pagination: DiscogsSearchResponse.Pagination,
                      query: String) {
        dataSource?.update(results: results)
        pageLabel?.stringValue = "Page \(pagination.page) of \(pagination.pages)"
        
        // Update current state
        currentState = SearchState(
            query: query,
            currentPage: pagination.page,
            totalPages: pagination.pages
        )
    }
    
    private func setupWindowContent(results: [DiscogsSearchResponse.SearchResult],
                                  pagination: DiscogsSearchResponse.Pagination,
                                  query: String,
                                  onSelect: @escaping (DiscogsSearchResponse.SearchResult) -> Void) {
        guard let window = self.window else { return }
        
        // Create container view
        let containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        window.contentView?.addSubview(containerView)
        
        // Create scroll view and table
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        containerView.addSubview(scrollView)
        
        let tableView = NSTableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add columns
        let titleColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("title"))
        titleColumn.title = "Title"
        titleColumn.width = 300
        tableView.addTableColumn(titleColumn)
        
        let yearColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("year"))
        yearColumn.title = "Year"
        yearColumn.width = 60
        tableView.addTableColumn(yearColumn)
        
        let formatColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("format"))
        formatColumn.title = "Format"
        formatColumn.width = 100
        tableView.addTableColumn(formatColumn)
        
        let actionColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("action"))
        actionColumn.title = ""  // No header title
        actionColumn.width = 40
        actionColumn.maxWidth = 40
        actionColumn.minWidth = 40
        tableView.addTableColumn(actionColumn)
        
        // Create pagination controls
        let paginationView = NSView()
        paginationView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(paginationView)
        
        let previousButton = NSButton(title: "Previous", target: self, action: #selector(previousPage))
        previousButton.translatesAutoresizingMaskIntoConstraints = false
        paginationView.addSubview(previousButton)
        
        pageLabel = NSTextField(labelWithString: "Page \(pagination.page) of \(pagination.pages)")
        pageLabel?.translatesAutoresizingMaskIntoConstraints = false
        pageLabel?.alignment = .center
        pageLabel?.isEditable = false
        pageLabel?.isBordered = false
        pageLabel?.backgroundColor = .clear
        if let pageLabel = pageLabel {
            paginationView.addSubview(pageLabel)
        }
        
        let nextButton = NSButton(title: "Next", target: self, action: #selector(nextPage))
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        paginationView.addSubview(nextButton)
        
        // Set up data source
        dataSource = SearchResultsDataSource(results: results, selectionCallback: onSelect)
        tableView.dataSource = dataSource
        tableView.delegate = dataSource
        
        scrollView.documentView = tableView
        
        // Set up pagination state
        previousButton.isEnabled = pagination.page > 1
        nextButton.isEnabled = pagination.page < pagination.pages
        
        // Layout constraints
        NSLayoutConstraint.activate([
            // Container view
            containerView.topAnchor.constraint(equalTo: window.contentView!.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor),
            
            // Scroll view
            scrollView.topAnchor.constraint(equalTo: containerView.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: paginationView.topAnchor),
            
            // Pagination view
            paginationView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            paginationView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            paginationView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            paginationView.heightAnchor.constraint(equalToConstant: 50),
            
            // Pagination controls
            previousButton.leadingAnchor.constraint(equalTo: paginationView.leadingAnchor, constant: 20),
            previousButton.centerYAnchor.constraint(equalTo: paginationView.centerYAnchor),
            
            pageLabel!.centerXAnchor.constraint(equalTo: paginationView.centerXAnchor),
            pageLabel!.centerYAnchor.constraint(equalTo: paginationView.centerYAnchor),
            
            nextButton.trailingAnchor.constraint(equalTo: paginationView.trailingAnchor, constant: -20),
            nextButton.centerYAnchor.constraint(equalTo: paginationView.centerYAnchor)
        ])
    }
    
    // Add pagination action handlers
    @objc private func previousPage() {
        // Notify AppDelegate to load previous page
        NotificationCenter.default.post(name: NSNotification.Name("LoadPreviousPage"), object: nil)
    }
    
    @objc private func nextPage() {
        // Notify AppDelegate to load next page
        NotificationCenter.default.post(name: NSNotification.Name("LoadNextPage"), object: nil)
    }
    
    struct SearchState {
        let query: String
        let currentPage: Int
        let totalPages: Int
    }
} 