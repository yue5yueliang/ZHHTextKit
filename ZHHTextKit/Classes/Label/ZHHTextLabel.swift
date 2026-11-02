//
//  ZHHTextLabel.swift
//  ZHHTextKit
//
//  Created by 桃色三岁 on 2026/10/26.
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import UIKit

/// 富文本展示视图。负责行数、截断 token 和点击分发，不负责识别话题或链接语法。
///
/// 水平排版。后续若增加竖排，仍通过 `apply`、`text` 和 `onTapLink` 使用，不另开一套数据接口。
/// 链接的 `range` 始终相对未截断全文。完全落在被裁掉区域里的链接不可点；与可见区有交集的链接保持可点，回调里的 range 仍是原文区间。
///
/// 列表复用时把展开态放在数据模型上，并为可见区域附近的数据调用 `ZHHTextLayoutPrefetcher`。
/// `layoutCache` 命中后不会把上一条内容画到当前 cell。
open class ZHHTextLabel: UIView {

    // MARK: - 状态

    /// 当前正文从哪条路径写入。
    private enum ContentSource {
        /// `text` 直接赋值，未走解析器。
        case plain
        /// `text` 经 `parser` 解析后写入。
        case parsed
        /// `apply` 或直接赋值 `attributedText`。
        case applied
    }

    /// 最近一次写入的纯文本。
    private var storedText: String?
    /// 未截断的全文富文本。
    private var storedAttributedText: NSAttributedString?
    /// 与全文对齐的链接。
    private var storedLinks: [ZHHTextLink] = []
    /// 正文来源，决定改 `style` 时是否重新解析。
    private var contentSource: ContentSource = .plain
    /// 正在把 `style` 与 `parser.style` 互相同步，避免互相触发。
    private var isSyncingStyle = false
    /// 当前宽度下缓存的排版结果。
    private var cachedLayout: ZHHTextLayout?
    /// `cachedLayout` 对应的排版宽度。
    private var cachedLayoutWidth: CGFloat?
    /// 上一次 `layoutSubviews` 看到的 bounds 宽度。
    private var lastBoundsWidth: CGFloat = 0
    /// 排版代数。后台结果晚到时，代数对不上就丢弃。
    private var layoutGeneration = 0
    /// 按下高亮的展示串区间。
    private var highlightedRange: NSRange?
    /// 当前手指按下命中的动作。
    private var activeHit: ZHHTextHitAction?
    /// 行内视图附件：身份到宿主视图。
    private var attachmentHosts: [ObjectIdentifier: UIView] = [:]
    /// 行内图层附件：身份到子图层。
    private var attachmentLayers: [ObjectIdentifier: CALayer] = [:]

    // MARK: - 公开属性

    /// 正文和截断 token 的样式。
    ///
    /// 修改后会写回 `parser.style`。内容来自 `text` 时会重新解析；内容来自 `apply` 或直接赋值的 `attributedText` 时保留原字符串，样式只影响截断 token 和按压高亮。
    public var style: ZHHTextStyle = .body {
        didSet {
            guard !isSyncingStyle else { return }
            isSyncingStyle = true
            if var parser = parser {
                parser.style = style
                self.parser = parser
            }
            isSyncingStyle = false
            switch contentSource {
            case .plain, .parsed:
                setPlainText(storedText, force: true)
            case .applied:
                publishContentChange()
            }
        }
    }

    /// 解析器。赋值时会把它的 `style` 同步到视图，并按当前 `text` 重新解析。
    ///
    /// 这是值类型。调整规则后把整个解析器重新赋回来，才会触发解析。
    public var parser: ZHHTextParser? {
        didSet {
            guard !isSyncingStyle else { return }
            if let parser = parser {
                isSyncingStyle = true
                style = parser.style
                isSyncingStyle = false
            }
            setPlainText(storedText, force: true)
        }
    }

    /// 纯文本。赋值后按 `parser` 解析；没有解析器时按 `style` 生成正文。该赋值会替换已有的 `attributedText` 和 `links`。
    public var text: String? {
        get { storedText }
        set { setPlainText(newValue, force: false) }
    }

    /// 全文富文本，不含截断 token。直接赋值会清空 `links`。要同时提交链接，使用 `apply(_:)`。
    public var attributedText: NSAttributedString? {
        get { storedAttributedText }
        set {
            storedAttributedText = newValue
            storedText = newValue?.string
            storedLinks = []
            contentSource = .applied
            publishContentChange()
        }
    }

    /// 全文上的链接。range 相对 `attributedText`。
    public var links: [ZHHTextLink] {
        get { storedLinks }
        set {
            guard newValue != storedLinks else { return }
            storedLinks = newValue
            publishContentChange()
        }
    }

    /// 最大行数。`0` 表示不限制，此时不绘制截断 token。
    public var numberOfLines: Int = 0 {
        didSet {
            guard numberOfLines != oldValue else { return }
            publishContentChange()
        }
    }

    /// 计算 `intrinsicContentSize` 时使用的宽度。大于 0 时优先于当前 bounds 宽度。
    public var preferredMaxLayoutWidth: CGFloat = 0 {
        didSet {
            guard preferredMaxLayoutWidth != oldValue else { return }
            publishContentChange()
        }
    }

    /// 是否展开。折叠且正文超出 `numberOfLines` 时绘制「全文」；展开且确实发生过截断时绘制「收起」。
    public var isExpanded: Bool = false {
        didSet {
            guard isExpanded != oldValue else { return }
            publishContentChange()
        }
    }

    /// 折叠态截断处的可点文案。
    public var collapsedLinkText: String = "全文" {
        didSet {
            guard collapsedLinkText != oldValue else { return }
            publishContentChange()
        }
    }

    /// 展开态末尾的可点文案。
    public var expandedLinkText: String = "收起" {
        didSet {
            guard expandedLinkText != oldValue else { return }
            publishContentChange()
        }
    }

    /// 折叠且发生截断时，是否绘制 `collapsedLinkText`。
    public var showsCollapsedToken: Bool = true {
        didSet {
            guard showsCollapsedToken != oldValue else { return }
            publishContentChange()
        }
    }

    /// 展开且正文超过行数时，是否绘制 `expandedLinkText`。
    public var showsExpandedToken: Bool = true {
        didSet {
            guard showsExpandedToken != oldValue else { return }
            publishContentChange()
        }
    }

    /// 拼在「全文」前面的省略号。整个省略号加文案是一个点击热区。
    ///
    /// `truncationToken` 非空时，折叠态改用那段富文本，本属性和 `collapsedLinkText` 不再参与绘制。
    public var truncationEllipsis: String = "…" {
        didSet {
            guard truncationEllipsis != oldValue else { return }
            publishContentChange()
        }
    }

    /// 折叠态的自定义截断片段。可以带颜色、字体、图片或视图。
    ///
    /// 为 nil 或空串时，仍使用 `truncationEllipsis` 和 `collapsedLinkText`。非空时整段都是展开热区。
    public var truncationToken: NSAttributedString? {
        didSet {
            publishContentChange()
        }
    }

    /// 为 true 时，缓存未命中的排版放到后台计算。主线程会等待这一次结果，因此行高不会先跳成 0。
    ///
    /// 列表里应配合 `layoutCache` 和 `ZHHTextLayoutPrefetcher`。缓存命中时不会等待，也不会画上一个 cell 的正文。
    public var displaysAsynchronously: Bool = false

    /// 点击话题、提及、URL、电话或自定义链接时回调。参数中的 range 是原文区间。
    public var onTapLink: ((ZHHTextLink) -> Void)?

    /// 点击「全文 / 收起」后回调。参数是切换后的 `isExpanded`。视图会先更新状态再回调。
    public var onTapExpand: ((Bool) -> Void)?

    /// 跨 cell 共享的布局缓存。命中时直接复用排版，避免重复计算和串内容。
    public var layoutCache: ZHHTextLayoutCache?

    /// 当前宽度下正文是否超出 `numberOfLines`。还没有宽度时为 false。
    public var isTruncated: Bool {
        let width = measurementWidth(fitting: 0)
        guard width > 0 else { return false }
        return layout(constrainedWidth: width).isTruncated
    }

    // MARK: - 初始化

    /// - Parameter frame: 初始 frame。
    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    /// - Parameter coder: Interface Builder 解码器。
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    // MARK: - 公开方法

    /// 同时替换全文和链接。适合直接承接 `ZHHTextParser` 的输出，也适合业务自行染色后的结果。
    /// - Parameter result: 解析结果；`links` 的 range 需与 `attributedText` 对齐。
    public func apply(_ result: ZHHTextParseResult) {
        storedText = result.attributedText.string
        storedAttributedText = result.attributedText
        storedLinks = result.links
        contentSource = .applied
        publishContentChange()
    }

    /// 返回该点命中的正文链接。坐标系是 bounds。截断 token 不从这里返回。
    /// - Parameter point: 相对本视图 bounds 的点。
    /// - Returns: 命中的链接；点在空白或截断 token 上时为 nil。
    public func link(at point: CGPoint) -> ZHHTextLink? {
        guard let action = hitAction(at: point) else { return nil }
        if case .link(let link) = action.kind {
            return link
        }
        return nil
    }

    /// 在指定点执行一次点击（单测用）。
    /// - Parameter point: 相对 bounds 的点。
    func performInteraction(at point: CGPoint) {
        guard let action = hitAction(at: point) else { return }
        activate(action)
    }

    // MARK: - 布局与绘制

    open override func sizeThatFits(_ size: CGSize) -> CGSize {
        let width = measurementWidth(fitting: size.width)
        guard width > 0 else { return .zero }
        return layout(constrainedWidth: width).size
    }

    open override var intrinsicContentSize: CGSize {
        let width = measurementWidth(fitting: 0)
        guard width > 0, width.isFinite else {
            return CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
        }
        let height = layout(constrainedWidth: width).size.height
        return CGSize(width: UIView.noIntrinsicMetric, height: height)
    }

    open override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0 else { return }
        if bounds.width != lastBoundsWidth {
            lastBoundsWidth = bounds.width
            if cachedLayoutWidth != bounds.width {
                cachedLayout = nil
                cachedLayoutWidth = nil
            }
            setNeedsDisplay()
            if preferredMaxLayoutWidth <= 0 {
                invalidateIntrinsicContentSize()
            }
        }
        placeViewAttachments(layout(constrainedWidth: bounds.width))
    }

    open override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard bounds.width > 0, bounds.height > 0, let context = UIGraphicsGetCurrentContext() else { return }
        let result = layout(constrainedWidth: bounds.width)
        let color = style.highlightColor.resolvedColor(with: traitCollection)
        result.lineLayout.draw(
            in: context,
            text: result.displayText,
            highlight: highlightedRange,
            highlightColor: color
        )
        placeViewAttachments(result)
    }

    open override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            publishContentChange()
        }
    }

    // MARK: - 触摸

    open override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard isUserInteractionEnabled, !isHidden, alpha > 0.01 else { return nil }
        guard self.point(inside: point, with: event) else { return nil }
        for subview in subviews.reversed() {
            let local = convert(point, to: subview)
            if let hit = subview.hitTest(local, with: event) {
                return hit
            }
        }
        guard hitAction(at: point) != nil else { return nil }
        return self
    }

    open override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self), let action = hitAction(at: point) else {
            clearHighlight()
            return
        }
        activeHit = action
        highlightedRange = action.displayRange
        setNeedsDisplay()
    }

    open override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else { return }
        guard let action = hitAction(at: point), action.kind == activeHit?.kind else {
            highlightedRange = nil
            setNeedsDisplay()
            return
        }
        highlightedRange = action.displayRange
        setNeedsDisplay()
    }

    open override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        let hit = activeHit
        defer { clearHighlight() }
        guard let hit = hit, let point = touches.first?.location(in: self) else { return }
        guard let action = hitAction(at: point), action.kind == hit.kind else { return }
        activate(action)
    }

    open override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        clearHighlight()
    }
}

// MARK: - 初始化

private extension ZHHTextLabel {

    /// 公共初始化：透明背景、重绘、可点、无障碍。
    func commonInit() {
        backgroundColor = .clear
        isOpaque = false
        clipsToBounds = true
        isUserInteractionEnabled = true
        contentMode = .redraw
        isAccessibilityElement = true
        accessibilityTraits = .staticText
        setContentCompressionResistancePriority(.required, for: .vertical)
        setContentHuggingPriority(.required, for: .vertical)
    }
}

// MARK: - 内容

private extension ZHHTextLabel {

    /// 写入纯文本。有解析器时走解析，否则按正文样式生成。
    /// - Parameters:
    ///   - newValue: 纯文本；为 nil 时清空。
    ///   - force: 为 true 时即使文本相同也重新解析。
    func setPlainText(_ newValue: String?, force: Bool) {
        if !force && newValue == storedText { return }
        storedText = newValue
        guard let newValue = newValue else {
            storedAttributedText = nil
            storedLinks = []
            contentSource = parser == nil ? .plain : .parsed
            publishContentChange()
            return
        }
        if let parser = parser {
            let result = parser.parse(newValue)
            storedAttributedText = result.attributedText
            storedLinks = result.links
            contentSource = .parsed
        } else {
            storedAttributedText = NSAttributedString(
                string: newValue,
                attributes: style.attributes(for: .body)
            )
            storedLinks = []
            contentSource = .plain
        }
        publishContentChange()
    }

    /// 正文或截断配置变化后清空缓存并请求重排。
    func publishContentChange() {
        layoutGeneration += 1
        cachedLayout = nil
        cachedLayoutWidth = nil
        highlightedRange = nil
        activeHit = nil
        accessibilityLabel = storedText
        invalidateIntrinsicContentSize()
        setNeedsLayout()
        setNeedsDisplay()
    }
}

// MARK: - 排版

private extension ZHHTextLabel {

    /// 测算用宽度：优先入参，其次 `preferredMaxLayoutWidth`，再退到 bounds。
    /// - Parameter proposedWidth: `sizeThatFits` 传入的宽度；无效时忽略。
    /// - Returns: 可用宽度；尚无宽度时为 0。
    func measurementWidth(fitting proposedWidth: CGFloat) -> CGFloat {
        if proposedWidth > 0, proposedWidth.isFinite {
            return proposedWidth
        }
        if preferredMaxLayoutWidth > 0 {
            return preferredMaxLayoutWidth
        }
        if bounds.width > 0 {
            return bounds.width
        }
        return 0
    }

    /// 取当前宽度下的排版，命中本地缓存或共享缓存则直接返回。
    /// - Parameter width: 排版宽度。
    /// - Returns: 排版结果。
    func layout(constrainedWidth width: CGFloat) -> ZHHTextLayout {
        if let cachedLayout = cachedLayout, cachedLayoutWidth == width {
            return cachedLayout
        }
        let generation = layoutGeneration
        let request = makeRequest(width)
        let result = ZHHTextLayoutTasks.layout(
            request,
            cache: layoutCache,
            asynchronous: displaysAsynchronously
        )
        if generation != layoutGeneration {
            return layout(constrainedWidth: width)
        }
        cachedLayout = result
        cachedLayoutWidth = width
        return result
    }

    /// 用当前属性拼出排版请求。
    /// - Parameter width: 排版宽度。
    /// - Returns: 引擎输入。
    func makeRequest(_ width: CGFloat) -> ZHHTextLayoutRequest {
        ZHHTextLayoutRequest(
            attributedText: storedAttributedText ?? NSAttributedString(),
            links: storedLinks,
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
            interfaceStyle: traitCollection.userInterfaceStyle
        )
    }
}

// MARK: - 命中与附件

private extension ZHHTextLabel {

    /// 分发链接点击或切换展开态。
    /// - Parameter action: 命中结果。
    func activate(_ action: ZHHTextHitAction) {
        switch action.kind {
        case .link(let link):
            onTapLink?(link)
        case .expand:
            isExpanded = !isExpanded
            onTapExpand?(isExpanded)
        }
    }

    /// 按排版结果摆放行内视图和图层，并移除过期的宿主。
    /// - Parameter layout: 当前宽度下的排版。
    func placeViewAttachments(_ layout: ZHHTextLayout) {
        let text = layout.displayText
        var live = Set<ObjectIdentifier>()
        var liveLayers = Set<ObjectIdentifier>()
        let full = NSRange(location: 0, length: text.length)
        if full.length > 0 {
            text.enumerateAttribute(ZHHTextAttachmentAttribute.key, in: full, options: []) { value, range, _ in
                guard let attachment = value as? ZHHTextViewAttachment else { return }
                let view = attachment.view
                let identifier = ObjectIdentifier(view)
                live.insert(identifier)
                self.attachmentHosts[identifier] = view
                guard let rect = layout.lineLayout.rects(for: range).first, rect.width > 0 else {
                    view.isHidden = true
                    return
                }
                if view.superview !== self {
                    self.addSubview(view)
                }
                view.isHidden = false
                let size = attachment.layoutSize
                view.frame = CGRect(
                    x: rect.minX + (rect.width - size.width) / 2,
                    y: rect.minY + (rect.height - size.height) / 2,
                    width: size.width,
                    height: size.height
                )
            }
            text.enumerateAttribute(ZHHTextAttachmentAttribute.key, in: full, options: []) { value, range, _ in
                guard let attachment = value as? ZHHTextLayerAttachment else { return }
                let layer = attachment.layer
                let identifier = ObjectIdentifier(layer)
                liveLayers.insert(identifier)
                self.attachmentLayers[identifier] = layer
                guard let rect = layout.lineLayout.rects(for: range).first, rect.width > 0 else {
                    layer.isHidden = true
                    return
                }
                if layer.superlayer !== self.layer {
                    self.layer.addSublayer(layer)
                }
                layer.isHidden = false
                let size = attachment.layoutSize
                layer.frame = CGRect(
                    x: rect.minX + (rect.width - size.width) / 2,
                    y: rect.minY + (rect.height - size.height) / 2,
                    width: size.width,
                    height: size.height
                )
            }
        }
        let stale = attachmentHosts.keys.filter { live.contains($0) == false }
        for identifier in stale {
            if let view = attachmentHosts[identifier], view.superview === self {
                view.removeFromSuperview()
            }
            attachmentHosts.removeValue(forKey: identifier)
        }
        let staleLayers = attachmentLayers.keys.filter { liveLayers.contains($0) == false }
        for identifier in staleLayers {
            if let layer = attachmentLayers[identifier], layer.superlayer === self.layer {
                layer.removeFromSuperlayer()
            }
            attachmentLayers.removeValue(forKey: identifier)
        }
    }

    /// 命中链接或截断 token。
    /// - Parameter point: 相对 bounds 的点。
    /// - Returns: 命中动作；点在空白处为 nil。
    func hitAction(at point: CGPoint) -> ZHHTextHitAction? {
        let width = bounds.width > 0 ? bounds.width : preferredMaxLayoutWidth
        guard width > 0 else { return nil }
        let result = layout(constrainedWidth: width)
        return result.lineLayout.hit(at: point, displayText: result.displayText, linksByID: result.linksByID)
    }

    /// 清除按下高亮和当前命中。
    func clearHighlight() {
        activeHit = nil
        highlightedRange = nil
        setNeedsDisplay()
    }
}
