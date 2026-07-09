//
//  main.swift
//  Slack IOC Defanger
//
//  Created by Cody Dietz on 7/9/26.
//

import Cocoa

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// This starts the main run loop manually
app.run()
