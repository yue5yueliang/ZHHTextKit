//
//  EditorDemoViewController.swift
//  ZHHTextKit
//
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import UIKit
import ZHHTextKit

final class EditorDemoViewController: UIViewController {
    private let viewModel = EditorDemoViewModel()
    private let editor = ZHHTextView()
    private let summary = UILabel()
    private let payloadLabel = UILabel()
    private let previewCaption = UILabel()
    private let previewLabel = ZHHTextLabel()
    private var style = ZHHTextStyle()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "发布", style: .done, target: self, action: #selector(publishTapped)),
            UIBarButtonItem(title: "#话题", style: .plain, target: self, action: #selector(insertTopic)),
            UIBarButtonItem(title: "@小红", style: .plain, target: self, action: #selector(insertMention))
        ]

        let hint = UILabel()
        hint.text = "输入 #/@ 弹出推荐（可手打继续）。选中的带 id 进发布文档；手打无 id 交给服务端。下方是「详情回显」：只消费 entities 点击。"
        hint.font = UIFont.preferredFont(forTextStyle: .footnote)
        hint.textColor = .secondaryLabel
        hint.numberOfLines = 0

        summary.font = UIFont.preferredFont(forTextStyle: .subheadline)
        summary.textColor = .label
        summary.numberOfLines = 0
        summary.text = "等待输入"

        payloadLabel.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        payloadLabel.textColor = .secondaryLabel
        payloadLabel.numberOfLines = 0
        payloadLabel.text = "点右上角「发布」查看 text + entities JSON"

        previewCaption.font = UIFont.preferredFont(forTextStyle: .footnote)
        previewCaption.textColor = .secondaryLabel
        previewCaption.text = "查看页（模拟服务端回显后）"

        style.font = UIFont.systemFont(ofSize: 18)
        style.textColor = .label
        style.topicColor = .systemOrange
        style.mentionColor = .systemTeal
        style.urlColor = .systemBlue
        style.phoneColor = .systemPurple
        style.lineSpacing = 4
        var parser = ZHHTextParser(style: style)
        parser.topicRule.bindings = [ZHHTextTopicBinding(name: "周末去哪儿", topicID: "t-100")]
        parser.mentionRule.bindings = [ZHHTextMentionBinding(name: "小明", userID: "u-1001")]

        editor.backgroundColor = .secondarySystemBackground
        editor.layer.cornerRadius = 8
        editor.clipsToBounds = true
        editor.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        editor.placeholder = "说点什么吧，试试 @ 和 #"
        editor.placeholderColor = .tertiaryLabel
        // Demo 用较小上限方便验收；业务可设 500 或不设。
        editor.maxTextLength = 40
        editor.onReachMaxLength = { [weak self] in
            self?.summary.text = "已达字数上限（40）"
        }
        editor.onSpecialTrigger = { [weak self] trigger in
            self?.presentPicker(for: trigger)
        }
        editor.onEdit = { [weak self] result in
            self?.summary.text = EditorDemoViewController.describe(result)
        }
        editor.parser = parser
        // 空文便于看到占位；点工具栏或输入后占位会隐藏。
        editor.text = ""

        previewLabel.numberOfLines = 0
        previewLabel.onTapLink = { [weak self] link in
            self?.summary.text = "查看页点击 → " + EditorDemoViewController.describeLink(link)
        }

        let scroll = UIScrollView()
        scroll.delaysContentTouches = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        let column = UIStackView(arrangedSubviews: [hint, summary, editor, payloadLabel, previewCaption, previewLabel])
        column.axis = .vertical
        column.spacing = 12
        column.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(column)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            column.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 12),
            column.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 16),
            column.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -16),
            column.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -12),
            editor.heightAnchor.constraint(greaterThanOrEqualToConstant: 140)
        ])
        refreshPreview(with: editor.makePostDocument())
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        editor.becomeFirstResponder()
    }

    @objc private func insertMention() {
        editor.insert(mention: ZHHTextMention(name: "小红", userID: "u-2002"))
    }

    @objc private func insertTopic() {
        editor.insert(topic: ZHHTextTopic(name: "城市漫步", topicID: "t-200"))
    }

    @objc private func publishTapped() {
        editor.resignFirstResponder()
        // 客户端：上报 text + 已选 entities。服务端会补手打片段的 id（此处用本地模拟）。
        let client = editor.makePostDocument()
        let echoed = EditorDemoViewController.simulateServerResolve(client)
        payloadLabel.text = echoed.jsonString() ?? "{}"
        refreshPreview(with: echoed)
        summary.text = "已发布（模拟）。查看页只使用服务端 entities 跳转。\n客户端已选 \(client.entities.count) 个；回显 \(echoed.entities.count) 个。"
    }

    private func presentPicker(for trigger: ZHHTextSpecialTrigger) {
        let sheet = UIAlertController(
            title: trigger == .mention ? "选人" : "选话题",
            message: "选中后 insert；取消则可继续手打",
            preferredStyle: .actionSheet
        )
        switch trigger {
        case .mention:
            sheet.addAction(UIAlertAction(title: "@小红", style: .default, handler: { [weak self] _ in
                self?.editor.insert(mention: ZHHTextMention(name: "小红", userID: "u-2002"))
            }))
            sheet.addAction(UIAlertAction(title: "@阿柚", style: .default, handler: { [weak self] _ in
                self?.editor.insert(mention: ZHHTextMention(name: "阿柚", userID: "u-3003"))
            }))
        case .topic:
            sheet.addAction(UIAlertAction(title: "#城市漫步", style: .default, handler: { [weak self] _ in
                self?.editor.insert(topic: ZHHTextTopic(name: "城市漫步", topicID: "t-200"))
            }))
            sheet.addAction(UIAlertAction(title: "#深夜食堂", style: .default, handler: { [weak self] _ in
                self?.editor.insert(topic: ZHHTextTopic(name: "深夜食堂", topicID: "t-300"))
            }))
        }
        sheet.addAction(UIAlertAction(title: "继续手打", style: .cancel))
        present(sheet, animated: true)
    }

    private func refreshPreview(with document: ZHHTextPostDocument) {
        let parser = ZHHTextParser(style: style)
        let result = parser.parse(document)
        previewLabel.apply(result)
    }

    /// 模拟服务端：保留客户端已选，并给仍无 id 的话题 / 提及补一个演示 id。
    private static func simulateServerResolve(_ document: ZHHTextPostDocument) -> ZHHTextPostDocument {
        var parser = ZHHTextParser()
        parser.options = [.topic, .mention]
        let parsed = parser.parse(document.text)
        var entities = document.entities
        let covered = entities.map(\.range)
        for link in parsed.links {
            let overlaps = covered.contains { NSIntersectionRange($0, link.range).length > 0 }
            if overlaps { continue }
            switch link.kind {
            case .mention(let mention) where mention.userID == nil:
                entities.append(ZHHTextEntity(
                    type: .mention,
                    id: "server-u-\(mention.name)",
                    name: mention.name,
                    range: link.range
                ))
            case .topic(let topic) where topic.topicID == nil:
                entities.append(ZHHTextEntity(
                    type: .topic,
                    id: "server-t-\(topic.name)",
                    name: topic.name,
                    range: link.range
                ))
            default:
                break
            }
        }
        entities.sort { $0.location < $1.location }
        return ZHHTextPostDocument(text: document.text, entities: entities)
    }

    private static func describe(_ result: ZHHTextParseResult) -> String {
        if result.links.isEmpty { return "还没有链接" }
        return result.links.map(describeLink).joined(separator: "\n")
    }

    private static func describeLink(_ link: ZHHTextLink) -> String {
        switch link.kind {
        case .mention(let mention):
            return "@\(mention.name) id=\(mention.userID ?? "-")"
        case .topic(let topic):
            return "#\(topic.name) id=\(topic.topicID ?? "-")"
        case .url(let url):
            return url.absoluteString
        case .phone(let number):
            return number
        case .custom(let custom):
            return custom.identifier
        }
    }
}
