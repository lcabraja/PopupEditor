import AppKit
import WebKit
import Carbon.HIToolbox
import Foundation

// Custom window that can become key (required for borderless windows to receive keyboard input)
class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

class AppDelegate: NSObject, NSApplicationDelegate, WKScriptMessageHandler, WKNavigationDelegate, NSWindowDelegate {
    var window: KeyableWindow!
    var webView: WKWebView!
    var hotKeyRef: EventHotKeyRef?
    var eventMonitor: Any?
    var statusItem: NSStatusItem?
    var previousApp: NSRunningApplication?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupEditMenu()
        createWindow()
        createStatusItem()
        registerHotKey()
        setupEventMonitor()
    }
    
    func setupEditMenu() {
        // Create Edit menu for copy/paste to work
        let mainMenu = NSMenu()
        
        let editMenuItem = NSMenuItem()
        editMenuItem.title = "Edit"
        let editMenu = NSMenu(title: "Edit")
        
        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)
        
        NSApp.mainMenu = mainMenu
    }
    
    func createStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "pencil.and.outline", accessibilityDescription: "Popup Editor")
            button.action = #selector(statusBarButtonClicked(_:))
        }
    }
    
    @objc func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Toggle Editor", action: #selector(toggleWindowAction), keyEquivalent: "e"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitAction), keyEquivalent: "q"))
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil // Reset so simple click works next time if we want logic there
    }
    
    @objc func toggleWindowAction() {
        toggleWindow()
    }

    @objc func quitAction() {
        NSApp.terminate(nil)
    }

    func createWindow() {
        let screen = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let size = NSSize(width: 900, height: 550)
        let origin = NSPoint(
            x: screen.midX - size.width / 2,
            y: screen.midY - size.height / 2
        )

        window = KeyableWindow(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let visual = NSVisualEffectView(frame: window.contentView!.bounds)
        visual.autoresizingMask = [.width, .height]
        visual.material = .hudWindow
        visual.state = .active
        visual.blendingMode = .behindWindow
        visual.wantsLayer = true
        // visual.layer?.cornerRadius = 14
        // visual.layer?.masksToBounds = true

        let config = WKWebViewConfiguration()
        config.userContentController.add(self, name: "saveText")
        config.userContentController.add(self, name: "showLanguageSelector")
        
        webView = WKWebView(frame: visual.bounds, configuration: config)
        webView.autoresizingMask = [.width, .height]
        webView.setValue(false, forKey: "drawsBackground")
        webView.enclosingScrollView?.drawsBackground = false
        
        visual.addSubview(webView)

        window.contentView = visual
        window.delegate = self
        window.orderOut(nil)
        
        // Ensure web view can become first responder and handle input
        window.initialFirstResponder = webView

        loadEditor()
    }
    
    func windowDidResignKey(_ notification: Notification) {
        // Close window when it loses focus
        window.orderOut(nil)
    }

    func setupEventMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            
            let isCmd = event.modifierFlags.contains(.command)
            
            // Cmd+ESC: close and clear contents
            if event.keyCode == 53 && isCmd {
                self.clearAndClose()
                return nil
            }
            
            // ESC alone: just close
            if event.keyCode == 53 {
                self.window.orderOut(nil)
                return nil
            }
            
            // Cmd+R: show language selector
            if event.keyCode == 15 && isCmd { // R key
                self.webView.evaluateJavaScript("window.showLanguageSelector && window.showLanguageSelector()", completionHandler: nil)
                return nil
            }
            
            // Cmd+Enter: paste into previous app
            if event.keyCode == 36 && isCmd { // Enter key
                self.pasteIntoPreviousApp()
                return nil
            }
            
            return event
        }
    }
    
    func pasteIntoPreviousApp() {
        // Get the current editor content and copy to clipboard
        webView.evaluateJavaScript("window.getEditorValue ? window.getEditorValue() : ''") { [weak self] result, error in
            guard let self = self, let text = result as? String else { return }
            
            // Copy to clipboard
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            
            // Close window
            self.window.orderOut(nil)
            
            // Activate the previous app and simulate Cmd+V
            if let prevApp = self.previousApp {
                prevApp.activate(options: .activateIgnoringOtherApps)
                
                // Small delay to ensure app is activated before pasting
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.simulatePaste()
                }
            }
        }
    }
    
    func simulatePaste() {
        // Create Cmd+V key event
        let source = CGEventSource(stateID: .hidSystemState)
        
        // Key down
        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) { // V key
            keyDown.flags = .maskCommand
            keyDown.post(tap: .cghidEventTap)
        }
        
        // Key up
        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) { // V key
            keyUp.flags = .maskCommand
            keyUp.post(tap: .cghidEventTap)
        }
    }
    
    func clearAndClose() {
        // Clear the editor
        webView.evaluateJavaScript("window.clearEditor && window.clearEditor()", completionHandler: nil)
        // Clear the saved file
        let fileURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".popupeditor")
            .appendingPathComponent("text")
        try? FileManager.default.removeItem(at: fileURL)
        // Close window
        window.orderOut(nil)
    }
    
    func getClipboardText() -> String? {
        return NSPasteboard.general.string(forType: .string)
    }

    func loadEditor() {
        guard let url = Bundle.module.url(forResource: "index", withExtension: "html", subdirectory: "Resources") else {
            print("index.html not found in Resources")
            return
        }
        webView.navigationDelegate = self
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Inject saved text after loading
        var textToLoad = loadSavedText()
        var isFromClipboard = false
        
        // If text is blank (empty or just the default placeholder), use clipboard
        let isBlank = textToLoad.isEmpty || textToLoad == "// Write something..."
        if isBlank, let clipboardText = getClipboardText(), !clipboardText.isEmpty {
            textToLoad = clipboardText
            isFromClipboard = true
        }
        
        // Simple JSON encoding to safely pass string to JS
        if let data = try? JSONEncoder().encode(textToLoad),
           let jsonString = String(data: data, encoding: .utf8) {
            let script = """
            if (window.setEditorValue) { 
                window.setEditorValue(\(jsonString), \(isFromClipboard)); 
            }
            """
            webView.evaluateJavaScript(script, completionHandler: nil)
        }
        
        // Detect language from first line magic comment like // lang: python
        if let firstLine = textToLoad.components(separatedBy: CharacterSet.newlines).first,
           firstLine.hasPrefix("// lang: ") {
            let lang = String(firstLine.dropFirst(9)).trimmingCharacters(in: .whitespaces)
            let script = "if (window.setLanguage) { window.setLanguage('\(lang)'); }"
            webView.evaluateJavaScript(script, completionHandler: nil)
        }
    }

    func loadSavedText() -> String {
        let fileURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".popupeditor")
            .appendingPathComponent("text")
        
        do {
            return try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            return "// Write something..."
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "saveText", let text = message.body as? String {
            saveText(text)
        }
    }

    func saveText(_ text: String) {
        let folderURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".popupeditor")
        let fileURL = folderURL.appendingPathComponent("text")
        
        do {
            if !FileManager.default.fileExists(atPath: folderURL.path) {
                try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            }
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to save text: \(error)")
        }
    }

    func toggleWindow() {
        if window.isVisible {
            window.orderOut(nil)
        } else {
            // Store the currently focused app before we take focus
            previousApp = NSWorkspace.shared.frontmostApplication
            
            window.center()
            // Important for agent apps to activate forcefully
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless() 
            // Focus webview
            webView.becomeFirstResponder()
        }
    }

    func registerHotKey() {
        let hotKeyID = EventHotKeyID(signature: OSType(UInt32(truncatingIfNeeded: 0x504F5050)), id: 1)
        // Cmd+Shift+E
        let keyCode: UInt32 = UInt32(kVK_ANSI_E)
        let modifiers: UInt32 = UInt32(cmdKey | shiftKey)

        let eventTarget = GetEventDispatcherTarget()
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, eventTarget, 0, &hotKeyRef)
        if status != noErr {
            print("RegisterEventHotKey failed: \(status)")
        }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(eventTarget, { (_, eventRef, _) -> OSStatus in
            var hkID = EventHotKeyID()
            GetEventParameter(eventRef,
                              EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID),
                              nil,
                              MemoryLayout<EventHotKeyID>.size,
                              nil,
                              &hkID)
            if hkID.id == 1 {
                if let delegate = NSApp.delegate as? AppDelegate {
                    delegate.toggleWindow()
                }
            }
            return noErr
        }, 1, &eventType, nil, nil)
    }
}

    @main
struct Main {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.setActivationPolicy(.accessory) // Agent app
        app.delegate = delegate
        app.run()
    }
}
