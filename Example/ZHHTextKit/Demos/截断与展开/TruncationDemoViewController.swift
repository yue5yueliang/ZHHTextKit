//
//  TruncationDemoViewController.swift
//  ZHHTextKit
//
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import UIKit
import ZHHTextKit

/// 「截断与展开」页面：视图绑定；文案与长按处理在 ViewModel。
final class TruncationDemoViewController: UIViewController {
    private let viewModel = TruncationDemoViewModel()
    private let shortLabel = ZHHTextLabel()
    private let customLabel = ZHHTextLabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        configureDefaultLabel()
        configureCustomLabel()
        setupLayout()
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

    private func configureDefaultLabel() {
        shortLabel.numberOfLines = 3
        shortLabel.showsCollapsedToken = true
        shortLabel.showsExpandedToken = true
        shortLabel.collapsedLinkText = "全文"
        shortLabel.expandedLinkText = "收起"
        shortLabel.clipsToBounds = false
        shortLabel.allowsLongPressCopy = true
        shortLabel.text = viewModel.longText
        shortLabel.onTapExpand = { [weak self] expanded in
            guard let self = self else { return }
            DemoBanner.show(self.viewModel.expandBanner(expanded: expanded, custom: false), in: self)
        }
        shortLabel.onTapLink = { [weak self] link in
            guard let self = self else { return }
            DemoBanner.show(self.viewModel.linkBanner(for: link), in: self)
        }
        shortLabel.onLongPress = { [weak self] info in
            guard let self = self else { return }
            DemoBanner.show(self.viewModel.handleLongPress(info), in: self)
        }
    }

    private func configureCustomLabel() {
        customLabel.numberOfLines = 2
        customLabel.showsExpandedToken = false
        customLabel.truncationToken = viewModel.makeCustomTruncationToken()
        customLabel.clipsToBounds = false
        customLabel.text = viewModel.longText
        customLabel.onTapExpand = { [weak self] expanded in
            guard let self = self else { return }
            DemoBanner.show(self.viewModel.expandBanner(expanded: expanded, custom: true), in: self)
        }
    }

    private func setupLayout() {
        let scroll = UIScrollView()
        scroll.delaysContentTouches = false
        pinToSafeArea(scroll, in: self)
        let column = UIStackView(arrangedSubviews: [
            makeCaption(viewModel.defaultCaption),
            wrapCard(shortLabel),
            makeCaption(viewModel.customCaption),
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
