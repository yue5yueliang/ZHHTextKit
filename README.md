# ZHHTextKit

纯 Swift 富文本组件，面向社区 Feed、评论、私信、个人简介和协议页。用 `ZHHTextParser` 把纯文本解析成带点击信息的富文本，用 `ZHHTextLabel` 做行数截断、「全文 / 收起」和点击分发；另提供自定义表情短码替换与正文胶囊标签。

排版使用 CoreText，同一套结果可在后台线程计算并缓存。

要求 iOS 15+。

## 安装

CocoaPods：

```ruby
pod 'ZHHTextKit'
```

本地开发：

```ruby
pod 'ZHHTextKit', :path => '../'
```

Swift Package Manager 把仓库加为依赖，产品名是 `ZHHTextKit`。

## 最小示例

```swift
import ZHHTextKit

var style = ZHHTextStyle()
style.textColor = .label
style.topicColor = .systemOrange
style.mentionColor = .systemTeal
style.linkColor = .systemBlue

var parser = ZHHTextParser(style: style)
parser.topicRule.names = ["周末去哪儿"]
parser.mentionRule.bindings = [ZHHTextMentionBinding(name: "小明", userID: "u-1001")]

let label = ZHHTextLabel()
label.numberOfLines = 3
label.parser = parser
label.text = "约 @小明 看 #周末去哪儿# https://example.com 13800138000"
label.onTapLink = { link in
    print(link.kind.typeName, link.text)
}
label.onTapExpand = { isExpanded in
    print(isExpanded ? "展开" : "收起")
}
```

`ZHHTextLink.range` 相对未截断全文，单位是 UTF-16。被裁掉的链接不可点；还露在外面的链接可以点，回调里的 range 仍是原文区间。

## 列表

把展开状态放在数据模型上，不要放在 cell 里。cell 复用时先丢掉旧文本，再写入新文本。Label 用代数丢弃过期的后台结果，避免滑出屏幕的那条内容被点到。

```swift
let cache = ZHHTextMemoryLayoutCache()
label.layoutCache = cache
label.displaysAsynchronously = true
label.numberOfLines = 3
label.isExpanded = model.isExpanded

// 即将进入屏幕的数据提前排版。宽度、行数、展开态、截断文案和界面风格要与 Label 一致。
ZHHTextLayoutPrefetcher.prefetch(inputs, cache: cache)
```

`displaysAsynchronously` 只把缓存未命中的排版挪到后台。主线程会等待这一次结果，行高不会先变成 0。缓存命中时立即返回。Example 的 Async Display 和社区 Feed 会按当前宽度预取。

## 自定义表情

业务自己维护短码表和图片资源。库负责：短码 → 系统 emoji / `NSTextAttachment`，以及编辑区附件转成 Label 可画的行内图。

```swift
let font = UIFont.systemFont(ofSize: 18)
let smile = UIImage(named: "emo_face_smile")!
let mapper = ZHHTextEmoticonMapper(
    items: [
        ZHHTextEmoticonItem(token: ":smile:", emoji: "😄"),
        ZHHTextEmoticonItem(bracketName: "微笑", image: smile, sizeFactor: 1.35)
    ],
    font: font
)

// 一次性：纯文本 → 富文本
label.attributedText = ZHHTextEmoticonMapper.labelCompatible(
    mapper.attributedString(from: "你好 :smile: [微笑]"),
    alignedTo: font
)

// 输入中：在 UITextView.textStorage 上替换短码，并校正光标
func textViewDidChange(_ textView: UITextView) {
    let caret = mapper.replaceShortcodes(in: textView.textStorage, caret: textView.selectedRange.location)
    textView.selectedRange = NSRange(location: caret, length: 0)
    preview.attributedText = ZHHTextEmoticonMapper.labelCompatible(textView.textStorage, alignedTo: font)
}
```

要点：

- 匹配按短码从长到短，避免 `:sm:` 误伤 `:smile:`。
- 自定义图用 `sizeFactor` 相对 `font.lineHeight`（角色表情常用 `1.35`，符号常用 `1.0`）。
- `labelCompatible` 只转换带 `ZHHTextEmoticonAttribute.token` 的附件，其它图片不动。
- Example →「Text Parser (Emoticon)」可对照完整面板。

## 胶囊标签

编辑器用位图附件（退格一次整颗删）；Label 用文字 + `ZHHTextBorder`。正文混排预览走 `labelCompatible`。

```swift
let chip = ZHHTextChip(name: "咖啡探店", fill: 0xE8A33A, stroke: 0xD4890A)
let chipFont = UIFont.boldSystemFont(ofSize: 15)

// 只读 Label：边框画在字形上
label.attributedText = chip.labelPiece(font: chipFont)

// 可编辑：TextKit 1 + 整段退格
let editor = ZHHTextChipTextView.make()
editor.textStorage.append(chip.piece(font: chipFont))

// 编辑区 → Feed 预览
preview.attributedText = ZHHTextChip.labelCompatible(editor.textStorage, alignedTo: bodyFont)
```

要点：

- `piece` 把间距画进位图左右透明边，字符串里不必再夹空格。
- `labelPiece` 边框只盖文案；前后 NBSP 给外扩留空，方便再叠点击 `ZHHTextLink`。
- `attachmentRange(in:touching:)` 供自定义 `deleteBackward`；`ZHHTextChipTextView` 已内置整段删。
- Example →「正文标签编辑」「Text Attributes 2」「混排帖子卡片」可对照。

## 路线图

| 里程碑 | 内容 | 状态 |
| --- | --- | --- |
| M1 | 话题、提及、URL、电话解析；截断展开；点击；Example；单测 | 已完成 |
| M2 | 布局缓存、后台预计算、列表复用示例 | 已完成 |
| M3 | 图片、视图、图层附件；自定义截断 token | 已完成 |
| M4 | 富文本输入：@ / 话题插入；话题可编辑，@ 整段删 | 已完成 |
| M5 | 自定义表情、胶囊标签正式 API；回归单测 | 已完成（`1.0.0`） |

## 输入

业务自己的选人界面不用换。输入 `@` / `#` 时走 `onSpecialTrigger`，选完后再 `insert`。  
话题主格式为单井号 `#名字`（`#名字#` 仍可解析）；输入框内可进光标、逐字改，改坏后本地 id 拆掉。`@` 仍整段删除。

```swift
let editor = ZHHTextView()
editor.onSpecialTrigger = { trigger in
    // 只弹选人 / 选话题；选完再 insert。不要无条件 insert。
    presentPicker(for: trigger)
}
editor.insert(mention: ZHHTextMention(name: "小红", userID: "u-2002"))
editor.insert(topic: ZHHTextTopic(name: "城市漫步", topicID: "t-200"))
let document = editor.makePostDocument() // text + 已选 entities
```

## 发布 / 回显契约

| 角色 | 职责 |
| --- | --- |
| iOS / Android | 提交 `ZHHTextPostDocument`：`text` + 用户明确选过的 `entities`（有 id） |
| 服务端 | 校验已选 id；扫描手打 `#` / `@` 补 id；详情接口返回最终 document |
| 查看页 | `parser.parse(document)` → `label.apply`；点击只用下发 id 跳转 |

```swift
// 发布（客户端）
let document = editor.makePostDocument()
api.createPost(document)

// 详情（查看页，两端一致）
let document = api.fetchPost(id).document
label.apply(parser.parse(document))
label.onTapLink = { link in
    // mention.userID / topic.topicID 来自服务端 entities
}
```

输入框里不负责「点进话题页」；跳转只发生在发布后的只读展示。

Example 工程：在 `Example` 目录执行 `pod install`，打开 `ZHHTextKit.xcworkspace`。首页有社区 Feed、Text Editor、表情短码、胶囊编辑等对照 Demo。

## 许可

MIT，见 [LICENSE](LICENSE)。
