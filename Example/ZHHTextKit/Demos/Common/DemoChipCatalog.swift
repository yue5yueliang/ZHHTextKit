//
//  DemoChipCatalog.swift
//  ZHHTextKit
//
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import UIKit
import ZHHTextKit

enum DemoChipCatalog {
    static let items: [(name: String, fill: UInt32, stroke: UInt32)] = [
        ("周末出游", 0xF07167, 0xE85D4C),
        ("咖啡探店", 0xE8A33A, 0xD4890A),
        ("数码测评", 0x4DB6A0, 0x2F9B7A),
        ("居家收纳", 0x5B9AED, 0x3B7DD8),
        ("健身打卡", 0xA78BFA, 0x8B5CF6),
        ("读书笔记", 0xEC4899, 0xDB2777),
        ("宠物日常", 0x94A3B8, 0x64748B)
    ]

    static func chip(at index: Int) -> ZHHTextChip {
        let item = items[index]
        return ZHHTextChip(name: item.name, fill: item.fill, stroke: item.stroke)
    }
}
