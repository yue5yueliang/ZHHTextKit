//
//  MixedPostDemoViewController.swift
//  ZHHTextKit
//
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import UIKit
import ZHHTextKit

final class MixedPostDemoViewController: UIViewController {
    private let viewModel = MixedPostDemoViewModel()
    private let label = ZHHTextLabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let hint = UILabel()
        hint.text = "模拟 Feed 卡片：胶囊标签嵌在句子里，可和 @、#、链接一起点击。"
        hint.font = UIFont.preferredFont(forTextStyle: .footnote)
        hint.textColor = .secondaryLabel
        hint.numberOfLines = 0

        let card = UIView()
        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 12
        card.translatesAutoresizingMaskIntoConstraints = false

        label.numberOfLines = 0
        label.clipsToBounds = false
        label.translatesAutoresizingMaskIntoConstraints = false
        label.apply(makePost())
        label.onTapLink = { [weak self] link in
            guard let self = self else { return }
            DemoBanner.show("点击：\(link.text)", in: self)
        }

        card.addSubview(label)
        let scroll = UIScrollView()
        scroll.delaysContentTouches = false
        pinToSafeArea(scroll, in: self)
        let column = UIStackView(arrangedSubviews: [hint, card])
        column.axis = .vertical
        column.spacing = 12
        column.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(column)
        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 16),
            column.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 16),
            column.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -16),
            column.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            label.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            label.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            label.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14)
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let width = view.bounds.width - 60
        if width > 0, label.preferredMaxLayoutWidth != width {
            label.preferredMaxLayoutWidth = width
        }
    }

    private func makePost() -> ZHHTextParseResult {
        let font = UIFont.systemFont(ofSize: 17)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 8
        let text = NSMutableAttributedString()
        var links: [ZHHTextLink] = []

        func appendPlain(_ string: String) {
            text.append(NSAttributedString(string: string, attributes: [
                .font: font,
                .foregroundColor: UIColor.label,
                .paragraphStyle: paragraph
            ]))
        }

        appendPlain("今天和 ")
        let mentionStart = text.length
        appendPlain("@阿柚")
        let mentionRange = NSRange(location: mentionStart, length: 3)
        text.addAttribute(.foregroundColor, value: UIColor.systemTeal, range: mentionRange)
        links.append(ZHHTextLink(
            kind: .mention(ZHHTextMention(name: "阿柚", userID: "u-3003")),
            range: mentionRange,
            text: "@阿柚"
        ))

        appendPlain(" 去了新开的咖啡馆，顺便打卡 ")
        let chip = DemoChipCatalog.items[1]
        let chipStart = text.length
        let chipPiece = ZHHTextChip(name: chip.name, fill: chip.fill, stroke: chip.stroke).labelPiece(
            font: .boldSystemFont(ofSize: font.pointSize),
            paragraph: paragraph
        )
        text.append(chipPiece)
        // 胶囊标签可点：盖在标签文字上（跳过前后占位空格）。
        let leadingLen = 2
        let nameLen = (chip.name.map(String.init).joined(separator: "\u{2060}") as NSString).length
        let chipTap = NSRange(location: chipStart + leadingLen, length: nameLen)
        links.append(ZHHTextLink(
            kind: .custom(ZHHTextCustomLink(identifier: "tag.\(chip.name)")),
            range: chipTap,
            text: chip.name
        ))

        appendPlain("又刷了 ")
        let topicStart = text.length
        appendPlain("#城市漫步")
        let topicRange = NSRange(location: topicStart, length: 5)
        text.addAttribute(.foregroundColor, value: UIColor.systemOrange, range: topicRange)
        links.append(ZHHTextLink(
            kind: .topic(ZHHTextTopic(name: "城市漫步", topicID: "t-200")),
            range: topicRange,
            text: "#城市漫步"
        ))

        appendPlain("。菜单在 ")
        let urlStart = text.length
        let urlText = "https://cafe.example.com"
        appendPlain(urlText)
        let urlRange = NSRange(location: urlStart, length: (urlText as NSString).length)
        text.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: urlRange)
        text.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: urlRange)
        links.append(ZHHTextLink(
            kind: .url(URL(string: urlText)!),
            range: urlRange,
            text: urlText
        ))
        appendPlain("，有空来呀。")

        return ZHHTextParseResult(attributedText: text, links: links)
    }
}

/// 截断与展开：行数限制、默认「全文」、自定义 token。
