import Cocoa
import CoreVideo
import os

// MARK: - Main Player View Controller
// Manages the main player window interface and track list
class ViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource, NSWindowDelegate {
    // MARK: - Playback UI Elements
    // Progress and time display
    public var progressBar: NSProgressIndicator!
    public var currentTimeLabel: NSTextField!
    public var totalTimeLabel: NSTextField!
    
    // Playback control buttons
    public var previousButton: NSButton!
    public var playPauseButton: NSButton!
    public var nextButton: NSButton!
    public var isPlaying = false
    
    // MARK: - Album Info UI Elements
    // Album artwork and metadata display
    public var albumArtworkView: NSImageView!
    public var trackTitleLabel: NSTextField!
    public var albumTitleLabel: NSTextField!
    public var artistLabel: NSTextField!
    
    // MARK: - Track List UI Elements
    // Scrollable track list table
    public var scrollView: NSScrollView!
    public var trackListTableView: NSTableView!
    private var controlsContainer: NSView!
    
    // MARK: - Window Management
    private let logger = Logger(subsystem: "com.vinyl.scrobbler", category: "ViewController")
    private var isWindowVisible = false
    private var updateTimer: Timer?
    
    // MARK: - Public Window Management
    public var isPlayerWindowVisible: Bool {
        return isWindowVisible
    }
    
    // Show the player window and bring it to front
    public func showPlayerWindow() {
        isWindowVisible = true
        view.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        refreshUI()
    }
    
    // Hide the player window
    public func hidePlayerWindow() {
        isWindowVisible = false
        view.window?.orderOut(nil)
    }
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Configure window delegate and update timer
        view.window?.delegate = self
        setupUpdateTimer()
        
        // Configure window properties
        configureWindow()
        
        // Set up UI components
        setupAlbumArtwork()
        setupTrackInfo()
        setupPlayerControls()
        setupTrackListTable()
        
        // Connect control buttons to AppDelegate actions
        connectControlActions()
    }
    
    // MARK: - UI Setup Methods
    private func setupUpdateTimer() {
        updateTimer = Timer(timeInterval: 0.1, target: self, selector: #selector(updateDisplay), userInfo: nil, repeats: true)
        RunLoop.main.add(updateTimer!, forMode: .common)
    }
    
    private func configureWindow() {
        guard let window = view.window else { return }
        window.title = "Vinyl Scrobbler"
        window.isOpaque = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.displaysWhenScreenProfileChanges = true
        NSAnimationContext.current.allowsImplicitAnimation = true
    }
    
    // Setup methods for UI components...
    // [Previous setupAlbumArtwork, setupTrackInfo, setupPlayerControls, setupTrackListTable methods remain the same]
    
    // MARK: - UI Update Methods
    @objc private func updateDisplay() {
        view.window?.viewsNeedDisplay = true
        view.needsDisplay = true
    }
    
    // Update play/pause button state and refresh track list
    @objc public func updatePlayPauseButton() {
        let symbolName = isPlaying ? "stop.fill" : "play.fill"
        let description = isPlaying ? "Stop" : "Play"
        playPauseButton.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: description)
        trackListTableView.reloadData()
    }
    
    // MARK: - Control Actions
    // Handle control button clicks by delegating to AppDelegate
    @objc private func previousTrackClicked() {
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            appDelegate.previousTrack(nil)
        }
    }
    
    @objc private func playPauseClicked() {
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            appDelegate.togglePlayPause(nil)
        }
    }
    
    @objc private func nextTrackClicked() {
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            appDelegate.nextTrack(nil)
        }
    }
    
    // MARK: - TableView DataSource & Delegate
    func numberOfRows(in tableView: NSTableView) -> Int {
        guard let appDelegate = NSApplication.shared.delegate as? AppDelegate else { return 0 }
        return appDelegate.tracks.count
    }
    
    // Configure and return table cells for track list
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
    
    // Handle track selection in table
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let appDelegate = NSApplication.shared.delegate as? AppDelegate else { return }
        let selectedRow = trackListTableView.selectedRow
        if selectedRow >= 0 && selectedRow < appDelegate.tracks.count {
            appDelegate.currentTrackIndex = selectedRow
            appDelegate.updateControlState()
        }
    }
    
    // MARK: - Public UI Update Methods
    // Reload track list with animation
    public func reloadTrackList() {
        DispatchQueue.main.async { [weak self] in
            self?.trackListTableView.reloadData()
            self?.trackListTableView.needsLayout = true
            self?.trackListTableView.layoutSubtreeIfNeeded()
        }
    }
    
    // Refresh all UI elements with current state
    public func refreshUI() {
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
    
    // Update playback progress display
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
    
    // Clear all UI elements
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
    
    // MARK: - Window Delegate
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        isWindowVisible = false
        sender.orderOut(nil)
        
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            appDelegate.updateMenuItemsForWindowState()
        }
        
        return false
    }
    
    // MARK: - Cleanup
    deinit {
        updateTimer?.invalidate()
        updateTimer = nil
    }
}
