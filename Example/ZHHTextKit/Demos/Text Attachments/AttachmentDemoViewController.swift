//
//  AttachmentDemoViewController.swift
//  ZHHTextKit
//
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import CoreText
import UIKit
import ZHHTextKit

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
    private let viewModel = AttachmentDemoViewModel()
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
