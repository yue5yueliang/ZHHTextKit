//
//  EmoticonDemoViewController.swift
//  ZHHTextKit
//
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import UIKit
import ZHHTextKit

final class EmoticonDemoViewController: UIViewController, UITextViewDelegate {
    private let viewModel = EmoticonDemoViewModel()
    private let textView = UITextView()
    private let preview = ZHHTextLabel()
    private var applying = false
    private let bodyFont = UIFont.systemFont(ofSize: 18)

    private let systemItems: [(token: String, emoji: String)] = [
        (":smile:", "😄"),
        (":cool:", "😎"),
        (":biggrin:", "😁"),
        (":arrow:", "➡️"),
        (":confused:", "😕"),
        (":cry:", "😢"),
        (":wink:", "😉")
    ]

    /// 角色类：`emo_face_*`，图更大，行内按约 1.35 倍行高显示。
    private let faceItems: [(asset: String, name: String)] = [
        ("emo_face_smile", "微笑"),
        ("emo_face_laugh", "大笑"),
        ("emo_face_titter", "偷笑"),
        ("emo_face_heart", "比心"),
        ("emo_face_like", "点赞"),
        ("emo_face_melon", "吃瓜"),
        ("emo_face_dog", "狗子"),
        ("emo_face_clap", "鼓掌"),
        ("emo_face_scissors", "剪刀手"),
        ("emo_face_adore", "爱慕"),
        ("emo_face_sixsix", "666"),
        ("emo_face_daze", "发呆"),
        ("emo_face_expect", "期待"),
        ("emo_face_proud", "得意"),
        ("emo_face_silly", "憨笑"),
        ("emo_face_tongue", "吐舌")
    ]

    /// 符号类：`emo_symbol_*`，线稿更小，行内按约 1.0 倍行高显示。
    private let symbolItems: [(asset: String, name: String)] = [
        ("emo_symbol_play", "播放"),
        ("emo_symbol_pause", "暂停"),
        ("emo_symbol_stop", "停止"),
        ("emo_symbol_next", "下一首"),
        ("emo_symbol_previous", "上一首"),
        ("emo_symbol_volume_up", "音量加"),
        ("emo_symbol_volume_down", "音量减"),
        ("emo_symbol_volume_off", "静音"),
        ("emo_symbol_shuffle", "随机"),
        ("emo_symbol_replay", "重播"),
        ("emo_symbol_forward", "快进"),
        ("emo_symbol_rewind", "快退"),
        ("emo_symbol_record", "录音"),
        ("emo_symbol_equalizer", "均衡器"),
        ("emo_symbol_playlist", "列表"),
        ("emo_symbol_airplay", "投屏"),
        ("emo_symbol_cast", "投射"),
        ("emo_symbol_fullscreen", "全屏"),
        ("emo_symbol_fullscreen_exit", "退出全屏"),
        ("emo_symbol_eject", "弹出")
    ]

    /// Demo 只负责资源表；替换与 Label 转换走 `ZHHTextEmoticonMapper`。
    private lazy var mapper: ZHHTextEmoticonMapper = {
        var items: [ZHHTextEmoticonItem] = systemItems.map {
            ZHHTextEmoticonItem(token: $0.token, emoji: $0.emoji)
        }
        for item in faceItems {
            guard let image = UIImage(named: item.asset) else { continue }
            items.append(ZHHTextEmoticonItem(bracketName: item.name, image: image, sizeFactor: 1.35))
        }
        for item in symbolItems {
            guard let image = UIImage(named: item.asset) else { continue }
            items.append(ZHHTextEmoticonItem(bracketName: item.name, image: image, sizeFactor: 1))
        }
        return ZHHTextEmoticonMapper(items: items, font: bodyFont, textColor: .label)
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let systemBar = makeBar(
            title: "系统 Emoji（输入 :smile: 也会替换）",
            buttons: systemItems.enumerated().map { index, item in
                makeTextButton(title: "\(item.emoji) \(item.token)", tag: index, action: #selector(insertSystem(_:)))
            }
        )
        let faceBar = makeBar(
            title: "角色表情（输入 [微笑] 也会替换）",
            buttons: faceItems.enumerated().map { index, item in
                makeCustomButton(asset: item.asset, title: "[\(item.name)]", tag: index, action: #selector(insertFace(_:)))
            }
        )
        let symbolBar = makeBar(
            title: "符号表情（输入 [播放] 也会替换）",
            buttons: symbolItems.enumerated().map { index, item in
                makeCustomButton(asset: item.asset, title: "[\(item.name)]", tag: 1000 + index, action: #selector(insertSymbol(_:)))
            }
        )

        textView.font = bodyFont
        textView.delegate = self
        textView.keyboardDismissMode = .interactive
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        textView.typingAttributes = [
            .font: bodyFont,
            .foregroundColor: UIColor.label
        ]
        textView.translatesAutoresizingMaskIntoConstraints = false

        let previewCaption = UILabel()
        previewCaption.text = "ZHHTextLabel 预览（附件转成行内图）"
        previewCaption.font = UIFont.preferredFont(forTextStyle: .footnote)
        previewCaption.textColor = .secondaryLabel
        preview.numberOfLines = 0
        preview.clipsToBounds = false
        preview.backgroundColor = .secondarySystemBackground
        preview.layer.cornerRadius = 10
        preview.translatesAutoresizingMaskIntoConstraints = false

        let scroll = UIScrollView()
        scroll.keyboardDismissMode = .interactive
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        let column = UIStackView(arrangedSubviews: [
            systemBar, faceBar, symbolBar, textView, previewCaption, preview
        ])
        column.axis = .vertical
        column.spacing = 10
        column.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(column)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            column.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 8),
            column.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor),
            column.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor),
            column.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -12),
            textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 160),
            preview.leadingAnchor.constraint(equalTo: column.leadingAnchor, constant: 12),
            preview.trailingAnchor.constraint(equalTo: column.trailingAnchor, constant: -12)
        ])

        seedEditor()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        textView.becomeFirstResponder()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let width = view.bounds.width - 24
        if width > 0, preview.preferredMaxLayoutWidth != width {
            preview.preferredMaxLayoutWidth = width
        }
    }

    func textViewDidChange(_ textView: UITextView) {
        guard !applying else { return }
        replaceShortcodes(caret: textView.selectedRange.location)
    }

    @objc private func insertSystem(_ sender: UIButton) {
        guard systemItems.indices.contains(sender.tag) else { return }
        insertSnippet(systemItems[sender.tag].token)
    }

    @objc private func insertFace(_ sender: UIButton) {
        guard faceItems.indices.contains(sender.tag) else { return }
        insertSnippet("[\(faceItems[sender.tag].name)]")
    }

    @objc private func insertSymbol(_ sender: UIButton) {
        let index = sender.tag - 1000
        guard symbolItems.indices.contains(index) else { return }
        insertSnippet("[\(symbolItems[index].name)]")
    }

    private func seedEditor() {
        let seed = NSMutableAttributedString(
            string: "系统表情用短码 :smile: :wink:，自定义用 [微笑][比心]，可以混着写。",
            attributes: [
                .font: bodyFont,
                .foregroundColor: UIColor.label
            ]
        )
        textView.textStorage.setAttributedString(seed)
        replaceShortcodes(caret: seed.length)
    }

    private func insertSnippet(_ snippet: String) {
        let location = min(textView.selectedRange.location, textView.textStorage.length)
        let piece = NSAttributedString(string: snippet, attributes: textView.typingAttributes)
        textView.textStorage.insert(piece, at: location)
        textView.selectedRange = NSRange(location: location + piece.length, length: 0)
        replaceShortcodes(caret: location + piece.length)
    }

    /// 在 `textStorage` 上替换短码，保留已有自定义附件。
    private func replaceShortcodes(caret: Int) {
        applying = true
        let adjusted = mapper.replaceShortcodes(in: textView.textStorage, caret: caret)
        textView.selectedRange = NSRange(location: adjusted, length: 0)
        applying = false
        refreshPreview()
    }

    private func refreshPreview() {
        preview.attributedText = ZHHTextEmoticonMapper.labelCompatible(textView.textStorage, alignedTo: bodyFont)
        preview.invalidateIntrinsicContentSize()
    }

    private func makeBar(title: String, buttons: [UIView]) -> UIStackView {
        let caption = UILabel()
        caption.text = title
        caption.font = UIFont.preferredFont(forTextStyle: .footnote)
        caption.textColor = .secondaryLabel
        caption.numberOfLines = 0

        let row = UIStackView(arrangedSubviews: buttons)
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            row.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -12),
            row.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            row.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor)
        ])
        scroll.heightAnchor.constraint(equalToConstant: 44).isActive = true

        let captionWrap = UIView()
        caption.translatesAutoresizingMaskIntoConstraints = false
        captionWrap.addSubview(caption)
        NSLayoutConstraint.activate([
            caption.topAnchor.constraint(equalTo: captionWrap.topAnchor),
            caption.leadingAnchor.constraint(equalTo: captionWrap.leadingAnchor, constant: 12),
            caption.trailingAnchor.constraint(equalTo: captionWrap.trailingAnchor, constant: -12),
            caption.bottomAnchor.constraint(equalTo: captionWrap.bottomAnchor)
        ])
        let stack = UIStackView(arrangedSubviews: [captionWrap, scroll])
        stack.axis = .vertical
        stack.spacing = 4
        return stack
    }

    private func makeTextButton(title: String, tag: Int, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        button.tag = tag
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func makeCustomButton(asset: String, title: String, tag: Int, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        var config = UIButton.Configuration.plain()
        config.title = title
        config.baseForegroundColor = .label
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.systemFont(ofSize: 13)
            return outgoing
        }
        // 图标与短码、按钮之间都留空，避免「图[微笑]」糊成一团。
        config.imagePadding = 8
        config.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 10)
        if let image = UIImage(named: asset)?.withRenderingMode(.alwaysOriginal) {
            let side: CGFloat = asset.hasPrefix("emo_face_") ? 28 : 22
            config.image = image.preparingThumbnail(of: CGSize(width: side, height: side)) ?? image
        }
        config.background.backgroundColor = UIColor.secondarySystemFill
        config.background.cornerRadius = 10
        button.configuration = config
        button.tag = tag
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }
}

/// 邮箱整段绑定删除示例（系统 UITextView）。
