//
//  AppDelegate.swift
//  Slack IOC Defanger
//
//  Created by Cody Dietz on 7/9/26.
//

import Cocoa
import ApplicationServices
import Foundation

// 1. Global state toggle accessible by the C-style callback
var isDefangingEnabled = true


class AppDelegate: NSObject, NSApplicationDelegate {
    
    // 2. Define the status item
    var statusItem: NSStatusItem!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupMenuBar()
        setupEventTap()
    }
    
    func setupMenuBar() {
        // Create the status item in the system menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            if let button = statusItem.button {
                if let customIcon = NSImage(named: "DefangerIcon") {
                    // Force the image down to standard menu bar dimensions
                    customIcon.size = NSSize(width: 18, height: 18)
                    customIcon.isTemplate = true
                    button.image = customIcon
                    button.image?.accessibilityDescription = "Defanger"
                } else {
                    // FALLBACK: If the image fails to load, show the ladybug so you don't lose the app
                    button.image = NSImage(systemSymbolName: "ladybug", accessibilityDescription: "Defanger")
                    print("ERROR: Could not find 'DefangerIcon' in Assets.xcassets")
                }
            }
        }
        
        let menu = NSMenu()
        
        // Create the toggle item
        let toggleItem = NSMenuItem(title: "Defang Slack Pastes", action: #selector(toggleDefanging), keyEquivalent: "")
        toggleItem.state = isDefangingEnabled ? .on : .off
        menu.addItem(toggleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Add a clean way to quit the background app
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }
    
    @objc func toggleDefanging(_ sender: NSMenuItem) {
        isDefangingEnabled.toggle()
        // Update the checkmark in the menu to reflect the new state
        sender.state = isDefangingEnabled ? .on : .off
    }

    func setupEventTap() {
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: cgEventCallback,
            userInfo: nil
        ) else {
            print("Failed to create event tap. Ensure the app has Accessibility permissions.")
            NSApplication.shared.terminate(nil)
            return
        }

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }
}

// Global callback for the Event Tap
func cgEventCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    
    // 3. Early exit if the feature is toggled off from the menu bar
    guard isDefangingEnabled else {
        return Unmanaged.passRetained(event)
    }
    
    if type == .keyDown {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        if flags.contains(.maskCommand) && keyCode == 9 {
            if let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
               bundleID == "com.tinyspeck.slackmacgap" || bundleID == "com.tinyspeck.slackmacgap.mac" {
                
                if let clipboardString = NSPasteboard.general.string(forType: .string) {
                    let defangedString = defangURLs(in: clipboardString) // Calls your updated regex function
                    
                    if defangedString != clipboardString {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(defangedString, forType: .string)
                        Thread.sleep(forTimeInterval: 0.05)
                    }
                }
            }
        }
    }
    
    return Unmanaged.passRetained(event)
}

func defangURLs(in text: String) -> String {
    print("Defanging \(text)")
    
    let pattern = #"""
    (?:https?://|www\.)[^\s]+
    |
    \b(?:\d{1,3}\.){3}\d{1,3}\b
    |
    # You can uncomment some of these that are unfortunately TLDs now like zip
    \b[a-zA-Z0-9.-]+\.(?!(?:exe|dll|bin|sys|elf|sh|bat|txt|log|csv|zip|rar|tar|gz|7z|pdf|docx?|xlsx?|py|js|ps1|apk|msi)\b)[a-zA-Z]{2,15}\b(?:/[^\s]*)?
    """#
    
    // .allowCommentsAndWhitespace lets us use the multi-line, commented regex above
    guard let regex = try? NSRegularExpression(
        pattern: pattern,
        options: [.caseInsensitive, .allowCommentsAndWhitespace]
    ) else { return text }
    
    let nsString = text as NSString
    let results = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))

    var output = text
    
    // Iterate backwards to prevent string mutation from shifting upcoming match ranges
    for match in results.reversed() {
        let urlRange = match.range
        var urlString = nsString.substring(with: urlRange)
        
        urlString = urlString.replacingOccurrences(of: "http", with: "hxxp", options: .caseInsensitive)
        urlString = urlString.replacingOccurrences(of: ".", with: "[.]")
        
        let startIndex = output.index(output.startIndex, offsetBy: urlRange.location)
        let endIndex = output.index(startIndex, offsetBy: urlRange.length)
        output.replaceSubrange(startIndex..<endIndex, with: urlString)
    }
    
    return output
}
