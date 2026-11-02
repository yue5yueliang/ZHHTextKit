//
//  ZHHTextAttribute.swift
//  ZHHTextKit
//
//  Created by 桃色三岁 on 2026/10/26.
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import UIKit

/// 展示串上的内部属性键。不对外公开。
enum ZHHTextAttribute {
    /// 展示串上的链接 id，值是 `ZHHTextLink.id`。
    static let linkID = NSAttributedString.Key("com.zhhtext.linkID")
    /// 截断 token。存在即表示该区间点击后展开或收起。
    static let truncation = NSAttributedString.Key("com.zhhtext.truncation")
}

/// 一次命中结果：正文链接、展开 / 收起，或普通正文。
struct ZHHTextHitAction: Equatable {
    /// 命中种类。
    enum Kind: Equatable {
        /// 正文链接。
        case link(ZHHTextLink)
        /// 截断 token。
        case expand
        /// 普通正文（非链接、非截断 token）。
        case body
    }

    /// 命中种类。
    var kind: Kind
    /// 展示串中的区间，用来画按下高亮。
    var displayRange: NSRange
}

/// 把动态色收成当前界面风格下的具体颜色，供 CoreText 使用。
enum ZHHTextColorResolver {
    /// CoreText 不认动态色。排版前按界面风格收成具体颜色。
    /// - Parameters:
    ///   - text: 待解析的富文本。
    ///   - interfaceStyle: 目标界面风格。
    /// - Returns: 前景色已解析的副本。
    static func resolve(
        _ text: NSAttributedString,
        interfaceStyle: UIUserInterfaceStyle
    ) -> NSAttributedString {
        guard text.length > 0 else { return text }
        let trait = UITraitCollection(userInterfaceStyle: interfaceStyle)
        let mutable = NSMutableAttributedString(attributedString: text)
        let full = NSRange(location: 0, length: mutable.length)
        mutable.enumerateAttribute(.foregroundColor, in: full, options: []) { value, range, _ in
            guard let color = value as? UIColor else { return }
            mutable.addAttribute(
                .foregroundColor,
                value: color.resolvedColor(with: trait),
                range: range
            )
        }
        return mutable
    }
}
