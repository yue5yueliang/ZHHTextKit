//
//  DemoArtwork.swift
//  ZHHTextKit
//
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import CoreText
import UIKit
import ZHHTextKit

enum DemoArtwork {
    static func mark(side: CGFloat) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        return renderer.image { _ in
            let rect = CGRect(x: 1, y: 1, width: side - 2, height: side - 2)
            UIColor(red: 0.09, green: 0.45, blue: 0.95, alpha: 1).setFill()
            UIBezierPath(roundedRect: rect, cornerRadius: side * 0.18).fill()
            let text = "Z" as NSString
            let font = UIFont.boldSystemFont(ofSize: side * 0.52)
            let textSize = text.size(withAttributes: [.font: font])
            text.draw(
                at: CGPoint(x: (side - textSize.width) / 2, y: (side - textSize.height) / 2),
                withAttributes: [.font: font, .foregroundColor: UIColor.white]
            )
        }
    }

    static func stripes() -> UIImage {
        let size = CGSize(width: 20, height: 20)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor(red: 0.054, green: 0.879, blue: 0, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let cg = context.cgContext
            cg.setStrokeColor(UIColor(red: 0.869, green: 1, blue: 0.030, alpha: 1).cgColor)
            cg.setLineWidth(2)
            var x: CGFloat = 0
            while x < size.width * 2 {
                cg.move(to: CGPoint(x: x, y: -2))
                cg.addLine(to: CGPoint(x: x - size.height, y: size.height + 2))
                x += 4
            }
            cg.strokePath()
        }
    }

    static func face(shift: CGFloat) -> UIImage {
        let side: CGFloat = 32
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        return renderer.image { _ in
            UIColor.systemYellow.setFill()
            UIBezierPath(ovalIn: CGRect(x: 1, y: 1, width: 30, height: 30)).fill()
            UIColor.black.setFill()
            let eyeY = 10 + shift
            UIBezierPath(ovalIn: CGRect(x: 8, y: eyeY, width: 4, height: 5)).fill()
            UIBezierPath(ovalIn: CGRect(x: 20, y: eyeY, width: 4, height: 5)).fill()
            let smile = UIBezierPath()
            smile.move(to: CGPoint(x: 9, y: 18))
            smile.addQuadCurve(to: CGPoint(x: 23, y: 18), controlPoint: CGPoint(x: 16, y: 22 + shift))
            smile.lineWidth = 1.4
            UIColor.black.setStroke()
            smile.stroke()
        }
    }

    static func photo() -> UIImage {
        let size = CGSize(width: 108, height: 132)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            UIColor(red: 0.95, green: 0.55, blue: 0.25, alpha: 1).setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 10).fill()
            UIColor(red: 0.25, green: 0.55, blue: 0.85, alpha: 1).setFill()
            UIBezierPath(ovalIn: CGRect(x: 28, y: 24, width: 52, height: 52)).fill()
            UIColor.white.setFill()
            UIBezierPath(rect: CGRect(x: 0, y: 96, width: 108, height: 36)).fill()
            let title = "Photo" as NSString
            title.draw(at: CGPoint(x: 28, y: 104), withAttributes: [
                .font: UIFont.boldSystemFont(ofSize: 16),
                .foregroundColor: UIColor(red: 0.95, green: 0.45, blue: 0.15, alpha: 1)
            ])
        }
    }
}

