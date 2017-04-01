//
//  StatusButton.swift
//  QuickDrop
//
//  Created by cpsd on 21.12.2016.
//  Copyright © 2016 cpsd. All rights reserved.
//

import Cocoa

class StatusButton: NSStatusBarButton {
    var progress = 0.0
    var connecting = false
    var fileDragged: Event<String>?

    override func draw(_ dirtyRect: NSRect) {
        let barHeight = dirtyRect.height
        let width = barHeight * 0.8
        let image = NSImage(size: NSSize(width: width, height: barHeight))
        image.lockFocus()
        self.drawIcon(dirtyRect)
        image.unlockFocus()
        image.isTemplate = true
        self.image = image

        super.draw(dirtyRect)
    }

    func drawIcon(_ dirtyRect: NSRect) {
        if let context = NSGraphicsContext.current() {
            let ctx = context.cgContext
            let color = CGColor(gray: 0, alpha: 1)

            let midX = dirtyRect.midX - 4
            let midY = dirtyRect.midY

            ctx.setStrokeColor(color)
            ctx.setFillColor(color)
            ctx.setLineWidth(1)

            ctx.saveGState()
            ctx.translateBy(x: midX, y: midY)
            if connecting {
                ctx.rotate(by: CGFloat(.pi / 2 + 2 * .pi * CFAbsoluteTimeGetCurrent()))
            } else {
                ctx.rotate(by: CGFloat(Double.pi / 2))
            }
            ctx.beginPath()
            ctx.addArc(center: CGPoint(x: 0, y: 0),
                radius: 8, startAngle: 0, endAngle: CGFloat(.pi * (2 - 2 *
                progress)), clockwise: true)
            ctx.strokePath()
            ctx.restoreGState()

            ctx.beginPath()
            ctx.move(to: CGPoint(x: midX - 3, y: midY + 1))
            ctx.addLine(to: CGPoint(x: midX, y: midY + 4))
            ctx.addLine(to: CGPoint(x: midX + 3, y: midY + 1))
            ctx.move(to: CGPoint(x: midX, y: midY + 4))
            ctx.addLine(to: CGPoint(x: midX, y: midY - 4))
            ctx.strokePath()
        }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return NSDragOperation.copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard()

        if (pasteboard.types?.contains(NSFilenamesPboardType))! {
            let files = pasteboard.propertyList(forType: NSFilenamesPboardType) as! NSArray
            let path = files[0] as! NSString
            fileDragged?.raise(path as String)
        }
        return true
    }
}
