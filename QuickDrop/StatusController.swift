//
//  StatusController.swift
//  QuickDrop
//
//  Created by cpsd on 21.12.2016.
//  Copyright © 2016 cpsd. All rights reserved.
//

import Cocoa
import Alamofire
import Magnet

class StatusController: NSObject {
    // the status bar item
    let statusItem = NSStatusBar.system().statusItem(withLength: -1)

    // the status bar button
    var statusButton: StatusButton!

    // config stuff
    var config: Config!

    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var cancelUploadItem: NSMenuItem!

    override func awakeFromNib() {
        // set menu
        statusItem.menu = statusMenu

        // apply subclass to the status button. This kind of feels like a hack
        object_setClass(statusItem.button, StatusButton.self)

        statusButton = statusItem.button! as! StatusButton

        statusButton.progress = 0
        statusButton.needsDisplay = true

        cancelUploadItem.isEnabled = false

        // register global hotkeys
        if let keyCombo = KeyCombo(keyCode: 21, cocoaModifiers: [NSEventModifierFlags.shift, NSEventModifierFlags.option, NSEventModifierFlags.command]) {
            let hotKey = HotKey(identifier: "ShiftOptionCommand4", keyCombo: keyCombo, target: self, action: #selector(uploadAreaO))
            hotKey.register()
        }
        if let keyCombo = KeyCombo(keyCode: 20, cocoaModifiers: [NSEventModifierFlags.shift, NSEventModifierFlags.option, NSEventModifierFlags.command]) {
            let hotKey = HotKey(identifier: "ShiftOptionCommand3", keyCombo: keyCombo, target: self, action: #selector(uploadScreenO))
            hotKey.register()
        }

        // init config
        config = Config()
    }

    var timer: Timer = Timer()
    func startAnimationLoop () {
        timer = Timer.scheduledTimer(withTimeInterval: 0.0016, repeats: true) {_ in
            self.statusButton.needsDisplay = true
        }
    }
    func stopAnimationLoop () {
        timer.invalidate()
    }

    var currentUpload: Request?
    var canceled = false

    func uploadRequest (_ filePath: String, _ saveIfFailed: Bool) {
        // use imgur token from config
        // or alert if it doesn't exist
        if config.imgurToken == nil || config.imgurToken.characters.count == 0 {
            let alert = NSAlert()
            alert.messageText = "No Imgur Token"
            alert.informativeText = "Put it in a file in ~/.config/quickdrop-config"
            alert.addButton(withTitle: "OK")
            alert.runModal()
            // don't return (so that it fails and the file is saved)
        }
        let headers = ["Authorization": "Client-ID \(config.imgurToken!)"]
        let url = "https://api.imgur.com/3/upload"
        let fileURL = URL(string: "file://\(filePath)")!

        cancelUploadItem.isEnabled = true

        statusButton.progress = 0.01
        statusButton.connecting = true
        statusButton.needsDisplay = true
        startAnimationLoop()

        currentUpload = Alamofire.upload(fileURL, to: url, headers: headers)
            .uploadProgress { progress in
            let prog = progress.fractionCompleted
            self.stopAnimationLoop()
            self.statusButton.connecting = false
            self.statusButton.progress = min(0.99, prog)
            self.statusButton.needsDisplay = true
            self.cancelUploadItem.title = "Cancel Upload (\(round(prog * 1000) / 10)%)"
        }.responseJSON { response in
            self.stopAnimationLoop()
            self.statusButton.connecting = false
            self.statusButton.progress = 0
            self.statusButton.needsDisplay = true
            self.cancelUploadItem.title = "Cancel Upload"
            self.cancelUploadItem.isEnabled = false

            var saveFile = false
            if response.response?.statusCode == 200 {
                if let result = response.result.value {
                    let data = (result as! NSDictionary).value(forKey: "data") as! NSDictionary
                    // use https link
                    let link = (data.value(forKey: "link") as! String).replacingOccurrences(of: "http:", with: "https:")

                    let notification = NSUserNotification()
                    notification.title = "Upload Complete"
                    notification.informativeText = link
                    notification.soundName = NSUserNotificationDefaultSoundName
                    NSUserNotificationCenter.default.deliver(notification)
                    NSPasteboard.general().clearContents()
                    NSPasteboard.general().writeObjects([link as NSPasteboardWriting])
                } else {
                    let notification = NSUserNotification()
                    notification.title = "No data received"
                    notification.informativeText = ""
                    notification.soundName = "Submarine"
                    NSUserNotificationCenter.default.deliver(notification)
                    if saveIfFailed {
                        saveFile = true
                    }
                }
            } else if !self.canceled {
                let notification = NSUserNotification()
                notification.title = "Upload failed"
                notification.informativeText = "Status: \(String(describing: response.response?.statusCode))"
                notification.soundName = "Sosumi"
                NSUserNotificationCenter.default.deliver(notification)
                if saveIfFailed {
                    saveFile = true
                }
                print(response)
            }

            if saveFile && !self.canceled {
                do {
                    // put file in desktop directory
                    let paths = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)
                    try FileManager.default.copyItem(at: fileURL, to: paths[0].appendingPathComponent("quickdrop-\(CFAbsoluteTimeGetCurrent()).png"))
                } catch {
                    print(error)
                }
            }
            self.canceled = false
        }
    }

    @objc public func uploadAreaO() {
        uploadArea(true)
    }

    @objc public func uploadScreenO() {
        uploadScreen(true)
    }

    func uploadArea(_ saveIfFailed: Bool) {
        let task = Process()
        let name = "quickdrop-\(CFAbsoluteTimeGetCurrent())"
        task.launchPath = "/usr/sbin/screencapture"
        task.arguments = ["-i", "/tmp/\(name).png"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        task.waitUntilExit()
        if (task.terminationStatus == 0) {
            uploadRequest("/tmp/\(name).png", saveIfFailed)
        }
    }

    func uploadScreen(_ saveIfFailed: Bool) {
        let task = Process()
        let name = "quickdrop-\(CFAbsoluteTimeGetCurrent())"
        task.launchPath = "/usr/sbin/screencapture"
        task.arguments = ["/tmp/\(name).png"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        task.waitUntilExit()
        if (task.terminationStatus == 0) {
            uploadRequest("/tmp/\(name).png", saveIfFailed)
        }
    }

    @IBAction func uploadAreaPressed(_ sender: NSMenuItem) {
        uploadArea(true)
    }

    @IBAction func uploadScreenPressed(_ sender: NSMenuItem) {
        uploadScreen(true)
    }

    @IBAction func uploadFilePressed(_ sender: NSMenuItem) {
        let dialog = NSOpenPanel()
        dialog.title = "Choose an image to upload"
        dialog.showsResizeIndicator = true
        dialog.showsHiddenFiles = false
        dialog.canChooseDirectories = false
        dialog.canCreateDirectories = false
        dialog.allowsMultipleSelection = false

        if dialog.runModal() == NSModalResponseOK {
            if dialog.urls.count != 0 {
                uploadRequest(dialog.urls[0].absoluteString, false)
            }
        }
    }

    @IBAction func cancelUploadPressed(_ sender: NSMenuItem) {
        if currentUpload != nil {
            canceled = true
            currentUpload?.cancel()
        }
    }
}
