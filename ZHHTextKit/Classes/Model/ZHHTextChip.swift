//
//  ZHHTextChip.swift
//  ZHHTextKit
//
//  Created by 桃色三岁 on 2026/10/26.
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import UIKit

/// 胶囊标签相关的富文本属性键。
public enum ZHHTextChipAttribute {
    /// 值为胶囊文案，例如 `周末出游`。
    public static let name = NSAttributedString.Key("com.zhhtext.chip.name")
}

/// 胶囊外观：填充、描边、内边距；编辑器画成图，Label 用 `ZHHTextBorder`。
public struct ZHHTextChipStyle {
    /// 填充色。
    public var fillColor: UIColor
    /// 描边色。
    public var strokeColor: UIColor
    /// 描边宽度。
    public var lineWidth: CGFloat
    /// 胶囊内文字颜色。
    public var textColor: UIColor
    /// 文字相对胶囊边缘的内边距（左右 / 上下）。
    public var contentInsets: UIEdgeInsets
    /// 编辑器位图左右透明边，避免标签与正文挤在一起，又不必在字符串里插空格。
    public var horizontalMargin: CGFloat
    /// Label 边框相对字形的外扩。
    public var labelOutsets: UIEdgeInsets
    /// Label 文案前的不换行空格个数。
    public var labelLeadingNBSPCount: Int
    /// Label 文案后缀（默认两个 NBSP + 普通空格）。
    public var labelTrailing: String

    /// - Parameters:
    ///   - fillColor: 填充色。
    ///   - strokeColor: 描边色。
    ///   - lineWidth: 描边宽度。
    ///   - textColor: 文字颜色。
    ///   - contentInsets: 内边距。
    ///   - horizontalMargin: 编辑器图左右透明边。
    ///   - labelOutsets: Label 边框外扩。
    ///   - labelLeadingNBSPCount: Label 前导 NBSP 个数。
    ///   - labelTrailing: Label 后缀。
    public init(
        fillColor: UIColor,
        strokeColor: UIColor,
        lineWidth: CGFloat = 1.5,
        textColor: UIColor = .white,
        contentInsets: UIEdgeInsets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10),
        horizontalMargin: CGFloat = 4,
        labelOutsets: UIEdgeInsets = UIEdgeInsets(top: 2, left: 5.5, bottom: 2, right: 8),
        labelLeadingNBSPCount: Int = 2,
        labelTrailing: String = "\u{00A0}\u{00A0} "
    ) {
        self.fillColor = fillColor
        self.strokeColor = strokeColor
        self.lineWidth = lineWidth
        self.textColor = textColor
        self.contentInsets = contentInsets
        self.horizontalMargin = horizontalMargin
        self.labelOutsets = labelOutsets
        self.labelLeadingNBSPCount = max(0, labelLeadingNBSPCount)
        self.labelTrailing = labelTrailing
    }

    /// 用 `0xRRGGBB` 便捷构造。
    /// - Parameters:
    ///   - fill: 填充色十六进制。
    ///   - stroke: 描边色十六进制。
    public init(fill: UInt32, stroke: UInt32) {
        self.init(fillColor: ZHHTextChipColor.rgb(fill), strokeColor: ZHHTextChipColor.rgb(stroke))
    }
}

/// 一颗正文胶囊：编辑器走 `NSTextAttachment`，Label 走文字 + `ZHHTextBorder`。
public struct ZHHTextChip {
    /// 显示文案。
    public var name: String
    /// 外观。
    public var style: ZHHTextChipStyle

    /// - Parameters:
    ///   - name: 胶囊文案。
    ///   - style: 外观。
    public init(name: String, style: ZHHTextChipStyle) {
        self.name = name
        self.style = style
    }

    /// 十六进制颜色便捷构造。
    /// - Parameters:
    ///   - name: 胶囊文案。
    ///   - fill: 填充色。
    ///   - stroke: 描边色。
    public init(name: String, fill: UInt32, stroke: UInt32) {
        self.init(name: name, style: ZHHTextChipStyle(fill: fill, stroke: stroke))
    }

    /// 编辑器用：单字符 `NSTextAttachment`；间距画在图里。
    /// - Parameters:
    ///   - font: 胶囊内文字字体。
    ///   - paragraph: 可选段落样式，写入附件字符。
    /// - Returns: 可插入 `UITextView` 的片段。
    public func piece(font: UIFont = .boldSystemFont(ofSize: 15), paragraph: NSParagraphStyle? = nil) -> NSAttributedString {
        let image = renderPill(font: font)
        let attachment = NSTextAttachment()
        attachment.image = image
        // y 按 descender 居中，避免胶囊贴基线偏上/偏下。
        let mid = font.descender + (font.lineHeight - image.size.height) * 0.5
        attachment.bounds = CGRect(x: 0, y: mid, width: image.size.width, height: image.size.height)

        var attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            ZHHTextChipAttribute.name: name
        ]
        if let paragraph = paragraph {
            attrs[.paragraphStyle] = paragraph
        }
        let chip = NSMutableAttributedString(attachment: attachment)
        chip.addAttributes(attrs, range: NSRange(location: 0, length: chip.length))
        return chip
    }

    /// Label 用：边框画在文字上（CoreText 不走 UIKit Attachment）。
    /// - Parameters:
    ///   - font: 胶囊内文字字体。
    ///   - paragraph: 可选段落样式。
    /// - Returns: 可供 `ZHHTextLabel` 直接展示的片段。
    public func labelPiece(font: UIFont = .boldSystemFont(ofSize: 15), paragraph: NSParagraphStyle? = nil) -> NSAttributedString {
        // 前后 NBSP / 空格撑出边框外扩空间，本身不画边框。
        let leading = String(repeating: "\u{00A0}", count: style.labelLeadingNBSPCount)
        let trailing = style.labelTrailing
        // 字间插入 WJ（U+2060），降低中文名在窄宽下被拆行的概率。
        let display = name.map(String.init).joined(separator: "\u{2060}")
        var attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: style.textColor
        ]
        if let paragraph = paragraph {
            attrs[.paragraphStyle] = paragraph
        }
        let piece = NSMutableAttributedString(string: leading + display + trailing, attributes: attrs)
        // 边框只盖在文案上，不包含前后占位，点击热区也对齐这段。
        let tagRange = NSRange(location: (leading as NSString).length, length: (display as NSString).length)
        // cornerRadius 给大值，短边一半时由排版侧收成胶囊。
        let border = ZHHTextBorder(
            fillColor: style.fillColor,
            strokeColor: style.strokeColor,
            lineWidth: style.lineWidth,
            cornerRadius: 100,
            outsets: style.labelOutsets
        )
        piece.addAttribute(ZHHTextAttachmentAttribute.border, value: border, range: tagRange)
        // 打上名称标记，方便后续命中或业务识别。
        piece.addAttribute(ZHHTextChipAttribute.name, value: name, range: tagRange)
        return piece
    }

    /// 把编辑区里的胶囊附件转成 Label 可画的 `ZHHTextInlineAttachment`。
    ///
    /// 只转换带 `ZHHTextChipAttribute.name` 的附件，避免误伤其它图片。
    /// - Parameters:
    ///   - text: 编辑器富文本。
    ///   - font: Label 对齐用的正文字体。
    /// - Returns: 可供 `ZHHTextLabel` 使用的副本。
    public static func labelCompatible(_ text: NSAttributedString, alignedTo font: UIFont) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: text)
        let full = NSRange(location: 0, length: mutable.length)
        // 倒序枚举：替换会改后续下标，从后往前改不会踩到未处理的 range。
        mutable.enumerateAttribute(.attachment, in: full, options: [.reverse]) { value, range, _ in
            guard let attachment = value as? NSTextAttachment, let image = attachment.image else { return }
            // 只认带胶囊标记的附件。
            let hasName = mutable.attribute(ZHHTextChipAttribute.name, at: range.location, effectiveRange: nil) != nil
            guard hasName else { return }
            let size = attachment.bounds.size.width > 0 ? attachment.bounds.size : image.size
            var replacement = NSMutableAttributedString(
                attributedString: ZHHTextInlineAttachment.image(image, size: size, alignedTo: font)
            )
            // 文案标记一并拷过去，方便后续再识别。
            if let name = mutable.attribute(ZHHTextChipAttribute.name, at: range.location, effectiveRange: nil) {
                replacement.addAttribute(
                    ZHHTextChipAttribute.name,
                    value: name,
                    range: NSRange(location: 0, length: replacement.length)
                )
            }
            mutable.replaceCharacters(in: range, with: replacement)
        }
        return mutable
    }

    /// 光标紧贴胶囊后、或选区碰到胶囊时，返回该附件的整段范围。
    /// - Parameters:
    ///   - storage: 富文本（如 `textStorage`）。
    ///   - range: 当前选区；长度为 0 时探测光标左侧一格。
    /// - Returns: 胶囊有效属性区间；未命中则为 `nil`。
    public static func attachmentRange(in storage: NSAttributedString, touching range: NSRange) -> NSRange? {
        guard storage.length > 0 else { return nil }
        let probe: Int
        if range.length == 0 {
            // 退格场景：光标在胶囊正后方，探左侧字符。
            guard range.location > 0 else { return nil }
            probe = range.location - 1
        } else {
            probe = min(range.location, storage.length - 1)
        }
        guard probe >= 0, probe < storage.length else { return nil }
        var effective = NSRange()
        guard storage.attribute(ZHHTextChipAttribute.name, at: probe, effectiveRange: &effective) != nil else {
            return nil
        }
        return effective
    }

    // MARK: - 私有

    private func renderPill(font: UIFont) -> UIImage {
        // 内边距决定胶囊本体大小；左右透明 margin 负责与正文/邻标签的间距。
        let padX = style.contentInsets.left
        let padY = style.contentInsets.top
        let marginX = style.horizontalMargin
        let textSize = (name as NSString).size(withAttributes: [.font: font])
        // 高度至少贴近一行，避免矮字时胶囊显得过扁。
        let pillSize = CGSize(
            width: ceil(textSize.width + padX + style.contentInsets.right),
            height: ceil(max(textSize.height + padY + style.contentInsets.bottom, font.lineHeight + 2))
        )
        // 最终位图宽 = 胶囊 + 两侧透明边；字符串里就不必再插空格。
        let size = CGSize(width: pillSize.width + marginX * 2, height: pillSize.height)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            // 描边向内收半个线宽，避免抗锯齿被裁切。
            let inset = style.lineWidth * 0.5
            let rect = CGRect(x: marginX, y: 0, width: pillSize.width, height: pillSize.height)
                .insetBy(dx: inset, dy: inset)
            // 圆角取半高，短标签自然收成胶囊。
            let path = UIBezierPath(roundedRect: rect, cornerRadius: pillSize.height * 0.5)
            style.fillColor.setFill()
            path.fill()
            style.strokeColor.setStroke()
            path.lineWidth = style.lineWidth
            path.stroke()
            // 文案在胶囊矩形内水平/垂直居中（相对含 margin 的画布）。
            let textRect = CGRect(
                x: marginX + (pillSize.width - textSize.width) * 0.5,
                y: (pillSize.height - textSize.height) * 0.5,
                width: textSize.width,
                height: textSize.height
            )
            (name as NSString).draw(in: textRect, withAttributes: [
                .font: font,
                .foregroundColor: style.textColor
            ])
        }
    }
}

/// 编辑区胶囊：退格一次整颗删掉。
///
/// 使用 TextKit 1 文本栈，避免 TextKit 2 下 `NSTextAttachment` 表现不一致。
open class ZHHTextChipTextView: UITextView {
    /// 组装 TextKit 1 的 storage / layout / container。
    public static func make() -> ZHHTextChipTextView {
        let storage = NSTextStorage()
        let layout = NSLayoutManager()
        let container = NSTextContainer()
        container.widthTracksTextView = true
        storage.addLayoutManager(layout)
        layout.addTextContainer(container)
        return ZHHTextChipTextView(frame: .zero, textContainer: container)
    }

    open override func deleteBackward() {
        let selection = selectedRange
        // 直接整段替换；只改 selectedRange 再 super.deleteBackward 经常仍只删 1 个字符。
        if let chip = ZHHTextChip.attachmentRange(in: textStorage, touching: selection) {
            textStorage.replaceCharacters(in: chip, with: "")
            selectedRange = NSRange(location: chip.location, length: 0)
            delegate?.textViewDidChange?(self)
            return
        }
        super.deleteBackward()
    }
}

enum ZHHTextChipColor {
    static func rgb(_ hex: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
