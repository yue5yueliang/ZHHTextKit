//
//  ZHHTextLayout.swift
//  ZHHTextKit
//
//  Created by 桃色三岁 on 2026/10/26.
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import UIKit

/// 一次排版的缓存键。相等性包含全文，避免只靠哈希时串到别的正文。
public struct ZHHTextLayoutKey: Hashable {
    /// 未截断的全文。
    public let sourceText: String
    /// 进程内哈希，覆盖链接、截断文案、样式和界面风格。
    ///
    /// `Hasher` 带随机种子，不能把该值写入磁盘。
    public let contentHash: Int
    /// 宽度，单位是 1/1000 point。`0` 表示宽度无效。
    public let widthBucket: Int
    /// 最大行数。`0` 表示不限制。
    public let numberOfLines: Int
    /// 是否按展开态排版。
    public let isExpanded: Bool

    /// - Parameters:
    ///   - sourceText: 未截断的全文。
    ///   - contentHash: 进程内内容哈希。
    ///   - widthBucket: 宽度桶，单位 1/1000 point。
    ///   - numberOfLines: 最大行数；`0` 表示不限制。
    ///   - isExpanded: 是否按展开态排版。
    public init(sourceText: String, contentHash: Int, widthBucket: Int, numberOfLines: Int, isExpanded: Bool) {
        self.sourceText = sourceText
        self.contentHash = contentHash
        self.widthBucket = widthBucket
        self.numberOfLines = numberOfLines
        self.isExpanded = isExpanded
    }
}

/// 供预取使用的排版输入。字段需要和 Label 当前配置一致，缓存才会命中。
public struct ZHHTextLayoutInput {
    /// 全文富文本，不含截断 token。
    public var attributedText: NSAttributedString
    /// 与全文对齐的链接。
    public var links: [ZHHTextLink]
    /// 排版宽度，单位 point。
    public var width: CGFloat
    /// 最大行数。`0` 表示不限制。
    public var numberOfLines: Int
    /// 是否展开。
    public var isExpanded: Bool
    /// 截断 token 和正文样式。
    public var style: ZHHTextStyle
    /// 折叠态文案。
    public var collapsedLinkText: String
    /// 展开态文案。
    public var expandedLinkText: String
    /// 是否绘制折叠文案。
    public var showsCollapsedToken: Bool
    /// 是否绘制展开文案。
    public var showsExpandedToken: Bool
    /// 省略号。`truncationToken` 非空时不使用。
    public var truncationEllipsis: String
    /// 折叠态的自定义截断片段。非空时替换省略号和 `collapsedLinkText`，整段可点。
    public var truncationToken: NSAttributedString?
    /// 颜色解析使用的界面风格，需要和 Label 所在界面一致。
    public var interfaceStyle: UIUserInterfaceStyle

    /// - Parameters:
    ///   - attributedText: 全文富文本，不含截断 token。
    ///   - links: 与全文对齐的链接。
    ///   - width: 排版宽度，单位 point。
    ///   - numberOfLines: 最大行数；`0` 表示不限制。
    ///   - isExpanded: 是否展开。
    ///   - style: 截断 token 和正文样式。
    ///   - collapsedLinkText: 折叠态文案。
    ///   - expandedLinkText: 展开态文案。
    ///   - showsCollapsedToken: 是否绘制折叠文案。
    ///   - showsExpandedToken: 是否绘制展开文案。
    ///   - truncationEllipsis: 省略号；`truncationToken` 非空时不使用。
    ///   - truncationToken: 自定义折叠截断片段。
    ///   - interfaceStyle: 颜色解析使用的界面风格。
    public init(
        attributedText: NSAttributedString,
        links: [ZHHTextLink],
        width: CGFloat,
        numberOfLines: Int,
        isExpanded: Bool,
        style: ZHHTextStyle = .body,
        collapsedLinkText: String = "全文",
        expandedLinkText: String = "收起",
        showsCollapsedToken: Bool = true,
        showsExpandedToken: Bool = true,
        truncationEllipsis: String = "…",
        truncationToken: NSAttributedString? = nil,
        interfaceStyle: UIUserInterfaceStyle = .unspecified
    ) {
        self.attributedText = attributedText
        self.links = links
        self.width = width
        self.numberOfLines = numberOfLines
        self.isExpanded = isExpanded
        self.style = style
        self.collapsedLinkText = collapsedLinkText
        self.expandedLinkText = expandedLinkText
        self.showsCollapsedToken = showsCollapsedToken
        self.showsExpandedToken = showsExpandedToken
        self.truncationEllipsis = truncationEllipsis
        self.truncationToken = truncationToken
        self.interfaceStyle = interfaceStyle
    }
}

/// 一次排版的结果。展示串可能包含截断 token，链接原文 range 不在这里改写。
public struct ZHHTextLayout {
    /// 生成这次结果的键。
    public let key: ZHHTextLayoutKey
    /// 占用尺寸，单位 point。
    public let size: CGSize
    /// 实际绘制的富文本。颜色已按界面风格解析。
    public let displayText: NSAttributedString
    /// 是否裁掉了超出行数的正文。展开后只要正文仍超过行数，该值仍为 true。
    public let isTruncated: Bool

    /// 行框，供绘制和命中使用。
    let lineLayout: ZHHTextLineLayout
    /// 展示串上的链接 id 到原文链接。
    let linksByID: [String: ZHHTextLink]
    /// 展示串中的截断 token 区间。没有可点 token 时为空。
    let truncationRange: NSRange?

    /// 公开构造只保留尺寸和展示串。点击命中需要引擎产出的完整结果。
    /// - Parameters:
    ///   - key: 这次结果的缓存键。
    ///   - size: 占用尺寸。
    ///   - displayText: 实际绘制的富文本。
    ///   - isTruncated: 是否裁掉了超出行数的正文。
    public init(
        key: ZHHTextLayoutKey,
        size: CGSize,
        displayText: NSAttributedString,
        isTruncated: Bool
    ) {
        self.init(
            key: key,
            size: size,
            displayText: displayText,
            isTruncated: isTruncated,
            lineLayout: ZHHTextLineLayout(lines: [], size: size),
            linksByID: [:],
            truncationRange: nil
        )
    }

    init(
        key: ZHHTextLayoutKey,
        size: CGSize,
        displayText: NSAttributedString,
        isTruncated: Bool,
        lineLayout: ZHHTextLineLayout,
        linksByID: [String: ZHHTextLink],
        truncationRange: NSRange?
    ) {
        self.key = key
        self.size = size
        self.displayText = displayText
        self.isTruncated = isTruncated
        self.lineLayout = lineLayout
        self.linksByID = linksByID
        self.truncationRange = truncationRange
    }
}

/// 跨视图共享的布局缓存。实现方应原样保存 `store` 收到的结果，不要自行拆开再组装。
public protocol ZHHTextLayoutCache: AnyObject {
    /// 读取已缓存的排版。未命中返回 nil。
    func layout(for key: ZHHTextLayoutKey) -> ZHHTextLayout?
    /// 写入排版结果。
    func store(_ layout: ZHHTextLayout, for key: ZHHTextLayoutKey)
    /// 清空缓存。
    func removeAll()
}
