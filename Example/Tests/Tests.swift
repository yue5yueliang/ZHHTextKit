//
//  Tests.swift
//  ZHHTextKit
//
//  Created by 桃色三岁 on 2026/10/26.
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import UIKit
import XCTest
@testable import ZHHTextKit

/// 解析器单测：话题、提及、URL、电话与重叠取舍。
final class ZHHTextParserTests: XCTestCase {

    func testParsesTopicMentionURLAndPhone() {
        let parser = makeParser()
        let text = "看 #标题# 和 @张三 以及 https://example.com/a 电话 13800138000"
        let result = parser.parse(text)
        let names = result.links.map { $0.kind.typeName }
        XCTAssertEqual(names, ["topic", "mention", "url", "phone"])

        guard result.links.count == 4 else { return }
        if case .topic(let topic) = result.links[0].kind {
            XCTAssertEqual(topic.name, "标题")
            XCTAssertEqual(result.links[0].text, "#标题#")
        } else {
            XCTFail("话题类型不符")
        }
        if case .mention(let mention) = result.links[1].kind {
            XCTAssertEqual(mention.name, "张三")
            XCTAssertEqual(mention.userID, "u-1")
        } else {
            XCTFail("提及类型不符")
        }
        if case .url(let url) = result.links[2].kind {
            XCTAssertEqual(url.host, "example.com")
        } else {
            XCTFail("URL 类型不符")
        }
        XCTAssertEqual(result.links[2].range.location + result.links[2].range.length <= (text as NSString).length, true)
        let color = result.attributedText.attribute(
            .foregroundColor,
            at: result.links[0].range.location,
            effectiveRange: nil
        ) as? UIColor
        XCTAssertEqual(color, UIColor(red: 0.8, green: 0.3, blue: 0.1, alpha: 1))
    }

    func testExactTopicWinsAndPatternCanBeDisabled() {
        var parser = makeParser()
        parser.topicRule.names = ["标题"]
        parser.topicRule.detectsPairedHash = false
        parser.topicRule.detectsLeadingHash = false
        let result = parser.parse("#标题# 和 #其他#")
        XCTAssertEqual(result.links.count, 1)
        XCTAssertEqual(result.links[0].text, "#标题#")
    }

    func testLeadingHashTopicIsDetected() {
        var parser = makeParser()
        parser.options = [.topic]
        parser.topicRule.names = []
        parser.topicRule.bindings = []
        parser.topicRule.detectsPairedHash = false
        parser.topicRule.detectsLeadingHash = true
        let result = parser.parse("看 #周末去哪儿 和普通字")
        XCTAssertEqual(result.links.count, 1)
        XCTAssertEqual(result.links[0].text, "#周末去哪儿")
    }

    func testPairedTopicRespectsMaximumLength() {
        var parser = makeParser()
        parser.topicRule.names = []
        parser.topicRule.detectsPairedHash = true
        parser.topicRule.detectsLeadingHash = false
        parser.topicRule.maximumLength = 2
        let result = parser.parse("#ab# #abcd#")
        XCTAssertEqual(result.links.map { $0.text }, ["#ab#"])
    }

    func testBindingOverlapsURL() {
        var parser = makeParser()
        parser.options = [.url, .mention]
        parser.mentionRule.detectsPattern = false
        let text = "https://example.com/a"
        let range = (text as NSString).range(of: "example")
        parser.mentionRule.bindings = [ZHHTextMentionBinding(name: "站点", userID: "9", range: range)]
        let result = parser.parse(text)
        XCTAssertEqual(result.links.count, 1)
        XCTAssertEqual(result.links[0].kind.typeName, "mention")
        if case .mention(let mention) = result.links[0].kind {
            XCTAssertEqual(mention.userID, "9")
        } else {
            XCTFail("绑定应覆盖 URL")
        }
    }

    func testMentionStopsAtPunctuation() {
        var parser = makeParser()
        parser.options = [.mention]
        parser.mentionRule.bindings = []
        let result = parser.parse("你好@张三，下一句")
        XCTAssertEqual(result.links.count, 1)
        XCTAssertEqual(result.links[0].text, "@张三")
    }

    /// 阶段 0：overlaying 直接 API + 实体覆盖 URL 猜测。
    func testParseOverlayingKeepsEntityIDs() {
        let text = "找 @阿柚 聊 https://cafe.example.com"
        let mentionRange = (text as NSString).range(of: "@阿柚")
        let result = ZHHTextParser().parse(
            text,
            overlaying: [
                ZHHTextEntity(type: .mention, id: "u-3003", name: "阿柚", range: mentionRange)
            ]
        )
        let mention = result.links.first { link in
            if case .mention = link.kind { return true }
            return false
        }
        XCTAssertNotNil(mention)
        if case .mention(let value) = mention?.kind {
            XCTAssertEqual(value.userID, "u-3003")
            XCTAssertEqual(value.name, "阿柚")
        } else {
            XCTFail("overlay 提及应带 userID")
        }
        XCTAssertTrue(result.links.contains { link in
            if case .url = link.kind { return true }
            return false
        })
    }

    func testOverlayEntityWinsOverlappingURL() {
        var parser = ZHHTextParser()
        parser.options = [.url, .mention]
        parser.mentionRule.detectsPattern = false
        let text = "https://example.com/path"
        // 把 host 一段锁成提及绑定，应压过 URL 检测。
        let range = (text as NSString).range(of: "example.com")
        let result = parser.parse(
            text,
            overlaying: [
                ZHHTextEntity(type: .mention, id: "u-host", name: "站点", range: range)
            ]
        )
        XCTAssertEqual(result.links.count, 1)
        XCTAssertEqual(result.links[0].kind.typeName, "mention")
        if case .mention(let mention) = result.links[0].kind {
            XCTAssertEqual(mention.userID, "u-host")
        } else {
            XCTFail("实体绑定应覆盖重叠 URL")
        }
    }

    func testSpanResolverKeepsHigherPriorityAndLongerSpan() {
        let low = ZHHTextDetectionCandidate(
            priority: ZHHTextDetectionPriority.url,
            range: NSRange(location: 0, length: 5),
            kind: .url(URL(string: "https://a.co")!)
        )
        let high = ZHHTextDetectionCandidate(
            priority: ZHHTextDetectionPriority.binding,
            range: NSRange(location: 2, length: 4),
            kind: .mention(ZHHTextMention(name: "甲", userID: "1"))
        )
        let longerSamePriority = ZHHTextDetectionCandidate(
            priority: ZHHTextDetectionPriority.binding,
            range: NSRange(location: 10, length: 6),
            kind: .topic(ZHHTextTopic(name: "长话题"))
        )
        let shorterSamePriority = ZHHTextDetectionCandidate(
            priority: ZHHTextDetectionPriority.binding,
            range: NSRange(location: 11, length: 3),
            kind: .topic(ZHHTextTopic(name: "短"))
        )
        let resolved = ZHHTextSpanResolver.resolve([low, high, longerSamePriority, shorterSamePriority])
        XCTAssertEqual(resolved.count, 2)
        XCTAssertEqual(resolved[0].priority, ZHHTextDetectionPriority.binding)
        XCTAssertEqual(resolved[0].range, high.range)
        XCTAssertEqual(resolved[1].range, longerSamePriority.range)
    }

    private func makeParser() -> ZHHTextParser {
        var style = ZHHTextStyle()
        style.font = UIFont.systemFont(ofSize: 16)
        style.textColor = .black
        style.topicColor = UIColor(red: 0.8, green: 0.3, blue: 0.1, alpha: 1)
        style.mentionColor = UIColor(red: 0.1, green: 0.4, blue: 0.3, alpha: 1)
        style.linkColor = UIColor(red: 0.1, green: 0.3, blue: 0.8, alpha: 1)
        var parser = ZHHTextParser(style: style)
        parser.mentionRule.bindings = [ZHHTextMentionBinding(name: "张三", userID: "u-1")]
        return parser
    }
}

/// 排版与缓存单测：截断、命中、附件占位、预取。
final class ZHHTextLayoutTests: XCTestCase {

    func testCustomTruncationTokenReplacesTheDefaultWord() {
        let text = String(repeating: "正文", count: 40)
        var request = ZHHTextLayoutRequest(
            attributedText: NSAttributedString(string: text, attributes: bodyAttributes()),
            links: [],
            constrainedWidth: 120,
            numberOfLines: 2,
            isExpanded: false,
            style: bodyStyle(),
            collapsedLinkText: "全文",
            expandedLinkText: "收起",
            showsCollapsedToken: true,
            showsExpandedToken: true,
            truncationEllipsis: "…",
            truncationToken: NSAttributedString(string: "...more", attributes: bodyAttributes()),
            interfaceStyle: .light
        )
        let layout = ZHHTextLayoutEngine.layout(request)
        XCTAssertTrue(layout.isTruncated)
        XCTAssertTrue(layout.displayText.string.hasSuffix("...more"))
        XCTAssertFalse(layout.displayText.string.contains("全文"))
        let point = firstHit(in: layout) { action in
            if case .expand = action.kind { return true }
            return false
        }
        XCTAssertNotNil(point)

        request.truncationToken = nil
        request.isExpanded = true
        let expanded = ZHHTextLayoutEngine.layout(request)
        XCTAssertTrue(expanded.displayText.string.contains("收起"))
        XCTAssertFalse(expanded.displayText.string.contains("...more"))
    }

    func testImageAndLayerAttachmentsReserveWidth() {
        let font = UIFont.systemFont(ofSize: 16)
        let plain = NSAttributedString(string: "A", attributes: [.font: font])
        let image = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 20)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 20))
        }
        let withImage = NSMutableAttributedString(attributedString: plain)
        withImage.append(ZHHTextInlineAttachment.image(image, size: CGSize(width: 40, height: 20), alignedTo: font))
        let chip = CALayer()
        chip.bounds = CGRect(x: 0, y: 0, width: 30, height: 30)
        let withLayer = NSMutableAttributedString(attributedString: plain)
        withLayer.append(ZHHTextInlineAttachment.layer(chip, size: CGSize(width: 30, height: 30), alignedTo: font))

        let plainWidth = attachmentLayout(plain).size.width
        XCTAssertGreaterThan(attachmentLayout(withImage).size.width, plainWidth + 30)
        XCTAssertGreaterThan(attachmentLayout(withLayer).size.width, plainWidth + 20)
    }

    func testShortTextIsNotTruncated() {
        let layout = makeLayout("你好", lines: 2, expanded: false)
        XCTAssertFalse(layout.isTruncated)
        XCTAssertEqual(layout.displayText.string, "你好")
        XCTAssertLessThanOrEqual(layout.lineLayout.lines.count, 1)
    }

    func testCollapsedTextDropsTailAndKeepsToken() {
        let tail = "TAILMARKER"
        let text = String(repeating: "正文", count: 40) + tail
        let layout = makeLayout(text, lines: 2, expanded: false)
        XCTAssertTrue(layout.isTruncated)
        XCTAssertFalse(layout.displayText.string.contains(tail))
        XCTAssertTrue(layout.displayText.string.hasSuffix("全文"))
        XCTAssertLessThanOrEqual(layout.lineLayout.lines.count, 2)
    }

    func testDefaultCollapsedTokenColorsEllipsisAsBodyAndWordAsTruncation() {
        let text = String(repeating: "正文", count: 40)
        let layout = makeLayout(text, lines: 2, expanded: false)
        XCTAssertTrue(layout.isTruncated)
        XCTAssertTrue(layout.displayText.string.hasSuffix("…全文"))

        let display = layout.displayText
        let ellipsisRange = (display.string as NSString).range(of: "…", options: .backwards)
        let wordRange = (display.string as NSString).range(of: "全文", options: .backwards)
        XCTAssertNotEqual(ellipsisRange.location, NSNotFound)
        XCTAssertNotEqual(wordRange.location, NSNotFound)

        let ellipsisColor = display.attribute(.foregroundColor, at: ellipsisRange.location, effectiveRange: nil) as? UIColor
        let wordColor = display.attribute(.foregroundColor, at: wordRange.location, effectiveRange: nil) as? UIColor
        XCTAssertEqual(ellipsisColor, bodyStyle().textColor)
        XCTAssertEqual(wordColor, bodyStyle().truncationColor)

        guard let truncationRange = layout.truncationRange else {
            return XCTFail("折叠热区应覆盖整段默认 token")
        }
        XCTAssertEqual(truncationRange, NSUnionRange(ellipsisRange, wordRange))
    }

    func testExpandedTextKeepsTailAndCollapseToken() {
        let tail = "TAILMARKER"
        let text = String(repeating: "正文", count: 40) + tail
        let layout = makeLayout(text, lines: 2, expanded: true)
        XCTAssertTrue(layout.isTruncated)
        XCTAssertTrue(layout.displayText.string.contains(tail))
        XCTAssertTrue(layout.displayText.string.contains("收起"))
    }

    func testVisibleLinkStaysAndHiddenLinkIsRemoved() {
        let visible = "见 https://a.co " + String(repeating: "字", count: 80)
        let visibleLayout = makeLayout(visible, lines: 2, expanded: false)
        XCTAssertTrue(visibleLayout.displayText.string.contains("https://a.co"))

        let hidden = String(repeating: "字", count: 80) + " ENDMARK"
        let hiddenLayout = makeLayout(hidden, lines: 2, expanded: false)
        XCTAssertFalse(hiddenLayout.displayText.string.contains("ENDMARK"))

        let hiddenRange = (hidden as NSString).range(of: "ENDMARK")
        let link = ZHHTextLink(
            kind: .url(URL(string: "https://example.com/hidden")!),
            range: hiddenRange,
            text: "ENDMARK"
        )
        let linked = makeLayout(hidden, lines: 2, expanded: false, links: [link])
        XCTAssertTrue(linked.linksByID.isEmpty)
    }

    func testVisibleLinkCanBeHitAndTailLinkCannot() {
        let url = URL(string: "https://example.com/visible")!
        let text = "https://example.com/visible " + String(repeating: "字", count: 30)
        let range = (text as NSString).range(of: "https://example.com/visible")
        let link = ZHHTextLink(kind: .url(url), range: range, text: "https://example.com/visible")
        let layout = makeLayout(text, lines: 1, expanded: false, links: [link])
        let hit = firstHit(in: layout) { action in
            if case .link(let value) = action.kind, value.text == link.text { return true }
            return false
        }
        XCTAssertNotNil(hit)

        let tail = String(repeating: "字", count: 40) + " https://example.com/tail"
        let tailRange = (tail as NSString).range(of: "https://example.com/tail")
        let tailLink = ZHHTextLink(
            kind: .url(URL(string: "https://example.com/tail")!),
            range: tailRange,
            text: "https://example.com/tail"
        )
        let tailLayout = makeLayout(tail, lines: 1, expanded: false, links: [tailLink])
        let tailHit = firstHit(in: tailLayout) { action in
            if case .link = action.kind { return true }
            return false
        }
        XCTAssertNil(tailHit)
    }

    func testExpandTokenIsHittable() {
        let text = String(repeating: "正文", count: 40)
        let layout = makeLayout(text, lines: 2, expanded: false)
        let point = firstHit(in: layout) { action in
            if case .expand = action.kind { return true }
            return false
        }
        XCTAssertNotNil(point)
    }

    func testExpandTokenHitAllowsPadding() {
        let text = String(repeating: "正文", count: 40)
        let layout = makeLayout(text, lines: 2, expanded: false)
        guard let exact = firstHit(in: layout, where: { action in
            if case .expand = action.kind { return true }
            return false
        }) else {
            XCTFail("没有找到全文热区")
            return
        }
        let padded = CGPoint(x: exact.x + 8, y: exact.y + 6)
        let action = layout.lineLayout.hit(
            at: padded,
            displayText: layout.displayText,
            linksByID: layout.linksByID
        )
        guard case .expand = action?.kind else {
            XCTFail("外扩后的点也应命中全文")
            return
        }
    }

    func testCacheDoesNotConfuseTexts() {
        let cache = ZHHTextMemoryLayoutCache()
        let first = makeLayout("第一条 https://example.com/a " + String(repeating: "甲", count: 30), lines: 2, expanded: false)
        let second = makeLayout("第二条 https://example.com/b " + String(repeating: "乙", count: 30), lines: 2, expanded: false)
        cache.store(first, for: first.key)
        cache.store(second, for: second.key)
        XCTAssertEqual(cache.layout(for: first.key)?.displayText.string, first.displayText.string)
        XCTAssertEqual(cache.layout(for: second.key)?.displayText.string, second.displayText.string)
        XCTAssertNotEqual(first.displayText.string, second.displayText.string)
    }

    func testPrefetchFillsCache() {
        let cache = ZHHTextMemoryLayoutCache()
        let text = String(repeating: "预取", count: 30)
        let input = ZHHTextLayoutInput(
            attributedText: NSAttributedString(string: text, attributes: bodyAttributes()),
            links: [],
            width: 120,
            numberOfLines: 2,
            isExpanded: false,
            style: bodyStyle(),
            interfaceStyle: .light
        )
        let expected = ZHHTextLayoutEngine.layout(input.request)
        cache.removeAll()
        let done = expectation(description: "prefetch")
        ZHHTextLayoutPrefetcher.prefetch([input], cache: cache) {
            XCTAssertEqual(cache.layout(for: expected.key)?.displayText.string, expected.displayText.string)
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
    }

    private func makeLayout(
        _ text: String,
        lines: Int,
        expanded: Bool,
        links: [ZHHTextLink] = []
    ) -> ZHHTextLayout {
        let request = ZHHTextLayoutRequest(
            attributedText: NSAttributedString(string: text, attributes: bodyAttributes()),
            links: links,
            constrainedWidth: 120,
            numberOfLines: lines,
            isExpanded: expanded,
            style: bodyStyle(),
            collapsedLinkText: "全文",
            expandedLinkText: "收起",
            showsCollapsedToken: true,
            showsExpandedToken: true,
            truncationEllipsis: "…",
            truncationToken: nil,
            interfaceStyle: .light
        )
        return ZHHTextLayoutEngine.layout(request)
    }

    private func attachmentLayout(_ text: NSAttributedString) -> ZHHTextLayout {
        let request = ZHHTextLayoutRequest(
            attributedText: text,
            links: [],
            constrainedWidth: 200,
            numberOfLines: 0,
            isExpanded: false,
            style: bodyStyle(),
            collapsedLinkText: "全文",
            expandedLinkText: "收起",
            showsCollapsedToken: true,
            showsExpandedToken: true,
            truncationEllipsis: "…",
            truncationToken: nil,
            interfaceStyle: .light
        )
        return ZHHTextLayoutEngine.layout(request)
    }

    private func bodyStyle() -> ZHHTextStyle {
        var style = ZHHTextStyle()
        style.font = UIFont.systemFont(ofSize: 16)
        style.textColor = .black
        style.truncationColor = .blue
        style.lineSpacing = 2
        return style
    }

    private func bodyAttributes() -> [NSAttributedString.Key: Any] {
        bodyStyle().attributes(for: .body)
    }

    private func firstHit(
        in layout: ZHHTextLayout,
        where predicate: (ZHHTextHitAction) -> Bool
    ) -> CGPoint? {
        let height = max(layout.size.height, 1)
        var y: CGFloat = 0
        while y <= height {
            var x: CGFloat = 0
            while x <= 120 {
                let point = CGPoint(x: x, y: y)
                if let action = layout.lineLayout.hit(
                    at: point,
                    displayText: layout.displayText,
                    linksByID: layout.linksByID
                ), predicate(action) {
                    return point
                }
                x += 3
            }
            y += 2
        }
        return nil
    }
}

/// Label 交互单测：展开收起、复用、绘制。
final class ZHHTextLabelTests: XCTestCase {

    func testTapExpandThenCollapse() {
        let label = makeLabel(width: 120)
        label.numberOfLines = 2
        label.text = String(repeating: "正文", count: 40) + "TAILMARKER"
        let collapsed = label.sizeThatFits(CGSize(width: 120, height: 1000))
        label.frame = CGRect(x: 0, y: 0, width: 120, height: collapsed.height)
        XCTAssertTrue(label.isTruncated)

        let layout = currentLayout(label, width: 120)
        guard let point = expandPoint(in: layout) else {
            XCTFail("没有找到全文热区")
            return
        }
        var states: [Bool] = []
        label.onTapExpand = { states.append($0) }
        label.performInteraction(at: point)
        XCTAssertEqual(states, [true])
        XCTAssertTrue(label.isExpanded)
        XCTAssertTrue(label.text?.contains("TAILMARKER") == true)

        let expandedLayout = currentLayout(label, width: 120)
        XCTAssertTrue(expandedLayout.displayText.string.contains("TAILMARKER"))
        XCTAssertTrue(expandedLayout.displayText.string.contains("收起"))
    }

    /// 有截断时，展开 / 收起热区的 hitTest 应落到 UIControl，且能切换 isExpanded。
    func testExpandHitControlIsUIControlAndTogglesExpanded() {
        let label = makeLabel(width: 120)
        label.numberOfLines = 2
        label.text = String(repeating: "正文", count: 40) + "TAILMARKER"
        let collapsed = label.sizeThatFits(CGSize(width: 120, height: 1000))
        label.frame = CGRect(x: 0, y: 0, width: 120, height: collapsed.height)
        label.layoutIfNeeded()

        let layout = currentLayout(label, width: 120)
        guard let point = expandPoint(in: layout) else {
            return XCTFail("没有找到全文热区")
        }
        // 宿主可据此判断 touch.view 是 UIControl，从而跳过单击暂停。
        let hit = label.hitTest(point, with: nil)
        XCTAssertTrue(hit is UIControl)
        XCTAssertFalse(hit === label)

        var states: [Bool] = []
        label.onTapExpand = { states.append($0) }
        (hit as? UIControl)?.sendActions(for: .touchUpInside)
        XCTAssertEqual(states, [true])
        XCTAssertTrue(label.isExpanded)

        // 展开后正文变高，「收起」可能落在原 frame 之外，需同步拉高再测。
        let expandedSize = label.sizeThatFits(CGSize(width: 120, height: 1000))
        label.frame = CGRect(x: 0, y: 0, width: 120, height: expandedSize.height)
        label.layoutIfNeeded()
        let expandedLayout = currentLayout(label, width: 120)
        guard let collapsePoint = expandPoint(in: expandedLayout) else {
            return XCTFail("没有找到收起热区")
        }
        let collapseHit = label.hitTest(collapsePoint, with: nil)
        XCTAssertTrue(collapseHit is UIControl)
        (collapseHit as? UIControl)?.sendActions(for: .touchUpInside)
        XCTAssertEqual(states, [true, false])
        XCTAssertFalse(label.isExpanded)
    }

    /// 未截断时不应创建展开热区 UIControl，避免挡底层手势。
    func testExpandHitControlAbsentWhenNotTruncated() {
        let label = makeLabel(width: 180)
        label.numberOfLines = 2
        label.text = "短文本"
        let size = label.sizeThatFits(CGSize(width: 180, height: 1000))
        label.frame = CGRect(x: 0, y: 0, width: 180, height: size.height)
        label.layoutIfNeeded()
        XCTAssertFalse(label.isTruncated)

        var y: CGFloat = 0
        while y <= label.bounds.height {
            var x: CGFloat = 0
            while x <= label.bounds.width {
                let hit = label.hitTest(CGPoint(x: x, y: y), with: nil)
                XCTAssertFalse(hit is UIControl, "无截断时不应出现展开热区 UIControl")
                x += 4
            }
            y += 3
        }
    }

    /// 关闭折叠文案且无可点 token 时，即使发生截断也不应挂热区控件。
    func testExpandHitControlAbsentWhenShowsCollapsedTokenDisabled() {
        let label = makeLabel(width: 120)
        label.numberOfLines = 2
        label.showsCollapsedToken = false
        label.collapsedLinkText = ""
        label.text = String(repeating: "正文", count: 40)
        let size = label.sizeThatFits(CGSize(width: 120, height: 1000))
        label.frame = CGRect(x: 0, y: 0, width: 120, height: size.height)
        label.layoutIfNeeded()
        XCTAssertTrue(label.isTruncated)

        var y: CGFloat = 0
        while y <= label.bounds.height {
            var x: CGFloat = 0
            while x <= label.bounds.width {
                XCTAssertFalse(
                    label.hitTest(CGPoint(x: x, y: y), with: nil) is UIControl,
                    "无可点展开文案时不应创建热区 UIControl"
                )
                x += 4
            }
            y += 3
        }
    }

    /// 自定义 truncationToken 整段仍应由 UIControl 热区承接，并可展开。
    func testCustomTruncationTokenUsesExpandHitControl() {
        let label = makeLabel(width: 120)
        label.numberOfLines = 2
        label.truncationToken = NSAttributedString(
            string: "...more",
            attributes: bodyAttributes()
        )
        label.text = String(repeating: "正文", count: 40)
        let size = label.sizeThatFits(CGSize(width: 120, height: 1000))
        label.frame = CGRect(x: 0, y: 0, width: 120, height: size.height)
        label.layoutIfNeeded()

        let layout = currentLayout(label, width: 120)
        guard let point = expandPoint(in: layout) else {
            return XCTFail("自定义 truncationToken 应可点展开")
        }
        let hit = label.hitTest(point, with: nil)
        XCTAssertTrue(hit is UIControl)
        var expanded = false
        label.onTapExpand = { expanded = $0 }
        (hit as? UIControl)?.sendActions(for: .touchUpInside)
        XCTAssertTrue(expanded)
        XCTAssertTrue(label.isExpanded)
    }

    func testReusedLabelDoesNotKeepPreviousLink() {
        let label = makeLabel(width: 220)
        label.numberOfLines = 1
        label.text = "https://example.com/aaa " + String(repeating: "甲", count: 20)
        label.parser = nil
        let linkRange = ("https://example.com/aaa " as NSString).range(of: "https://example.com/aaa")
        // 上面的 text 赋值没有 parser，链接为空。改为 apply。
        let text = "https://example.com/aaa"
        let range = (text as NSString).range(of: text)
        label.apply(ZHHTextParseResult(
            attributedText: NSAttributedString(string: text, attributes: bodyAttributes()),
            links: [ZHHTextLink(kind: .url(URL(string: text)!), range: range, text: text)]
        ))
        label.frame = CGRect(x: 0, y: 0, width: 220, height: 40)
        _ = linkRange
        guard let point = pointOfLink(label) else {
            XCTFail("没有点中第一段链接")
            return
        }
        let first = label.link(at: point)
        XCTAssertEqual(first?.text, text)

        label.text = "第二段没有任何链接"
        let after = label.link(at: point)
        XCTAssertNil(after)
    }

    func testDrawProducesInk() {
        let label = makeLabel(width: 180)
        label.frame = CGRect(x: 0, y: 0, width: 180, height: 40)
        label.text = "测试"
        let renderer = UIGraphicsImageRenderer(size: label.bounds.size)
        let image = renderer.image { _ in
            UIColor.white.setFill()
            UIRectFill(label.bounds)
            label.draw(label.bounds)
        }
        XCTAssertTrue(imageContainsInk(image))
    }

    func testBodyTapDisabledByDefault() {
        let label = makeLabel(width: 180)
        label.text = "我已阅读并同意协议"
        let size = label.sizeThatFits(CGSize(width: 180, height: 1000))
        label.frame = CGRect(x: 0, y: 0, width: 180, height: size.height)

        var bodyTaps = 0
        label.onTapBody = { bodyTaps += 1 }
        guard let point = bodyPoint(label) else {
            return XCTFail("没有找到正文字形")
        }
        label.performInteraction(at: point)
        XCTAssertEqual(bodyTaps, 0)
        XCTAssertNil(label.hitTest(point, with: nil))
    }

    func testBodyTapFiresWhenEnabledAndSkipsLinks() {
        let label = makeLabel(width: 220)
        label.allowsBodyTap = true
        let plain = "同意 "
        let linkText = "《用户协议》"
        let full = plain + linkText
        let linkRange = (full as NSString).range(of: linkText)
        label.apply(ZHHTextParseResult(
            attributedText: NSAttributedString(string: full, attributes: bodyAttributes()),
            links: [
                ZHHTextLink(
                    kind: .custom(ZHHTextCustomLink(identifier: "agreement")),
                    range: linkRange,
                    text: linkText
                )
            ]
        ))
        let size = label.sizeThatFits(CGSize(width: 220, height: 1000))
        label.frame = CGRect(x: 0, y: 0, width: 220, height: size.height)

        var bodyTaps = 0
        var linkTaps = 0
        label.onTapBody = { bodyTaps += 1 }
        label.onTapLink = { _ in linkTaps += 1 }

        guard let bodyPoint = bodyPoint(label) else {
            return XCTFail("没有找到普通正文")
        }
        label.performInteraction(at: bodyPoint)
        XCTAssertEqual(bodyTaps, 1)
        XCTAssertEqual(linkTaps, 0)

        guard let linkPoint = pointOfLink(label) else {
            return XCTFail("没有找到协议链接")
        }
        label.performInteraction(at: linkPoint)
        XCTAssertEqual(bodyTaps, 1)
        XCTAssertEqual(linkTaps, 1)
    }

    func testLongPressDisabledByDefault() {
        let label = makeLabel(width: 180)
        label.text = "可复制的正文"
        let size = label.sizeThatFits(CGSize(width: 180, height: 1000))
        label.frame = CGRect(x: 0, y: 0, width: 180, height: size.height)

        var pressed = 0
        label.onLongPress = { _ in pressed += 1 }
        label.performLongPress(at: CGPoint(x: 20, y: 10))
        XCTAssertEqual(pressed, 0)
    }

    func testLongPressDeliversContextWithoutCopying() {
        let label = makeLabel(width: 220)
        label.allowsLongPressCopy = true
        let plain = "同意 "
        let linkText = "《用户协议》"
        let full = plain + linkText
        let linkRange = (full as NSString).range(of: linkText)
        label.apply(ZHHTextParseResult(
            attributedText: NSAttributedString(string: full, attributes: bodyAttributes()),
            links: [
                ZHHTextLink(
                    kind: .custom(ZHHTextCustomLink(identifier: "agreement")),
                    range: linkRange,
                    text: linkText
                )
            ]
        ))
        let size = label.sizeThatFits(CGSize(width: 220, height: 1000))
        label.frame = CGRect(x: 0, y: 0, width: 220, height: size.height)

        let beforePasteboard = UIPasteboard.general.string
        var info: ZHHTextLongPressInfo?
        label.onLongPress = { info = $0 }

        guard let bodyPoint = bodyPoint(label) else {
            return XCTFail("没有找到普通正文")
        }
        label.performLongPress(at: bodyPoint)
        XCTAssertEqual(info?.kind, .body)
        XCTAssertEqual(info?.plainText, full)
        XCTAssertEqual(info?.attributedText.string, full)
        XCTAssertNotNil(info?.displayRange)
        XCTAssertEqual(UIPasteboard.general.string, beforePasteboard)

        guard let linkPoint = pointOfLink(label) else {
            return XCTFail("没有找到协议链接")
        }
        label.performLongPress(at: linkPoint)
        guard case .link(let link) = info?.kind else {
            return XCTFail("长按链接应回传 link kind")
        }
        XCTAssertEqual(link.text, linkText)
    }

    func testBodyTapAcceptsPaddedHotZone() {
        let label = makeLabel(width: 220)
        label.allowsBodyTap = true
        label.text = "我已阅读并同意"
        let size = label.sizeThatFits(CGSize(width: 220, height: 1000))
        label.frame = CGRect(x: 0, y: 0, width: 220, height: size.height)

        guard let exact = bodyPoint(label) else {
            return XCTFail("没有找到正文字形")
        }
        // 略偏到字形下方，仍应落在外扩热区内。
        let padded = CGPoint(x: exact.x, y: exact.y + 8)
        var bodyTaps = 0
        label.onTapBody = { bodyTaps += 1 }
        label.performInteraction(at: padded)
        XCTAssertEqual(bodyTaps, 1)
        XCTAssertNotNil(label.hitTest(padded, with: nil))
    }

    func testBodyTapBetweenAdjacentLinksIsNotStolenByLinkPadding() {
        let label = makeLabel(width: 320)
        label.allowsBodyTap = true
        let left = "《用户协议》"
        let middle = "和"
        let right = "《隐私政策》"
        let full = left + middle + right
        let leftRange = (full as NSString).range(of: left)
        let rightRange = (full as NSString).range(of: right)
        let middleRange = (full as NSString).range(of: middle)
        label.apply(ZHHTextParseResult(
            attributedText: NSAttributedString(string: full, attributes: bodyAttributes()),
            links: [
                ZHHTextLink(
                    kind: .custom(ZHHTextCustomLink(identifier: "user-agreement")),
                    range: leftRange,
                    text: left
                ),
                ZHHTextLink(
                    kind: .custom(ZHHTextCustomLink(identifier: "privacy")),
                    range: rightRange,
                    text: right
                )
            ]
        ))
        let size = label.sizeThatFits(CGSize(width: 320, height: 1000))
        label.frame = CGRect(x: 0, y: 0, width: 320, height: size.height)

        let layout = currentLayout(label, width: 320)
        guard let middleRect = layout.lineLayout.rects(for: middleRange).first else {
            return XCTFail("找不到「和」的字形框")
        }
        let point = CGPoint(x: middleRect.midX, y: middleRect.midY)
        let action = layout.lineLayout.hit(
            at: point,
            displayText: layout.displayText,
            linksByID: layout.linksByID,
            allowsBodyTap: true
        )
        guard case .body = action?.kind else {
            return XCTFail("点「和」应命中正文，不能被两侧链接热区抢走")
        }

        var bodyTaps = 0
        var linkTaps = 0
        label.onTapBody = { bodyTaps += 1 }
        label.onTapLink = { _ in linkTaps += 1 }
        label.performInteraction(at: point)
        XCTAssertEqual(bodyTaps, 1)
        XCTAssertEqual(linkTaps, 0)
    }

    func testBodyTapHighlightCoversContiguousPlainRun() {
        let label = makeLabel(width: 260)
        label.allowsBodyTap = true
        let plain = "我已阅读并同意"
        let linkText = "《用户协议》"
        let full = plain + linkText
        let linkRange = (full as NSString).range(of: linkText)
        label.apply(ZHHTextParseResult(
            attributedText: NSAttributedString(string: full, attributes: bodyAttributes()),
            links: [
                ZHHTextLink(
                    kind: .custom(ZHHTextCustomLink(identifier: "agreement")),
                    range: linkRange,
                    text: linkText
                )
            ]
        ))
        let size = label.sizeThatFits(CGSize(width: 260, height: 1000))
        label.frame = CGRect(x: 0, y: 0, width: 260, height: size.height)

        guard let point = bodyPoint(label) else {
            return XCTFail("没有找到普通正文")
        }
        let width = label.bounds.width
        let layout = currentLayout(label, width: width)
        let action = layout.lineLayout.hit(
            at: point,
            displayText: layout.displayText,
            linksByID: layout.linksByID,
            allowsBodyTap: true
        )
        guard case .body = action?.kind else {
            return XCTFail("应命中正文")
        }
        XCTAssertEqual(action?.displayRange, NSRange(location: 0, length: (plain as NSString).length))
    }

    private func makeLabel(width: CGFloat) -> ZHHTextLabel {
        let label = ZHHTextLabel(frame: CGRect(x: 0, y: 0, width: width, height: 80))
        var style = ZHHTextStyle()
        style.font = UIFont.systemFont(ofSize: 16)
        style.textColor = .black
        style.truncationColor = .blue
        label.style = style
        label.preferredMaxLayoutWidth = width
        return label
    }

    private func bodyAttributes() -> [NSAttributedString.Key: Any] {
        var style = ZHHTextStyle()
        style.font = UIFont.systemFont(ofSize: 16)
        style.textColor = .black
        return style.attributes(for: .body)
    }

    private func currentLayout(_ label: ZHHTextLabel, width: CGFloat) -> ZHHTextLayout {
        let text = label.attributedText ?? NSAttributedString()
        let request = ZHHTextLayoutRequest(
            attributedText: text,
            links: label.links,
            constrainedWidth: width,
            numberOfLines: label.numberOfLines,
            isExpanded: label.isExpanded,
            style: label.style,
            collapsedLinkText: label.collapsedLinkText,
            expandedLinkText: label.expandedLinkText,
            showsCollapsedToken: label.showsCollapsedToken,
            showsExpandedToken: label.showsExpandedToken,
            truncationEllipsis: label.truncationEllipsis,
            truncationToken: label.truncationToken,
            interfaceStyle: .light
        )
        return ZHHTextLayoutEngine.layout(request)
    }

    private func expandPoint(in layout: ZHHTextLayout) -> CGPoint? {
        var y: CGFloat = 0
        while y <= layout.size.height {
            var x: CGFloat = 0
            while x <= 120 {
                let point = CGPoint(x: x, y: y)
                if let action = layout.lineLayout.hit(
                    at: point,
                    displayText: layout.displayText,
                    linksByID: layout.linksByID
                ), case .expand = action.kind {
                    return point
                }
                x += 2
            }
            y += 2
        }
        return nil
    }

    private func pointOfLink(_ label: ZHHTextLabel) -> CGPoint? {
        var y: CGFloat = 0
        while y <= label.bounds.height {
            var x: CGFloat = 0
            while x <= label.bounds.width {
                if label.link(at: CGPoint(x: x, y: y)) != nil {
                    return CGPoint(x: x, y: y)
                }
                x += 4
            }
            y += 3
        }
        return nil
    }

    /// 找一个命中普通正文、且不是链接的点。临时打开 `allowsBodyTap` 做探测。
    private func bodyPoint(_ label: ZHHTextLabel) -> CGPoint? {
        let previous = label.allowsBodyTap
        label.allowsBodyTap = true
        defer { label.allowsBodyTap = previous }
        var y: CGFloat = 0
        while y <= label.bounds.height {
            var x: CGFloat = 0
            while x <= label.bounds.width {
                let point = CGPoint(x: x, y: y)
                if label.link(at: point) == nil,
                   let action = label.hitTest(point, with: nil),
                   action === label {
                    return point
                }
                x += 3
            }
            y += 2
        }
        return nil
    }

    private func imageContainsInk(_ image: UIImage) -> Bool {
        guard let cgImage = image.cgImage else { return false }
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return false }
        let bytesPerRow = width * 4
        var bytes = [UInt8](repeating: 0, count: height * bytesPerRow)
        guard let context = CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return false }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        for index in stride(from: 0, to: bytes.count, by: 4) {
            let red = bytes[index]
            let green = bytes[index + 1]
            let blue = bytes[index + 2]
            if red < 250 || green < 250 || blue < 250 {
                return true
            }
        }
        return false
    }
}

/// 输入框单测：整段删除规则与插入提及 / 话题。
final class ZHHTextEditorTests: XCTestCase {

    func testBackspaceAtMentionEndDeletesTheWholeSpan() {
        let mention = ZHHTextLink(
            kind: .mention(ZHHTextMention(name: "小明", userID: "u-1")),
            range: NSRange(location: 2, length: 3),
            text: "@小明"
        )
        let caret = NSRange(location: 5, length: 0)
        XCTAssertEqual(ZHHTextEditing.deletionRange(for: caret, links: [mention]), mention.range)
        XCTAssertNil(ZHHTextEditing.deletionRange(for: mention.range, links: [mention]))

        let partial = NSRange(location: 3, length: 1)
        XCTAssertEqual(ZHHTextEditing.deletionRange(for: partial, links: [mention]), mention.range)

        let topic = ZHHTextLink(
            kind: .topic(ZHHTextTopic(name: "周末去哪儿", topicID: "t-1")),
            range: NSRange(location: 0, length: 6),
            text: "#周末去哪儿"
        )
        XCTAssertFalse(ZHHTextEditing.isAtomic(topic))
        XCTAssertNil(ZHHTextEditing.deletionRange(for: NSRange(location: 6, length: 0), links: [topic]))

        let url = ZHHTextLink(
            kind: .url(URL(string: "https://a.co")!),
            range: NSRange(location: 0, length: 12),
            text: "https://a.co"
        )
        XCTAssertNil(ZHHTextEditing.deletionRange(for: NSRange(location: 12, length: 0), links: [url]))
    }

    func testEditorInsertKeepsMentionAndTopicIdentity() {
        let editor = ZHHTextView(frame: CGRect(x: 0, y: 0, width: 320, height: 180))
        editor.insert(mention: ZHHTextMention(name: "小明", userID: "u-1001"))
        editor.insert(topic: ZHHTextTopic(name: "周末去哪儿", topicID: "t-88"))
        XCTAssertEqual(editor.text, "@小明 #周末去哪儿 ")

        let mention = editor.editResult.links.first { link in
            if case .mention(let value) = link.kind {
                return value.userID == "u-1001"
            }
            return false
        }
        let topic = editor.editResult.links.first { link in
            if case .topic(let value) = link.kind {
                return value.topicID == "t-88"
            }
            return false
        }
        XCTAssertNotNil(mention)
        XCTAssertNotNil(topic)
        XCTAssertEqual(editor.boundLinks.count, 2)
    }

    func testEditorKeepsDistinctIDsForSameMentionName() {
        let editor = ZHHTextView(frame: CGRect(x: 0, y: 0, width: 320, height: 180))
        editor.insert(mention: ZHHTextMention(name: "小明", userID: "u-1"))
        editor.insert(mention: ZHHTextMention(name: "小明", userID: "u-2"))
        XCTAssertEqual(editor.text, "@小明 @小明 ")

        let ids = editor.boundLinks.compactMap { link -> String? in
            if case .mention(let mention) = link.kind {
                return mention.userID
            }
            return nil
        }
        XCTAssertEqual(ids, ["u-1", "u-2"])
    }

    func testEditorBackspaceRemovesWholeMentionOnce() {
        let editor = ZHHTextView(frame: CGRect(x: 0, y: 0, width: 320, height: 180))
        editor.insert(mention: ZHHTextMention(name: "小明", userID: "u-1001"))
        XCTAssertEqual(editor.text, "@小明 ")
        editor.deleteBackward()
        XCTAssertEqual(editor.text, "@小明")
        editor.deleteBackward()
        XCTAssertEqual(editor.text, "")
        XCTAssertTrue(editor.boundLinks.isEmpty)
    }

    func testEditorInsertTopicAfterDeletedSeparatorKeepsBothTopics() {
        let editor = ZHHTextView(frame: CGRect(x: 0, y: 0, width: 320, height: 180))
        editor.insert(topic: ZHHTextTopic(name: "周末去哪儿", topicID: "t-100"))
        XCTAssertEqual(editor.text, "#周末去哪儿 ")
        editor.deleteBackward()
        XCTAssertEqual(editor.text, "#周末去哪儿")

        editor.insert(topic: ZHHTextTopic(name: "城市漫步", topicID: "t-200"))
        XCTAssertEqual(editor.text, "#周末去哪儿 #城市漫步 ")

        let ids = editor.boundLinks.compactMap { link -> String? in
            if case .topic(let topic) = link.kind {
                return topic.topicID
            }
            return nil
        }
        XCTAssertEqual(ids, ["t-100", "t-200"])
        XCTAssertEqual(editor.editResult.links.filter { ZHHTextEditing.isAtomic($0) }.count, 0)
    }

    func testEditorInsertsSpaceBetweenAdjacentTopics() {
        let editor = ZHHTextView(frame: CGRect(x: 0, y: 0, width: 320, height: 180))
        editor.insert(topic: ZHHTextTopic(name: "周末去哪儿", topicID: "t-100"))
        editor.deleteBackward()
        editor.insert(topic: ZHHTextTopic(name: "城市漫步", topicID: "t-200"))
        XCTAssertEqual(editor.text, "#周末去哪儿 #城市漫步 ")
    }

    func testTypingHashAfterURLInsertsLeadingSpace() {
        let editor = ZHHTextView(frame: CGRect(x: 0, y: 0, width: 320, height: 180))
        editor.text = "详情 https://example.com"
        let end = (editor.text as NSString?)?.length ?? 0
        editor.selectedRange = NSRange(location: end, length: 0)
        editor.insertText("#")
        editor.insertText("不敢接你")
        XCTAssertEqual(editor.text, "详情 https://example.com #不敢接你")
    }

    func testTypingSecondHashStartsNewTopicWithSpace() {
        let editor = ZHHTextView(frame: CGRect(x: 0, y: 0, width: 320, height: 180))
        editor.insertText("#")
        editor.insertText("不敢接你")
        editor.insertText("#")
        XCTAssertEqual(editor.text, "#不敢接你 #")
    }

    func testTypingAtAfterURLInsertsLeadingSpace() {
        let editor = ZHHTextView(frame: CGRect(x: 0, y: 0, width: 320, height: 180))
        editor.text = "https://example.com"
        let end = (editor.text as NSString?)?.length ?? 0
        editor.selectedRange = NSRange(location: end, length: 0)
        editor.insertText("@")
        XCTAssertEqual(editor.text, "https://example.com @")
    }

    func testEditingTopicTextDropsLocalTopicID() {
        let editor = ZHHTextView(frame: CGRect(x: 0, y: 0, width: 320, height: 180))
        editor.insert(topic: ZHHTextTopic(name: "周末去哪儿", topicID: "t-100"))
        XCTAssertEqual(editor.boundLinks.count, 1)
        // 删掉尾随空格后再删最后一个字 → 文案对不上 raw，拆绑。
        editor.deleteBackward()
        editor.deleteBackward()
        XCTAssertTrue(editor.boundLinks.isEmpty)
        XCTAssertEqual(editor.text, "#周末去哪")
    }

    func testMakePostDocumentExportsSelectedEntitiesOnly() {
        let editor = ZHHTextView(frame: CGRect(x: 0, y: 0, width: 320, height: 180))
        editor.insert(mention: ZHHTextMention(name: "小明", userID: "u-1"))
        editor.insert(topic: ZHHTextTopic(name: "城市漫步", topicID: "t-2"))
        editor.insertText("#手打话题")
        let document = editor.makePostDocument()
        XCTAssertTrue(document.text.contains("#手打话题"))
        XCTAssertEqual(document.entities.count, 2)
        XCTAssertEqual(document.entities.map(\.id), ["u-1", "t-2"])
        XCTAssertNotNil(document.jsonString())
    }

    func testParserOverlaysServerEntitiesForDisplay() {
        let text = "约 @小明 看 #城市漫步"
        let document = ZHHTextPostDocument(
            text: text,
            entities: [
                ZHHTextEntity(type: .mention, id: "u-1", name: "小明", range: (text as NSString).range(of: "@小明")),
                ZHHTextEntity(type: .topic, id: "t-2", name: "城市漫步", range: (text as NSString).range(of: "#城市漫步"))
            ]
        )
        let result = ZHHTextParser().parse(document)
        XCTAssertEqual(result.links.count, 2)
        if case .mention(let mention) = result.links[0].kind {
            XCTAssertEqual(mention.userID, "u-1")
        } else {
            XCTFail("应为提及")
        }
        if case .topic(let topic) = result.links[1].kind {
            XCTAssertEqual(topic.topicID, "t-2")
        } else {
            XCTFail("应为话题")
        }
    }
}

/// 阶段 0：LineLayout 排版 / 边框外溢 / 命中回归。
final class ZHHTextLineLayoutRegressionTests: XCTestCase {

    func testMakeRejectsEmptyOrInvalidWidth() {
        let text = NSAttributedString(string: "你好", attributes: [.font: UIFont.systemFont(ofSize: 16)])
        let empty = ZHHTextLineLayout.make(attributedText: NSAttributedString(), width: 100)
        XCTAssertTrue(empty.lines.isEmpty)
        XCTAssertEqual(empty.constrainedWidth, 100)

        let bad = ZHHTextLineLayout.make(attributedText: text, width: 0)
        XCTAssertTrue(bad.lines.isEmpty)

        let nan = ZHHTextLineLayout.make(attributedText: text, width: .nan)
        XCTAssertTrue(nan.lines.isEmpty)
    }

    func testMakeStoresOuterConstrainedWidth() {
        let text = bordered("胶囊标签")
        let width: CGFloat = 200
        let layout = ZHHTextLineLayout.make(attributedText: text, width: width)
        XCTAssertFalse(layout.lines.isEmpty)
        // 必须存外宽：按下高亮重排依赖它，不能退化成内容紧包围宽。
        XCTAssertEqual(layout.constrainedWidth, width)
        XCTAssertLessThanOrEqual(layout.size.width, width)
    }

    func testBorderOverflowMakesLayoutTallerOrWiderThanPlain() {
        let font = UIFont.systemFont(ofSize: 16)
        let plain = NSAttributedString(string: "胶囊", attributes: [.font: font])
        let withBorder = bordered("胶囊", outsets: UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10))
        let plainLayout = ZHHTextLineLayout.make(attributedText: plain, width: 180)
        let borderLayout = ZHHTextLineLayout.make(attributedText: withBorder, width: 180)
        XCTAssertGreaterThan(borderLayout.size.height, plainLayout.size.height - 0.5)
        // 内容被内缩排版后，总宽仍可吃满外宽附近（含 pad）。
        XCTAssertGreaterThan(borderLayout.size.width, 0)
        XCTAssertEqual(borderLayout.constrainedWidth, 180)
    }

    func testHighlightRelayoutUsesConstrainedWidthNotContentWidth() {
        // 居中短文：若误用 size.width 重排会整体左移。
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let text = NSMutableAttributedString(
            string: "短",
            attributes: [
                .font: UIFont.systemFont(ofSize: 18),
                .paragraphStyle: paragraph
            ]
        )
        let outer: CGFloat = 240
        let layout = ZHHTextLineLayout.make(attributedText: text, width: outer)
        XCTAssertEqual(layout.constrainedWidth, outer)
        XCTAssertLessThan(layout.size.width, outer)

        let highlight = ZHHTextHighlight()
        highlight.foregroundColor = .red
        let painted = text.zhh_applyingForTest(highlight: highlight, range: NSRange(location: 0, length: text.length))
        let width = layout.constrainedWidth > 0 ? layout.constrainedWidth : layout.size.width
        let again = ZHHTextLineLayout.make(attributedText: painted, width: width)
        XCTAssertEqual(again.constrainedWidth, outer)
        // 重排后第一行原点应仍接近居中，而不是贴左。
        guard let first = again.lines.first, let original = layout.lines.first else {
            XCTFail("应有行框")
            return
        }
        XCTAssertEqual(first.originX, original.originX, accuracy: 1.0)
    }

    func testRectsAndVisualRectsForBorderedRange() {
        let text = bordered("标签文字", outsets: UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8))
        let layout = ZHHTextLineLayout.make(attributedText: text, width: 220)
        let range = NSRange(location: 0, length: text.length)
        let base = layout.rects(for: range)
        let visual = layout.visualRects(for: range, in: text)
        XCTAssertFalse(base.isEmpty)
        XCTAssertEqual(base.count, visual.count)
        XCTAssertLessThan(visual[0].minX, base[0].minX)
        XCTAssertLessThan(visual[0].minY, base[0].minY)
        XCTAssertGreaterThan(visual[0].width, base[0].width)
        XCTAssertGreaterThan(visual[0].height, base[0].height)
    }

    func testHitBorderedLinkInOutsetArea() {
        let label = "可点标签"
        let font = UIFont.boldSystemFont(ofSize: 16)
        let text = NSMutableAttributedString(string: label, attributes: [
            .font: font,
            .foregroundColor: UIColor.white
        ])
        let full = NSRange(location: 0, length: text.length)
        let border = ZHHTextBorder(
            fillColor: .systemBlue,
            strokeColor: .systemBlue,
            lineWidth: 1,
            cornerRadius: 100,
            outsets: UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        )
        text.addAttribute(ZHHTextAttachmentAttribute.border, value: border, range: full)
        let link = ZHHTextLink(
            kind: .custom(ZHHTextCustomLink(identifier: "tag")),
            range: full,
            text: label
        )
        text.addAttribute(ZHHTextAttribute.linkID, value: link.id, range: full)

        let layout = ZHHTextLineLayout.make(attributedText: text, width: 200)
        let boxes = layout.visualRects(for: full, in: text)
        XCTAssertFalse(boxes.isEmpty)
        // 点在视觉框左上角内侧（落在 outsets 空隙，不一定在字形上）。
        let box = boxes[0]
        let point = CGPoint(x: box.minX + 2, y: box.minY + 2)
        let action = layout.hit(
            at: point,
            displayText: text,
            linksByID: [link.id: link]
        )
        guard case .link(let hit) = action?.kind else {
            XCTFail("边框 outsets 内应能命中链接")
            return
        }
        XCTAssertEqual(hit.id, link.id)
    }

    func testHitMissesWhenPointFarFromLines() {
        let text = NSAttributedString(string: "一行字", attributes: [.font: UIFont.systemFont(ofSize: 16)])
        let layout = ZHHTextLineLayout.make(attributedText: text, width: 160)
        let action = layout.hit(
            at: CGPoint(x: 10, y: layout.size.height + 40),
            displayText: text,
            linksByID: [:]
        )
        XCTAssertNil(action)
    }

    private func bordered(
        _ string: String,
        outsets: UIEdgeInsets = UIEdgeInsets(top: 3, left: 6, bottom: 3, right: 6)
    ) -> NSAttributedString {
        let text = NSMutableAttributedString(
            string: string,
            attributes: [
                .font: UIFont.systemFont(ofSize: 16),
                .foregroundColor: UIColor.white
            ]
        )
        let border = ZHHTextBorder(
            fillColor: .systemOrange,
            strokeColor: .systemOrange,
            lineWidth: 1.5,
            cornerRadius: 100,
            outsets: outsets
        )
        text.addAttribute(
            ZHHTextAttachmentAttribute.border,
            value: border,
            range: NSRange(location: 0, length: text.length)
        )
        return text
    }
}

private extension NSAttributedString {
    /// 测试用：调用文件内 private `zhh_applying` 的等价逻辑。
    func zhh_applyingForTest(highlight: ZHHTextHighlight, range: NSRange) -> NSAttributedString {
        guard range.length > 0, NSMaxRange(range) <= length else { return self }
        let mutable = NSMutableAttributedString(attributedString: self)
        if let color = highlight.foregroundColor {
            mutable.addAttribute(.foregroundColor, value: color, range: range)
        }
        if let border = highlight.border {
            mutable.addAttribute(ZHHTextAttachmentAttribute.border, value: border, range: range)
        }
        if let shadows = highlight.shadows {
            mutable.removeAttribute(.shadow, range: range)
            mutable.addAttribute(ZHHTextAttachmentAttribute.shadows, value: shadows, range: range)
        }
        if let inner = highlight.innerShadow {
            mutable.addAttribute(ZHHTextAttachmentAttribute.innerShadow, value: inner, range: range)
        }
        return mutable
    }
}

/// 胶囊标签正式 API：编辑附件、Label 边框、整段命中、兼容转换。
final class ZHHTextChipTests: XCTestCase {

    func testEditorPieceMarksAttachmentWithName() {
        let chip = ZHHTextChip(name: "周末出游", fill: 0xF07167, stroke: 0xE85D4C)
        let piece = chip.piece(font: .boldSystemFont(ofSize: 15))
        XCTAssertEqual(piece.length, 1)
        XCTAssertNotNil(piece.attribute(.attachment, at: 0, effectiveRange: nil) as? NSTextAttachment)
        XCTAssertEqual(piece.attribute(ZHHTextChipAttribute.name, at: 0, effectiveRange: nil) as? String, "周末出游")
    }

    func testLabelPieceAppliesBorderOnNameRange() {
        let chip = ZHHTextChip(name: "咖啡探店", fill: 0xE8A33A, stroke: 0xD4890A)
        let piece = chip.labelPiece(font: .boldSystemFont(ofSize: 15))
        XCTAssertTrue(piece.string.contains("咖啡探店") || piece.length > 0)
        var foundBorder = false
        piece.enumerateAttribute(ZHHTextAttachmentAttribute.border, in: NSRange(location: 0, length: piece.length)) { value, range, _ in
            guard value is ZHHTextBorder else { return }
            foundBorder = true
            XCTAssertEqual(piece.attribute(ZHHTextChipAttribute.name, at: range.location, effectiveRange: nil) as? String, "咖啡探店")
        }
        XCTAssertTrue(foundBorder)
    }

    func testAttachmentRangeTouchesCaretAfterChip() {
        let storage = NSMutableAttributedString(string: "前", attributes: [.font: UIFont.systemFont(ofSize: 16)])
        storage.append(ZHHTextChip(name: "标签", fill: 0x5B9AED, stroke: 0x3B7DD8).piece())
        storage.append(NSAttributedString(string: "后", attributes: [.font: UIFont.systemFont(ofSize: 16)]))
        // 光标在胶囊正后方（索引 2：前=0，胶囊=1，后=2）。
        let range = ZHHTextChip.attachmentRange(
            in: storage,
            touching: NSRange(location: 2, length: 0)
        )
        XCTAssertEqual(range, NSRange(location: 1, length: 1))
        XCTAssertNil(ZHHTextChip.attachmentRange(in: storage, touching: NSRange(location: 1, length: 0)))
    }

    func testLabelCompatibleConvertsChipAttachmentOnly() {
        let font = UIFont.systemFont(ofSize: 17)
        let mixed = NSMutableAttributedString()
        mixed.append(ZHHTextChip(name: "健身打卡", fill: 0xA78BFA, stroke: 0x8B5CF6).piece(font: font))
        let stray = NSTextAttachment()
        let image = UIGraphicsImageRenderer(size: CGSize(width: 12, height: 12)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 12, height: 12))
        }
        stray.image = image
        stray.bounds = CGRect(x: 0, y: 0, width: 12, height: 12)
        mixed.append(NSAttributedString(attachment: stray))

        let labelText = ZHHTextChip.labelCompatible(mixed, alignedTo: font)
        var inlineCount = 0
        var systemAttachmentCount = 0
        labelText.enumerateAttributes(in: NSRange(location: 0, length: labelText.length)) { attrs, _, _ in
            if attrs[ZHHTextAttachmentAttribute.key] is ZHHTextImageAttachment {
                inlineCount += 1
            }
            if attrs[.attachment] is NSTextAttachment {
                systemAttachmentCount += 1
            }
        }
        XCTAssertEqual(inlineCount, 1)
        XCTAssertEqual(systemAttachmentCount, 1)
    }
}

/// 自定义表情正式 API：短码替换、附件尺寸、Label 兼容转换。
final class ZHHTextEmoticonTests: XCTestCase {

    func testAttributedStringReplacesEmojiAndImageShortcodes() {
        let font = UIFont.systemFont(ofSize: 18)
        let image = makeSolidImage(side: 32)
        let mapper = ZHHTextEmoticonMapper(
            items: [
                ZHHTextEmoticonItem(token: ":smile:", emoji: "😄"),
                ZHHTextEmoticonItem(bracketName: "微笑", image: image, sizeFactor: 1.35)
            ],
            font: font
        )
        let result = mapper.attributedString(from: "你好 :smile: 和 [微笑]")
        XCTAssertFalse(result.string.contains(":smile:"))
        XCTAssertFalse(result.string.contains("[微笑]"))
        XCTAssertTrue(result.string.contains("😄"))

        var foundAttachment = false
        result.enumerateAttribute(.attachment, in: NSRange(location: 0, length: result.length)) { value, range, _ in
            guard let attachment = value as? NSTextAttachment else { return }
            foundAttachment = true
            let expected = ceil(font.lineHeight * 1.35)
            XCTAssertEqual(attachment.bounds.width, expected, accuracy: 0.5)
            XCTAssertEqual(
                result.attribute(ZHHTextEmoticonAttribute.token, at: range.location, effectiveRange: nil) as? String,
                "[微笑]"
            )
        }
        XCTAssertTrue(foundAttachment)
    }

    func testLongerTokenWinsOverPrefix() {
        let mapper = ZHHTextEmoticonMapper(
            items: [
                ZHHTextEmoticonItem(token: ":sm:", emoji: "A"),
                ZHHTextEmoticonItem(token: ":smile:", emoji: "B")
            ],
            font: .systemFont(ofSize: 16)
        )
        let result = mapper.attributedString(from: ":smile:")
        XCTAssertEqual(result.string, "B")
    }

    func testReplaceShortcodesAdjustsCaret() {
        let mapper = ZHHTextEmoticonMapper(
            items: [ZHHTextEmoticonItem(token: ":smile:", emoji: "😄")],
            font: .systemFont(ofSize: 16)
        )
        let storage = NSMutableAttributedString(string: "hi :smile:", attributes: [.font: UIFont.systemFont(ofSize: 16)])
        let caretBefore = storage.length
        let caret = mapper.replaceShortcodes(in: storage, caret: caretBefore)
        XCTAssertEqual(storage.string, "hi 😄")
        XCTAssertEqual(caret, storage.length)
    }

    func testLabelCompatibleConvertsTokenizedAttachmentOnly() {
        let font = UIFont.systemFont(ofSize: 18)
        let image = makeSolidImage(side: 24)
        let mapper = ZHHTextEmoticonMapper(
            items: [ZHHTextEmoticonItem(bracketName: "微笑", image: image, sizeFactor: 1)],
            font: font
        )
        let editor = mapper.attributedString(from: "x[微笑]")

        // 额外插入一个无 token 的附件，转换时不应被动。
        let stray = NSTextAttachment()
        stray.image = image
        stray.bounds = CGRect(x: 0, y: 0, width: 10, height: 10)
        let mixed = NSMutableAttributedString(attributedString: editor)
        mixed.append(NSAttributedString(attachment: stray))

        let labelText = ZHHTextEmoticonMapper.labelCompatible(mixed, alignedTo: font)
        var inlineCount = 0
        var systemAttachmentCount = 0
        labelText.enumerateAttributes(in: NSRange(location: 0, length: labelText.length)) { attrs, _, _ in
            if attrs[ZHHTextAttachmentAttribute.key] is ZHHTextImageAttachment {
                inlineCount += 1
            }
            if attrs[.attachment] is NSTextAttachment {
                systemAttachmentCount += 1
            }
        }
        XCTAssertEqual(inlineCount, 1)
        XCTAssertEqual(systemAttachmentCount, 1)
    }

    private func makeSolidImage(side: CGFloat) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        return renderer.image { context in
            UIColor.systemOrange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        }
    }
}
