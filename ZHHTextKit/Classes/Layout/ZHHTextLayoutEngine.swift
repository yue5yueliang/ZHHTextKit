//
//  ZHHTextLayoutEngine.swift
//  ZHHTextKit
//
//  Created by 桃色三岁 on 2026/10/26.
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import UIKit

/// Label 一次排版的输入。截断 token 的拼接在引擎内完成，不回写调用方的全文。
struct ZHHTextLayoutRequest {
    /// 全文富文本，不含截断 token。
    var attributedText: NSAttributedString
    /// 与全文对齐的链接。
    var links: [ZHHTextLink]
    /// 排版宽度，单位 point。
    var constrainedWidth: CGFloat
    /// 最大行数；`0` 表示不限制。
    var numberOfLines: Int
    /// 是否展开。
    var isExpanded: Bool
    /// 截断 token 和正文样式。
    var style: ZHHTextStyle
    /// 折叠态文案。
    var collapsedLinkText: String
    /// 展开态文案。
    var expandedLinkText: String
    /// 是否绘制折叠文案。
    var showsCollapsedToken: Bool
    /// 是否绘制展开文案。
    var showsExpandedToken: Bool
    /// 省略号；`truncationToken` 非空时不使用。
    var truncationEllipsis: String
    /// 非空时替换折叠态的省略号和 `collapsedLinkText`。整段都可点，用来展开。
    var truncationToken: NSAttributedString?
    /// 颜色解析使用的界面风格。
    var interfaceStyle: UIUserInterfaceStyle
}

extension ZHHTextLayoutInput {
    /// 转成引擎内部请求。
    var request: ZHHTextLayoutRequest {
        ZHHTextLayoutRequest(
            attributedText: attributedText,
            links: links,
            constrainedWidth: width,
            numberOfLines: numberOfLines,
            isExpanded: isExpanded,
            style: style,
            collapsedLinkText: collapsedLinkText,
            expandedLinkText: expandedLinkText,
            showsCollapsedToken: showsCollapsedToken,
            showsExpandedToken: showsExpandedToken,
            truncationEllipsis: truncationEllipsis,
            truncationToken: truncationToken,
            interfaceStyle: interfaceStyle
        )
    }
}

/// 同步排版。使用 CoreText，以便同一套结果能在后台线程计算并缓存。
enum ZHHTextLayoutEngine {

    // MARK: - 公开接口

    /// 根据请求生成缓存键。
    /// - Parameter request: 排版输入。
    /// - Returns: 可用于缓存的键。
    static func makeKey(_ request: ZHHTextLayoutRequest) -> ZHHTextLayoutKey {
        ZHHTextLayoutKey(
            sourceText: request.attributedText.string,
            contentHash: contentHash(for: request),
            widthBucket: widthBucket(for: request.constrainedWidth),
            numberOfLines: max(request.numberOfLines, 0),
            isExpanded: request.isExpanded
        )
    }

    /// 同步计算一次排版结果。
    /// - Parameter request: 排版输入。
    /// - Returns: 含行框和可点区间的结果。
    static func layout(_ request: ZHHTextLayoutRequest) -> ZHHTextLayout {
        let key = makeKey(request)
        let width = resolvedWidth(request.constrainedWidth)
        let source = ZHHTextRunAttachment.prepare(request.attributedText, fallbackFont: request.style.font)
        let limit = max(request.numberOfLines, 0)
        let built = buildDisplay(request: request, source: source, width: width, limit: limit)
        let resolved = ZHHTextColorResolver.resolve(built.text, interfaceStyle: request.interfaceStyle)
        let lines = ZHHTextLineLayout.make(attributedText: resolved, width: width)
        return ZHHTextLayout(
            key: key,
            size: lines.size,
            displayText: resolved,
            isTruncated: built.isTruncated,
            lineLayout: lines,
            linksByID: built.linksByID,
            truncationRange: built.truncationRange
        )
    }
}

// MARK: - 展示串

private extension ZHHTextLayoutEngine {

    /// 截断拼接后的中间结果。
    struct DisplayBuild {
        /// 展示串。
        var text: NSAttributedString
        /// 是否发生过截断。
        var isTruncated: Bool
        /// 展示串链接 id 到原文链接。
        var linksByID: [String: ZHHTextLink]
        /// 可点截断 token 区间。
        var truncationRange: NSRange?
    }

    /// 按展开 / 折叠规则生成展示串。
    static func buildDisplay(
        request: ZHHTextLayoutRequest,
        source: NSAttributedString,
        width: CGFloat,
        limit: Int
    ) -> DisplayBuild {
        if source.length == 0 || limit == 0 {
            return stamped(source: source, links: request.links, visibleLength: source.length, isTruncated: false, truncationRange: nil)
        }

        let fullLines = ZHHTextLineLayout.make(attributedText: source, width: width)
        let exceeds = !fullLines.fits(maxLines: limit, textLength: source.length)
        if !exceeds {
            return stamped(source: source, links: request.links, visibleLength: source.length, isTruncated: false, truncationRange: nil)
        }

        if request.isExpanded {
            return expandedDisplay(request: request, source: source)
        }
        return collapsedDisplay(request: request, source: source, width: width, limit: limit)
    }

    /// 展开态：全文后可选拼接「收起」。
    static func expandedDisplay(
        request: ZHHTextLayoutRequest,
        source: NSAttributedString
    ) -> DisplayBuild {
        let showToken = request.showsExpandedToken && !request.expandedLinkText.isEmpty
        guard showToken else {
            return stamped(
                source: source,
                links: request.links,
                visibleLength: source.length,
                isTruncated: true,
                truncationRange: nil
            )
        }

        let mutable = NSMutableAttributedString(attributedString: source)
        let separator = needsSeparator(before: source.string) ? " " : ""
        let token = separator + request.expandedLinkText
        let start = mutable.length
        mutable.append(NSAttributedString(string: token, attributes: tokenAttributes(request: request, source: source)))
        let location = start + (separator as NSString).length
        let range = NSRange(location: location, length: (request.expandedLinkText as NSString).length)
        if range.length > 0, range.location + range.length <= mutable.length {
            mutable.addAttribute(ZHHTextAttribute.truncation, value: true, range: range)
        }
        return stamped(
            source: mutable,
            links: request.links,
            visibleLength: source.length,
            isTruncated: true,
            truncationRange: range.length > 0 ? range : nil
        )
    }

    /// 折叠态：截取前缀并拼上截断 token。
    static func collapsedDisplay(
        request: ZHHTextLayoutRequest,
        source: NSAttributedString,
        width: CGFloat,
        limit: Int
    ) -> DisplayBuild {
        let token = collapsedToken(request: request, source: source)
        // 自定义 token，或默认「…全文」都可点。
        let tappable = token.length > 0 && (
            (request.truncationToken?.length ?? 0) > 0
                || (request.showsCollapsedToken && !request.collapsedLinkText.isEmpty)
        )
        let best = bestPrefixLength(source: source, token: token, width: width, limit: limit, request: request)
        let mutable = NSMutableAttributedString(attributedString: prefix(source, length: best))
        let tokenStart = mutable.length
        if token.length > 0 {
            mutable.append(token)
        }
        var truncationRange: NSRange?
        if tappable, tokenStart < mutable.length {
            truncationRange = NSRange(location: tokenStart, length: mutable.length - tokenStart)
            mutable.addAttribute(ZHHTextAttribute.truncation, value: true, range: truncationRange!)
        }
        return stamped(
            source: mutable,
            links: request.links,
            visibleLength: best,
            isTruncated: true,
            truncationRange: truncationRange
        )
    }

    /// 折叠态截断片段：自定义 token，或默认「…」+「全文」。
    ///
    /// 默认拼装时，「…」用正文色，「全文」用截断色；整段仍由调用方标成同一展开热区。
    /// 自定义 `truncationToken` 整段沿用原样，不做分色。
    static func collapsedToken(
        request: ZHHTextLayoutRequest,
        source: NSAttributedString
    ) -> NSAttributedString {
        if let custom = request.truncationToken, custom.length > 0 {
            let mutable = NSMutableAttributedString(attributedString: custom)
            if source.length > 0,
               mutable.attribute(.paragraphStyle, at: 0, effectiveRange: nil) == nil,
               let paragraph = source.attribute(.paragraphStyle, at: 0, effectiveRange: nil) {
                mutable.addAttribute(
                    .paragraphStyle,
                    value: paragraph,
                    range: NSRange(location: 0, length: mutable.length)
                )
            }
            return ZHHTextRunAttachment.prepare(mutable, fallbackFont: request.style.font)
        }
        let includeWord = request.showsCollapsedToken && !request.collapsedLinkText.isEmpty
        let ellipsis = request.truncationEllipsis
        if ellipsis.isEmpty && !includeWord { return NSAttributedString() }

        let mutable = NSMutableAttributedString()
        if !ellipsis.isEmpty {
            mutable.append(
                NSAttributedString(
                    string: ellipsis,
                    attributes: ellipsisAttributes(request: request, source: source)
                )
            )
        }
        if includeWord {
            mutable.append(
                NSAttributedString(
                    string: request.collapsedLinkText,
                    attributes: tokenAttributes(request: request, source: source)
                )
            )
        }
        return mutable
    }

    /// 二分找最长前缀，使拼上 token 后仍不超过行数。
    static func bestPrefixLength(
        source: NSAttributedString,
        token: NSAttributedString,
        width: CGFloat,
        limit: Int,
        request: ZHHTextLayoutRequest
    ) -> Int {
        let nsText = source.string as NSString
        var low = 0
        var high = nsText.length
        var best = 0
        while low <= high {
            let mid = low + (high - low) / 2
            let cut = floorComposed(mid, in: nsText)
            let candidate = collapsedString(source: source, prefixLength: cut, token: token, request: request)
            let lines = ZHHTextLineLayout.make(attributedText: candidate, width: width)
            if lines.fits(maxLines: limit, textLength: candidate.length) {
                best = cut
                low = mid + 1
            } else if cut <= 0 {
                break
            } else {
                high = cut - 1
            }
        }

        var cut = best
        var candidate = collapsedString(source: source, prefixLength: cut, token: token, request: request)
        var lines = ZHHTextLineLayout.make(attributedText: candidate, width: width)
        var guardCount = 0
        while cut > 0 && !lines.fits(maxLines: limit, textLength: candidate.length) && guardCount < nsText.length {
            let range = nsText.rangeOfComposedCharacterSequence(at: cut - 1)
            cut = range.location
            candidate = collapsedString(source: source, prefixLength: cut, token: token, request: request)
            lines = ZHHTextLineLayout.make(attributedText: candidate, width: width)
            guardCount += 1
        }
        return trimmingTrailingWhitespace(candidatePrefixLength: cut, in: nsText)
    }

    /// 前缀加 token 的候选展示串。
    static func collapsedString(
        source: NSAttributedString,
        prefixLength: Int,
        token: NSAttributedString,
        request: ZHHTextLayoutRequest
    ) -> NSAttributedString {
        let head = prefix(source, length: trimmingTrailingWhitespace(candidatePrefixLength: prefixLength, in: source.string as NSString))
        if token.length == 0 { return head }
        let mutable = NSMutableAttributedString(attributedString: head)
        mutable.append(token)
        return mutable
    }

    /// 给可见区打上链接 id，并包成 `DisplayBuild`。
    static func stamped(
        source: NSAttributedString,
        links: [ZHHTextLink],
        visibleLength: Int,
        isTruncated: Bool,
        truncationRange: NSRange?
    ) -> DisplayBuild {
        let mutable = NSMutableAttributedString(attributedString: source)
        let visible = NSRange(location: 0, length: max(0, min(visibleLength, mutable.length)))
        var linksByID: [String: ZHHTextLink] = [:]
        for link in links {
            let intersection = NSIntersectionRange(link.range, visible)
            if intersection.length <= 0 { continue }
            if intersection.location + intersection.length > mutable.length { continue }
            mutable.addAttribute(ZHHTextAttribute.linkID, value: link.id, range: intersection)
            linksByID[link.id] = link
        }
        return DisplayBuild(
            text: mutable,
            isTruncated: isTruncated,
            linksByID: linksByID,
            truncationRange: truncationRange
        )
    }

    /// 截取富文本前缀。
    static func prefix(_ text: NSAttributedString, length: Int) -> NSAttributedString {
        if length <= 0 { return NSAttributedString() }
        let safe = min(length, text.length)
        return text.attributedSubstring(from: NSRange(location: 0, length: safe))
    }

    /// 折叠省略号属性：正文色/字体，尽量继承正文段落样式。
    static func ellipsisAttributes(
        request: ZHHTextLayoutRequest,
        source: NSAttributedString
    ) -> [NSAttributedString.Key: Any] {
        var attributes = request.style.attributes(for: .body)
        if source.length > 0, let paragraph = source.attribute(.paragraphStyle, at: 0, effectiveRange: nil) {
            attributes[.paragraphStyle] = paragraph
        }
        return attributes
    }

    /// 「全文 / 收起」属性；尽量继承正文段落样式。
    static func tokenAttributes(
        request: ZHHTextLayoutRequest,
        source: NSAttributedString
    ) -> [NSAttributedString.Key: Any] {
        var attributes = request.style.attributes(for: .truncation)
        if source.length > 0, let paragraph = source.attribute(.paragraphStyle, at: 0, effectiveRange: nil) {
            attributes[.paragraphStyle] = paragraph
        }
        return attributes
    }

    /// 展开态在「收起」前是否需要空格分隔。
    static func needsSeparator(before text: String) -> Bool {
        guard let last = text.last else { return false }
        return !last.isWhitespace && !last.isNewline
    }

    /// 去掉前缀末尾空白，避免省略号贴着空格。
    static func trimmingTrailingWhitespace(candidatePrefixLength: Int, in text: NSString) -> Int {
        var end = min(max(candidatePrefixLength, 0), text.length)
        while end > 0 {
            let range = text.rangeOfComposedCharacterSequence(at: end - 1)
            let piece = text.substring(with: range)
            let isSpace = piece.unicodeScalars.allSatisfy { scalar in
                CharacterSet.whitespacesAndNewlines.contains(scalar)
            }
            if !isSpace { break }
            end = range.location
        }
        return end
    }

    /// 把 UTF-16 下标对齐到组合字符边界。
    static func floorComposed(_ index: Int, in text: NSString) -> Int {
        if index <= 0 { return 0 }
        if index >= text.length { return text.length }
        let range = text.rangeOfComposedCharacterSequence(at: index)
        if range.location < index {
            return range.location
        }
        return index
    }
}

// MARK: - 宽度与哈希

private extension ZHHTextLayoutEngine {

    /// 无效宽度时退成 1，避免 CoreText 异常。
    static func resolvedWidth(_ width: CGFloat) -> CGFloat {
        if width > 0, width.isFinite {
            return width
        }
        return 1
    }

    /// 宽度量化成毫点，减少浮点键抖动。
    static func widthBucket(for width: CGFloat) -> Int {
        guard width > 0, width.isFinite else { return 0 }
        let milli = width * 1000
        if milli >= CGFloat(Int.max) { return Int.max }
        return Int(milli.rounded())
    }

    /// 进程内内容哈希，覆盖链接、截断、样式和附件。
    static func contentHash(for request: ZHHTextLayoutRequest) -> Int {
        var hasher = Hasher()
        hasher.combine(request.links.map { "\($0.id):\($0.range.location):\($0.range.length):\($0.kind.typeName)" })
        hasher.combine(request.numberOfLines)
        hasher.combine(request.isExpanded)
        hasher.combine(request.collapsedLinkText)
        hasher.combine(request.expandedLinkText)
        hasher.combine(request.showsCollapsedToken)
        hasher.combine(request.showsExpandedToken)
        hasher.combine(request.truncationEllipsis)
        hasher.combine(request.truncationToken?.string)
        hasher.combine(request.interfaceStyle.rawValue)
        let style = request.style
        hasher.combine(style.font.fontName)
        hasher.combine(style.font.pointSize)
        hasher.combine(style.lineSpacing)
        hasher.combine(style.alignment.rawValue)
        hasher.combine(style.lineBreakMode.rawValue)
        hasher.combine(style.textColor.description)
        hasher.combine(style.linkColor.description)
        hasher.combine(style.topicColor?.description)
        hasher.combine(style.mentionColor?.description)
        hasher.combine(style.urlColor?.description)
        hasher.combine(style.phoneColor?.description)
        hasher.combine(style.truncationColor.description)
        hasher.combine(style.truncationFont?.fontName)
        hasher.combine(style.truncationFont?.pointSize)
        hashAttributes(request.attributedText, into: &hasher)
        if let token = request.truncationToken {
            hashAttributes(token, into: &hasher)
        }
        return hasher.finalize()
    }

    /// 同一段纯文本可以带不同颜色、阴影和附件。这些差别必须进缓存键。
    /// 把影响绘制的属性折进哈希。
    static func hashAttributes(_ text: NSAttributedString, into hasher: inout Hasher) {
        guard text.length > 0 else { return }
        let full = NSRange(location: 0, length: text.length)
        text.enumerateAttributes(in: full, options: []) { attributes, range, _ in
            hasher.combine(range.location)
            hasher.combine(range.length)
            if let font = attributes[.font] as? UIFont {
                hasher.combine(font.fontName)
                hasher.combine(font.pointSize)
            }
            if let color = attributes[.foregroundColor] as? UIColor {
                hasher.combine(color.description)
            }
            if let shadow = attributes[.shadow] as? NSShadow {
                hasher.combine(shadow.shadowBlurRadius)
                hasher.combine(shadow.shadowOffset.width)
                hasher.combine(shadow.shadowOffset.height)
            }
            if attributes[ZHHTextAttachmentAttribute.border] != nil {
                hasher.combine(1)
            }
            if let image = attributes[ZHHTextAttachmentAttribute.key] as? ZHHTextImageAttachment {
                hasher.combine(image.layoutSize.width)
                hasher.combine(image.layoutSize.height)
                hasher.combine(ObjectIdentifier(image.image).hashValue)
            } else if let hosted = attributes[ZHHTextAttachmentAttribute.key] as? ZHHTextViewAttachment {
                hasher.combine(hosted.layoutSize.width)
                hasher.combine(hosted.layoutSize.height)
                hasher.combine(ObjectIdentifier(hosted.view).hashValue)
            } else if let hosted = attributes[ZHHTextAttachmentAttribute.key] as? ZHHTextLayerAttachment {
                hasher.combine(hosted.layoutSize.width)
                hasher.combine(hosted.layoutSize.height)
                hasher.combine(ObjectIdentifier(hosted.layer).hashValue)
            }
        }
    }
}
