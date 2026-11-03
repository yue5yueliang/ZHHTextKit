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
/// 水平排版。后续若增加竖排，仍通过 `apply`、`text`、`onTapLink`、可选的 `onTapBody` 与 `onLongPress` 使用，不另开一套数据接口。
/// 链接的 `range` 始终相对未截断全文。完全落在被裁掉区域里的链接不可点；与可见区有交集的链接保持可点，回调里的 range 仍是原文区间。
/// 「全文 / 收起」热区由内部透明 `UIControl` 承接命中，便于宿主按 `UIControl` 排除单击暂停等手势；话题等链接仍由 Label 自身处理。
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
    /// 当前按下是否用前景字色高亮（正文）；否则用背景底。
    private var highlightUsesForeground = false
    /// 当前手指按下命中的动作。
    private var activeHit: ZHHTextHitAction?
    /// 行内视图附件：身份到宿主视图。
    private var attachmentHosts: [ObjectIdentifier: UIView] = [:]
    /// 行内图层附件：身份到子图层。
    private var attachmentLayers: [ObjectIdentifier: CALayer] = [:]
    /// 长按手势；仅在 `allowsLongPressCopy` 时启用。
    private lazy var longPressGesture: UILongPressGestureRecognizer = {
        let gesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        gesture.minimumPressDuration = 0.45
        gesture.cancelsTouchesInView = true
        gesture.isEnabled = false
        return gesture
    }()
    /// 承接「全文 / 收起」热区的透明控件。
    ///
    /// 视觉仍是内联 token，不额外画按钮；点击时 `touch.view` 落在 `UIControl` 上，
    /// 便于短视频滑滑流等宿主按「跳过 UIControl」排除单击暂停手势。
    /// 仅在存在可点截断 token 时启用；无 token 时隐藏，避免挡底层手势。
    private lazy var expandHitControl: UIControl = {
        let control = UIControl()
        // 透明覆盖，不改变内联 token 的绘制外观。
        control.backgroundColor = .clear
        // 默认关闭；等排版算出 truncationRange 后再打开。
        control.isHidden = true
        control.isUserInteractionEnabled = false
        // 无障碍继续走 Label 自身的 staticText，避免重复朗读。
        control.isAccessibilityElement = false
        control.addTarget(self, action: #selector(handleExpandControlTouchDown), for: .touchDown)
        control.addTarget(self, action: #selector(handleExpandControlTouchUpInside), for: .touchUpInside)
        control.addTarget(
            self,
            action: #selector(handleExpandControlTouchCancel),
            for: [.touchUpOutside, .touchCancel, .touchDragExit]
        )
        return control
    }()
    /// 当前展开热区对应的展示串区间。
    ///
    /// 与 `layout.truncationRange` 对齐，供 control 按下时画高亮；无可点 token 时为 nil。
    private var expandTokenDisplayRange: NSRange?

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

    /// 是否允许点击普通正文。默认 `false`，Feed 等列表保持现状；协议勾选等场景可打开。
    ///
    /// 打开后，点在非链接、非截断 token 的字形上会走 `onTapBody`。命中优先级仍是：截断 token > 链接 > 正文。
    public var allowsBodyTap: Bool = false

    /// 点击普通正文时回调。仅在 `allowsBodyTap == true` 时生效。
    ///
    /// 按下时对连续正文段做字色高亮（`bodyHighlightColor`，默认略淡的正文色），不铺背景。
    public var onTapBody: (() -> Void)?

    /// 是否允许长按回调。默认 `false`。
    ///
    /// 开启后长按会走 `onLongPress`，并取消本次短按；库不弹菜单、不写剪贴板。
    public var allowsLongPressCopy: Bool = false {
        didSet {
            longPressGesture.isEnabled = allowsLongPressCopy
        }
    }

    /// 长按回调。仅在 `allowsLongPressCopy == true` 时生效；内容由业务自行组装菜单或复制。
    public var onLongPress: ((ZHHTextLongPressInfo) -> Void)?

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

    /// 在指定点执行一次长按回调（单测用）。
    /// - Parameter point: 相对 bounds 的点。
    func performLongPress(at point: CGPoint) {
        guard allowsLongPressCopy else { return }
        clearHighlight()
        onLongPress?(makeLongPressInfo(at: point))
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
        // 尚无宽度时无法排版，顺手清掉热区，避免复用残留。
        guard bounds.width > 0 else {
            hideExpandHitControl()
            return
        }
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
        let result = layout(constrainedWidth: bounds.width)
        placeViewAttachments(result)
        // 宽度变化、展开切换、列表复用后都在这里同步热区 frame。
        updateExpandHitControl(for: result)
    }

    open override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard bounds.width > 0, bounds.height > 0, let context = UIGraphicsGetCurrentContext() else { return }
        let result = layout(constrainedWidth: bounds.width)
        let highlightStyle: ZHHTextLineLayout.PressHighlightStyle = highlightUsesForeground ? .foreground : .background
        let color: UIColor
        if highlightUsesForeground {
            color = (style.bodyHighlightColor ?? style.textColor.withAlphaComponent(0.45))
                .resolvedColor(with: traitCollection)
        } else {
            color = style.highlightColor.resolvedColor(with: traitCollection)
        }
        result.lineLayout.draw(
            in: context,
            text: result.displayText,
            highlight: highlightedRange,
            highlightColor: color,
            highlightStyle: highlightStyle
        )
        placeViewAttachments(result)
        // 异步排版或仅触发重绘时，同样刷新热区，避免与字形错位。
        updateExpandHitControl(for: result)
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

        // 展开热区优先落到 UIControl：宿主 `shouldReceive` 可用 `touch.view is UIControl` 跳过暂停。
        if expandHitControl.isUserInteractionEnabled, !expandHitControl.isHidden {
            let local = convert(point, to: expandHitControl)
            if expandHitControl.point(inside: local, with: event) {
                return expandHitControl
            }
        }

        // 其余附件子视图照常命中；expandHitControl 已单独处理，这里跳过避免重复。
        for subview in subviews.reversed() {
            if subview === expandHitControl { continue }
            let local = convert(point, to: subview)
            if let hit = subview.hitTest(local, with: event) {
                return hit
            }
        }
        // 开启长按时整块可接手势；否则仅在有可点命中时拦截。
        // 截断 token 已由 expandHitControl 承接，这里不再把 .expand 算作 Label 自身命中，
        // 否则 touch.view 会落在普通 UIView 上，滑滑流单击暂停仍会触发。
        if allowsLongPressCopy {
            return self
        }
        if let action = hitAction(at: point), action.kind != .expand {
            return self
        }
        return nil
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard allowsLongPressCopy, gesture.state == .began else { return }
        let point = gesture.location(in: self)
        clearHighlight()
        onLongPress?(makeLongPressInfo(at: point))
    }

    /// 展开热区按下：用截断 token 区间画背景高亮，与原先 Label 触摸路径观感一致。
    @objc private func handleExpandControlTouchDown() {
        guard let range = expandTokenDisplayRange else { return }
        activeHit = ZHHTextHitAction(kind: .expand, displayRange: range)
        highlightedRange = range
        // 展开 token 用背景高亮，不用正文前景色。
        highlightUsesForeground = false
        setNeedsDisplay()
    }

    /// 展开热区抬起：清除高亮，并走与 `.expand` 相同的 `activate`（切换展开态 + `onTapExpand`）。
    @objc private func handleExpandControlTouchUpInside() {
        clearHighlight()
        activate(ZHHTextHitAction(
            kind: .expand,
            displayRange: expandTokenDisplayRange ?? NSRange(location: 0, length: 0)
        ))
    }

    /// 展开热区取消或拖出：只清高亮，不切换展开态。
    @objc private func handleExpandControlTouchCancel() {
        clearHighlight()
    }

    open override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self), let action = hitAction(at: point) else {
            clearHighlight()
            return
        }
        activeHit = action
        highlightedRange = action.displayRange
        highlightUsesForeground = (action.kind == .body)
        setNeedsDisplay()
    }

    open override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else { return }
        guard let action = hitAction(at: point), action.kind == activeHit?.kind else {
            highlightedRange = nil
            highlightUsesForeground = false
            setNeedsDisplay()
            return
        }
        highlightedRange = action.displayRange
        highlightUsesForeground = (action.kind == .body)
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
        // 先挂上热区控件；默认隐藏，等有 truncationRange 再启用。
        addSubview(expandHitControl)
        addGestureRecognizer(longPressGesture)
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
        highlightUsesForeground = false
        activeHit = nil
        // 内容一变，旧热区立刻失效，等下一次 layout/draw 再按新 truncationRange 重建。
        expandTokenDisplayRange = nil
        hideExpandHitControl()
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

    /// 分发链接点击、切换展开态，或正文点击。
    /// - Parameter action: 命中结果。
    func activate(_ action: ZHHTextHitAction) {
        switch action.kind {
        case .link(let link):
            onTapLink?(link)
        case .expand:
            isExpanded = !isExpanded
            onTapExpand?(isExpanded)
        case .body:
            onTapBody?()
        }
    }

    /// 按截断 token 矩形更新展开热区 `UIControl`。
    ///
    /// 折叠态「…全文 / 自定义 truncationToken」、展开态「收起」共用此路径。
    /// `truncationRange` 为空（未截断、仅省略号、或关闭 showsCollapsed/ExpandedToken）时隐藏控件，
    /// 避免透明热区吞掉播放器等底层手势。
    /// - Parameter layout: 当前宽度下的排版结果。
    func updateExpandHitControl(for layout: ZHHTextLayout) {
        guard let range = layout.truncationRange,
              range.length > 0,
              let union = layout.lineLayout.expandHitUnion(for: range),
              union.width > 0,
              union.height > 0 else {
            hideExpandHitControl()
            return
        }
        expandTokenDisplayRange = range
        // frame 与 hitExpandToken 外扩一致，保证命中区域和手势过滤范围对齐。
        expandHitControl.frame = union
        expandHitControl.isHidden = false
        expandHitControl.isUserInteractionEnabled = true
        // 置于附件之上，避免行内视图挡住「全文 / 收起」。
        bringSubviewToFront(expandHitControl)
    }

    /// 隐藏并禁用展开热区控件。
    ///
    /// 清空 frame，确保 `hitTest` 不会再落到该 `UIControl` 上。
    func hideExpandHitControl() {
        expandTokenDisplayRange = nil
        expandHitControl.isHidden = true
        expandHitControl.isUserInteractionEnabled = false
        expandHitControl.frame = .zero
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

    /// 命中链接、截断 token，或（开启后）普通正文。
    /// - Parameter point: 相对 bounds 的点。
    /// - Returns: 命中动作；点在空白处为 nil。
    func hitAction(at point: CGPoint) -> ZHHTextHitAction? {
        hitAction(at: point, allowsBodyTap: allowsBodyTap)
    }

    /// 命中探测。
    /// - Parameters:
    ///   - point: 相对 bounds 的点。
    ///   - allowsBodyTap: 是否把普通正文算作命中。
    /// - Returns: 命中动作；点在空白处为 nil。
    func hitAction(at point: CGPoint, allowsBodyTap: Bool) -> ZHHTextHitAction? {
        let width = bounds.width > 0 ? bounds.width : preferredMaxLayoutWidth
        guard width > 0 else { return nil }
        let result = layout(constrainedWidth: width)
        return result.lineLayout.hit(
            at: point,
            displayText: result.displayText,
            linksByID: result.linksByID,
            allowsBodyTap: allowsBodyTap
        )
    }

    /// 组装长按回调上下文。分类时强制探测正文，不依赖 `allowsBodyTap`。
    func makeLongPressInfo(at point: CGPoint) -> ZHHTextLongPressInfo {
        let width = bounds.width > 0 ? bounds.width : preferredMaxLayoutWidth
        let result = width > 0 ? layout(constrainedWidth: width) : nil
        let attributed = storedAttributedText ?? NSAttributedString()
        let plain = storedText ?? attributed.string
        let visible = result?.displayText.string ?? plain

        let action = hitAction(at: point, allowsBodyTap: true)
        let kind: ZHHTextLongPressInfo.Kind
        let displayRange: NSRange?
        switch action?.kind {
        case .link(let link):
            kind = .link(link)
            displayRange = action?.displayRange
        case .expand:
            kind = .expand
            displayRange = action?.displayRange
        case .body:
            kind = .body
            displayRange = action?.displayRange
        case .none:
            kind = .empty
            displayRange = nil
        }

        return ZHHTextLongPressInfo(
            point: point,
            kind: kind,
            plainText: plain,
            visibleText: visible,
            attributedText: attributed,
            displayRange: displayRange
        )
    }

    /// 清除按下高亮和当前命中。
    func clearHighlight() {
        activeHit = nil
        highlightedRange = nil
        highlightUsesForeground = false
        setNeedsDisplay()
    }
}
