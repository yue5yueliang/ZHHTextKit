//
//  ZHHTextStyle.swift
//  ZHHTextKit
//
//  Created by 桃色三岁 on 2026/10/26.
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import UIKit

/// 富文本样式。颜色和字体都由调用方注入，组件不内置品牌色。
public struct ZHHTextStyle {

    // MARK: - 角色

    /// 正文样式角色。链接角色只描述字色和字体，不携带段落属性。
    public enum Role {
        /// 正文。
        case body
        /// 话题。
        case topic
        /// 提及。
        case mention
        /// URL。
        case url
        /// 电话。
        case phone
        /// 「全文 / 收起」截断 token。
        case truncation
    }

    // MARK: - 属性

    /// 正文字体。
    public var font: UIFont
    /// 正文颜色。
    public var textColor: UIColor
    /// 链接默认色。某一类链接未单独设色时使用该值。
    public var linkColor: UIColor
    /// 话题色。为空时使用 `linkColor`。
    public var topicColor: UIColor?
    /// 提及色。为空时使用 `linkColor`。
    public var mentionColor: UIColor?
    /// URL 色。为空时使用 `linkColor`。
    public var urlColor: UIColor?
    /// 电话色。为空时使用 `linkColor`。
    public var phoneColor: UIColor?
    /// 「全文 / 收起」颜色。
    public var truncationColor: UIColor
    /// 「全文 / 收起」字体。为空时使用 `font`。
    public var truncationFont: UIFont?
    /// 按下链接时的底色。
    public var highlightColor: UIColor
    /// 行间距，单位 point。
    public var lineSpacing: CGFloat
    /// 水平对齐。
    public var alignment: NSTextAlignment
    /// 换行方式。默认按字符换行，避免中文段落留下大块空白。
    public var lineBreakMode: NSLineBreakMode

    // MARK: - 预设与初始化

    /// 使用系统语义色的正文预设：`.label`、`.link`、`.quaternarySystemFill`。
    public static var body: ZHHTextStyle { ZHHTextStyle() }

    /// 创建样式。未单独指定的链接色会回落到 `linkColor`。
    /// - Parameters:
    ///   - font: 正文字体。
    ///   - textColor: 正文颜色。
    ///   - linkColor: 链接默认色。
    ///   - topicColor: 话题色；为空时用 `linkColor`。
    ///   - mentionColor: 提及色；为空时用 `linkColor`。
    ///   - urlColor: URL 色；为空时用 `linkColor`。
    ///   - phoneColor: 电话色；为空时用 `linkColor`。
    ///   - truncationColor: 「全文 / 收起」颜色。
    ///   - truncationFont: 「全文 / 收起」字体；为空时用 `font`。
    ///   - highlightColor: 按下链接时的底色。
    ///   - lineSpacing: 行间距，单位 point。
    ///   - alignment: 水平对齐。
    ///   - lineBreakMode: 换行方式。
    public init(
        font: UIFont = .preferredFont(forTextStyle: .body),
        textColor: UIColor = .label,
        linkColor: UIColor = .link,
        topicColor: UIColor? = nil,
        mentionColor: UIColor? = nil,
        urlColor: UIColor? = nil,
        phoneColor: UIColor? = nil,
        truncationColor: UIColor = .link,
        truncationFont: UIFont? = nil,
        highlightColor: UIColor = .quaternarySystemFill,
        lineSpacing: CGFloat = 2,
        alignment: NSTextAlignment = .natural,
        lineBreakMode: NSLineBreakMode = .byCharWrapping
    ) {
        self.font = font
        self.textColor = textColor
        self.linkColor = linkColor
        self.topicColor = topicColor
        self.mentionColor = mentionColor
        self.urlColor = urlColor
        self.phoneColor = phoneColor
        self.truncationColor = truncationColor
        self.truncationFont = truncationFont
        self.highlightColor = highlightColor
        self.lineSpacing = lineSpacing
        self.alignment = alignment
        self.lineBreakMode = lineBreakMode
    }
}

// MARK: - 取值

public extension ZHHTextStyle {

    /// 该角色使用的前景色。
    /// - Parameter role: 正文或链接角色。
    /// - Returns: 对应颜色；未单独配置的链接色回落到 `linkColor`。
    func color(for role: Role) -> UIColor {
        switch role {
        case .body:
            return textColor
        case .topic:
            return topicColor ?? linkColor
        case .mention:
            return mentionColor ?? linkColor
        case .url:
            return urlColor ?? linkColor
        case .phone:
            return phoneColor ?? linkColor
        case .truncation:
            return truncationColor
        }
    }

    /// 生成富文本属性。
    ///
    /// `body` 含段落样式。其余角色只含字体和前景色，应追加到已有正文属性上，避免一段文字被拆成多个段落。
    /// - Parameter role: 正文或链接角色。
    /// - Returns: 可直接写入 `NSAttributedString` 的属性字典。
    func attributes(for role: Role) -> [NSAttributedString.Key: Any] {
        let usedFont = role == .truncation ? (truncationFont ?? font) : font
        var attributes: [NSAttributedString.Key: Any] = [
            .font: usedFont,
            .foregroundColor: color(for: role)
        ]
        if role == .body {
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = lineSpacing
            paragraph.alignment = alignment
            paragraph.lineBreakMode = lineBreakMode
            attributes[.paragraphStyle] = paragraph
        }
        return attributes
    }
}
