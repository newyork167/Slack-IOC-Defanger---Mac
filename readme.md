# Slack IOC Defanger (macOS)

A lightweight macOS native background utility that intercepts clipboard pastes (`Cmd + V`) into Slack to automatically defang Indicators of Compromise (IOCs). 

Built to prevent accidental unfurling or clicking of live malware domains and IP addresses in team channels, this tool lives in the macOS Menu Bar and rewrites URLs on the fly before they hit Slack's message queue.

## Features

* **Targeted Interception:** Uses a `CGEventTap` to globally monitor for `Cmd + V`. It only manipulates the clipboard if the active application bundle ID matches Slack (`com.tinyspeck.slackmacgap`).
* **Smart Defanging:** Converts protocols (`http/https` -> `hxxp/hxxps`) and brackets periods in domains/IPs (`.` -> `[.]`).
* **File Extension Ignore List:** Uses regex negative lookaheads to ensure standard file names (e.g., `malware.exe`, `payload.dll`) are not accidentally mangled into `malware[.]exe`.

The regex targets three specific structures:
- **Explicit URLs:** Anything starting with `http://`, `https://`, or `www.`.
- **IPv4 Addresses:** Standard 4-octet boundaries.
- **Bare Domains:** `word.word` structures, specifically ignoring a predefined list of file extensions (e.g., `.exe`, `.dll`, `.bin`, `.zip`, `.py`).


* **Menu Bar Control:** Sits cleanly in the menu bar (using a ladybug icon) allowing you to toggle the defanging logic on/off or quit the app instantly.

## How It Works

When `Cmd + V` is pressed, the event tap intercepts the keystroke before the OS routes it to the foreground app. If the foreground app is Slack, the utility reads the general `NSPasteboard`, applies a Swift-based regex transformation to defang any matched IOCs, updates the pasteboard, and then passes the `Cmd + V` event forward to execute the paste.

## Getting Started

### Prerequisites
* macOS 12+ (Monterey or newer recommended)
* Xcode

### Building from Source
- Clone the repository and open the `.xcodeproj` file in Xcode.
- **Disable the Sandbox:** In the project settings, navigate to the **Signing & Capabilities** tab. If **App Sandbox** is listed, click the trash can icon to delete it. `CGEventTap` cannot intercept global keystrokes if the app is sandboxed.
- Build and run the app (`Cmd + R`).

### Granting Permissions
Because this app intercepts global keystrokes, macOS requires explicit consent.

On the first run, OSX _should_ ask you to do this, but if it does not, here are the steps:
- The first time you run the app, macOS will block it and prompt you to grant **Accessibility** permissions.
- Go to `System Settings > Privacy & Security > Accessibility`.
- Toggle the switch ON for the defanger app.
- Restart the app for the permissions to take effect.

*Note: If you recompile the app frequently during development, macOS may silently invalidate the permission. If it stops working, remove the app from the Accessibility list entirely using the `-` button, re-run the app, and approve the new prompt.*

## Configuration

To add more file extensions to the ignore list, edit the `pattern` variable in the `defangURLs(in:)` function:

```swift
// Add new extensions to this group, separated by a pipe (|)
(?!(?:exe|dll|bin|sys|elf|sh|bat|txt|log|csv|zip|rar|tar|gz|7z|pdf|docx?|xlsx?|py|js|ps1|apk|msi)\b)
