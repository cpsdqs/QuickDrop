//
//  Event.swift
//  QuickDrop
//
//  Created by cpsd on 23.12.2016.
//  Copyright © 2016 cpsd. All rights reserved.
//

import Cocoa

class Event<T>: NSObject {
    typealias EventHandler = (T) -> ()
    private var eventHandlers = [EventHandler]()

    func addHandler(_ handler: @escaping EventHandler) {
        eventHandlers.append(handler)
    }
    func raise(_ data: T) {
        for handler in eventHandlers {
            handler(data)
        }
    }
}
