//
//  MarkdownDemoViewController.swift
//  ZHHTextKit
//
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import UIKit
import ZHHTextKit

final class MarkdownDemoViewController: UIViewController, UITextViewDelegate {
    private let viewModel = MarkdownDemoViewModel()
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

enum DemoMarkdown {
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
