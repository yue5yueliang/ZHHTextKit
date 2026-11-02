//
//  FeedDemoViewController.swift
//  ZHHTextKit
//
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import UIKit
import ZHHTextKit

/// 社区 Feed 示例：单条预览 + 列表复用 + 布局缓存预取。
final class FeedDemoViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private let viewModel = FeedDemoViewModel()
    private let cache = ZHHTextMemoryLayoutCache(countLimit: 80)
    private var prefetchedWidth: CGFloat = 0
    private var toastToken = 0

    private let toastLabel = UILabel()
    private let captionLabel = UILabel()
    private let previewLabel = ZHHTextLabel()
    private let tableView = UITableView(frame: .zero, style: .plain)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = viewModel.title
        configureToast()
        configurePreview()
        configureTable()
        layoutViews()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let previewWidth = previewLabel.bounds.width
        if previewWidth > 0, previewLabel.preferredMaxLayoutWidth != previewWidth {
            previewLabel.preferredMaxLayoutWidth = previewWidth
        }
        prefetchIfNeeded()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: FeedTextCell.reuseID, for: indexPath) as! FeedTextCell
        let item = viewModel.items[indexPath.row]
        let width = max(tableView.bounds.width - 32, 0)
        cell.configure(
            document: item.document,
            expanded: viewModel.isExpanded(id: item.id),
            parser: viewModel.parser,
            cache: cache,
            width: width,
            onLink: { [weak self] link in
                guard let self = self else { return }
                self.showToast(self.viewModel.message(for: link))
            },
            onExpand: { [weak self] expanded in
                guard let self = self else { return }
                self.viewModel.setExpanded(expanded, id: item.id)
                self.showToast(self.viewModel.expandToast(expanded))
                UIView.performWithoutAnimation {
                    self.tableView.beginUpdates()
                    self.tableView.endUpdates()
                    self.tableView.layoutIfNeeded()
                }
            }
        )
        return cell
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        viewModel.listHeaderTitle
    }

    private func configureToast() {
        toastLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        toastLabel.textColor = .label
        toastLabel.backgroundColor = .secondarySystemBackground
        toastLabel.numberOfLines = 2
        toastLabel.textAlignment = .center
        toastLabel.text = viewModel.idleToast
    }

    private func configurePreview() {
        captionLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        captionLabel.textColor = .label
        captionLabel.text = viewModel.previewCaption

        previewLabel.numberOfLines = 3
        previewLabel.style = viewModel.parser.style
        previewLabel.apply(viewModel.parser.parse(viewModel.previewDocument()))
        previewLabel.onTapLink = { [weak self] link in
            guard let self = self else { return }
            self.showToast(self.viewModel.message(for: link))
        }
        previewLabel.onTapExpand = { [weak self] expanded in
            guard let self = self else { return }
            self.showToast(self.viewModel.expandToast(expanded))
        }
    }

    private func configureTable() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 96
        tableView.backgroundColor = .systemBackground
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        tableView.allowsSelection = false
        tableView.delaysContentTouches = false
        tableView.register(FeedTextCell.self, forCellReuseIdentifier: FeedTextCell.reuseID)
    }

    private func layoutViews() {
        let wrap = UIView()
        previewLabel.translatesAutoresizingMaskIntoConstraints = false
        wrap.addSubview(previewLabel)
        NSLayoutConstraint.activate([
            previewLabel.topAnchor.constraint(equalTo: wrap.topAnchor, constant: 8),
            previewLabel.leadingAnchor.constraint(equalTo: wrap.leadingAnchor, constant: 16),
            previewLabel.trailingAnchor.constraint(equalTo: wrap.trailingAnchor, constant: -16),
            previewLabel.bottomAnchor.constraint(equalTo: wrap.bottomAnchor, constant: -8)
        ])

        captionLabel.translatesAutoresizingMaskIntoConstraints = false
        let captionWrap = UIView()
        captionWrap.addSubview(captionLabel)
        NSLayoutConstraint.activate([
            captionLabel.topAnchor.constraint(equalTo: captionWrap.topAnchor, constant: 8),
            captionLabel.leadingAnchor.constraint(equalTo: captionWrap.leadingAnchor, constant: 16),
            captionLabel.trailingAnchor.constraint(equalTo: captionWrap.trailingAnchor, constant: -16),
            captionLabel.bottomAnchor.constraint(equalTo: captionWrap.bottomAnchor, constant: -4)
        ])

        toastLabel.translatesAutoresizingMaskIntoConstraints = false
        let column = UIStackView(arrangedSubviews: [toastLabel, captionWrap, wrap, tableView])
        column.axis = .vertical
        column.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(column)
        NSLayoutConstraint.activate([
            toastLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 36),
            column.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            column.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            column.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            column.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        tableView.setContentHuggingPriority(.defaultLow, for: .vertical)
        tableView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
    }

    private func prefetchIfNeeded() {
        let width = tableView.bounds.width - 32
        guard width > 1, abs(width - prefetchedWidth) >= 0.5 else { return }
        prefetchedWidth = width
        let inputs = viewModel.items.map {
            viewModel.layoutInput(for: $0, width: width, interfaceStyle: traitCollection.userInterfaceStyle)
        }
        ZHHTextLayoutPrefetcher.prefetch(inputs, cache: cache, completion: nil)
    }

    private func showToast(_ message: String) {
        toastToken += 1
        let token = toastToken
        toastLabel.text = message
        print("ZHHTextKit \(message)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            guard let self = self, self.toastToken == token else { return }
            self.toastLabel.text = self.viewModel.idleToast
        }
    }
}

/// Feed 列表 Cell，承载一条 `ZHHTextLabel`。
private final class FeedTextCell: UITableViewCell {
    static let reuseID = "FeedTextCell"
    let body = ZHHTextLabel()
    private var didBindParser = false

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .systemBackground
        contentView.backgroundColor = .systemBackground
        body.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(body)
        NSLayoutConstraint.activate([
            body.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            body.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            body.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            body.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        body.text = nil
        body.isExpanded = false
        body.onTapLink = nil
        body.onTapExpand = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = contentView.bounds.width - 32
        if width > 0, body.preferredMaxLayoutWidth != width {
            body.preferredMaxLayoutWidth = width
        }
    }

    func configure(
        document: ZHHTextPostDocument,
        expanded: Bool,
        parser: ZHHTextParser,
        cache: ZHHTextLayoutCache,
        width: CGFloat,
        onLink: @escaping (ZHHTextLink) -> Void,
        onExpand: @escaping (Bool) -> Void
    ) {
        if !didBindParser {
            body.numberOfLines = 3
            body.displaysAsynchronously = true
            didBindParser = true
        }
        body.style = parser.style
        body.layoutCache = cache
        if width > 0 {
            body.preferredMaxLayoutWidth = width
        }
        body.isExpanded = expanded
        body.apply(parser.parse(document))
        body.onTapLink = onLink
        body.onTapExpand = onExpand
    }
}
