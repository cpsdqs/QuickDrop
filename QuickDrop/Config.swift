//
//  Config.swift
//  QuickDrop
//
//  Created by cpsd on 1.4.2017.
//  Copyright © 2017 cpsd. All rights reserved.
//

import Cocoa

class Config {
    let location = NSString(string: "~/.config/quickdrop-config").expandingTildeInPath
    var imgurToken: String!

    init () {
        let textContent = try? NSString(contentsOfFile: location, encoding: String.Encoding.utf8.rawValue)
        let lines = textContent?.components(separatedBy: "\n")
        imgurToken = lines?[0]
    }
}
