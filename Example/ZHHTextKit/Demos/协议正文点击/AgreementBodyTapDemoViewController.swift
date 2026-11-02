//
//  AgreementBodyTapDemoViewController.swift
//  ZHHTextKit
//
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import UIKit
import ZHHTextKit

/// 「协议正文点击」页面：只负责视图绑定，状态在 ViewModel。
final class AgreementBodyTapDemoViewController: UIViewController {
    private let viewModel = AgreementBodyTapDemoViewModel()
    private let checkbox = UIButton(type: .custom)
    private let agreementLabel = ZHHTextLabel()
    private let statusLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupCheckbox()
        setupAgreementLabel()
        setupStatus()
        setupLayout()
        bind()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let width = viewModel.contentWidth(forContainerWidth: view.bounds.width)
        guard width > 0, agreementLabel.preferredMaxLayoutWidth != width else { return }
        agreementLabel.preferredMaxLayoutWidth = width
    }

    private func setupCheckbox() {
        let unchecked = UIImage(named: "ic_common_checkbox_unchecked")?.withRenderingMode(.alwaysOriginal)
        let checked = UIImage(named: "ic_common_checkbox_checked")?.withRenderingMode(.alwaysOriginal)
        checkbox.setImage(unchecked, for: .normal)
        checkbox.setImage(checked, for: .selected)
        checkbox.imageView?.contentMode = .scaleAspectFit
        checkbox.addTarget(self, action: #selector(toggleAgreement), for: .touchUpInside)
        checkbox.setContentHuggingPriority(.required, for: .horizontal)
        checkbox.setContentCompressionResistancePriority(.required, for: .horizontal)
        checkbox.accessibilityLabel = "同意协议"
    }

    private func setupAgreementLabel() {
        let style = viewModel.makeStyle()
        agreementLabel.style = style
        agreementLabel.allowsBodyTap = true
        agreementLabel.numberOfLines = 0
        agreementLabel.clipsToBounds = false
        agreementLabel.apply(viewModel.makeAgreementResult(style: style))
        agreementLabel.onTapBody = { [weak self] in
            self?.toggleAgreement()
        }
        agreementLabel.onTapLink = { [weak self] link in
            guard let self = self else { return }
            DemoBanner.show("打开 \(self.viewModel.bannerTitle(for: link))", in: self)
        }
    }

    private func setupStatus() {
        statusLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        statusLabel.textColor = .secondaryLabel
        statusLabel.numberOfLines = 0
    }

    private func setupLayout() {
        let row = UIStackView(arrangedSubviews: [checkbox, agreementLabel])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 0

        let card = UIView()
        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)
        let checkboxSide = viewModel.checkboxSide
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            checkbox.widthAnchor.constraint(equalToConstant: checkboxSide),
            checkbox.heightAnchor.constraint(equalToConstant: checkboxSide)
        ])

        let scroll = UIScrollView()
        scroll.delaysContentTouches = false
        pinToSafeArea(scroll, in: self)
        let column = UIStackView(arrangedSubviews: [
            makeCaption(viewModel.caption),
            card,
            statusLabel
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

    private func bind() {
        checkbox.isSelected = viewModel.isChecked
        statusLabel.text = viewModel.statusText
    }

    @objc private func toggleAgreement() {
        let message = viewModel.toggleAgreement()
        bind()
        DemoBanner.show(message, in: self)
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
