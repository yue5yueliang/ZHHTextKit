//
//  ZHHTextEntity.swift
//  ZHHTextKit
//
//  Created by 桃色三岁 on 2026/10/29.
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import Foundation

/// 发布 / 回显用的结构化实体。两端与服务端共用同一套字段。
///
/// - 客户端：`ZHHTextView.makePostDocument()` 只带上**用户明确选过**且仍有效的 id。
/// - 服务端：校验已选 id，并给手打 `#` / `@` 补齐 id 后写入详情。
/// - 查看页：只消费下发的 `entities` 做点击跳转，不要再本地猜 id。
public struct ZHHTextEntity: Hashable, Codable, Sendable {
    /// 实体种类。
    public enum Kind: String, Codable, Sendable {
        /// 用户提及。
        case mention
        /// 话题。
        case topic
    }

    /// 提及或话题。
    public var type: Kind
    /// 业务 id：`userID` 或 `topicID`。
    public var id: String
    /// 展示名（不含 `@` / `#`）。
    public var name: String
    /// 相对全文 UTF-16 起点。
    public var location: Int
    /// 相对全文 UTF-16 长度。
    public var length: Int

    /// 与正文对齐的 UTF-16 区间。
    public var range: NSRange {
        NSRange(location: location, length: length)
    }

    /// - Parameters:
    ///   - type: 提及或话题。
    ///   - id: 业务 id。
    ///   - name: 展示名。
    ///   - location: UTF-16 起点。
    ///   - length: UTF-16 长度。
    public init(type: Kind, id: String, name: String, location: Int, length: Int) {
        self.type = type
        self.id = id
        self.name = name
        self.location = location
        self.length = length
    }

    /// - Parameters:
    ///   - type: 提及或话题。
    ///   - id: 业务 id。
    ///   - name: 展示名。
    ///   - range: UTF-16 区间。
    public init(type: Kind, id: String, name: String, range: NSRange) {
        self.init(type: type, id: id, name: name, location: range.location, length: range.length)
    }
}

/// 一篇待发布或已回显的正文文档：纯文本 + 结构化实体。
public struct ZHHTextPostDocument: Hashable, Codable, Sendable {
    /// 完整正文。
    public var text: String
    /// 已确认的提及 / 话题。手打未绑定的片段可以不在这里，交给服务端补。
    public var entities: [ZHHTextEntity]

    /// - Parameters:
    ///   - text: 完整正文。
    ///   - entities: 结构化实体列表。
    public init(text: String, entities: [ZHHTextEntity] = []) {
        self.text = text
        self.entities = entities
    }
}

public extension ZHHTextPostDocument {
    /// 编码为 UTF-8 JSON，便于 Demo / 调试打印。
    /// - Parameter prettyPrinted: 是否格式化。
    /// - Returns: JSON 字符串；编码失败为 nil。
    func jsonString(prettyPrinted: Bool = true) -> String? {
        let encoder = JSONEncoder()
        if prettyPrinted {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// 从 JSON 解码。
    /// - Parameter string: JSON 字符串。
    /// - Returns: 文档；失败为 nil。
    static func from(jsonString string: String) -> ZHHTextPostDocument? {
        guard let data = string.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(ZHHTextPostDocument.self, from: data)
    }
}
