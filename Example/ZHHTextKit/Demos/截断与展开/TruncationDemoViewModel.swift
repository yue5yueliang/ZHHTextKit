//
//  TruncationDemoViewModel.swift
//  ZHHTextKit
//
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import UIKit
import ZHHTextKit

/// 「截断与展开」页面文案与交互结果。
final class TruncationDemoViewModel {

    let title = "截断与展开"
    let defaultCaption = "默认：3 行 +「全文 / 收起」。本页开启 allowsLongPressCopy，长按后由业务复制未截断全文。"
    let customCaption = "自定义 truncationToken：2 行 + “...more”"

    let longText = """
    这是一段用来演示截断的长文。社区 Feed 里常见三行折叠，点「全文」再展开；展开后可再「收起」。\
    下面两块分别是默认截断 token，以及自定义 "...more" 样式。排版宽度变化时会重新计算截断位置，\
    链接落在可见区时仍可点；完全被裁掉的链接不会进命中。适合列表复用时配合 layoutCache。
    """

    func expandBanner(expanded: Bool, custom: Bool) -> String {
        if custom {
            return expanded ? "自定义 token 展开" : "自定义 token 收起"
        }
        return expanded ? "已展开" : "已收起"
    }

    func linkBanner(for link: ZHHTextLink) -> String {
        "链接：\(link.text)"
    }

    func makeCustomTruncationToken() -> NSAttributedString {
        let more = NSMutableAttributedString(string: "...more", attributes: [
            .font: UIFont.systemFont(ofSize: 16),
            .foregroundColor: UIColor.label
        ])
        more.addAttribute(
            .foregroundColor,
            value: UIColor(red: 0, green: 0.449, blue: 1, alpha: 1),
            range: NSRange(location: 3, length: 4)
        )
        return more
    }

    func handleLongPress(_ info: ZHHTextLongPressInfo) -> String {
        let kind: String
        switch info.kind {
        case .body:
            kind = "正文"
        case .link(let link):
            kind = "链接(\(link.text))"
        case .expand:
            kind = "全文/收起"
        case .empty:
            kind = "空白"
        }
        UIPasteboard.general.string = info.plainText
        return "长按\(kind)，已复制全文 \(info.plainText.count) 字"
    }
}
