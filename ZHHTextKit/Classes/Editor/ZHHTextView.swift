//
//  ZHHTextView.swift
//  ZHHTextKit
//
//  Created by 桃色三岁 on 2026/10/26.
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import UIKit

/// 输入 `@` / `#` 时的触发种类，供业务弹出选人 / 选话题页。
public enum ZHHTextSpecialTrigger: Sendable {
    /// 用户输入了 `@`。
    case mention
    /// 用户输入了 `#`。
    case topic
}

/// 提及的整段删除规则。话题可进光标、逐字删；URL 和电话按字符删除。
public enum ZHHTextEditing {

    /// 这次退格应立刻删掉的整段提及。
    ///
    /// 仅对原子片段（当前为 `@` 提及）生效。话题按普通字符删除。
    /// 返回非空 range 时直接删除该区间；返回 nil 表示按系统方式删除。
    /// - Parameters:
    ///   - range: 当前选区；长度为 0 表示光标。
    ///   - links: 当前正文上的链接。
    /// - Returns: 应整段删除的区间；可走系统删除时为 nil。
    public static func deletionRange(for range: NSRange, links: [ZHHTextLink]) -> NSRange? {
        let bound = links.filter(isAtomic)

        if range.length == 0 {
            let index = range.location - 1
            guard index >= 0 else { return nil }
            for link in bound {
                let start = link.range.location
                let end = start + link.range.length
                if index >= start && index < end {
                    return link.range
                }
            }
            return nil
        }

        let selectionEnd = range.location + range.length
        for link in bound {
            let start = link.range.location
            let end = start + link.range.length
            let insideLink = range.location >= start && selectionEnd <= end
            let exact = range.location == start && selectionEnd == end
            if insideLink && !exact {
                return link.range
            }
        }
        return nil
    }

    /// 提及按整段处理；话题允许逐字编辑（改字后本地 id 绑定会拆掉）。
    /// - Parameter link: 待判断的链接。
    /// - Returns: 删除时应整段处理则为 true。
    public static func isAtomic(_ link: ZHHTextLink) -> Bool {
        switch link.kind {
        case .mention:
            return true
        case .topic, .url, .phone, .custom:
            return false
        }
    }
}

/// 可输入的富文本框。用 `ZHHTextParser` 给话题、提及、URL 和电话上色。
///
/// 业务自己的选人界面继续用。选完后调用 `insert(mention:)` 或 `insert(topic:)`。
/// 输入 `@` / `#` 时可通过 `onSpecialTrigger` 弹出选择页，不要在回调里无条件 insert。
/// `@` 提及整段删除；`#` 话题主格式为单井号，可进光标、逐字删，改字后丢掉本地 id。
/// 正式跳转用的 id 以服务端发布 / 回显为准。中文联想未上屏时不改写文字。
///
/// ## 占位与字数
/// - `placeholder` / `placeholderColor`：空文且无未上屏联想时显示；布局对齐 `textContainerInset`，不挡触摸。
/// - `maxTextLength`：按 `String.count`（Swift 字素）计数，与发布正文一致；`@提及` / `#话题` 按展示原文长度计入（含 `@` / `#`）。
/// - 超限时整段拒绝插入（键盘、粘贴、`insert(mention:)` / `insert(topic:)`），并触发 `onReachMaxLength`；不静默截断半个原子提及。删除 / 退格不受限。
/// - 中文联想未上屏时不按中间态拦输入；确认上屏后再按最终长度判断。
open class ZHHTextView: UITextView {

    // MARK: - 内部 token

    /// 编辑器内带业务 id 的稳定片段。range 随增删平移；半截改写会拆掉。
    fileprivate struct EditorToken: Equatable {
        enum Payload: Equatable {
            case mention(ZHHTextMention)
            case topic(ZHHTextTopic)
        }

        var payload: Payload
        var range: NSRange

        var expectedRaw: String {
            switch payload {
            case .mention(let mention):
                return mention.raw
            case .topic(let topic):
                return topic.raw
            }
        }
    }

    // MARK: - 状态

    /// 没有解析器时使用的正文样式。
    private var storedStyle = ZHHTextStyle.body
    /// 正在重写 `textStorage`，忽略 `textDidChange` 回调，避免递归。
    private var isRestyling = false
    /// 正在把 `style` 写回 `parser`，避免互相触发。
    private var isSyncingParser = false
    /// 正在校正选区，避免 `selectedTextRange` 递归。
    private var isAdjustingSelection = false
    /// 带 id 的提及 / 话题，发布时从这里（经 `editResult.links`）取回。
    private var tokens: [EditorToken] = []
    /// 刚输入 `@` / `#`，下一次 `insert` 可吃掉触发符只补名字。
    private var pendingSpecial: ZHHTextSpecialTrigger?
    /// 上次选区起点，用于判断光标移动方向并跳过整段。
    private var lastSelectionLocation = 0
    /// 空文占位标签；不参与编辑命中。
    private lazy var placeholderLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.isUserInteractionEnabled = false
        label.isHidden = true
        return label
    }()

    // MARK: - 公开属性

    /// 最近一次按当前文本解析出的结果。提及 / 话题带插入时的业务 id。
    public private(set) var editResult = ZHHTextParseResult(
        attributedText: NSAttributedString(),
        links: []
    )

    /// 文本或样式变化后回调。参数是刚解析完的全文。
    public var onEdit: ((ZHHTextParseResult) -> Void)?

    /// 用户输入 `@` 或 `#` 时回调，业务可据此 push 选人 / 选话题页。
    public var onSpecialTrigger: ((ZHHTextSpecialTrigger) -> Void)?

    /// 是否在输入 `@` / `#` 时触发 `onSpecialTrigger`。默认 `true`。
    public var detectsSpecialTrigger = true

    /// 空文占位文案。默认 `nil`（不显示）。有内容或中文联想未上屏时隐藏。
    public var placeholder: String? {
        didSet { refreshPlaceholder() }
    }

    /// 占位颜色。默认 `tertiaryLabel`；深浅色随 `traitCollection` 刷新。
    public var placeholderColor: UIColor = .tertiaryLabel {
        didSet { placeholderLabel.textColor = placeholderColor }
    }

    /// 正文最大字数（`String.count` / 字素）。默认 `nil` 表示不限制。
    ///
    /// 计数与发布 `text` 一致；提及 / 话题按展示原文计入。超限插入整段拒绝并回调 `onReachMaxLength`。
    public var maxTextLength: Int?

    /// 触达 `maxTextLength` 且本次插入被拒绝时回调（便于业务 Toast）。
    public var onReachMaxLength: (() -> Void)?

    /// 正文和链接的样式。会写回 `parser.style`。
    public var style: ZHHTextStyle {
        get { parser?.style ?? storedStyle }
        set {
            storedStyle = newValue
            guard !isSyncingParser else { return }
            if var parser = parser {
                parser.style = newValue
                isSyncingParser = true
                self.parser = parser
                isSyncingParser = false
                restyle(preserving: selectedRange)
            } else {
                restyle(preserving: selectedRange)
            }
        }
    }

    /// 解析器。赋值后按当前纯文本重新上色。
    ///
    /// 这是值类型。改完规则后把整个解析器赋回来才会生效。
    /// 为 nil 时按 `style` 显示纯正文，不再识别话题和提及。
    public var parser: ZHHTextParser? {
        didSet {
            if let parser = parser {
                storedStyle = parser.style
            }
            guard !isSyncingParser else { return }
            seedTokensFromParserIfNeeded()
            restyle(preserving: selectedRange)
        }
    }

    // MARK: - 初始化

    /// - Parameters:
    ///   - frame: 初始 frame。
    ///   - textContainer: 文本容器；传 nil 时由系统创建。
    public override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        commonInit()
    }

    /// - Parameter coder: Interface Builder 解码器。
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - 文本读写

    open override var text: String? {
        get { super.text }
        set {
            isRestyling = true
            super.text = newValue
            isRestyling = false
            tokens.removeAll()
            seedTokensFromParserIfNeeded()
            let length = ((newValue ?? "") as NSString).length
            restyle(preserving: NSRange(location: length, length: 0))
            refreshPlaceholder()
        }
    }

    open override var textContainerInset: UIEdgeInsets {
        get { super.textContainerInset }
        set {
            super.textContainerInset = newValue
            setNeedsLayout()
        }
    }

    open override func layoutSubviews() {
        super.layoutSubviews()
        layoutPlaceholderLabel()
    }

    open override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            placeholderLabel.textColor = placeholderColor
        }
    }

    open override var selectedTextRange: UITextRange? {
        get { super.selectedTextRange }
        set {
            guard !isAdjustingSelection else {
                super.selectedTextRange = newValue
                return
            }
            guard let newValue = newValue else {
                super.selectedTextRange = nil
                return
            }
            let ns = nsRange(from: newValue)
            let adjusted = adjustedSelection(ns)
            isAdjustingSelection = true
            if let start = position(from: beginningOfDocument, offset: adjusted.location),
               let end = position(from: start, offset: adjusted.length),
               let range = textRange(from: start, to: end) {
                super.selectedTextRange = range
            } else {
                super.selectedTextRange = newValue
            }
            isAdjustingSelection = false
            lastSelectionLocation = selectedRange.location
        }
    }

    // MARK: - 公开方法

    /// 当前正文里带业务 id 的提及与话题（按 location 升序）。
    public var boundLinks: [ZHHTextLink] {
        editResult.links.filter { link in
            switch link.kind {
            case .mention(let mention):
                return mention.userID != nil
            case .topic(let topic):
                return topic.topicID != nil
            default:
                return false
            }
        }
    }

    /// 组装发布文档：全文 + 仍有效的已选实体。手打无 id 的片段不进入 `entities`，交给服务端补。
    public func makePostDocument() -> ZHHTextPostDocument {
        let entities: [ZHHTextEntity] = boundLinks.compactMap { link in
            switch link.kind {
            case .mention(let mention):
                guard let userID = mention.userID else { return nil }
                return ZHHTextEntity(
                    type: .mention,
                    id: userID,
                    name: mention.name,
                    range: link.range
                )
            case .topic(let topic):
                guard let topicID = topic.topicID else { return nil }
                return ZHHTextEntity(
                    type: .topic,
                    id: topicID,
                    name: topic.name,
                    range: link.range
                )
            default:
                return nil
            }
        }
        return ZHHTextPostDocument(text: text ?? "", entities: entities)
    }

    /// 插入一个提及。保留 `userID`，同名多人靠 range 区分。
    ///
    /// 仅当刚输入 `@`（`pendingSpecial`）时吃掉触发符只补名字；工具栏插入不会误吃上一段的字符。
    /// 两侧按需补空格，避免和相邻 @ / # 粘在一起。
    /// - Parameter mention: 要插入的提及。
    public func insert(mention: ZHHTextMention) {
        let name = ZHHTextMention.normalizedName(from: mention.name)
        guard !name.isEmpty else { return }
        let value = ZHHTextMention(name: name, userID: mention.userID)
        insertAtomic(
            payload: .mention(value),
            raw: value.raw,
            consumeTrigger: .mention,
            consumingSnippet: name
        )
    }

    /// 插入一个话题。保留 `topicID`，同名话题靠 range 区分。主格式为 `#名字`。
    ///
    /// 仅当刚输入 `#`（`pendingSpecial`）时吃掉触发符只补名字。
    /// 两侧按需补空格。插入后仍可进光标改字；改坏后本地 id 拆掉。
    /// - Parameter topic: 要插入的话题。
    public func insert(topic: ZHHTextTopic) {
        let name = ZHHTextTopic.normalizedName(from: topic.name)
        guard !name.isEmpty else { return }
        let value = ZHHTextTopic(name: name, topicID: topic.topicID)
        insertAtomic(
            payload: .topic(value),
            raw: value.raw,
            consumeTrigger: .topic,
            consumingSnippet: name
        )
    }

    // MARK: - 输入覆盖

    open override func insertText(_ text: String) {
        // 中文联想未上屏：不按中间态拦长度，交给系统；确认后再走普通路径。
        guard markedTextRange == nil else {
            super.insertText(text)
            refreshPlaceholder()
            return
        }

        if detectsSpecialTrigger {
            if text == "@" {
                insertSpecialTrigger("@", kind: .mention)
                return
            }
            if text == "#" {
                insertSpecialTrigger("#", kind: .topic)
                return
            }
            pendingSpecial = nil
        }

        if selectedRange.length > 0,
           let expanded = ZHHTextEditing.deletionRange(for: selectedRange, links: editResult.links) {
            selectedRange = expanded
        } else if selectedRange.length == 0, let link = atomicLink(containing: selectedRange.location) {
            selectedRange = NSRange(location: link.range.location + link.range.length, length: 0)
        }

        // 粘贴或输入超长：整段拒绝，不截断半个 token。
        guard allowInserting(text, replacing: selectedRange) else { return }

        applyReplacement(selectedRange, insertedLength: (text as NSString).length)
        super.insertText(text)
    }

    open override func paste(_ sender: Any?) {
        let pasteboard = UIPasteboard.general.string ?? ""
        guard markedTextRange == nil else {
            super.paste(sender)
            refreshPlaceholder()
            return
        }
        var range = selectedRange
        if range.length > 0,
           let expanded = ZHHTextEditing.deletionRange(for: range, links: editResult.links) {
            range = expanded
            selectedRange = expanded
        }
        guard allowInserting(pasteboard, replacing: range) else { return }
        super.paste(sender)
    }

    open override func deleteBackward() {
        guard markedTextRange == nil else {
            super.deleteBackward()
            refreshPlaceholder()
            return
        }
        pendingSpecial = nil

        if let expanded = ZHHTextEditing.deletionRange(for: selectedRange, links: editResult.links) {
            applyReplacement(expanded, insertedLength: 0)
            isAdjustingSelection = true
            selectedRange = expanded
            isAdjustingSelection = false
            super.deleteBackward()
            return
        }

        let selection = selectedRange
        if selection.length > 0 {
            applyReplacement(selection, insertedLength: 0)
        } else if selection.location > 0 {
            applyReplacement(NSRange(location: selection.location - 1, length: 1), insertedLength: 0)
        }
        super.deleteBackward()
    }
}

// MARK: - 初始化

private extension ZHHTextView {

    /// 公共初始化：默认解析器、占位层与文本变化观察。
    func commonInit() {
        backgroundColor = .clear
        adjustsFontForContentSizeCategory = true
        addSubview(placeholderLabel)
        placeholderLabel.textColor = placeholderColor
        parser = ZHHTextParser(style: storedStyle)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(plainTextDidChange),
            name: UITextView.textDidChangeNotification,
            object: self
        )
        refreshPlaceholder()
    }
}

// MARK: - token 与选区

private extension ZHHTextView {

    /// 把 `UITextRange` 转成 UTF-16 `NSRange`。
    func nsRange(from textRange: UITextRange) -> NSRange {
        let location = offset(from: beginningOfDocument, to: textRange.start)
        let length = offset(from: textRange.start, to: textRange.end)
        return NSRange(location: location, length: length)
    }

    /// 光标或选区落在原子提及中间时，弹到段首或段尾。话题允许进入内部。
    func adjustedSelection(_ range: NSRange) -> NSRange {
        guard range.length == 0 else {
            if let expanded = ZHHTextEditing.deletionRange(for: range, links: editResult.links) {
                return expanded
            }
            return range
        }
        guard let link = atomicLink(containing: range.location) else {
            return range
        }
        let start = link.range.location
        let end = start + link.range.length
        let location = lastSelectionLocation < range.location ? end : start
        return NSRange(location: location, length: 0)
    }

    /// 手打 `@` / `#`：紧贴非空白时先补空格（单 `#` 主格式下，下一个 `#` 视为新话题）。
    func insertSpecialTrigger(_ trigger: String, kind: ZHHTextSpecialTrigger) {
        let selection = selectedRange
        var snippet = trigger
        if shouldInsertLeadingSpaceBeforeSpecial() {
            snippet = " " + trigger
        }
        guard allowInserting(snippet, replacing: selection) else { return }
        applyReplacement(selection, insertedLength: (snippet as NSString).length)
        super.insertText(snippet)
        pendingSpecial = kind
        onSpecialTrigger?(kind)
    }

    /// 触发符紧贴非空白字符时补前导空格。
    func shouldInsertLeadingSpaceBeforeSpecial() -> Bool {
        let location = selectedRange.location
        guard location > 0 else { return false }
        return !isWhitespaceChar(character(before: location))
    }

    /// 仅「刚输入的触发符」可被吃掉。
    func shouldConsumeTrigger(_ trigger: ZHHTextSpecialTrigger) -> Bool {
        pendingSpecial == trigger
            && selectedRange.length == 0
            && character(before: selectedRange.location) == triggerCharacter(trigger)
    }

    func triggerCharacter(_ trigger: ZHHTextSpecialTrigger) -> Character {
        switch trigger {
        case .mention: return "@"
        case .topic: return "#"
        }
    }

    func character(before location: Int) -> Character? {
        let raw = (text ?? "") as NSString
        guard location > 0, location <= raw.length else { return nil }
        let piece = raw.substring(with: NSRange(location: location - 1, length: 1))
        return piece.first
    }

    func character(at location: Int) -> Character? {
        let raw = (text ?? "") as NSString
        guard location >= 0, location < raw.length else { return nil }
        let piece = raw.substring(with: NSRange(location: location, length: 1))
        return piece.first
    }

    func isWhitespaceChar(_ character: Character?) -> Bool {
        guard let character else { return false }
        return character.unicodeScalars.allSatisfy { CharacterSet.whitespacesAndNewlines.contains($0) }
    }

    /// 插入带 id 的 @ / #：处理触发符、左右空格，并登记 token。
    func insertAtomic(
        payload: EditorToken.Payload,
        raw: String,
        consumeTrigger: ZHHTextSpecialTrigger,
        consumingSnippet: String
    ) {
        let consume = shouldConsumeTrigger(consumeTrigger)
        let selection = selectedRange
        var replaceLocation = selection.location
        var replaceLength = selection.length
        var pieces = ""
        var tokenStart = selection.location

        if consume {
            replaceLocation = max(0, selection.location - 1)
            replaceLength = selection.location + selection.length - replaceLocation
            pieces = consumingSnippet
            tokenStart = replaceLocation
        } else {
            // 文首不必前导空格；紧贴非空白字符时补一个，避免粘住上一段。
            if selection.location > 0, !isWhitespaceChar(character(before: selection.location)) {
                pieces += " "
                tokenStart = selection.location + 1
            }
            pieces += raw
        }

        // 文末或后接非空白时补尾随空格，方便连续插入下一个 @ / #。
        let afterIndex = selection.location + selection.length
        if character(at: afterIndex) == nil || !isWhitespaceChar(character(at: afterIndex)) {
            pieces += " "
        }

        let token = EditorToken(
            payload: payload,
            range: NSRange(location: tokenStart, length: (raw as NSString).length)
        )
        let replace = NSRange(location: replaceLocation, length: replaceLength)
        // 整段提及 / 话题（含两侧空格）超限则整段拒绝，避免半截 token。
        guard allowInserting(pieces, replacing: replace) else { return }
        applyReplacement(replace, insertedLength: (pieces as NSString).length, inserting: token)
        insertPlain(pieces, at: replace)
        pendingSpecial = nil
    }

    /// 按替换区间平移 / 拆掉 token。
    func applyReplacement(_ replaced: NSRange, insertedLength: Int, inserting token: EditorToken? = nil) {
        var next: [EditorToken] = []
        let replacedEnd = replaced.location + replaced.length
        for item in tokens {
            let tokenEnd = item.range.location + item.range.length
            let overlap = NSIntersectionRange(item.range, replaced)
            if overlap.length > 0 || (replaced.length == 0 && item.range.location < replaced.location && tokenEnd > replaced.location) {
                continue
            }
            var updated = item
            if item.range.location >= replacedEnd {
                updated.range.location += insertedLength - replaced.length
            }
            next.append(updated)
        }
        if let token = token {
            next.append(token)
        }
        tokens = next.sorted { $0.range.location < $1.range.location }
    }

    /// 从 parser 的名字 / range 绑定种子化 token（例如 `text =` 赋初值后）。
    func seedTokensFromParserIfNeeded() {
        guard tokens.isEmpty, let parser = parser else { return }
        let raw = text ?? ""
        let ns = raw as NSString
        var seeded: [EditorToken] = []

        for binding in parser.mentionRule.bindings {
            let name = ZHHTextMention.normalizedName(from: binding.name)
            if let range = binding.range {
                guard range.location >= 0, range.location + range.length <= ns.length else { continue }
                let piece = ns.substring(with: range)
                let mention = ZHHTextMention(name: name.isEmpty ? ZHHTextMention.normalizedName(from: piece) : name, userID: binding.userID, raw: piece)
                seeded.append(EditorToken(payload: .mention(mention), range: range))
            } else if !name.isEmpty {
                let needle = "@\(name)"
                var search = raw.startIndex
                while search < raw.endIndex, let found = raw.range(of: needle, range: search..<raw.endIndex) {
                    let range = NSRange(found, in: raw)
                    seeded.append(EditorToken(
                        payload: .mention(ZHHTextMention(name: name, userID: binding.userID, raw: needle)),
                        range: range
                    ))
                    search = found.upperBound
                }
            }
        }

        for binding in parser.topicRule.bindings {
            let name = ZHHTextTopic.normalizedName(from: binding.name)
            if let range = binding.range {
                guard range.location >= 0, range.location + range.length <= ns.length else { continue }
                let piece = ns.substring(with: range)
                let topic = ZHHTextTopic(name: name.isEmpty ? ZHHTextTopic.normalizedName(from: piece) : name, topicID: binding.topicID, raw: piece)
                seeded.append(EditorToken(payload: .topic(topic), range: range))
            } else if !name.isEmpty {
                var covered = IndexSet()
                for needle in ["#\(name)#", "#\(name)"] {
                    var search = raw.startIndex
                    while search < raw.endIndex, let found = raw.range(of: needle, range: search..<raw.endIndex) {
                        let range = NSRange(found, in: raw)
                        let indices = IndexSet(integersIn: range.location ..< (range.location + range.length))
                        defer { search = found.upperBound }
                        if !covered.intersection(indices).isEmpty { continue }
                        let end = range.location + range.length
                        if end < ns.length {
                            let next = ns.substring(with: NSRange(location: end, length: 1))
                            if let character = next.first, !isSeedTopicBoundary(character) {
                                continue
                            }
                        }
                        covered.formUnion(indices)
                        seeded.append(EditorToken(
                            payload: .topic(ZHHTextTopic(name: name, topicID: binding.topicID, raw: needle)),
                            range: range
                        ))
                    }
                }
            }
        }

        tokens = seeded.sorted { $0.range.location < $1.range.location }
    }

    func isSeedTopicBoundary(_ character: Character) -> Bool {
        if character == "@" || character == "#" { return true }
        return character.unicodeScalars.allSatisfy {
            CharacterSet.whitespacesAndNewlines.contains($0) || CharacterSet.punctuationCharacters.contains($0)
        }
    }

    /// 丢掉越界或正文已对不上的 token（半截改写后拆绑定）。
    func pruneInvalidTokens(in raw: String) {
        let ns = raw as NSString
        tokens = tokens.filter { token in
            let range = token.range
            guard range.location >= 0, range.length > 0, range.location + range.length <= ns.length else {
                return false
            }
            return ns.substring(with: range) == token.expectedRaw
        }
    }
}

// MARK: - 上色与插入

private extension ZHHTextView {

    /// 系统文本变化通知。联想未上屏或正在重写时跳过。
    @objc func plainTextDidChange() {
        guard !isRestyling else { return }
        // 联想过程中只刷新占位显隐；上色仍等 markedText 结束后再走。
        if markedTextRange != nil {
            refreshPlaceholder()
            return
        }
        restyle(preserving: selectedRange)
        refreshPlaceholder()
    }

    /// 在指定选区插入纯文本，再按解析器上色。
    func insertPlain(_ string: String, at range: NSRange) {
        guard markedTextRange == nil else { return }
        let current = (text ?? "") as NSString
        var safe = range
        if safe.location > current.length {
            safe = NSRange(location: current.length, length: 0)
        }
        if safe.location + safe.length > current.length {
            safe.length = current.length - safe.location
        }
        // 上限已在 insertAtomic / insertText 入口校验；此处只落字，避免先改 token 再拒绝。
        let next = current.replacingCharacters(in: safe, with: string) as String
        let caret = safe.location + (string as NSString).length
        isRestyling = true
        super.text = next
        isRestyling = false
        restyle(preserving: NSRange(location: caret, length: 0))
    }

    /// 若设置了 `maxTextLength`，判断把 `range` 换成 `insertion` 后是否超限。
    ///
    /// 超限时触发 `onReachMaxLength` 并返回 `false`。`maxTextLength == nil` 时始终允许。
    @discardableResult
    func allowInserting(_ insertion: String, replacing range: NSRange) -> Bool {
        guard let limit = maxTextLength else { return true }
        let next = text(afterReplacing: range, with: insertion)
        guard next.count <= max(0, limit) else {
            onReachMaxLength?()
            return false
        }
        return true
    }

    /// 用 UTF-16 选区替换后的正文（再按 `String.count` 计字素）。
    func text(afterReplacing range: NSRange, with insertion: String) -> String {
        let current = (text ?? "") as NSString
        var safe = range
        if safe.location > current.length {
            safe = NSRange(location: current.length, length: 0)
        }
        if safe.location + safe.length > current.length {
            safe.length = max(0, current.length - safe.location)
        }
        return current.replacingCharacters(in: safe, with: insertion) as String
    }

    /// 刷新占位文案、颜色与显隐。
    func refreshPlaceholder() {
        let hasPlaceholder = !(placeholder?.isEmpty ?? true)
        placeholderLabel.text = placeholder
        placeholderLabel.font = font ?? storedStyle.font
        placeholderLabel.textColor = placeholderColor
        let isEmpty = (text ?? "").isEmpty
        let isMarking = markedTextRange != nil
        placeholderLabel.isHidden = !(hasPlaceholder && isEmpty && !isMarking)
        if !placeholderLabel.isHidden {
            layoutPlaceholderLabel()
        }
    }

    /// 占位框对齐 `textContainerInset` 与 `lineFragmentPadding`。
    func layoutPlaceholderLabel() {
        guard !placeholderLabel.isHidden else { return }
        let inset = textContainerInset
        let pad = textContainer.lineFragmentPadding
        let x = inset.left + pad
        let y = inset.top
        let width = bounds.width - inset.left - inset.right - pad * 2
        guard width > 0 else { return }
        let size = placeholderLabel.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        placeholderLabel.frame = CGRect(x: x, y: y, width: width, height: ceil(size.height))
    }

    /// 光标严格落在某个话题或提及内部时返回该链接。
    func atomicLink(containing caret: Int) -> ZHHTextLink? {
        editResult.links.first { link in
            guard ZHHTextEditing.isAtomic(link) else { return false }
            let start = link.range.location
            let end = start + link.range.length
            return caret > start && caret < end
        }
    }

    /// 把当前 token 叠进解析器，使结果带上 userID / topicID。
    func parserForEditing() -> ZHHTextParser {
        var current = parser ?? ZHHTextParser(style: storedStyle)
        let raw = text ?? ""
        pruneInvalidTokens(in: raw)

        var mentionBindings = current.mentionRule.bindings.filter { $0.range == nil }
        var topicBindings = current.topicRule.bindings.filter { $0.range == nil }
        for token in tokens {
            switch token.payload {
            case .mention(let mention):
                mentionBindings.append(ZHHTextMentionBinding(
                    name: mention.name,
                    userID: mention.userID,
                    range: token.range
                ))
            case .topic(let topic):
                topicBindings.append(ZHHTextTopicBinding(
                    name: topic.name,
                    topicID: topic.topicID,
                    range: token.range
                ))
            }
        }
        current.mentionRule.bindings = mentionBindings
        current.topicRule.bindings = topicBindings
        return current
    }

    /// 按当前纯文本重新上色，并尽量保住选区。
    func restyle(preserving selection: NSRange) {
        guard !isRestyling else { return }
        if markedTextRange != nil { return }
        isRestyling = true
        let raw = super.text ?? ""
        pruneInvalidTokens(in: raw)
        let activeParser = parserForEditing()
        let result = activeParser.parse(raw)
        font = storedStyle.font
        textColor = storedStyle.textColor
        typingAttributes = storedStyle.attributes(for: .body)
        if textStorage.string == result.attributedText.string {
            let full = NSRange(location: 0, length: textStorage.length)
            textStorage.beginEditing()
            if full.length == 0 {
                textStorage.setAttributedString(result.attributedText)
            } else {
                result.attributedText.enumerateAttributes(in: full, options: []) { attributes, range, _ in
                    textStorage.setAttributes(attributes, range: range)
                }
            }
            textStorage.endEditing()
        } else {
            textStorage.setAttributedString(result.attributedText)
        }
        let length = textStorage.length
        let location = min(max(selection.location, 0), length)
        let selectionLength = min(selection.length, length - location)
        isAdjustingSelection = true
        selectedRange = NSRange(location: location, length: selectionLength)
        isAdjustingSelection = false
        lastSelectionLocation = selectedRange.location
        typingAttributes = storedStyle.attributes(for: .body)
        editResult = result
        isRestyling = false
        refreshPlaceholder()
        onEdit?(result)
    }
}
