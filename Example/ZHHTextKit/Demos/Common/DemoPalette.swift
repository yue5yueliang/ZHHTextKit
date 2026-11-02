//
//  DemoPalette.swift
//  ZHHTextKit
//
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import UIKit

/// Demo 共用语义色。
enum DemoPalette {
    static let link = UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(red: 0.55, green: 0.78, blue: 1, alpha: 1)
        }
        return UIColor(red: 0.08, green: 0.38, blue: 0.78, alpha: 1)
    }
    static let topic = UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(red: 1, green: 0.72, blue: 0.35, alpha: 1)
        }
        return UIColor(red: 0.78, green: 0.42, blue: 0.08, alpha: 1)
    }
    static let mention = UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(red: 0.55, green: 0.85, blue: 0.70, alpha: 1)
        }
        return UIColor(red: 0.05, green: 0.50, blue: 0.40, alpha: 1)
    }
    static let phone = UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(red: 0.78, green: 0.68, blue: 1, alpha: 1)
        }
        return UIColor(red: 0.38, green: 0.28, blue: 0.72, alpha: 1)
    }
}
