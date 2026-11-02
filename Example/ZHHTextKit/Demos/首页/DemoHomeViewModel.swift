//
//  DemoHomeViewModel.swift
//  ZHHTextKit
//
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import UIKit

/// Demo 首页视图模型：提供目录数据。
final class DemoHomeViewModel {
    let title = "ZHHTextKit Demo"

    var entries: [DemoEntry] { DemoCatalog.entries }

    func entry(at index: Int) -> DemoEntry {
        entries[index]
    }

    var numberOfRows: Int { entries.count }
}
