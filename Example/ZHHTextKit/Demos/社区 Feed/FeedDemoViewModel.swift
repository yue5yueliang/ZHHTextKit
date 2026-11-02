//
//  FeedDemoViewModel.swift
//  ZHHTextKit
//
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import UIKit
import ZHHTextKit

struct FeedItem {
    let id: Int
    /// 模拟详情接口下发的正文 + entities。
    let document: ZHHTextPostDocument
}

/// 「社区 Feed」数据、展开态与文案。
final class FeedDemoViewModel {

    let title = "社区 Feed"
    let idleToast = "点击链接、全文或收起"
    let previewCaption = "单条：下发 entities 后的查看态（点击带 id）"

    let parser: ZHHTextParser
    let items: [FeedItem]
    private(set) var expandedIDs = Set<Int>()

    var listHeaderTitle: String {
        "列表复用 · \(items.count) 条，向下滑动"
    }

    init() {
        let built = Self.makeContent()
        parser = built.parser
        items = built.items
    }

    func isExpanded(id: Int) -> Bool {
        expandedIDs.contains(id)
    }

    func setExpanded(_ expanded: Bool, id: Int) {
        if expanded {
            expandedIDs.insert(id)
        } else {
            expandedIDs.remove(id)
        }
    }

    func expandToast(_ expanded: Bool) -> String {
        expanded ? "展开" : "收起"
    }

    func message(for link: ZHHTextLink) -> String {
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

    func previewDocument() -> ZHHTextPostDocument {
        let previewText = """
        周末去 #周末去哪儿 找 @小明 拿票，详情 https://example.com/event ，电话 13800138000。\
        这条预览故意写长，用来看三行之后的全文和收起，截断以后前面的链接也要能点。\
        再补一句 #城市漫步 ，避免刚好卡在行尾。
        """
        return Self.makeDocument(
            text: previewText,
            topicName: "周末去哪儿",
            topicID: "t-100",
            mentionName: "小明",
            userID: "u-1001",
            extraTopicName: "城市漫步",
            extraTopicID: "t-200"
        )
    }

    func layoutInput(for item: FeedItem, width: CGFloat, interfaceStyle: UIUserInterfaceStyle) -> ZHHTextLayoutInput {
        let parsed = parser.parse(item.document)
        return ZHHTextLayoutInput(
            attributedText: parsed.attributedText,
            links: parsed.links,
            width: width,
            numberOfLines: 3,
            isExpanded: isExpanded(id: item.id),
            style: parser.style,
            interfaceStyle: interfaceStyle
        )
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
