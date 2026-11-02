//
//  DemoEntry.swift
//  ZHHTextKit
//
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import UIKit
import ZHHTextKit

struct DemoEntry {
    /// 标题。
    let title: String
    /// 副标题说明。
    let detail: String
    /// 创建对应页面。
    let make: () -> UIViewController
}

