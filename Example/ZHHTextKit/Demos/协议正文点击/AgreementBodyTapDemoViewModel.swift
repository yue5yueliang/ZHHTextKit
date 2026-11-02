//
//  AgreementBodyTapDemoViewModel.swift
//  ZHHTextKit
//
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import UIKit
import ZHHTextKit

/// 「协议正文点击」页面状态与文案。
final class AgreementBodyTapDemoViewModel {

    let title = "协议正文点击"
    let caption = "默认关闭；本页打开 allowsBodyTap。点「我已阅读…」等普通字可勾选，点《用户协议》《隐私政策》打开链接。"
    let checkboxSide: CGFloat = 22

    private(set) var isChecked = false

    var statusText: String {
        isChecked
            ? "当前状态：已同意。点正文或复选框可取消。"
            : "当前状态：未同意。点正文或复选框可勾选。"
    }

    var toggleBannerText: String {
        isChecked ? "已勾选协议" : "已取消勾选"
    }

    @discardableResult
    func toggleAgreement() -> String {
        isChecked.toggle()
        return toggleBannerText
    }

    func makeStyle() -> ZHHTextStyle {
        var style = ZHHTextStyle.body
        style.font = UIFont.preferredFont(forTextStyle: .body)
        style.linkColor = .systemBlue
        return style
    }

    func makeAgreementResult(style: ZHHTextStyle) -> ZHHTextParseResult {
        let plain = "我已阅读并同意"
        let userAgreement = "《用户协议》"
        let conjunction = "和"
        let privacy = "《隐私政策》"
        let full = plain + userAgreement + conjunction + privacy
        let mutable = NSMutableAttributedString(string: full, attributes: style.attributes(for: .body))
        let userRange = (full as NSString).range(of: userAgreement)
        let privacyRange = (full as NSString).range(of: privacy)
        let linkAttributes = style.attributes(for: .url)
        mutable.addAttributes(linkAttributes, range: userRange)
        mutable.addAttributes(linkAttributes, range: privacyRange)
        let links = [
            ZHHTextLink(
                kind: .custom(ZHHTextCustomLink(identifier: "user-agreement")),
                range: userRange,
                text: userAgreement
            ),
            ZHHTextLink(
                kind: .custom(ZHHTextCustomLink(identifier: "privacy")),
                range: privacyRange,
                text: privacy
            )
        ]
        return ZHHTextParseResult(attributedText: mutable, links: links)
    }

    func bannerTitle(for link: ZHHTextLink) -> String {
        if case .custom(let custom) = link.kind {
            return custom.identifier == "privacy" ? "隐私政策" : "用户协议"
        }
        return link.text
    }

    func contentWidth(forContainerWidth width: CGFloat) -> CGFloat {
        width - 16 * 2 - 14 * 2 - checkboxSide
    }
}
