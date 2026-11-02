//
//  DemoCatalog.swift
//  ZHHTextKit
//
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import UIKit
import ZHHTextKit

enum DemoCatalog {
    /// 首页列表数据。
    static let entries: [DemoEntry] = [
        DemoEntry(title: "社区 Feed", detail: "话题、提及、链接、电话、全文和列表缓存", make: { FeedDemoViewController() }),
        DemoEntry(title: "Text Editor", detail: "选人发布 document；回显 entities 可点", make: { EditorDemoViewController() }),
        DemoEntry(title: "正文标签编辑", detail: "正文里插胶囊标签，退格整段删；下方 Label 预览", make: { InlineChipComposerDemoViewController() }),
        DemoEntry(title: "混排帖子卡片", detail: "正文 + 胶囊标签 + @/# + 链接，只读回显", make: { MixedPostDemoViewController() }),
        DemoEntry(title: "截断与展开", detail: "行数限制、全文 / 收起、自定义 token", make: { TruncationDemoViewController() }),
        DemoEntry(title: "协议正文点击", detail: "allowsBodyTap：点普通字勾选，点协议名打开链接", make: { AgreementBodyTapDemoViewController() }),
        DemoEntry(title: "Text Attributes 1", detail: "阴影、图案字、边框、可点链接", make: { AttributeDemoViewController() }),
        DemoEntry(title: "Text Attributes 2", detail: "彩色标签：Label 展示 / TextView 编辑", make: { TagDemoViewController() }),
        DemoEntry(title: "Text Attachments", detail: "图片、视图、图层和自定义 ...more", make: { AttachmentDemoViewController() }),
        DemoEntry(title: "Text Edit", detail: "图文绕排编辑", make: { EditDemoViewController() }),
        DemoEntry(title: "Text Parser (Markdown)", detail: "标题、强调、链接、代码", make: { MarkdownDemoViewController() }),
        DemoEntry(title: "Text Parser (Emoticon)", detail: "系统 emoji + 自定义表情图混排", make: { EmoticonDemoViewController() }),
        DemoEntry(title: "Text Binding", detail: "退格先选中整段邮箱", make: { BindingDemoViewController() }),
        DemoEntry(title: "Copy and Paste", detail: "插入图片、复制和粘贴", make: { PasteDemoViewController() }),
        DemoEntry(title: "Undo and Redo", detail: "撤销和重做", make: { UndoDemoViewController() }),
        DemoEntry(title: "Ruby Annotation", detail: "汉字和假名注音", make: { RubyDemoViewController() }),
        DemoEntry(title: "Async Display", detail: "UILabel 和 ZHHTextLabel 对比", make: { AsyncDemoViewController() })
    ]
}

