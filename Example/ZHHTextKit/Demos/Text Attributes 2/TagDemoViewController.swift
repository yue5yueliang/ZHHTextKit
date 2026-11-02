//
//  TagDemoViewController.swift
//  ZHHTextKit
//
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import UIKit
import ZHHTextKit

final class TagDemoViewController: UIViewController, UITextViewDelegate {
    private let viewModel = TagDemoViewModel()
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
