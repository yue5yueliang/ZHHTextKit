//
//  PasteDemoViewController.swift
//  ZHHTextKit
//
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import UIKit
import ZHHTextKit

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
    private let viewModel = PasteDemoViewModel()
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
