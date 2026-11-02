//
//  AsyncDemoViewController.swift
//  ZHHTextKit
//
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import UIKit
import ZHHTextKit

final class FPSLabel: UILabel {
    private var link: CADisplayLink?
    private var last = CACurrentMediaTime()
    private var frames = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        font = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        textColor = .systemGreen
        textAlignment = .center
        text = "-- FPS"
        backgroundColor = UIColor.black.withAlphaComponent(0.72)
        layer.cornerRadius = 6
        clipsToBounds = true
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func start() {
        guard link == nil else { return }
        let display = CADisplayLink(target: self, selector: #selector(tick))
        display.add(to: .main, forMode: .common)
        link = display
    }

    deinit {
        link?.invalidate()
    }

    @objc private func tick() {
        frames += 1
        let now = CACurrentMediaTime()
        let delta = now - last
        guard delta >= 0.5 else { return }
        text = String(format: "%.0f FPS", Double(frames) / delta)
        frames = 0
        last = now
    }
}

/// UILabel 与 ZHHTextLabel 异步排版对比。
final class AsyncDemoViewController: UIViewController, UITableViewDataSource {
    private let viewModel = AsyncDemoViewModel()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let rows: [NSAttributedString]
    private let cache = ZHHTextMemoryLayoutCache(countLimit: 400)
    private let asyncSwitch = UISwitch()
    private var prefetchedWidth: CGFloat = 0
    private var useRichText = true

    init() {
        let font = UIFont.systemFont(ofSize: 12)
        let glow = shadow(color: UIColor.black.withAlphaComponent(0.45), x: 0, y: 1, radius: 1)
        rows = (0..<300).map { index in
            let sentence = "\(index) Async Display 😀 阴影描边 " + String(repeating: "ZHHTextKit ", count: 2)
            return NSAttributedString(string: sentence, attributes: [
                .font: font,
                .foregroundColor: UIColor.black,
                .strokeColor: UIColor.systemRed,
                .strokeWidth: NSNumber(value: -2),
                .shadow: glow
            ])
        }
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let fps = FPSLabel(frame: CGRect(x: 0, y: 0, width: 72, height: 26))
        fps.start()
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: fps)

        let header = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 56))
        let caption = UILabel()
        caption.text = "ZHHTextKit 异步"
        caption.font = UIFont.systemFont(ofSize: 16)
        asyncSwitch.isOn = true
        asyncSwitch.addTarget(self, action: #selector(switchChanged), for: .valueChanged)
        caption.translatesAutoresizingMaskIntoConstraints = false
        asyncSwitch.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(caption)
        header.addSubview(asyncSwitch)
        NSLayoutConstraint.activate([
            caption.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
            caption.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            asyncSwitch.leadingAnchor.constraint(equalTo: caption.trailingAnchor, constant: 12),
            asyncSwitch.centerYAnchor.constraint(equalTo: header.centerYAnchor)
        ])
        tableView.tableHeaderView = header
        tableView.dataSource = self
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        tableView.rowHeight = 40
        tableView.register(AsyncDemoCell.self, forCellReuseIdentifier: AsyncDemoCell.reuseID)
        pinToSafeArea(tableView, in: self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let width = tableView.bounds.width - 24
        guard width > 1, abs(width - prefetchedWidth) >= 0.5 else { return }
        prefetchedWidth = width
        let style = ZHHTextStyle()
        let interfaceStyle = traitCollection.userInterfaceStyle
        let inputs = rows.map { text in
            ZHHTextLayoutInput(
                attributedText: text,
                links: [],
                width: width,
                numberOfLines: 1,
                isExpanded: false,
                style: style,
                interfaceStyle: interfaceStyle
            )
        }
        ZHHTextLayoutPrefetcher.prefetch(inputs, cache: cache, completion: nil)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: AsyncDemoCell.reuseID, for: indexPath) as! AsyncDemoCell
        cell.apply(rows[indexPath.row], rich: useRichText, cache: cache)
        return cell
    }

    @objc private func switchChanged() {
        useRichText = asyncSwitch.isOn
        tableView.reloadData()
    }
}

/// Async Display 列表 Cell。
private final class AsyncDemoCell: UITableViewCell {
    static let reuseID = "AsyncDemoCell"
    private let plain = UILabel()
    private let rich = ZHHTextLabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        plain.numberOfLines = 1
        rich.numberOfLines = 1
        rich.displaysAsynchronously = true
        contentView.addSubview(plain)
        contentView.addSubview(rich)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let rect = contentView.bounds.insetBy(dx: 12, dy: 4)
        plain.frame = rect
        rich.frame = rect
        if rect.width > 0 {
            rich.preferredMaxLayoutWidth = rect.width
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        rich.attributedText = nil
        plain.attributedText = nil
    }

    func apply(_ text: NSAttributedString, rich useRich: Bool, cache: ZHHTextLayoutCache) {
        plain.isHidden = useRich
        rich.isHidden = !useRich
        rich.layoutCache = cache
        if useRich {
            rich.attributedText = text
        } else {
            plain.attributedText = text
        }
    }
}

/// ZHHTextView 输入 @ / 话题示例：触发选人、发布文档、查看页回显。
