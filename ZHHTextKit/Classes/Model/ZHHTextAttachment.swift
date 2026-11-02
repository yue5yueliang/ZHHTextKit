//
//  ZHHTextAttachment.swift
//  ZHHTextKit
//
//  Created by 桃色三岁 on 2026/10/26.
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import UIKit

/// 附件占位尺寸，单位 point。
public protocol ZHHTextAttachmentSizing: AnyObject {
    /// 排版占位。
    var layoutSize: CGSize { get }
}

/// 行内图片。`ZHHTextLabel` 会按 `layoutSize` 留空并画出 `image`。
public final class ZHHTextImageAttachment: NSObject, ZHHTextAttachmentSizing {
    /// 要绘制的图片。
    public let image: UIImage
    /// 占位尺寸。
    public let layoutSize: CGSize

    /// - Parameters:
    ///   - image: 图片。
    ///   - layoutSize: 占位。不传时用 `image.size`。
    public init(image: UIImage, layoutSize: CGSize? = nil) {
        self.image = image
        let resolved = layoutSize ?? image.size
        self.layoutSize = CGSize(width: max(resolved.width, 0), height: max(resolved.height, 0))
        super.init()
    }
}

/// 行内图层。`ZHHTextLabel` 会把它加为子图层并摆到对应字形上。
public final class ZHHTextLayerAttachment: NSObject, ZHHTextAttachmentSizing {
    /// 被挂到标签上的图层。同一个图层不要同时放进两段文字。
    public let layer: CALayer
    /// 占位尺寸。
    public let layoutSize: CGSize

    /// - Parameters:
    ///   - layer: 子图层，例如一段色块或自己在播的动画。
    ///   - layoutSize: 占位，一般等于图层的 `bounds.size`。
    public init(layer: CALayer, layoutSize: CGSize) {
        self.layer = layer
        self.layoutSize = CGSize(width: max(layoutSize.width, 0), height: max(layoutSize.height, 0))
        super.init()
    }
}

/// 行内视图。`ZHHTextLabel` 会把它加为子视图并摆到对应字形上。
public final class ZHHTextViewAttachment: NSObject, ZHHTextAttachmentSizing {
    /// 被挂到标签上的视图。同一个视图不要同时放进两段文字。
    public let view: UIView
    /// 占位尺寸。
    public let layoutSize: CGSize

    /// - Parameters:
    ///   - view: 子视图，例如 `UISwitch`。
    ///   - layoutSize: 占位，一般等于视图的 `bounds.size`。
    public init(view: UIView, layoutSize: CGSize) {
        self.view = view
        self.layoutSize = CGSize(width: max(layoutSize.width, 0), height: max(layoutSize.height, 0))
        super.init()
    }
}

/// 边框描边样式。
public enum ZHHTextBorderStrokeStyle {
    /// 实线。
    case solid
    /// 线段虚线，使用 `lineDash`；为空时退回实线。
    case dash
    /// 圆点虚线：`[0, width*3]` + round cap。
    case circleDot
}

/// 包住一段文字的圆角框。`ZHHTextLabel` 会画在字形后面。
public final class ZHHTextBorder: NSObject {
    /// 填充色。为空则不填充。
    public var fillColor: UIColor?
    /// 描边色。为空则不描边。
    public var strokeColor: UIColor?
    /// 描边宽度。
    public var lineWidth: CGFloat
    /// 圆角。大于边框短边一半时画成胶囊。
    public var cornerRadius: CGFloat
    /// 相对字形向外扩张的边距。
    public var outsets: UIEdgeInsets
    /// 描边样式。默认实线；传了非空 `lineDash` 且未指定时按虚线。
    public var strokeStyle: ZHHTextBorderStrokeStyle
    /// 虚线间隔，仅 `strokeStyle == .dash` 时生效。空数组表示实线。
    public var lineDash: [CGFloat]

    /// - Parameters:
    ///   - fillColor: 填充色；为空则不填充。
    ///   - strokeColor: 描边色；为空则不描边。
    ///   - lineWidth: 描边宽度。
    ///   - cornerRadius: 圆角。
    ///   - outsets: 相对字形向外扩张的边距。
    ///   - strokeStyle: 描边样式；为 nil 时按 `lineDash` 是否为空推断。
    ///   - lineDash: 虚线间隔；空数组表示实线。
    public init(
        fillColor: UIColor? = nil,
        strokeColor: UIColor? = nil,
        lineWidth: CGFloat = 0,
        cornerRadius: CGFloat = 0,
        outsets: UIEdgeInsets = .zero,
        strokeStyle: ZHHTextBorderStrokeStyle? = nil,
        lineDash: [CGFloat] = []
    ) {
        self.fillColor = fillColor
        self.strokeColor = strokeColor
        self.lineWidth = lineWidth
        self.cornerRadius = cornerRadius
        self.outsets = outsets
        self.lineDash = lineDash
        if let strokeStyle = strokeStyle {
            self.strokeStyle = strokeStyle
        } else {
            self.strokeStyle = lineDash.isEmpty ? .solid : .dash
        }
        super.init()
    }
}

/// 按下时替换区间外观。
public final class ZHHTextHighlight: NSObject {
    /// 按下时的文字颜色。
    public var foregroundColor: UIColor?
    /// 按下时的背景边框；非空则整段替换原边框。
    public var border: ZHHTextBorder?
    /// 按下时的外阴影列表；非空则替换 `.shadow` / `shadows`。
    public var shadows: [NSShadow]?
    /// 按下时的内阴影；非空则写入 `innerShadow`。
    public var innerShadow: NSShadow?

    public override init() {
        super.init()
    }
}

/// 写入 `NSAttributedString` 的附件和装饰键。
public enum ZHHTextAttachmentAttribute {
    /// 值为 `ZHHTextImageAttachment`、`ZHHTextViewAttachment` 或 `ZHHTextLayerAttachment`。
    public static let key = NSAttributedString.Key("com.zhhtext.attachment")
    /// 值为 `ZHHTextBorder`。
    public static let border = NSAttributedString.Key("com.zhhtext.border")
    /// 值为 `[NSShadow]`，按顺序叠多道阴影。
    public static let shadows = NSAttributedString.Key("com.zhhtext.shadows")
    /// 值为 `NSShadow`，画在字形之上的内阴影。
    public static let innerShadow = NSAttributedString.Key("com.zhhtext.innerShadow")
    /// 值为 `ZHHTextHighlight`，按下时套用。
    public static let highlight = NSAttributedString.Key("com.zhhtext.highlight")
}

/// 生成行内附件占位串。字符是 U+FFFC，标签排版时再按字体垂直居中。
public enum ZHHTextInlineAttachment {
    /// 图片附件。
    /// - Parameters:
    ///   - image: 要绘制的图片。
    ///   - size: 占位尺寸。
    ///   - font: 用来垂直对齐的正文字体。
    /// - Returns: 带 U+FFFC 占位符的富文本片段。
    public static func image(_ image: UIImage, size: CGSize, alignedTo font: UIFont) -> NSAttributedString {
        let attachment = ZHHTextImageAttachment(image: image, layoutSize: size)
        return placeholder(attachment, font: font)
    }

    /// 视图附件。
    /// - Parameters:
    ///   - view: 要挂到标签上的视图。
    ///   - size: 占位尺寸。
    ///   - font: 用来垂直对齐的正文字体。
    /// - Returns: 带 U+FFFC 占位符的富文本片段。
    public static func view(_ view: UIView, size: CGSize, alignedTo font: UIFont) -> NSAttributedString {
        let attachment = ZHHTextViewAttachment(view: view, layoutSize: size)
        return placeholder(attachment, font: font)
    }

    /// 图层附件。
    /// - Parameters:
    ///   - layer: 要挂到标签上的图层。
    ///   - size: 占位尺寸。
    ///   - font: 用来垂直对齐的正文字体。
    /// - Returns: 带 U+FFFC 占位符的富文本片段。
    public static func layer(_ layer: CALayer, size: CGSize, alignedTo font: UIFont) -> NSAttributedString {
        let attachment = ZHHTextLayerAttachment(layer: layer, layoutSize: size)
        return placeholder(attachment, font: font)
    }

    private static func placeholder(_ attachment: NSObject, font: UIFont) -> NSAttributedString {
        NSAttributedString(
            string: "\u{FFFC}",
            attributes: [
                ZHHTextAttachmentAttribute.key: attachment,
                .font: font,
                .foregroundColor: UIColor.clear
            ]
        )
    }
}
