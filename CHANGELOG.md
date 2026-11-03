# Changelog

## 1.0.5

### Added
- `ZHHTextView.placeholder` / `placeholderColor`：空文且无未上屏联想时显示占位，布局对齐 `textContainerInset`
- `ZHHTextView.maxTextLength` / `onReachMaxLength`：按 `String.count`（字素）限制正文；`@` / `#` 按展示原文计入；超限整段拒绝插入（含粘贴与提及/话题插入），删除不受限

## 1.0.4

- 展开/收起热区改用 `UIButton`，并在按下时暂时冻结祖先单击手势

## 1.0.3

- 展开/收起热区由内部控件承接命中

## 1.0.2

- 正文点击、长按回调；Demo 按场景拆分

## 1.0.1

- 折叠截断 token 分色优化

## 1.0.0

- 首发：纯 Swift 富文本解析、展示与输入
