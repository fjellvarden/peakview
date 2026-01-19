//
//  PeakviewApp.swift
//  Peakview
//
//  Created by Kristoffer Follestad on 18/01/2026.
//

import SwiftUI

@main
struct PeakviewApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Window("Peakview", id: "main") {
            ContentView()
        }

        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Start as accessory app (no dock icon)
        NSApp.setActivationPolicy(.accessory)
        setupMenuBar()
    }

    /// Prevent app from quitting when window is closed (menu bar app behavior)
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    func applicationDidResignActive(_ notification: Notification) {
        // Check if all windows are closed, if so, hide dock icon
        updateDockIconVisibility()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(named: "peakview-menubar-icon")
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
        }

        // Create right-click menu
        menu = NSMenu()
        menu?.addItem(NSMenuItem(title: "Open Peakview", action: #selector(openMainWindow), keyEquivalent: "o"))
        menu?.addItem(NSMenuItem.separator())
        menu?.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu?.addItem(NSMenuItem.separator())
        menu?.addItem(NSMenuItem(title: "Quit Peakview", action: #selector(quitApp), keyEquivalent: "q"))
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            // Right-click: show menu
            statusItem?.menu = menu
            statusItem?.button?.performClick(nil)
            statusItem?.menu = nil  // Reset so left-click works next time
        } else {
            // Left-click: toggle window
            toggleMainWindow()
        }
    }

    private func toggleMainWindow() {
        // Find the main window
        let mainWindow = NSApp.windows.first { window in
            window.level == .normal &&
            window.title == "Peakview" &&
            !window.className.contains("Settings")
        }

        if let window = mainWindow, window.isVisible, NSApp.isActive {
            // Window is open and app is active - close it
            window.close()
            hideDockIcon()
        } else {
            // Window is closed or app not active - open it
            openMainWindow()
        }
    }

    @objc func openMainWindow() {
        // Show dock icon when opening window
        showDockIcon()
        
        // Find the main content window (normal level, not status bar or settings)
        let mainWindow = NSApp.windows.first { window in
            window.level == .normal &&
            window.title == "Peakview" &&
            !window.className.contains("Settings")
        }

        if let window = mainWindow {
            window.makeKeyAndOrderFront(nil)
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        // Simulate Cmd+, keyboard shortcut to open settings
        DispatchQueue.main.async {
            let event = NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: .command,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: ",",
                charactersIgnoringModifiers: ",",
                isARepeat: false,
                keyCode: 43  // comma key
            )
            if let event = event {
                NSApp.sendEvent(event)
            }
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
    
    // MARK: - Dock Icon Management
    
    private func showDockIcon() {
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }
    }
    
    private func hideDockIcon() {
        if NSApp.activationPolicy() != .accessory {
            NSApp.setActivationPolicy(.accessory)
        }
    }
    
    private func updateDockIconVisibility() {
        // Check if any main windows are visible
        let hasVisibleMainWindow = NSApp.windows.contains { window in
            window.level == .normal &&
            window.title == "Peakview" &&
            !window.className.contains("Settings") &&
            window.isVisible
        }
        
        if hasVisibleMainWindow {
            showDockIcon()
        } else {
            hideDockIcon()
        }
    }
}

/// Helper to close the main window
enum WindowManager {
    static func closeMainWindow() {
        DispatchQueue.main.async {
            for window in NSApp.windows {
                if window.level == .normal &&
                   window.title == "Peakview" &&
                   !window.className.contains("Settings") {
                    window.close()
                    // Hide dock icon when closing via WindowManager
                    if NSApp.activationPolicy() != .accessory {
                        NSApp.setActivationPolicy(.accessory)
                    }
                    break
                }
            }
        }
    }
}
