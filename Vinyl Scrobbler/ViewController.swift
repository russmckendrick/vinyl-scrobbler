import Cocoa
import CoreVideo
import os

/**
 The main view controller that manages the vinyl scrobbler player UI and handles track list functionalities,
 as well as window visibility and table view updates.
 */
class ViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource, NSWindowDelegate {

    // MARK: - Public Properties
    
    /// The progress bar showing the current track's playback progress.
    public var progressBar: NSProgressIndicator!
    
    /// Label showing the current playback time (e.g., 1:23).
    public var currentTimeLabel: NSTextField!
    
    /// Label showing the total time of the current track (e.g., 4:56).
    public var totalTimeLabel: NSTextField!
    
    /// Button to go to the previous track.
    public var previousButton: NSButton!
    
    /// Button to play or pause the current track.
    public var playPauseButton: NSButton!
    
    /// Button to skip to the next track.
    public var nextButton: NSButton!
    
    /// Flag indicating whether the player is currently in a playing state.
    public var isPlaying = false
    
    // MARK: - New UI Elements
    
    /// An image view for displaying the album artwork.
    public var albumArtworkView: NSImageView!
    
    /// A label to display the current track's title.
    public var trackTitleLabel: NSTextField!
    
    /// A label to display the current album's title.
    public var albumTitleLabel: NSTextField!
    
    /// A label to display the artist name.
    public var artistLabel: NSTextField!
    
    // MARK: - Track List Table
    
    /// A scroll view wrapping the track list table.
    public var scrollView: NSScrollView!
    
    /// The table view displaying the list of tracks.
    public var trackListTableView: NSTableView!
    
    /// A container view for player controls.
    private var controlsContainer: NSView!
    
    // MARK: - Window Management
    
    /// Logger for debugging and information logs.
    private let logger = Logger(subsystem: "com.vinyl.scrobbler", category: "ViewController")
    
    /// Tracks the visibility state of the player window.
    private var isWindowVisible = false
    
    /// A computed property indicating if the player window is currently visible on screen.
    public var isPlayerWindowVisible: Bool {
        return isWindowVisible
    }
    
    /**
     Shows the player window, brings it to the front, and refreshes the UI.
     */
    public func showPlayerWindow() {
        isWindowVisible = true
        view.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)  // Move this here from AppDelegate
        refreshUI()  // Refresh UI when showing window
    }
    
    /**
     Hides the player window.
     */
    public func hidePlayerWindow() {
        isWindowVisible = false
        view.window?.orderOut(nil)
    }

    // MARK: - Timer
    
    /// Timer used to update the display continuously.
    private var updateTimer: Timer?

    /**
     Called after the view has been loaded. Sets up the window delegate, timer, UI elements,
     and configures control button actions.
     */
    override func viewDidLoad() {
        super.viewDidLoad()

        // Set window delegate to handle close button
        view.window?.delegate = self
        
        // Set up timer for continuous updates
        updateTimer = Timer(timeInterval: 0.1, target: self, selector: #selector(updateDisplay), userInfo: nil, repeats: true)
        RunLoop.main.add(updateTimer!, forMode: .common)
        
        // Configure window for background updates
        view.window?.isOpaque = false
        view.window?.level = .floating
        view.window?.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Enable background animation and updates
        view.window?.displaysWhenScreenProfileChanges = true
        NSAnimationContext.current.allowsImplicitAnimation = true
        
        // Set window title
        self.view.window?.title = "Vinyl Scrobbler"
        
        setupAlbumArtwork()
        setupTrackInfo()
        setupPlayerControls()
        setupTrackListTable()
        
        // Force layout update
        view.layoutSubtreeIfNeeded()
        
        // Connect buttons to AppDelegate actions
        previousButton.target = NSApp.delegate
        previousButton.action = #selector(AppDelegate.previousTrackMenuAction)
        
        playPauseButton.target = NSApp.delegate
        playPauseButton.action = #selector(AppDelegate.playPauseMenuAction)
        
        nextButton.target = NSApp.delegate
        nextButton.action = #selector(AppDelegate.nextTrackMenuAction)
    }
    
    /**
     Called after the view has appeared. Updates table view layout and scroll view layout.
     */
    override func viewDidAppear() {
        super.viewDidAppear()
        
        // Force table layout update when view appears
        trackListTableView.sizeToFit()
        trackListTableView.sizeLastColumnToFit()
        
        // Ensure scroll view updates its layout
        scrollView.tile()
        scrollView.layoutSubtreeIfNeeded()
    }

    /**
     Sets up and constraints the album artwork view in the UI.
     */
    private func setupAlbumArtwork() {
        // Album artwork view
        albumArtworkView = NSImageView()
        albumArtworkView.translatesAutoresizingMaskIntoConstraints = false
        albumArtworkView.imageScaling = .scaleProportionallyUpOrDown
        albumArtworkView.wantsLayer = true
        albumArtworkView.layer?.cornerRadius = 8
        albumArtworkView.layer?.masksToBounds = true
        view.addSubview(albumArtworkView)
        
        NSLayoutConstraint.activate([
            albumArtworkView.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            albumArtworkView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            albumArtworkView.widthAnchor.constraint(equalToConstant: 300),
            albumArtworkView.heightAnchor.constraint(equalToConstant: 300)
        ])
    }
    
    /**
     Sets up labels for track title, album title, and artist name.
     */
    private func setupTrackInfo() {
        // Track title
        trackTitleLabel = NSTextField(labelWithString: "")
        trackTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        trackTitleLabel.font = .systemFont(ofSize: 16, weight: .bold)
        trackTitleLabel.alignment = .center
        trackTitleLabel.lineBreakMode = .byTruncatingTail
        view.addSubview(trackTitleLabel)
        
        // Album title
        albumTitleLabel = NSTextField(labelWithString: "")
        albumTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        albumTitleLabel.font = .systemFont(ofSize: 14)
        albumTitleLabel.textColor = .secondaryLabelColor
        albumTitleLabel.alignment = .center
        albumTitleLabel.lineBreakMode = .byTruncatingTail
        view.addSubview(albumTitleLabel)
        
        // Artist name
        artistLabel = NSTextField(labelWithString: "")
        artistLabel.translatesAutoresizingMaskIntoConstraints = false
        artistLabel.font = .systemFont(ofSize: 14)
        artistLabel.textColor = .secondaryLabelColor
        artistLabel.alignment = .center
        artistLabel.lineBreakMode = .byTruncatingTail
        view.addSubview(artistLabel)
        
        NSLayoutConstraint.activate([
            trackTitleLabel.topAnchor.constraint(equalTo: albumArtworkView.bottomAnchor, constant: 16),
            trackTitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            trackTitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            albumTitleLabel.topAnchor.constraint(equalTo: trackTitleLabel.bottomAnchor, constant: 4),
            albumTitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            albumTitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            artistLabel.topAnchor.constraint(equalTo: albumTitleLabel.bottomAnchor, constant: 4),
            artistLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            artistLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    /**
     Sets up the player controls: progress bar, time labels, and forward/back/play-pause buttons.
     */
    private func setupPlayerControls() {
        // Create container view for controls
        let controlsContainer = NSView()
        self.controlsContainer = controlsContainer
        controlsContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controlsContainer)
        
        // Create a container for progress bar and time labels
        let progressContainer = NSView()
        progressContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressContainer)
        
        // Setup progress bar with modern style
        progressBar = NSProgressIndicator()
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        progressBar.isIndeterminate = false
        progressBar.minValue = 0
        progressBar.maxValue = 100
        progressBar.controlSize = .large
        progressBar.alphaValue = 0.8
        progressContainer.addSubview(progressBar)
        
        // Time labels
        currentTimeLabel = NSTextField(labelWithString: "0:00")
        currentTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        currentTimeLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        currentTimeLabel.textColor = .secondaryLabelColor
        progressContainer.addSubview(currentTimeLabel)
        
        totalTimeLabel = NSTextField(labelWithString: "0:00")
        totalTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        totalTimeLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        totalTimeLabel.textColor = .secondaryLabelColor
        progressContainer.addSubview(totalTimeLabel)
        
        // Setup control buttons with SF Symbols
        previousButton = NSButton(frame: .zero)
        previousButton.translatesAutoresizingMaskIntoConstraints = false
        previousButton.bezelStyle = .regularSquare
        previousButton.isBordered = false
        previousButton.image = NSImage(systemSymbolName: "backward.fill", accessibilityDescription: "Previous")
        previousButton.wantsLayer = true
        previousButton.layer?.backgroundColor = .clear
        controlsContainer.addSubview(previousButton)
        
        playPauseButton = NSButton(frame: .zero)
        playPauseButton.translatesAutoresizingMaskIntoConstraints = false
        playPauseButton.bezelStyle = .regularSquare
        playPauseButton.isBordered = false
        playPauseButton.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Play")
        playPauseButton.wantsLayer = true
        playPauseButton.layer?.backgroundColor = .clear
        controlsContainer.addSubview(playPauseButton)
        
        nextButton = NSButton(frame: .zero)
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        nextButton.bezelStyle = .regularSquare
        nextButton.isBordered = false
        nextButton.image = NSImage(systemSymbolName: "forward.fill", accessibilityDescription: "Next")
        nextButton.wantsLayer = true
        nextButton.layer?.backgroundColor = .clear
        controlsContainer.addSubview(nextButton)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            // Progress container constraints
            progressContainer.topAnchor.constraint(equalTo: artistLabel.bottomAnchor, constant: 20),
            progressContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            progressContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Controls container constraints
            controlsContainer.topAnchor.constraint(equalTo: progressContainer.bottomAnchor, constant: 20),
            controlsContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            controlsContainer.heightAnchor.constraint(equalToConstant: 40),
            controlsContainer.widthAnchor.constraint(equalToConstant: 160),
            
            // Progress bar constraints
            progressBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            progressBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            progressBar.heightAnchor.constraint(equalToConstant: 4),
            
            // Time label constraints
            currentTimeLabel.topAnchor.constraint(equalTo: progressBar.bottomAnchor, constant: 8),
            currentTimeLabel.leadingAnchor.constraint(equalTo: progressBar.leadingAnchor),
            
            totalTimeLabel.topAnchor.constraint(equalTo: progressBar.bottomAnchor, constant: 8),
            totalTimeLabel.trailingAnchor.constraint(equalTo: progressBar.trailingAnchor),
            
            // Control buttons
            previousButton.leadingAnchor.constraint(equalTo: controlsContainer.leadingAnchor),
            previousButton.centerYAnchor.constraint(equalTo: controlsContainer.centerYAnchor),
            previousButton.widthAnchor.constraint(equalToConstant: 40),
            previousButton.heightAnchor.constraint(equalToConstant: 40),
            
            playPauseButton.centerXAnchor.constraint(equalTo: controlsContainer.centerXAnchor),
            playPauseButton.centerYAnchor.constraint(equalTo: controlsContainer.centerYAnchor),
            playPauseButton.widthAnchor.constraint(equalToConstant: 40),
            playPauseButton.heightAnchor.constraint(equalToConstant: 40),
            
            nextButton.trailingAnchor.constraint(equalTo: controlsContainer.trailingAnchor),
            nextButton.centerYAnchor.constraint(equalTo: controlsContainer.centerYAnchor),
            nextButton.widthAnchor.constraint(equalToConstant: 40),
            nextButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    /**
     Sets up the scrollable track list table and its columns.
     */
    private func setupTrackListTable() {
        // Create scroll view
        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        view.addSubview(scrollView)
        
        // Create table view
        trackListTableView = NSTableView()
        trackListTableView.translatesAutoresizingMaskIntoConstraints = false
        trackListTableView.style = .inset
        trackListTableView.usesAlternatingRowBackgroundColors = true
        trackListTableView.gridStyleMask = .solidHorizontalGridLineMask
        trackListTableView.delegate = self
        trackListTableView.dataSource = self
        trackListTableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        trackListTableView.rowHeight = 24
        
        // Add columns
        let positionColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("position"))
        positionColumn.title = "#"
        positionColumn.width = 40
        positionColumn.minWidth = 40
        positionColumn.maxWidth = 60
        trackListTableView.addTableColumn(positionColumn)
        
        let titleColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("title"))
        titleColumn.title = "Title"
        titleColumn.width = 320
        titleColumn.minWidth = 100
        trackListTableView.addTableColumn(titleColumn)
        
        let durationColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("duration"))
        durationColumn.title = "Duration"
        durationColumn.width = 80
        durationColumn.minWidth = 60
        durationColumn.maxWidth = 100
        trackListTableView.addTableColumn(durationColumn)
        
        // Set up scroll view with table
        scrollView.documentView = trackListTableView
        scrollView.contentView.frame = scrollView.bounds
        
        // Make sure table fills scroll view width
        trackListTableView.sizeToFit()
        trackListTableView.autoresizingMask = [.width]
        
        // Layout constraints for scroll view
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: controlsContainer.bottomAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            
            // Set a minimum height for the scroll view
            scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 200)
        ])
        
        // Initial reload
        trackListTableView.reloadData()
    }
    
    /**
     Selector method called at the interval specified by updateTimer to refresh the display.
     */
    @objc private func updateDisplay() {
        view.window?.viewsNeedDisplay = true
        view.needsDisplay = true
    }
    
    /**
     Updates the play/pause button image based on the current playing state, then reloads the track list table.
     */
    @objc public func updatePlayPauseButton() {
        let symbolName = isPlaying ? "stop.fill" : "play.fill"
        let description = isPlaying ? "Stop" : "Play"
        playPauseButton.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: description)
        // Refresh the table to update the play indicator
        trackListTableView.reloadData()
    }
    
    /**
     IBAction-style selector for the previous track button. Delegates handling to the AppDelegate.
     */
    @objc private func previousTrackClicked() {
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            appDelegate.previousTrack(nil)
        }
    }
    
    /**
     IBAction-style selector for the play/pause button. Delegates handling to the AppDelegate.
     */
    @objc private func playPauseClicked() {
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            appDelegate.togglePlayPause(nil)
        }
    }
    
    /**
     IBAction-style selector for the next track button. Delegates handling to the AppDelegate.
     */
    @objc private func nextTrackClicked() {
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            appDelegate.nextTrack(nil)
        }
    }

    /// Property that can be overridden to update the view when data changes.
    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    /**
     Cleans up the update timer on deinitialization.
     */
    deinit {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    // MARK: - TableView DataSource
    
    /**
     Returns the number of rows in the track list table, based on the tracks array in the AppDelegate.
     */
    func numberOfRows(in tableView: NSTableView) -> Int {
        guard let appDelegate = NSApplication.shared.delegate as? AppDelegate else { return 0 }
        return appDelegate.tracks.count
    }
    
    /**
     Provides a view for each table cell based on the column identifier and the track data.
     */
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let appDelegate = NSApplication.shared.delegate as? AppDelegate,
              row < appDelegate.tracks.count,
              let columnIdentifier = tableColumn?.identifier else { return nil }
        
        let track = appDelegate.tracks[row]
        let cellIdentifier = NSUserInterfaceItemIdentifier(columnIdentifier.rawValue + "Cell")
        
        var cell = tableView.makeView(withIdentifier: cellIdentifier, owner: nil) as? NSTableCellView
        
        if cell == nil {
            // Create new cell if none exists
            cell = NSTableCellView()
            cell?.identifier = cellIdentifier
            
            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.drawsBackground = false
            textField.isBordered = false
            textField.isEditable = false
            textField.cell?.truncatesLastVisibleLine = true
            textField.cell?.lineBreakMode = .byTruncatingTail
            
            cell?.addSubview(textField)
            cell?.textField = textField
            
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cell!.leadingAnchor, constant: 5),
                textField.trailingAnchor.constraint(equalTo: cell!.trailingAnchor, constant: -5),
                textField.centerYAnchor.constraint(equalTo: cell!.centerYAnchor)
            ])
        }
        
        // Check if this is the currently playing track
        let isCurrentTrack = row == appDelegate.currentTrackIndex
        let isPlaying = appDelegate.isPlaying
        
        // Set the text color based on whether this is the current track
        cell?.textField?.textColor = isCurrentTrack ? .systemBlue : .labelColor
        
        // Configure cell based on column
        switch columnIdentifier.rawValue {
        case "position":
            if isCurrentTrack && isPlaying {
                cell?.textField?.stringValue = "▶️"
            } else {
                cell?.textField?.stringValue = track.position
            }
            cell?.textField?.alignment = .center
        case "title":
            cell?.textField?.stringValue = track.title
            cell?.textField?.alignment = .left
        case "duration":
            cell?.textField?.stringValue = track.duration ?? "--:--"
            cell?.textField?.alignment = .right
        default:
            return nil
        }
        
        return cell
    }
    
    // MARK: - TableView Delegate
    
    /**
     Called when the table view selection changes. Updates the current track index and control state
     in the AppDelegate.
     */
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let appDelegate = NSApplication.shared.delegate as? AppDelegate else { return }
        let selectedRow = trackListTableView.selectedRow
        if selectedRow >= 0 && selectedRow < appDelegate.tracks.count {
            appDelegate.currentTrackIndex = selectedRow
            appDelegate.updateControlState()
        }
    }
    
    /**
     Reloads the track list on the main thread and forces a layout update.
     */
    public func reloadTrackList() {
        DispatchQueue.main.async { [weak self] in
            self?.trackListTableView.reloadData()
            // Force layout update
            self?.trackListTableView.needsLayout = true
            self?.trackListTableView.layoutSubtreeIfNeeded()
        }
    }
    
    // MARK: - NSWindowDelegate
    
    /**
     Handles the close button of the window. Instead of closing, it hides the window and updates the menu items.
     */
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Update state before hiding window
        isWindowVisible = false
        
        // Hide window instead of closing
        sender.orderOut(nil)
        
        // Update menu items
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            appDelegate.updateMenuItemsForWindowState()
        }
        
        return false
    }

    /**
     Refreshes the entire UI, including currently displayed track information, play/pause button, and progress bar.
     */
    func refreshUI() {
        guard let appDelegate = NSApplication.shared.delegate as? AppDelegate else { return }
        
        // Only update if we have tracks
        guard !appDelegate.tracks.isEmpty else {
            clearUI()
            return
        }
        
        // Get current track
        let track = appDelegate.tracks[appDelegate.currentTrackIndex]
        
        // Update track info
        trackTitleLabel.stringValue = track.title
        albumTitleLabel.stringValue = track.album
        artistLabel.stringValue = track.artist
        
        // Update play/pause button
        let symbolName = appDelegate.isPlaying ? "stop.fill" : "play.fill"
        let description = appDelegate.isPlaying ? "Stop" : "Play"
        playPauseButton.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: description)
        
        // Update progress and time
        updatePlaybackDisplay()
        
        // Update track list
        trackListTableView.reloadData()
        
        // Ensure table view is properly laid out
        trackListTableView.needsLayout = true
        trackListTableView.layoutSubtreeIfNeeded()
        
        // Force window update
        view.window?.viewsNeedDisplay = true
        view.window?.displayIfNeeded()
    }

    /**
     Updates and calculates the current playback progress, updating labels and progress bar accordingly.
     */
    func updatePlaybackDisplay() {
        guard let appDelegate = NSApplication.shared.delegate as? AppDelegate else { return }
        
        let currentMM = appDelegate.currentPlaybackSeconds / 60
        let currentSS = appDelegate.currentPlaybackSeconds % 60
        currentTimeLabel.stringValue = String(format: "%d:%02d", currentMM, currentSS)
        
        if let track = appDelegate.tracks[safe: appDelegate.currentTrackIndex],
           let duration = track.durationSeconds {
            let totalMM = duration / 60
            let totalSS = duration % 60
            totalTimeLabel.stringValue = String(format: "%d:%02d", totalMM, totalSS)
            
            let progress = Double(appDelegate.currentPlaybackSeconds) / Double(duration) * 100
            progressBar.doubleValue = progress
        } else {
            totalTimeLabel.stringValue = "--:--"
            progressBar.doubleValue = 0
        }
    }

    /**
     Clears all UI elements and resets progress/time to default values.
     */
    private func clearUI() {
        // Clear all UI elements
        trackTitleLabel.stringValue = ""
        albumTitleLabel.stringValue = ""
        artistLabel.stringValue = ""
        currentTimeLabel.stringValue = "0:00"
        totalTimeLabel.stringValue = "--:--"
        progressBar.doubleValue = 0
        albumArtworkView.image = nil
        trackListTableView.reloadData()
    }

    /**
     Called before the view appears. Re-assigns the window delegate to self to handle window actions properly.
     */
    override func viewWillAppear() {
        super.viewWillAppear()
        // Make sure window delegate is set
        view.window?.delegate = self
    }
}