//
//  InlineChipComposerDemoViewController.swift
//  ZHHTextKit
//
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import UIKit
import ZHHTextKit

final class InlineChipComposerDemoViewController: UIViewController, UITextViewDelegate {
    private let viewModel = InlineChipComposerDemoViewModel()
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
