//
//  ZHHTextParser.swift
//  ZHHTextKit
//
//  Created by 桃色三岁 on 2026/10/26.
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import UIKit

/// 一处由业务给定的话题。有 `range` 时按该区间高亮，不再用名字搜索。
public struct ZHHTextTopicBinding: Hashable, Sendable {
    /// 话题名，可带或不带前后 `#`。
    public var name: String
    /// 业务话题 id。
    public var topicID: String?
    /// 相对全文的 UTF-16 range。为空时搜索 `#name`（兼兼容 `#name#`）。
    public var range: NSRange?

    /// - Parameters:
    ///   - name: 话题名，可带或不带 `#`。
    ///   - topicID: 业务话题 id。
    ///   - range: 锁定的 UTF-16 区间；为空时按名字搜索。
    public init(name: String, topicID: String? = nil, range: NSRange? = nil) {
        self.name = name
        self.topicID = topicID
        self.range = range
    }
}

/// 话题匹配规则。
public struct ZHHTextTopicRule {
    /// 精确话题名。元素可带或不带 `#`，比较前会归一成裸名。
    public var names: [String]
    /// 结构化绑定。带 `range` 或 `topicID` 时优先于纯名字 / 模式扫描。
    public var bindings: [ZHHTextTopicBinding]
    /// 是否扫描单井号 `#话题`（主格式，对齐小红书 / 微信）。
    public var detectsLeadingHash: Bool
    /// 是否扫描成对井号 `#话题#`（兼容旧正文）。
    public var detectsPairedHash: Bool
    /// 话题名的字符数上限（Swift `Character`）。超长不视为话题。
    public var maximumLength: Int

    /// - Parameters:
    ///   - names: 精确话题名列表。
    ///   - bindings: 结构化话题绑定。
    ///   - detectsLeadingHash: 是否识别 `#话题`。
    ///   - detectsPairedHash: 是否识别 `#话题#`。
    ///   - maximumLength: 话题名最大字符数。
    public init(names: [String] = [], bindings: [ZHHTextTopicBinding] = [], detectsLeadingHash: Bool = true, detectsPairedHash: Bool = true, maximumLength: Int = 50) {
        // 默认开启单井号与成对井号；maximumLength 按 Character 计，不是 UTF-16。
        self.names = names
        self.bindings = bindings
        self.detectsLeadingHash = detectsLeadingHash
        self.detectsPairedHash = detectsPairedHash
        self.maximumLength = maximumLength
    }
}

/// 一处由业务给定的提及。有 `range` 时按该区间高亮，不再用名字搜索。
public struct ZHHTextMentionBinding: Hashable, Sendable {
    /// 用户名，可带或不带前导 `@`。
    public var name: String
    /// 业务用户 id。
    public var userID: String?
    /// 相对全文的 UTF-16 range。为空时搜索 `@name`。
    public var range: NSRange?

    /// - Parameters:
    ///   - name: 用户名，可带或不带 `@`。
    ///   - userID: 业务用户 id。
    ///   - range: 锁定的 UTF-16 区间；为空时按名字搜索。
    public init(name: String, userID: String? = nil, range: NSRange? = nil) {
        self.name = name
        self.userID = userID
        self.range = range
    }
}

/// 提及匹配规则。
public struct ZHHTextMentionRule {
    /// 结构化绑定。优先于正则。
    public var bindings: [ZHHTextMentionBinding]
    /// 是否用正则扫描 `@` 后的名字。
    public var detectsPattern: Bool
    /// `@` 之后名字的字符数上限（Swift `Character`）。
    public var maximumLength: Int

    /// - Parameters:
    ///   - bindings: 结构化提及绑定。
    ///   - detectsPattern: 是否用正则扫描 `@名字`。
    ///   - maximumLength: `@` 后名字的最大字符数。
    public init(bindings: [ZHHTextMentionBinding] = [], detectsPattern: Bool = true, maximumLength: Int = 30) {
        // detectsPattern 默认开：无绑定也能扫出 `@名字`。
        self.bindings = bindings
        self.detectsPattern = detectsPattern
        self.maximumLength = maximumLength
    }
}

/// 把纯文本解析成富文本和链接元数据。值类型，可在后台线程调用。
///
/// 重叠区间的保留顺序：带 range 的提及绑定、精确话题名、成对井号话题、正则提及、电话、URL。
/// 同级时更长者优先，长度相同则起点更前者优先。输出的 `links` 互不重叠，并按 location 升序。
public struct ZHHTextParser {

    // MARK: - 选项

    /// 解析时启用的检测种类。
    public struct Options: OptionSet {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        /// 话题。
        public static let topic = Options(rawValue: 1 << 0)
        /// 提及。
        public static let mention = Options(rawValue: 1 << 1)
        /// URL。
        public static let url = Options(rawValue: 1 << 2)
        /// 电话。
        public static let phone = Options(rawValue: 1 << 3)
        /// 四类全部启用。
        public static let all: Options = [.topic, .mention, .url, .phone]
    }

    // MARK: - 属性

    /// 正文和链接的样式。
    public var style: ZHHTextStyle
    /// 启用的检测种类。
    public var options: Options
    /// 话题规则。
    public var topicRule: ZHHTextTopicRule
    /// 提及规则。
    public var mentionRule: ZHHTextMentionRule

    // MARK: - 初始化

    /// - Parameters:
    ///   - style: 正文和链接样式。
    ///   - options: 启用的检测种类。
    ///   - topicRule: 话题规则。
    ///   - mentionRule: 提及规则。
    public init(style: ZHHTextStyle = .body, options: Options = .all, topicRule: ZHHTextTopicRule = ZHHTextTopicRule(), mentionRule: ZHHTextMentionRule = ZHHTextMentionRule()) {
        // 默认全开检测；业务可收窄 options 或改 rule。
        self.style = style
        self.options = options
        self.topicRule = topicRule
        self.mentionRule = mentionRule
    }
}

// MARK: - 解析

public extension ZHHTextParser {

    /// 按样式解析纯文本。
    /// - Parameters:
    ///   - text: 纯文本。
    ///   - style: 正文和链接样式。
    ///   - options: 启用的检测种类。
    /// - Returns: 富文本和链接元数据。
    static func parse(_ text: String, style: ZHHTextStyle, options: Options = .all) -> ZHHTextParseResult {
        // 便捷入口：临时构造 parser，规则用默认 topic/mention。
        ZHHTextParser(style: style, options: options).parse(text)
    }

    /// 解析纯文本。链接 range 与返回的富文本对齐，坐标是 UTF-16。
    /// - Parameter text: 纯文本。
    /// - Returns: 富文本和链接元数据。
    func parse(_ text: String) -> ZHHTextParseResult {
        parse(text, overlaying: [])
    }

    /// 按服务端（或本地草稿）下发的文档解析。`entities` 以 range 锁定并带上 id，供查看页点击。
    /// - Parameter document: 正文 + 实体。
    /// - Returns: 富文本和链接元数据。
    func parse(_ document: ZHHTextPostDocument) -> ZHHTextParseResult {
        parse(document.text, overlaying: document.entities)
    }

    /// 解析正文，并把给定实体叠进绑定（优先于纯文本猜测）。
    /// - Parameters:
    ///   - text: 纯文本。
    ///   - entities: 已确认的提及 / 话题。
    /// - Returns: 富文本和链接元数据。
    func parse(_ text: String, overlaying entities: [ZHHTextEntity]) -> ZHHTextParseResult {
        // MARK: 叠实体绑定
        // 拷贝规则再追加，避免改到调用方持有的 parser 原值。
        // 带 range 的 binding 优先级最高，保证服务端下发的 @/# 不被模式扫描改写。
        var topicRule = self.topicRule
        var mentionRule = self.mentionRule
        // 把已确认实体写成带 range 的 binding，检测时优先生效。
        for entity in entities {
            switch entity.type {
            case .mention:
                // id → userID；有 range 时不再按名字全文搜 @。
                mentionRule.bindings.append(
                    ZHHTextMentionBinding(name: entity.name, userID: entity.id, range: entity.range)
                )
            case .topic:
                // id → topicID；有 range 时锁定该区间为话题。
                topicRule.bindings.append(
                    ZHHTextTopicBinding(name: entity.name, topicID: entity.id, range: entity.range)
                )
            }
        }

        // MARK: 检测 + 去重叠
        // candidates 允许重叠；resolve 按 priority / 长度 / 起点裁成互不重叠列表。
        let accepted = ZHHTextSpanResolver.resolve(
            ZHHTextDetectors.candidates(
                in: text,
                options: options,
                topicRule: topicRule,
                mentionRule: mentionRule
            )
        )

        // MARK: 候选 → 链接元数据
        // link.text 用 Swift Range 截原文；NSRange 越界或编码对不上时丢弃该项。
        let links: [ZHHTextLink] = accepted.compactMap { candidate in
            guard let swiftRange = Range(candidate.range, in: text) else { return nil }
            return ZHHTextLink(
                kind: candidate.kind,
                range: candidate.range,
                text: String(text[swiftRange])
            )
        }

        // MARK: 刷富文本
        // 先整段正文样式，再按链接角色覆盖颜色等属性（不改字符串长度，range 仍对齐）。
        let mutable = NSMutableAttributedString(string: text, attributes: style.attributes(for: .body))
        for link in links {
            let end = link.range.location + link.range.length
            guard link.range.location >= 0, end <= mutable.length else { continue }
            mutable.addAttributes(style.attributes(for: role(for: link.kind)), range: link.range)
        }
        return ZHHTextParseResult(attributedText: mutable, links: links)
    }
}

// MARK: - 内部

private extension ZHHTextParser {

    /// 链接种类对应的样式角色。
    func role(for kind: ZHHTextLink.Kind) -> ZHHTextStyle.Role {
        // custom 没有独立色板，暂跟 URL 同一套，避免正文色。
        switch kind {
        case .topic:
            return .topic
        case .mention:
            return .mention
        case .url:
            return .url
        case .phone:
            return .phone
        case .custom:
            return .url
        }
    }
}
