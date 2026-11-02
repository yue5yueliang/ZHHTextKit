//
//  EditDemoViewController.swift
//  ZHHTextKit
//
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import UIKit
import ZHHTextKit

final class EditDemoViewController: UIViewController, UITextViewDelegate {
    private let viewModel = EditDemoViewModel()
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
