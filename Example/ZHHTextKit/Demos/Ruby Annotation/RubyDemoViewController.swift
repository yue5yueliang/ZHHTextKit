//
//  RubyDemoViewController.swift
//  ZHHTextKit
//
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import CoreText
import UIKit
import ZHHTextKit

final class RubyDemoViewController: UIViewController {
    private let viewModel = RubyDemoViewModel()
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
