//
//  ZHHTextLineLayout.swift
//  ZHHTextKit
//
//  Created by 桃色三岁 on 2026/10/26.
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import CoreText
import UIKit

/// 单行的 CoreText 几何信息，坐标系与 UIKit 一致（原点在左上）。
struct ZHHTextLaidLine {
    /// CoreText 行对象。
    let ctLine: CTLine
    /// 相对展示串的 UTF-16 区间。
    let range: NSRange
    /// 行起点的 x。
    let originX: CGFloat
    /// 行框，含 ascent 和 descent。
    let rect: CGRect
    /// 基线以上高度。
    let ascent: CGFloat
    /// 基线以下高度。
    let descent: CGFloat
}

/// 一次 CoreText 排版得到的行框。点击和绘制都走这里，避免两套坐标。
final class ZHHTextLineLayout {

    // MARK: - 行框

    /// 从上到下的行列表。
    let lines: [ZHHTextLaidLine]
    /// 全部行占用的尺寸（宽度可能小于排版约束宽，居中时常见）。
    let size: CGSize
    /// 排版时的约束宽度。按下高亮重排必须用这个，不能用 `size.width`。
    let constrainedWidth: CGFloat

    /// - Parameters:
    ///   - lines: 行框。
    ///   - size: 总尺寸。
    ///   - constrainedWidth: 排版约束宽度。
    init(lines: [ZHHTextLaidLine], size: CGSize, constrainedWidth: CGFloat = 0) {
        // constrainedWidth 默认 0：旧调用方未传时，draw 高亮重排会退回 size.width。
        self.lines = lines
        self.size = size
        self.constrainedWidth = constrainedWidth
    }

    // MARK: - 排版与命中

    /// 用 CoreText 按给定宽度排版。
    /// - Parameters:
    ///   - attributedText: 展示串。
    ///   - width: 排版宽度。
    /// - Returns: 行框与总尺寸。
    static func make(attributedText: NSAttributedString, width: CGFloat) -> ZHHTextLineLayout {
        // MARK: 入参校验
        // 空串或非法宽度：返回空布局，仍记下约束宽，方便后续高亮重排对齐。
        guard attributedText.length > 0, width > 0, width.isFinite else {
            return ZHHTextLineLayout(lines: [], size: .zero, constrainedWidth: max(width, 0))
        }

        // MARK: 边框外溢 → 内宽
        // 胶囊 / 描边会画出字形外侧。若按外宽直接排，行末边框常被裁掉。
        // 做法：左右先扣掉最大外溢，CoreText 只在「内容槽」里折行；最终行框再整体右移 pad.left。
        let pad = borderOverflow(in: attributedText)
        // 内宽至少 1，避免 CTFramesetter 对 0 宽 path 行为未定义。
        let innerWidth = max(width - pad.left - pad.right, 1)

        // MARK: CoreText 排版
        // framesetter 持有富文本度量；frame 是一次具体折行结果。
        // path 高度给很大，等于「竖向不限」，一次取出全文所有行。
        // 注意：CT 坐标系原点在左下、y 向上，后面要翻成 UIKit（左上、y 向下）。
        let framesetter = CTFramesetterCreateWithAttributedString(attributedText)
        let pathHeight = CGFloat(1_000_000)
        let path = CGPath(
            rect: CGRect(x: 0, y: 0, width: innerWidth, height: pathHeight),
            transform: nil
        )
        // CFRange.length 用全文长度，从头排到尾。
        let frame = CTFramesetterCreateFrame(
            framesetter,
            CFRange(location: 0, length: attributedText.length),
            path,
            nil
        )
        let cfLines = CTFrameGetLines(frame)
        let count = CFArrayGetCount(cfLines)
        // 有内容却 0 行：极少见（例如全是零宽），按空布局返回，约束宽仍用外宽。
        guard count > 0 else {
            return ZHHTextLineLayout(lines: [], size: .zero, constrainedWidth: width)
        }

        // 每行基线原点（CT 坐标）。range.length == 0 表示「从 0 取到末尾全部行」。
        var origins = Array(repeating: CGPoint.zero, count: count)
        CTFrameGetLineOrigins(frame, CFRange(location: 0, length: 0), &origins)

        // MARK: 收集 CT 草稿
        // 先只记 CT 几何，不在这里混 UIKit 坐标，第二趟再统一翻转，逻辑更清晰。
        struct Draft {
            let line: CTLine
            /// 基线起点的 x（相对 path，尚未加 pad）。
            let originX: CGFloat
            let ascent: CGFloat
            let descent: CGFloat
            /// 字形排版宽度（typographic width）。
            let width: CGFloat
            /// 该行在 CT 坐标下的顶部 y（基线 + ascent）。
            let ctTop: CGFloat
            /// 本行覆盖的 UTF-16 区间。
            let range: NSRange
        }

        var drafts: [Draft] = []
        drafts.reserveCapacity(count)
        // 全文在 CT 里的纵向上下界，用来算总高、以及把每行 ctTop 映射到 UIKit y。
        var globalTop = CGFloat(0)
        var globalBottom = pathHeight
        // 所有行右边缘的最大 x，决定内容宽（居中短行时会小于 innerWidth）。
        var maxX = CGFloat(0)

        for index in 0..<count {
            // CFArray 存的是裸指针，需 bitCast 成 CTLine。
            let raw = CFArrayGetValueAtIndex(cfLines, index)
            let line = unsafeBitCast(raw, to: CTLine.self)
            let origin = origins[index]

            var ascent = CGFloat(0)
            var descent = CGFloat(0)
            var leading = CGFloat(0)
            // 返回值是行宽；ascent / descent / leading 经指针写出。
            // leading（行距）暂不并进行框高度，与绘制侧「按 ascent+descent」一致。
            let typoWidth = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))

            // CT：基线在 origin.y；字形向上占 ascent，向下占 descent。
            let ctTop = origin.y + ascent
            let ctBottom = origin.y - descent
            globalTop = max(globalTop, ctTop)
            globalBottom = min(globalBottom, ctBottom)

            // 行对应的字符串区间，供截断、命中、高亮按 range 查找。
            let cfRange = CTLineGetStringRange(line)
            drafts.append(Draft(
                line: line,
                originX: origin.x,
                ascent: ascent,
                descent: descent,
                width: typoWidth,
                ctTop: ctTop,
                range: NSRange(location: cfRange.location, length: cfRange.length)
            ))
            maxX = max(maxX, origin.x + typoWidth)
        }

        // MARK: CT → UIKit 行框
        // 翻转公式：uiY = globalTop - ctTop。
        // 这样第一行顶对齐到 0（再加 pad.top），后续行按相对距离往下排。
        let height = max(globalTop - globalBottom, 0)
        var lines: [ZHHTextLaidLine] = []
        lines.reserveCapacity(drafts.count)
        for draft in drafts {
            // x / originX 加上 pad.left：内容右移，左边留给描边与 outsets。
            // y 加上 pad.top：同理给顶部边框留空。
            // height 只用 ascent+descent，与按下高亮、边框绘制共用同一套行框。
            let rect = CGRect(
                x: draft.originX + pad.left,
                y: globalTop - draft.ctTop + pad.top,
                width: draft.width,
                height: draft.ascent + draft.descent
            )
            lines.append(ZHHTextLaidLine(
                ctLine: draft.line,
                range: draft.range,
                originX: draft.originX + pad.left,
                rect: rect,
                ascent: draft.ascent,
                descent: draft.descent
            ))
        }

        // MARK: 汇总尺寸
        // 宽：内容最大右缘 + 左右 pad，且不超过调用方的外宽（防止 pad 把宽撑破约束）。
        // 高：CT 文本块高度 + 上下 pad。ceil 对齐像素，减少模糊。
        let size = CGSize(
            width: ceil(min(max(maxX + pad.left + pad.right, 0), width)),
            height: ceil(height + pad.top + pad.bottom)
        )
        // constrainedWidth 必须存「外宽」width，而不是 innerWidth：
        // 按下高亮会按同一约束重排，若误用 size.width / innerWidth，行宽会跳变。
        return ZHHTextLineLayout(lines: lines, size: size, constrainedWidth: width)
    }

    /// 统计边框向外溢出的最大边距（含一半描边宽）。
    ///
    /// `ZHHTextBorder` 相对字形向外扩：`outsets` 是空隙，`lineWidth` 的描边以路径为中线再各占一半。
    /// 排版时要按「全文各方向最大值」预留，否则行首/行末胶囊会被裁切。
    private static func borderOverflow(in text: NSAttributedString) -> UIEdgeInsets {
        // 无内容则无需留边。
        guard text.length > 0 else { return .zero }

        // 四个方向分别取「所有边框」的最大外溢，而不是相加：
        // 同行多个胶囊时，只要按最宽的那侧留空即可。
        var top: CGFloat = 0
        var left: CGFloat = 0
        var bottom: CGFloat = 0
        var right: CGFloat = 0
        let full = NSRange(location: 0, length: text.length)

        // 只扫自定义 border 键；没有边框的区间直接跳过。
        text.enumerateAttribute(ZHHTextAttachmentAttribute.border, in: full, options: []) { value, _, _ in
            guard let border = value as? ZHHTextBorder else { return }

            // 描边以边框路径为中线：一半画出 outsets 之外，所以外溢要再加 lineWidth/2。
            // lineWidth 可能为 0（只填充不描边），用 max(..., 0) 防止异常负值。
            let stroke = max(border.lineWidth, 0) * 0.5

            // 每侧：outsets + 半描边；与历史最大值取 max，得到该方向全局所需 pad。
            top = max(top, border.outsets.top + stroke)
            left = max(left, border.outsets.left + stroke)
            bottom = max(bottom, border.outsets.bottom + stroke)
            right = max(right, border.outsets.right + stroke)
        }

        // 返回值给 make(attributedText:width:)：内宽 = 外宽 - left - right，行框再整体平移。
        return UIEdgeInsets(top: top, left: left, bottom: bottom, right: right)
    }

    /// 当前行数和覆盖长度是否装得下全文。
    /// - Parameters:
    ///   - maxLines: 最大行数；`0` 视为不限制。
    ///   - textLength: 全文 UTF-16 长度。
    /// - Returns: 未超行且覆盖到文末则为 true。
    func fits(maxLines: Int, textLength: Int) -> Bool {
        // 空文视为装得下，避免截断逻辑对空串再插 token。
        if textLength == 0 { return true }
        // 行数已超上限：一定装不下（maxLines == 0 时调用方应先自行跳过本检查）。
        if lines.count > maxLines { return false }
        // 看已排行覆盖到的最大 UTF-16 终点，是否已到文末。
        let covered = lines.reduce(0) { partial, line in
            max(partial, line.range.location + line.range.length)
        }
        return covered >= textLength
    }

    /// 命中链接或截断 token。
    ///
    /// 「全文 / 收起」热区会外扩一圈；带边框的链接按边框视觉区域命中（含 outsets），与按下高亮一致。
    /// 正文点击热区外扩（与「全文」热区同量级），仅在 `allowsBodyTap` 时启用。
    private static let bodyTapPaddingX: CGFloat = 10
    private static let bodyTapPaddingY: CGFloat = 10

    /// - Parameters:
    ///   - point: UIKit 坐标。
    ///   - displayText: 展示串。
    ///   - linksByID: 链接 id 表。
    ///   - allowsBodyTap: 为 true 时，点在非链接字形（含外扩热区）上返回正文命中。
    /// - Returns: 命中动作；未命中为 nil。
    func hit(
        at point: CGPoint,
        displayText: NSAttributedString,
        linksByID: [String: ZHHTextLink],
        allowsBodyTap: Bool = false
    ) -> ZHHTextHitAction? {
        // 1) 截断 token 优先：热区外扩，避免被后面的字形命中抢走。
        if let expand = hitExpandToken(at: point, displayText: displayText) {
            return expand
        }
        // 2) 带边框链接按视觉框（含 outsets）命中，与按下高亮区域一致。
        if let bordered = hitBorderedLink(at: point, displayText: displayText, linksByID: linksByID) {
            return bordered
        }

        // 3) 先按字形精确命中。
        // 必须在链接外扩之前：否则「《用户协议》和《隐私政策》」里的「和」会被两侧链接热区抢走。
        let verticalBound = allowsBodyTap ? Self.bodyTapPaddingY : 1
        let lineSlop = allowsBodyTap ? Self.bodyTapPaddingY : 0
        if point.y >= -verticalBound,
           point.y <= size.height + verticalBound,
           let line = nearestLine(to: point, extraSlop: lineSlop),
           let action = hitCharacter(
            on: line,
            point: point,
            displayText: displayText,
            linksByID: linksByID,
            allowsBodyTap: allowsBodyTap
           ) {
            return action
        }

        // 4) 空白处再给链接外扩热区（不会覆盖已落在正文字形上的点）。
        if allowsBodyTap, let paddedLink = hitLinkPadded(at: point, displayText: displayText, linksByID: linksByID) {
            return paddedLink
        }

        // 5) 正文热区兜底：落在行框外扩区域内也算点中正文。
        if allowsBodyTap {
            return hitBodyPadded(at: point, displayText: displayText, linksByID: linksByID)
        }
        return nil
    }

    /// 在指定行上按字符命中链接或正文。
    private func hitCharacter(
        on line: ZHHTextLaidLine,
        point: CGPoint,
        displayText: NSAttributedString,
        linksByID: [String: ZHHTextLink],
        allowsBodyTap: Bool
    ) -> ZHHTextHitAction? {
        guard line.range.length > 0 else { return nil }
        // CTLine 的 position.x 相对行起点；要先减去 layout 里记下的 originX。
        let relativeX = point.x - line.originX

        // 正文可点时：先扫紧贴的正文字形。两链接夹着的「和」即使 CT 更靠近邻接链接，也归正文。
        if allowsBodyTap,
           let bodyIndex = tightBodyGlyphIndex(on: line, relativeX: relativeX, displayText: displayText) {
            return ZHHTextHitAction(
                kind: .body,
                displayRange: bodyHighlightRange(at: bodyIndex, in: displayText)
            )
        }

        let rawIndex = CTLineGetStringIndexForPosition(line.ctLine, CGPoint(x: relativeX, y: 0))
        let lineEnd = line.range.location + line.range.length
        // 点在行首左侧时 rawIndex 可能仍落在行首，后面用 containsGlyph 再滤一次。
        guard rawIndex >= line.range.location else { return nil }
        // 点在行尾空白时 index 可能顶到 lineEnd，夹到最后一个字符再查属性。
        let index = min(rawIndex, lineEnd - 1)
        guard index >= 0, index < displayText.length else { return nil }

        var effective = NSRange()
        let linkID = displayText.attribute(
            ZHHTextAttribute.linkID,
            at: index,
            effectiveRange: &effective
        ) as? String
        let isLink = linkID != nil && linkID.flatMap { linksByID[$0] } != nil
        // 链接用紧字形；正文可点时正文侧放宽。
        let glyphSlop: CGFloat = (allowsBodyTap && !isLink) ? Self.bodyTapPaddingX : 2
        guard containsGlyph(line: line, index: index, relativeX: relativeX, slop: glyphSlop) else { return nil }

        if let identifier = linkID, let link = linksByID[identifier] {
            return ZHHTextHitAction(kind: .link(link), displayRange: effective)
        }
        if allowsBodyTap {
            return ZHHTextHitAction(kind: .body, displayRange: bodyHighlightRange(at: index, in: displayText))
        }
        return nil
    }

    /// 行内是否有紧贴 `relativeX` 的普通正文字形；有则返回其下标。
    private func tightBodyGlyphIndex(
        on line: ZHHTextLaidLine,
        relativeX: CGFloat,
        displayText: NSAttributedString
    ) -> Int? {
        let ns = displayText.string as NSString
        var index = line.range.location
        let end = NSMaxRange(line.range)
        while index < end {
            let composed = ns.rangeOfComposedCharacterSequence(at: index)
            defer { index = NSMaxRange(composed) }
            guard composed.location < displayText.length else { continue }
            if displayText.attribute(ZHHTextAttribute.linkID, at: composed.location, effectiveRange: nil) != nil {
                continue
            }
            if displayText.attribute(ZHHTextAttribute.truncation, at: composed.location, effectiveRange: nil) != nil {
                continue
            }
            if containsGlyph(line: line, index: composed.location, relativeX: relativeX, slop: 2) {
                return composed.location
            }
        }
        return nil
    }

    /// 无边框链接的外扩命中，仅配合 `allowsBodyTap` 使用。
    ///
    /// 若落点下的字形是普通正文（如两链接之间的「和」），不抢，留给正文点击。
    private func hitLinkPadded(
        at point: CGPoint,
        displayText: NSAttributedString,
        linksByID: [String: ZHHTextLink]
    ) -> ZHHTextHitAction? {
        guard displayText.length > 0 else { return nil }
        if isTightBodyGlyph(at: point, displayText: displayText) {
            return nil
        }
        let full = NSRange(location: 0, length: displayText.length)
        var matched: ZHHTextHitAction?
        displayText.enumerateAttribute(ZHHTextAttribute.linkID, in: full) { value, range, stop in
            guard let identifier = value as? String,
                  let link = linksByID[identifier],
                  range.length > 0 else { return }
            let padded = rects(for: range).map {
                $0.insetBy(dx: -Self.bodyTapPaddingX, dy: -Self.bodyTapPaddingY)
            }
            guard padded.contains(where: { $0.contains(point) }) else { return }
            matched = ZHHTextHitAction(kind: .link(link), displayRange: range)
            stop.pointee = true
        }
        return matched
    }

    /// 点是否落在「非链接」正文字形上（紧容差），用于阻止链接热区吞掉夹心字。
    private func isTightBodyGlyph(at point: CGPoint, displayText: NSAttributedString) -> Bool {
        guard let line = nearestLine(to: point, extraSlop: Self.bodyTapPaddingY) else { return false }
        let relativeX = point.x - line.originX
        return tightBodyGlyphIndex(on: line, relativeX: relativeX, displayText: displayText) != nil
    }

    /// 正文外扩热区：点在行框周围也能勾选；空白处链接热区仍可点。
    private func hitBodyPadded(
        at point: CGPoint,
        displayText: NSAttributedString,
        linksByID: [String: ZHHTextLink]
    ) -> ZHHTextHitAction? {
        if let link = hitLinkPadded(at: point, displayText: displayText, linksByID: linksByID) {
            return link
        }
        for line in lines where line.range.length > 0 {
            var ascent: CGFloat = 0
            var descent: CGFloat = 0
            let width = CGFloat(CTLineGetTypographicBounds(line.ctLine, &ascent, &descent, nil))
            let hot = CGRect(
                x: line.originX,
                y: line.rect.minY,
                width: max(width, 0),
                height: line.rect.height
            ).insetBy(dx: -Self.bodyTapPaddingX, dy: -Self.bodyTapPaddingY)
            guard hot.contains(point) else { continue }

            let relativeX = point.x - line.originX
            let rawIndex = CTLineGetStringIndexForPosition(line.ctLine, CGPoint(x: relativeX, y: 0))
            let lineEnd = line.range.location + line.range.length
            let index = min(max(rawIndex, line.range.location), lineEnd - 1)
            guard index >= 0, index < displayText.length else { continue }

            if let identifier = displayText.attribute(
                ZHHTextAttribute.linkID,
                at: index,
                effectiveRange: nil
            ) as? String, let link = linksByID[identifier] {
                var effective = NSRange()
                _ = displayText.attribute(ZHHTextAttribute.linkID, at: index, effectiveRange: &effective)
                return ZHHTextHitAction(kind: .link(link), displayRange: effective)
            }
            return ZHHTextHitAction(kind: .body, displayRange: bodyHighlightRange(at: index, in: displayText))
        }
        return nil
    }

    /// 按下高亮用的连续正文区间：从命中字向两边扩到链接 / 截断 token 边界。
    private func bodyHighlightRange(at index: Int, in displayText: NSAttributedString) -> NSRange {
        let ns = displayText.string as NSString
        guard displayText.length > 0, index >= 0, index < displayText.length else {
            return NSRange(location: 0, length: 0)
        }

        func isBodyIndex(_ i: Int) -> Bool {
            guard i >= 0, i < displayText.length else { return false }
            if displayText.attribute(ZHHTextAttribute.linkID, at: i, effectiveRange: nil) != nil {
                return false
            }
            if displayText.attribute(ZHHTextAttribute.truncation, at: i, effectiveRange: nil) != nil {
                return false
            }
            return true
        }

        var start = index
        while start > 0, isBodyIndex(start - 1) {
            start -= 1
        }
        var end = index
        while end + 1 < displayText.length, isBodyIndex(end + 1) {
            end += 1
        }

        let startRange = ns.rangeOfComposedCharacterSequence(at: start)
        let endRange = ns.rangeOfComposedCharacterSequence(at: end)
        let location = startRange.location
        let max = endRange.location + endRange.length
        return NSRange(location: location, length: max - location)
    }

    /// 按视觉框命中链接：有边框时含 outsets，与按下高亮区域一致。
    func hitBorderedLink(at point: CGPoint, displayText: NSAttributedString, linksByID: [String: ZHHTextLink]) -> ZHHTextHitAction? {
        // 空串没有可点区间。
        guard displayText.length > 0 else { return nil }
        let full = NSRange(location: 0, length: displayText.length)
        var matched: ZHHTextHitAction?

        // 按 linkID 连贯区间枚举；同一链接可能跨多行，visualRects 会返回多个框。
        displayText.enumerateAttribute(ZHHTextAttribute.linkID, in: full) { value, range, stop in
            // id 对不上表、或空 range，跳过（可能是残留属性）。
            guard let identifier = value as? String,
                  let link = linksByID[identifier],
                  range.length > 0 else { return }

            // 有 border 时框会按 outsets 外扩，点在描边空隙里也能中。
            let boxes = visualRects(for: range, in: displayText)
            guard boxes.contains(where: { $0.contains(point) }) else { return }

            // 命中即停：靠前的链接优先（与绘制叠层习惯一致）。
            matched = ZHHTextHitAction(kind: .link(link), displayRange: range)
            stop.pointee = true
        }
        return matched
    }

    /// 区间视觉矩形：有 `ZHHTextBorder` 时按 outsets 外扩，与边框/高亮一致。
    func visualRects(for range: NSRange, in text: NSAttributedString) -> [CGRect] {
        // 先拿字形紧包围框；无边框时视觉框就等于它。
        let base = rects(for: range)
        guard range.length > 0, range.location < text.length else { return base }

        // 只看区间起点上的 border（整段链接通常共一份）。
        let border = text.attribute(
            ZHHTextAttachmentAttribute.border,
            at: range.location,
            effectiveRange: nil
        ) as? ZHHTextBorder
        guard let border = border else { return base }

        // inset 传负值 = 向外扩，与 drawBorders 里画胶囊用的 outsets 同一套。
        let insets = UIEdgeInsets(
            top: -border.outsets.top,
            left: -border.outsets.left,
            bottom: -border.outsets.bottom,
            right: -border.outsets.right
        )
        return base.map { $0.inset(by: insets) }
    }

    /// 按下高亮用的圆角：优先取区间上的边框圆角。
    func highlightCornerRadius(for range: NSRange, in text: NSAttributedString) -> CGFloat {
        // 非法区间或没有边框：给一个很小的默认圆角，避免直角高亮太硬。
        guard range.length > 0, range.location < text.length,
              let border = text.attribute(
                ZHHTextAttachmentAttribute.border,
                at: range.location,
                effectiveRange: nil
              ) as? ZHHTextBorder else {
            return 2
        }
        // 至少 2，防止 cornerRadius 为 0 时高亮与胶囊观感不一致。
        return max(border.cornerRadius, 2)
    }

    /// 「全文 / 收起」热区相对字形外扩的水平边距。
    ///
    /// 与 `ZHHTextLabel` 内 `expandHitControl` 的 frame 共用，避免手势命中与控件区域不一致。
    static let expandHitPaddingX: CGFloat = 12
    /// 「全文 / 收起」热区相对字形外扩的垂直边距。
    static let expandHitPaddingY: CGFloat = 10

    /// 截断 token 外扩后的命中矩形。
    ///
    /// 多行 token 会返回多段；零宽段会过滤掉。供点测与 `expandHitUnion` 共用。
    /// - Parameter range: 展示串上的 truncation 区间。
    /// - Returns: UIKit 坐标下外扩后的矩形列表。
    func expandHitRects(for range: NSRange) -> [CGRect] {
        guard range.length > 0 else { return [] }
        return rects(for: range).map {
            $0.insetBy(dx: -Self.expandHitPaddingX, dy: -Self.expandHitPaddingY)
        }.filter { $0.width > 0 && $0.height > 0 }
    }

    /// 截断 token 外扩热区的并集。
    ///
    /// Label 用单个 `UIControl` 承接命中时取并集即可；跨行 token 会略放大热区，但实现更简单。
    /// - Parameter range: 展示串上的 truncation 区间。
    /// - Returns: 外扩矩形的并集；没有有效矩形时为 nil。
    func expandHitUnion(for range: NSRange) -> CGRect? {
        let padded = expandHitRects(for: range)
        guard let first = padded.first else { return nil }
        // 多段时取并集，交给一个 UIControl 覆盖。
        return padded.dropFirst().reduce(first) { $0.union($1) }
    }

    /// 「全文 / 收起」用外扩矩形命中，手指稍偏也能点中。
    ///
    /// 热区几何与 `expandHitRects` / Label 的 `expandHitControl` 保持一致。
    func hitExpandToken(at point: CGPoint, displayText: NSAttributedString) -> ZHHTextHitAction? {
        guard displayText.length > 0 else { return nil }
        let full = NSRange(location: 0, length: displayText.length)
        var matched: ZHHTextHitAction?

        // truncation 标记在截断 token 上；可能跨行，rects 会给出多段。
        displayText.enumerateAttribute(ZHHTextAttribute.truncation, in: full) { value, range, stop in
            guard value != nil, range.length > 0 else { return }
            // 热区比字形大约一圈，列表里小字「全文」更好点。
            if expandHitRects(for: range).contains(where: { $0.contains(point) }) {
                matched = ZHHTextHitAction(kind: .expand, displayRange: range)
                stop.pointee = true
            }
        }
        return matched
    }

    /// 展示串区间对应的行框列表，用于高亮和附件摆放。
    /// - Parameter range: 相对展示串的 UTF-16 区间。
    /// - Returns: UIKit 坐标下的矩形。
    func rects(for range: NSRange) -> [CGRect] {
        guard range.length > 0 else { return [] }
        var result: [CGRect] = []

        // 区间可能跨多行：逐行求交，每行贡献一个矩形。
        for line in lines {
            let intersection = NSIntersectionRange(line.range, range)
            guard intersection.length > 0 else { continue }

            // CT 偏移相对行起点；RTL 时 end 可能小于 start，下面取 min/max。
            let start = CGFloat(CTLineGetOffsetForStringIndex(
                line.ctLine,
                intersection.location,
                nil
            ))
            let end = CGFloat(CTLineGetOffsetForStringIndex(
                line.ctLine,
                intersection.location + intersection.length,
                nil
            ))
            let left = min(start, end)
            let right = max(start, end)

            // 拼回 UIKit：x = 行原点 + 行内偏移；高度直接用整行 ascent+descent 框。
            let rect = CGRect(
                x: line.originX + left,
                y: line.rect.minY,
                width: max(right - left, 0),
                height: line.rect.height
            )
            // 零宽交段（例如空属性跑）丢掉，避免脏高亮。
            if rect.width > 0 {
                result.append(rect)
            }
        }
        return result
    }

    // MARK: - 绘制

    /// 按下反馈样式：链接 / 截断用背景，普通正文用字色。
    enum PressHighlightStyle {
        /// 圆角底色（链接、「全文 / 收起」）。
        case background
        /// 仅改前景色（普通正文）。
        case foreground
    }

    /// 按边框、背景、阴影、正文、内阴影、图片的顺序绘制。
    /// - Parameters:
    ///   - context: 当前图形上下文。
    ///   - text: 展示串。
    ///   - highlight: 按下高亮区间。
    ///   - highlightColor: 背景高亮时的底色，或前景高亮时的字色。
    ///   - highlightStyle: 按下反馈样式；默认背景。
    func draw(
        in context: CGContext,
        text: NSAttributedString,
        highlight: NSRange?,
        highlightColor: UIColor,
        highlightStyle: PressHighlightStyle = .background
    ) {
        // 按下区间若挂了自定义 ZHHTextHighlight，整段外观要换成高亮配置。
        let custom = highlight.flatMap { range -> ZHHTextHighlight? in
            guard range.length > 0, range.location < text.length else { return nil }
            return text.attribute(
                ZHHTextAttachmentAttribute.highlight,
                at: range.location,
                effectiveRange: nil
            ) as? ZHHTextHighlight
        }

        let paintText: NSAttributedString
        let painter: ZHHTextLineLayout
        let width = constrainedWidth > 0 ? constrainedWidth : size.width
        if let range = highlight, let custom = custom {
            // 自定义高亮可能改字色/边框/阴影，度量会变，必须重排。
            paintText = text.zhh_applying(highlight: custom, range: range)
            // 必须用原约束宽重排；用 size.width（内容紧包围）会导致居中文本整体左移。
            painter = ZHHTextLineLayout.make(attributedText: paintText, width: width)
        } else if let range = highlight,
                  range.length > 0,
                  custom == nil,
                  highlightStyle == .foreground,
                  NSMaxRange(range) <= text.length {
            // 正文按下：只改字色。CTLine 属性在创建时固化，必须重排才能看到新颜色。
            let mutable = NSMutableAttributedString(attributedString: text)
            mutable.addAttribute(.foregroundColor, value: highlightColor, range: range)
            paintText = mutable
            painter = ZHHTextLineLayout.make(attributedText: paintText, width: width)
        } else {
            // 无自定义高亮：沿用当前行框，避免无谓重排。
            paintText = text
            painter = self
        }

        // 底层装饰先画，正文后画，保证字在边框/背景之上。
        painter.drawBorders(in: context, text: paintText)
        painter.drawBackgrounds(in: context, text: paintText)

        // 链接 / 截断默认按下底：没有 ZHHTextHighlight 时，用传入的 highlightColor 铺一层圆角。
        if let highlight = highlight,
           highlight.length > 0,
           custom == nil,
           highlightStyle == .background {
            context.saveGState()
            context.setFillColor(highlightColor.cgColor)
            let radius = highlightCornerRadius(for: highlight, in: paintText)
            for rect in painter.visualRects(for: highlight, in: paintText) {
                let path = UIBezierPath(roundedRect: rect, cornerRadius: radius)
                context.addPath(path.cgPath)
                context.fillPath()
            }
            context.restoreGState()
        }

        // CTLineDraw 要在翻转后的 CT 坐标里画：先移到底部再 scale(1,-1)。
        context.saveGState()
        context.textMatrix = .identity
        context.translateBy(x: 0, y: painter.size.height)
        context.scaleBy(x: 1, y: -1)
        // 外阴影在字形之下。
        painter.drawShadows(in: context, text: paintText)
        for line in painter.lines {
            // UIKit 行顶 + ascent → CT 基线 y（已在翻转坐标系内）。
            let baseline = painter.size.height - (line.rect.minY + line.ascent)
            context.textPosition = CGPoint(x: line.originX, y: baseline)
            CTLineDraw(line.ctLine, context)
        }
        // 内阴影盖在字形之上。
        painter.drawInnerShadows(in: context, text: paintText)
        context.restoreGState()
        // 图片附件走 UIKit 坐标，放在翻转栈外画。
        painter.drawImages(in: context, text: paintText)
    }
}

private extension NSAttributedString {
    /// 把高亮属性写进指定区间，供按下态绘制。
    func zhh_applying(highlight: ZHHTextHighlight, range: NSRange) -> NSAttributedString {
        // 区间越界直接返回原串，避免 NSMutableAttributedString 崩溃。
        guard range.length > 0, NSMaxRange(range) <= length else { return self }
        let mutable = NSMutableAttributedString(attributedString: self)

        // 字色：按下态前景。
        if let color = highlight.foregroundColor {
            mutable.addAttribute(.foregroundColor, value: color, range: range)
        }
        // 边框：整段替换原 border（含填充/描边/圆角）。
        if let border = highlight.border {
            mutable.addAttribute(ZHHTextAttachmentAttribute.border, value: border, range: range)
        }
        // 外阴影：清掉系统 .shadow，改走自定义多阴影键，避免两套叠画。
        if let shadows = highlight.shadows {
            mutable.removeAttribute(.shadow, range: range)
            mutable.addAttribute(ZHHTextAttachmentAttribute.shadows, value: shadows, range: range)
        }
        // 内阴影：画在字形之上的那一层。
        if let inner = highlight.innerShadow {
            mutable.addAttribute(ZHHTextAttachmentAttribute.innerShadow, value: inner, range: range)
        }
        return mutable
    }
}

// MARK: - 绘制细节

private extension ZHHTextLineLayout {

    /// 按边框样式设置 dash / lineCap。
    func updateStrokeStyle(_ border: ZHHTextBorder, in context: CGContext) {
        switch border.strokeStyle {
        case .solid:
            // 实线：无虚线周期，平头直角。
            context.setLineDash(phase: 0, lengths: [])
            context.setLineCap(.butt)
            context.setLineJoin(.miter)
        case .dash:
            // 线段虚线：用 lineDash；为空则退回实线。
            if border.lineDash.isEmpty {
                context.setLineDash(phase: 0, lengths: [])
            } else {
                context.setLineDash(phase: 0, lengths: border.lineDash)
            }
            context.setLineCap(.butt)
            context.setLineJoin(.miter)
        case .circleDot:
            // 圆点虚线：零长度线段 + 圆角线帽，画出等距圆点。
            let width = max(border.lineWidth, 0.1)
            context.setLineDash(phase: 0, lengths: [0, width * 3])
            context.setLineCap(.round)
            context.setLineJoin(.round)
        }
    }

    /// 绘制圆角边框。
    func drawBorders(in context: CGContext, text: NSAttributedString) {
        guard text.length > 0 else { return }
        let full = NSRange(location: 0, length: text.length)
        // 按 border 连贯区间枚举；跨行时 rects 会给出多段，每段各画一颗胶囊。
        text.enumerateAttribute(ZHHTextAttachmentAttribute.border, in: full, options: []) { value, range, _ in
            guard let border = value as? ZHHTextBorder else { return }
            for rect in rects(for: range) {
                // 负 inset = 相对字形框外扩，与 visualRects / 命中热区一致。
                let box = rect.inset(by: UIEdgeInsets(
                    top: -border.outsets.top,
                    left: -border.outsets.left,
                    bottom: -border.outsets.bottom,
                    right: -border.outsets.right
                ))
                let path = UIBezierPath(roundedRect: box, cornerRadius: border.cornerRadius)
                // 先填后描，描边盖在填充边缘上。
                if let fill = border.fillColor {
                    context.saveGState()
                    context.setFillColor(fill.cgColor)
                    context.addPath(path.cgPath)
                    context.fillPath()
                    context.restoreGState()
                }
                if let stroke = border.strokeColor, border.lineWidth > 0 {
                    context.saveGState()
                    context.setStrokeColor(stroke.cgColor)
                    context.setLineWidth(border.lineWidth)
                    // solid / dash / circleDot 在 updateStrokeStyle 里设 dash 与 lineCap。
                    updateStrokeStyle(border, in: context)
                    context.addPath(path.cgPath)
                    context.strokePath()
                    context.restoreGState()
                }
            }
        }
    }

    /// 绘制背景色块。
    func drawBackgrounds(in context: CGContext, text: NSAttributedString) {
        guard text.length > 0 else { return }
        let full = NSRange(location: 0, length: text.length)
        // 系统 .backgroundColor：按字形紧包围填充，不做 outsets 外扩。
        text.enumerateAttribute(.backgroundColor, in: full, options: []) { value, range, _ in
            guard let color = value as? UIColor else { return }
            context.saveGState()
            context.setFillColor(color.cgColor)
            // 跨行时每行一块；与边框不同，这里不圆角。
            for rect in rects(for: range) {
                context.fill(rect)
            }
            context.restoreGState()
        }
    }

    /// 在翻转坐标系里先画阴影 run。
    func drawShadows(in context: CGContext, text: NSAttributedString) {
        guard text.length > 0 else { return }
        for line in lines {
            // 与 CTLineDraw 同一套基线，保证阴影贴在字形脚下。
            let baseline = size.height - (line.rect.minY + line.ascent)
            guard let runs = CTLineGetGlyphRuns(line.ctLine) as? [CTRun] else { continue }
            for run in runs {
                let cfRange = CTRunGetStringRange(run)
                guard cfRange.location >= 0, cfRange.location < text.length else { continue }
                // 自定义多阴影优先，否则退回系统 .shadow。
                let shadows = shadowList(in: text, at: cfRange.location)
                guard !shadows.isEmpty else { continue }
                // run 在行内的起点偏移；多阴影就同一 run 叠画多次。
                let offset = CTLineGetOffsetForStringIndex(line.ctLine, cfRange.location, nil)
                for shadow in shadows {
                    context.saveGState()
                    let color = (shadow.shadowColor as? UIColor)?.cgColor
                    context.setShadow(offset: shadow.shadowOffset, blur: shadow.shadowBlurRadius, color: color)
                    context.textPosition = CGPoint(x: line.originX + CGFloat(offset), y: baseline)
                    // length 0 = 画整个 run。
                    CTRunDraw(run, context, CFRange(location: 0, length: 0))
                    context.restoreGState()
                }
            }
        }
    }

    /// 在翻转坐标系里画内阴影。
    func drawInnerShadows(in context: CGContext, text: NSAttributedString) {
        guard text.length > 0 else { return }
        for line in lines {
            let baseline = size.height - (line.rect.minY + line.ascent)
            guard let runs = CTLineGetGlyphRuns(line.ctLine) as? [CTRun] else { continue }
            for run in runs {
                let cfRange = CTRunGetStringRange(run)
                guard cfRange.location >= 0, cfRange.location < text.length else { continue }
                guard let shadow = text.attribute(
                    ZHHTextAttachmentAttribute.innerShadow,
                    at: cfRange.location,
                    effectiveRange: nil
                ) as? NSShadow,
                let shadowUIColor = shadow.shadowColor as? UIColor else { continue }

                let offset = CTLineGetOffsetForStringIndex(line.ctLine, cfRange.location, nil)
                context.textPosition = CGPoint(x: line.originX + CGFloat(offset), y: baseline)
                // 以字形图像包围盒为裁剪区；再外扩模糊半径，避免阴影被裁没。
                var runBounds = CTRunGetImageBounds(run, context, CFRange(location: 0, length: 0))
                guard runBounds.width > 0.1, runBounds.height > 0.1 else { continue }
                runBounds = runBounds.insetBy(dx: -shadow.shadowBlurRadius - abs(shadow.shadowOffset.width),
                                              dy: -shadow.shadowBlurRadius - abs(shadow.shadowOffset.height))

                // 经典「内阴影」合成：sourceOut 挖空 + destinationIn 用字形做蒙版。
                context.saveGState()
                context.setShadow(offset: .zero, blur: 0, color: nil)
                context.setAlpha(shadowUIColor.cgColor.alpha)
                context.clip(to: runBounds)
                context.beginTransparencyLayer(auxiliaryInfo: nil)
                let opaque = shadowUIColor.withAlphaComponent(1).cgColor
                context.setShadow(offset: shadow.shadowOffset, blur: shadow.shadowBlurRadius, color: opaque)
                context.setFillColor(opaque)
                context.setBlendMode(.sourceOut)
                context.beginTransparencyLayer(auxiliaryInfo: nil)
                context.fill(runBounds)
                context.setBlendMode(.destinationIn)
                context.beginTransparencyLayer(auxiliaryInfo: nil)
                // 再用一遍 CTRun 把阴影限制在字形轮廓内。
                context.textPosition = CGPoint(x: line.originX + CGFloat(offset), y: baseline)
                CTRunDraw(run, context, CFRange(location: 0, length: 0))
                context.endTransparencyLayer()
                context.endTransparencyLayer()
                context.endTransparencyLayer()
                context.restoreGState()
            }
        }
    }

    /// 读取多道阴影或单个 `NSShadow`。
    func shadowList(in text: NSAttributedString, at index: Int) -> [NSShadow] {
        // 自定义多阴影优先：可叠多层，且与按下高亮的 shadows 字段对齐。
        if let list = text.attribute(ZHHTextAttachmentAttribute.shadows, at: index, effectiveRange: nil) as? [NSShadow],
           !list.isEmpty {
            return list
        }
        // 退回系统单阴影，兼容外部直接设 .shadow 的富文本。
        if let shadow = text.attribute(.shadow, at: index, effectiveRange: nil) as? NSShadow {
            return [shadow]
        }
        return []
    }

    /// 在 UIKit 坐标系里绘制图片附件。
    func drawImages(in context: CGContext, text: NSAttributedString) {
        // 调用方已 restore 翻转栈，这里直接用 UIKit 坐标画 UIImage。
        guard text.length > 0 else { return }
        for line in lines {
            guard let runs = CTLineGetGlyphRuns(line.ctLine) as? [CTRun] else { continue }
            for run in runs {
                let cfRange = CTRunGetStringRange(run)
                guard cfRange.location >= 0, cfRange.location < text.length else { continue }
                // 只处理图片附件；视图/图层附件由 Label 挂子视图，不在这里画。
                guard let attachment = text.attribute(
                    ZHHTextAttachmentAttribute.key,
                    at: cfRange.location,
                    effectiveRange: nil
                ) as? ZHHTextImageAttachment else { continue }

                // RunDelegate 留下的排版宽高，决定落点矩形。
                var ascent = CGFloat(0)
                var descent = CGFloat(0)
                let width = CGFloat(CTRunGetTypographicBounds(
                    run,
                    CFRange(location: 0, length: 0),
                    &ascent,
                    &descent,
                    nil
                ))
                guard width > 0, ascent + descent > 0 else { continue }

                let offset = CGFloat(CTLineGetOffsetForStringIndex(line.ctLine, cfRange.location, nil))
                // y：行顶 +（行 ascent - run ascent），与正文字形顶对齐习惯一致。
                let rect = CGRect(
                    x: line.originX + offset,
                    y: line.rect.minY + (line.ascent - ascent),
                    width: width,
                    height: ascent + descent
                )
                context.saveGState()
                attachment.image.draw(in: rect)
                context.restoreGState()
            }
        }
    }

    /// 取与点纵向最近且距离合理的一行。
    /// - Parameters:
    ///   - point: UIKit 坐标。
    ///   - extraSlop: 在默认半行高 + 2pt 之外再放宽的纵向容差。
    func nearestLine(to point: CGPoint, extraSlop: CGFloat = 0) -> ZHHTextLaidLine? {
        var chosen: ZHHTextLaidLine?
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for line in lines {
            // 用行中线距离；limit 约为半行高再加 2pt，点离太远就不认这一行。
            let distance = abs(line.rect.midY - point.y)
            let limit = max(line.rect.height / 2 + 2 + extraSlop, 2)
            if distance <= limit && distance < bestDistance {
                bestDistance = distance
                chosen = line
            }
        }
        return chosen
    }

    /// 点的相对 x 是否落在该字形宽度内，避免点中行尾空白。
    /// - Parameters:
    ///   - line: 目标行。
    ///   - index: 展示串下标。
    ///   - relativeX: 相对行起点的 x。
    ///   - slop: 左右外扩容差；默认 2pt。
    func containsGlyph(
        line: ZHHTextLaidLine,
        index: Int,
        relativeX: CGFloat,
        slop: CGFloat = 2
    ) -> Bool {
        // index → index+1 的行内偏移即该字宽度；RTL 时可能 end < start。
        let start = CGFloat(CTLineGetOffsetForStringIndex(line.ctLine, index, nil))
        let end = CGFloat(CTLineGetOffsetForStringIndex(line.ctLine, index + 1, nil))
        let left = min(start, end) - slop
        let right = max(start, end) + slop
        return relativeX >= left && relativeX <= right
    }
}

// MARK: - 附件 RunDelegate

/// 给图片和视图附件装上 CoreText 行宽回调，排版时才会把位置留出来。
enum ZHHTextRunAttachment {
    /// 读取附件占位尺寸。
    static func size(of value: Any?) -> CGSize? {
        // 三种行内附件都走 layoutSize；认不出类型则视为无附件。
        if let image = value as? ZHHTextImageAttachment { return image.layoutSize }
        if let hosted = value as? ZHHTextViewAttachment { return hosted.layoutSize }
        if let hosted = value as? ZHHTextLayerAttachment { return hosted.layoutSize }
        return nil
    }

    /// 为单字符附件写入 `CTRunDelegate`。
    /// - Parameters:
    ///   - text: 原文。
    ///   - fallbackFont: 属性里没有字体时用来垂直居中。
    /// - Returns: 已装好 run delegate 的副本。
    static func prepare(_ text: NSAttributedString, fallbackFont: UIFont) -> NSAttributedString {
        guard text.length > 0 else { return text }
        let mutable = NSMutableAttributedString(attributedString: text)
        let full = NSRange(location: 0, length: mutable.length)
        let delegateKey = NSAttributedString.Key(kCTRunDelegateAttributeName as String)

        // 只给「单字符占位 + 有 layoutSize」装 delegate；多字符附件忽略。
        mutable.enumerateAttribute(ZHHTextAttachmentAttribute.key, in: full, options: []) { value, range, _ in
            guard range.length == 1 else { return }
            let size = ZHHTextRunAttachment.size(of: value)
            guard let size = size else { return }
            // 已有 delegate 不覆盖，避免重复 retain metrics。
            if mutable.attribute(delegateKey, at: range.location, effectiveRange: nil) != nil { return }

            let font = (mutable.attribute(.font, at: range.location, effectiveRange: nil) as? UIFont) ?? fallbackFont
            // metrics 交由 CTRunDelegate 持有；dealloc 回调里 release。
            let metrics = ZHHTextRunMetrics(size: size, font: font)
            let pointer = Unmanaged.passRetained(metrics).toOpaque()
            var callbacks = CTRunDelegateCallbacks(
                version: kCTRunDelegateVersion1,
                dealloc: { refCon in
                    Unmanaged<ZHHTextRunMetrics>.fromOpaque(refCon).release()
                },
                getAscent: { refCon in
                    Unmanaged<ZHHTextRunMetrics>.fromOpaque(refCon).takeUnretainedValue().ascent
                },
                getDescent: { refCon in
                    Unmanaged<ZHHTextRunMetrics>.fromOpaque(refCon).takeUnretainedValue().descent
                },
                getWidth: { refCon in
                    Unmanaged<ZHHTextRunMetrics>.fromOpaque(refCon).takeUnretainedValue().width
                }
            )
            // 创建失败要手动 release，否则 metrics 泄漏。
            guard let delegate = CTRunDelegateCreate(&callbacks, pointer) else {
                Unmanaged<ZHHTextRunMetrics>.fromOpaque(pointer).release()
                return
            }
            mutable.addAttribute(delegateKey, value: delegate, range: range)
        }
        return mutable
    }
}

/// 附件相对正文字体垂直居中后的 ascent / descent / width。
private final class ZHHTextRunMetrics {
    /// 占位宽度。
    let width: CGFloat
    /// 基线以上。
    let ascent: CGFloat
    /// 基线以下。
    let descent: CGFloat

    /// - Parameters:
    ///   - size: 附件占位。
    ///   - font: 用来对齐的正文字体。
    init(size: CGSize, font: UIFont) {
        width = max(size.width, 0)
        // UIFont.descender 为负；转成正的 descent 高度方便和 ascent 相加。
        let fontAscent = font.ascender
        let fontDescent = -font.descender
        let fontHeight = max(fontAscent + fontDescent, 1)
        let target = max(size.height, 0)

        if target <= fontHeight {
            // 附件比字矮：在字体行高里上下均分空隙，视觉居中。
            let spare = fontHeight - target
            ascent = fontAscent - spare / 2
            descent = max(target - ascent, 0)
        } else {
            // 附件比字高：多出来的高度上下均分，撑高这一 run。
            let extra = target - fontHeight
            ascent = fontAscent + extra / 2
            descent = fontDescent + extra / 2
        }
    }
}
