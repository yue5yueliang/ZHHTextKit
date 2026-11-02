//
//  ZHHTextParseResult.swift
//  ZHHTextKit
//
//  Created by 桃色三岁 on 2026/10/26.
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import Foundation

/// 解析器的输出。`links` 的 range 与 `attributedText` 使用同一套全文坐标。
public struct ZHHTextParseResult {
    /// 已套用正文和链接样式的全文，不含截断 token。
    public let attributedText: NSAttributedString
    /// 按 location 升序、互不重叠的链接。
    public let links: [ZHHTextLink]

    /// - Parameters:
    ///   - attributedText: 已套用样式的全文，不含截断 token。
    ///   - links: 与全文对齐的链接。
    public init(attributedText: NSAttributedString, links: [ZHHTextLink]) {
        self.attributedText = attributedText
        self.links = links
    }
}
