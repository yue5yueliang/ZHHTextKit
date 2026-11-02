//
//  ZHHTextDetecting.swift
//  ZHHTextKit
//
//  Created by 桃色三岁 on 2026/10/26.
//  Copyright © 2026 桃色三岁. All rights reserved.
//

import Foundation

/// 检测器输出的一个候选区间。多个检测器的结果允许重叠，由解析器统一取舍。
struct ZHHTextDetectedSpan {
    /// 相对入参纯文本的 UTF-16 range。
    var range: NSRange
    /// 命中的链接种类。原文子串由解析器按 range 截取。
    var kind: ZHHTextLink.Kind
}

/// 纯文本检测器。实现不得修改入参，也不得依赖 UI。
protocol ZHHTextDetecting {
    /// 返回候选区间。顺序没有要求。
    func detect(in text: String) -> [ZHHTextDetectedSpan]
}
