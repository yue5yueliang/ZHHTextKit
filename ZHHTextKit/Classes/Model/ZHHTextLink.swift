//
//  ZHHTextLink.swift
//  ZHHTextKit
//
//  Created by 桃色三岁 on 2026/10/26.
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import Foundation

/// 话题。`name` 不含井号，`raw` 是正文里的原文。
public struct ZHHTextTopic: Hashable, Sendable {
    /// 话题名，不含前后 `#`。
    public var name: String
    /// 业务话题 id。纯正则识别时为空；正式跳转由服务端补齐。
    public var topicID: String?
    /// 正文中的原文。默认单井号 `#标题`；兼容旧数据 `#标题#`。
    public var raw: String

    /// - Parameters:
    ///   - name: 裸话题名。
    ///   - topicID: 业务话题 id。
    ///   - raw: 正文原文；为空时拼成 `#name`。
    public init(name: String, topicID: String? = nil, raw: String? = nil) {
        self.name = name
        self.topicID = topicID
        self.raw = raw ?? "#\(name)"
    }

    /// 去掉首尾空白和最多一侧前后 `#`，得到裸话题名。
    /// - Parameter raw: 可能带 `#` 的原文。
    /// - Returns: 归一后的话题名。
    public static func normalizedName(from raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") {
            value.removeFirst()
        }
        if value.hasSuffix("#") {
            value.removeLast()
        }
        return value
    }
}

/// 提及。正则识别的结果没有 `userID`，结构化绑定可以带上。
public struct ZHHTextMention: Hashable, Sendable {
    /// 用户名，不含 `@`。
    public var name: String
    /// 业务用户 id。纯正则匹配时为空。
    public var userID: String?
    /// 正文中的原文，例如 `@张三`。
    public var raw: String

    /// - Parameters:
    ///   - name: 裸用户名。
    ///   - userID: 业务用户 id。
    ///   - raw: 正文原文；为空时拼成 `@name`。
    public init(name: String, userID: String? = nil, raw: String? = nil) {
        self.name = name
        self.userID = userID
        self.raw = raw ?? "@\(name)"
    }

    /// 去掉首尾空白和前导 `@`。
    /// - Parameter raw: 可能带 `@` 的原文。
    /// - Returns: 归一后的用户名。
    public static func normalizedName(from raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("@") {
            value.removeFirst()
        }
        return value
    }
}

/// 解析器无法覆盖时，由业务直接标出的点击片段。
public struct ZHHTextCustomLink: Hashable, Sendable {
    /// 业务自定义类型名，用于区分点击。
    public var identifier: String
    /// 随点击回传的字符串载荷。
    public var userInfo: [String: String]

    /// - Parameters:
    ///   - identifier: 业务自定义类型名。
    ///   - userInfo: 随点击回传的字符串载荷。
    public init(identifier: String, userInfo: [String: String] = [:]) {
        self.identifier = identifier
        self.userInfo = userInfo
    }
}

/// 全文中的一个可点击片段。`range` 相对未截断的全文，单位是 UTF-16。
public struct ZHHTextLink: Hashable, Identifiable, Sendable {

    /// 点击片段的种类。展开和收起不属于正文链接。
    public enum Kind: Hashable, Sendable {
        /// 网页或通用 URL。
        case url(URL)
        /// 电话号码。
        case phone(String)
        /// 话题。
        case topic(ZHHTextTopic)
        /// 提及。
        case mention(ZHHTextMention)
        /// 业务自定义片段。
        case custom(ZHHTextCustomLink)

        /// 稳定类型名：`url`、`phone`、`topic`、`mention`、`custom`。
        public var typeName: String {
            switch self {
            case .url:
                return "url"
            case .phone:
                return "phone"
            case .topic:
                return "topic"
            case .mention:
                return "mention"
            case .custom:
                return "custom"
            }
        }
    }

    /// 同一轮解析内稳定的标识，写入展示副本时用来反查链接。
    public let id: String
    /// 链接种类与载荷。
    public let kind: Kind
    /// 相对全文的 UTF-16 range。截断后回调仍返回这个原文区间。
    public let range: NSRange
    /// `range` 在全文中的子串。
    public let text: String

    /// - Parameters:
    ///   - kind: 链接种类与载荷。
    ///   - range: 相对全文的 UTF-16 区间。
    ///   - text: `range` 对应的原文子串。
    ///   - id: 稳定标识；为空时按种类和区间生成。
    public init(kind: Kind, range: NSRange, text: String, id: String? = nil) {
        self.kind = kind
        self.range = range
        self.text = text
        self.id = id ?? "\(kind.typeName)@\(range.location)+\(range.length)"
    }
}
