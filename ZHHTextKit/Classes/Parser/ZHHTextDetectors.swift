//
//  ZHHTextDetectors.swift
//  ZHHTextKit
//
//  Created by 桃色三岁 on 2026/10/26.
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import Foundation

/// 一次检测得到的候选区间。尚未做重叠取舍。
struct ZHHTextDetectionCandidate {
    /// 越小越优先，见 `ZHHTextDetectionPriority`。
    var priority: Int
    /// 相对全文的 UTF-16 区间。
    var range: NSRange
    /// 命中的链接种类。
    var kind: ZHHTextLink.Kind
}

/// 检测候选的优先级常量。数值越小越优先。
enum ZHHTextDetectionPriority {
    /// 带 range 的提及 / 话题绑定。
    static let binding = 0
    /// 精确话题名。
    static let exactTopic = 1
    /// 成对井号话题（兼容）。
    static let pairedTopic = 2
    /// 单井号话题模式 `#名字`。
    static let leadingTopic = 3
    /// 正则提及。
    static let mentionPattern = 4
    /// 电话。
    static let phone = 5
    /// URL。
    static let url = 6
}

/// 把重叠的检测候选收成互不重叠的结果。
enum ZHHTextSpanResolver {
    /// 按优先级、长度、起点取舍重叠区间，返回按 location 升序的结果。
    /// - Parameter candidates: 各检测器输出的候选。
    /// - Returns: 互不重叠、按 location 升序的区间。
    static func resolve(_ candidates: [ZHHTextDetectionCandidate]) -> [ZHHTextDetectionCandidate] {
        // 先按 priority 升序；同级取更长的；再比起点，保证取舍稳定。
        let sorted = candidates.sorted { lhs, rhs in
            if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
            if lhs.range.length != rhs.range.length { return lhs.range.length > rhs.range.length }
            return lhs.range.location < rhs.range.location
        }
        var accepted: [ZHHTextDetectionCandidate] = []
        for candidate in sorted {
            // 非法区间直接丢。
            if candidate.range.length <= 0 || candidate.range.location < 0 { continue }
            // 已与更高优先级（或同级更长）区间相交则放弃。
            let overlaps = accepted.contains { existing in
                NSIntersectionRange(existing.range, candidate.range).length > 0
            }
            if overlaps { continue }
            accepted.append(candidate)
        }
        // 最终按文中出现顺序排，方便后续一次性刷属性。
        return accepted.sorted { $0.range.location < $1.range.location }
    }
}

/// 话题、提及、电话、URL 的纯文本检测。不碰 UI。
enum ZHHTextDetectors {
    /// 按选项和规则收集候选区间，允许重叠。
    /// - Parameters:
    ///   - text: 纯文本。
    ///   - options: 启用的检测种类。
    ///   - topicRule: 话题规则。
    ///   - mentionRule: 提及规则。
    /// - Returns: 尚未取舍的候选列表。
    static func candidates(in text: String, options: ZHHTextParser.Options, topicRule: ZHHTextTopicRule, mentionRule: ZHHTextMentionRule) -> [ZHHTextDetectionCandidate] {
        var results: [ZHHTextDetectionCandidate] = []
        // 各类检测独立产出，重叠留给 ZHHTextSpanResolver 按优先级裁。
        if options.contains(.topic) {
            results.append(contentsOf: topics(in: text, rule: topicRule))
        }
        if options.contains(.mention) {
            results.append(contentsOf: mentions(in: text, rule: mentionRule))
        }
        // URL / 电话共用 NSDataDetector，一次扫完再按 options 分流。
        if options.contains(.url) || options.contains(.phone) {
            results.append(contentsOf: dataDetectorMatches(in: text, options: options))
        }
        return results
    }

    // MARK: - 话题

    private static func topics(in text: String, rule: ZHHTextTopicRule) -> [ZHHTextDetectionCandidate] {
        var results: [ZHHTextDetectionCandidate] = []
        let nsText = text as NSString

        // 1) 显式绑定：有 range 的直接用；否则按名字全文搜。
        for binding in rule.bindings {
            let name = ZHHTextTopic.normalizedName(from: binding.name)
            if name.isEmpty && binding.range == nil { continue }
            if let range = binding.range {
                // range 越界或空串则跳过，避免崩溃和脏链接。
                if range.location < 0 || range.length <= 0 || range.location + range.length > nsText.length {
                    continue
                }
                let raw = nsText.substring(with: range)
                let resolvedName = name.isEmpty ? ZHHTextTopic.normalizedName(from: raw) : name
                if resolvedName.isEmpty { continue }
                results.append(ZHHTextDetectionCandidate(
                    priority: ZHHTextDetectionPriority.binding,
                    range: range,
                    kind: .topic(ZHHTextTopic(name: resolvedName, topicID: binding.topicID, raw: raw))
                ))
                continue
            }
            // 无 range：用 `#name#` / `#name` 字面匹配，并要求后方是边界。
            for needle in topicNeedles(for: name) {
                for range in boundedLiteralRanges(of: needle, in: text) {
                    results.append(ZHHTextDetectionCandidate(
                        priority: ZHHTextDetectionPriority.binding,
                        range: range,
                        kind: .topic(ZHHTextTopic(name: name, topicID: binding.topicID, raw: needle))
                    ))
                }
            }
        }

        // 2) 精确名字列表：去重后按同样 needle 规则扫。
        var seen = Set<String>()
        for rawName in rule.names {
            let name = ZHHTextTopic.normalizedName(from: rawName)
            if name.isEmpty || seen.contains(name) { continue }
            seen.insert(name)
            for needle in topicNeedles(for: name) {
                for range in boundedLiteralRanges(of: needle, in: text) {
                    results.append(ZHHTextDetectionCandidate(
                        priority: ZHHTextDetectionPriority.exactTopic,
                        range: range,
                        kind: .topic(ZHHTextTopic(name: name, raw: needle))
                    ))
                }
            }
        }

        // 3) 模式检测：成对井号、单井号（受 maximumLength 限制）。
        if rule.detectsPairedHash, rule.maximumLength > 0 {
            results.append(contentsOf: pairedTopics(in: text, maximumLength: rule.maximumLength))
        }
        if rule.detectsLeadingHash, rule.maximumLength > 0 {
            results.append(contentsOf: leadingTopics(in: text, maximumLength: rule.maximumLength))
        }
        return results
    }

    /// 先长后短：`#name#` 兼容，`#name` 主格式。
    private static func topicNeedles(for name: String) -> [String] {
        ["#\(name)#", "#\(name)"]
    }

    /// 字面匹配，且针后须为边界，避免 `#周末` 误吃 `#周末去哪儿` 的前缀。
    private static func boundedLiteralRanges(of needle: String, in text: String) -> [NSRange] {
        let nsText = text as NSString
        return literalRanges(of: needle, in: text).filter { range in
            let end = range.location + range.length
            // 贴文末：后面没有字符，视为合法边界。
            guard end < nsText.length else { return true }
            let next = nsText.substring(with: NSRange(location: end, length: 1))
            guard let character = next.first else { return true }
            return isHashTagBoundary(character)
        }
    }

    private static func leadingTopics(in text: String, maximumLength: Int) -> [ZHHTextDetectionCandidate] {
        guard maximumLength > 0 else { return [] }
        var results: [ZHHTextDetectionCandidate] = []
        var search = text.startIndex
        while search < text.endIndex {
            // 找下一个 `#`，再向后吞名字字符直到边界或触顶。
            guard let hash = text[search..<text.endIndex].firstIndex(of: "#") else { break }
            var cursor = text.index(after: hash)
            var count = 0
            while cursor < text.endIndex && count < maximumLength {
                let character = text[cursor]
                if isHashTagBoundary(character) { break }
                count += 1
                cursor = text.index(after: cursor)
            }
            if count > 0 {
                // 触顶后若下一个仍不是边界，说明超长：不当截断话题，整段跳过。
                let hitLimit = count >= maximumLength
                    && cursor < text.endIndex
                    && !isHashTagBoundary(text[cursor])
                if hitLimit {
                    while cursor < text.endIndex && !isHashTagBoundary(text[cursor]) {
                        cursor = text.index(after: cursor)
                    }
                    search = cursor
                } else {
                    let slice = text[hash..<cursor]
                    let raw = String(slice)
                    results.append(ZHHTextDetectionCandidate(
                        priority: ZHHTextDetectionPriority.leadingTopic,
                        range: NSRange(hash..<cursor, in: text),
                        kind: .topic(ZHHTextTopic(
                            name: String(slice.dropFirst()),
                            topicID: nil,
                            raw: raw
                        ))
                    ))
                    search = cursor
                }
            } else {
                // `#` 后立刻是边界：空话题，跳过这个井号。
                search = text.index(after: hash)
            }
        }
        return results
    }

    private static func isHashTagBoundary(_ character: Character) -> Bool {
        // `@` / `#` 开新实体；空白、标点结束当前话题名。
        if character == "@" || character == "#" { return true }
        for scalar in character.unicodeScalars {
            if CharacterSet.whitespacesAndNewlines.contains(scalar) { return true }
            if CharacterSet.punctuationCharacters.contains(scalar) { return true }
        }
        return false
    }

    private static func pairedTopics(in text: String, maximumLength: Int) -> [ZHHTextDetectionCandidate] {
        // `#内容#`：内容不含井号和换行；超长丢弃。
        guard let expression = try? NSRegularExpression(pattern: "#([^#\\n\\r]+)#", options: []) else {
            return []
        }
        let nsText = text as NSString
        let full = NSRange(location: 0, length: nsText.length)
        var results: [ZHHTextDetectionCandidate] = []
        expression.enumerateMatches(in: text, options: [], range: full) { match, _, _ in
            guard let match = match, match.numberOfRanges > 1 else { return }
            let innerRange = match.range(at: 1)
            guard innerRange.location != NSNotFound else { return }
            let inner = nsText.substring(with: innerRange)
            if inner.isEmpty || inner.count > maximumLength { return }
            let raw = nsText.substring(with: match.range)
            results.append(ZHHTextDetectionCandidate(
                priority: ZHHTextDetectionPriority.pairedTopic,
                range: match.range,
                kind: .topic(ZHHTextTopic(name: inner, raw: raw))
            ))
        }
        return results
    }

    // MARK: - 提及

    private static func mentions(in text: String, rule: ZHHTextMentionRule) -> [ZHHTextDetectionCandidate] {
        var results: [ZHHTextDetectionCandidate] = []
        let nsText = text as NSString

        // 显式绑定优先；有 range 用 range，否则搜 `@name`。
        for binding in rule.bindings {
            let name = ZHHTextMention.normalizedName(from: binding.name)
            if name.isEmpty && binding.range == nil { continue }
            if let range = binding.range {
                if range.location < 0 || range.length <= 0 || range.location + range.length > nsText.length {
                    continue
                }
                let raw = nsText.substring(with: range)
                let resolvedName = name.isEmpty ? ZHHTextMention.normalizedName(from: raw) : name
                if resolvedName.isEmpty { continue }
                results.append(ZHHTextDetectionCandidate(
                    priority: ZHHTextDetectionPriority.binding,
                    range: range,
                    kind: .mention(ZHHTextMention(name: resolvedName, userID: binding.userID, raw: raw))
                ))
                continue
            }
            let needle = "@\(name)"
            for range in literalRanges(of: needle, in: text) {
                results.append(ZHHTextDetectionCandidate(
                    priority: ZHHTextDetectionPriority.binding,
                    range: range,
                    kind: .mention(ZHHTextMention(name: name, userID: binding.userID, raw: needle))
                ))
            }
        }
        // 无绑定的 `@名字` 模式扫描。
        if rule.detectsPattern {
            results.append(contentsOf: patternMentions(in: text, maximumLength: rule.maximumLength))
        }
        return results
    }

    private static func patternMentions(in text: String, maximumLength: Int) -> [ZHHTextDetectionCandidate] {
        guard maximumLength > 0 else { return [] }
        var results: [ZHHTextDetectionCandidate] = []
        var search = text.startIndex
        while search < text.endIndex {
            guard let at = text[search..<text.endIndex].firstIndex(of: "@") else { break }
            var cursor = text.index(after: at)
            var count = 0
            // 向后吞名字，直到边界或达到最大长度。
            while cursor < text.endIndex && count < maximumLength {
                let character = text[cursor]
                if isMentionBoundary(character) { break }
                count += 1
                cursor = text.index(after: cursor)
            }
            if count > 0 {
                let slice = text[at..<cursor]
                results.append(ZHHTextDetectionCandidate(
                    priority: ZHHTextDetectionPriority.mentionPattern,
                    range: NSRange(at..<cursor, in: text),
                    kind: .mention(ZHHTextMention(
                        name: String(slice.dropFirst()),
                        userID: nil,
                        raw: String(slice)
                    ))
                ))
                search = cursor
            } else {
                // `@` 后立刻边界：空提及，跳过。
                search = text.index(after: at)
            }
        }
        return results
    }

    private static func isMentionBoundary(_ character: Character) -> Bool {
        // 与话题边界规则一致：空白 / 标点 / 新实体符号结束名字。
        if character == "@" || character == "#" { return true }
        for scalar in character.unicodeScalars {
            if CharacterSet.whitespacesAndNewlines.contains(scalar) { return true }
            if CharacterSet.punctuationCharacters.contains(scalar) { return true }
        }
        return false
    }

    // MARK: - URL / 电话

    private static func dataDetectorMatches(in text: String, options: ZHHTextParser.Options) -> [ZHHTextDetectionCandidate] {
        // 按 options 拼 NSDataDetector 类型掩码。
        var types: NSTextCheckingTypes = 0
        if options.contains(.url) {
            types |= NSTextCheckingResult.CheckingType.link.rawValue
        }
        if options.contains(.phone) {
            types |= NSTextCheckingResult.CheckingType.phoneNumber.rawValue
        }
        guard types != 0, let detector = try? NSDataDetector(types: types) else { return [] }
        let full = NSRange(location: 0, length: (text as NSString).length)
        var results: [ZHHTextDetectionCandidate] = []
        detector.enumerateMatches(in: text, options: [], range: full) { match, _, _ in
            guard let match = match else { return }
            // 纯电话号。
            if match.resultType == .phoneNumber, let number = match.phoneNumber, options.contains(.phone) {
                results.append(ZHHTextDetectionCandidate(
                    priority: ZHHTextDetectionPriority.phone,
                    range: match.range,
                    kind: .phone(number)
                ))
                return
            }
            guard match.resultType == .link, let url = match.url else { return }
            // tel: 链接按电话处理（系统常把号码识别成 link）。
            if url.scheme?.lowercased() == "tel", options.contains(.phone) {
                let number = match.phoneNumber ?? url.absoluteString
                results.append(ZHHTextDetectionCandidate(
                    priority: ZHHTextDetectionPriority.phone,
                    range: match.range,
                    kind: .phone(number)
                ))
                return
            }
            if options.contains(.url) {
                results.append(ZHHTextDetectionCandidate(
                    priority: ZHHTextDetectionPriority.url,
                    range: match.range,
                    kind: .url(url)
                ))
            }
        }
        return results
    }

    // MARK: - 工具

    private static func literalRanges(of needle: String, in text: String) -> [NSRange] {
        // 非重叠向前搜：找到后从 upperBound 继续，避免死循环。
        if needle.isEmpty { return [] }
        var results: [NSRange] = []
        var search = text.startIndex
        while search < text.endIndex, let found = text.range(of: needle, range: search..<text.endIndex) {
            results.append(NSRange(found, in: text))
            search = found.upperBound
        }
        return results
    }
}
