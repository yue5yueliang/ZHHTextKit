//
//  DemoViewControllers.swift
//  ZHHTextKit
//
//  Created by 桃色三岁 on 2026/10/26.
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import CoreText
import UIKit
import ZHHTextKit

/// Demo 目录里的一行。
struct DemoEntry {
    /// 标题。
    let title: String
    /// 副标题说明。
    let detail: String
    /// 创建对应页面。
    let make: () -> UIViewController
}

/// 示例目录：社区 Feed、Text Editor 与各富文本效果页。
enum DemoCatalog {
    /// 首页列表数据。
    static let entries: [DemoEntry] = [
        DemoEntry(title: "社区 Feed", detail: "话题、提及、链接、电话、全文和列表缓存", make: { FeedDemoViewController() }),
        DemoEntry(title: "Text Editor", detail: "选人发布 document；回显 entities 可点", make: { EditorDemoViewController() }),
        DemoEntry(title: "正文标签编辑", detail: "正文里插胶囊标签，退格整段删；下方 Label 预览", make: { InlineChipComposerDemoViewController() }),
        DemoEntry(title: "混排帖子卡片", detail: "正文 + 胶囊标签 + @/# + 链接，只读回显", make: { MixedPostDemoViewController() }),
        DemoEntry(title: "截断与展开", detail: "行数限制、全文 / 收起、自定义 token", make: { TruncationDemoViewController() }),
        DemoEntry(title: "Text Attributes 1", detail: "阴影、图案字、边框、可点链接", make: { AttributeDemoViewController() }),
        DemoEntry(title: "Text Attributes 2", detail: "彩色标签：Label 展示 / TextView 编辑", make: { TagDemoViewController() }),
        DemoEntry(title: "Text Attachments", detail: "图片、视图、图层和自定义 ...more", make: { AttachmentDemoViewController() }),
        DemoEntry(title: "Text Edit", detail: "图文绕排编辑", make: { EditDemoViewController() }),
        DemoEntry(title: "Text Parser (Markdown)", detail: "标题、强调、链接、代码", make: { MarkdownDemoViewController() }),
        DemoEntry(title: "Text Parser (Emoticon)", detail: "系统 emoji + 自定义表情图混排", make: { EmoticonDemoViewController() }),
        DemoEntry(title: "Text Binding", detail: "退格先选中整段邮箱", make: { BindingDemoViewController() }),
        DemoEntry(title: "Copy and Paste", detail: "插入图片、复制和粘贴", make: { PasteDemoViewController() }),
        DemoEntry(title: "Undo and Redo", detail: "撤销和重做", make: { UndoDemoViewController() }),
        DemoEntry(title: "Ruby Annotation", detail: "汉字和假名注音", make: { RubyDemoViewController() }),
        DemoEntry(title: "Async Display", detail: "UILabel 和 ZHHTextLabel 对比", make: { AsyncDemoViewController() })
    ]
}

/// 页面顶部短暂提示。
enum DemoBanner {
    /// 在指定页面显示一条提示文案。
    /// - Parameters:
    ///   - message: 提示内容。
    ///   - controller: 宿主页面。
    static func show(_ message: String, in controller: UIViewController) {
        controller.view.viewWithTag(9001)?.removeFromSuperview()
        let label = UILabel()
        label.tag = 9001
        label.text = "  \(message)  "
        label.textAlignment = .center
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.78)
        label.font = UIFont.systemFont(ofSize: 15)
        label.numberOfLines = 2
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        controller.view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: controller.view.centerXAnchor),
            label.bottomAnchor.constraint(equalTo: controller.view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: controller.view.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(lessThanOrEqualTo: controller.view.trailingAnchor, constant: -24),
            label.heightAnchor.constraint(greaterThanOrEqualToConstant: 40)
        ])
        UIView.animate(withDuration: 0.25, delay: 1.3, options: [], animations: {
            label.alpha = 0
        }, completion: { _ in
            label.removeFromSuperview()
        })
    }
}

private func pinToSafeArea(_ child: UIView, in controller: UIViewController) {
    child.translatesAutoresizingMaskIntoConstraints = false
    controller.view.addSubview(child)
    NSLayoutConstraint.activate([
        child.topAnchor.constraint(equalTo: controller.view.safeAreaLayoutGuide.topAnchor),
        child.leadingAnchor.constraint(equalTo: controller.view.leadingAnchor),
        child.trailingAnchor.constraint(equalTo: controller.view.trailingAnchor),
        child.bottomAnchor.constraint(equalTo: controller.view.bottomAnchor)
    ])
}

private func rgb(_ hex: UInt32) -> UIColor {
    UIColor(
        red: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: 1
    )
}

private func shadow(color: UIColor, x: CGFloat, y: CGFloat, radius: CGFloat) -> NSShadow {
    let item = NSShadow()
    item.shadowColor = color
    item.shadowOffset = CGSize(width: x, height: y)
    item.shadowBlurRadius = radius
    return item
}

/// 编辑区用的胶囊附件：一个字符，退格天然整颗删除。
/// 标记编辑区胶囊附件（U+FFFC），退格时整颗删。
/// Demo 示例胶囊色板；构造走 `ZHHTextChip`。
private enum DemoChipCatalog {
    static let items: [(name: String, fill: UInt32, stroke: UInt32)] = [
        ("周末出游", 0xF07167, 0xE85D4C),
        ("咖啡探店", 0xE8A33A, 0xD4890A),
        ("数码测评", 0x4DB6A0, 0x2F9B7A),
        ("居家收纳", 0x5B9AED, 0x3B7DD8),
        ("健身打卡", 0xA78BFA, 0x8B5CF6),
        ("读书笔记", 0xEC4899, 0xDB2777),
        ("宠物日常", 0x94A3B8, 0x64748B)
    ]

    static func chip(at index: Int) -> ZHHTextChip {
        let item = items[index]
        return ZHHTextChip(name: item.name, fill: item.fill, stroke: item.stroke)
    }
}

private enum DemoArtwork {
    static func mark(side: CGFloat) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        return renderer.image { _ in
            let rect = CGRect(x: 1, y: 1, width: side - 2, height: side - 2)
            UIColor(red: 0.09, green: 0.45, blue: 0.95, alpha: 1).setFill()
            UIBezierPath(roundedRect: rect, cornerRadius: side * 0.18).fill()
            let text = "Z" as NSString
            let font = UIFont.boldSystemFont(ofSize: side * 0.52)
            let textSize = text.size(withAttributes: [.font: font])
            text.draw(
                at: CGPoint(x: (side - textSize.width) / 2, y: (side - textSize.height) / 2),
                withAttributes: [.font: font, .foregroundColor: UIColor.white]
            )
        }
    }

    static func stripes() -> UIImage {
        let size = CGSize(width: 20, height: 20)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor(red: 0.054, green: 0.879, blue: 0, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let cg = context.cgContext
            cg.setStrokeColor(UIColor(red: 0.869, green: 1, blue: 0.030, alpha: 1).cgColor)
            cg.setLineWidth(2)
            var x: CGFloat = 0
            while x < size.width * 2 {
                cg.move(to: CGPoint(x: x, y: -2))
                cg.addLine(to: CGPoint(x: x - size.height, y: size.height + 2))
                x += 4
            }
            cg.strokePath()
        }
    }

    static func face(shift: CGFloat) -> UIImage {
        let side: CGFloat = 32
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        return renderer.image { _ in
            UIColor.systemYellow.setFill()
            UIBezierPath(ovalIn: CGRect(x: 1, y: 1, width: 30, height: 30)).fill()
            UIColor.black.setFill()
            let eyeY = 10 + shift
            UIBezierPath(ovalIn: CGRect(x: 8, y: eyeY, width: 4, height: 5)).fill()
            UIBezierPath(ovalIn: CGRect(x: 20, y: eyeY, width: 4, height: 5)).fill()
            let smile = UIBezierPath()
            smile.move(to: CGPoint(x: 9, y: 18))
            smile.addQuadCurve(to: CGPoint(x: 23, y: 18), controlPoint: CGPoint(x: 16, y: 22 + shift))
            smile.lineWidth = 1.4
            UIColor.black.setStroke()
            smile.stroke()
        }
    }

    static func photo() -> UIImage {
        let size = CGSize(width: 108, height: 132)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            UIColor(red: 0.95, green: 0.55, blue: 0.25, alpha: 1).setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 10).fill()
            UIColor(red: 0.25, green: 0.55, blue: 0.85, alpha: 1).setFill()
            UIBezierPath(ovalIn: CGRect(x: 28, y: 24, width: 52, height: 52)).fill()
            UIColor.white.setFill()
            UIBezierPath(rect: CGRect(x: 0, y: 96, width: 108, height: 36)).fill()
            let title = "Photo" as NSString
            title.draw(at: CGPoint(x: 28, y: 104), withAttributes: [
                .font: UIFont.boldSystemFont(ofSize: 16),
                .foregroundColor: UIColor(red: 0.95, green: 0.45, blue: 0.15, alpha: 1)
            ])
        }
    }
}

/// 阴影、图案字、边框与可点链接示例。
final class AttributeDemoViewController: UIViewController {
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
final class TagDemoViewController: UIViewController, UITextViewDelegate {
    private let label = ZHHTextLabel()
    private let textView = ZHHTextChipTextView.make()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let labelCaption = sectionCaption("ZHHTextLabel · 只读展示")
        label.numberOfLines = 0
        label.clipsToBounds = false
        label.attributedText = makeLabelTags()
        label.translatesAutoresizingMaskIntoConstraints = false

        let editorCaption = sectionCaption("可编辑 · 每个标签是一张图，退格一次整颗删")
        textView.backgroundColor = UIColor.secondarySystemBackground
        textView.layer.cornerRadius = 8
        textView.clipsToBounds = true
        textView.delegate = self
        textView.keyboardDismissMode = .interactive
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 14, bottom: 16, right: 14)
        textView.textContainer.lineFragmentPadding = 0
        textView.alwaysBounceVertical = true
        let tags = makeEditorTags()
        textView.textStorage.setAttributedString(tags)
        textView.selectedRange = NSRange(location: tags.length, length: 0)
        textView.translatesAutoresizingMaskIntoConstraints = false

        let scroll = UIScrollView()
        scroll.keyboardDismissMode = .interactive
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        let column = UIStackView(arrangedSubviews: [labelCaption, label, editorCaption, textView])
        column.axis = .vertical
        column.spacing = 8
        column.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(column)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            column.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 12),
            column.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 12),
            column.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -12),
            column.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -12),
            textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 220)
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let width = view.bounds.width - 24
        if width > 0, label.preferredMaxLayoutWidth != width {
            label.preferredMaxLayoutWidth = width
        }
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(endEditing)
        )
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        navigationItem.rightBarButtonItem = nil
    }

    @objc private func endEditing() {
        textView.resignFirstResponder()
    }

    private func sectionCaption(_ title: String) -> UILabel {
        let caption = UILabel()
        caption.text = title
        caption.font = UIFont.preferredFont(forTextStyle: .footnote)
        caption.textColor = .secondaryLabel
        caption.numberOfLines = 0
        return caption
    }

    private func makeLabelTags() -> NSAttributedString {
        let font = UIFont.boldSystemFont(ofSize: 16)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 14
        paragraph.lineBreakMode = .byWordWrapping
        let text = NSMutableAttributedString()
        func appendRow() {
            for item in DemoChipCatalog.items {
                text.append(ZHHTextChip(name: item.name, fill: item.fill, stroke: item.stroke).labelPiece(
                    font: font,
                    paragraph: paragraph
                ))
            }
        }
        appendRow()
        text.append(NSAttributedString(string: "\n", attributes: [.font: font, .paragraphStyle: paragraph]))
        appendRow()
        return text
    }

    private func makeEditorTags() -> NSAttributedString {
        let font = UIFont.boldSystemFont(ofSize: 16)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 14
        paragraph.lineBreakMode = .byWordWrapping
        let text = NSMutableAttributedString()
        func appendRow() {
            for item in DemoChipCatalog.items {
                text.append(ZHHTextChip(name: item.name, fill: item.fill, stroke: item.stroke).piece(
                    font: font,
                    paragraph: paragraph
                ))
            }
        }
        appendRow()
        text.append(NSAttributedString(string: "\n", attributes: [.font: font, .paragraphStyle: paragraph]))
        appendRow()
        return text
    }
}

/// 发帖编辑器里正文夹胶囊标签：可打字、点按钮插入，退格整段删；下方 Label 模拟 Feed 预览。
final class InlineChipComposerDemoViewController: UIViewController, UITextViewDelegate {
    private let editor = ZHHTextChipTextView.make()
    private let preview = ZHHTextLabel()
    private let bodyFont = UIFont.systemFont(ofSize: 17)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(endEditing)
        )

        let hint = makeCaption("在正文中间插入胶囊标签。点下方按钮插入；每个标签是一张附件图，退格一次整颗删除。")
        let editorCaption = makeCaption("编辑区")
        editor.backgroundColor = .secondarySystemBackground
        editor.layer.cornerRadius = 10
        editor.clipsToBounds = true
        editor.delegate = self
        editor.font = bodyFont
        editor.typingAttributes = [
            .font: bodyFont,
            .foregroundColor: UIColor.label
        ]
        editor.keyboardDismissMode = .interactive
        editor.textContainerInset = UIEdgeInsets(top: 14, left: 12, bottom: 14, right: 12)
        editor.textContainer.lineFragmentPadding = 0
        editor.translatesAutoresizingMaskIntoConstraints = false
        seedEditor()

        let chipBar = makeChipBar()
        let previewCaption = makeCaption("Feed / 详情预览（ZHHTextLabel）")
        preview.numberOfLines = 0
        preview.clipsToBounds = false
        preview.backgroundColor = .secondarySystemBackground
        preview.layer.cornerRadius = 10
        preview.translatesAutoresizingMaskIntoConstraints = false
        refreshPreview()

        let scroll = UIScrollView()
        scroll.keyboardDismissMode = .interactive
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        let column = UIStackView(arrangedSubviews: [hint, editorCaption, editor, chipBar, previewCaption, preview])
        column.axis = .vertical
        column.spacing = 10
        column.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(column)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            column.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 12),
            column.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 16),
            column.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -16),
            column.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -16),
            editor.heightAnchor.constraint(greaterThanOrEqualToConstant: 160)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        editor.becomeFirstResponder()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let width = view.bounds.width - 32
        if width > 0, preview.preferredMaxLayoutWidth != width {
            preview.preferredMaxLayoutWidth = width
        }
    }

    func textViewDidChange(_ textView: UITextView) {
        refreshPreview()
    }

    @objc private func endEditing() {
        editor.resignFirstResponder()
    }

    @objc private func insertChip(_ sender: UIButton) {
        let index = sender.tag
        guard DemoChipCatalog.items.indices.contains(index) else { return }
        let paragraph = bodyParagraph()
        let chip = DemoChipCatalog.chip(at: index).piece(
            font: .boldSystemFont(ofSize: bodyFont.pointSize),
            paragraph: paragraph
        )
        let location = editor.selectedRange.location
        editor.textStorage.insert(chip, at: location)
        editor.selectedRange = NSRange(location: location + chip.length, length: 0)
        refreshPreview()
    }

    private func seedEditor() {
        let paragraph = bodyParagraph()
        let text = NSMutableAttributedString(
            string: "周末打算去海边走走，顺便探店喝咖啡。想带上这些标签：",
            attributes: [
                .font: bodyFont,
                .foregroundColor: UIColor.label,
                .paragraphStyle: paragraph
            ]
        )
        let chipFont = UIFont.boldSystemFont(ofSize: bodyFont.pointSize)
        text.append(DemoChipCatalog.chip(at: 0).piece(font: chipFont, paragraph: paragraph))
        text.append(DemoChipCatalog.chip(at: 1).piece(font: chipFont, paragraph: paragraph))
        text.append(NSAttributedString(
            string: "有一起的吗？",
            attributes: [
                .font: bodyFont,
                .foregroundColor: UIColor.label,
                .paragraphStyle: paragraph
            ]
        ))
        editor.textStorage.setAttributedString(text)
        editor.selectedRange = NSRange(location: text.length, length: 0)
    }

    private func refreshPreview() {
        preview.attributedText = ZHHTextChip.labelCompatible(editor.textStorage, alignedTo: bodyFont)
        preview.invalidateIntrinsicContentSize()
    }

    private func makeChipBar() -> UIScrollView {
        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(row)
        for (index, item) in DemoChipCatalog.items.enumerated() {
            let button = UIButton(type: .system)
            button.setTitle("+\(item.name)", for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
            button.backgroundColor = rgb(item.fill).withAlphaComponent(0.18)
            button.setTitleColor(rgb(item.stroke), for: .normal)
            button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
            button.layer.cornerRadius = 14
            button.tag = index
            button.addTarget(self, action: #selector(insertChip(_:)), for: .touchUpInside)
            row.addArrangedSubview(button)
        }
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            row.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            row.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            row.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor)
        ])
        scroll.heightAnchor.constraint(equalToConstant: 36).isActive = true
        return scroll
    }

    private func bodyParagraph() -> NSMutableParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 8
        paragraph.lineBreakMode = .byWordWrapping
        return paragraph
    }

    private func makeCaption(_ title: String) -> UILabel {
        let caption = UILabel()
        caption.text = title
        caption.font = UIFont.preferredFont(forTextStyle: .footnote)
        caption.textColor = .secondaryLabel
        caption.numberOfLines = 0
        return caption
    }
}

/// 只读混排：一段帖子里同时有正文、胶囊标签、@、#、链接。
final class MixedPostDemoViewController: UIViewController {
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
final class TruncationDemoViewController: UIViewController {
    private let shortLabel = ZHHTextLabel()
    private let customLabel = ZHHTextLabel()
    private let longText = """
    这是一段用来演示截断的长文。社区 Feed 里常见三行折叠，点「全文」再展开；展开后可再「收起」。\
    下面两块分别是默认截断 token，以及自定义 "...more" 样式。排版宽度变化时会重新计算截断位置，\
    链接落在可见区时仍可点；完全被裁掉的链接不会进命中。适合列表复用时配合 layoutCache。
    """

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        shortLabel.numberOfLines = 3
        shortLabel.showsCollapsedToken = true
        shortLabel.showsExpandedToken = true
        shortLabel.collapsedLinkText = "全文"
        shortLabel.expandedLinkText = "收起"
        shortLabel.clipsToBounds = false
        shortLabel.text = longText
        shortLabel.onTapExpand = { [weak self] expanded in
            guard let self = self else { return }
            DemoBanner.show(expanded ? "已展开" : "已收起", in: self)
        }
        shortLabel.onTapLink = { [weak self] link in
            guard let self = self else { return }
            DemoBanner.show("链接：\(link.text)", in: self)
        }

        customLabel.numberOfLines = 2
        customLabel.showsExpandedToken = false
        let more = NSMutableAttributedString(string: "...more", attributes: [
            .font: UIFont.systemFont(ofSize: 16),
            .foregroundColor: UIColor.label
        ])
        more.addAttribute(
            .foregroundColor,
            value: UIColor(red: 0, green: 0.449, blue: 1, alpha: 1),
            range: NSRange(location: 3, length: 4)
        )
        customLabel.truncationToken = more
        customLabel.clipsToBounds = false
        customLabel.text = longText
        customLabel.onTapExpand = { [weak self] expanded in
            guard let self = self else { return }
            DemoBanner.show(expanded ? "自定义 token 展开" : "自定义 token 收起", in: self)
        }

        let scroll = UIScrollView()
        scroll.delaysContentTouches = false
        pinToSafeArea(scroll, in: self)
        let column = UIStackView(arrangedSubviews: [
            makeCaption("默认：3 行 +「全文 / 收起」"),
            wrapCard(shortLabel),
            makeCaption("自定义 truncationToken：2 行 + “...more”"),
            wrapCard(customLabel)
        ])
        column.axis = .vertical
        column.spacing = 12
        column.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(column)
        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 16),
            column.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 16),
            column.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -16),
            column.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24)
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let width = view.bounds.width - 60
        guard width > 0 else { return }
        if shortLabel.preferredMaxLayoutWidth != width {
            shortLabel.preferredMaxLayoutWidth = width
        }
        if customLabel.preferredMaxLayoutWidth != width {
            customLabel.preferredMaxLayoutWidth = width
        }
    }

    private func wrapCard(_ label: ZHHTextLabel) -> UIView {
        let card = UIView()
        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 12
        label.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            label.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            label.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14)
        ])
        return card
    }

    private func makeCaption(_ title: String) -> UILabel {
        let caption = UILabel()
        caption.text = title
        caption.font = UIFont.preferredFont(forTextStyle: .footnote)
        caption.textColor = .secondaryLabel
        caption.numberOfLines = 0
        return caption
    }
}

/// 角落可拖拽改变尺寸的标签，用于附件 Demo。
final class CornerHitLabel: ZHHTextLabel {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let hit = super.hitTest(point, with: event) {
            return hit
        }
        guard bounds.contains(point) else { return nil }
        if point.x >= bounds.width - 36 && point.y >= bounds.height - 36 {
            return self
        }
        return nil
    }
}

/// 图片、视图、图层附件与自定义截断 token 示例。
final class AttachmentDemoViewController: UIViewController, UIGestureRecognizerDelegate {
    private let scrollView = UIScrollView()
    private let label = CornerHitLabel()
    private let dot = UIView()
    private let knob = UIView()
    private var faces: [UIImageView] = []
    private var pulseLayer: CALayer?
    private var didPlace = false
    private var userMoved = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        scrollView.delaysContentTouches = false
        pinToSafeArea(scrollView, in: self)
        label.numberOfLines = 6
        label.showsExpandedToken = false
        let more = NSMutableAttributedString(string: "...more", attributes: [
            .font: UIFont.systemFont(ofSize: 16),
            .foregroundColor: UIColor.label
        ])
        more.addAttribute(
            .foregroundColor,
            value: UIColor(red: 0, green: 0.449, blue: 1, alpha: 1),
            range: NSRange(location: 3, length: 4)
        )
        label.truncationToken = more
        label.layer.borderWidth = 0.5
        label.layer.borderColor = UIColor(red: 0, green: 0.463, blue: 1, alpha: 1).cgColor
        label.backgroundColor = .systemBackground
        var style = label.style
        style.truncationColor = UIColor(red: 0, green: 0.449, blue: 1, alpha: 1)
        style.highlightColor = UIColor(red: 0.578, green: 0.790, blue: 1, alpha: 1)
        style.font = UIFont.systemFont(ofSize: 16)
        label.style = style
        label.attributedText = makeText()
        label.onTapExpand = { [weak self] expanded in
            guard let self = self, expanded else { return }
            let fit = self.label.sizeThatFits(CGSize(width: self.label.bounds.width, height: 2000))
            self.label.frame.size.height = max(self.label.bounds.height, fit.height + 12)
            self.placeDot()
            self.updateContentSize()
        }
        scrollView.addSubview(label)

        knob.bounds = CGRect(x: 0, y: 0, width: 12, height: 12)
        knob.layer.cornerRadius = 6
        knob.backgroundColor = UIColor(red: 0, green: 0.463, blue: 1, alpha: 1)
        knob.isUserInteractionEnabled = false
        dot.addSubview(knob)
        dot.isUserInteractionEnabled = false
        label.addSubview(dot)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(resize(_:)))
        pan.delegate = self
        label.addGestureRecognizer(pan)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        for face in faces {
            face.startAnimating()
        }
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 1
        pulse.toValue = 0.25
        pulse.duration = 0.7
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulseLayer?.add(pulse, forKey: "pulse")
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard scrollView.bounds.width > 1, !didPlace else { return }
        didPlace = true
        let width: CGFloat = min(260, scrollView.bounds.width - 32)
        label.frame = CGRect(x: (scrollView.bounds.width - width) / 2, y: 24, width: width, height: 260)
        label.preferredMaxLayoutWidth = width
        placeDot()
        updateContentSize()
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        let point = gestureRecognizer.location(in: label)
        return point.x >= label.bounds.width - 36 && point.y >= label.bounds.height - 36
    }

    @objc private func resize(_ gesture: UIPanGestureRecognizer) {
        let point = gesture.location(in: scrollView)
        let width = max(120, point.x - label.frame.minX)
        let height = max(80, point.y - label.frame.minY)
        userMoved = true
        label.frame.size = CGSize(width: width, height: height)
        label.preferredMaxLayoutWidth = width
        placeDot()
        updateContentSize()
    }

    private func placeDot() {
        dot.bounds = CGRect(x: 0, y: 0, width: 44, height: 44)
        dot.center = CGPoint(x: label.bounds.width - 8, y: label.bounds.height - 8)
        knob.center = CGPoint(x: dot.bounds.midX, y: dot.bounds.midY)
    }

    private func updateContentSize() {
        scrollView.contentSize = CGSize(
            width: scrollView.bounds.width,
            height: max(scrollView.bounds.height, label.frame.maxY + 32)
        )
    }

    private func makeText() -> NSAttributedString {
        let font = UIFont.systemFont(ofSize: 16)
        let text = NSMutableAttributedString()
        let body: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.label
        ]
        func append(_ string: String) {
            text.append(NSAttributedString(string: string, attributes: body))
        }
        append("This is UIImage attachment:")
        text.append(ZHHTextInlineAttachment.image(DemoArtwork.mark(side: 44), size: CGSize(width: 44, height: 44), alignedTo: font))
        append("\nThis is UIView attachment: ")
        let toggle = UISwitch()
        toggle.sizeToFit()
        text.append(ZHHTextInlineAttachment.view(toggle, size: toggle.bounds.size, alignedTo: font))
        append("\nThis is CALayer attachment:")
        let chip = CALayer()
        chip.bounds = CGRect(x: 0, y: 0, width: 28, height: 28)
        chip.cornerRadius = 6
        chip.backgroundColor = UIColor.systemOrange.cgColor
        pulseLayer = chip
        text.append(ZHHTextInlineAttachment.layer(chip, size: CGSize(width: 28, height: 28), alignedTo: font))
        append("\nThis is Animated Image attachment:")
        for index in 0..<5 {
            let face = UIImageView(frame: CGRect(x: 0, y: 0, width: 32, height: 32))
            var frames: [UIImage] = []
            for frame in 0..<4 {
                frames.append(DemoArtwork.face(shift: CGFloat((frame + index) % 4) * 1.5))
            }
            face.animationImages = frames
            face.animationDuration = 0.6
            face.image = frames.first
            faces.append(face)
            text.append(ZHHTextInlineAttachment.view(face, size: CGSize(width: 32, height: 32), alignedTo: font))
        }
        append("\n")
        append(String(repeating: "拖右下角圆点改变标签宽高。点 ...more 展开被挡住的文字。", count: 4))
        return text
    }
}

/// 图文绕排编辑示例（系统 UITextView）。
final class EditDemoViewController: UIViewController, UITextViewDelegate {
    private let textView = UITextView()
    private let imageView = UIImageView(image: DemoArtwork.photo())
    private let debugSwitch = UISwitch()
    private let exclusionSwitch = UISwitch()
    private var exclusionOn = true

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let debugLabel = UILabel()
        debugLabel.text = "调试"
        debugLabel.font = UIFont.systemFont(ofSize: 15)
        let exclusionLabel = UILabel()
        exclusionLabel.text = "排除区域"
        exclusionLabel.font = UIFont.systemFont(ofSize: 15)
        debugSwitch.addTarget(self, action: #selector(optionsChanged), for: .valueChanged)
        exclusionSwitch.isOn = true
        exclusionSwitch.addTarget(self, action: #selector(optionsChanged), for: .valueChanged)
        let bar = UIStackView(arrangedSubviews: [debugLabel, debugSwitch, exclusionLabel, exclusionSwitch])
        bar.axis = .horizontal
        bar.spacing = 8
        bar.alignment = .center
        bar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bar)

        let paragraph = NSMutableParagraphStyle()
        paragraph.firstLineHeadIndent = 20
        paragraph.lineSpacing = 4
        let font = UIFont(name: "Times New Roman", size: 20) ?? UIFont.systemFont(ofSize: 20)
        let article = """
        It was the best of times, it was the worst of times, it was the age of wisdom, it was the age of foolishness.

        这是最好的时代，也是最坏的时代。文字会绕开右侧图片。打开「排除区域」看绕排，关掉后恢复普通换行。调试开关只给编辑区加边框。

        The image stays with the first lines while you scroll. Type at the end to see the keyboard and the exclusion together.
        """
        textView.attributedText = NSAttributedString(string: article, attributes: [
            .font: font,
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraph
        ])
        textView.typingAttributes = [
            .font: font,
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraph
        ]
        textView.font = font
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        textView.textContainer.lineFragmentPadding = 0
        textView.delegate = self
        textView.keyboardDismissMode = .interactive
        textView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(textView)
        imageView.isUserInteractionEnabled = false
        textView.addSubview(imageView)

        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            bar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            bar.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -16),
            textView.topAnchor.constraint(equalTo: bar.bottomAnchor, constant: 8),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        textView.becomeFirstResponder()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutExclusion()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        layoutExclusion()
    }

    @objc private func optionsChanged() {
        exclusionOn = exclusionSwitch.isOn
        textView.layer.borderWidth = debugSwitch.isOn ? 1 : 0
        textView.layer.borderColor = UIColor.systemBlue.cgColor
        layoutExclusion()
    }

    private func layoutExclusion() {
        let width = textView.bounds.width
        guard width > 1 else { return }
        let imageSize = CGSize(width: 108, height: 132)
        let inset = textView.textContainerInset
        let containerX = max(0, width - inset.left - inset.right - imageSize.width)
        let containerY: CGFloat = 4
        imageView.frame = CGRect(
            x: inset.left + containerX,
            y: inset.top + containerY - textView.contentOffset.y,
            width: imageSize.width,
            height: imageSize.height
        )
        if exclusionOn {
            imageView.isHidden = false
            textView.textContainer.exclusionPaths = [
                UIBezierPath(roundedRect: CGRect(origin: CGPoint(x: containerX, y: containerY), size: imageSize), cornerRadius: 10)
            ]
        } else {
            imageView.isHidden = true
            textView.textContainer.exclusionPaths = []
        }
    }
}

/// Markdown 轻量解析示例（系统 UITextView）。
final class MarkdownDemoViewController: UIViewController, UITextViewDelegate {
    private let textView = UITextView()
    private var applying = false
    private let source = """
    #Markdown Editor
    This is a simple markdown editor based on ZHHTextKit.

    *********************************************
    It's *italic* style.

    It's also _italic_ style.

    It's **bold** style.

    It's ***italic and bold*** style.

    It's __underline__ style.

    It's ~~deleteline~~ style.


    Here is a link: [ZHHTextKit](https://github.com)

    Here is some code:

    \tif(a){
    \t\tif(b){
    \t\t\tif(c){
    \t\t\t\tprintf("haha");
    \t\t\t}
    \t\t}
    \t}
    """

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(white: 0.134, alpha: 1)
        textView.backgroundColor = UIColor(white: 0.134, alpha: 1)
        textView.textColor = .white
        textView.tintColor = .white
        textView.keyboardAppearance = .dark
        textView.indicatorStyle = .white
        textView.delegate = self
        textView.keyboardDismissMode = .interactive
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        pinToSafeArea(textView, in: self)
        apply(source, caret: (source as NSString).length)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        textView.becomeFirstResponder()
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(finishEditing)
        )
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        navigationItem.rightBarButtonItem = nil
    }

    func textViewDidChange(_ textView: UITextView) {
        guard !applying else { return }
        apply(textView.text ?? "", caret: textView.selectedRange.location)
    }

    @objc private func finishEditing() {
        textView.resignFirstResponder()
    }

    private func apply(_ raw: String, caret: Int) {
        applying = true
        textView.attributedText = DemoMarkdown.render(raw)
        let length = textView.textStorage.length
        let location = max(0, min(caret, length))
        textView.selectedRange = NSRange(location: location, length: 0)
        applying = false
    }
}

private enum DemoMarkdown {
    static func render(_ raw: String) -> NSAttributedString {
        let font = UIFont.systemFont(ofSize: 16)
        let text = NSMutableAttributedString(string: raw, attributes: [
            .font: font,
            .foregroundColor: UIColor.white
        ])
        restyle(text, pattern: "\\*[^*\\n]+\\*", marker: 1) { body, range in
            body.addAttribute(.font, value: face(size: 16, bold: false, italic: true), range: range)
            body.addAttribute(.foregroundColor, value: UIColor(red: 1, green: 0.862, blue: 0.387, alpha: 1), range: range)
        }
        restyle(text, pattern: "_[^_\\n]+_", marker: 1) { body, range in
            body.addAttribute(.font, value: face(size: 16, bold: false, italic: true), range: range)
            body.addAttribute(.foregroundColor, value: UIColor(red: 1, green: 0.862, blue: 0.387, alpha: 1), range: range)
        }
        restyle(text, pattern: "__(?!_)[^_\\n]+__", marker: 2) { body, range in
            body.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        }
        restyle(text, pattern: "\\*\\*[^*\\n]+\\*\\*", marker: 2) { body, range in
            body.addAttribute(.font, value: face(size: 16, bold: true, italic: false), range: range)
        }
        restyle(text, pattern: "~~[^~\\n]+~~", marker: 2) { body, range in
            body.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        }
        restyle(text, pattern: "\\*\\*\\*[^*\\n]+\\*\\*\\*", marker: 3) { body, range in
            body.addAttribute(.font, value: face(size: 16, bold: true, italic: true), range: range)
            body.addAttribute(.foregroundColor, value: UIColor(red: 1, green: 0.862, blue: 0.387, alpha: 1), range: range)
        }
        restyle(text, pattern: "`[^`\\n]+`", marker: 1) { body, range in
            body.addAttribute(.font, value: UIFont(name: "Menlo", size: 15) ?? UIFont.monospacedSystemFont(ofSize: 15, weight: .regular), range: range)
            body.addAttribute(.foregroundColor, value: UIColor(white: 0.906, alpha: 1), range: range)
            body.addAttribute(.backgroundColor, value: UIColor(white: 1, alpha: 0.12), range: range)
        }
        restyle(text, pattern: "\\[[^\\]\\n]+\\]\\([^\\)\\n]+\\)", marker: 0) { body, range in
            body.addAttribute(.foregroundColor, value: UIColor(red: 0, green: 0.646, blue: 1, alpha: 1), range: range)
            body.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        }

        let ns = text.string as NSString
        var index = 0
        while index < ns.length {
            let line = ns.lineRange(for: NSRange(location: index, length: 0))
            let content = ns.substring(with: line)
            if content.hasPrefix("#") {
                var count = 0
                for character in content {
                    if character == "#" {
                        count += 1
                    } else {
                        break
                    }
                }
                if count >= 1 && count <= 6 {
                    let size = CGFloat(24 - count)
                    text.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: size), range: line)
                    text.addAttribute(.foregroundColor, value: UIColor(white: 0.604, alpha: 1), range: NSRange(location: line.location, length: min(count, line.length)))
                    if line.length > count {
                        text.addAttribute(
                            .foregroundColor,
                            value: UIColor(red: 0.558, green: 1, blue: 0.502, alpha: 1),
                            range: NSRange(location: line.location + count, length: line.length - count)
                        )
                    }
                }
            } else if isRule(content) {
                text.addAttribute(.foregroundColor, value: UIColor(white: 0.604, alpha: 1), range: line)
            } else if content.hasPrefix("\t") || content.hasPrefix("    ") {
                text.addAttribute(.font, value: UIFont(name: "Menlo", size: 14) ?? font, range: line)
                text.addAttribute(.foregroundColor, value: UIColor(white: 0.906, alpha: 1), range: line)
            }
            index = line.location + line.length
            if line.length == 0 { break }
        }
        return text
    }

    private static func isRule(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else { return false }
        return trimmed.allSatisfy { $0 == "*" || $0 == "-" }
    }

    private static func restyle(
        _ text: NSMutableAttributedString,
        pattern: String,
        marker: Int,
        body: (NSMutableAttributedString, NSRange) -> Void
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }
        let raw = text.string
        let full = NSRange(location: 0, length: (raw as NSString).length)
        let gray = UIColor(white: 0.604, alpha: 1)
        regex.enumerateMatches(in: raw, options: [], range: full) { match, _, _ in
            guard let match = match, match.range.length > marker * 2 else { return }
            if marker > 0 {
                text.addAttribute(.foregroundColor, value: gray, range: NSRange(location: match.range.location, length: marker))
                text.addAttribute(
                    .foregroundColor,
                    value: gray,
                    range: NSRange(location: match.range.location + match.range.length - marker, length: marker)
                )
            }
            let inner = NSRange(location: match.range.location + marker, length: match.range.length - marker * 2)
            body(text, inner)
        }
    }

    private static func face(size: CGFloat, bold: Bool, italic: Bool) -> UIFont {
        var traits = UIFontDescriptor.SymbolicTraits()
        if bold { traits.insert(.traitBold) }
        if italic { traits.insert(.traitItalic) }
        let base = UIFont.systemFont(ofSize: size)
        if let descriptor = base.fontDescriptor.withSymbolicTraits(traits) {
            return UIFont(descriptor: descriptor, size: size)
        }
        if bold { return UIFont.boldSystemFont(ofSize: size) }
        return base
    }
}

/// 表情短码：系统 emoji（`:smile:`）+ 自定义图片（`[微笑]`）混在同一编辑框。
final class EmoticonDemoViewController: UIViewController, UITextViewDelegate {
    private let textView = UITextView()
    private let preview = ZHHTextLabel()
    private var applying = false
    private let bodyFont = UIFont.systemFont(ofSize: 18)

    private let systemItems: [(token: String, emoji: String)] = [
        (":smile:", "😄"),
        (":cool:", "😎"),
        (":biggrin:", "😁"),
        (":arrow:", "➡️"),
        (":confused:", "😕"),
        (":cry:", "😢"),
        (":wink:", "😉")
    ]

    /// 角色类：`emo_face_*`，图更大，行内按约 1.35 倍行高显示。
    private let faceItems: [(asset: String, name: String)] = [
        ("emo_face_smile", "微笑"),
        ("emo_face_laugh", "大笑"),
        ("emo_face_titter", "偷笑"),
        ("emo_face_heart", "比心"),
        ("emo_face_like", "点赞"),
        ("emo_face_melon", "吃瓜"),
        ("emo_face_dog", "狗子"),
        ("emo_face_clap", "鼓掌"),
        ("emo_face_scissors", "剪刀手"),
        ("emo_face_adore", "爱慕"),
        ("emo_face_sixsix", "666"),
        ("emo_face_daze", "发呆"),
        ("emo_face_expect", "期待"),
        ("emo_face_proud", "得意"),
        ("emo_face_silly", "憨笑"),
        ("emo_face_tongue", "吐舌")
    ]

    /// 符号类：`emo_symbol_*`，线稿更小，行内按约 1.0 倍行高显示。
    private let symbolItems: [(asset: String, name: String)] = [
        ("emo_symbol_play", "播放"),
        ("emo_symbol_pause", "暂停"),
        ("emo_symbol_stop", "停止"),
        ("emo_symbol_next", "下一首"),
        ("emo_symbol_previous", "上一首"),
        ("emo_symbol_volume_up", "音量加"),
        ("emo_symbol_volume_down", "音量减"),
        ("emo_symbol_volume_off", "静音"),
        ("emo_symbol_shuffle", "随机"),
        ("emo_symbol_replay", "重播"),
        ("emo_symbol_forward", "快进"),
        ("emo_symbol_rewind", "快退"),
        ("emo_symbol_record", "录音"),
        ("emo_symbol_equalizer", "均衡器"),
        ("emo_symbol_playlist", "列表"),
        ("emo_symbol_airplay", "投屏"),
        ("emo_symbol_cast", "投射"),
        ("emo_symbol_fullscreen", "全屏"),
        ("emo_symbol_fullscreen_exit", "退出全屏"),
        ("emo_symbol_eject", "弹出")
    ]

    /// Demo 只负责资源表；替换与 Label 转换走 `ZHHTextEmoticonMapper`。
    private lazy var mapper: ZHHTextEmoticonMapper = {
        var items: [ZHHTextEmoticonItem] = systemItems.map {
            ZHHTextEmoticonItem(token: $0.token, emoji: $0.emoji)
        }
        for item in faceItems {
            guard let image = UIImage(named: item.asset) else { continue }
            items.append(ZHHTextEmoticonItem(bracketName: item.name, image: image, sizeFactor: 1.35))
        }
        for item in symbolItems {
            guard let image = UIImage(named: item.asset) else { continue }
            items.append(ZHHTextEmoticonItem(bracketName: item.name, image: image, sizeFactor: 1))
        }
        return ZHHTextEmoticonMapper(items: items, font: bodyFont, textColor: .label)
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let systemBar = makeBar(
            title: "系统 Emoji（输入 :smile: 也会替换）",
            buttons: systemItems.enumerated().map { index, item in
                makeTextButton(title: "\(item.emoji) \(item.token)", tag: index, action: #selector(insertSystem(_:)))
            }
        )
        let faceBar = makeBar(
            title: "角色表情（输入 [微笑] 也会替换）",
            buttons: faceItems.enumerated().map { index, item in
                makeCustomButton(asset: item.asset, title: "[\(item.name)]", tag: index, action: #selector(insertFace(_:)))
            }
        )
        let symbolBar = makeBar(
            title: "符号表情（输入 [播放] 也会替换）",
            buttons: symbolItems.enumerated().map { index, item in
                makeCustomButton(asset: item.asset, title: "[\(item.name)]", tag: 1000 + index, action: #selector(insertSymbol(_:)))
            }
        )

        textView.font = bodyFont
        textView.delegate = self
        textView.keyboardDismissMode = .interactive
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        textView.typingAttributes = [
            .font: bodyFont,
            .foregroundColor: UIColor.label
        ]
        textView.translatesAutoresizingMaskIntoConstraints = false

        let previewCaption = UILabel()
        previewCaption.text = "ZHHTextLabel 预览（附件转成行内图）"
        previewCaption.font = UIFont.preferredFont(forTextStyle: .footnote)
        previewCaption.textColor = .secondaryLabel
        preview.numberOfLines = 0
        preview.clipsToBounds = false
        preview.backgroundColor = .secondarySystemBackground
        preview.layer.cornerRadius = 10
        preview.translatesAutoresizingMaskIntoConstraints = false

        let scroll = UIScrollView()
        scroll.keyboardDismissMode = .interactive
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        let column = UIStackView(arrangedSubviews: [
            systemBar, faceBar, symbolBar, textView, previewCaption, preview
        ])
        column.axis = .vertical
        column.spacing = 10
        column.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(column)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            column.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 8),
            column.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor),
            column.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor),
            column.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -12),
            textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 160),
            preview.leadingAnchor.constraint(equalTo: column.leadingAnchor, constant: 12),
            preview.trailingAnchor.constraint(equalTo: column.trailingAnchor, constant: -12)
        ])

        seedEditor()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        textView.becomeFirstResponder()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let width = view.bounds.width - 24
        if width > 0, preview.preferredMaxLayoutWidth != width {
            preview.preferredMaxLayoutWidth = width
        }
    }

    func textViewDidChange(_ textView: UITextView) {
        guard !applying else { return }
        replaceShortcodes(caret: textView.selectedRange.location)
    }

    @objc private func insertSystem(_ sender: UIButton) {
        guard systemItems.indices.contains(sender.tag) else { return }
        insertSnippet(systemItems[sender.tag].token)
    }

    @objc private func insertFace(_ sender: UIButton) {
        guard faceItems.indices.contains(sender.tag) else { return }
        insertSnippet("[\(faceItems[sender.tag].name)]")
    }

    @objc private func insertSymbol(_ sender: UIButton) {
        let index = sender.tag - 1000
        guard symbolItems.indices.contains(index) else { return }
        insertSnippet("[\(symbolItems[index].name)]")
    }

    private func seedEditor() {
        let seed = NSMutableAttributedString(
            string: "系统表情用短码 :smile: :wink:，自定义用 [微笑][比心]，可以混着写。",
            attributes: [
                .font: bodyFont,
                .foregroundColor: UIColor.label
            ]
        )
        textView.textStorage.setAttributedString(seed)
        replaceShortcodes(caret: seed.length)
    }

    private func insertSnippet(_ snippet: String) {
        let location = min(textView.selectedRange.location, textView.textStorage.length)
        let piece = NSAttributedString(string: snippet, attributes: textView.typingAttributes)
        textView.textStorage.insert(piece, at: location)
        textView.selectedRange = NSRange(location: location + piece.length, length: 0)
        replaceShortcodes(caret: location + piece.length)
    }

    /// 在 `textStorage` 上替换短码，保留已有自定义附件。
    private func replaceShortcodes(caret: Int) {
        applying = true
        let adjusted = mapper.replaceShortcodes(in: textView.textStorage, caret: caret)
        textView.selectedRange = NSRange(location: adjusted, length: 0)
        applying = false
        refreshPreview()
    }

    private func refreshPreview() {
        preview.attributedText = ZHHTextEmoticonMapper.labelCompatible(textView.textStorage, alignedTo: bodyFont)
        preview.invalidateIntrinsicContentSize()
    }

    private func makeBar(title: String, buttons: [UIView]) -> UIStackView {
        let caption = UILabel()
        caption.text = title
        caption.font = UIFont.preferredFont(forTextStyle: .footnote)
        caption.textColor = .secondaryLabel
        caption.numberOfLines = 0

        let row = UIStackView(arrangedSubviews: buttons)
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            row.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -12),
            row.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            row.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor)
        ])
        scroll.heightAnchor.constraint(equalToConstant: 44).isActive = true

        let captionWrap = UIView()
        caption.translatesAutoresizingMaskIntoConstraints = false
        captionWrap.addSubview(caption)
        NSLayoutConstraint.activate([
            caption.topAnchor.constraint(equalTo: captionWrap.topAnchor),
            caption.leadingAnchor.constraint(equalTo: captionWrap.leadingAnchor, constant: 12),
            caption.trailingAnchor.constraint(equalTo: captionWrap.trailingAnchor, constant: -12),
            caption.bottomAnchor.constraint(equalTo: captionWrap.bottomAnchor)
        ])
        let stack = UIStackView(arrangedSubviews: [captionWrap, scroll])
        stack.axis = .vertical
        stack.spacing = 4
        return stack
    }

    private func makeTextButton(title: String, tag: Int, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        button.tag = tag
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func makeCustomButton(asset: String, title: String, tag: Int, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        var config = UIButton.Configuration.plain()
        config.title = title
        config.baseForegroundColor = .label
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.systemFont(ofSize: 13)
            return outgoing
        }
        // 图标与短码、按钮之间都留空，避免「图[微笑]」糊成一团。
        config.imagePadding = 8
        config.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 10)
        if let image = UIImage(named: asset)?.withRenderingMode(.alwaysOriginal) {
            let side: CGFloat = asset.hasPrefix("emo_face_") ? 28 : 22
            config.image = image.preparingThumbnail(of: CGSize(width: side, height: side)) ?? image
        }
        config.background.backgroundColor = UIColor.secondarySystemFill
        config.background.cornerRadius = 10
        button.configuration = config
        button.tag = tag
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }
}

/// 邮箱整段绑定删除示例（系统 UITextView）。
final class BindingDemoViewController: UIViewController, UITextViewDelegate {
    private let textView = UITextView()
    private var applying = false
    private let seed = "sjobs@apple.com, apple@apple.com, banana@banana.com, pear@pear.com "

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let hint = UILabel()
        hint.text = "蓝色邮箱是一整段。在邮箱里按删除，会先选中它，再按一次才删掉。"
        hint.font = UIFont.preferredFont(forTextStyle: .footnote)
        hint.textColor = .secondaryLabel
        hint.numberOfLines = 0
        hint.translatesAutoresizingMaskIntoConstraints = false
        textView.font = UIFont.systemFont(ofSize: 18)
        textView.delegate = self
        textView.keyboardDismissMode = .interactive
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        textView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hint)
        view.addSubview(textView)
        NSLayoutConstraint.activate([
            hint.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            hint.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            hint.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            textView.topAnchor.constraint(equalTo: hint.bottomAnchor, constant: 8),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        paint(seed, caret: (seed as NSString).length)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        textView.becomeFirstResponder()
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        guard text.isEmpty, let email = emailRange(touching: range) else { return true }
        if NSEqualRanges(range, email) { return true }
        textView.selectedRange = email
        return false
    }

    func textViewDidChange(_ textView: UITextView) {
        guard !applying else { return }
        paint(textView.text ?? "", caret: textView.selectedRange.location)
    }

    private func paint(_ raw: String, caret: Int) {
        let attributed = NSMutableAttributedString(string: raw, attributes: [
            .font: UIFont.systemFont(ofSize: 18),
            .foregroundColor: UIColor.label
        ])
        if let regex = try? NSRegularExpression(pattern: "[A-Z0-9a-z._%+-]+@[A-Z0-9a-z.-]+\\.[A-Za-z]{2,}") {
            let full = NSRange(location: 0, length: (raw as NSString).length)
            regex.enumerateMatches(in: raw, options: [], range: full) { match, _, _ in
                guard let match = match else { return }
                attributed.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: match.range)
            }
        }
        applying = true
        textView.attributedText = attributed
        let length = textView.textStorage.length
        textView.selectedRange = NSRange(location: max(0, min(caret, length)), length: 0)
        applying = false
    }

    private func emailRange(touching range: NSRange) -> NSRange? {
        let raw = textView.text ?? ""
        guard let regex = try? NSRegularExpression(pattern: "[A-Z0-9a-z._%+-]+@[A-Z0-9a-z.-]+\\.[A-Za-z]{2,}") else {
            return nil
        }
        let full = NSRange(location: 0, length: (raw as NSString).length)
        var found: NSRange?
        regex.enumerateMatches(in: raw, options: [], range: full) { match, _, stop in
            guard let match = match else { return }
            let deletionEnd = range.location + range.length
            let emailEnd = match.range.location + match.range.length
            let overlaps = range.location < emailEnd && deletionEnd > match.range.location
            let backspaceAtEnd = range.length == 0 && range.location == emailEnd
            if overlaps || backspaceAtEnd {
                found = match.range
                stop.pointee = true
            }
        }
        return found
    }
}

/// 支持粘贴图片的文本框。
final class PasteAwareTextView: UITextView {
    var onPasteImage: ((UIImage) -> Void)?

    override func paste(_ sender: Any?) {
        if let image = UIPasteboard.general.image {
            onPasteImage?(image)
            return
        }
        super.paste(sender)
    }
}

/// 复制粘贴图片示例。
final class PasteDemoViewController: UIViewController {
    private let textView = PasteAwareTextView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "粘贴图片", style: .plain, target: self, action: #selector(pasteImage)),
            UIBarButtonItem(title: "插入图片", style: .plain, target: self, action: #selector(insertSample)),
            UIBarButtonItem(title: "复制", style: .plain, target: self, action: #selector(copyText))
        ]
        textView.font = UIFont.systemFont(ofSize: 17)
        textView.text = "点右上角「插入图片」，或把相册图片复制后点「粘贴图片」。也可以长按这里粘贴文字。"
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        textView.onPasteImage = { [weak self] image in
            self?.insert(image)
        }
        pinToSafeArea(textView, in: self)
    }

    @objc private func insertSample() {
        insert(DemoArtwork.mark(side: 72))
    }

    @objc private func pasteImage() {
        guard let image = UIPasteboard.general.image else {
            DemoBanner.show("剪贴板里没有图片", in: self)
            return
        }
        insert(image)
    }

    @objc private func copyText() {
        UIPasteboard.general.string = textView.text
        DemoBanner.show("已复制文字", in: self)
    }

    private func insert(_ image: UIImage) {
        let attachment = NSTextAttachment()
        attachment.image = image
        let side: CGFloat = 64
        attachment.bounds = CGRect(x: 0, y: -8, width: side, height: side)
        let piece = NSAttributedString(attachment: attachment)
        let location = min(textView.selectedRange.location, textView.textStorage.length)
        textView.textStorage.insert(piece, at: location)
        textView.selectedRange = NSRange(location: location + 1, length: 0)
    }
}

/// 撤销与重做示例。
final class UndoDemoViewController: UIViewController {
    private let textView = UITextView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "重做", style: .plain, target: self, action: #selector(redo)),
            UIBarButtonItem(title: "撤销", style: .plain, target: self, action: #selector(undo))
        ]
        textView.font = UIFont.systemFont(ofSize: 18)
        textView.text = "可以摇一摇撤销和重做，也可以点右上角的按钮。\nYou can shake the device to undo and redo."
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        pinToSafeArea(textView, in: self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        textView.becomeFirstResponder()
    }

    @objc private func undo() {
        textView.becomeFirstResponder()
        textView.undoManager?.undo()
    }

    @objc private func redo() {
        textView.becomeFirstResponder()
        textView.undoManager?.redo()
    }
}

/// 汉字假名注音示例。
final class RubyDemoViewController: UIViewController {
    private let label = ZHHTextLabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        label.numberOfLines = 0
        label.backgroundColor = UIColor(white: 0.93, alpha: 1)
        label.clipsToBounds = false
        label.attributedText = makeRuby()
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12)
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let width = view.bounds.width - 24
        if width > 0, label.preferredMaxLayoutWidth != width {
            label.preferredMaxLayoutWidth = width
        }
    }

    private func makeRuby() -> NSAttributedString {
        let font = UIFont.boldSystemFont(ofSize: 28)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.minimumLineHeight = 72
        paragraph.lineSpacing = 18
        let base: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black,
            .paragraphStyle: paragraph
        ]
        let text = NSMutableAttributedString()
        let chinese = NSMutableAttributedString(string: "这是用汉语写的一段文字。", attributes: base)
        addRuby("hàn yŭ", to: chinese, word: "汉语")
        addRuby("wén", to: chinese, word: "文")
        addRuby("zì", to: chinese, word: "字")
        text.append(chinese)
        text.append(NSAttributedString(string: "\n", attributes: base))
        let japanese = NSMutableAttributedString(string: "日本語で書いた作文です。", attributes: base)
        let pairs = [("日", "に"), ("本", "ほん"), ("語", "ご"), ("書", "か"), ("作", "さく"), ("文", "ぶん")]
        for pair in pairs {
            addRuby(pair.1, to: japanese, word: pair.0)
        }
        text.append(japanese)
        return text
    }

    private func addRuby(_ reading: String, to text: NSMutableAttributedString, word: String) {
        let range = (text.string as NSString).range(of: word)
        guard range.location != NSNotFound else { return }
        let attributes = [
            kCTFontAttributeName: UIFont.systemFont(ofSize: 11),
            kCTForegroundColorAttributeName: UIColor.darkGray.cgColor
        ] as CFDictionary
        let ruby = CTRubyAnnotationCreateWithAttributes(.center, .auto, .before, reading as CFString, attributes)
        text.addAttribute(
            NSAttributedString.Key(kCTRubyAnnotationAttributeName as String),
            value: ruby,
            range: range
        )
    }
}

/// 简易帧率标签。
final class FPSLabel: UILabel {
    private var link: CADisplayLink?
    private var last = CACurrentMediaTime()
    private var frames = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        font = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        textColor = .systemGreen
        textAlignment = .center
        text = "-- FPS"
        backgroundColor = UIColor.black.withAlphaComponent(0.72)
        layer.cornerRadius = 6
        clipsToBounds = true
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func start() {
        guard link == nil else { return }
        let display = CADisplayLink(target: self, selector: #selector(tick))
        display.add(to: .main, forMode: .common)
        link = display
    }

    deinit {
        link?.invalidate()
    }

    @objc private func tick() {
        frames += 1
        let now = CACurrentMediaTime()
        let delta = now - last
        guard delta >= 0.5 else { return }
        text = String(format: "%.0f FPS", Double(frames) / delta)
        frames = 0
        last = now
    }
}

/// UILabel 与 ZHHTextLabel 异步排版对比。
final class AsyncDemoViewController: UIViewController, UITableViewDataSource {
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let rows: [NSAttributedString]
    private let cache = ZHHTextMemoryLayoutCache(countLimit: 400)
    private let asyncSwitch = UISwitch()
    private var prefetchedWidth: CGFloat = 0
    private var useRichText = true

    init() {
        let font = UIFont.systemFont(ofSize: 12)
        let glow = shadow(color: UIColor.black.withAlphaComponent(0.45), x: 0, y: 1, radius: 1)
        rows = (0..<300).map { index in
            let sentence = "\(index) Async Display 😀 阴影描边 " + String(repeating: "ZHHTextKit ", count: 2)
            return NSAttributedString(string: sentence, attributes: [
                .font: font,
                .foregroundColor: UIColor.black,
                .strokeColor: UIColor.systemRed,
                .strokeWidth: NSNumber(value: -2),
                .shadow: glow
            ])
        }
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let fps = FPSLabel(frame: CGRect(x: 0, y: 0, width: 72, height: 26))
        fps.start()
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: fps)

        let header = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 56))
        let caption = UILabel()
        caption.text = "ZHHTextKit 异步"
        caption.font = UIFont.systemFont(ofSize: 16)
        asyncSwitch.isOn = true
        asyncSwitch.addTarget(self, action: #selector(switchChanged), for: .valueChanged)
        caption.translatesAutoresizingMaskIntoConstraints = false
        asyncSwitch.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(caption)
        header.addSubview(asyncSwitch)
        NSLayoutConstraint.activate([
            caption.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
            caption.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            asyncSwitch.leadingAnchor.constraint(equalTo: caption.trailingAnchor, constant: 12),
            asyncSwitch.centerYAnchor.constraint(equalTo: header.centerYAnchor)
        ])
        tableView.tableHeaderView = header
        tableView.dataSource = self
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        tableView.rowHeight = 40
        tableView.register(AsyncDemoCell.self, forCellReuseIdentifier: AsyncDemoCell.reuseID)
        pinToSafeArea(tableView, in: self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let width = tableView.bounds.width - 24
        guard width > 1, abs(width - prefetchedWidth) >= 0.5 else { return }
        prefetchedWidth = width
        let style = ZHHTextStyle()
        let interfaceStyle = traitCollection.userInterfaceStyle
        let inputs = rows.map { text in
            ZHHTextLayoutInput(
                attributedText: text,
                links: [],
                width: width,
                numberOfLines: 1,
                isExpanded: false,
                style: style,
                interfaceStyle: interfaceStyle
            )
        }
        ZHHTextLayoutPrefetcher.prefetch(inputs, cache: cache, completion: nil)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: AsyncDemoCell.reuseID, for: indexPath) as! AsyncDemoCell
        cell.apply(rows[indexPath.row], rich: useRichText, cache: cache)
        return cell
    }

    @objc private func switchChanged() {
        useRichText = asyncSwitch.isOn
        tableView.reloadData()
    }
}

/// Async Display 列表 Cell。
private final class AsyncDemoCell: UITableViewCell {
    static let reuseID = "AsyncDemoCell"
    private let plain = UILabel()
    private let rich = ZHHTextLabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        plain.numberOfLines = 1
        rich.numberOfLines = 1
        rich.displaysAsynchronously = true
        contentView.addSubview(plain)
        contentView.addSubview(rich)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let rect = contentView.bounds.insetBy(dx: 12, dy: 4)
        plain.frame = rect
        rich.frame = rect
        if rect.width > 0 {
            rich.preferredMaxLayoutWidth = rect.width
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        rich.attributedText = nil
        plain.attributedText = nil
    }

    func apply(_ text: NSAttributedString, rich useRich: Bool, cache: ZHHTextLayoutCache) {
        plain.isHidden = useRich
        rich.isHidden = !useRich
        rich.layoutCache = cache
        if useRich {
            rich.attributedText = text
        } else {
            plain.attributedText = text
        }
    }
}

/// ZHHTextView 输入 @ / 话题示例：触发选人、发布文档、查看页回显。
final class EditorDemoViewController: UIViewController {
    private let editor = ZHHTextView()
    private let summary = UILabel()
    private let payloadLabel = UILabel()
    private let previewCaption = UILabel()
    private let previewLabel = ZHHTextLabel()
    private var style = ZHHTextStyle()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "发布", style: .done, target: self, action: #selector(publishTapped)),
            UIBarButtonItem(title: "#话题", style: .plain, target: self, action: #selector(insertTopic)),
            UIBarButtonItem(title: "@小红", style: .plain, target: self, action: #selector(insertMention))
        ]

        let hint = UILabel()
        hint.text = "输入 #/@ 弹出推荐（可手打继续）。选中的带 id 进发布文档；手打无 id 交给服务端。下方是「详情回显」：只消费 entities 点击。"
        hint.font = UIFont.preferredFont(forTextStyle: .footnote)
        hint.textColor = .secondaryLabel
        hint.numberOfLines = 0

        summary.font = UIFont.preferredFont(forTextStyle: .subheadline)
        summary.textColor = .label
        summary.numberOfLines = 0
        summary.text = "等待输入"

        payloadLabel.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        payloadLabel.textColor = .secondaryLabel
        payloadLabel.numberOfLines = 0
        payloadLabel.text = "点右上角「发布」查看 text + entities JSON"

        previewCaption.font = UIFont.preferredFont(forTextStyle: .footnote)
        previewCaption.textColor = .secondaryLabel
        previewCaption.text = "查看页（模拟服务端回显后）"

        style.font = UIFont.systemFont(ofSize: 18)
        style.textColor = .label
        style.topicColor = .systemOrange
        style.mentionColor = .systemTeal
        style.urlColor = .systemBlue
        style.phoneColor = .systemPurple
        style.lineSpacing = 4
        var parser = ZHHTextParser(style: style)
        parser.topicRule.bindings = [ZHHTextTopicBinding(name: "周末去哪儿", topicID: "t-100")]
        parser.mentionRule.bindings = [ZHHTextMentionBinding(name: "小明", userID: "u-1001")]

        editor.backgroundColor = .secondarySystemBackground
        editor.layer.cornerRadius = 8
        editor.clipsToBounds = true
        editor.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        editor.onSpecialTrigger = { [weak self] trigger in
            self?.presentPicker(for: trigger)
        }
        editor.onEdit = { [weak self] result in
            self?.summary.text = EditorDemoViewController.describe(result)
        }
        editor.parser = parser
        editor.text = "约 @小明 看 #周末去哪儿 ，详情 https://example.com"

        previewLabel.numberOfLines = 0
        previewLabel.onTapLink = { [weak self] link in
            self?.summary.text = "查看页点击 → " + EditorDemoViewController.describeLink(link)
        }

        let scroll = UIScrollView()
        scroll.delaysContentTouches = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        let column = UIStackView(arrangedSubviews: [hint, summary, editor, payloadLabel, previewCaption, previewLabel])
        column.axis = .vertical
        column.spacing = 12
        column.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(column)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            column.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 12),
            column.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 16),
            column.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -16),
            column.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -12),
            editor.heightAnchor.constraint(greaterThanOrEqualToConstant: 140)
        ])
        refreshPreview(with: editor.makePostDocument())
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        editor.becomeFirstResponder()
    }

    @objc private func insertMention() {
        editor.insert(mention: ZHHTextMention(name: "小红", userID: "u-2002"))
    }

    @objc private func insertTopic() {
        editor.insert(topic: ZHHTextTopic(name: "城市漫步", topicID: "t-200"))
    }

    @objc private func publishTapped() {
        editor.resignFirstResponder()
        // 客户端：上报 text + 已选 entities。服务端会补手打片段的 id（此处用本地模拟）。
        let client = editor.makePostDocument()
        let echoed = EditorDemoViewController.simulateServerResolve(client)
        payloadLabel.text = echoed.jsonString() ?? "{}"
        refreshPreview(with: echoed)
        summary.text = "已发布（模拟）。查看页只使用服务端 entities 跳转。\n客户端已选 \(client.entities.count) 个；回显 \(echoed.entities.count) 个。"
    }

    private func presentPicker(for trigger: ZHHTextSpecialTrigger) {
        let sheet = UIAlertController(
            title: trigger == .mention ? "选人" : "选话题",
            message: "选中后 insert；取消则可继续手打",
            preferredStyle: .actionSheet
        )
        switch trigger {
        case .mention:
            sheet.addAction(UIAlertAction(title: "@小红", style: .default, handler: { [weak self] _ in
                self?.editor.insert(mention: ZHHTextMention(name: "小红", userID: "u-2002"))
            }))
            sheet.addAction(UIAlertAction(title: "@阿柚", style: .default, handler: { [weak self] _ in
                self?.editor.insert(mention: ZHHTextMention(name: "阿柚", userID: "u-3003"))
            }))
        case .topic:
            sheet.addAction(UIAlertAction(title: "#城市漫步", style: .default, handler: { [weak self] _ in
                self?.editor.insert(topic: ZHHTextTopic(name: "城市漫步", topicID: "t-200"))
            }))
            sheet.addAction(UIAlertAction(title: "#深夜食堂", style: .default, handler: { [weak self] _ in
                self?.editor.insert(topic: ZHHTextTopic(name: "深夜食堂", topicID: "t-300"))
            }))
        }
        sheet.addAction(UIAlertAction(title: "继续手打", style: .cancel))
        present(sheet, animated: true)
    }

    private func refreshPreview(with document: ZHHTextPostDocument) {
        let parser = ZHHTextParser(style: style)
        let result = parser.parse(document)
        previewLabel.apply(result)
    }

    /// 模拟服务端：保留客户端已选，并给仍无 id 的话题 / 提及补一个演示 id。
    private static func simulateServerResolve(_ document: ZHHTextPostDocument) -> ZHHTextPostDocument {
        var parser = ZHHTextParser()
        parser.options = [.topic, .mention]
        let parsed = parser.parse(document.text)
        var entities = document.entities
        let covered = entities.map(\.range)
        for link in parsed.links {
            let overlaps = covered.contains { NSIntersectionRange($0, link.range).length > 0 }
            if overlaps { continue }
            switch link.kind {
            case .mention(let mention) where mention.userID == nil:
                entities.append(ZHHTextEntity(
                    type: .mention,
                    id: "server-u-\(mention.name)",
                    name: mention.name,
                    range: link.range
                ))
            case .topic(let topic) where topic.topicID == nil:
                entities.append(ZHHTextEntity(
                    type: .topic,
                    id: "server-t-\(topic.name)",
                    name: topic.name,
                    range: link.range
                ))
            default:
                break
            }
        }
        entities.sort { $0.location < $1.location }
        return ZHHTextPostDocument(text: document.text, entities: entities)
    }

    private static func describe(_ result: ZHHTextParseResult) -> String {
        if result.links.isEmpty { return "还没有链接" }
        return result.links.map(describeLink).joined(separator: "\n")
    }

    private static func describeLink(_ link: ZHHTextLink) -> String {
        switch link.kind {
        case .mention(let mention):
            return "@\(mention.name) id=\(mention.userID ?? "-")"
        case .topic(let topic):
            return "#\(topic.name) id=\(topic.topicID ?? "-")"
        case .url(let url):
            return url.absoluteString
        case .phone(let number):
            return number
        case .custom(let custom):
            return custom.identifier
        }
    }
}
