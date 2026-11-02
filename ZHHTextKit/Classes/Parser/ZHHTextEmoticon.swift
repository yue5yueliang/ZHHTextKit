//
//  ZHHTextEmoticon.swift
//  ZHHTextKit
//
//  Created by 桃色三岁 on 2026/10/26.
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import UIKit

/// 表情相关的富文本属性键。
public enum ZHHTextEmoticonAttribute {
    /// 值为短码原文，例如 `[微笑]` 或 `:smile:`。
    public static let token = NSAttributedString.Key("com.zhhtext.emoticon.token")
}

/// 一条表情映射：短码 → 系统 emoji 或自定义图片。
public struct ZHHTextEmoticonItem {
    /// 替换载荷。
    public enum Payload {
        /// Unicode 表情字符，例如 `😄`。
        case emoji(String)
        /// 自定义图片。`sizeFactor` 相对正文字体 `lineHeight`（角色表情常用 1.35，符号常用 1.0）。
        case image(UIImage, sizeFactor: CGFloat)
    }

    /// 短码，例如 `[微笑]`、`:smile:`。
    public var token: String
    /// 替换内容。
    public var payload: Payload

    /// 系统 emoji 短码。
    /// - Parameters:
    ///   - token: 短码。
    ///   - emoji: Unicode 表情。
    public init(token: String, emoji: String) {
        self.token = token
        self.payload = .emoji(emoji)
    }

    /// 自定义图片短码。
    /// - Parameters:
    ///   - token: 短码。
    ///   - image: 表情图。
    ///   - sizeFactor: 相对 `font.lineHeight` 的边长倍数。
    public init(token: String, image: UIImage, sizeFactor: CGFloat = 1) {
        self.token = token
        self.payload = .image(image, sizeFactor: max(sizeFactor, 0.1))
    }

    /// 中括号短码便捷构造：`name` → `[name]`。
    /// - Parameters:
    ///   - name: 括号内名字，不含 `[]`。
    ///   - image: 表情图。
    ///   - sizeFactor: 相对行高倍数。
    public init(bracketName name: String, image: UIImage, sizeFactor: CGFloat = 1) {
        self.init(token: "[\(name)]", image: image, sizeFactor: sizeFactor)
    }
}

/// 把短码替换成 emoji / 图片附件；编辑器用 `NSTextAttachment`，Label 用 `labelCompatible` 转换。
public struct ZHHTextEmoticonMapper {
    /// 映射表。匹配时按短码从长到短，避免前缀误伤。
    public var items: [ZHHTextEmoticonItem]
    /// 替换后纯文字 / emoji 使用的属性（通常含 font、foregroundColor）。
    public var textAttributes: [NSAttributedString.Key: Any]

    /// - Parameters:
    ///   - items: 表情条目。
    ///   - font: 正文字体；写入 `textAttributes[.font]`。
    ///   - textColor: 正文颜色。
    public init(items: [ZHHTextEmoticonItem], font: UIFont, textColor: UIColor = .label) {
        self.items = items
        self.textAttributes = [
            .font: font,
            .foregroundColor: textColor
        ]
    }

    /// - Parameters:
    ///   - items: 表情条目。
    ///   - textAttributes: 完整文字属性。
    public init(items: [ZHHTextEmoticonItem], textAttributes: [NSAttributedString.Key: Any]) {
        self.items = items
        self.textAttributes = textAttributes
    }

    /// 正文字体；缺省时用 17pt 系统字体。
    public var font: UIFont {
        (textAttributes[.font] as? UIFont) ?? .systemFont(ofSize: 17)
    }

    /// 把纯文本里的短码一次性换成富文本（emoji + 附件）。
    /// - Parameter plain: 含短码的纯文本。
    /// - Returns: 已替换的富文本。
    public func attributedString(from plain: String) -> NSAttributedString {
        let mutable = NSMutableAttributedString(string: plain, attributes: textAttributes)
        _ = replaceShortcodes(in: mutable, caret: mutable.length)
        return mutable
    }

    /// 在已有富文本上替换短码，保留已有附件；返回调整后的光标位置。
    /// - Parameters:
    ///   - storage: 可写富文本（如 `UITextView.textStorage`）。
    ///   - caret: 替换前的 UTF-16 光标；落在被替换短码左侧时会按长度差平移。
    /// - Returns: 调整后的光标。
    @discardableResult
    public func replaceShortcodes(in storage: NSMutableAttributedString, caret: Int) -> Int {
        // 光标随每次替换的长度差平移，避免输入过程中跳位。
        var adjusted = caret
        // 长短码优先，避免 `:sm:` 抢先吃掉 `:smile:` 的前缀。
        let ordered = items.sorted { $0.token.count > $1.token.count }
        for item in ordered {
            let token = item.token
            guard !token.isEmpty else { continue }
            let piece = piece(for: item)
            let tokenLength = (token as NSString).length
            // emoji / 附件长度通常短于短码，delta 多为负。
            let delta = piece.length - tokenLength
            while true {
                // 每次从头扫：上一轮替换后索引已失效，不能沿用旧 location。
                let found = (storage.string as NSString).range(of: token)
                if found.location == NSNotFound { break }
                storage.replaceCharacters(in: found, with: piece)
                // 只挪「落在替换点右侧」的光标；左侧不受影响。
                if found.location < adjusted {
                    adjusted += delta
                }
            }
        }
        return max(0, min(adjusted, storage.length))
    }

    /// 单条表情对应的富文本片段（一个 emoji 串或一个 `NSTextAttachment`）。
    /// - Parameter item: 表情条目。
    /// - Returns: 可插入编辑器的片段。
    public func piece(for item: ZHHTextEmoticonItem) -> NSAttributedString {
        switch item.payload {
        case .emoji(let emoji):
            var attrs = textAttributes
            attrs[ZHHTextEmoticonAttribute.token] = item.token
            return NSAttributedString(string: emoji, attributes: attrs)
        case .image(let image, let sizeFactor):
            return imageAttachment(image: image, token: item.token, sizeFactor: sizeFactor)
        }
    }

    /// 把编辑区里的 `NSTextAttachment` 表情转成 Label 可画的 `ZHHTextInlineAttachment`。
    ///
    /// 只转换带 `ZHHTextEmoticonAttribute.token` 的附件，避免误伤其它图片附件。
    /// - Parameters:
    ///   - text: 编辑器富文本。
    ///   - font: Label 对齐用的正文字体。
    /// - Returns: 可供 `ZHHTextLabel` 使用的副本。
    public static func labelCompatible(_ text: NSAttributedString, alignedTo font: UIFont) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: text)
        let full = NSRange(location: 0, length: mutable.length)
        // 倒序枚举：替换会改后续下标，从后往前改不会踩到未处理的 range。
        mutable.enumerateAttribute(.attachment, in: full, options: [.reverse]) { value, range, _ in
            // UITextView 用系统 `NSTextAttachment`；无图的占位跳过。
            guard let attachment = value as? NSTextAttachment, let image = attachment.image else { return }
            // 只认带表情短码标记的附件，其它业务图不动。
            let hasToken = mutable.attribute(ZHHTextEmoticonAttribute.token, at: range.location, effectiveRange: nil) != nil
            guard hasToken else { return }
            // 优先沿用编辑器里算好的 bounds；缺省时退回一行高的方块。
            let size = attachment.bounds.size.width > 0
                ? attachment.bounds.size
                : CGSize(width: font.lineHeight, height: font.lineHeight)
            // Label 走 `ZHHTextInlineAttachment`，才能做行内排版。
            var replacement = NSMutableAttributedString(
                attributedString: ZHHTextInlineAttachment.image(image, size: size, alignedTo: font)
            )
            // 短码属性一并拷过去，方便后续再识别是哪条表情。
            if let token = mutable.attribute(ZHHTextEmoticonAttribute.token, at: range.location, effectiveRange: nil) {
                replacement.addAttribute(
                    ZHHTextEmoticonAttribute.token,
                    value: token,
                    range: NSRange(location: 0, length: replacement.length)
                )
            }
            mutable.replaceCharacters(in: range, with: replacement)
        }
        return mutable
    }

    // MARK: - 私有

    private func imageAttachment(image: UIImage, token: String, sizeFactor: CGFloat) -> NSAttributedString {
        // 边长相对正文字高缩放；角色表情常用 1.35，符号常用 1.0。
        let side = ceil(font.lineHeight * sizeFactor)
        let attachment = NSTextAttachment()
        attachment.image = image
        // y 按 descender 居中，避免图片贴基线显得偏上/偏下。
        let mid = font.descender + (font.lineHeight - side) * 0.5
        attachment.bounds = CGRect(x: 0, y: mid, width: side, height: side)
        let piece = NSMutableAttributedString(attachment: attachment)
        // 同步正文属性，并打上短码标记供 Label 转换识别。
        var attrs = textAttributes
        attrs[ZHHTextEmoticonAttribute.token] = token
        piece.addAttributes(attrs, range: NSRange(location: 0, length: piece.length))
        return piece
    }
}
