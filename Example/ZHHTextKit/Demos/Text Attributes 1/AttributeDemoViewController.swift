//
//  AttributeDemoViewController.swift
//  ZHHTextKit
//
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import CoreText
import UIKit
import ZHHTextKit

final class AttributeDemoViewController: UIViewController {
    private let viewModel = AttributeDemoViewModel()
    private let label = ZHHTextLabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        // 浅灰底，白字阴影才看得出来。
        let page = UIColor(white: 0.933, alpha: 1)
        view.backgroundColor = page
        let scroll = UIScrollView()
        scroll.backgroundColor = page
        // 按下立刻收到 touchesBegan，避免滚动判定拖成「长按才高亮」。
        scroll.delaysContentTouches = false
        pinToSafeArea(scroll, in: self)
        label.numberOfLines = 0
        label.clipsToBounds = false
        label.backgroundColor = page
        label.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 20),
            label.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -16),
            label.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            label.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -32)
        ])
        var style = ZHHTextStyle()
        style.highlightColor = UIColor.black.withAlphaComponent(0.22)
        style.font = UIFont.boldSystemFont(ofSize: 30)
        label.style = style
        label.apply(makeResult())
        label.onTapLink = { [weak self] link in
            guard let self = self else { return }
            DemoBanner.show("Tap: \(link.text)", in: self)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let width = view.bounds.width - 32
        if width > 0, label.preferredMaxLayoutWidth != width {
            label.preferredMaxLayoutWidth = width
        }
    }

    private func makeResult() -> ZHHTextParseResult {
        let text = NSMutableAttributedString()
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineSpacing = 10
        var links: [ZHHTextLink] = []

        func add(_ string: String, attributes: [NSAttributedString.Key: Any]) -> NSRange {
            let start = text.length
            var merged = attributes
            merged[.paragraphStyle] = paragraph
            text.append(NSAttributedString(string: string, attributes: merged))
            return NSRange(location: start, length: (string as NSString).length)
        }

        func pad() {
            _ = add("\n\n", attributes: [.font: UIFont.systemFont(ofSize: 10)])
        }

        // 不要擅自给 Shadow / Inner Shadow 等加底色块。
        let heavy = UIFont.boldSystemFont(ofSize: 30)
        _ = add("Shadow", attributes: [
            .font: heavy,
            .foregroundColor: UIColor.white,
            .shadow: shadow(color: UIColor(white: 0, alpha: 0.49), x: 0, y: 1, radius: 5)
        ])
        pad()

        _ = add("Inner Shadow", attributes: [
            .font: heavy,
            .foregroundColor: UIColor.white,
            ZHHTextAttachmentAttribute.innerShadow: shadow(
                color: UIColor(white: 0, alpha: 0.40),
                x: 0,
                y: 1,
                radius: 1
            )
        ])
        pad()

        let up = shadow(color: UIColor(white: 0, alpha: 0.20), x: 0, y: -1, radius: 1.5)
        let down = shadow(color: UIColor(white: 1, alpha: 0.99), x: 0, y: 1, radius: 1.5)
        let multiInner = shadow(
            color: UIColor(red: 0.851, green: 0.311, blue: 0, alpha: 0.78),
            x: 0,
            y: 1,
            radius: 1
        )
        _ = add("Multiple Shadows", attributes: [
            .font: heavy,
            .foregroundColor: UIColor(red: 1, green: 0.795, blue: 0.014, alpha: 1),
            ZHHTextAttachmentAttribute.shadows: [up, down],
            ZHHTextAttachmentAttribute.innerShadow: multiInner
        ])
        pad()

        let pattern = UIColor(patternImage: DemoArtwork.stripes())
        _ = add("Background Image", attributes: [
            .font: heavy,
            .foregroundColor: pattern
        ])
        pad()

        let pink = UIColor(red: 1, green: 0.029, blue: 0.651, alpha: 1)
        _ = add("Border", attributes: [
            .font: heavy,
            .foregroundColor: pink,
            ZHHTextAttachmentAttribute.border: ZHHTextBorder(
                strokeColor: pink,
                lineWidth: 3,
                cornerRadius: 3,
                outsets: UIEdgeInsets(top: 0, left: 4, bottom: 0, right: 4),
                strokeStyle: .circleDot
            )
        ])
        pad()

        let linkFont = UIFont.boldSystemFont(ofSize: 30)
        let linkHighlight = ZHHTextHighlight()
        linkHighlight.border = ZHHTextBorder(
            fillColor: UIColor(white: 0, alpha: 0.22),
            cornerRadius: 3,
            outsets: UIEdgeInsets(top: 2, left: 1, bottom: 2, right: 1)
        )
        let linkRange = add("Link", attributes: [
            .font: linkFont,
            .foregroundColor: UIColor(red: 0.093, green: 0.492, blue: 1, alpha: 1),
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            ZHHTextAttachmentAttribute.highlight: linkHighlight
        ])
        links.append(ZHHTextLink(kind: .custom(ZHHTextCustomLink(identifier: "link")), range: linkRange, text: "Link"))
        pad()

        let red = UIColor.red
        let anotherBorder = ZHHTextBorder(
            strokeColor: red,
            lineWidth: 0.5,
            cornerRadius: 50,
            outsets: UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
        )
        let anotherPress = ZHHTextBorder(
            fillColor: red,
            cornerRadius: 50,
            outsets: UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
        )
        let anotherHighlight = ZHHTextHighlight()
        anotherHighlight.foregroundColor = .white
        anotherHighlight.border = anotherPress
        let another = add("Another Link", attributes: [
            .font: linkFont,
            .foregroundColor: red,
            ZHHTextAttachmentAttribute.border: anotherBorder,
            ZHHTextAttachmentAttribute.highlight: anotherHighlight
        ])
        links.append(ZHHTextLink(kind: .custom(ZHHTextCustomLink(identifier: "another")), range: another, text: "Another Link"))
        pad()

        let yetHighlight = ZHHTextHighlight()
        yetHighlight.foregroundColor = UIColor(red: 1, green: 0.795, blue: 0.014, alpha: 1)
        yetHighlight.shadows = [up, down]
        yetHighlight.innerShadow = multiInner
        let yet = add("Yet Another Link", attributes: [
            .font: linkFont,
            .foregroundColor: UIColor.white,
            .shadow: shadow(color: UIColor(white: 0, alpha: 0.49), x: 0, y: 1, radius: 5),
            ZHHTextAttachmentAttribute.highlight: yetHighlight
        ])
        links.append(ZHHTextLink(kind: .custom(ZHHTextCustomLink(identifier: "yet")), range: yet, text: "Yet Another Link"))

        return ZHHTextParseResult(attributedText: text, links: links)
    }
}

/// 彩色标签示例：上面 `ZHHTextLabel` 只读展示，下面可编辑 TextView（退格整段删）。
