//
//  ZHHTextLongPressInfo.swift
//  ZHHTextKit
//
//  Created by 桃色三岁 on 2026/11/02.
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import UIKit

/// 长按回调上下文。库不弹菜单、不写剪贴板，由业务自行组装。
public struct ZHHTextLongPressInfo: Equatable {

    /// 长按落点上的内容种类。
    public enum Kind: Equatable {
        /// 普通正文。
        case body
        /// 正文链接。
        case link(ZHHTextLink)
        /// 「全文 / 收起」截断 token。
        case expand
        /// 空白或未命中可点内容。
        case empty
    }

    /// 相对 `ZHHTextLabel` bounds 的触点。
    public let point: CGPoint
    /// 命中种类。
    public let kind: Kind
    /// 未截断纯文本，最常用的复制源。
    public let plainText: String
    /// 当前展示串纯文本；折叠态可能含「…全文」，展开态可能含「收起」。
    public let visibleText: String
    /// 未截断富文本。
    public let attributedText: NSAttributedString
    /// 展示串上的命中区间；`empty` 时为 `nil`。
    public let displayRange: NSRange?

    /// - Parameters:
    ///   - point: 相对 Label 的触点。
    ///   - kind: 命中种类。
    ///   - plainText: 未截断纯文本。
    ///   - visibleText: 当前展示串纯文本。
    ///   - attributedText: 未截断富文本。
    ///   - displayRange: 展示串命中区间；空白时传 `nil`。
    public init(
        point: CGPoint,
        kind: Kind,
        plainText: String,
        visibleText: String,
        attributedText: NSAttributedString,
        displayRange: NSRange?
    ) {
        self.point = point
        self.kind = kind
        self.plainText = plainText
        self.visibleText = visibleText
        self.attributedText = attributedText
        self.displayRange = displayRange
    }
}
