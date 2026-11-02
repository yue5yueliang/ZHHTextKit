//
//  FeedDemoViewController.swift
//  ZHHTextKit
//
//  Created by 桃色三岁 on 2026/10/26.
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import UIKit
import ZHHTextKit

/// 社区 Feed 示例：单条预览 + 列表复用 + 布局缓存预取。
final class FeedDemoViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private let cache = ZHHTextMemoryLayoutCache(countLimit: 80)
    private let parser: ZHHTextParser
    private let items: [FeedItem]
    private var expandedIDs = Set<Int>()
    private var prefetchedWidth: CGFloat = 0
    private var toastToken = 0

    private let toastLabel = UILabel()
    private let captionLabel = UILabel()
    private let previewLabel = ZHHTextLabel()
    private let tableView = UITableView(frame: .zero, style: .plain)

    init() {
        let built = FeedDemoViewController.makeContent()
        parser = built.parser
        items = built.items
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        let built = FeedDemoViewController.makeContent()
        parser = built.parser
        items = built.items
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "社区 Feed"
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
        items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: FeedTextCell.reuseID, for: indexPath) as! FeedTextCell
        let item = items[indexPath.row]
        let width = max(tableView.bounds.width - 32, 0)
        cell.configure(
            document: item.document,
            expanded: expandedIDs.contains(item.id),
            parser: parser,
            cache: cache,
            width: width,
            onLink: { [weak self] link in
                self?.showToast(self?.message(for: link) ?? "")
            },
            onExpand: { [weak self] expanded in
                guard let self = self else { return }
                if expanded {
                    self.expandedIDs.insert(item.id)
                } else {
                    self.expandedIDs.remove(item.id)
                }
                self.showToast(expanded ? "展开" : "收起")
                // Label 已先切到展开排版；若再带动画改行高，cell 高度插值会把文字纵向拉扁/拉高。
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
        "列表复用 · \(items.count) 条，向下滑动"
    }

    private func configureToast() {
        toastLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        toastLabel.textColor = .label
        toastLabel.backgroundColor = .secondarySystemBackground
        toastLabel.numberOfLines = 2
        toastLabel.textAlignment = .center
        toastLabel.text = "点击链接、全文或收起"
    }

    private func configurePreview() {
        captionLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        captionLabel.textColor = .label
        captionLabel.text = "单条：下发 entities 后的查看态（点击带 id）"

        previewLabel.numberOfLines = 3
        previewLabel.style = parser.style
        let previewText = """
        周末去 #周末去哪儿 找 @小明 拿票，详情 https://example.com/event ，电话 13800138000。\
        这条预览故意写长，用来看三行之后的全文和收起，截断以后前面的链接也要能点。\
        再补一句 #城市漫步 ，避免刚好卡在行尾。
        """
        let previewDocument = FeedDemoViewController.makeDocument(
            text: previewText,
            topicName: "周末去哪儿",
            topicID: "t-100",
            mentionName: "小明",
            userID: "u-1001",
            extraTopicName: "城市漫步",
            extraTopicID: "t-200"
        )
        previewLabel.apply(parser.parse(previewDocument))
        previewLabel.onTapLink = { [weak self] link in
            self?.showToast(self?.message(for: link) ?? "")
        }
        previewLabel.onTapExpand = { [weak self] expanded in
            self?.showToast(expanded ? "展开" : "收起")
        }
    }

    private func configureTable() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 96
        tableView.backgroundColor = .systemBackground
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        // 避免轻点「全文」时 table 抢手势 / 误进 didSelect 提示「未点中链接」。
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
        let inputs = items.map { item in
            input(for: item, width: width)
        }
        ZHHTextLayoutPrefetcher.prefetch(inputs, cache: cache, completion: nil)
    }

    private func input(for item: FeedItem, width: CGFloat) -> ZHHTextLayoutInput {
        let parsed = parser.parse(item.document)
        return ZHHTextLayoutInput(
            attributedText: parsed.attributedText,
            links: parsed.links,
            width: width,
            numberOfLines: 3,
            isExpanded: expandedIDs.contains(item.id),
            style: parser.style,
            interfaceStyle: traitCollection.userInterfaceStyle
        )
    }

    private func showToast(_ message: String) {
        toastToken += 1
        let token = toastToken
        toastLabel.text = message
        print("ZHHTextKit \(message)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            guard let self = self, self.toastToken == token else { return }
            self.toastLabel.text = "点击链接、全文或收起"
        }
    }

    private func message(for link: ZHHTextLink) -> String {
        switch link.kind {
        case .url(let url):
            return "url \(url.absoluteString)"
        case .phone(let number):
            return "phone \(number)"
        case .topic(let topic):
            return "topic \(topic.name) id=\(topic.topicID ?? "-")"
        case .mention(let mention):
            return "mention \(mention.name) id=\(mention.userID ?? "-")"
        case .custom(let custom):
            return "custom \(custom.identifier)"
        }
    }

    private static func makeContent() -> (parser: ZHHTextParser, items: [FeedItem]) {
        var style = ZHHTextStyle()
        style.font = UIFont.systemFont(ofSize: 16)
        style.textColor = .label
        style.linkColor = DemoPalette.link
        style.topicColor = DemoPalette.topic
        style.mentionColor = DemoPalette.mention
        style.urlColor = DemoPalette.link
        style.phoneColor = DemoPalette.phone
        style.truncationColor = DemoPalette.link
        style.highlightColor = DemoPalette.link.withAlphaComponent(0.18)
        style.lineSpacing = 4
        let parser = ZHHTextParser(style: style)
        let items = (0..<40).map { index -> FeedItem in
            let extra: String
            if index % 3 == 0 {
                extra = String(repeating: "这里是补充说明，用来把正文撑过三行。", count: 3)
            } else if index % 3 == 1 {
                extra = "这是一条短内容。"
            } else {
                extra = String(repeating: "中等长度的描述。", count: 2)
            }
            let text = "第\(index)条 约 @小明 看 #周末去哪儿 ，链接 https://example.com/feed/\(index) ，电话 13800138000。\(extra)"
            let document = makeDocument(
                text: text,
                topicName: "周末去哪儿",
                topicID: "t-100",
                mentionName: "小明",
                userID: "u-1001"
            )
            return FeedItem(id: index, document: document)
        }
        return (parser, items)
    }

    /// 构造「服务端已补 id」的文档，供查看页直接消费。
    private static func makeDocument(
        text: String,
        topicName: String,
        topicID: String,
        mentionName: String,
        userID: String,
        extraTopicName: String? = nil,
        extraTopicID: String? = nil
    ) -> ZHHTextPostDocument {
        let ns = text as NSString
        var entities: [ZHHTextEntity] = []
        let mentionNeedle = "@\(mentionName)"
        let mentionRange = ns.range(of: mentionNeedle)
        if mentionRange.location != NSNotFound {
            entities.append(ZHHTextEntity(type: .mention, id: userID, name: mentionName, range: mentionRange))
        }
        let topicNeedle = "#\(topicName)"
        let topicRange = ns.range(of: topicNeedle)
        if topicRange.location != NSNotFound {
            entities.append(ZHHTextEntity(type: .topic, id: topicID, name: topicName, range: topicRange))
        }
        if let extraTopicName, let extraTopicID {
            let extraNeedle = "#\(extraTopicName)"
            let extraRange = ns.range(of: extraNeedle, options: .backwards)
            if extraRange.location != NSNotFound {
                entities.append(ZHHTextEntity(type: .topic, id: extraTopicID, name: extraTopicName, range: extraRange))
            }
        }
        entities.sort { $0.location < $1.location }
        return ZHHTextPostDocument(text: text, entities: entities)
    }
}

private struct FeedItem {
    let id: Int
    /// 模拟详情接口下发的正文 + entities。
    let document: ZHHTextPostDocument
}

private enum DemoPalette {
    static let link = UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(red: 0.55, green: 0.78, blue: 1, alpha: 1)
        }
        return UIColor(red: 0.08, green: 0.38, blue: 0.78, alpha: 1)
    }
    static let topic = UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(red: 1, green: 0.72, blue: 0.35, alpha: 1)
        }
        return UIColor(red: 0.78, green: 0.42, blue: 0.08, alpha: 1)
    }
    static let mention = UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(red: 0.55, green: 0.85, blue: 0.70, alpha: 1)
        }
        return UIColor(red: 0.05, green: 0.50, blue: 0.40, alpha: 1)
    }
    static let phone = UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            return UIColor(red: 0.78, green: 0.68, blue: 1, alpha: 1)
        }
        return UIColor(red: 0.38, green: 0.28, blue: 0.72, alpha: 1)
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
