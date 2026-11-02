//
//  BindingDemoViewController.swift
//  ZHHTextKit
//
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import UIKit
import ZHHTextKit

final class BindingDemoViewController: UIViewController, UITextViewDelegate {
    private let viewModel = BindingDemoViewModel()
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
